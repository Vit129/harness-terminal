import AppKit
import XCTest
@testable import HarnessApp

@MainActor
final class SyntaxHighlighterTests: XCTestCase {
    func testSwiftHighlighting() {
        let code = "import Foundation\n// This is a comment\nfunc test() {\n    let hello = \"world\"\n}"
        let highlighted = SyntaxHighlighter.highlight(code, fileExtension: "swift")
        
        let string = highlighted.string
        XCTAssertEqual(string, code)
        
        // Find comment "// This is a comment" and assert it has a color attribute
        let commentRange = (string as NSString).range(of: "// This is a comment")
        XCTAssertNotEqual(commentRange.location, NSNotFound)
        let commentColor = highlighted.attribute(.foregroundColor, at: commentRange.location, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(commentColor, "Comment should be colored")
        
        // Find keyword "func" and assert it has a color attribute
        let funcRange = (string as NSString).range(of: "func")
        XCTAssertNotEqual(funcRange.location, NSNotFound)
        let funcColor = highlighted.attribute(.foregroundColor, at: funcRange.location, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(funcColor, "Keyword should be colored")
        
        // Find string "\"world\"" and assert it has a color attribute
        let stringRange = (string as NSString).range(of: "\"world\"")
        XCTAssertNotEqual(stringRange.location, NSNotFound)
        let stringColor = highlighted.attribute(.foregroundColor, at: stringRange.location, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(stringColor, "String should be colored")
    }
    
    func testPythonHighlighting() {
        let code = "def hello():\n    # python comment\n    x = 123"
        let highlighted = SyntaxHighlighter.highlight(code, fileExtension: "py")
        let string = highlighted.string
        
        let defRange = (string as NSString).range(of: "def")
        let commentRange = (string as NSString).range(of: "# python comment")
        let numberRange = (string as NSString).range(of: "123")
        
        XCTAssertNotNil(highlighted.attribute(.foregroundColor, at: defRange.location, effectiveRange: nil))
        XCTAssertNotNil(highlighted.attribute(.foregroundColor, at: commentRange.location, effectiveRange: nil))
        XCTAssertNotNil(highlighted.attribute(.foregroundColor, at: numberRange.location, effectiveRange: nil))
    }
    
    func testGoHighlighting() {
        let code = "package main\nimport \"fmt\""
        let highlighted = SyntaxHighlighter.highlight(code, fileExtension: "go")
        let string = highlighted.string
        
        let packageRange = (string as NSString).range(of: "package")
        let importRange = (string as NSString).range(of: "import")
        
        XCTAssertNotNil(highlighted.attribute(.foregroundColor, at: packageRange.location, effectiveRange: nil))
        XCTAssertNotNil(highlighted.attribute(.foregroundColor, at: importRange.location, effectiveRange: nil))
    }

    func testPlainTextViewerFallbacks() {
        let code = "plain text line 1\nplain text line 2"
        let highlighted = SyntaxHighlighter.highlight(code, fileExtension: "txt")
        let string = highlighted.string
        
        // Default text should have default white color and default font size, no specific keyword colors
        XCTAssertEqual(string, code)
        let firstCharColor = highlighted.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        // It should have the default text color (NSColor(white: 0.9, alpha: 1))
        XCTAssertEqual(firstCharColor, NSColor(white: 0.9, alpha: 1))
    }
}
