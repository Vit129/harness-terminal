import XCTest
import KouenCore
@testable import KouenApp

final class FileTreeWatcherTests: XCTestCase {
    func testScanReturnsOneLevelTreeForTempDirectory() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFile(root.appendingPathComponent("README.md"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try writeFile(root.appendingPathComponent("Sources").appendingPathComponent("main.swift"))

        let nodes = try await FileTreeWatcher().scan(rootPath: root.path)

        XCTAssertEqual(nodes.map(\.name), ["Sources", "README.md"])
        XCTAssertEqual(nodes.first?.isDirectory, true)
        XCTAssertNil(nodes.first?.children)
        XCTAssertEqual(nodes.last?.isDirectory, false)
    }

    func testScanExcludesHiddenFilesHiddenFoldersAndNoiseDirectoriesByDefault() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFile(root.appendingPathComponent(".env"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".config"), withIntermediateDirectories: true)
        try writeFile(root.appendingPathComponent(".config").appendingPathComponent("settings.json"))
        try writeFile(root.appendingPathComponent("visible.txt"))
        for name in [".git", "node_modules", ".build", "DerivedData"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
            try writeFile(root.appendingPathComponent(name).appendingPathComponent("ignored.txt"))
        }

        let nodes = try await FileTreeWatcher().scan(rootPath: root.path)

        XCTAssertEqual(nodes.map(\.name), ["visible.txt"])
    }

    func testScanCanIncludeHiddenFilesWithoutHiddenFolders() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFile(root.appendingPathComponent(".env"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".config"), withIntermediateDirectories: true)
        try writeFile(root.appendingPathComponent("visible.txt"))

        let nodes = try await FileTreeWatcher().scan(
            rootPath: root.path,
            options: FileTreeScanOptions(showsHiddenFiles: true)
        )

