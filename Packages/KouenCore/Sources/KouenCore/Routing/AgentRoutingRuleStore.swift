import Foundation
import KouenIPC

/// Daemon-owned Agent Routing Rule storage, mirroring `AutomationStore`'s persistence shape.
public final class AgentRoutingRuleStore: @unchecked Sendable {
    private var rules: [AgentRoutingRule] = []
    private let lock = NSLock()
    private let url: URL

    public init(url: URL = KouenPaths.agentRoutingRulesURL) {
        self.url = url
        self.rules = Self.loadFromDisk(at: url)
    }

    public func list() -> [AgentRoutingRule] {
        lock.lock(); defer { lock.unlock() }
        return rules
    }

    public func get(id: UUID) -> AgentRoutingRule? {
        lock.lock(); defer { lock.unlock() }
        return rules.first { $0.id == id }
    }

    @discardableResult
    public func create(
        kind: AgentRoutingRule.Kind, pattern: String, targetAgent: AgentKind, enabled: Bool = true
    ) -> AgentRoutingRule {
        lock.lock()
        let nextOrder = (rules.filter { $0.kind == kind }.map(\.order).max() ?? -1) + 1
        let rule = AgentRoutingRule(order: nextOrder, kind: kind, pattern: pattern, targetAgent: targetAgent, enabled: enabled)
        rules.append(rule)
        let toSave = rules
        lock.unlock()
        save(toSave)
        return rule
    }

    @discardableResult
    public func update(
        id: UUID, pattern: String?, targetAgent: AgentKind?, enabled: Bool?
    ) -> AgentRoutingRule? {
        lock.lock()
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return nil
        }
        if let pattern { rules[index].pattern = pattern }
        if let targetAgent { rules[index].targetAgent = targetAgent }
        if let enabled { rules[index].enabled = enabled }
        rules[index].updatedAt = Date()
        let updated = rules[index]
        let toSave = rules
        lock.unlock()
        save(toSave)
        return updated
    }

    @discardableResult
    public func delete(id: UUID) -> Bool {
        lock.lock()
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }
        rules.remove(at: index)
        let toSave = rules
        lock.unlock()
        save(toSave)
        return true
    }

    /// Reassigns `order` for every rule of `kind`, per `orderedIDs`. IDs not belonging to
    /// `kind`, or not present in the current rule set, are ignored. Rules of `kind` not
    /// named in `orderedIDs` keep their relative order, appended after the named ones —
    /// so a partial reorder call never drops a rule silently.
    @discardableResult
    public func reorder(kind: AgentRoutingRule.Kind, orderedIDs: [UUID]) -> [AgentRoutingRule] {
        lock.lock()
        let named = orderedIDs.filter { id in rules.contains { $0.id == id && $0.kind == kind } }
        let unnamed = rules
            .filter { $0.kind == kind && !named.contains($0.id) }
            .sorted { $0.order < $1.order }
            .map(\.id)
        for (newOrder, id) in (named + unnamed).enumerated() {
            if let index = rules.firstIndex(where: { $0.id == id }) {
                rules[index].order = newOrder
                rules[index].updatedAt = Date()
            }
        }
        let toSave = rules
        lock.unlock()
        save(toSave)
        return toSave.filter { $0.kind == kind }.sorted { $0.order < $1.order }
    }

    private static func loadFromDisk(at url: URL) -> [AgentRoutingRule] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let rules = try? decoder.decode([AgentRoutingRule].self, from: data) else {
            KouenPaths.backupCorruptFile(at: url, label: "KouenDaemon")
            return []
        }
        return rules
    }

    private func save(_ snapshot: [AgentRoutingRule]) {
        try? KouenPaths.ensureDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
