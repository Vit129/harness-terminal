import Foundation
import KouenCore

/// Drives the `claude` (Claude Code) CLI as a real subprocess — `-p --output-format
/// stream-json` — instead of the pty-pane screen-scrape `kouenSpawnAgent` uses. Built to
/// replace the shelved ACP integration's motivation for Claude Code specifically: no
/// adapter binary (spawns the user's own `claude` install), tool control via
/// `--allowedTools`/`--disallowedTools` (see `Profile`), and a PATH-resolution fix for the
/// launchd-minimal-PATH problem that broke ACP (see `resolveClaudeBinary`).
///
/// One-shot only in this version: a run is prompt-in, result-out. Mid-run steering stays
/// the pty pane's job (`kouenSpawnAgent`); a follow-up turn is a new `start()` call with
/// `resumeSessionID` set to a prior run's id. See `agent-memory/plans/claude-code-harness/
/// design.md` for the full design and the empirical verification behind these choices.
public actor ClaudeCodeHarness {
    public enum Profile: String, Sendable {
        case readonly
        case edit
    }

    public enum RunState: String, Codable, Sendable {
        case running
        case succeeded
        case failed
        case cancelled
    }

    public struct RunSummary: Codable, Sendable, Equatable {
        public var id: UUID
        public var state: RunState
        public var cwd: String
        public var startedAt: Date
        public var lastAssistantText: String?
        public var resultText: String?
        public var totalCostUSD: Double?
        public var exitCode: Int32?
    }

    private struct Run {
        var summary: RunSummary
        let process: Process
        var stdoutBuffer = Data()
    }

    private var runs: [UUID: Run] = [:]
    private var cachedClaudeBinaryPath: String?
    private let transcriptsDirectory: URL

    public init() {
        transcriptsDirectory = KouenPaths.applicationSupport.appendingPathComponent("claude-runs", isDirectory: true)
        try? FileManager.default.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    @discardableResult
    public func start(
        id: UUID,
        prompt: String,
        cwd: String,
        profile: Profile,
        model: String?,
        resumeSessionID: UUID?
    ) async -> RunSummary {
        let summary = RunSummary(id: id, state: .running, cwd: cwd, startedAt: Date())

        guard let claudePath = await resolveClaudeBinary() else {
            var failed = summary
            failed.state = .failed
            failed.resultText = "claude binary not found on PATH"
            return failed
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = buildArguments(
            id: id, prompt: prompt, profile: profile, model: model, resumeSessionID: resumeSessionID
        )
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        var env = ProcessInfo.processInfo.environment
        if let path = await resolvedPATH() { env["PATH"] = path }
        process.environment = env

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe() // drained, not surfaced — stream-json on stdout carries everything needed

        let transcriptURL = transcriptsDirectory.appendingPathComponent("\(id.uuidString).jsonl")
        FileManager.default.createFile(atPath: transcriptURL.path, contents: nil)
        let transcriptHandle = try? FileHandle(forWritingTo: transcriptURL)

        runs[id] = Run(summary: summary, process: process)

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            transcriptHandle?.write(chunk)
            Task { await self?.consume(chunk, forRun: id) }
        }

        process.terminationHandler = { [weak self] proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            try? transcriptHandle?.close()
            Task { await self?.finish(id: id, exitCode: proc.terminationStatus) }
        }

        do {
            try process.run()
        } catch {
            var failed = summary
            failed.state = .failed
            failed.resultText = "failed to launch claude: \(error.localizedDescription)"
            runs[id] = nil
            return failed
        }

        return summary
    }

    public func get(id: UUID) -> RunSummary? {
        runs[id]?.summary
    }

    public func list() -> [RunSummary] {
        runs.values.map(\.summary).sorted { $0.startedAt < $1.startedAt }
    }

    public func cancel(id: UUID) -> Bool {
        guard let run = runs[id], run.summary.state == .running else { return false }
        run.process.terminate()
        runs[id]?.summary.state = .cancelled
        return true
    }

    // MARK: - Argument construction

    /// `readonly`: no writes, no Bash — analysis/review only. `edit`: Edit/Write allowed,
    /// a git-readonly Bash allowlist, `rm`/`sudo`/`git push` explicitly denied. Never
    /// `bypassPermissions` — headless mode has no UI to answer prompts, so the allowlist
    /// is the entire security boundary. `--setting-sources ""` skips the user's global
    /// CLAUDE.md + hooks (measured ~83% cache-creation-token cut) without touching OAuth
    /// auth the way `--bare` does — see design.md's "Cost/context overhead control".
    private func buildArguments(
        id: UUID, prompt: String, profile: Profile, model: String?, resumeSessionID: UUID?
    ) -> [String] {
        var args = ["-p", prompt, "--output-format", "stream-json", "--verbose", "--setting-sources", ""]
        if let resumeSessionID {
            args += ["--resume", resumeSessionID.uuidString]
        } else {
            args += ["--session-id", id.uuidString]
        }
        switch profile {
        case .readonly:
            args += ["--permission-mode", "dontAsk", "--allowedTools", "Read", "Glob", "Grep", "Task", "WebFetch"]
        case .edit:
            args += [
                "--permission-mode", "acceptEdits",
                "--allowedTools", "Read", "Glob", "Grep", "Task", "Edit", "Write",
                "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)",
                "--disallowedTools", "Bash(rm:*)", "Bash(sudo:*)", "Bash(git push:*)",
            ]
        }
        if let model { args += ["--model", model] }
        return args
    }

    // MARK: - Stream-json parsing

    /// Decodes only the two line shapes the harness needs (`type: "assistant"` for a live
    /// preview, `type: "result"` for the terminal outcome) — the raw JSONL transcript
    /// keeps full fidelity on disk, so nothing else needs modeling in Swift.
    private struct AssistantLine: Decodable {
        struct Message: Decodable {
            struct Content: Decodable { var type: String; var text: String? }
            var content: [Content]
        }
        var type: String
        var message: Message
    }

    private struct ResultLine: Decodable {
        var type: String
        var is_error: Bool
        var result: String?
        var total_cost_usd: Double?
    }

    private func consume(_ chunk: Data, forRun id: UUID) {
        guard var run = runs[id] else { return }
        run.stdoutBuffer.append(chunk)
        while let newlineRange = run.stdoutBuffer.range(of: Data([0x0A])) {
            let lineData = run.stdoutBuffer.subdata(in: run.stdoutBuffer.startIndex..<newlineRange.lowerBound)
            run.stdoutBuffer.removeSubrange(run.stdoutBuffer.startIndex..<newlineRange.upperBound)
            parseLine(lineData, into: &run.summary)
        }
        runs[id] = run
    }

    /// `internal` (not `private`) so `ClaudeCodeHarnessTests` can exercise it directly via
    /// `@testable import` against real captured stream-json fixtures, without spawning an
    /// actual `claude` process.
    func parseLine(_ lineData: Data, into summary: inout RunSummary) {
        guard !lineData.isEmpty else { return }
        if let assistant = try? JSONDecoder().decode(AssistantLine.self, from: lineData), assistant.type == "assistant" {
            if let text = assistant.message.content.first(where: { $0.type == "text" })?.text {
                summary.lastAssistantText = text
            }
        } else if let result = try? JSONDecoder().decode(ResultLine.self, from: lineData), result.type == "result" {
            summary.resultText = result.result
            summary.totalCostUSD = result.total_cost_usd
            summary.state = result.is_error ? .failed : .succeeded
        }
    }

    private func finish(id: UUID, exitCode: Int32) {
        guard var run = runs[id] else { return }
        run.summary.exitCode = exitCode
        // A `result` line normally already set state; a process that exits without one
        // (crash, killed) falls back to exit-code interpretation here.
        if run.summary.state == .running {
            run.summary.state = exitCode == 0 ? .succeeded : .failed
        }
        runs[id] = run
    }

    // MARK: - Binary / PATH resolution

    /// `claude` is a zsh *function* in interactive shells (injects `-n <dirname>`), not a
    /// directly executable path — plain `which`/`command -v` under a non-login shell won't
    /// resolve it. `whence -p` (zsh) / `type -P` (bash) finds the real binary. Probed once
    /// per daemon lifetime and cached; this is also what fixes the launchd-minimal-PATH
    /// problem that shelved the ACP integration (`Kouen.entitlements` has App Sandbox off,
    /// so it was never a sandbox restriction — just a PATH one).
    private func resolveClaudeBinary() async -> String? {
        if let cachedClaudeBinaryPath { return cachedClaudeBinaryPath }
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let probeCommand = shellPath.hasSuffix("zsh") ? "whence -p claude" : "type -P claude"
        if let resolved = await runProbe(shellPath: shellPath, command: probeCommand) {
            cachedClaudeBinaryPath = resolved
            return resolved
        }
        for candidate in ["~/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"] {
            let expanded = (candidate as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expanded) {
                cachedClaudeBinaryPath = expanded
                return expanded
            }
        }
        return nil
    }

    private func resolvedPATH() async -> String? {
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        return await runProbe(shellPath: shellPath, command: "echo $PATH")
    }

    private func runProbe(shellPath: String, command: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shellPath)
            process.arguments = ["-l", "-c", command]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: (output?.isEmpty ?? true) ? nil : output)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