        XCTAssertEqual(nodes.map(\.name), [".env", "visible.txt"])
    }

    func testScanCanIncludeHiddenFoldersWithoutNoiseDirectories() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFile(root.appendingPathComponent(".env"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".config"), withIntermediateDirectories: true)
        try writeFile(root.appendingPathComponent(".config").appendingPathComponent("settings.json"))
        for name in [".git", "node_modules", ".build", "DerivedData"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
            try writeFile(root.appendingPathComponent(name).appendingPathComponent("ignored.txt"))
        }

        let nodes = try await FileTreeWatcher().scan(
            rootPath: root.path,
            options: FileTreeScanOptions(showsHiddenFolders: true)
        )

        XCTAssertEqual(nodes.map(\.name), [".config"])
    }

    func testExpandLoadsChildren() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try writeFile(folder.appendingPathComponent("child.txt"))

        let rootNodes = try await FileTreeWatcher().scan(rootPath: root.path)
        let folderNode = try XCTUnwrap(rootNodes.first { $0.name == "Folder" })
        let children = try await FileTreeWatcher().expand(node: folderNode)

        XCTAssertEqual(children.map(\.name), ["child.txt"])
        XCTAssertFalse(children[0].isDirectory)
    }

    func testSearchFindsNestedFilesByExtensionFragmentWithoutExpandingFolder() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("Tests").appendingPathComponent("Feature")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try writeFile(nested.appendingPathComponent("login.spec.ts"))
        try writeFile(root.appendingPathComponent("README.md"))

        let results = try await FileTreeWatcher().search(rootPath: root.path, query: ".spec.ts")

        XCTAssertEqual(results.map(\.name), ["login.spec.ts"])
        XCTAssertEqual(results.first?.path, nested.appendingPathComponent("login.spec.ts").path)
    }

    func testSearchFindsNestedItemsByPathTokens() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("src").appendingPathComponent("components").appendingPathComponent("Button")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try writeFile(folder.appendingPathComponent("Button.tsx"))

        let results = try await FileTreeWatcher().search(rootPath: root.path, query: "components button")

        XCTAssertTrue(results.contains { $0.isDirectory && $0.path == folder.path })
        XCTAssertTrue(results.contains { !$0.isDirectory && $0.name == "Button.tsx" })
    }

    func testSearchSplitsCommonFilenameSeparatorsLikeSpotlightStyleSearch() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("tests")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try writeFile(nested.appendingPathComponent("checkout-flow.spec.ts"))

        let results = try await FileTreeWatcher().search(rootPath: root.path, query: "checkout spec ts")

        XCTAssertEqual(results.map(\.name), ["checkout-flow.spec.ts"])
    }

    func testSearchIsCaseAndDiacriticInsensitive() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFile(root.appendingPathComponent("RésuméView.swift"))

        let results = try await FileTreeWatcher().search(rootPath: root.path, query: "resumeview")

        XCTAssertEqual(results.map(\.name), ["RésuméView.swift"])
    }

    func testSearchRelevanceRanking() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        // Setup various files to test ranking for query "test"
        // 1. Exact match (highest)
        try writeFile(root.appendingPathComponent("test"))
        // 2. Starts with
        try writeFile(root.appendingPathComponent("testing.txt"))
        // 3. Ends with
        try writeFile(root.appendingPathComponent("latest.test"))
        // 4. Contains (filename contains)
        try writeFile(root.appendingPathComponent("mytestfile.txt"))
        // 5. Path contains
        let subDir = root.appendingPathComponent("testdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try writeFile(subDir.appendingPathComponent("other.txt"))
        // 6. Ties check: shallower vs deeper
        // "test_deep" is deeper than "test_shallow"
        let subDir2 = root.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir2, withIntermediateDirectories: true)
        let deepDir = subDir2.appendingPathComponent("deep")
        try FileManager.default.createDirectory(at: deepDir, withIntermediateDirectories: true)
        try writeFile(subDir2.appendingPathComponent("test_shallow"))
        try writeFile(deepDir.appendingPathComponent("test_deep"))

        let results = try await FileTreeWatcher().search(rootPath: root.path, query: "test")

        // Exact match "test" -> starts with "testing.txt" -> ends with "latest.test" -> contains "mytestfile.txt"
        // Then ties "test_shallow" (shallower) vs "test_deep" (deeper)
        // Then path contains "other.txt" (inside "testdir")
        let names = results.map(\.name)
        XCTAssertEqual(names.first, "test")
        XCTAssertTrue(names.contains("testing.txt"))
        XCTAssertTrue(names.contains("latest.test"))
        XCTAssertTrue(names.contains("mytestfile.txt"))
        XCTAssertTrue(names.contains("test_shallow"))
        XCTAssertTrue(names.contains("test_deep"))
        XCTAssertTrue(names.contains("other.txt"))

        // Verify ordering: exact before startsWith
        let exactIdx = names.firstIndex(of: "test")!
        let startsWithIdx = names.firstIndex(of: "testing.txt")!
        let endsWithIdx = names.firstIndex(of: "latest.test")!
        let containsIdx = names.firstIndex(of: "mytestfile.txt")!
        let shallowIdx = names.firstIndex(of: "test_shallow")!
        let deepIdx = names.firstIndex(of: "test_deep")!
        let pathContainsIdx = names.firstIndex(of: "other.txt")!

        XCTAssertLessThan(exactIdx, startsWithIdx)
        XCTAssertLessThan(startsWithIdx, endsWithIdx)
        XCTAssertLessThan(endsWithIdx, containsIdx)
        // Both test_shallow and test_deep are "starts with" ("test_shallow", "test_deep" starts with "test")
        // but test_shallow is shallower (1 slash from root) than test_deep (2 slashes from root)
        XCTAssertLessThan(shallowIdx, deepIdx)
        // pathContains should be after filename startsWith/contains
        XCTAssertLessThan(containsIdx, pathContainsIdx)
    }

    func testSearchFuzzyFallback() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeFile(root.appendingPathComponent("FileTreeWatcher.swift"))
        try writeFile(root.appendingPathComponent("flat.txt"))

        // Query "flwatcher" has no direct match, but should fuzzy match "FileTreeWatcher.swift"
        let fuzzyResults = try await FileTreeWatcher().search(rootPath: root.path, query: "flwatcher")
        XCTAssertEqual(fuzzyResults.map(\.name), ["FileTreeWatcher.swift"])

        // Query "flat" has a direct match, so it should NOT return "FileTreeWatcher.swift" as a fuzzy fallback
        let directResults = try await FileTreeWatcher().search(rootPath: root.path, query: "flat")
        XCTAssertEqual(directResults.map(\.name), ["flat.txt"])
    }

    func testSearchSuffixPatternMatching() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeFile(root.appendingPathComponent("Foo.spec.ts"))
        try writeFile(root.appendingPathComponent("spec.ts.tmp"))

        // Query ".spec.ts" should rank "Foo.spec.ts" (ends with) higher than "spec.ts.tmp" (contains)
        let results = try await FileTreeWatcher().search(rootPath: root.path, query: ".spec.ts")
        XCTAssertEqual(results.map(\.name), ["Foo.spec.ts", "spec.ts.tmp"])
    }

    func testSearchCappingDirectMatches() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        // Create 25 files starting with "test-a-" (alphabetically first)
        for i in 1...25 {
            let num = String(format: "%02d", i)
            try writeFile(root.appendingPathComponent("test-a-\(num).txt"))
        }
        // Create 1 file "test-z" (alphabetically last, but is an exact match which ranks higher)
        try writeFile(root.appendingPathComponent("test-z"))

        // With limit = 1, directMatches early exit threshold is 10 matches (limit * 10).
        // Since the APFS directory B-tree structure (hash-based) returns "test-a-08.txt" within
        // the first 10 matched files but "test-a-01.txt" later, the early exit will stop before
        // scanning "test-a-01.txt". Thus, the alphabetical sort of the capped candidate set
        // will yield "test-a-08.txt" as the top result, rather than "test-a-01.txt".
        let resultsForCommonQuery = try await FileTreeWatcher().search(rootPath: root.path, query: "test-a", limit: 1)
        XCTAssertEqual(resultsForCommonQuery.count, 1)
        XCTAssertEqual(resultsForCommonQuery.first?.name, "test-a-08.txt")
        XCTAssertNotEqual(resultsForCommonQuery.first?.name, "test-a-01.txt")
    }

    @MainActor
    func testBuildSearchTree() throws {
        let rootPath = "/Users/test/project"
        
        // Setup raw matched FileNodes
        let matched1 = FileNode(
            id: "/Users/test/project/Sources/main.swift",
            name: "main.swift",
            path: "/Users/test/project/Sources/main.swift",
            isDirectory: false,
            children: nil,
            gitStatus: .modified
        )
        let matched2 = FileNode(
            id: "/Users/test/project/Tests/mainTests.swift",
            name: "mainTests.swift",
            path: "/Users/test/project/Tests/mainTests.swift",
            isDirectory: false,
            children: nil,
            gitStatus: .unmodified
        )
        let matched3 = FileNode(
            id: "/Users/test/project/README.md",
            name: "README.md",
            path: "/Users/test/project/README.md",
            isDirectory: false,
            children: nil,
            gitStatus: .added
        )
        
        let gitStatus: [String: GitStatusType] = [
            "Sources/main.swift": .modified,
            "README.md": .added
        ]
        
        let rawNodes = [matched1, matched2, matched3]
        let results = FileTreeNode.buildSearchTree(from: rawNodes, rootPath: rootPath, gitStatus: gitStatus)
        
        // Root level should contain: Sources, Tests, README.md (sorted directory-first, then alphabetically)
        XCTAssertEqual(results.count, 3)
        
        XCTAssertEqual(results[0].node.name, "Sources")
        XCTAssertEqual(results[0].node.isDirectory, true)
        XCTAssertEqual(results[0].isExpanded, true) // Should be expanded because it contains a descendant match
        XCTAssertEqual(results[0].children?.count, 1)
        XCTAssertEqual(results[0].children?[0].node.name, "main.swift")
        XCTAssertEqual(results[0].children?[0].node.gitStatus, .modified)
        
        XCTAssertEqual(results[1].node.name, "Tests")
        XCTAssertEqual(results[1].node.isDirectory, true)
        XCTAssertEqual(results[1].isExpanded, true) // Should be expanded because it contains a descendant match
        XCTAssertEqual(results[1].children?.count, 1)
        XCTAssertEqual(results[1].children?[0].node.name, "mainTests.swift")
        
        XCTAssertEqual(results[2].node.name, "README.md")
        XCTAssertEqual(results[2].node.isDirectory, false)
        XCTAssertEqual(results[2].node.gitStatus, .added)
    }

    /// Regression test for a SIGBUS crash (Kouen-2026-07-25-215525.ips): rapid
    /// startWatching()/stopWatching() cycles used to free the FSEventStream callback
    /// context on a shared concurrent queue while a callback block for the old stream
    /// could still be in flight on that same queue. Hammering the cycle is the closest
    /// a unit test gets to that race without a debug-build sanitizer; it reliably
    /// crashed the process under the old DispatchQueue.global() implementation.
    func testRapidStartStopCyclesDoNotCrash() async throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let watcher = FileTreeWatcher()

        for _ in 0..<200 {
            await watcher.startWatching(rootPath: root.path) {}
            await watcher.stopWatching()
        }
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("file-tree-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeFile(_ url: URL) throws {
        try Data("x".utf8).write(to: url)
    }
}
