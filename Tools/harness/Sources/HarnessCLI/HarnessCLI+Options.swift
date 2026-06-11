#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation
import HarnessCore

extension HarnessCLI {
    static func handleSetOption(_ args: [String], defaultScope: String, client: DaemonClient) throws {
        // Usage: set-option [-g|-w|-s|-t|-p] [-T <target>] <key> <value>
        var scope = defaultScope
        if args.contains("-g") { scope = "global" }
        if args.contains("-w") { scope = "workspace" }
        if args.contains("-s") { scope = "session" }
        if args.contains("-t") { scope = "tab" }
        if args.contains("-p") { scope = "pane" }
        var target = flagValue(args, flag: "-T")
        // Scoped options resolve by exact target — a nil-target workspace/session/tab/pane
        // entry is stored but unreachable by every read path (the fallback chain only widens
        // toward global). Without -T, resolve the target from the calling pane
        // ($HARNESS_SURFACE — tmux: scoped sets apply to the current window); outside
        // a Harness pane, require -T instead of silently writing a dead option.
        if scope != "global", target == nil {
            target = callingPaneTarget(scope: scope, client: client)
        }
        if scope != "global", target == nil {
            fputs("set-option: \(scope) scope requires -T <target> (or run inside a Harness pane)\n", harnessStderr)
            exit(1)
        }
        // `positionalArgs` skips the subcommand at index 0 plus `-T <target>` (and any
        // lone scope flags), so `<key>` isn't mis-read as the subcommand name.
        let positional = positionalArgs(args, skippingValuesFor: ["-T"])
        guard positional.count >= 2 else {
            fputs("Usage: harness-cli set-option [-g|-w|-s|-t|-p] [-T <target>] <key> <value>\n", harnessStderr)
            exit(1)
        }
        let key = positional[0]
        let value = positional.dropFirst().joined(separator: " ")
        _ = try checkedRequest(client, .setOption(scope: scope, target: target, key: key, rawValue: value))
    }

    /// The calling pane's workspace/session/tab/pane ID for a scoped option write —
    /// the CLI's "focus" when it runs inside a Harness pane ($HARNESS_SURFACE).
    /// nil outside a pane or when the surface is gone from the snapshot.
    static func callingPaneTarget(scope: String, client: DaemonClient) -> String? {
        guard let surface = ProcessInfo.processInfo.environment["HARNESS_SURFACE"],
              let surfaceID = UUID(uuidString: surface),
              case let .snapshot(snapshot)? = try? client.request(.getSnapshot, timeout: 2)
        else { return nil }
        for workspace in snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs where tab.rootPane.allSurfaceIDs().contains(surfaceID) {
                    switch scope {
                    case "workspace": return workspace.id.uuidString
                    case "session": return session.id.uuidString
                    case "tab": return tab.id.uuidString
                    case "pane":
                        return tab.rootPane.allLeaves().first { $0.surfaceID == surfaceID }?.id.uuidString
                    default: return nil
                    }
                }
            }
        }
        return nil
    }

    static func handleShowOptions(_ args: [String], client: DaemonClient) throws {
        var scope: String?
        if args.contains("-g") { scope = "global" }
        if args.contains("-w") { scope = "workspace" }
        if args.contains("-s") { scope = "session" }
        if args.contains("-t") { scope = "tab" }
        if args.contains("-p") { scope = "pane" }
        let response = try checkedRequest(client, .showOptions(scope: scope))
        guard case let .options(items) = response else { throw DaemonClientError.unexpectedResponse }
        let sorted = items.sorted(by: { $0.key < $1.key })
        try emit(sorted, args) {
            for item in sorted {
                let prefix = item.target.map { "\(item.scope):\($0)" } ?? item.scope
                print("\(prefix)\t\(item.key)\t\(item.value)")
            }
        }
    }

    static func requireSessionID(_ nameOrID: String, client: DaemonClient, command: String) throws -> SessionID {
        if let session = resolveSession(try snapshot(client), nameOrID: nameOrID) { return session.id }
        fputs("\(command): no session matches '\(nameOrID)'\n", harnessStderr)
        exit(1)
    }

    static func handleSetEnvironment(_ args: [String], client: DaemonClient) throws {
        // Usage: set-environment [-g] [-u] [-s <session name|uuid>] <key> [value]
        // -g = global (default when no -s); -u = unset; -s targets a session.
        let global = args.contains("-g")
        let unset = args.contains("-u")
        // A dangling `-s` (last token, no value) collapses to nil in flagValue, which would
        // bypass requireSessionID and fall through to the GLOBAL environment — the exact
        // secret-leak fail-open requireSessionID's own comment forbids. Reject it loudly.
        if !global, flagIsDangling(args, flag: "-s") {
            fputs("set-environment: -s requires a <session name|uuid>\n", harnessStderr)
            exit(1)
        }
        let sessionRaw = global ? nil : flagValue(args, flag: "-s")
        let sessionID = try sessionRaw.map { try requireSessionID($0, client: client, command: "set-environment") }
        // `positionalArgs` skips the subcommand at index 0 plus `-s <session>` (and lone
        // flags like `-g`/`-u`), so `<key>` isn't mis-read as the subcommand name.
        let positional = positionalArgs(args, skippingValuesFor: ["-s"])
        guard let key = positional.first else {
            fputs("Usage: harness-cli set-environment [-g] [-u] [-s <session name|uuid>] <key> [value]\n", harnessStderr)
            exit(1)
        }
        let value = unset ? nil : positional.dropFirst().joined(separator: " ")
        _ = try checkedRequest(client, .setEnvironment(sessionID: sessionID, key: key, value: value))
    }

    static func handleShowEnvironment(_ args: [String], client: DaemonClient) throws {
        // Same dangling-`-s` guard as set-environment: a truncated `-s` must not silently
        // read the global environment instead of the intended session's.
        if !args.contains("-g"), flagIsDangling(args, flag: "-s") {
            fputs("show-environment: -s requires a <session name|uuid>\n", harnessStderr)
            exit(1)
        }
        let sessionRaw = args.contains("-g") ? nil : flagValue(args, flag: "-s")
        let sessionID = try sessionRaw.map { try requireSessionID($0, client: client, command: "show-environment") }
        let response = try checkedRequest(client, .showEnvironment(sessionID: sessionID))
        guard case let .options(items) = response else { throw DaemonClientError.unexpectedResponse }
        try emit(items, args) {
            for item in items {
                print("\(item.key)=\(item.value)")
            }
        }
    }
}
