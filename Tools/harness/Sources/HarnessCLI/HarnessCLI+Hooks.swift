#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation
import HarnessCore

extension HarnessCLI {
    static func handleBindHook(_ args: [String], client: DaemonClient) throws {
        // Drop the subcommand (`bind-hook`) at index 0: `<event> <command...> [--if <format>]`.
        guard let parsed = parseBindHook(Array(args.dropFirst())) else {
            fputs("Usage: harness-cli bind-hook <event> <command...> [--if <format>]\n", harnessStderr)
            exit(1)
        }
        let response = try checkedRequest(
            client, .bindHook(event: parsed.event, source: parsed.source, condition: parsed.condition))
        if case let .hookID(id) = response { print(id.uuidString) }
    }

    /// Parse `<event> <command...> [--if <format>]` (the args after the `bind-hook` subcommand).
    /// Returns nil for any malformed shape so the caller can print usage once:
    ///   - fewer than two tokens (no command);
    ///   - `--if` at index 0 (no event) or index 1 (empty command) — the latter also closes the
    ///     `rest[1..<ifIndex]` crash where `ifIndex < 1` slices an inverted range and traps.
    static func parseBindHook(_ rest: [String]) -> (event: String, source: String, condition: String?)? {
        guard rest.count >= 2 else { return nil }
        let event = rest[0]
        let ifIndex = rest.firstIndex(of: "--if")
        if let ifIndex {
            // Need an event (index 0) and at least one command token before `--if` (index >= 2),
            // plus a format token after it.
            guard ifIndex > 1, rest.count > ifIndex + 1 else { return nil }
            return (event, rest[1..<ifIndex].joined(separator: " "), rest[ifIndex + 1])
        }
        return (event, rest.dropFirst().joined(separator: " "), nil)
    }

    static func handleUnbindHook(_ args: [String], client: DaemonClient) throws {
        guard let raw = flagValue(args, flag: "--id"), let id = UUID(uuidString: raw) else {
            fputs("Usage: harness-cli unbind-hook --id <uuid>\n", harnessStderr)
            exit(1)
        }
        _ = try checkedRequest(client, .unbindHook(id: id))
    }

    static func handleListHooks(_ args: [String], client: DaemonClient) throws {
        let event = flagValue(args, flag: "--event")
        let response = try checkedRequest(client, .listHooks(event: event))
        guard case let .hooks(items) = response else { throw DaemonClientError.unexpectedResponse }
        try emit(items, args) {
            for item in items {
                let cond = item.condition.map { " if '\($0)'" } ?? ""
                print("\(item.id.uuidString)\t\(item.event)\t\(item.commandSource)\(cond)")
            }
        }
    }
}
