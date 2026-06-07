import Foundation
import HarnessCore

/// Registry of MCP tools exposed to agents.
struct ToolRegistry: Sendable {
    func listTools() -> AnyCodable {
        .object(["tools": .array([
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

    // MARK: - Terminal tools

    private func runCommand(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
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
}
