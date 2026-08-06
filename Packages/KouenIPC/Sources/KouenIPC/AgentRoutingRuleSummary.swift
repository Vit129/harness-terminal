import Foundation

/// The wire shape for an Agent Routing Rule (M2: `kouenRoutingRule*` MCP tools). Mirrors
/// `KouenCore`'s `AgentRoutingRule`, same separation `AutomationSummary` uses for
/// `KouenAutomation`. `kind` is `"path"` or `"stack"`; `pattern` is the glob (path) or
/// `SignalFileRouter`-detected stack name (stack).
public struct AgentRoutingRuleSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let order: Int
    public let kind: String
    public let pattern: String
    public let targetAgent: String
    public let enabled: Bool

    public init(id: UUID, order: Int, kind: String, pattern: String, targetAgent: String, enabled: Bool) {
        self.id = id
        self.order = order
        self.kind = kind
        self.pattern = pattern
        self.targetAgent = targetAgent
        self.enabled = enabled
    }
}
