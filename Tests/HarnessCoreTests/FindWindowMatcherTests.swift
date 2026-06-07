import XCTest
@testable import HarnessCore

final class FindWindowMatcherTests: XCTestCase {
    private func snapshot(titles: [String]) -> SessionSnapshot {
        var editor = SessionEditor()
        let ws = editor.snapshot.activeWorkspace!
        // The seeded tab + one per extra title.
        for _ in titles.dropFirst() { _ = editor.addTab(to: ws.id) }
        let tabs = editor.snapshot.workspaces[0].sessions.flatMap(\.tabs)
        for (index, tab) in tabs.enumerated() where index < titles.count {
            editor.updateTabTitle(surfaceID: tab.rootPane.allSurfaceIDs().first!, title: titles[index])
        }
        return editor.snapshot
    }

    func testBarePatternMatchesAsSubstringCaseInsensitive() {
        XCTAssertTrue(FindWindowMatcher.matches(pattern: "api", in: "My-API-server"))
        XCTAssertFalse(FindWindowMatcher.matches(pattern: "api", in: "frontend"))
    }

    func testGlobPatternsUseFnmatch() {
        XCTAssertTrue(FindWindowMatcher.matches(pattern: "api*", in: "api-server"))
        XCTAssertFalse(FindWindowMatcher.matches(pattern: "api*", in: "my-api"))
        XCTAssertTrue(FindWindowMatcher.matches(pattern: "a?i", in: "api"))
    }

    func testSnapshotMatchesFindsByTitleInOrder() {
        let snap = snapshot(titles: ["frontend", "api-server", "api-worker"])
        let matches = FindWindowMatcher.snapshotMatches(snap, pattern: "api", name: true, title: true)
        XCTAssertEqual(matches.count, 2)
        let tabs = snap.workspaces[0].sessions.flatMap(\.tabs)
        XCTAssertEqual(matches.first?.tabID, tabs[1].id)
    }

    func testFirstMatchFallsBackToContentCapture() {
        let snap = snapshot(titles: ["frontend", "backend"])
        let tabs = snap.workspaces[0].sessions.flatMap(\.tabs)
        let needleSurface = tabs[1].rootPane.allSurfaceIDs().first!.uuidString
        // Title doesn't match; content of the second tab's pane does.
        let match = FindWindowMatcher.firstMatch(snap, pattern: "panic: segfault", name: true, title: true) { sid in
            sid == needleSurface ? "some output...\npanic: segfault at 0x0\n" : "calm output"
        }
        XCTAssertEqual(match?.tabID, tabs[1].id)
        XCTAssertNil(FindWindowMatcher.firstMatch(snap, pattern: "no-such-text", name: true, title: true) { _ in "calm" })
    }
}
