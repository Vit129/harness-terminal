import Foundation
import KouenIPC

/// A Task's lifecycle state, for Orchestrator/Worker use (P44a) — richer than the
/// legacy `done: Bool` alone. `open` is the decode default for JSON persisted before
/// this field existed.
public enum KouenTaskStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case open
    case running
    case ciFailing
    case mergeReady
    case done
}

/// A session-scoped checklist item, addressable via `kouen-mcp`. Belongs to exactly one
/// session — there is no global, session-independent Task (see LANGUAGE.md).
public struct KouenTask: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var sessionID: SessionID
    public var title: String
    public var done: Bool
    public var status: KouenTaskStatus
    public let createdAt: Date
    public var updatedAt: Date
    /// The creating session's active-tab cwd, captured once at `create()` time — not
    /// re-derived later. A session can close (Tasks deliberately outlive it, see below),
    /// at which point there is no other way to recover which project a Task came from;
    /// stamping it up front is the only point where that information is ever available.
    /// Optional so Tasks created before this field existed decode to nil, not a crash.
    public var cwd: String?

    public init(
        id: UUID = UUID(), sessionID: SessionID, title: String, done: Bool = false,
        status: KouenTaskStatus? = nil,
        createdAt: Date = Date(), updatedAt: Date = Date(), cwd: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.title = title
        self.done = done
        self.status = status ?? (done ? .done : .open)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cwd = cwd
    }

    private enum CodingKeys: String, CodingKey {
        case id, sessionID, title, done, status, createdAt, updatedAt, cwd
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionID = try container.decode(SessionID.self, forKey: .sessionID)
        title = try container.decode(String.self, forKey: .title)
        done = try container.decode(Bool.self, forKey: .done)
        // Pre-P44a persisted JSON has no `status` key — default it from `done` rather
        // than crash on decode.
        status = try container.decodeIfPresent(KouenTaskStatus.self, forKey: .status)
            ?? (done ? .done : .open)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
    }
}

/// Daemon-owned Task storage so Tasks survive `Kouen.app` quitting, mirroring
/// `PasteBufferStore`'s persistence shape. A session closing does NOT delete its
/// Tasks — they remain listable; deletion is never a *session* eviction side effect
/// (see design.md's Tactical Design — data loss on routine tab-close would be
/// surprising). A done Task also stays listable (P44a — previously `update(done:
/// true)` deleted it immediately; an Auto-Fix Loop needs a durable status history,
/// so completion is no longer an implicit-delete trigger. Explicit `delete(id:)` is
/// the only way a Task disappears now.)
public final class TaskStore: @unchecked Sendable {
    private var tasks: [KouenTask] = []
    private let lock = NSLock()
    private let url: URL

    public init(url: URL = KouenPaths.tasksURL) {
        self.url = url
        self.tasks = Self.loadFromDisk(at: url)
    }

    /// All Tasks, or only those owned by `sessionID` when provided. `nil` powers the
    /// Task Dashboard's cross-session view.
    public func list(sessionID: SessionID? = nil) -> [KouenTask] {
        lock.lock(); defer { lock.unlock() }
        guard let sessionID else { return tasks }
        return tasks.filter { $0.sessionID == sessionID }
    }

    public func get(id: UUID) -> KouenTask? {
        lock.lock(); defer { lock.unlock() }
        return tasks.first { $0.id == id }
    }

    @discardableResult
    public func create(sessionID: SessionID, title: String, cwd: String? = nil) -> KouenTask {
        lock.lock()
        let task = KouenTask(sessionID: sessionID, title: title, cwd: cwd)
        tasks.append(task)
        let toSave = tasks
        lock.unlock()
        save(toSave)
        return task
    }

    /// Updates title/done/status in place — the Task stays listable afterward
    /// regardless of `done`/status (see class doc comment). Passing `done` without
    /// `status` also moves `status` to `.done`/`.open` to keep the two fields
    /// consistent for legacy callers that only ever set `done`.
    @discardableResult
    public func update(
        id: UUID, title: String? = nil, done: Bool? = nil, status: KouenTaskStatus? = nil
    ) -> KouenTask? {
        lock.lock()
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return nil
        }
        if let title { tasks[index].title = title }
        if let status {
            tasks[index].status = status
            tasks[index].done = (status == .done)
        } else if let done {
            tasks[index].done = done
            tasks[index].status = done ? .done : .open
        }
        tasks[index].updatedAt = Date()
        let updated = tasks[index]
        let toSave = tasks
        lock.unlock()
        save(toSave)
        return updated
    }

    @discardableResult
    public func delete(id: UUID) -> Bool {
        lock.lock()
        guard let index = tasks.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }
        tasks.remove(at: index)
        let toSave = tasks
        lock.unlock()
        save(toSave)
        return true
    }

    private static func loadFromDisk(at url: URL) -> [KouenTask] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let tasks = try? decoder.decode([KouenTask].self, from: data) else {
            KouenPaths.backupCorruptFile(at: url, label: "KouenDaemon")
            return []
        }
        return tasks
    }

    private func save(_ snapshot: [KouenTask]) {
        try? KouenPaths.ensureDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
