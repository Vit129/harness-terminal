import Foundation
import XCTest
@testable import KouenApp
import KouenCore
import KouenIPC

@MainActor
final class ActivityAssertionManagerTests: XCTestCase {
    private var manager: ActivityAssertionManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = ActivityAssertionManager()
    }

    override func tearDown() async throws {
        manager.releaseAll()
        manager = nil
        try await super.tearDown()
    }

    func testBeginAndEndActivity() {
        let key = "test-activity-1"
        XCTAssertFalse(manager.isAsserted(key: key))
        XCTAssertEqual(manager.activeAssertionCount, 0)

        manager.beginActivity(key: key, reason: "Testing activity assertion")
        XCTAssertTrue(manager.isAsserted(key: key))
        XCTAssertEqual(manager.activeAssertionCount, 1)

        // Duplicate beginActivity should be ignored (idempotent)
        manager.beginActivity(key: key, reason: "Testing activity assertion again")
        XCTAssertEqual(manager.activeAssertionCount, 1)

        manager.endActivity(key: key)
        XCTAssertFalse(manager.isAsserted(key: key))
        XCTAssertEqual(manager.activeAssertionCount, 0)
    }

    func testReleaseAssertionsForSurface() {
        let surfaceID = SurfaceID()
        let ptyKey = "pty-build:\(surfaceID.uuidString)"
        let agentKey = "agent:\(surfaceID.uuidString):1234"

        manager.beginActivity(key: ptyKey, surfaceID: surfaceID, reason: "Build")
        manager.beginActivity(key: agentKey, surfaceID: surfaceID, reason: "Agent")

        XCTAssertTrue(manager.isAsserted(key: ptyKey))
        XCTAssertTrue(manager.isAsserted(key: agentKey))

        // Simulating pane death / retire hook
        manager.releaseAssertions(forSurface: surfaceID)

        XCTAssertFalse(manager.isAsserted(key: ptyKey))
        XCTAssertFalse(manager.isAsserted(key: agentKey))
    }

    func testUpdateFromSnapshotReconcilesActiveAndFinished() {
        let surfaceID = SurfaceID()
        let leaf = PaneLeaf(surfaceID: surfaceID)
        let tab = Tab(
            id: UUID(),
            title: "Build Tab",
            cwd: "/tmp",
            status: .running,
            rootPane: .leaf(leaf),
            agent: AgentSnapshot(kind: .claudeCode, executable: "claude", pid: 999, activity: .working),
            currentCommand: "swift build"
        )
        let session = SessionGroup(id: UUID(), name: "Build Session", tabs: [tab])
        let workspace = Workspace(id: UUID(), name: "Dev Workspace", sessions: [session])
        let snapshot = SessionSnapshot(workspaces: [workspace], activeWorkspaceID: workspace.id)

        manager.update(from: snapshot)

        let ptyKey = "pty-build:\(surfaceID.uuidString)"
        let agentKey = "agent:\(surfaceID.uuidString):999"

        XCTAssertTrue(manager.isAsserted(key: ptyKey))
        XCTAssertTrue(manager.isAsserted(key: agentKey))

        // Idle snapshot (finished build and agent)
        let idleTab = Tab(
            id: tab.id,
            title: "Build Tab",
            cwd: "/tmp",
            status: .idle,
            rootPane: .leaf(leaf),
            agent: AgentSnapshot(kind: .claudeCode, executable: "claude", pid: 999, activity: .idle)
        )
        let idleSession = SessionGroup(id: session.id, name: "Build Session", tabs: [idleTab])
        let idleWorkspace = Workspace(id: workspace.id, name: "Dev Workspace", sessions: [idleSession])
        let idleSnapshot = SessionSnapshot(workspaces: [idleWorkspace], activeWorkspaceID: workspace.id)

        manager.update(from: idleSnapshot)

        XCTAssertFalse(manager.isAsserted(key: ptyKey), "PTY build assertion should be released when tab becomes idle")
        XCTAssertFalse(manager.isAsserted(key: agentKey), "Agent assertion should be released when agent becomes idle")
    }

    func testSubagentActivityAssertions() {
        let surfaceID = SurfaceID()
        let leaf = PaneLeaf(surfaceID: surfaceID)
        let subagent = AgentSnapshot(kind: .claudeCode, executable: "claude", pid: 888, activity: .working)
        let tab = Tab(
            id: UUID(),
            title: "Agent Tab",
            cwd: "/tmp",
            status: .idle,
            rootPane: .leaf(leaf),
            subagents: [subagent]
        )
        let session = SessionGroup(id: UUID(), name: "Agent Session", tabs: [tab])
        let workspace = Workspace(id: UUID(), name: "Dev Workspace", sessions: [session])
        let snapshot = SessionSnapshot(workspaces: [workspace], activeWorkspaceID: workspace.id)

        manager.update(from: snapshot)

        let subagentKey = "subagent:\(surfaceID.uuidString):888"
        XCTAssertTrue(manager.isAsserted(key: subagentKey), "Working subagent must trigger activity assertion")

        manager.releaseAssertions(forSurface: surfaceID)
        XCTAssertFalse(manager.isAsserted(key: subagentKey), "Pane teardown must release subagent activity assertion")
    }
}
