import Foundation

/// Checks this build's git checkout for a newer `version.json` on this repo's GitHub `main`
/// and, on a clean working tree, offers to `git pull`.
///
/// Kouen is only ever built locally (`make prod`/`make install` from the developer's own
/// clone) — never distributed as a prebuilt binary — so the checkout that produced this
/// binary is findable via `#filePath`, a compile-time literal captured right here. This is a
/// separate, lighter counter from `KouenVersion` (short/build): that pair is atomically synced
/// across 4 files by `prepare-release.sh` on every release, whereas this just answers "is
/// `main` ahead of the checkout that built this binary".
enum GitCloneUpdateChecker {
    static let currentVersion = 1

    private static let repo = "Vit129/kouen-terminal"
    private static let versionURL = URL(string: "https://raw.githubusercontent.com/\(repo)/main/version.json")!
    private static let fetchTimeout: TimeInterval = 2.5
    private static let sourceFileDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
    private static let gitExecutableURL = URL(fileURLWithPath: "/usr/bin/git")

    private static var dismissFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/kouen-terminal/update-dismissed")
    }

    struct RemoteVersion: Decodable, Sendable {
        let version: Int
        let updated: String
        let summary: String
    }

    struct CheckResult: Sendable {
        let gitRoot: String
        let currentVersion: Int
        let remoteVersion: Int
        let updated: String
        let summary: String
        let dirty: Bool
    }

    /// Best-effort, non-blocking: never throws to the caller, never touches the UI itself — the
    /// caller (`AppDelegate`) decides what to show. Returns `nil` whenever there's nothing to do:
    /// not a git checkout, fetch failed, already current, or the remote version was dismissed.
    static func check() async -> CheckResult? {
        guard let gitRoot = await Task.detached(priority: .utility, operation: { findGitRoot() }).value else {
            return nil
        }
        guard let remote = await fetchRemoteVersion() else { return nil }
        guard remote.version > currentVersion else { return nil }

        if let dismissed = readDismissedVersion(), dismissed >= remote.version {
            return nil
        }

        let dirty = await Task.detached(priority: .utility, operation: { isWorkingTreeDirty(gitRoot: gitRoot) }).value
        return CheckResult(
            gitRoot: gitRoot,
            currentVersion: currentVersion,
            remoteVersion: remote.version,
            updated: remote.updated,
            summary: remote.summary,
            dirty: dirty
        )
    }

    static func dismiss(version: Int) {
        let url = dismissFileURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "\(version)\n".write(to: url, atomically: true, encoding: .utf8)
    }

    /// Runs `git pull origin main` in the checkout root. Callers must only invoke this after
    /// confirming `CheckResult.dirty` is false and getting explicit user confirmation.
    static func pull(gitRoot: String) async -> (success: Bool, output: String) {
        let process = Process()
        process.executableURL = gitExecutableURL
        process.arguments = ["-C", gitRoot, "pull", "origin", "main"]
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        do {
            try process.run()
        } catch {
            return (false, "Failed to launch git: \(error.localizedDescription)")
        }
        // Drain both pipes concurrently, before waitUntilExit(): a `git pull` with a lot
        // of stdout (fast-forward summary) or stderr (conflict/warning text) can exceed
        // the kernel pipe buffer — reading only after exit (or reading the two
        // sequentially) deadlocks if the unread one fills first.
        async let stdoutDataTask = drainPipe(stdoutPipe)
        async let stderrDataTask = drainPipe(stderrPipe)
        let stdoutData = await stdoutDataTask
        let stderrData = await stderrDataTask
        process.waitUntilExit()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let success = process.terminationStatus == 0
        let output = success ? stdout : (stderr.isEmpty ? stdout : stderr)
        return (success, output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Reads a pipe to EOF off the calling thread — `readDataToEndOfFile()` blocks
    /// synchronously until the write end closes, so running it directly in an async
    /// context would tie up a cooperative-pool thread for the child process's lifetime.
    private static func drainPipe(_ pipe: Pipe) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: pipe.fileHandleForReading.readDataToEndOfFile())
            }
        }
    }

    // MARK: - Private

    private static func findGitRoot() -> String? {
        let process = Process()
        process.executableURL = gitExecutableURL
        process.arguments = ["-C", sourceFileDirectory, "rev-parse", "--show-toplevel"]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !output.isEmpty
        else { return nil }
        return output
    }

    private static func isWorkingTreeDirty(gitRoot: String) -> Bool {
        let process = Process()
        process.executableURL = gitExecutableURL
        process.arguments = ["-C", gitRoot, "status", "--short", "--untracked-files=normal"]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return false
        }
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return false }
        let output = String(data: data, encoding: .utf8) ?? ""
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func fetchRemoteVersion() async -> RemoteVersion? {
        var request = URLRequest(url: versionURL)
        request.timeoutInterval = fetchTimeout
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(RemoteVersion.self, from: data)
        } catch {
            return nil
        }
    }

    private static func readDismissedVersion() -> Int? {
        guard let text = try? String(contentsOf: dismissFileURL, encoding: .utf8) else { return nil }
        return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
