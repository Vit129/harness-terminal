import HarnessLSP
import XCTest
@testable import HarnessApp

final class ViDiagnosticNavigatorTests: XCTestCase {
    func testNextDiagnosticWrapsAfterLastLine() {
        let diagnostics = [
            diagnostic(line: 2, character: 4),
            diagnostic(line: 8, character: 1),
        ]

        XCTAssertEqual(ViDiagnosticNavigator.targetIndex(currentLine: 8, diagnostics: diagnostics, forward: true), 0)
    }

    func testPreviousDiagnosticWrapsBeforeFirstLine() {
        let diagnostics = [
            diagnostic(line: 2, character: 4),
            diagnostic(line: 8, character: 1),
        ]

        XCTAssertEqual(ViDiagnosticNavigator.targetIndex(currentLine: 2, diagnostics: diagnostics, forward: false), 1)
    }

    func testDiagnosticsAreSortedBeforeNavigation() {
        let diagnostics = [
            diagnostic(line: 12, character: 0),
            diagnostic(line: 4, character: 3),
            diagnostic(line: 4, character: 1),
        ]

        XCTAssertEqual(ViDiagnosticNavigator.targetIndex(currentLine: 3, diagnostics: diagnostics, forward: true), 2)
        XCTAssertEqual(ViDiagnosticNavigator.targetIndex(currentLine: 12, diagnostics: diagnostics, forward: false), 1)
    }

    func testEmptyDiagnosticsReturnNil() {
        XCTAssertNil(ViDiagnosticNavigator.targetIndex(currentLine: 0, diagnostics: [], forward: true))
    }

    private func diagnostic(line: Int, character: Int) -> LSPDiagnostic {
        LSPDiagnostic(
            range: LSPRange(
                start: LSPPosition(line: line, character: character),
                end: LSPPosition(line: line, character: character + 1)
            ),
            severity: .error,
            message: "diagnostic"
        )
    }
}
