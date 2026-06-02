import Darwin
import Foundation
import HarnessCore

/// Connects the app to the long-lived `HarnessDaemon` process. The daemon is
/// owned by launchd (installed by `LaunchAgentInstaller`) in release builds so it
/// survives `Harness.app` quitting, logout, and reboot. The launcher's job is to
/// *find* a running daemon and, if none, start one — fast and without freezing the
/// UI. Release builds prefer launchd first so the daemon is supervised from the
/// start; debug builds and launchd failures fall back to a directly-spawned child.
///
/// **Startup must never block the main thread.** `ensureRunning(then:)` runs the
/// whole discover→install→poll dance on a background queue and calls back on the
/// main thread once the daemon answers (or gives up). The strategy is
/// *launchd-first in release*: if a quick ping fails we install/bootstrap the
/// LaunchAgent and let launchd bring the daemon up, so it is launchd-owned and
/// supervised from the start. Installing first also rewrites a stale LaunchAgent
/// path (e.g. a DerivedData path from a previous Xcode build that no longer
/// exists) instead of running a directly-spawned daemon *underneath* a launchd
/// service that then retries every throttle interval. A directly-spawned child is
/// the fallback only when launchd cannot bring one up — and is the normal path in
/// DEBUG, which skips the LaunchAgent entirely.
///
/// @unchecked Sendable: launch/poll state is confined to the serial `queue`.
final class DaemonLauncher: @unchecked Sendable {
    static let shared = DaemonLauncher()

    private var fallbackProcess: Process?
    private let queue = DispatchQueue(label: "com.robert.harness.daemon-launcher")

    private init() {}

