import XCTest
@testable import KouenCore
@testable import KouenDaemonCore

/// Integration tests for Agent Routing Rule IPC (M2) via SurfaceRegistry.handle() directly,
/// same pattern as AutomationIPCDaemonTests — no socket, real KOUEN_HOME sandbox.
final class AgentRoutingRuleIPCDaemonTests: XCTestCase {
    private var root: URL!
    private var previousHome: String?

    override func setUpWithError() throws {
        previousHome = getenv("KOUEN_HOME").map { String(cString: $0) }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kouen-routing-rule-daemon-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        root = dir
        setenv("KOUEN_HOME", dir.path, 1)
        try KouenPaths.ensureDirectories()
    }

    override func tearDownWithError() throws {
        if let previousHome { setenv("KOUEN_HOME", previousHome, 1) } else { unsetenv("KOUEN_HOME") }
        try? FileManager.default.removeItem(at: root)
    }

    func testCreateListGetUpdateDeleteRoundTripViaIPC() throws {
        let registry = SurfaceRegistry()

        guard case let .routingRuleInfo(created?) = registry.handle(.routingRuleCreate(
            kind: "path", pattern: "~/Git/Company/**", targetAgent: "codex", enabled: true
        )) else {
            return XCTFail("Expected .routingRuleInfo from routingRuleCreate")
        }
        XCTAssertEqual(created.pattern, "~/Git/Company/**")
        XCTAssertTrue(created.enabled)

        guard case let .routingRules(list) = registry.handle(.routingRuleList) else {
            return XCTFail("Expected .routingRules from routingRuleList")
        }
        XCTAssertEqual(list.count, 1)

        guard case let .routingRuleInfo(fetched?) = registry.handle(.routingRuleGet(id: created.id)) else {
            return XCTFail("Expected .routingRuleInfo from routingRuleGet")
        }
        XCTAssertEqual(fetched.id, created.id)

        guard case let .routingRuleInfo(updated?) = registry.handle(.routingRuleUpdate(
            id: created.id, kind: nil, pattern: "~/Git/Personal/**", targetAgent: nil, enabled: nil
        )) else {
            return XCTFail("Expected .routingRuleInfo from routingRuleUpdate")
        }
        XCTAssertEqual(updated.pattern, "~/Git/Personal/**")

        guard case .ok = registry.handle(.routingRuleDelete(id: created.id)) else {
            return XCTFail("Expected .ok from routingRuleDelete")
        }
        guard case let .routingRuleInfo(gone) = registry.handle(.routingRuleGet(id: created.id)) else {
            return XCTFail("Expected .routingRuleInfo from routingRuleGet after delete")
        }
        XCTAssertNil(gone)
    }

    func testCreateRejectsUnknownKindOrAgent() {
        let registry = SurfaceRegistry()
        guard case .error = registry.handle(.routingRuleCreate(
            kind: "bogus", pattern: "x", targetAgent: "codex", enabled: true
        )) else {
            return XCTFail("Expected .error for unknown kind")
        }
        guard case .error = registry.handle(.routingRuleCreate(
            kind: "path", pattern: "x", targetAgent: "bogus-agent", enabled: true
        )) else {
            return XCTFail("Expected .error for unknown agent")
        }
    }

    func testUpdateAndDeleteOnMissingIDReturnsError() {
        let registry = SurfaceRegistry()
        guard case .error = registry.handle(.routingRuleUpdate(
            id: UUID(), kind: nil, pattern: "nope", targetAgent: nil, enabled: nil
        )) else {
            return XCTFail("Expected .error from routingRuleUpdate on missing id")
        }
        guard case .error = registry.handle(.routingRuleDelete(id: UUID())) else {
            return XCTFail("Expected .error from routingRuleDelete on missing id")
        }
    }

    func testReorderRoundTripViaIPC() {
        let registry = SurfaceRegistry()
        guard case let .routingRuleInfo(a?) = registry.handle(.routingRuleCreate(
            kind: "path", pattern: "a", targetAgent: "codex", enabled: true
        )) else { return XCTFail("Expected .routingRuleInfo") }
        guard case let .routingRuleInfo(b?) = registry.handle(.routingRuleCreate(
            kind: "path", pattern: "b", targetAgent: "codex", enabled: true
        )) else { return XCTFail("Expected .routingRuleInfo") }

        guard case let .routingRules(reordered) = registry.handle(
            .routingRuleReorder(kind: "path", orderedIDs: [b.id, a.id])
        ) else {
            return XCTFail("Expected .routingRules from routingRuleReorder")
        }
        XCTAssertEqual(reordered.map(\.id), [b.id, a.id])
    }
}
