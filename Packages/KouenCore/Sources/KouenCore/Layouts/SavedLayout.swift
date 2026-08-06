import Foundation
import KouenIPC

/// Daemon-owned Saved Layout storage, mirroring `AutomationStore`'s persistence shape.
/// `SavedLayout` + `PaneLayoutShape` themselves live in `KouenIPC` (see that file for the
/// naming note vs. the pre-existing `LayoutTemplate` enum) — this is just the store.
public final class SavedLayoutStore: @unchecked Sendable {
    private var layouts: [SavedLayout] = []
    private let lock = NSLock()
    private let url: URL

    public init(url: URL = KouenPaths.savedLayoutsURL) {
        self.url = url
        self.layouts = Self.loadFromDisk(at: url)
    }

    public func list() -> [SavedLayout] {
        lock.lock(); defer { lock.unlock() }
        return layouts
    }

    public func get(id: UUID) -> SavedLayout? {
        lock.lock(); defer { lock.unlock() }
        return layouts.first { $0.id == id }
    }

    @discardableResult
    public func create(name: String, shape: PaneLayoutShape) -> SavedLayout {
        lock.lock()
        let layout = SavedLayout(name: name, shape: shape)
        layouts.append(layout)
        let toSave = layouts
        lock.unlock()
        save(toSave)
        return layout
    }

    @discardableResult
    public func delete(id: UUID) -> Bool {
        lock.lock()
        guard let index = layouts.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }
        layouts.remove(at: index)
        let toSave = layouts
        lock.unlock()
        save(toSave)
        return true
    }

    private static func loadFromDisk(at url: URL) -> [SavedLayout] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let layouts = try? decoder.decode([SavedLayout].self, from: data) else {
            KouenPaths.backupCorruptFile(at: url, label: "KouenDaemon")
            return []
        }
        return layouts
    }

    private func save(_ snapshot: [SavedLayout]) {
        try? KouenPaths.ensureDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
