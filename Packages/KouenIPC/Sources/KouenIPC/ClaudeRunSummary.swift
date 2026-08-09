import Foundation

/// The wire shape for a Claude Code Harness run (`ccRun*` MCP tools). Mirrors
/// `KouenDaemon`'s `ClaudeCodeHarness.RunSummary` — kept as a separate type for the same
/// reason `TaskSummary` is: `KouenIPC` cannot import `KouenDaemon`.
public struct ClaudeRunSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let state: String
    public let cwd: String
    public let startedAt: Date
    public let lastAssistantText: String?
    public let resultText: String?
    public let totalCostUSD: Double?
    public let exitCode: Int32?

    public init(
        id: UUID, state: String, cwd: String, startedAt: Date,
        lastAssistantText: String? = nil, resultText: String? = nil,
        totalCostUSD: Double? = nil, exitCode: Int32? = nil
    ) {
        self.id = id
        self.state = state
        self.cwd = cwd
        self.startedAt = startedAt
        self.lastAssistantText = lastAssistantText
        self.resultText = resultText
        self.totalCostUSD = totalCostUSD
        self.exitCode = exitCode
    }
}
