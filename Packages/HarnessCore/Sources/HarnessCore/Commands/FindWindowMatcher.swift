#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

/// Matching for `find-window` (tmux `-N` name / `-T` title / `-C` content). Name and
/// title both match the tab's title in Harness (tabs have no separate pane titles);
/// `-N` additionally matches the display subtitle (cwd basename / git branch), which is
/// what the sidebar shows as the window's identity. Content matching needs a live
/// capture, so it lives with the callers that own a daemon connection — this type only
/// hosts the shared pattern + snapshot logic so every front-end agrees on what matches.
public enum FindWindowMatcher {
    /// tmux-style fnmatch. A pattern with no glob metacharacters matches as a
    /// case-insensitive substring (tmux wraps bare patterns in `*…*`).
    public static func matches(pattern: String, in text: String) -> Bool {
        let hasGlob = pattern.contains("*") || pattern.contains("?") || pattern.contains("[")
        let effective = hasGlob ? pattern : "*\(pattern)*"
        return fnmatch(effective.lowercased(), text.lowercased(), 0) == 0
    }

    public static func tabMatches(_ tab: Tab, pattern: String, name: Bool, title: Bool) -> Bool {
        if title, matches(pattern: pattern, in: tab.title) { return true }
        if name {
            if matches(pattern: pattern, in: tab.title) { return true }
            if matches(pattern: pattern, in: tab.displaySubtitle) { return true }
        }
        return false
    }

    /// First match including pane CONTENT (`find-window -C`): name/title from the
    /// snapshot, content via the caller's `capture` (each front-end owns a daemon
    /// connection; pass nil-returning capture to skip a surface). Snapshot order.
    public static func firstMatch(
        _ snapshot: SessionSnapshot,
        pattern: String,
        name: Bool,
        title: Bool,
        capture: (String) -> String?
    ) -> (workspaceID: WorkspaceID, tabID: TabID)? {
        for workspace in snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs {
                    if name || title, tabMatches(tab, pattern: pattern, name: name, title: title) {
                        return (workspace.id, tab.id)
                    }
                    for surfaceID in tab.rootPane.allSurfaceIDs() {
                        if let text = capture(surfaceID.uuidString),
                           matches(pattern: pattern, in: text) {
                            return (workspace.id, tab.id)
                        }
                    }
                }
            }
        }
        return nil
    }

    /// All tabs whose name/title matches, in snapshot order.
    public static func snapshotMatches(
        _ snapshot: SessionSnapshot,
        pattern: String,
        name: Bool,
        title: Bool
    ) -> [(workspaceID: WorkspaceID, tabID: TabID)] {
        var found: [(WorkspaceID, TabID)] = []
        for workspace in snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs where tabMatches(tab, pattern: pattern, name: name, title: title) {
                    found.append((workspace.id, tab.id))
                }
            }
        }
        return found
    }
}
