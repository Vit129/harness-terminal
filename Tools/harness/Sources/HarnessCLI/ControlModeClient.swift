import Foundation
import HarnessCore

/// Control mode (`harness-cli -CC` / `control-mode`): the tmux control protocol
/// over stdin/stdout, so external tools (terminal emulators, scripts) can drive
/// Harness programmatically. Commands arrive one-per-line on stdin; each runs
/// through the shared `CommandIPCTranslator` and is wrapped in a `%begin/%end`
/// block. Live pane output is emitted as `%output`, and layout changes as
/// `%layout-change`. EOF emits `%exit`.
///
/// This is the same verb vocabulary as the GUI and compositor — control mode is
/// just another front-end onto `Command` → IPC.
enum ControlModeClient {
    static func run(client: DaemonClient) throws -> Int32 {
        _ = try? client.request(.identifyClient(label: "harness-cli -CC"), timeout: 1)
        let writer = Writer()
        var commandNumber = 0

        // Async: layout-change notifications via the snapshot push.
        let snapshotSub = try? client.subscribeSnapshot(label: "-CC", onRevision: { _ in
            writer.line("%layout-change")
        }, onEnd: {
            writer.line("%exit")
        })

        // Async: stream every current surface's output as %output.
        var outputSubs: [DaemonSubscription] = []
        if case let .surfaces(surfaces)? = try? client.request(.listSurfaces, timeout: 2) {
            for (index, surface) in surfaces.enumerated() {
                let paneRef = "%\(index)"
                if let sub = try? client.subscribeSurfaceOutput(surfaceID: surface.surfaceID, label: "-CC", onData: { data, _ in
                    writer.line("%output \(paneRef) \(escape(data))")
                }, onEnd: {}) {
                    outputSubs.append(sub)
                }
            }
        }
        defer {
            snapshotSub?.cancel()
            outputSubs.forEach { $0.cancel() }
        }

        // Command loop on stdin.
        while let line = readLine(strippingNewline: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            commandNumber += 1
            let stamp = Int(Date().timeIntervalSince1970)
            writer.line("%begin \(stamp) \(commandNumber) 1")
            do {
                let output = try runCommand(trimmed, client: client)
                if !output.isEmpty { writer.raw(output.hasSuffix("\n") ? output : output + "\n") }
                writer.line("%end \(stamp) \(commandNumber) 1")
            } catch {
                writer.line("\(error)")
                writer.line("%error \(stamp) \(commandNumber) 1")
            }
        }

        writer.line("%exit")
        return 0
    }

    /// Parse one control-mode command line, translate it, and run it. Returns any
    /// textual output (e.g. from `capture-pane`/`list-*`).
    private static func runCommand(_ source: String, client: DaemonClient) throws -> String {
        // A few queries map directly to IPC for richer output.
        let words = source.split(separator: " ").map(String.init)
        switch words.first {
        case "list-sessions", "ls":
            guard case let .snapshot(snapshot)? = try? client.request(.getSnapshot, timeout: 2) else { return "" }
            return SnapshotQueryFormatter.sessions(snapshot).joined(separator: "\n")
        case "list-windows", "lsw":
            guard case let .snapshot(snapshot)? = try? client.request(.getSnapshot, timeout: 2) else { return "" }
            return SnapshotQueryFormatter.windows(snapshot).joined(separator: "\n")
        case "list-panes", "lsp":
            guard case let .snapshot(snapshot)? = try? client.request(.getSnapshot, timeout: 2),
                  let tab = snapshot.activeWorkspace?.activeTab else { return "" }
            return SnapshotQueryFormatter.panes(in: tab).joined(separator: "\n")
        default:
            break
        }

        // Everything else: parse → translate against the active target → run.
        let command = try CommandParser.parse(source)
        guard case let .snapshot(snapshot)? = try? client.request(.getSnapshot, timeout: 2) else {
            throw ControlModeError.noSnapshot
        }
        let target = CommandTarget(snapshot: snapshot)
        let (baseIndex, paneBaseIndex) = indexBases(client: client)
        switch CommandIPCTranslator.translate(command, target: target, baseIndex: baseIndex, paneBaseIndex: paneBaseIndex) {
        case let .requests(requests):
            var output = ""
            for request in requests {
                switch try? client.request(request, timeout: 3) {
                case let .text(text)?: output += text
                // Daemon validation errors become a %error block — a dropped .error
                // would read as success to anything parsing the control protocol.
                case let .error(message)?: throw ControlModeError.daemon(message)
                default: break
                }
            }
            return output
        case let .clientLocal(local):
            // Show verbs print their query results as control-mode lines; UI-only
            // verbs (overlays, modes) have no control-mode output.
            return try showVerbOutput(local, client: client) ?? ""
        case .unresolved:
            throw ControlModeError.unresolved
        }
    }

