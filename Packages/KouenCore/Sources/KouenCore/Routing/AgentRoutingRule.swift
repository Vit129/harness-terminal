import Foundation
import KouenIPC

/// An ordered rule resolving `agent: "auto"` to a concrete `AgentKind` at spawn time
/// (`kouenSpawnAgent`, Automation fire). Never consulted mid-session. Two independently
/// ordered kinds — a repo-path glob (checked first, across all path rules) and a
/// `SignalFileRouter`-detected stack name (checked only if no path rule matched).
public struct AgentRoutingRule: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case path
        case stack
    }

    public let id: UUID
    /// Priority within this rule's own `kind` group, ascending. Path and stack orderings
    /// are independent — reordering path rules never affects stack rule order.
    public var order: Int
    public var kind: Kind
    /// Glob pattern (kind == .path, e.g. "~/Git/Company/**") or stack name (kind == .stack,
    /// e.g. "swift", matching `SignalFileRouter.DetectedProfile.stack`).
    public var pattern: String
    public var targetAgent: AgentKind
    public var enabled: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(), order: Int, kind: Kind, pattern: String, targetAgent: AgentKind,
        enabled: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()
    ) {
        self.id = id
        self.order = order
        self.kind = kind
        self.pattern = pattern
        self.targetAgent = targetAgent
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
