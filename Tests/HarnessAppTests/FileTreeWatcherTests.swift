import XCTest
import HarnessCore
@testable import HarnessApp

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
