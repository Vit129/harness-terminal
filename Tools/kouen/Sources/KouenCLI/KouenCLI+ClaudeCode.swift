import Foundation
import KouenCore
import KouenIPC

extension KouenCLI {
    /// `kouen cc run "<prompt>" [--cwd <path>] [--profile edit|readonly] [--model <name>]
    ///                          [--effort low|medium|high|xhigh|max] [--no-wait]`
    /// `kouen cc status <runId>`
    /// `kouen cc list`
    /// `kouen cc cancel <runId>`
    ///
    /// Direct terminal path to the Claude Code Harness (`ClaudeCodeHarness`) — same IPC
    /// requests `kouenCCRun`/`kouenCCStatus` (kouen-mcp) send, no MCP/AI-agent needed.
    static func handleClaudeCode(_ args: [String], client: DaemonClient) throws {
        guard let sub = args.first else {
            printClaudeCodeUsage()
            exit(1)
        }
        switch sub {
        case "run":
            try handleClaudeCodeRun(Array(args.dropFirst()), client: client)
        case "status":
            guard let runId = args.dropFirst().first, let id = UUID(uuidString: runId) else {
                fputs("Usage: kouen cc status <runId>\n", kouenStderr)
                exit(1)
            }
            try printClaudeCodeRun(id: id, client: client)
        case "list":
            try printClaudeCodeList(client: client)
        case "cancel":
            guard let runId = args.dropFirst().first, let id = UUID(uuidString: runId) else {
                fputs("Usage: kouen cc cancel <runId>\n", kouenStderr)
                exit(1)
            }
            _ = try checkedRequest(client, .ccRunCancel(id: id))
            print("cancelled: \(id.uuidString)")
        default:
            printClaudeCodeUsage()
            exit(1)
        }
    }

    private static func printClaudeCodeUsage() {
        fputs("""
        Usage:
          kouen cc run "<prompt>" [--cwd <path>] [--profile edit|readonly] [--model <name>] [--effort <level>] [--no-wait]
          kouen cc status <runId>
          kouen cc list
          kouen cc cancel <runId>
        \n
        """, kouenStderr)
    }

    private static func handleClaudeCodeRun(_ args: [String], client: DaemonClient) throws {
        guard let prompt = args.first, !prompt.hasPrefix("--") else {
            printClaudeCodeUsage()
            exit(1)
        }
        let cwd = flagValue(args, flag: "--cwd") ?? FileManager.default.currentDirectoryPath
        let profile = flagValue(args, flag: "--profile")
        let model = flagValue(args, flag: "--model")
        let effort = flagValue(args, flag: "--effort")
        let noWait = args.contains("--no-wait")

        let id = UUID()
        guard case .ccRunInfo = try checkedRequest(client, .ccRunStart(
            id: id, prompt: prompt, cwd: cwd, profile: profile ?? "edit", model: model, effort: effort
        )) else {
            fputs("cc run: unexpected response starting the run\n", kouenStderr)
            exit(1)
        }
        print("started: \(id.uuidString)")
        guard !noWait else { return }

        for _ in 0 ..< 1800 { // up to 3 minutes
            guard case let .ccRunInfo(summary?) = try checkedRequest(client, .ccRunGet(id: id)) else { break }
            if summary.state != "running" {
                printSummary(summary)
                exit(summary.state == "succeeded" ? 0 : 1)
            }
            usleep(100_000)
        }
        fputs("cc run: timed out waiting for a terminal state; check with `kouen cc status \(id.uuidString)`\n", kouenStderr)
        exit(1)
    }

    private static func printClaudeCodeRun(id: UUID, client: DaemonClient) throws {
        guard case let .ccRunInfo(summary) = try checkedRequest(client, .ccRunGet(id: id)) else {
            fputs("cc status: unexpected response\n", kouenStderr)
            exit(1)
        }
        guard let summary else {
            fputs("cc status: run not found: \(id.uuidString)\n", kouenStderr)
            exit(1)
        }
        printSummary(summary)
    }

    private static func printClaudeCodeList(client: DaemonClient) throws {
        guard case let .ccRuns(runs) = try checkedRequest(client, .ccRunList) else {
            fputs("cc list: unexpected response\n", kouenStderr)
            exit(1)
        }
        if runs.isEmpty { print("no runs"); return }
        for run in runs { printSummary(run) }
    }

    private static func printSummary(_ summary: ClaudeRunSummary) {
        print("\(summary.id.uuidString)  \(summary.state)  \(summary.cwd)")
        if let text = summary.lastAssistantText, summary.state == "running" { print("  ↳ \(text)") }
        if let result = summary.resultText { print("  result: \(result)") }
        if let cost = summary.totalCostUSD { print("  cost: $\(cost)") }
    }
}
