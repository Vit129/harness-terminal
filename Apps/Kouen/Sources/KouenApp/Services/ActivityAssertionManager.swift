import AppKit
import Foundation
import KouenCore
import KouenIPC

/// Manages macOS `ProcessInfo.beginActivity` assertions to prevent App Nap and system sleep
/// from interrupting active PTY build sessions, daemon tasks, and AI subagent runs (Phase 9).
@MainActor
final class ActivityAssertionManager {
    static let shared = ActivityAssertionManager()

    /// Active activity assertions keyed by string ID.
    private var assertions: [String: NSObjectProtocol] = [:]
    /// Map of surface IDs to their associated assertion keys so surface teardown
    /// releases all assertions for that surface without leaving orphan tokens.
    private var surfaceAssertionKeys: [SurfaceID: Set<String>] = [:]

    init() {}

    /// Begin a power activity assertion for a named workload.
    /// - Parameters:
    ///   - key: Unique key identifying the workload (e.g. `pty-build:<surfaceID>`)
    ///   - surfaceID: Surface ID to associate with this assertion for pane teardown release
    ///   - reason: Descriptive reason string passed to ProcessInfo
    func beginActivity(key: String, surfaceID: SurfaceID? = nil, reason: String) {
        guard assertions[key] == nil else { return }
        let token = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: reason
        )
        assertions[key] = token
        if let surfaceID {
            surfaceAssertionKeys[surfaceID, default: []].insert(key)
        }
    }

    /// End a power activity assertion.
    /// - Parameter key: Unique key identifying the workload
    func endActivity(key: String) {
        guard let token = assertions.removeValue(forKey: key) else { return }
        ProcessInfo.processInfo.endActivity(token)
        for (surfaceID, keys) in surfaceAssertionKeys {
            if keys.contains(key) {
                var updated = keys
                updated.remove(key)
                if updated.isEmpty {
                    surfaceAssertionKeys.removeValue(forKey: surfaceID)
                } else {
                    surfaceAssertionKeys[surfaceID] = updated
                }
            }
        }
    }

    /// Release all activity assertions tied to a specific surface.
    /// Called directly from `TerminalPaneRegistry.onRetire` via `SessionCoordinator`'s retire hook,
    /// ensuring assertions are always cleaned up on pane death/session teardown.
    func releaseAssertions(forSurface surfaceID: SurfaceID) {
        guard let keys = surfaceAssertionKeys.removeValue(forKey: surfaceID) else { return }
        for key in keys {
            if let token = assertions.removeValue(forKey: key) {
                ProcessInfo.processInfo.endActivity(token)
            }
        }
    }

    /// Update activity assertions based on the latest SessionSnapshot and active tasks/progress.
    func update(from snapshot: SessionSnapshot) {
        var liveKeys: Set<String> = []

        for workspace in snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs {
                    for surfaceID in tab.rootPane.allSurfaceIDs() {
                        // 1. PTY build session or active command execution
                        let progressActive = SurfaceProgressTracker.shared.isActive(surfaceID)
                        let tabRunning = tab.status == .running
                        let hasBusyCommand = isBusyCommand(tab.currentCommand)

                        if progressActive || tabRunning || hasBusyCommand {
                            let key = "pty-build:\(surfaceID.uuidString)"
                            liveKeys.insert(key)
                            let cmdName = tab.currentCommand ?? (tab.title.isEmpty ? "Build" : tab.title)
                            beginActivity(
                                key: key,
                                surfaceID: surfaceID,
                                reason: "Kouen PTY Build Session (\(cmdName))"
                            )
                        }

                        // 2. Primary agent or subagent runs
                        if let agent = tab.agent, agent.activity == .working {
                            let key = "agent:\(surfaceID.uuidString):\(agent.pid)"
                            liveKeys.insert(key)
                            beginActivity(
                                key: key,
                                surfaceID: surfaceID,
                                reason: "Kouen Agent (\(agent.kind.displayName) PID \(agent.pid))"
                            )
                        }

                        if let subagents = tab.subagents {
                            for sub in subagents where sub.activity == .working {
                                let key = "subagent:\(surfaceID.uuidString):\(sub.pid)"
                                liveKeys.insert(key)
                                beginActivity(
                                    key: key,
                                    surfaceID: surfaceID,
                                    reason: "Kouen Subagent (\(sub.kind.displayName) PID \(sub.pid))"
                                )
                            }
                        }
                    }
                }
            }
        }

        // Reconcile and release any assertions that are no longer active
        let currentKeys = Array(assertions.keys)
        for key in currentKeys {
            if !liveKeys.contains(key) {
                endActivity(key: key)
            }
        }
    }

    /// End all active assertions (for app shutdown / reset).
    func releaseAll() {
        for token in assertions.values {
            ProcessInfo.processInfo.endActivity(token)
        }
        assertions.removeAll()
        surfaceAssertionKeys.removeAll()
    }

    /// Returns the number of currently active assertions (useful for testing).
    var activeAssertionCount: Int {
        assertions.count
    }

    /// Returns whether an assertion key is active (useful for testing).
    func isAsserted(key: String) -> Bool {
        assertions[key] != nil
    }

    // MARK: - Private Helpers

    /// True if `command` is a non-shell active command (e.g. swift, xcodebuild, make, cargo, etc.).
    private func isBusyCommand(_ command: String?) -> Bool {
        guard let command = command?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty else {
            return false
        }
        let lower = command.lowercased()
        let shells: Set<String> = ["zsh", "-zsh", "bash", "-bash", "fish", "-fish", "sh", "-sh", "csh", "tcsh"]
        if shells.contains(lower) { return false }
        for shell in shells {
            if lower.hasSuffix("/" + shell) { return false }
        }
        return true
    }
}
