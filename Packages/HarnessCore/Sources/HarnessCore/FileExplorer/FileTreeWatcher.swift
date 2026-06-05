import Foundation

public actor FileTreeWatcher {
    private static let excludedDirectoryNames: Set<String> = [
        ".git",
        "node_modules",
        ".build",
        "DerivedData",
    ]
    private static let maxNodeCount = 10_000

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func scan(rootPath: String) async throws -> [FileNode] {
        try scanDirectory(atPath: rootPath)
    }

    public func expand(node: FileNode) async throws -> [FileNode] {
        guard node.isDirectory else { return [] }
        return try scanDirectory(atPath: node.path)
    }

    private func scanDirectory(atPath path: String) throws -> [FileNode] {
        let rootURL = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        let urls = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        var nodes: [FileNode] = []
        nodes.reserveCapacity(min(urls.count, Self.maxNodeCount))
        for url in urls where nodes.count < Self.maxNodeCount {
            let name = url.lastPathComponent
            guard shouldInclude(name: name) else { continue }

            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values.isDirectory ?? false
            guard !isDirectory || !Self.excludedDirectoryNames.contains(name) else { continue }

            let path = url.standardizedFileURL.path
            nodes.append(FileNode(
                id: path,
                name: name,
                path: path,
                isDirectory: isDirectory,
                children: nil,
                gitStatus: .unmodified
            ))
        }

        return nodes.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func shouldInclude(name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".") && !Self.excludedDirectoryNames.contains(name)
    }
}
