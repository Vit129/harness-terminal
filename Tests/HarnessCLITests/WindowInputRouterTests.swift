import XCTest
import HarnessCore
@testable import HarnessCLI

final class WindowInputRouterTests: XCTestCase {
    func testDecodeKeySpecArrowKeys() {
        // ESC [ A/B/C/D → Up/Down/Right/Left
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "A")]),
            .complete(KeySpec(key: "Up"))
        )
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "B")]),
            .complete(KeySpec(key: "Down"))
        )
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "C")]),
            .complete(KeySpec(key: "Right"))
        )
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "D")]),
            .complete(KeySpec(key: "Left"))
        )
    }

    func testDecodeKeySpecModifiedArrows() {
        // ESC [ 1 ; 5 C → Ctrl+Right
        // 5 is ctrl (1 + ctrl=4)
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "1"), UInt8(ascii: ";"), UInt8(ascii: "5"), UInt8(ascii: "C")]),
            .complete(KeySpec(key: "Right", modifiers: .control))
        )
        // ESC [ 1 ; 2 A → Shift+Up
        // 2 is shift (1 + shift=1)
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "1"), UInt8(ascii: ";"), UInt8(ascii: "2"), UInt8(ascii: "A")]),
            .complete(KeySpec(key: "Up", modifiers: .shift))
        )
        // ESC [ 1 ; 3 B → Alt+Down
        // 3 is alt (1 + alt=2)
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "1"), UInt8(ascii: ";"), UInt8(ascii: "3"), UInt8(ascii: "B")]),
            .complete(KeySpec(key: "Down", modifiers: .option))
        )
    }

    func testDecodeKeySpecControlBytes() {
        // 0x01 is special-cased to return .literalPrefix
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x01]),
            .literalPrefix
        )

        // 0x02-0x1a → C-b through C-z
        for byte in UInt8(2)...UInt8(26) {
            let letter = String(Character(UnicodeScalar(byte + 0x60)))
            XCTAssertEqual(
                WindowInputRouter.decodeKeySpec([byte]),
                .complete(KeySpec(key: letter, modifiers: .control))
            )
        }
    }

    func testDecodeKeySpecPrintable() {
        // 0x20-0x7e → literal char
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([UInt8(ascii: "a")]), .complete(KeySpec(key: "a")))
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([UInt8(ascii: "Z")]), .complete(KeySpec(key: "Z")))
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([UInt8(ascii: " ")]), .complete(KeySpec(key: " ")))
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([UInt8(ascii: "~")]), .complete(KeySpec(key: "~")))
    }

    func testDecodeKeySpecEscPrefixed() {
        // ESC + printable → M-<char>
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "x")]),
            .complete(KeySpec(key: "x", modifiers: .option))
        )
        XCTAssertEqual(
            WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "A")]),
            .complete(KeySpec(key: "A", modifiers: .option))
        )
    }

    func testDecodeKeySpecIncomplete() {
        // partial sequences → .incomplete
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([]), .incomplete)
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([0x1b]), .incomplete)
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "[")]), .incomplete)
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "1")]), .incomplete)
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "1"), UInt8(ascii: ";")]), .incomplete)
    }

    func testDecodeKeySpecInvalid() {
        // unrecognized → .invalid
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([0x1b, 0x00]), .invalid)
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([0x1b, UInt8(ascii: "["), UInt8(ascii: "1"), UInt8(ascii: ";"), UInt8(ascii: "5"), UInt8(ascii: "X")]), .invalid)
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([0x00]), .invalid)
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([0x80]), .invalid)
    }

    func testDecodeKeySpecBackspace() {
        // 0x7f → BSpace
        XCTAssertEqual(WindowInputRouter.decodeKeySpec([0x7f]), .complete(KeySpec(key: "BSpace")))
    }
}
