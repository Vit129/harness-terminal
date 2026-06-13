import XCTest
@testable import HarnessApp

final class SearchPanelViewTests: XCTestCase {
    func testSpotlightMatchFindsNestedFileFromFolderName() {
        XCTAssertTrue(SearchPanelView.spotlightMatch(
            query: "Controllers",
            name: "SessionView.swift",
            relativePath: "Sources/App/Controllers/SessionView.swift",
            caseSensitive: false
        ))
    }

    func testSpotlightMatchFindsNestedFolderByRelativePath() {
        XCTAssertTrue(SearchPanelView.spotlightMatch(
            query: "view controllers",
            name: "Controllers",
            relativePath: "Sources/App/View/Controllers",
            caseSensitive: false
        ))
    }

    func testSpotlightMatchSplitsFilenameSeparators() {
        XCTAssertTrue(SearchPanelView.spotlightMatch(
            query: "session view swift",
            name: "SessionView.swift",
            relativePath: "Sources/App/SessionView.swift",
            caseSensitive: false
        ))
    }

    func testSpotlightMatchHonorsCaseSensitiveMode() {
        XCTAssertFalse(SearchPanelView.spotlightMatch(
            query: "readme",
            name: "README.md",
            relativePath: "Docs/README.md",
            caseSensitive: true
        ))
    }
}
