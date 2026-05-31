import Foundation

/// Renders `[AgentSessionSummary]` into the `harness-cli list-agents` text output —
/// tab-separated lines. Lives in HarnessCore (not the CLI) so the formatting is
/// unit-testable, mirroring `SnapshotQueryFormatter`. JSON output goes through the shared
/// `JSONOutputFormatter` (encoding `AgentSessionSummary` directly), so there's one encoder.
public enum AgentListFormatter {
    /// One tab-separated line per agent:
    /// `surfaceID \t workspace/session/tab \t agentName \t state \t age`.
    /// `state` is `waiting` when the agent is blocking on you, otherwise the raw
    /// `activity` (idle/working/awaiting/errored). `age` is a compact relative
    /// string from `lastActivityAt`. `now` is injectable for deterministic tests.
    public static func text(_ agents: [AgentSessionSummary], now: Date = .now) -> [String] {
        agents.map { agent in
            let location = "\(agent.workspaceName)/\(displaySession(agent))/\(displayTab(agent))"
            let state = agent.waiting ? "waiting" : agent.activity.rawValue
            let age = self.age(from: agent.lastActivityAt, to: now)
            return "\(agent.surfaceID)\t\(location)\t\(agent.agentName)\t\(state)\t\(age)"
        }
    }

    private static func displaySession(_ agent: AgentSessionSummary) -> String {
        agent.sessionName.isEmpty ? "-" : agent.sessionName
    }

    private static func displayTab(_ agent: AgentSessionSummary) -> String {
        agent.tabTitle.isEmpty ? "-" : agent.tabTitle
    }

    /// Compact relative age: `5s`, `3m`, `2h`, `4d`. Clamps negatives (clock skew)
    /// to `0s`. Public so the GUI Agent Inbox renders ages identically.
    public static func age(from then: Date, to now: Date = .now) -> String {
        let seconds = Int(now.timeIntervalSince(then))
        if seconds < 0 { return "0s" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}
