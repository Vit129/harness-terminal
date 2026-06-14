import Foundation
import HarnessCore
import HarnessLSP

private final class AsyncCLIResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Int, Error>?

    func set(_ result: Result<Int, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func get() -> Result<Int, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}

private struct LSPStatusPayload: Codable {
    var status: String
    var server: String?
    var root: String
    var note: String?
}

private struct LSPDefinitionPayload: Codable {
    var locations: [String]
}

private struct LSPDiagnosticsPayload: Codable {
    var diagnostics: [LSPDiagnostic]
}

extension HarnessCLI {
    static func handleLSP(_ args: [String]) -> Int {
        guard args.count >= 2 else {
            fputs("Usage: harness-cli lsp <start|status|hover|definition|diagnostics> ...\n", harnessStderr)
            return 64
        }
        return runAsyncCLI {
            try await handleLSPAsync(args)
        }
    }

    private static func runAsyncCLI(_ operation: @escaping @Sendable () async throws -> Int) -> Int {
        let semaphore = DispatchSemaphore(value: 0)
        let box = AsyncCLIResultBox()
        Task {
            do {
                box.set(.success(try await operation()))
            } catch {
                box.set(.failure(error))
            }
            semaphore.signal()
        }
        semaphore.wait()
        switch box.get() {
        case .success(let code): return code
        case .failure(let error):
            fputs("harness-cli lsp: \(error)\n", harnessStderr)
            return 1
        case nil:
            return 1
        }
    }

    private static func handleLSPAsync(_ args: [String]) async throws -> Int {
        switch args[1] {
        case "start":
            return try await handleLSPStart(args)
        case "status":
            return try handleLSPStatus(args)
        case "hover":
            return try await handleLSPHover(args)
        case "definition":
            return try await handleLSPDefinition(args)
        case "diagnostics":
            return try await handleLSPDiagnostics(args)
        default:
            fputs("Usage: harness-cli lsp <start|status|hover|definition|diagnostics> ...\n", harnessStderr)
            return 64
        }
    }

    private static func handleLSPStart(_ args: [String]) async throws -> Int {
        let path = positionalArgs(args, skippingValuesFor: ["--lang"]).dropFirst(1).first
            ?? FileManager.default.currentDirectoryPath
        guard let configuration = lspConfiguration(path: path, lang: flagValue(args, flag: "--lang")) else {
            fputs("harness-cli lsp start: no language server configured for \(path)\n", harnessStderr)
            return 1
        }
        let client = LSPClient()
        defer { Task { await client.shutdown() } }
        try await client.launch(configuration: configuration)
        try await client.initialize(rootURL: configuration.rootURL)
        let payload = LSPStatusPayload(
            status: "started",
            server: (configuration.executablePath as NSString).lastPathComponent,
            root: configuration.rootURL.path,
            note: "CLI-process-local; server is stopped when this command exits"
        )
        try emit(payload, args) {
            print("started \(payload.server ?? configuration.executablePath) at \(payload.root) (process-local)")
        }
        return 0
    }

    private static func handleLSPStatus(_ args: [String]) throws -> Int {
        let payload = LSPStatusPayload(
            status: "not_running",
            server: nil,
            root: FileManager.default.currentDirectoryPath,
            note: "No daemon-persistent LSP lifecycle is implemented; CLI commands launch servers per invocation"
        )
        try emit(payload, args) {
            print("not running (CLI LSP servers are process-local)")
        }
        return 0
    }

    private static func handleLSPHover(_ args: [String]) async throws -> Int {
        guard let location = parseLocationArgument(args) else {
            fputs("Usage: harness-cli lsp hover <file>:<line>:<col> [--json]\n", harnessStderr)
            return 64
        }
        let (client, configuration, text) = try await openLSPDocument(location.fileURL)
        defer { Task { await client.shutdown() } }
        _ = text
        let hover = try await client.hover(url: location.fileURL, position: location.position)
        if args.contains("--json") {
            print(try JSONOutputFormatter.encode(hover, pretty: args.contains("--pretty")))
        } else if let text = hover?.plainText, !text.isEmpty {
            print(text)
        } else {
            print("No hover information.")
        }
        _ = configuration
        return 0
    }

    private static func handleLSPDefinition(_ args: [String]) async throws -> Int {
        guard let location = parseLocationArgument(args) else {
            fputs("Usage: harness-cli lsp definition <file>:<line>:<col> [--json]\n", harnessStderr)
            return 64
        }
        let (client, _, _) = try await openLSPDocument(location.fileURL)
        defer { Task { await client.shutdown() } }
        let definitions = try await client.definition(url: location.fileURL, position: location.position)
        let lines = definitions.compactMap(formatLocation)
        try emit(LSPDefinitionPayload(locations: lines), args) {
            if lines.isEmpty {
                print("No definition found.")
            } else {
                lines.forEach { print($0) }
            }
        }
        return 0
    }

