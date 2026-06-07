import XCTest
@testable import HarnessCore

/// Drift guards for the generated what's-new banner content. These are what make
/// `GeneratedReleaseNotes.swift` safe to check in: a release prep that bumps
/// CHANGELOG.md/HarnessVersion.swift without rerunning `make release-notes` fails here
/// (and again in `package-app.sh`) instead of shipping a banner for the wrong release.
final class ReleaseNotesGuardTests: XCTestCase {
    private var changelog: String {
        get throws {
            let url = URL(fileURLWithPath: #filePath) // Tests/HarnessCoreTests/<this file>
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("CHANGELOG.md")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    /// Same extraction as Scripts/generate-release-notes.swift: the top release block,
    /// heading included, up to the next release heading, trailing whitespace trimmed.
    private func topBlock(of changelog: String) throws -> String {
        guard let headerRange = changelog.range(
            of: #"(?m)^## \[[^\]]+\] - .*$"#, options: [.regularExpression]
        ) else {
            throw XCTSkip("CHANGELOG.md has no release heading")
        }
        let afterHeader = changelog[headerRange.upperBound...]
        let blockEnd = afterHeader.range(of: "\n## [", options: [.literal])?.lowerBound
            ?? afterHeader.endIndex
        return String(changelog[headerRange.lowerBound ..< blockEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testGeneratedNotesMatchHarnessVersion() {
        XCTAssertEqual(
            ReleaseNotes.current.version, HarnessVersion.short,
            "GeneratedReleaseNotes.swift is for \(ReleaseNotes.current.version) but " +
                "HarnessVersion.short is \(HarnessVersion.short) — run `make release-notes`."
        )
    }

    func testGeneratedNotesMatchChangelogBlock() throws {
        let block = try topBlock(of: try changelog)
        XCTAssertEqual(
            ReleaseNotes.digest(of: block), ReleaseNotes.current.changelogDigest,
            "CHANGELOG.md's top release block changed after GeneratedReleaseNotes.swift " +
                "was generated — run `make release-notes`."
        )
    }

    func testGeneratedNotesAreRenderable() {
        XCTAssertFalse(ReleaseNotes.current.sections.isEmpty)
        for section in ReleaseNotes.current.sections {
            XCTAssertFalse(section.items.isEmpty, "empty section \(section.title)")
            for item in section.items {
                XCTAssertFalse(item.isEmpty)
                // No markdown survives generation — the banner renders text verbatim.
                XCTAssertFalse(item.contains("**"), "markdown leaked into: \(item)")
                XCTAssertFalse(item.contains("`"), "markdown leaked into: \(item)")
            }
        }
    }

    /// Pins the FNV-1a implementation both the generator script and the guard rely on.
    func testDigestIsStableFNV1a() {
        XCTAssertEqual(ReleaseNotes.digest(of: ""), "cbf29ce484222325")
        XCTAssertEqual(ReleaseNotes.digest(of: "a"), "af63dc4c8601ec8c")
        XCTAssertNotEqual(ReleaseNotes.digest(of: "harness"), ReleaseNotes.digest(of: "harness "))
    }
}
