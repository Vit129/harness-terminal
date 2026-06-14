#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation
import HarnessCore
import HarnessTheme

@main
struct HarnessCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            printUsage()
            exit(1)
        }
        do {
            switch command {
            case "color-check":
                printColorCheck(args)
                return
            case "theme-preview":
                printThemePreview(args)
                return
            case "view":
                exit(Int32(handleView(args)))
            case "lsp":
                exit(Int32(handleLSP(args)))
            case "remote":
                exit(try handleRemote(args))
            case "daemon":
                runDaemonForeground() // execs HarnessDaemon; never returns
            case "version", "--version", "-v":
                printVersion(args) // best-effort daemon query; works with the daemon down
                return
            default:
                break
            }

            let client = try makeClient(args)
            switch command {
            case "list-workspaces":
                try printWorkspaces(args, client: client)
            case "list-surfaces":
                try printSurfaces(args, client: client)
            case "list-sessions":
                try printSessions(args, client: client)
            case "list-agents":
                try printAgents(args, client: client)
            case "doctor":
                try runDoctor(args, client: client)   // exits with its own status
            case "completions":
                try printCompletions(args)
            case "list-windows":
                try printWindows(args, client: client)
            case "list-panes":
                try printPanes(args, client: client)
            case "has-session":
                try handleHasSession(args, client: client)   // exits with status, prints nothing
            case "list-commands":
                CommandParser.knownVerbs.forEach { print($0) }
            case "get-snapshot":
                try printSnapshot(client)
            case "new-workspace":
                let name = flagValue(args, flag: "--name") ?? "Workspace"
                let response = try checkedRequest(client, .newWorkspace(name: name))
                if case let .workspaceID(id) = response { print(id.uuidString) }
            case "new-session":
                try handleNewSession(args, client: client)
            case "new-tab":
                try handleNewTab(args, client: client)
            case "new-split":
                try handleNewSplit(args, client: client)
            case "select-workspace":
                try handleSelectWorkspace(args, client: client)
            case "select-tab":
                try handleSelectTab(args, client: client)
            case "select-session":
                try handleSelectSession(args, client: client)
            case "close-tab":
                guard let tabID = UUID(uuidString: flagValue(args, flag: "--tab") ?? "") else {
                    fputs("Usage: harness-cli close-tab --tab <uuid>\n", harnessStderr)
                    exit(1)
                }
                _ = try checkedRequest(client, .closeTab(tabID: tabID))
            case "close-session":
                guard let sessionID = UUID(uuidString: flagValue(args, flag: "--session") ?? "") else {
                    fputs("Usage: harness-cli close-session --session <uuid>\n", harnessStderr)
                    exit(1)
                }
                _ = try checkedRequest(client, .closeSession(sessionID: sessionID))
            case "promote-session", "demote-session":
                guard let sessionID = UUID(uuidString: flagValue(args, flag: "--session") ?? "") else {
                    fputs("Usage: harness-cli \(command) --session <uuid>\n", harnessStderr)
                    exit(1)
                }
                // Promote pins a session to survive a clean quit even in Plain mode; demote
                // makes it ephemeral again.
                _ = try checkedRequest(client, .setSessionPersistent(sessionID: sessionID, persistent: command == "promote-session"))
            case "send":
                guard let surface = flagValue(args, flag: "--surface"),
                      let text = flagValue(args, flag: "--text")
                else {
                    fputs("Usage: harness-cli send --surface <uuid> --text \"...\"\n", harnessStderr)
                    exit(1)
                }
                _ = try checkedRequest(client, .send(surfaceID: surface, text: text))
            case "notify":
                guard let surface = flagValue(args, flag: "--surface") else {
                    fputs("Usage: harness-cli notify --surface <uuid> [--title t] [--body b] [--from-hook]\n", harnessStderr)
                    exit(1)
                }
                let title = flagValue(args, flag: "--title") ?? "Agent"
                let fallbackBody = flagValue(args, flag: "--body") ?? flagValue(args, flag: "--message")
                // `--from-hook`: read the agent's notification payload (JSON) from stdin and use
                // its `message` for the body. Gated behind the flag (like `set-buffer --stdin`)
                // so an interactive `notify` never blocks on `readDataToEndOfFile`. Claude Code's
                // `Notification` hook delivers the message this way — not via an env var.
                // Both paths resolve through HookNotificationParser so the default body lives in
                // one place; only `--from-hook` reads stdin, otherwise we resolve with no payload.
                let parsed = args.contains("--from-hook")
                    ? HookNotificationParser.parse(FileHandle.standardInput.readDataToEndOfFile())
                    : nil
                let body = HookNotificationParser.resolveBody(parsed: parsed, fallbackBody: fallbackBody)
                _ = try checkedRequest(client, .notify(surfaceID: surface, title: title, body: body))
            case "install":
                try installCLI()
            case "ping":
                let response = try checkedRequest(client, .ping)
                print(response)
            case "send-keys":
                try handleSendKeys(args, client: client)
            case "capture-pane":
                try handleCapturePane(args, client: client)
            case "pipe-pane":
                try handlePipePane(args, client: client)
            case "wait-for", "wait":
                try handleWaitFor(args, client: client)
            case "link-window":
                try handleLinkWindow(args, client: client)
            case "unlink-window":
                try handleUnlinkWindow(args, client: client)
            case "control-mode", "-CC":
                exit(try ControlModeClient.run(client: client))
            case "kill-server":
                handleKillServer(args)
            case "start-server":
                handleStartServer(args, client: client)
            case "show-messages":
                if case let .text(log) = try checkedRequest(client, .showMessages) {
                    print(log.isEmpty ? "no messages" : log)
                }
            case "kill-pane":
                try handlePaneCommand(args, client: client) { paneID in .killPane(paneID: paneID) }
            case "swap-pane":
                try handleSwapPane(args, client: client)
            case "resize-pane":
                try handleResizePane(args, client: client)
            case "zoom-pane":
                try handlePaneCommand(args, client: client) { paneID in .zoomPane(paneID: paneID) }
            case "copy-mode":
                try handleCopyMode(args, client: client)
            case "rename-tab":
                try handleRenameTab(args, client: client)
            case "rename-session":
                try handleRenameSession(args, client: client)
            case "rename-workspace":
                try handleRenameWorkspace(args, client: client)
            case "detect-agent":
                try handleDetectAgent(args, client: client)
            case "install-hooks":
                try handleInstallHooks(args)
            case "install-shell-integration":
                handleInstallShellIntegration(args)
            case "attach":
                let code = try handleAttach(args)
                exit(code)
            case "attach-window":
                #if canImport(HarnessTerminalKit)
                let code = try handleAttachWindow(args)
                exit(code)
                #else
                // The window compositor needs the Metal/AppKit terminal kit, which isn't built on
                // headless/Linux. Single-pane `attach` still works there.
                fputs("harness-cli attach-window: not supported on this platform; use `attach`\n", harnessStderr)
                exit(64)
                #endif
            case "record":
                exit(handleRecord(args, client: client))
            case "replay":
                exit(handleReplay(args))
            case "daemon-stats":
                try printDaemonStats(args, client: client)
            case "list-clients":
                try printClients(args, client: client)
            case "detach-client":
                try handleDetachClient(args, client: client)
            case "bind-key", "bind":
                try handleBindKey(args)
            case "unbind-key", "unbind":
                try handleUnbindKey(args)
            case "list-keys":
                try handleListKeys(args)
            case "set-buffer":
                try handleSetBuffer(args, client: client)
            case "list-buffers":
                try handleListBuffers(args, client: client)
            case "show-buffer":
                try handleShowBuffer(args, client: client)
            case "delete-buffer":
                try handleDeleteBuffer(args, client: client)
            case "paste-buffer":
                try handlePasteBuffer(args, client: client)
            case "save-buffer":
                try handleSaveBuffer(args, client: client)
            case "load-buffer":
                try handleLoadBuffer(args, client: client)
            case "select-layout":
                try handleSelectLayout(args, client: client)
            case "next-layout":
                try handleCycleLayout(args, client: client, forward: true)
            case "previous-layout":
                try handleCycleLayout(args, client: client, forward: false)
            case "rotate-window":
                try handleRotateWindow(args, client: client)
            case "break-pane":
                try handleBreakPane(args, client: client)
            case "join-pane":
                try handleJoinPane(args, client: client)
            case "move-pane":
                try handleMovePane(args, client: client)
            case "renumber-windows":
                try handleRenumberWindows(args, client: client)
            case "respawn-pane":
                try handleRespawnPane(args, client: client)
            case "select-pane":
                try handleSelectPane(args, client: client)
            case "set-option":
                try handleSetOption(args, defaultScope: "global", client: client)
            case "setw", "set-window-option":
                // tmux `setw` is a WINDOW option — same default the bindable parser
                // uses, so a sourced `.tmux.conf` line and the CLI write the same scope.
                try handleSetOption(args, defaultScope: "tab", client: client)
            case "show-options":
                try handleShowOptions(args, client: client)
            case "set-environment", "setenv":
                try handleSetEnvironment(args, client: client)
            case "show-environment", "showenv":
                try handleShowEnvironment(args, client: client)
            case "bind-hook":
                try handleBindHook(args, client: client)
            case "unbind-hook":
                try handleUnbindHook(args, client: client)
            case "list-hooks":
                try handleListHooks(args, client: client)
            case "display-message":
                try handleDisplayMessage(args, client: client)
            default:
                printUsage()
                exit(1)
            }
        } catch {
            fputs("harness-cli: \(error)\n", harnessStderr)
            exit(1)
        }
    }

    static func flagValue(_ args: [String], flag: String) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static func flagIsDangling(_ args: [String], flag: String) -> Bool {
        guard let index = args.firstIndex(of: flag) else { return false }
        return index + 1 >= args.count
    }

    static func optionalUUIDFlag(_ args: [String], flag: String) -> OptionalUUID {
        guard let raw = flagValue(args, flag: flag) else {
            // nil means either absent or present-but-dangling; only the latter is an error.
            return flagIsDangling(args, flag: flag) ? .dangling : .absent
        }
        guard let id = UUID(uuidString: raw) else { return .invalid(raw) }
        return .valid(id)
    }

    static func checkedRequest(_ client: DaemonClient, _ request: IPCRequest, timeout: TimeInterval = 2) throws -> IPCResponse {
        let response = try client.request(request, timeout: timeout)
        if case let .error(message) = response {
            throw DaemonSessionError.daemonError(message)
        }
        return response
    }

    static func emit<T: Encodable>(_ payload: T, _ args: [String], text: () -> Void) throws {
        if args.contains("--json") {
            print(try JSONOutputFormatter.encode(payload, pretty: args.contains("--pretty")))
        } else {
            text()
        }
    }

    static func positionalArgs(_ args: [String], skippingValuesFor flags: Set<String>) -> [String] {
        var out: [String] = []
        var i = 1  // index 0 is the subcommand
        while i < args.count {
            let a = args[i]
            if flags.contains(a) { i += 2; continue }   // flag + its value
            if a.hasPrefix("-") { i += 1; continue }
            out.append(a); i += 1
        }
        return out
    }

    static func makeClient(_ args: [String]) throws -> DaemonClient {
        DaemonClient(endpoint: try resolveEndpoint(args))
    }

    static func resolveEndpoint(_ args: [String]) throws -> Endpoint {
        guard let hostName = flagValue(args, flag: "--host") else { return .localControlSocket }
        guard let host = RemoteHostStore().host(named: hostName) else {
            fputs("harness-cli: unknown --host '\(hostName)'. Add it with `harness-cli remote add`.\n", harnessStderr)
            exit(64)
        }
        return try SSHTunnelManager.shared.endpoint(for: host)
    }

    static func resolvedCLIPath() -> String {
        Bundle.main.executablePath ?? CommandLine.arguments.first ?? "harness-cli"
    }

    static func parseDetachSequence(_ raw: String) -> [UInt8]? {
        let tokens = raw.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        var bytes: [UInt8] = []
        for token in tokens {
            if token.hasPrefix("0x"), let value = UInt8(token.dropFirst(2), radix: 16) {
                bytes.append(value)
            } else if let value = UInt8(token) {
                bytes.append(value)
            } else if token.count == 3, token.hasPrefix("C-") || token.hasPrefix("c-") {
                guard let last = token.last,
                      let ch = last.uppercased().first,
                      let scalar = ch.asciiValue else { return nil }
                bytes.append(scalar & 0x1f)
            } else if token.count == 1, let scalar = token.first?.asciiValue {
                bytes.append(scalar)
            } else {
                return nil
            }
        }
        return bytes.isEmpty ? nil : bytes
    }

    static func resolveDetachSequence(_ args: [String]) -> DetachKeys {
        guard let raw = flagValue(args, flag: "--detach-keys") else {
            // A dangling `--detach-keys` (last token, no value) must not silently keep the default:
            // the user asked for a custom sequence and would otherwise get a different one.
            if flagIsDangling(args, flag: "--detach-keys") {
                return .invalid("harness-cli: --detach-keys requires a value "
                    + "('C-a d', '0x01 0x64', or comma-separated decimal bytes).\n")
            }
            return .absent
        }
        guard let parsed = parseDetachSequence(raw) else {
            return .invalid(
                "harness-cli: invalid --detach-keys '\(raw)'. "
                + "Use 'C-a d', '0x01 0x64', or comma-separated decimal bytes.\n")
        }
        return .parsed(parsed)
    }

    static func installCLI() throws {
        let source = CLIInstallLocator.sourceBinary()
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw DaemonSessionError.daemonError("harness-cli binary not found at \(source.path)")
        }
        let dest = HarnessPaths.applicationSupport.appendingPathComponent("bin/harness-cli")
        try HarnessPaths.ensureDirectories()
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try copyExecutable(source: source, destination: dest)
        print(dest.path)
        print("export PATH=\"\(dest.deletingLastPathComponent().path):$PATH\"")
        // Install the daemon as a managed service so it survives reboot/logout: launchd on macOS,
        // systemd --user on Linux. The same flow works on a headless box.
        let installer = ServiceInstallers.current
        if let daemon = locateDaemonBinary() {
            do {
                let installedDaemon = HarnessPaths.applicationSupport.appendingPathComponent("bin/HarnessDaemon")
                try copyExecutable(source: daemon, destination: installedDaemon)
                print("daemon: \(installedDaemon.path)")
                let report = try installer.install(daemonPath: installedDaemon, harnessHome: HarnessPaths.applicationSupport)
                print("service (\(installer.backendName)): \(report.unitPath.path)")
            } catch {
                fputs("warning: \(installer.backendName) install failed: \(error)\n", harnessStderr)
            }
        } else {
            fputs("warning: HarnessDaemon binary not found; service not installed\n", harnessStderr)
        }
        // Shell completions for the user's login shell, so they work out of the box: fish drops
        // into its auto-load dir; zsh/bash get a guarded, backed-up, idempotent `source` block
        // wired into the rc (the same mechanism as install-shell-integration). Any shell can also
        // regenerate the script on demand with `harness-cli completions <shell>`.
        do {
            for line in try ShellCompletionInstaller.installForLoginShell() { print(line) }
        } catch {
            fputs("warning: shell completion install failed: \(error)\n", harnessStderr)
        }
        print("Tip: run 'harness-cli install-shell-integration' to enable OSC 133 prompt marks, "
            + "the success/failure gutter, and prompt jumping.")
    }

    static func copyExecutable(source: URL, destination: URL) throws {
        try BinaryRefresher.copyExecutable(from: source, to: destination)
    }

    static func locateDaemonBinary() -> URL? {
        if let override = ProcessInfo.processInfo.environment["HARNESS_DAEMON_PATH"],
           !override.isEmpty, FileManager.default.fileExists(atPath: override) {
            return URL(fileURLWithPath: override)
        }
        let cli = CLIInstallLocator.sourceBinary()
        let candidate = cli.deletingLastPathComponent().appendingPathComponent("HarnessDaemon")
        if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        // The copy `install` placed under the Harness home.
        let installed = HarnessPaths.applicationSupport.appendingPathComponent("bin/HarnessDaemon")
        if FileManager.default.fileExists(atPath: installed.path) { return installed }
        // The installed macOS app bundle (no-op on Linux).
        let appCandidate = URL(fileURLWithPath: "/Applications/Harness.app/Contents/MacOS/HarnessDaemon")
        if FileManager.default.fileExists(atPath: appCandidate.path) { return appCandidate }
        return nil
    }

    enum DetachKeys: Equatable {
        case absent
        case parsed([UInt8])
        case invalid(String)
    }

    enum OptionalUUID: Equatable {
        case absent
        case valid(UUID)
        case invalid(String)
        case dangling
    }
}

enum CLIInstallLocator {
    static func sourceBinary() -> URL {
        if let exe = Bundle.main.executableURL {
            return exe
        }
        return URL(fileURLWithPath: CommandLine.arguments[0])
    }
}
