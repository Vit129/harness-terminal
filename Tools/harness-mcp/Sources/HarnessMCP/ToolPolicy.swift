import Foundation
import HarnessCore

/// Persisted allowlist for MCP tools that can mutate files, run processes, or control panes.
struct ToolPolicy: Sendable {
    static let fileName = "mcp-policy.json"
    static let controlGateVariable = HarnessDaemonTools.controlGateVariable

    static var defaultURL: URL {
        HarnessPaths.applicationSupport.appendingPathComponent(fileName)
    }

    static let dangerousTools: Set<String> = [
        "writeFile",
        "runCommand",
        "sendPaneText",
        "sendPaneKeys",
        "spawnSession",
        "splitPane",
        "closePane",
    ]

    private let allowControl: Bool
    private let allowedTools: Set<String>
    private let environment: [String: String]

    init(
        allowControl: Bool = false,
        allowedTools: Set<String> = [],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.allowControl = allowControl
        self.allowedTools = allowedTools
        self.environment = environment
    }

    static func load(
        from url: URL = defaultURL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ToolPolicy {
        guard let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(Document.self, from: data)
        else {
            return ToolPolicy(environment: environment)
        }
        return ToolPolicy(
            allowControl: document.allowControl ?? false,
            allowedTools: Set(document.allowedTools ?? []),
            environment: environment
        )
    }

    func isToolAllowed(_ toolName: String) -> Bool {
        guard Self.dangerousTools.contains(toolName) else { return true }
        if environment[Self.controlGateVariable] == "1" { return true }
        return allowControl || allowedTools.contains(toolName)
    }

    func disabledError(for toolName: String) -> JSONRPCError {
        JSONRPCError(
            code: -32000,
            message: "Harness MCP tool '\(toolName)' is disabled; allow it in \(Self.defaultURL.path) or set \(Self.controlGateVariable)=1"
        )
    }

    private struct Document: Decodable {
        var version: Int?
        var allowControl: Bool?
        var allowedTools: [String]?
        var workspaceOverrides: [String: [String: String]]?
    }
}
