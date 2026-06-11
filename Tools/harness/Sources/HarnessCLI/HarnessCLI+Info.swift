#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation
import HarnessCore
import HarnessTheme

extension HarnessCLI {
    static func printVersion(_ args: [String]) {
        struct VersionReport: Encodable {
            var cliVersion: String
            var cliBuild: Int
            var daemonVersion: String?
            var daemonBuild: Int?
            var daemonRunning: Bool
        }
        var report = VersionReport(
            cliVersion: HarnessVersion.short,
            cliBuild: HarnessVersion.build,
            daemonVersion: nil,
            daemonBuild: nil,
            daemonRunning: false
        )
        if let client = try? makeClient(args),
           let response = try? client.request(.daemonStats, timeout: 0.3),
           case let .daemonStats(stats) = response {
            report.daemonRunning = true
            report.daemonVersion = stats.version
            report.daemonBuild = stats.build
        }
        if args.contains("--json") {
            if let encoded = try? JSONOutputFormatter.encode(report, pretty: args.contains("--pretty")) {
                print(encoded)
            }
            return
        }
        print("harness-cli \(report.cliVersion) (\(report.cliBuild))")
        if !report.daemonRunning {
            print("daemon: not running")
        } else if let build = report.daemonBuild {
            var line = "daemon: \(report.daemonVersion ?? "?") (\(build))"
            if build != HarnessVersion.build { line += "  [mismatch — restart Harness.app, or run: harness-cli install]" }
            print(line)
        } else {
            print("daemon: running, pre-handshake build (no version reported)")
        }
    }

    static func printColorCheck(_ args: [String]) {
        print(ThemeDiagnostics.colorCheck(), terminator: "")
    }

    static func printThemePreview(_ args: [String]) {
        if args.contains("--all") {
            for (index, theme) in HarnessThemeCatalog.allThemes.enumerated() {
                if index > 0 { print("") }
                print(ThemeDiagnostics.themePreview(theme), terminator: "")
            }
            return
        }

        let themeName = flagValue(args, flag: "--theme") ?? HarnessThemeCatalog.defaultThemeName
        guard let theme = HarnessThemeCatalog.theme(named: themeName) else {
            fputs("Unknown theme: \(themeName)\n", harnessStderr)
            exit(1)
        }
        print(ThemeDiagnostics.themePreview(theme), terminator: "")
    }

    static func printCompletions(_ args: [String]) throws {
        let positional = Array(args.dropFirst()).first { !$0.hasPrefix("-") }
        guard let raw = positional, let shell = ShellIntegration.Shell(rawValue: raw) else {
            fputs("Usage: harness-cli completions <zsh|fish|bash>\n", harnessStderr)
            exit(1)
        }
        print(CompletionGenerator.script(for: shell))
    }

    static func runDoctor(_ args: [String], client: DaemonClient) throws {
        var daemonReachable = false
        if let response = try? client.request(.ping, timeout: 0.3), case .pong = response {
            daemonReachable = true
        }
        var stats: DaemonStats?
        if daemonReachable,
           let response = try? client.request(.daemonStats, timeout: 0.3),
           case let .daemonStats(s) = response {
            stats = s
        }
        let report = DoctorRunner.run(daemonReachable: daemonReachable, cliPath: resolvedCLIPath(), daemonStats: stats)
        if args.contains("--json") {
            print(try JSONOutputFormatter.encode(report, pretty: args.contains("--pretty")))
        } else {
            report.text().forEach { print($0) }
        }
        exit(report.exitCode)
    }

    static func handleDetectAgent(_ args: [String], client: DaemonClient) throws {
        guard let surface = flagValue(args, flag: "--surface") else {
            fputs("Usage: harness-cli detect-agent --surface <id>\n", harnessStderr)
            exit(1)
        }
        let response = try checkedRequest(client, .detectAgent(surfaceID: surface))
        if case let .agentInfo(info) = response, let info {
            print("\(info.kind.rawValue)\t\(info.executable)\t\(info.activity.rawValue)")
        }
    }

    static func handleInstallHooks(_ args: [String]) throws {
        let agent = args.dropFirst().first ?? flagValue(args, flag: "--agent") ?? ""
        AgentHookInstallerCLI.run(agentArg: agent)
    }

