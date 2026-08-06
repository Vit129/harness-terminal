import XCTest
@testable import KouenApp

/// M9: `ComposerPanel.slashMatch` — pure logic behind the `/` command picker. The popup
/// UI itself (via `CompletionPopupView`, already exercised by `SyntaxTextView`'s own file
/// completion) isn't re-tested here.
@MainActor
final class ComposerPanelSlashCommandTests: XCTestCase {
    func testMatchesAtStartOfEmptyText() {
        let result = ComposerPanel.slashMatch(text: "/mo", cursorLocation: 3)
        XCTAssertEqual(result?.prefix, "/mo")
        XCTAssertEqual(result?.candidates, ["/model"])
    }

    func testMatchesOnNewLineAfterOtherText() {
        let text = "please fix the bug\n/cl"
        let result = ComposerPanel.slashMatch(text: text, cursorLocation: (text as NSString).length)
        XCTAssertEqual(result?.prefix, "/cl")
        XCTAssertEqual(result?.candidates, ["/clear"])
    }

    func testNoMatchWhenSlashIsMidSentence() {
        let text = "fix src/model.swift"
        XCTAssertNil(ComposerPanel.slashMatch(text: text, cursorLocation: (text as NSString).length))
    }

    func testNoMatchWithoutLeadingSlash() {
        XCTAssertNil(ComposerPanel.slashMatch(text: "model", cursorLocation: 5))
    }

    func testNoMatchWhenNoCommandStartsWithPrefix() {
        XCTAssertNil(ComposerPanel.slashMatch(text: "/zzz", cursorLocation: 4))
    }

    func testBareSlashMatchesAllCommands() {
        let result = ComposerPanel.slashMatch(text: "/", cursorLocation: 1)
        XCTAssertEqual(result?.prefix, "/")
        XCTAssertEqual(result?.candidates, ComposerPanel.slashCommands)
    }

    func testCursorMidTextOnlyConsidersTextBeforeCursor() {
        // Cursor right after "/mo" in "/model" — must match on "/mo", not the full line.
        let result = ComposerPanel.slashMatch(text: "/model", cursorLocation: 3)
        XCTAssertEqual(result?.prefix, "/mo")
    }
}
