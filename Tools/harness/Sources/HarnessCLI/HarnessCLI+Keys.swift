#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation
import HarnessCore

extension HarnessCLI {
    static func handleBindKey(_ args: [String]) throws {
        // Usage: harness-cli bind-key [-T <table>] <spec> <command source>
        let (table, positional) = parseKeyTableArgs(args)
        guard positional.count >= 2 else {
            fputs("Usage: harness-cli bind-key [-T <table>] <spec> <command...>\n", harnessStderr)
            exit(1)
        }
        let spec = positional[0]
        let source = positional.dropFirst().joined(separator: " ")
        guard let parsedSpec = KeySpec.parse(spec) else {
            fputs("Invalid key spec: \(spec)\n", harnessStderr)
            exit(1)
        }
        let command = try CommandParser.parse(source)
        var set = KeybindingsStore.load()
        set.setBinding(table: KeyTableID(rawValue: table), binding: Binding(spec: parsedSpec, command: command))
        let url = try KeybindingsStore.save(set)
        print(url.path)
    }

    static func handleUnbindKey(_ args: [String]) throws {
        let (table, positional) = parseKeyTableArgs(args)
        guard let spec = positional.first, let parsedSpec = KeySpec.parse(spec) else {
            fputs("Usage: harness-cli unbind-key [-T <table>] <spec>\n", harnessStderr)
            exit(1)
        }
        var set = KeybindingsStore.load()
        set.removeBinding(table: KeyTableID(rawValue: table), spec: parsedSpec)
        let url = try KeybindingsStore.save(set)
        print(url.path)
    }

    static func handleListKeys(_ args: [String]) throws {
        let tableFlag = flagValue(args, flag: "-T")
        let set = KeybindingsStore.load()
        let chosen: [KeyTable] = tableFlag.map {
            [set.table(KeyTableID(rawValue: CommandParser.canonicalTableName($0)))].compactMap { $0 }
        } ?? set.tableList
        for table in chosen {
            print("[\(table.id.rawValue)]")
            for binding in table.bindings {
                let note = binding.note.map { "  -- \($0)" } ?? ""
                print("  \(binding.spec.description)\t\(binding.command.shortDescription)\(note)")
            }
        }
    }

    static func parseKeyTableArgs(_ args: [String]) -> (table: String, positional: [String]) {
        let explicitTable = flagValue(args, flag: "-T")
        let table = explicitTable ?? "prefix"
        // Drop the subcommand at index 0; keep every other token so the command source can itself
        // contain flags (e.g. `new-window -h`).
        var positional = Array(args.dropFirst())
        positional.removeAll { $0 == "-T" }
        // Only strip the table token when it came from an explicit `-T <table>`; never when it's the
        // implicit default, or a literal key spec equal to "prefix" would be eaten.
        if explicitTable != nil, let i = positional.firstIndex(of: table) { positional.remove(at: i) }
        // tmux's `copy-mode-vi` is Harness's `copy-mode` — same mapping the parser
        // applies, so a CLI bind never lands in a phantom table no client consults.
        return (CommandParser.canonicalTableName(table), positional)
    }
}