    /// Ensure a daemon is reachable, off the main thread. `completion` runs on the
    /// main thread with `true` if the daemon answers. Safe to call at launch — the
    /// UI can build immediately and refresh from the callback.
    func ensureRunning(then completion: @escaping @MainActor (Bool) -> Void = { _ in }) {
        queue.async { [weak self] in
            let ok = self?.ensureRunningBlocking() ?? false
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(ok) } }
        }
    }

    /// Synchronous variant for non-main callers/tests. Never call from the main thread.
    @discardableResult
    func ensureRunningBlocking() -> Bool {
        if let stats = daemonStats(timeout: 0.4) {
            if bundledDaemonIsNewer(than: stats) {
                restartStaleDaemon()
                if pollUntilFreshDaemon(replacingPID: stats.pid, timeoutSeconds: 3) { return true }
            } else {
                return true
            }
        } else if daemonResponds(timeout: 0.2) {
            // A daemon old enough to not understand `daemonStats` may still
            // answer `ping`, which is not enough for newer app/CLI features.
            // Restart it through the installed LaunchAgent and wait for a
            // daemon that can report stats before declaring startup ready.
            let stalePID = daemonPIDFromFile()
            restartStaleDaemon()
            if pollUntilFreshDaemon(replacingPID: stalePID, timeoutSeconds: 3) { return true }
        }

        // In release, install the corrected LaunchAgent before falling back. This
        // fixes stale DerivedData/App bundle paths and avoids running a fallback
        // daemon underneath a launchd service that then retries every throttle
        // interval.
        #if !DEBUG
        if installLaunchAgentIfPossible(), pollUntilResponding(timeoutSeconds: 4) { return true }
        #endif

        spawnFallbackProcess()
        if pollUntilResponding(timeoutSeconds: 3) { return true }
        return false
    }

    private func daemonResponds(timeout: TimeInterval = 0.5) -> Bool {
        guard let response = try? DaemonClient().request(.ping, timeout: timeout) else { return false }
        if case .pong = response { return true }
        return false
    }

    private func daemonStats(timeout: TimeInterval = 0.5) -> DaemonStats? {
        guard let response = try? DaemonClient().request(.daemonStats, timeout: timeout),
              case let .daemonStats(stats) = response
        else { return nil }
        return stats
    }

    private func bundledDaemonIsNewer(than stats: DaemonStats) -> Bool {
        guard let executable = daemonExecutableURL(),
              let attributes = try? FileManager.default.attributesOfItem(atPath: executable.path),
              let modifiedAt = attributes[.modificationDate] as? Date
        else { return false }
        let daemonStartedAt = Date().addingTimeInterval(-stats.uptimeSeconds)
        return modifiedAt > daemonStartedAt.addingTimeInterval(1)
    }

    /// Restart the daemon **exactly once**. `install()` already bootouts-on-change + bootstraps, so a
    /// changed plist path (daemon moved on disk) starts the fresh daemon itself; only an *unchanged*
    /// path (the same binary rebuilt in place — the common Xcode dev loop) needs a single
    /// `relaunch()` kick. The old `install() + relaunch() + kill(pid)` combo fired 2–3 restarts,
    /// re-running `ensureAllSnapshotSurfaces` each time and widening the window where a pane reconnect
    /// could subscribe to a momentarily-missing surface and freeze.
    private func restartStaleDaemon() {
        guard let executable = daemonExecutableURL(),
              let report = try? LaunchAgentInstaller.install(daemonPath: executable)
        else {
            // No installable LaunchAgent (e.g. daemon binary not found) — best-effort kick.
            LaunchAgentInstaller.relaunch()
            fallbackProcess = nil
            return
        }
        if report.wasAlreadyInstalled {
            LaunchAgentInstaller.relaunch()
        }
        fallbackProcess = nil
    }

    private func pollUntilResponding(timeoutSeconds: Double) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if daemonResponds(timeout: 0.3) { return true }
            usleep(100_000)
        }
        return false
    }

    private func pollUntilFreshDaemon(replacingPID oldPID: Int32?, timeoutSeconds: Double) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if let stats = daemonStats(timeout: 0.3),
               oldPID.map({ stats.pid != $0 }) ?? true,
               !bundledDaemonIsNewer(than: stats) {
                return true
            }
            usleep(100_000)
        }
        return false
    }

    private func daemonPIDFromFile() -> Int32? {
        guard let raw = try? String(contentsOf: HarnessPaths.daemonPIDURL, encoding: .utf8) else {
            return nil
        }
        return Int32(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func installLaunchAgentIfPossible() -> Bool {
        guard let executable = daemonExecutableURL() else { return false }
        do {
            _ = try LaunchAgentInstaller.install(daemonPath: executable)
            return true
        } catch {
            fputs("Harness: LaunchAgent install failed: \(error) — using in-process daemon\n", harnessStderr)
            return false
        }
    }

    private func spawnFallbackProcess() {
        // Don't stack duplicate spawns if a previous one is still coming up.
        if let existing = fallbackProcess, existing.isRunning { return }
        guard let executable = daemonExecutableURL() else {
            fputs("Harness: could not locate HarnessDaemon executable\n", harnessStderr)
            return
        }
        let proc = Process()
        proc.executableURL = executable
        proc.standardOutput = nil
        proc.standardError = nil
        var environment = ProcessInfo.processInfo.environment
        environment["HARNESS_HOME"] = HarnessPaths.applicationSupport.path
        proc.environment = environment
        try? HarnessPaths.ensureDirectories()
        do {
            try proc.run()
            fallbackProcess = proc
        } catch {
            fputs("Harness: failed to spawn HarnessDaemon at \(executable.path): \(error)\n", harnessStderr)
        }
    }

    /// Locate the daemon binary across every layout we ship in:
    /// 1. inside the app bundle (`Contents/MacOS/HarnessDaemon`, copied by the
    ///    release packager and the Xcode post-build script),
    /// 2. next to the app bundle (Xcode `BUILT_PRODUCTS_DIR` sibling),
    /// 3. the SwiftPM debug build dir (`.build/debug`),
    /// 4. a system install path.
    private func daemonExecutableURL() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []

        if let executable = Bundle.main.executableURL {
            candidates.append(executable.deletingLastPathComponent().appendingPathComponent("HarnessDaemon"))
        }
        // Sibling of Harness.app — where Xcode drops the HarnessDaemon product.
        candidates.append(Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("HarnessDaemon"))

        #if DEBUG
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        candidates.append(repoRoot.appendingPathComponent(".build/debug/HarnessDaemon"))
        candidates.append(repoRoot.appendingPathComponent(".build/release/HarnessDaemon"))
        #endif

        candidates.append(URL(fileURLWithPath: "/usr/local/bin/HarnessDaemon"))

        return candidates.first { fm.isExecutableFile(atPath: $0.path) }
    }
}
