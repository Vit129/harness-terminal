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
        // Name and title both match the tab's title; name additionally matches the
        // display subtitle (cwd basename / git branch).
        if name || title, matches(pattern: pattern, in: tab.title) { return true }
        if name, matches(pattern: pattern, in: tab.displaySubtitle) { return true }
        return false
    }

    /// First match including pane CONTENT (`find-window -C`): name/title from the
    /// snapshot, content via the caller's `capture` (each front-end owns a daemon
    /// connection; pass nil-returning capture to skip a surface). Snapshot order.
    ///
    /// `target` is the optional `-t` scope (a session): when present, only that session's
    /// windows are searched. A `-t` that names a missing session scopes to nothing, so the
    /// search finds no match and the caller fails loudly — never a silent widen to a global
    /// search (the release's no-silent-misroute invariant). `current` resolves relative/empty
    /// session refs.
    public static func firstMatch(
        _ snapshot: SessionSnapshot,
        pattern: String,
        name: Bool,
        title: Bool,
        target: String? = nil,
        current: SessionGroup? = nil,
        capture: (String) -> String?
    ) -> (workspaceID: WorkspaceID, tabID: TabID)? {
        let scope = matchScope(target, in: snapshot, current: current)
        for workspace in snapshot.workspaces {
            for session in workspace.sessions where scope.includes(session.id) {
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

    /// All tabs whose name/title matches, in snapshot order. `target`/`current` scope the
    /// search exactly as in `firstMatch`.
    public static func snapshotMatches(
        _ snapshot: SessionSnapshot,
        pattern: String,
        name: Bool,
        title: Bool,
        target: String? = nil,
        current: SessionGroup? = nil
    ) -> [(workspaceID: WorkspaceID, tabID: TabID)] {
        let scope = matchScope(target, in: snapshot, current: current)
        var found: [(WorkspaceID, TabID)] = []
        for workspace in snapshot.workspaces {
            for session in workspace.sessions where scope.includes(session.id) {
                for tab in session.tabs where tabMatches(tab, pattern: pattern, name: name, title: title) {
                    found.append((workspace.id, tab.id))
                }
            }
        }
        return found
    }

    /// Which sessions a find-window `-t` value scopes the search to.
    enum SearchScope: Equatable {
        case all                 // no `-t` — every session
        case only(SessionID)     // `-t` resolved to this session
        case none                // `-t` named a session that doesn't exist — match nothing

        func includes(_ id: SessionID) -> Bool {
            switch self {
            case .all: return true
            case let .only(scoped): return scoped == id
            case .none: return false
            }
        }
    }

    /// Resolve the optional `-t` value to a search scope. Empty/absent → `.all`; a `-t` with no
    /// session component (e.g. a bare window index) → the current session; a named-but-missing
    /// session → `.none` (so the search yields no match and the caller fails loudly).
    static func matchScope(
        _ target: String?,
        in snapshot: SessionSnapshot,
        current: SessionGroup?
    ) -> SearchScope {
        guard let target, !target.trimmingCharacters(in: .whitespaces).isEmpty else { return .all }
        let spec = TargetSpec.parse(target)
        guard let sref = spec.session else {
            return current.map { SearchScope.only($0.id) } ?? .all
        }
        guard let (_, session) = CommandTarget.findSession(sref, in: snapshot, current: current) else {
            return .none
        }
        return .only(session.id)
    }
}
