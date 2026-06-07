import Foundation

/// Tracks open file tabs (GUI-only, not daemon-managed).
@MainActor
final class FileTabManager {
    struct FileTab: Identifiable, Equatable {
        let id: FileTabID
        let path: String
        var title: String { (path as NSString).lastPathComponent }
    }

    private(set) var openTabs: [FileTab] = []
    var activeFileTabID: FileTabID?

    /// Open a file. If already open, activate it. Returns the tab ID.
    @discardableResult
    func open(path: String) -> FileTabID {
        if let existing = openTabs.first(where: { $0.path == path }) {
            activeFileTabID = existing.id
            return existing.id
        }
        let tab = FileTab(id: UUID(), path: path)
        openTabs.append(tab)
        activeFileTabID = tab.id
        return tab.id
    }

    func close(id: FileTabID) {
        openTabs.removeAll { $0.id == id }
        if activeFileTabID == id {
            activeFileTabID = openTabs.last?.id
        }
    }

    func activate(id: FileTabID) {
        guard openTabs.contains(where: { $0.id == id }) else { return }
        activeFileTabID = id
    }

    func activeTab() -> FileTab? {
        guard let id = activeFileTabID else { return nil }
        return openTabs.first { $0.id == id }
    }

    var hasOpenTabs: Bool { !openTabs.isEmpty }
}
