import XCTest
@testable import KouenCore

final class AgentRoutingResolverTests: XCTestCase {
    func testPathRuleWinsOverStackRule() {
        let rules = [
            AgentRoutingRule(order: 0, kind: .path, pattern: "/repo/**", targetAgent: .codex),
            AgentRoutingRule(order: 0, kind: .stack, pattern: "swift", targetAgent: .gemini),
        ]
        // Path rules are phase 1, stack rules are phase 2 fallback only — phase 2 (and its
        // real filesystem stack-detection) is never reached once phase 1 matches.
        let resolved = AgentRoutingResolver.resolve(cwd: "/repo/sub", rules: rules, defaultAgent: .kiro)
        XCTAssertEqual(resolved, .codex)
    }

    func testDisabledRuleIsSkipped() {
        var rule = AgentRoutingRule(order: 0, kind: .path, pattern: "/repo/**", targetAgent: .codex)
        rule.enabled = false
        let resolved = AgentRoutingResolver.resolve(cwd: "/repo/sub", rules: [rule], defaultAgent: .kiro)
        XCTAssertEqual(resolved, .kiro)
    }

    func testNoMatchFallsToDefault() {
        let rules = [AgentRoutingRule(order: 0, kind: .path, pattern: "/other/**", targetAgent: .codex)]
        let resolved = AgentRoutingResolver.resolve(cwd: "/repo/sub", rules: rules, defaultAgent: .kiro)
        XCTAssertEqual(resolved, .kiro)
    }

    func testNilCwdFallsToDefault() {
        let rules = [AgentRoutingRule(order: 0, kind: .path, pattern: "/repo/**", targetAgent: .codex)]
        let resolved = AgentRoutingResolver.resolve(cwd: nil, rules: rules, defaultAgent: .kiro)
        XCTAssertEqual(resolved, .kiro)
    }

    func testGlobPatternMatching() {
        let rules = [AgentRoutingRule(order: 0, kind: .path, pattern: "/Git/Company/**", targetAgent: .codex)]
        XCTAssertEqual(AgentRoutingResolver.resolve(cwd: "/Git/Company/repo-a", rules: rules, defaultAgent: .kiro), .codex)
        XCTAssertEqual(AgentRoutingResolver.resolve(cwd: "/Git/Personal/repo-b", rules: rules, defaultAgent: .kiro), .kiro)
    }

    func testFirstMatchWinsWithinPathPhaseByOrder() {
        let rules = [
            AgentRoutingRule(order: 1, kind: .path, pattern: "/repo/**", targetAgent: .gemini),
            AgentRoutingRule(order: 0, kind: .path, pattern: "/repo/**", targetAgent: .codex),
        ]
        let resolved = AgentRoutingResolver.resolve(cwd: "/repo/sub", rules: rules, defaultAgent: .kiro)
        XCTAssertEqual(resolved, .codex, "lower order must win even if listed later in the array")
    }

    func testStackRuleMatchesDetectedStack() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kouen-resolver-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "".write(to: dir.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let rules = [AgentRoutingRule(order: 0, kind: .stack, pattern: "swift", targetAgent: .claudeCode)]
        let resolved = AgentRoutingResolver.resolve(cwd: dir.path, rules: rules, defaultAgent: .kiro)
        XCTAssertEqual(resolved, .claudeCode)
    }

    func testUnknownStackFallsThroughToDefault() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kouen-resolver-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        // No recognizable signal file — SignalFileRouter.detectProfile returns nil.

        let rules = [AgentRoutingRule(order: 0, kind: .stack, pattern: "swift", targetAgent: .claudeCode)]
        let resolved = AgentRoutingResolver.resolve(cwd: dir.path, rules: rules, defaultAgent: .kiro)
        XCTAssertEqual(resolved, .kiro)
    }
}
