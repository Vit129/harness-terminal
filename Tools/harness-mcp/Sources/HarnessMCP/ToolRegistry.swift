import Foundation
import HarnessCore

/// Registry of MCP tools exposed to agents.
struct ToolRegistry: Sendable {
    private let policy: ToolPolicy
    private let daemonTools: HarnessDaemonTools

    init(policy: ToolPolicy = ToolPolicy.load()) {
        self.policy = policy
        self.daemonTools = HarnessDaemonTools(
            isToolAllowed: { policy.isToolAllowed($0) },
            disabledError: { policy.disabledError(for: $0) }
        )
    }

    func listTools() -> AnyCodable {
        .object(["tools": .array([
            toolDef("harnessList", "List Harness workspaces, sessions, tabs, and panes", [
                param("includePanes", "boolean", "Include per-tab pane details (optional, default true)"),
                param("includeAgents", "boolean", "Include detected agent info per tab (optional, default true)"),
            ]),
            toolDef("readPaneOutput", "Read recent output from a Harness pane", [
                param("surfaceId", "string", "Surface id from harnessList"),
                param("lines", "number", "Number of lines to read from the bottom (optional, default 200, max 2000)"),
                param("escapeSequences", "boolean", "Return raw output including escape sequences (optional)"),
                param("joinWrapped", "boolean", "Join soft-wrapped lines into their logical line (optional)"),
            ]),
            toolDef("sendPaneText", "Send text to a Harness pane (requires MCP policy allowlist or HARNESS_MCP_ALLOW_CONTROL=1)", [
                param("surfaceId", "string", "Surface id from harnessList"),
                param("text", "string", "Text to send"),
                param("bracketed", "boolean", "Whether text was requested as bracketed paste (optional, currently sent as text)"),
            ]),
            toolDef("sendPaneKeys", "Send key tokens to a Harness pane (requires MCP policy allowlist or HARNESS_MCP_ALLOW_CONTROL=1)", [
                param("surfaceId", "string", "Surface id from harnessList"),
                param("keys", "array", "Key tokens to send"),
            ]),
            toolDef("spawnSession", "Create a new Harness session (requires MCP policy allowlist or HARNESS_MCP_ALLOW_CONTROL=1)", [
                param("workspaceId", "string", "Workspace UUID"),
                param("cwd", "string", "Working directory (optional)"),
                param("name", "string", "Session name (optional)"),
                param("shell", "string", "Shell path (optional)"),
            ]),
            toolDef("splitPane", "Split an existing Harness pane (requires MCP policy allowlist or HARNESS_MCP_ALLOW_CONTROL=1)", [
                param("tabId", "string", "Tab UUID"),
                param("paneId", "string", "Pane UUID"),
                param("direction", "string", "Split direction: right, left, up, or down"),
                param("shell", "string", "Shell path (optional)"),
            ]),
            toolDef("closePane", "Close a Harness pane (requires MCP policy allowlist or HARNESS_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Pane UUID"),
            ]),
            toolDef("waitForPaneOutput", "Wait until a Harness pane emits a target string", [
                param("surfaceId", "string", "Surface id from harnessList"),
                param("pattern", "string", "Target string to match"),
                param("timeoutMs", "number", "Timeout in milliseconds (optional, default 30000)"),
                param("fromNow", "boolean", "Ignore existing scrollback when true (optional, default true)"),
            ]),
            toolDef("readFile", "Read the contents of a file", [
                param("path", "string", "Absolute path to the file"),
            ]),
            toolDef("writeFile", "Write content to a file", [
                param("path", "string", "Absolute path to the file"),
                param("content", "string", "Content to write"),
            ]),
            toolDef("listDirectory", "List files and directories at a path", [
                param("path", "string", "Absolute path to the directory"),
            ]),
            toolDef("runCommand", "Run a shell command and return output", [
                param("command", "string", "The command to execute"),
                param("cwd", "string", "Working directory (optional)"),
            ]),
            toolDef("gitStatus", "Get git status for a repository", [
                param("path", "string", "Path to the git repository"),
            ]),
            toolDef("gitDiff", "Get git diff for a repository", [
                param("path", "string", "Path to the git repository"),
                param("staged", "boolean", "Show staged changes only (optional)"),
            ]),
            toolDef("gitLog", "Get recent git commits", [
                param("path", "string", "Path to the git repository"),
                param("count", "number", "Number of commits (default 10)"),
            ]),
        ])])
    }

    func callTool(params: AnyCodable?) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .object(obj)? = params,
              case let .string(name)? = obj["name"],
              let arguments = obj["arguments"]
        else {
            return (nil, JSONRPCError(code: -32602, message: "Invalid params: expected {name, arguments}"))
        }
        let args: [String: AnyCodable]
        if case let .object(a) = arguments { args = a } else { args = [:] }

        switch name {
        case "harnessList": return await harnessList(args)
        case "readPaneOutput": return await readPaneOutput(args)
        case "sendPaneText": return await sendPaneText(args)
        case "sendPaneKeys": return await sendPaneKeys(args)
        case "spawnSession": return await spawnSession(args)
        case "splitPane": return await splitPane(args)
        case "closePane": return await closePane(args)
        case "waitForPaneOutput": return await waitForPaneOutput(args)
        case "readFile": return await readFile(args)
        case "writeFile": return await writeFile(args)
        case "listDirectory": return await listDirectory(args)
        case "runCommand": return await runCommand(args)
        case "gitStatus": return await gitStatus(args)
        case "gitDiff": return await gitDiff(args)
        case "gitLog": return await gitLog(args)
        default:
            return (nil, JSONRPCError(code: -32602, message: "Unknown tool: \(name)"))
        }
    }

    // MARK: - File tools

    private func readFile(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return (nil, JSONRPCError(code: -32000, message: "Cannot read file: \(path)"))
        }
        return (toolResult(content), nil)
    }

    private func writeFile(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard policy.isToolAllowed("writeFile") else {
            return (nil, policy.disabledError(for: "writeFile"))
        }
        guard case let .string(path)? = args["path"],
              case let .string(content)? = args["content"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' or 'content' parameter"))
        }
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return (toolResult("Written \(content.count) bytes to \(path)"), nil)
        } catch {
            return (nil, JSONRPCError(code: -32000, message: "Write failed: \(error.localizedDescription)"))
        }
    }

    private func listDirectory(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return (nil, JSONRPCError(code: -32000, message: "Cannot list directory: \(path)"))
        }
        let listing = entries.sorted().joined(separator: "\n")
        return (toolResult(listing), nil)
    }

    // MARK: - Harness daemon tools

    private func harnessList(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        let includePanes = boolArg(args["includePanes"], default: true)
        let includeAgents = boolArg(args["includeAgents"], default: true)
        return await daemonTools.harnessList(includePanes: includePanes, includeAgents: includeAgents)
    }

    private func readPaneOutput(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' parameter"))
        }
        let lines: Int?
        if case let .int(n)? = args["lines"] { lines = n } else { lines = nil }
        let escapeSequences = boolArg(args["escapeSequences"], default: false)
        let joinWrapped = boolArg(args["joinWrapped"], default: false)
        return await daemonTools.readPaneOutput(
            surfaceId: surfaceId,
            lines: lines,
            escapeSequences: escapeSequences,
            joinWrapped: joinWrapped
        )
    }

    private func sendPaneText(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"],
              case let .string(text)? = args["text"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' or 'text' parameter"))
        }
        let bracketed = boolArg(args["bracketed"], default: false)
        return await daemonTools.sendPaneText(surfaceId: surfaceId, text: text, bracketed: bracketed)
    }

    private func sendPaneKeys(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"],
              case let .array(keysValue)? = args["keys"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' or 'keys' parameter"))
        }
        let keys = keysValue.compactMap { value -> String? in
            if case let .string(key) = value { return key }
            return nil
        }
        guard keys.count == keysValue.count else {
            return (nil, JSONRPCError(code: -32602, message: "'keys' must be an array of strings"))
        }
        return await daemonTools.sendPaneKeys(surfaceId: surfaceId, keys: keys)
    }

    private func spawnSession(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(workspaceId)? = args["workspaceId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'workspaceId' parameter"))
        }
        return await daemonTools.spawnSession(
            workspaceId: workspaceId,
            cwd: optionalStringArg(args["cwd"]),
            name: optionalStringArg(args["name"]),
            shell: optionalStringArg(args["shell"])
        )
    }

    private func splitPane(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(tabId)? = args["tabId"],
              case let .string(paneId)? = args["paneId"],
              case let .string(direction)? = args["direction"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'tabId', 'paneId', or 'direction' parameter"))
        }
        return await daemonTools.splitPane(
            tabId: tabId,
            paneId: paneId,
            direction: direction,
            shell: optionalStringArg(args["shell"])
        )
    }

    private func closePane(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        return await daemonTools.closePane(paneId: paneId)
    }

    private func waitForPaneOutput(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"],
              case let .string(pattern)? = args["pattern"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' or 'pattern' parameter"))
        }
        let timeoutMs: Int?
        if case let .int(n)? = args["timeoutMs"] { timeoutMs = n } else { timeoutMs = nil }
        let fromNow = boolArg(args["fromNow"], default: true)
        return await daemonTools.waitForPaneOutput(
            surfaceId: surfaceId,
            pattern: pattern,
            timeoutMs: timeoutMs,
            fromNow: fromNow
        )
    }

    // MARK: - Terminal tools

    private func runCommand(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard policy.isToolAllowed("runCommand") else {
            return (nil, policy.disabledError(for: "runCommand"))
        }
        guard case let .string(command)? = args["command"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'command' parameter"))
        }
        let cwd: String?
        if case let .string(c)? = args["cwd"] { cwd = c } else { cwd = nil }

        let (stdout, stderr, code) = await shell(command, cwd: cwd)
        return (.object([
            "content": .array([.object([
                "type": .string("text"),
                "text": .string(code == 0 ? stdout : "exit \(code)\n\(stderr)\n\(stdout)"),
            ])]),
        ]), nil)
    }

    // MARK: - Git tools

    private func gitStatus(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        let (out, _, _) = await shell("git status --short", cwd: path)
        return (toolResult(out.isEmpty ? "Working tree clean" : out), nil)
    }

    private func gitDiff(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        let staged = args["staged"] == .bool(true)
        let cmd = staged ? "git diff --cached" : "git diff"
        let (out, _, _) = await shell(cmd, cwd: path)
        return (toolResult(out.isEmpty ? "No changes" : out), nil)
    }

    private func gitLog(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        let count: Int
        if case let .int(n)? = args["count"] { count = n } else { count = 10 }
        let (out, _, _) = await shell("git log --oneline -\(count)", cwd: path)
        return (toolResult(out.isEmpty ? "No commits" : out), nil)
    }

    // MARK: - Helpers

    private func shell(_ command: String, cwd: String?) async -> (String, String, Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", command]
                if let cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
                let outPipe = Pipe(); let errPipe = Pipe()
                process.standardOutput = outPipe; process.standardError = errPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: (out, err, process.terminationStatus))
                } catch {
                    continuation.resume(returning: ("", error.localizedDescription, -1))
                }
            }
        }
    }

    private func toolResult(_ text: String) -> AnyCodable {
        .object([
            "content": .array([.object([
                "type": .string("text"),
                "text": .string(text),
            ])]),
        ])
    }

    private func toolDef(_ name: String, _ description: String, _ properties: [AnyCodable]) -> AnyCodable {
        var props: [String: AnyCodable] = [:]
        var required: [AnyCodable] = []
        for prop in properties {
            if case let .object(p) = prop,
               case let .string(n)? = p["name"],
               case let .string(t)? = p["type"] {
                props[n] = .object(["type": .string(t), "description": p["description"] ?? .string("")])
                if !(isOptionalParam(p["description"])) {
                    required.append(.string(n))
                }
            }
        }
        return .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object(props),
                "required": .array(required),
            ]),
        ])
    }

    private func param(_ name: String, _ type: String, _ description: String) -> AnyCodable {
        .object(["name": .string(name), "type": .string(type), "description": .string(description)])
    }

    private func isOptionalParam(_ value: AnyCodable?) -> Bool {
        guard case let .string(desc)? = value else { return false }
        return desc.contains("optional")
    }

    private func boolArg(_ value: AnyCodable?, default defaultValue: Bool) -> Bool {
        guard case let .bool(b)? = value else { return defaultValue }
        return b
    }

    private func optionalStringArg(_ value: AnyCodable?) -> String? {
        guard case let .string(s)? = value else { return nil }
        return s
    }
}
