import XCTest
@testable import HarnessApp

final class FuzzyPathResolverTests: XCTestCase {
    func testFuzzyScorePrefersPrefixAndWordStarts() throws {
        let prefix = try XCTUnwrap(FileFuzzyMatcher.score(query: "file", in: "FileEditorView.swift"))
        let scattered = try XCTUnwrap(FileFuzzyMatcher.score(query: "file", in: "ProfileListEntry.swift"))
        XCTAssertGreaterThan(prefix, scattered)
    }

    func testFuzzyScoreRejectsMissingSubsequence() {
        XCTAssertNil(FileFuzzyMatcher.score(query: "xyz", in: "FileEditorView.swift"))
    }

    func testFuzzyRankUsesFileNameBeforeFullPathPenalty() {
        let ranked = FileFuzzyMatcher.rank(query: "editor", candidates: [
            "/tmp/project/Docs/EditorGuide.md",
            "/tmp/project/Apps/Harness/Sources/HarnessApp/UI/FileEditorView.swift",
            "/tmp/project/editor-notes.txt",
        ])
        XCTAssertEqual(ranked.first?.candidate, "/tmp/project/editor-notes.txt")
        XCTAssertTrue(ranked.contains { $0.candidate.hasSuffix("FileEditorView.swift") })
    }

    func testResolveReturnsUniqueForClearWinner() {
        let resolution = FuzzyPathResolver.resolve(query: "editor", ranked: [
            (candidate: "/tmp/project/editor-notes.txt", score: 100),
            (candidate: "/tmp/project/FileEditorView.swift", score: 80),
        ])
        XCTAssertEqual(resolution, .unique("/tmp/project/editor-notes.txt"))
    }

    func testResolveReturnsAmbiguousForCloseMatches() {
        let resolution = FuzzyPathResolver.resolve(query: "editor", ranked: [
            (candidate: "/tmp/project/FileEditorView.swift", score: 100),
            (candidate: "/tmp/project/EditorGuide.md", score: 95),
        ])
        XCTAssertEqual(resolution, .ambiguous([
            "/tmp/project/FileEditorView.swift",
            "/tmp/project/EditorGuide.md",
        ]))
    }

    func testResolveReturnsNoneForNoMatches() {
        XCTAssertEqual(FuzzyPathResolver.resolve(query: "missing", ranked: []), .none)
    }
}
