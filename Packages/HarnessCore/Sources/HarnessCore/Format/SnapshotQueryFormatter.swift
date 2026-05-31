import Foundation

/// Machine-readable rows behind `harness-cli list-sessions/list-windows/list-panes --json`.
/// The text form is derived from these (`SnapshotQueryFormatter`), so the JSON and the
/// tmux-style text never drift: one traversal produces the row, text is just its rendering.
public struct SessionListRow: Codable, Sendable, Equatable {
    public var id: UUID
    /// Resolved display name (never empty — falls back to the active tab's title).
    public var name: String
    public var windowCount: Int
}

public struct WindowListRow: Codable, Sendable, Equatable {
    public var index: Int
    public var title: String
}

public struct PaneListRow: Codable, Sendable, Equatable {
    public var index: Int
    public var paneID: UUID
    public var surfaceID: UUID
    public var active: Bool
}

/// Formats `SessionSnapshot` queries (sessions / windows / panes) into tmux-style text lines and
/// the parallel `--json` rows. Shared by `harness-cli`'s `list-sessions`/`list-windows`/
/// `list-panes` subcommands and the control-mode client, so the two never drift in what they
/// report. Text is rendered from the row structs (`*Rows`) so the JSON and text stay in lockstep.
public enum SnapshotQueryFormatter {
    // MARK: - Rows (the --json contract; text is derived from these)

    /// tmux `list-sessions`: one row per sidebar session, with its window (tab) count.
    public static func sessionRows(_ snapshot: SessionSnapshot) -> [SessionListRow] {
        snapshot.workspaces.flatMap(\.sessions).map { session in
            SessionListRow(id: session.id, name: displayName(session), windowCount: session.tabs.count)
        }
    }

    /// tmux `list-windows`: every tab across all sessions, index-prefixed (flat enumeration,
    /// matching the control-mode behavior).
    public static func windowRows(_ snapshot: SessionSnapshot) -> [WindowListRow] {
        snapshot.workspaces.flatMap(\.sessions).flatMap(\.tabs)
            .enumerated().map { WindowListRow(index: $0.offset, title: $0.element.title) }
    }

    /// One session's tabs, index-prefixed within that session.
    public static func windowRows(in session: SessionGroup) -> [WindowListRow] {
        session.tabs.enumerated().map { WindowListRow(index: $0.offset, title: $0.element.title) }
    }

    /// tmux `list-panes`: one row per pane in `tab`, index-prefixed in the same order as
    /// `display-panes`/`select-pane`, flagging the active pane.
    public static func paneRows(in tab: Tab) -> [PaneListRow] {
        tab.rootPane.allLeaves().enumerated().map { index, leaf in
            PaneListRow(index: index, paneID: leaf.id, surfaceID: leaf.surfaceID,
                        active: leaf.id == tab.activePaneID)
        }
    }

    // MARK: - Text (rendered from the rows above — keep byte-identical)

    public static func sessions(_ snapshot: SessionSnapshot) -> [String] {
        sessionRows(snapshot).map(line)
    }

    public static func windows(_ snapshot: SessionSnapshot) -> [String] {
        windowRows(snapshot).map(line)
    }

    public static func windows(in session: SessionGroup) -> [String] {
        windowRows(in: session).map(line)
    }

    public static func panes(in tab: Tab) -> [String] {
        paneRows(in: tab).map(line)
    }

    private static func line(_ row: SessionListRow) -> String {
        "\(row.id.uuidString): \(row.name) (\(row.windowCount) windows)"
    }

    private static func line(_ row: WindowListRow) -> String {
        "\(row.index): \(row.title)"
    }

    private static func line(_ row: PaneListRow) -> String {
        let active = row.active ? " (active)" : ""
        return "\(row.index): pane \(row.paneID.uuidString) surface \(row.surfaceID.uuidString)\(active)"
    }

    // MARK: - Queries

    /// Whether a session with this name or UUID exists (`has-session`).
    public static func sessionExists(_ snapshot: SessionSnapshot, nameOrID: String) -> Bool {
        let lowered = nameOrID.lowercased()
        return snapshot.workspaces.flatMap(\.sessions).contains { session in
            session.id.uuidString.lowercased() == lowered || session.name == nameOrID
        }
    }

    /// A non-empty display name for a session (sessions can be unnamed; fall back to the active
    /// tab's title so the line is never blank).
    private static func displayName(_ session: SessionGroup) -> String {
        if !session.name.isEmpty { return session.name }
        return session.activeTab?.title ?? "session"
    }
}
