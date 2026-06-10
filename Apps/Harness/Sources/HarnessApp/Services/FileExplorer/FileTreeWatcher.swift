import Foundation
import HarnessCore
import CoreServices

public struct FileTreeScanOptions: Equatable, Sendable {
    public var showsHiddenFiles: Bool
    public var showsHiddenFolders: Bool

    public init(showsHiddenFiles: Bool = false, showsHiddenFolders: Bool = false) {
        self.showsHiddenFiles = showsHiddenFiles
        self.showsHiddenFolders = showsHiddenFolders
    }
}

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

    /// Scan `rootPath` and optionally merge a pre-fetched git status map.
    ///
    /// - Parameters:
    ///   - rootPath: Directory to scan.
    ///   - gitStatus: Optional map of relative path → `GitStatusType` from
    ///     `GitStatusProvider.status(rootPath:)`. Pass `nil` (default) to skip
    ///     git colouring (e.g. when expanding a child directory).
    public func scan(
        rootPath: String,
        gitStatus: [String: GitStatusType]? = nil,
        options: FileTreeScanOptions = FileTreeScanOptions()
    ) async throws -> [FileNode] {
        let nodes = try scanDirectory(atPath: rootPath, options: options)
        guard let gitStatus, !gitStatus.isEmpty else { return nodes }
        return applyGitStatus(gitStatus, rootPath: rootPath, to: nodes)
    }

    public func expand(
        node: FileNode,
        gitStatus: [String: GitStatusType]? = nil,
        options: FileTreeScanOptions = FileTreeScanOptions()
    ) async throws -> [FileNode] {
        guard node.isDirectory else { return [] }
        let nodes = try scanDirectory(atPath: node.path, options: options)
        guard let gitStatus, !gitStatus.isEmpty else { return nodes }
        return applyGitStatus(gitStatus, rootPath: node.path, to: nodes)
    }

    // MARK: - FSEvents live watcher (F1-G)

    private final class WatcherContext: @unchecked Sendable {
        let onChange: @MainActor () -> Void
        init(onChange: @MainActor @escaping () -> Void) {
            self.onChange = onChange
        }
    }

    private final class FSEventStreamBox {
        private var streamRef: FSEventStreamRef?
        private var contextPointer: UnsafeMutableRawPointer?

        init(streamRef: FSEventStreamRef, contextPointer: UnsafeMutableRawPointer) {
            self.streamRef = streamRef
            self.contextPointer = contextPointer
        }

        func stop() {
            guard let streamRef = streamRef else { return }
            FSEventStreamStop(streamRef)
            FSEventStreamInvalidate(streamRef)
            FSEventStreamRelease(streamRef)
            self.streamRef = nil

            if let contextPointer = contextPointer {
                Unmanaged<WatcherContext>.fromOpaque(contextPointer).release()
                self.contextPointer = nil
            }
        }

        deinit {
            stop()
        }
    }

    private var watchBox: FSEventStreamBox?

    /// Start watching `rootPath` for filesystem changes recursively using FSEvents.
    /// Fires `onChange` on the **main actor** after events are received.
    public func startWatching(rootPath: String, onChange: @MainActor @escaping () -> Void) {
        stopWatching()

        let contextWrapper = WatcherContext(onChange: onChange)
        let contextPointer = UnsafeMutableRawPointer(Unmanaged.passRetained(contextWrapper).toOpaque())

        var context = FSEventStreamContext(
            version: 0,
            info: contextPointer,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (streamRef, clientInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let clientInfo = clientInfo else { return }
            let wrapper = Unmanaged<WatcherContext>.fromOpaque(clientInfo).takeUnretainedValue()
            Task { @MainActor in
                wrapper.onChange()
            }
        }

        let paths = [rootPath] as CFArray
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            Unmanaged<WatcherContext>.fromOpaque(contextPointer).release()
            return
        }

        let queue = DispatchQueue.global(qos: .utility)
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)

        self.watchBox = FSEventStreamBox(streamRef: stream, contextPointer: contextPointer)
    }

    /// Stop the active filesystem watcher.
    public func stopWatching() {
        watchBox?.stop()
        watchBox = nil
    }

    // MARK: - Private

    private func applyGitStatus(
        _ gitStatus: [String: GitStatusType],
        rootPath: String,
        to nodes: [FileNode]
    ) -> [FileNode] {
        // rootPath may or may not have a trailing slash; normalise once.
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return nodes.map { node in
            let rel = node.path.hasPrefix(prefix)
                ? String(node.path.dropFirst(prefix.count))
                : node.path
            var updated = node
            updated.gitStatus = gitStatus[rel] ?? .unmodified
            return updated
        }
    }

    private func scanDirectory(atPath path: String, options: FileTreeScanOptions) throws -> [FileNode] {
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
            guard !name.isEmpty else { continue }

            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values.isDirectory ?? false
            guard !isDirectory || !Self.excludedDirectoryNames.contains(name) else { continue }
            guard shouldInclude(name: name, isDirectory: isDirectory, options: options) else { continue }

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

    private func shouldInclude(name: String, isDirectory: Bool, options: FileTreeScanOptions) -> Bool {
        guard !Self.excludedDirectoryNames.contains(name) else { return false }
        guard name.hasPrefix(".") else { return true }
        return isDirectory ? options.showsHiddenFolders : options.showsHiddenFiles
    }
}
