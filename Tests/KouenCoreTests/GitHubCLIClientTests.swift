import XCTest
@testable import KouenCore

/// P39 G3 — the merge action gates on `PRInfo.mergeable`, so a wrong parse here means either
/// silently offering to merge a conflicting PR or silently blocking a clean one.
final class GitHubCLIClientTests: XCTestCase {
    private func json(mergeable: String?, statusCheckRollup: String = "[]", reviewDecision: String = "") -> String {
        let mergeableField = mergeable.map { "\"\($0)\"" } ?? "null"
        return """
        {"number": 42, "title": "Add feature", "state": "OPEN", "url": "https://x/42",
         "headRefName": "feature-x", "baseRefName": "main", "isDraft": false,
         "statusCheckRollup": \(statusCheckRollup), "mergeable": \(mergeableField),
         "reviewDecision": "\(reviewDecision)"}
        """
    }

    // M8: reviewDecision parsing (waiver feature's data source)

    func testApprovedReviewDecisionParsed() {
        let pr = GitHubCLIClient().parsePRInfo(json(mergeable: "MERGEABLE", reviewDecision: "APPROVED"))
        XCTAssertEqual(pr?.reviewDecision, "APPROVED")
    }

    func testEmptyReviewDecisionParsedAsNil() {
        let pr = GitHubCLIClient().parsePRInfo(json(mergeable: "MERGEABLE", reviewDecision: ""))
        XCTAssertNil(pr?.reviewDecision)
    }

    func testMergeableTrueOnlyForExactMergeableString() {
        let pr = GitHubCLIClient().parsePRInfo(json(mergeable: "MERGEABLE"))
        XCTAssertEqual(pr?.mergeable, true)
    }

    func testConflictingIsNotMergeable() {
        let pr = GitHubCLIClient().parsePRInfo(json(mergeable: "CONFLICTING"))
        XCTAssertEqual(pr?.mergeable, false)
    }

    func testUnknownMergeStateIsNotMergeable() {
        // GitHub returns UNKNOWN while it's still computing — must not be treated as mergeable.
        let pr = GitHubCLIClient().parsePRInfo(json(mergeable: "UNKNOWN"))
        XCTAssertEqual(pr?.mergeable, false)
    }

    func testMissingMergeableFieldDefaultsToNotMergeable() {
        let pr = GitHubCLIClient().parsePRInfo(json(mergeable: nil))
        XCTAssertEqual(pr?.mergeable, false)
    }

    func testBaseRefNameParsedForConfirmDialog() {
        let pr = GitHubCLIClient().parsePRInfo(json(mergeable: "MERGEABLE"))
        XCTAssertEqual(pr?.baseRefName, "main")
    }
}
