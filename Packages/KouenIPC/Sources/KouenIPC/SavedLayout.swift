import Foundation

/// The shape of a pane tree — split directions/ratios and leaf positions only, no
/// `PaneID`/`SurfaceID`/`daemonSurfaceID` runtime identity. A `PaneNode` (real, running
/// panes) reduces to this via `PaneNode.paneLayoutShape`; applying a shape creates fresh
/// empty-shell leaves, never restores specific processes — that's daemon session-restore's
/// job, a different, pre-existing feature this one is NOT replacing.
///
/// Named `SavedLayout`/`PaneLayoutShape`, not `LayoutTemplate` — that name is already taken
/// by the pre-existing tmux-style built-in algorithmic layouts (`even-horizontal`,
/// `main-vertical`, `tiled`, ... see `KouenCore/Layouts/LayoutTemplate.swift`,
/// `SessionEditor.applyLayout(tabID:layout:)`). Different concept entirely (this is a
/// human-named, human-saved custom arrangement; that's a small fixed algorithmic set) —
/// caught before it collided, not a rename of the existing type.
public indirect enum PaneLayoutShape: Codable, Sendable, Equatable {
    case leaf
    case branch(direction: SplitDirection, ratio: Double, first: PaneLayoutShape, second: PaneLayoutShape)
}

extension PaneNode {
    /// Browser leaves collapse to a plain `.leaf` too — a saved layout only remembers
    /// terminal-shell positions; applying it never recreates a browser pane (no URL is
    /// captured). Documented v1 cut, not an oversight.
    public var paneLayoutShape: PaneLayoutShape {
        switch self {
        case .leaf, .browser:
            return .leaf
        case let .branch(direction, ratio, first, second):
            return .branch(direction: direction, ratio: ratio, first: first.paneLayoutShape, second: second.paneLayoutShape)
        }
    }
}

public struct SavedLayout: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var shape: PaneLayoutShape
    public let createdAt: Date

    public init(id: UUID = UUID(), name: String, shape: PaneLayoutShape, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.shape = shape
        self.createdAt = createdAt
    }
}
