import XCTest
@testable import KouenDaemonCore

/// Stream-json line parsing against real captured `claude -p --output-format stream-json`
/// output (see agent-memory/plans/claude-code-harness/design.md) — no process spawning,
/// so this runs fast and deterministically in CI.
final class ClaudeCodeHarnessTests: XCTestCase {
    private func emptySummary() -> ClaudeCodeHarness.RunSummary {
        ClaudeCodeHarness.RunSummary(id: UUID(), state: .running, cwd: "/tmp", startedAt: Date())
    }

    func testParsesAssistantLine() async {
        let harness = ClaudeCodeHarness()
        var summary = emptySummary()
        let line = """
        {"type":"assistant","message":{"model":"claude-sonnet-5","id":"msg_1","type":"message","role":"assistant","content":[{"type":"text","text":"Yo."}]}}
        """
        await harness.parseLine(Data(line.utf8), into: &summary)
        XCTAssertEqual(summary.lastAssistantText, "Yo.")
        XCTAssertEqual(summary.state, .running, "an assistant line alone doesn't end the run")
    }

    func testParsesSuccessfulResultLine() async {
        let harness = ClaudeCodeHarness()
        var summary = emptySummary()
        let line = """
        {"is_error":false,"result":"Yo.","total_cost_usd":0.261165,"type":"result","session_id":"abc"}
        """
        await harness.parseLine(Data(line.utf8), into: &summary)
        XCTAssertEqual(summary.state, .succeeded)
        XCTAssertEqual(summary.resultText, "Yo.")
        XCTAssertEqual(summary.totalCostUSD, 0.261165)
    }

    func testParsesFailedResultLine() async {
        let harness = ClaudeCodeHarness()
        var summary = emptySummary()
        let line = """
        {"is_error":true,"result":"Not logged in \\u00b7 Please run /login","total_cost_usd":0,"type":"result"}
        """
        await harness.parseLine(Data(line.utf8), into: &summary)
        XCTAssertEqual(summary.state, .failed)
    }

    func testMalformedLineIsIgnoredNotCrashing() async {
        let harness = ClaudeCodeHarness()
        var summary = emptySummary()
        await harness.parseLine(Data("not json at all".utf8), into: &summary)
        XCTAssertEqual(summary.state, .running, "unparseable lines leave state untouched")
    }

    func testCancelUnknownRunReturnsFalse() async {
        let harness = ClaudeCodeHarness()
        let cancelled = await harness.cancel(id: UUID())
        XCTAssertFalse(cancelled)
    }

    func testListEmptyInitially() async {
        let harness = ClaudeCodeHarness()
        let list = await harness.list()
        XCTAssertTrue(list.isEmpty)
    }
}