    static func handleInstallShellIntegration(_ args: [String]) {
        let arg = (args.dropFirst().first ?? "").lowercased()
        let shells: [ShellIntegration.Shell]
        switch arg {
        case "all":
            shells = ShellIntegration.Shell.allCases
        case "bash", "zsh", "fish":
            shells = [ShellIntegration.Shell(rawValue: arg)!]
        case "":
            guard let detected = ShellIntegration.Shell.detect(from: ProcessInfo.processInfo.environment["SHELL"] ?? "") else {
                fputs("install-shell-integration: couldn't detect your shell from $SHELL — pass one of: bash, zsh, fish, all\n", harnessStderr)
                exit(1)
            }
            shells = [detected]
        default:
            fputs("install-shell-integration: unknown shell \"\(arg)\" (expected bash, zsh, fish, or all)\n", harnessStderr)
            exit(1)
        }
        var failed = false
        for shell in shells {
            do {
                let r = try ShellIntegration.install(shell)
                if let backup = r.rcBackedUp { print("(backed up \(r.rcPath.lastPathComponent) to \(backup.path))") }
                if r.alreadyWired {
                    print("\(shell.rawValue): already wired in \(r.rcPath.path) — refreshed \(r.scriptPath.lastPathComponent)")
                } else {
                    print("\(shell.rawValue): wrote \(r.scriptPath.path) and added it to \(r.rcPath.path)")
                }
            } catch {
                fputs("install-shell-integration: \(shell.rawValue) failed: \(error)\n", harnessStderr)
                failed = true
            }
        }
        print("Restart your shell (or open a new Harness pane) to enable prompt marks, the success/failure gutter, and prompt jumping.")
        if failed { exit(1) }
    }

    static func handleRenameTab(_ args: [String], client: DaemonClient) throws {
        guard let tabStr = flagValue(args, flag: "--tab"), let tabID = UUID(uuidString: tabStr),
              let name = flagValue(args, flag: "--name")
        else {
            fputs("Usage: harness-cli rename-tab --tab <uuid> --name \"...\"\n", harnessStderr)
            exit(1)
        }
        _ = try checkedRequest(client, .renameTab(tabID: tabID, name: name))
    }

    static func handleRenameSession(_ args: [String], client: DaemonClient) throws {
        guard let sessionStr = flagValue(args, flag: "--session"), let sessionID = UUID(uuidString: sessionStr),
              let name = flagValue(args, flag: "--name")
        else {
            fputs("Usage: harness-cli rename-session --session <uuid> --name \"...\"\n", harnessStderr)
            exit(1)
        }
        _ = try checkedRequest(client, .renameSession(sessionID: sessionID, name: name))
    }

    static func handleRenameWorkspace(_ args: [String], client: DaemonClient) throws {
        guard let idStr = flagValue(args, flag: "--id") ?? flagValue(args, flag: "--workspace"),
              let id = UUID(uuidString: idStr),
              let name = flagValue(args, flag: "--name")
        else {
            fputs("Usage: harness-cli rename-workspace --id <uuid> --name \"...\"\n", harnessStderr)
            exit(1)
        }
        _ = try checkedRequest(client, .renameWorkspace(workspaceID: id, name: name))
    }

    static func handleDisplayMessage(_ args: [String], client: DaemonClient) throws {
        // Drop the subcommand at index 0 so it doesn't leak into the format string.
        let format = args.dropFirst().joined(separator: " ")
        guard !format.isEmpty else {
            fputs("Usage: harness-cli display-message <format>\n", harnessStderr)
            exit(1)
        }
        _ = try checkedRequest(client, .displayMessage(format: format))
    }

