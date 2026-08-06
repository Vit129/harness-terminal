import XCTest
import KouenCore
@testable import KouenApp

/// `parseWorktreePorcelain` was extracted out of `refreshWorktrees` for direct testing
/// without shelling out to real git.
final class GitPanelViewWorktreeParsingTests: XCTestCase {

    // MARK: - parseWorktreePorcelain

    func testMainLinkedDetachedAndLockedEntries() {
        let porcelain = """
        worktree /repo/main
        HEAD abc123
        branch refs/heads/main

        worktree /repo/.kouen-worktrees/feature
        HEAD def456
        branch refs/heads/feature

        worktree /repo/.kouen-worktrees/detached
        HEAD ghi789
        detached

        worktree /repo/.kouen-worktrees/locked-one
        HEAD jkl012
        branch refs/heads/locked-branch
        locked
        """
        let entries = GitPanelView.parseWorktreePorcelain(porcelain, mergedBranchOutput: "")
        XCTAssertEqual(entries.count, 4)

        XCTAssertEqual(entries[0].path, "/repo/main")
        XCTAssertEqual(entries[0].branch, "main")
        XCTAssertTrue(entries[0].isMain)
        XCTAssertFalse(entries[0].isLocked)

        XCTAssertEqual(entries[1].path, "/repo/.kouen-worktrees/feature")
        XCTAssertEqual(entries[1].branch, "feature")
        XCTAssertFalse(entries[1].isMain)

        XCTAssertEqual(entries[2].branch, "detached")

        XCTAssertEqual(entries[3].branch, "locked-branch")
        XCTAssertTrue(entries[3].isLocked)
    }

    func testMergedBranchOutputMarksMatchingEntriesMerged() {
        let porcelain = """
        worktree /repo/main
        HEAD abc123
        branch refs/heads/main

        worktree /repo/.kouen-worktrees/done
        HEAD def456
        branch refs/heads/done-feature

        worktree /repo/.kouen-worktrees/pending
        HEAD ghi789
        branch refs/heads/pending-feature
        """
        let entries = GitPanelView.parseWorktreePorcelain(porcelain, mergedBranchOutput: "done-feature\n")
        XCTAssertEqual(entries.count, 3)
        XCTAssertFalse(entries[0].isMerged)
        XCTAssertTrue(entries[1].isMerged)
        XCTAssertFalse(entries[2].isMerged)
    }

    func testEmptyOutputReturnsNoEntries() {
        XCTAssertTrue(GitPanelView.parseWorktreePorcelain("", mergedBranchOutput: "").isEmpty)
    }

}
