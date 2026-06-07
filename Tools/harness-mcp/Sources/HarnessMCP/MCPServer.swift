import Foundation
import HarnessCore

/// MCP (Model Context Protocol) server for Harness. Speaks JSON-RPC 2.0 over
/// stdin/stdout so AI agents (Claude Code, Codex, Kiro) can use Harness as a
/// tool provider — reading files, running commands, querying git.
actor MCPServer {
    private let transport = StdioTransport()
    private let tools = ToolRegistry()

    func run() async {
        for await message in transport.incoming {
            let response = await handle(message)
            if let response {
                transport.send(response)
            }
        }
    }

    private func handle(_ message: ACPMessage) async -> ACPMessage? {
        switch message {
        case let .request(id, method, params):
            let (result, error) = await dispatch(method: method, params: params)
            return .response(id: id, result: result, error: error)
        case .notification:
            return nil
        case .response:
            return nil
        }
    }

    private func dispatch(method: String, params: AnyCodable?) async -> (AnyCodable?, JSONRPCError?) {
        switch method {
        case "initialize":
            return (initializeResult(), nil)
        case "initialized":
            return (AnyCodable.null, nil)
        case "tools/list":
            return (tools.listTools(), nil)
        case "tools/call":
            return await tools.callTool(params: params)
        case "shutdown":
            return (AnyCodable.null, nil)
        default:
            return (nil, JSONRPCError(code: -32601, message: "Method not found: \(method)"))
        }
    }

    private func initializeResult() -> AnyCodable {
        .object([
            "protocolVersion": .string("2024-11-05"),
            "capabilities": .object([
                "tools": .object([:]),
            ]),
            "serverInfo": .object([
                "name": .string("harness-mcp"),
                "version": .string(HarnessVersion.short),
            ]),
        ])
    }
}