    static func printUsage() {
        print("""
        harness-cli — control Harness terminal sessions

        List/show commands accept [--json] [--pretty] (compact JSON by default; --pretty indents).

        Commands:
          doctor [--json]                             (diagnose daemon, socket, paths, integrations)
          version [--json]                            (print CLI and daemon versions; flags build mismatch)
          color-check                                  (print ANSI/256/truecolor diagnostic swatches)
          theme-preview [--theme <name>] [--all]       (print deterministic themed sample output)
          completions <zsh|fish|bash>                 (print a shell completion script to stdout)
          list-workspaces [--json] [--pretty]
          list-surfaces [--json] [--pretty]
          list-sessions [--json] [--pretty]
          list-windows [--session <name|uuid>] [--json] [--pretty]
          list-panes [--tab <uuid>] [--json] [--pretty]
          list-agents [--waiting] [--json] [--pretty] (running agents: state, age, surface)
          has-session --session <name|uuid>           (exit 0 if it exists, else 1)
          list-commands
          get-snapshot
          new-workspace --name <name>
          new-session --workspace <name|uuid> [--cwd path] [--name name] [--group-with <session>]
          new-tab --workspace <name|uuid> [--cwd path]
          new-split --tab <uuid> --direction horizontal|vertical [--pane <uuid>]
          select-workspace --workspace <name|uuid>
          select-session --workspace <name|uuid> --session <uuid>
          select-tab --workspace <uuid> --tab <uuid>
          close-tab --tab <uuid>
          close-session --session <uuid>
          promote-session --session <uuid>            (pin: survive a clean quit in Plain mode)
          demote-session --session <uuid>             (unpin: ephemeral again)
          send --surface <uuid> --text "..."
          send-keys --surface <uuid> --keys "C-c Up Enter ..."
          capture-pane --surface <uuid> [--scrollback]
          kill-pane --pane <uuid>
          capture-pane --surface <uuid> [--scrollback] [-S <start>] [-E <end>] [-p]
          pipe-pane --surface <uuid> [<shell-command>]   (omit to stop)
          link-window --tab <uuid> --target-session <uuid>
          unlink-window --tab <uuid>
          control-mode | -CC                             (tmux control protocol over stdio)
          swap-pane --src <uuid> --dst <uuid>
          resize-pane --pane <uuid> --dir L|R|U|D [--amount N]
          zoom-pane --pane <uuid>
          copy-mode --surface <uuid> [--enter|--exit]
          rename-tab --tab <uuid> --name "..."
          rename-session --session <uuid> --name "..."
          rename-workspace --id <uuid> --name "..."
          detect-agent --surface <uuid>
          install-hooks <codex|claude-code|cursor|grok|opencode|pi|hermes|openclaw>
          install-shell-integration [bash|zsh|fish|all]  (OSC 133 prompt marks + gutter)
          attach --surface <uuid> [--detach-keys "C-a d"]
          record --surface <uuid> --output <file> [--display]
          replay <file> [--speed <n>] [--no-timing]
          notify --surface <uuid> [--title t] [--body b] [--from-hook]
          daemon-stats [--json] [--pretty]
          list-clients [--json] [--pretty]
          detach-client --client <uuid>
          bind-key [-T <table>] <spec> <command...>
          unbind-key [-T <table>] <spec>
          list-keys [-T <table>]
          set-buffer (--data <text> | --stdin) [--name <name>]
          list-buffers [--json] [--pretty]
          show-buffer [--name <name>]
          delete-buffer --name <name>
          paste-buffer --surface <uuid> [--name <name>]
          select-layout --tab <uuid> --layout even-horizontal|even-vertical|main-horizontal|main-vertical|tiled
          next-layout --tab <uuid>
          previous-layout --tab <uuid>
          rotate-window --tab <uuid> [--reverse]
          break-pane --pane <uuid>
          join-pane --src <uuid> --dst <uuid> --direction horizontal|vertical
          respawn-pane --surface <id> [--clear-history|-k]
          select-pane --pane <uuid> --dir L|R|U|D
          set-option [-g|-w|-s|-t|-p] [-T target] <key> <value>
          setw <key> <value>   (window option for the calling pane's tab; -T overrides)
          show-options [-g|-w|-s|-t|-p] [--json] [--pretty]
          set-environment [-g] [-u] [-s <sessionID>] <key> [value]
          show-environment [-g] [-s <sessionID>] [--json] [--pretty]
          bind-hook <event> <command...> [--if <format>]
          unbind-hook --id <uuid>
          list-hooks [--event <event>] [--json] [--pretty]
          display-message <format>
          install
          ping
        """)
    }
}