    private static func handleLSPDiagnostics(_ args: [String]) async throws -> Int {
        let files = positionalArgs(args, skippingValuesFor: []).dropFirst(1)
        guard let path = files.first else {
            fputs("Usage: harness-cli lsp diagnostics <file> [--json]\n", harnessStderr)
            return 64
        }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        let (client, _, _) = try await openLSPDocument(url)
        defer { Task { await client.shutdown() } }
        let diagnostics = await firstDiagnostics(from: client, matching: url, timeoutNanoseconds: 2_000_000_000)
        try emit(LSPDiagnosticsPayload(diagnostics: diagnostics), args) {
            if diagnostics.isEmpty {
                print("No diagnostics.")
            } else {
                for diagnostic in diagnostics {
                    let line = diagnostic.range.start.line + 1
                    let column = diagnostic.range.start.character + 1
                    print("\(url.path):\(line):\(column): \(diagnostic.message)")
                }
            }
        }
        return 0
    }

    private static func parseLocationArgument(_ args: [String]) -> LSPTextLocation? {
        let values = positionalArgs(args, skippingValuesFor: []).dropFirst(1)
        guard let raw = values.first else { return nil }
        return LSPTextLocationParser.parse(raw)
    }

    private static func openLSPDocument(_ url: URL) async throws -> (LSPClient, LSPServerConfiguration, String) {
        guard let configuration = LSPServerRegistry().configuration(forFile: url) else {
            throw LSPClientError.requestFailed("no language server configured for \(url.path)")
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        let client = LSPClient()
        try await client.launch(configuration: configuration)
        try await client.initialize(rootURL: configuration.rootURL)
        try await client.openDocument(url: url, languageID: languageID(for: url, fallback: configuration.language), text: text)
        return (client, configuration, text)
    }

    private static func lspConfiguration(path: String, lang: String?) -> LSPServerConfiguration? {
        let expanded = (path as NSString).expandingTildeInPath
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory)
        let inputURL = URL(fileURLWithPath: expanded).standardizedFileURL
        let fileURL: URL
        if let lang {
            let root = (exists && isDirectory.boolValue) ? inputURL : inputURL.deletingLastPathComponent()
            fileURL = root.appendingPathComponent("HarnessLSPProbe.\(extensionForLanguage(lang))")
        } else {
            fileURL = (exists && isDirectory.boolValue) ? inputURL.appendingPathComponent("HarnessLSPProbe") : inputURL
        }
        return LSPServerRegistry().configuration(forFile: fileURL)
    }

    private static func extensionForLanguage(_ lang: String) -> String {
        switch lang.lowercased() {
        case "swift": return "swift"
        case "python", "py": return "py"
        case "typescript", "ts": return "ts"
        case "javascript", "js": return "js"
        case "rust", "rs": return "rs"
        case "go": return "go"
        default: return lang
        }
    }

    private static func languageID(for url: URL, fallback: String) -> String {
        switch url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "py": return "python"
        case "ts", "tsx": return "typescript"
        case "js", "jsx": return "javascript"
        case "rs": return "rust"
        case "go": return "go"
        default: return fallback
        }
    }

    private static func firstDiagnostics(from client: LSPClient, matching url: URL, timeoutNanoseconds: UInt64) async -> [LSPDiagnostic] {
        await withTaskGroup(of: [LSPDiagnostic]?.self) { group in
            group.addTask {
                for await message in await client.incomingMessages {
                    guard case let .notification(method, params) = message,
                          method == "textDocument/publishDiagnostics",
                          let diagnostics = decodeDiagnostics(from: params, matching: url)
                    else { continue }
                    return diagnostics
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result ?? []
        }
    }

    private static func decodeDiagnostics(from params: AnyCodable?, matching url: URL) -> [LSPDiagnostic]? {
        guard case let .object(object)? = params,
              case let .string(uri)? = object["uri"],
              uri == url.absoluteString,
              let rawDiagnostics = object["diagnostics"],
              let data = try? JSONEncoder().encode(rawDiagnostics)
        else { return nil }
        return try? JSONDecoder().decode([LSPDiagnostic].self, from: data)
    }

    private static func formatLocation(_ location: LSPLocation) -> String? {
        guard let url = URL(string: location.uri), url.isFileURL else { return nil }
        return "\(url.path):\(location.range.start.line + 1):\(location.range.start.character + 1)"
    }
}
