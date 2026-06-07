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

    func testTabMatchesNameSearchesSubtitleButTitleDoesNot() {
        var editor = SessionEditor()
        let tab = editor.snapshot.workspaces[0].sessions[0].tabs[0]
        let surface = tab.rootPane.allSurfaceIDs().first!
        editor.updateTabTitle(surfaceID: surface, title: "frontend")
        editor.updateTabCwd(surfaceID: surface, path: "/home/user/myproject")
        let updated = editor.snapshot.workspaces[0].sessions[0].tabs[0]
        XCTAssertEqual(updated.displaySubtitle, "myproject")

        // Title (and name) both match the tab's title.
        XCTAssertTrue(FindWindowMatcher.tabMatches(updated, pattern: "frontend", name: false, title: true))
        XCTAssertTrue(FindWindowMatcher.tabMatches(updated, pattern: "frontend", name: true, title: true))
        // Only name additionally searches the display subtitle (cwd basename / branch).
        XCTAssertTrue(FindWindowMatcher.tabMatches(updated, pattern: "myproject", name: true, title: false))
        XCTAssertFalse(FindWindowMatcher.tabMatches(updated, pattern: "myproject", name: false, title: true))
        // Neither flag set never matches.
        XCTAssertFalse(FindWindowMatcher.tabMatches(updated, pattern: "frontend", name: false, title: false))
    }

    func testTargetScopesSearchToOneSessionOrMatchesNothing() throws {
        var editor = SessionEditor()
        let ws = try XCTUnwrap(editor.snapshot.activeWorkspace)
        // Session A (seeded) and session B, each with a window titled "api-…".
        let sessionA = editor.snapshot.workspaces[0].sessions[0].id
        editor.updateTabTitle(
            surfaceID: try XCTUnwrap(editor.snapshot.workspaces[0].sessions[0].tabs[0].rootPane.allSurfaceIDs().first),
            title: "api-A")
        let sessionB = try XCTUnwrap(editor.addSession(to: ws.id, name: "beta"))
        let bTab = try XCTUnwrap(editor.snapshot.workspaces[0].sessions.first { $0.id == sessionB }?.tabs.first)
        editor.updateTabTitle(surfaceID: try XCTUnwrap(bTab.rootPane.allSurfaceIDs().first), title: "api-B")
        let snap = editor.snapshot
        let aTab = try XCTUnwrap(snap.workspaces[0].sessions.first { $0.id == sessionA }?.tabs.first)

        // Unscoped: both sessions' windows match.
        XCTAssertEqual(
            FindWindowMatcher.snapshotMatches(snap, pattern: "api", name: true, title: true).count, 2)
        // Scoped to session A by id: only A's window, never B's.
        XCTAssertEqual(
            FindWindowMatcher.snapshotMatches(
                snap, pattern: "api", name: true, title: true, target: sessionA.uuidString).map(\.tabID),
            [aTab.id])
        // Scoped to a session that doesn't exist: nothing — the caller fails loudly instead of
        // silently widening back to a global search.
        XCTAssertTrue(
            FindWindowMatcher.snapshotMatches(
                snap, pattern: "api", name: true, title: true, target: UUID().uuidString).isEmpty)
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
