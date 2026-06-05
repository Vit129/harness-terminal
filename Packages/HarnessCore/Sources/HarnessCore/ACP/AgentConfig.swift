import Foundation

public struct AgentConfig: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var binaryPath: String
    public var args: [String]
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, binaryPath: String, args: [String] = [], isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.binaryPath = binaryPath
        self.args = args
        self.isEnabled = isEnabled
    }
}

@MainActor
public final class AgentRegistryStore {
    private let defaults: UserDefaults
    private let key = "agentRegistry"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [AgentConfig] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AgentConfig].self, from: data)) ?? []
    }

    public func save(_ configs: [AgentConfig]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        defaults.set(data, forKey: key)
    }
}
