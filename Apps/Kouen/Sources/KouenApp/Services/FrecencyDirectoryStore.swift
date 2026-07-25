import Foundation
import KouenCore

public struct FrecencyEntry: Codable, Sendable {
    public let path: String
    public var count: Double
    public var lastVisited: Date
}

@MainActor
public final class FrecencyDirectoryStore: @unchecked Sendable {
    public static let shared = FrecencyDirectoryStore()

    public private(set) var entries: [String: FrecencyEntry] = [:]
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    
    private init() {
        self.fileURL = KouenPaths.applicationSupport.appendingPathComponent("frecency-dirs.json")
        load()
    }
    
    public func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([FrecencyEntry].self, from: data)
            self.entries = Dictionary(uniqueKeysWithValues: decoded.map { ($0.path, $0) })
        } catch {
            self.entries = [:]
        }
    }
    
    public func save() {
        // Debounce: cancel any pending write and coalesce rapid cd bursts into one disk op.
        // The actual I/O runs off-main so it never stalls the render loop.
        saveTask?.cancel()
        let list = Array(entries.values)
        let url  = fileURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 s debounce
            guard !Task.isCancelled else { return }
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                try encoder.encode(list).write(to: url, options: .atomic)
            } catch {}
        }
    }
    
    private static let maxEntries = 500

    public func recordVisit(path: String) {
        let cleanPath = (path as NSString).standardizingPath
        guard !cleanPath.isEmpty, cleanPath != "/" else { return }

        var entry = entries[cleanPath] ?? FrecencyEntry(path: cleanPath, count: 0, lastVisited: Date())
        entry.count += 1
        entry.lastVisited = Date()
        entries[cleanPath] = entry
        if entries.count > Self.maxEntries { evictTail() }
        save()
    }

    private func evictTail() {
        let now = Date()
        let sorted = entries.sorted {
            let s0 = $0.value.count / log(1 + max(1, now.timeIntervalSince($0.value.lastVisited)))
            let s1 = $1.value.count / log(1 + max(1, now.timeIntervalSince($1.value.lastVisited)))
            return s0 > s1
        }
        entries = Dictionary(uniqueKeysWithValues: sorted.prefix(Self.maxEntries).map { ($0.key, $0.value) })
    }
    
    public func ranked() -> [String] {
        let now = Date()
        let scored = entries.values.map { entry -> (path: String, score: Double) in
            let seconds = now.timeIntervalSince(entry.lastVisited)
            let age = max(1.0, seconds)
            let score = entry.count / log(1.0 + age)
            return (entry.path, score)
        }
        return scored.sorted { $0.score > $1.score }.map { $0.path }
    }
}
