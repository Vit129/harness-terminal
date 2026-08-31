import XCTest
@testable import KouenCore
@testable import KouenDaemonCore

/// Integration tests for Task IPC (P40 F1) via SurfaceRegistry.handle() directly,
/// same pattern as WorktreeIsolationDaemonTests — no socket, real KOUEN_HOME sandbox.
final class TaskIPCDaemonTests: XCTestCase {
    private var root: URL!
    private var previousHome: String?

    override func setUpWithError() throws {
        previousHome = getenv("KOUEN_HOME").map { String(cString: $0) }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kouen-task-daemon-\(UUID().uuidString)", isDirectory: true)
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
        let sessionID = UUID()

        guard case let .taskInfo(created?) = registry.handle(.taskCreate(sessionID: sessionID, title: "write tests")) else {
            return XCTFail("Expected .taskInfo from taskCreate")
        }
        XCTAssertEqual(created.title, "write tests")
        XCTAssertFalse(created.done)

        guard case let .tasks(list) = registry.handle(.taskList(sessionID: sessionID)) else {
            return XCTFail("Expected .tasks from taskList")
        }
        XCTAssertEqual(list.count, 1)

        guard case let .taskInfo(fetched?) = registry.handle(.taskGet(id: created.id)) else {
            return XCTFail("Expected .taskInfo from taskGet")
        }
        XCTAssertEqual(fetched.id, created.id)

        // P44a: marking done no longer deletes the Task — it stays listed/gettable until
        // an explicit taskDelete.
        guard case let .taskInfo(updated?) = registry.handle(
            .taskUpdate(id: created.id, title: nil, done: true, status: nil)
        ) else {
            return XCTFail("Expected .taskInfo from taskUpdate")
        }
        XCTAssertTrue(updated.done)
        XCTAssertEqual(updated.status, .done)

        guard case let .taskInfo(stillThere) = registry.handle(.taskGet(id: created.id)) else {
            return XCTFail("Expected .taskInfo from taskGet after marking done")
        }
        XCTAssertNotNil(stillThere)

        guard case .ok = registry.handle(.taskDelete(id: created.id)) else {
            return XCTFail("Expected .ok from explicit taskDelete")
        }
        guard case let .taskInfo(gone) = registry.handle(.taskGet(id: created.id)) else {
            return XCTFail("Expected .taskInfo from taskGet after explicit delete")
        }
        XCTAssertNil(gone)
    }

    func testTaskListNilSessionIDReturnsAcrossSessions() {
        let registry = SurfaceRegistry()
        _ = registry.handle(.taskCreate(sessionID: UUID(), title: "a"))
        _ = registry.handle(.taskCreate(sessionID: UUID(), title: "b"))

        guard case let .tasks(all) = registry.handle(.taskList(sessionID: nil)) else {
            return XCTFail("Expected .tasks from taskList(sessionID: nil)")
        }
        XCTAssertEqual(all.count, 2)
    }

    func testUpdateAndDeleteOnMissingIDReturnsError() {
        let registry = SurfaceRegistry()
        guard case .error = registry.handle(.taskUpdate(id: UUID(), title: "nope", done: nil, status: nil)) else {
            return XCTFail("Expected .error from taskUpdate on missing id")
        }
        guard case .error = registry.handle(.taskDelete(id: UUID())) else {
            return XCTFail("Expected .error from taskDelete on missing id")
        }
    }

    func testTaskCreateCapturesTheOwningSessionsCwd() throws {
        // Real regression target: taskCreate's session -> active-tab cwd lookup, added so a
        // Kouen Task Sync workflow can tell which project a task came from even after its
        // owning session closes (see ~/.claude/rules/routing.md's "Kouen Task Sync").
        let registry = SurfaceRegistry()
        let wsID = registry.snapshot.activeWorkspaceID!
        // "/tmp" (not a made-up subpath) to match how every other daemon test in this file
        // requests a session cwd — a nonexistent directory gets silently resolved elsewhere
        // by newSession, which isn't this test's concern.
        guard case let .sessionID(sessionID) = registry.handle(.newSession(workspaceID: wsID, cwd: "/tmp", name: "p40-f1")) else {
            return XCTFail("expected sessionID")
        }

        guard case let .taskInfo(created?) = registry.handle(.taskCreate(sessionID: sessionID, title: "fix the bridge")) else {
            return XCTFail("Expected .taskInfo from taskCreate")
        }
        XCTAssertEqual(created.cwd, "/tmp")
    }

    func testTaskCreateWithUnknownSessionLeavesCwdNil() {
        // A sessionID that doesn't match any live session (e.g. a stale/forged one) must not
        // crash the lookup — it should just come back with no cwd guess, same as before this
        // field existed.
        let registry = SurfaceRegistry()
        guard case let .taskInfo(created?) = registry.handle(.taskCreate(sessionID: UUID(), title: "orphaned")) else {
            return XCTFail("Expected .taskInfo from taskCreate")
        }
        XCTAssertNil(created.cwd)
    }
}
