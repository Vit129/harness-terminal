import XCTest
import KouenCore
@testable import KouenApp

/// M4: `MenuTarget.forkCommand(for:)` maps an `AgentKind` to its CLI-native fork command
/// (verified against each CLI's own `--help`, see MainMenuBuilder.swift). Only the pure
/// mapping is testable here — the actual split+type happens via
/// `SessionCoordinator.splitActivePaneAndRun`, which needs a live daemon.
@MainActor
final class MenuTargetForkConversationTests: XCTestCase {
    func testClaudeCodeForkCommand() {
        XCTAssertEqual(MenuTarget.forkCommand(for: .claudeCode), "claude --continue --fork-session")
    }

    func testCodexForkCommand() {
        XCTAssertEqual(MenuTarget.forkCommand(for: .codex), "codex fork --last")
    }

    func testUnsupportedAgentsReturnNil() {
        for kind: AgentKind in [.gemini, .kiro, .cursor, .grok, .pi, .hermes, .openClaw, .openCode, .aider, .goose, .antigravity, .generic] {
            XCTAssertNil(MenuTarget.forkCommand(for: kind), "\(kind) has no verified CLI fork mechanism — must stay nil, not a silent fake fork")
        }
    }
}
