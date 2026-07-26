import Foundation
import KouenCore
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
        "Library",
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

    public func search(
        rootPath: String,
        query: String,
        gitStatus: [String: GitStatusType]? = nil,
        options: FileTreeScanOptions = FileTreeScanOptions(),
        limit: Int = 400
    ) async throws -> [FileNode] {
        let nodes = try searchRecursively(rootPath: rootPath, query: query, options: options, limit: limit)
        guard let gitStatus, !gitStatus.isEmpty else { return nodes }
        return applyGitStatus(gitStatus, rootPath: rootPath, to: nodes)
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
        // Dedicated SERIAL queue, not DispatchQueue.global(): the FSEvents callback runs
        // on this queue, so releasing the context here too guarantees FIFO ordering —
        // any callback block already enqueued before FSEventStreamStop() finishes running
        // before our release block gets a turn. A shared concurrent queue gave no such
        // ordering guarantee and let stop() free the context out from under an in-flight
        // callback (SIGBUS, see Kouen-2026-07-25-215525.ips).
        let queue = DispatchQueue(label: "com.vit129.kouen.filetreewatcher.fsevents")

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
                self.contextPointer = nil
                let bitPattern = UInt(bitPattern: contextPointer)
                queue.async {
                    let pointer = UnsafeMutableRawPointer(bitPattern: bitPattern)!
                    Unmanaged<WatcherContext>.fromOpaque(pointer).release()
                }
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
            // Skip events inside .git/ — only working tree changes matter for file tree.
            let cfPaths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            for i in 0..<numEvents {
                let p = unsafeBitCast(CFArrayGetValueAtIndex(cfPaths, i), to: CFString.self) as String
                if !p.contains("/.git/") {
                    let wrapper = Unmanaged<WatcherContext>.fromOpaque(clientInfo).takeUnretainedValue()
                    Task { @MainActor in wrapper.onChange() }
                    return
                }
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
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            Unmanaged<WatcherContext>.fromOpaque(contextPointer).release()
            return
        }

        let box = FSEventStreamBox(streamRef: stream, contextPointer: contextPointer)
        FSEventStreamSetDispatchQueue(stream, box.queue)
        FSEventStreamStart(stream)

        self.watchBox = box
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

    private struct ScoredMatch {
        let node: FileNode
        let category: SearchMatcher.MatchCategory
        let relativePath: String
    }

    private static func compareMatches(_ lhs: ScoredMatch, _ rhs: ScoredMatch) -> Bool {
        if lhs.category != rhs.category {
            return lhs.category < rhs.category
        }

        // Tie-breaker 1: shallower path (fewer path components / / characters)
        let lhsSlashCount = lhs.relativePath.filter { $0 == "/" }.count
        let rhsSlashCount = rhs.relativePath.filter { $0 == "/" }.count
        if lhsSlashCount != rhsSlashCount {
            return lhsSlashCount < rhsSlashCount
        }

        // Tie-breaker 2: shorter path length
        if lhs.relativePath.count != rhs.relativePath.count {
            return lhs.relativePath.count < rhs.relativePath.count
        }

        // Tie-breaker 3: alphabetical order of relative path
        return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
    }

    private func searchRecursively(
        rootPath: String,
        query: String,
        options: FileTreeScanOptions,
        limit: Int
    ) throws -> [FileNode] {
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL
        let rootPrefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        let matcher = Self.SearchMatcher(query: query)
        guard matcher.hasQuery else { return [] }

        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        )

        var directMatches: [ScoredMatch] = []
        var fuzzyMatches: [ScoredMatch] = []

        while let url = enumerator?.nextObject() as? URL {
            if Task.isCancelled {
                break
            }
            if directMatches.count >= limit * 10 {
                break
            }

            let standardizedURL = url.standardizedFileURL
            let name = standardizedURL.lastPathComponent
            guard !name.isEmpty else { continue }

            let isDirectory: Bool
            do {
                let values = try standardizedURL.resourceValues(forKeys: [.isDirectoryKey])
                isDirectory = values.isDirectory ?? false
            } catch {
                continue
            }

            if isDirectory {
                if Self.excludedDirectoryNames.contains(name) {
                    enumerator?.skipDescendants()
                    continue
                }
                
                let parentPath = standardizedURL.deletingLastPathComponent().path
                if parentPath == "/" {
                    let allowedDirs: Set<String> = ["Users", "usr", "Applications"]
                    if !allowedDirs.contains(name) {
                        enumerator?.skipDescendants()
                        continue
                    }
                } else if parentPath == "/usr" {
                    let allowedUsrDirs: Set<String> = ["local", "bin", "sbin"]
                    if !allowedUsrDirs.contains(name) {
                        enumerator?.skipDescendants()
                        continue
                    }
                }
            }
            guard shouldInclude(name: name, isDirectory: isDirectory, options: options) else {
                if isDirectory { enumerator?.skipDescendants() }
                continue
            }

            let path = standardizedURL.path
            let relativePath = path.hasPrefix(rootPrefix)
                ? String(path.dropFirst(rootPrefix.count))
                : path

            if let directCategory = matcher.matchCategory(name: name, relativePath: relativePath, allowFuzzy: false) {
                let node = FileNode(
                    id: path,
                    name: name,
                    path: path,
                    isDirectory: isDirectory,
                    children: nil,
                    gitStatus: .unmodified
                )
                directMatches.append(ScoredMatch(node: node, category: directCategory, relativePath: relativePath))
            } else if let fuzzyCategory = matcher.matchCategory(name: name, relativePath: relativePath, allowFuzzy: true) {
                let node = FileNode(
                    id: path,
                    name: name,
                    path: path,
                    isDirectory: isDirectory,
                    children: nil,
                    gitStatus: .unmodified
                )
                fuzzyMatches.append(ScoredMatch(node: node, category: fuzzyCategory, relativePath: relativePath))
            }
        }

        let sortedScored = !directMatches.isEmpty ? directMatches : fuzzyMatches
        let sortedNodes = sortedScored
            .sorted(by: Self.compareMatches)
            .map { $0.node }

        return Array(sortedNodes.prefix(limit))
    }

    nonisolated struct SearchMatcher {
        enum MatchCategory: Int, Comparable, Sendable {
            case exactFilename = 1
            case filenameStartsWith = 2
            case filenameEndsWith = 3
            case filenameContains = 4
            case filenameContainsTokens = 5
            case pathContains = 6
            case pathContainsTokens = 7
            case fuzzy = 8

            static func < (lhs: MatchCategory, rhs: MatchCategory) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

        let wholeQuery: String
        let tokens: [String]

        init(query: String) {
            wholeQuery = Self.normalized(query)
            tokens = wholeQuery
                .split(whereSeparator: Self.isTokenSeparator)
                .map(String.init)
                .filter { !$0.isEmpty }
        }

        var hasQuery: Bool {
            !wholeQuery.isEmpty || !tokens.isEmpty
        }

        func matchCategory(name: String, relativePath: String, allowFuzzy: Bool) -> MatchCategory? {
            let normalizedName = Self.normalized(name)
            let normalizedPath = Self.normalized(relativePath)

            if normalizedName == wholeQuery {
                return .exactFilename
            }
            if normalizedName.hasPrefix(wholeQuery) {
                return .filenameStartsWith
            }
            if normalizedName.hasSuffix(wholeQuery) {
                return .filenameEndsWith
            }
            if normalizedName.contains(wholeQuery) {
                return .filenameContains
            }
            if !tokens.isEmpty, tokens.allSatisfy({ normalizedName.contains($0) }) {
                return .filenameContainsTokens
            }
            if normalizedPath.contains(wholeQuery) {
                return .pathContains
            }
            if !tokens.isEmpty, tokens.allSatisfy({ normalizedPath.contains($0) }) {
                return .pathContainsTokens
            }

            if allowFuzzy {
                if Self.isSubsequence(wholeQuery, in: normalizedName) ||
                    Self.isSubsequence(wholeQuery, in: normalizedPath) {
                    return .fuzzy
                }
            }

            return nil
        }

        private static func isSubsequence(_ query: String, in haystack: String) -> Bool {
            if query.isEmpty { return true }
            var queryIdx = query.startIndex
            for char in haystack {
                if char == query[queryIdx] {
                    queryIdx = query.index(after: queryIdx)
                    if queryIdx == query.endIndex {
                        return true
                    }
                }
            }
            return false
        }

        private static func normalized(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private static func isTokenSeparator(_ character: Character) -> Bool {
            character.isWhitespace || character == "/" || character == "." || character == "-" || character == "_"
        }
    }
}
