import XCTest
import KouenCore
import KouenIPC
import KouenCommands
@testable import KouenApp

final class GitPanelViewWorktreeTaskTests: XCTestCase {
    func testSessionIDMatchesByExactCwd() {
        let tab = Tab(cwd: "/repo/feature")
        let session = SessionGroup(tabs: [tab])
        let workspace = Workspace(sessions: [session])
        let result = GitPanelView.sessionID(forWorktreePath: "/repo/feature", workspaces: [workspace])
        XCTAssertEqual(result, session.id)
    }

    func testSessionIDMatchesByWorktreePath() {
        var tab = Tab(cwd: "/repo/feature/subdir")
        tab.worktreePath = "/repo/feature"
        let session = SessionGroup(tabs: [tab])
        let workspace = Workspace(sessions: [session])
        let result = GitPanelView.sessionID(forWorktreePath: "/repo/feature", workspaces: [workspace])
        XCTAssertEqual(result, session.id)
    }

    func testSessionIDNoMatchReturnsNil() {
        let tab = Tab(cwd: "/repo/other")
        let session = SessionGroup(tabs: [tab])
        let workspace = Workspace(sessions: [session])
        let result = GitPanelView.sessionID(forWorktreePath: "/repo/feature", workspaces: [workspace])
        XCTAssertNil(result)
    }

    func testOpenTaskPicksFirstNonDoneTask() {
        let doneTask = TaskSummary(
            id: UUID(), sessionID: UUID(), title: "Setup repo", done: true, status: .done,
            createdAt: Date(), updatedAt: Date(), cwd: "/repo"
        )
        let runningTask = TaskSummary(
            id: UUID(), sessionID: UUID(), title: "Implement feature", done: false, status: .running,
            createdAt: Date(), updatedAt: Date(), cwd: "/repo"
        )
        let openTask = TaskSummary(
            id: UUID(), sessionID: UUID(), title: "Write tests", done: false, status: .open,
            createdAt: Date(), updatedAt: Date(), cwd: "/repo"
        )

        let result = GitPanelView.openTask(from: [doneTask, runningTask, openTask])
        XCTAssertEqual(result?.id, runningTask.id)
        XCTAssertEqual(result?.title, "Implement feature")
        XCTAssertEqual(result?.status, .running)
    }

    func testOpenTaskReturnsNilWhenAllDone() {
        let doneTask1 = TaskSummary(
            id: UUID(), sessionID: UUID(), title: "Task 1", done: true, status: .done,
            createdAt: Date(), updatedAt: Date()
        )
        let doneTask2 = TaskSummary(
            id: UUID(), sessionID: UUID(), title: "Task 2", done: true, status: .done,
            createdAt: Date(), updatedAt: Date()
        )
        XCTAssertNil(GitPanelView.openTask(from: [doneTask1, doneTask2]))
    }

    func testOpenTaskReturnsNilWhenEmpty() {
        XCTAssertNil(GitPanelView.openTask(from: []))
    }
}

final class TaskStatusMappingTests: XCTestCase {
    func testStatusToColumnKindMapping() {
        XCTAssertEqual(TaskSummary.Status.open.columnKind, .idle)
        XCTAssertEqual(TaskSummary.Status.running.columnKind, .running)
        XCTAssertEqual(TaskSummary.Status.ciFailing.columnKind, .error)
        XCTAssertEqual(TaskSummary.Status.mergeReady.columnKind, .needsAttention)
        XCTAssertEqual(TaskSummary.Status.done.columnKind, .done)
    }

    func testAggregateBoardStatusPriorities() {
        let sid = UUID()
        let tOpen = TaskSummary(id: UUID(), sessionID: sid, title: "A", done: false, status: .open, createdAt: Date(), updatedAt: Date())
        let tRun = TaskSummary(id: UUID(), sessionID: sid, title: "B", done: false, status: .running, createdAt: Date(), updatedAt: Date())
        let tFail = TaskSummary(id: UUID(), sessionID: sid, title: "C", done: false, status: .ciFailing, createdAt: Date(), updatedAt: Date())
        let tMerge = TaskSummary(id: UUID(), sessionID: sid, title: "D", done: false, status: .mergeReady, createdAt: Date(), updatedAt: Date())
        let tDone = TaskSummary(id: UUID(), sessionID: sid, title: "E", done: true, status: .done, createdAt: Date(), updatedAt: Date())

        // Error (ciFailing) takes top precedence
        XCTAssertEqual([tOpen, tRun, tFail, tMerge].aggregateBoardStatus, .error)
        // Needs attention (mergeReady) takes precedence over running
        XCTAssertEqual([tOpen, tRun, tMerge].aggregateBoardStatus, .needsAttention)
        // Running takes precedence over open
        XCTAssertEqual([tOpen, tRun].aggregateBoardStatus, .running)
        // All done -> done
        XCTAssertEqual([tDone].aggregateBoardStatus, .done)
        // Empty -> idle
        XCTAssertEqual([TaskSummary]().aggregateBoardStatus, .idle)
    }

    func testTaskTooltipSummary() {
        let sid = UUID()
        let t1 = TaskSummary(id: UUID(), sessionID: sid, title: "Step 1", done: true, status: .done, createdAt: Date(), updatedAt: Date())
        let t2 = TaskSummary(id: UUID(), sessionID: sid, title: "Step 2", done: false, status: .running, createdAt: Date(), updatedAt: Date())

        let tooltip = [t1, t2].taskTooltipSummary
        XCTAssertTrue(tooltip.contains("Tasks (1/2 done)"))
        XCTAssertTrue(tooltip.contains("✓ Step 1 [done]"))
        XCTAssertTrue(tooltip.contains("• Step 2 [running]"))
    }
}