    /// Render the config/buffer/hook show verbs as text lines (the control-mode analog of
    /// the GUI message overlay and the compositor status flash).
    private static func showVerbOutput(_ command: Command, client: DaemonClient) throws -> String? {
        switch command {
        case let .showOptions(scope):
            guard case let .options(items)? = try? client.request(.showOptions(scope: scope), timeout: 3) else { return nil }
            return items.map { "\($0.scope)\($0.target.map { "(\($0))" } ?? "") \($0.key) = \($0.value)" }
                .joined(separator: "\n")
        case let .showEnvironment(global):
            // Control mode has no focused session; non-global reads fall back to global too.
            _ = global
            guard case let .options(items)? = try? client.request(.showEnvironment(sessionID: nil), timeout: 3) else { return nil }
            return items.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        case .listBuffers:
            guard case let .buffers(buffers)? = try? client.request(.listBuffers, timeout: 3) else { return nil }
            return buffers.map { "\($0.name): \($0.byteCount) bytes: \"\($0.preview)\"" }.joined(separator: "\n")
        case let .showBuffer(name):
            // A missing buffer reports like the GUI/compositor ("no such buffer"),
            // not an empty success block.
            guard case let .buffer(buffer)? = try? client.request(.getBuffer(name: name), timeout: 3) else {
                return "no such buffer"
            }
            return buffer.data.map { String(decoding: $0, as: UTF8.self) } ?? buffer.preview
        case let .showHooks(event):
            guard case let .hooks(hooks)? = try? client.request(.listHooks(event: event), timeout: 3) else { return nil }
            return hooks.map { "\($0.event) → \($0.commandSource) [\($0.id.uuidString)]" }.joined(separator: "\n")
        case let .findWindow(pattern, name, content, title):
            // Only the -C form reaches here (non-content translated to selectTab upstream).
            _ = content
            guard case let .snapshot(snapshot)? = try? client.request(.getSnapshot, timeout: 3) else { return nil }
            let match = FindWindowMatcher.firstMatch(
                snapshot, pattern: pattern, name: name, title: title
            ) { surfaceID in
                guard case let .text(text)? = try? client.request(
                    .capturePane(surfaceID: surfaceID, includeScrollback: false), timeout: 3) else { return nil }
                return text
            }
            // No match is a %error (like the non-content path's .unresolved), not a
            // benign %end a protocol consumer would read as success.
            guard let match else { throw ControlModeError.noMatch(pattern: pattern) }
            _ = try? client.request(.selectTab(workspaceID: match.workspaceID, tabID: match.tabID), timeout: 3)
            return "find-window: focused \(match.tabID.uuidString)"
        default:
            return nil
        }
    }

    /// Read `base-index` / `pane-base-index` from the daemon (default 0) so
    /// `-t session:window.pane` indices match the user's configured base.
    private static func indexBases(client: DaemonClient) -> (Int, Int) {
        guard case let .options(entries)? = try? client.request(.showOptions(scope: nil), timeout: 1) else { return (0, 0) }
        func val(_ key: String) -> Int { entries.first { $0.key == key }.flatMap { Int($0.value) } ?? 0 }
        return (val("base-index"), val("pane-base-index"))
    }

    /// tmux-style escaping for `%output`: octal-escape control and high bytes.
    private static func escape(_ data: Data) -> String {
        var out = ""
        out.reserveCapacity(data.count)
        for byte in data {
            if byte == 0x5c { out += "\\\\" }
            else if byte >= 0x20 && byte < 0x7f { out.unicodeScalars.append(Unicode.Scalar(byte)) }
            else { out += String(format: "\\%03o", byte) }
        }
        return out
    }

    /// Serialize writes to stdout from the async subscription callbacks + the main loop.
    private final class Writer: @unchecked Sendable {
        private let lock = NSLock()
        func line(_ string: String) { raw(string + "\n") }
        func raw(_ string: String) {
            lock.lock(); defer { lock.unlock() }
            FileHandle.standardOutput.write(Data(string.utf8))
        }
    }

    enum ControlModeError: Error, CustomStringConvertible {
        case noSnapshot, unresolved
        case daemon(String)
        case noMatch(pattern: String)
        var description: String {
            switch self {
            case .noSnapshot: return "could not read session snapshot"
            case .unresolved: return "command had no resolvable target"
            case let .daemon(message): return message
            case let .noMatch(pattern): return "find-window: no matches for '\(pattern)'"
            }
        }
    }
}
