import Foundation

public struct LSPServerConfiguration: Equatable, Sendable {
    public var language: String
    public var executablePath: String
    public var arguments: [String]
    public var rootURL: URL

    public init(language: String, executablePath: String, arguments: [String], rootURL: URL) {
        self.language = language
        self.executablePath = executablePath
        self.arguments = arguments
        self.rootURL = rootURL
    }
}

public struct LSPSettings: Codable, Equatable, Sendable {
    public var autoStart: Bool
    public var servers: [String: String]

    public init(autoStart: Bool = true, servers: [String: String] = [:]) {
        self.autoStart = autoStart
        self.servers = servers
    }
}

public struct LSPServerRegistry {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func configuration(forFile fileURL: URL, settings: LSPSettings = LSPSettings()) -> LSPServerConfiguration? {
        guard settings.autoStart else { return nil }
        let rootURL = projectRoot(containing: fileURL) ?? fileURL.deletingLastPathComponent()
        let ext = fileURL.pathExtension.lowercased()

        if hasFile("Package.swift", in: rootURL) || ext == "swift" {
            return config(language: "swift", binary: settings.servers["swift"] ?? "sourcekit-lsp", args: [], root: rootURL)
        }
        if hasFile("package.json", in: rootURL) || ["ts", "tsx", "js", "jsx"].contains(ext) {
            let binary = settings.servers["typescript"] ?? settings.servers["javascript"] ?? "typescript-language-server"
            return config(language: "typescript", binary: binary, args: ["--stdio"], root: rootURL)
        }
        if hasFile("pyproject.toml", in: rootURL) || hasFile("requirements.txt", in: rootURL) || ext == "py" {
            return config(language: "python", binary: settings.servers["python"] ?? "pyright-langserver", args: ["--stdio"], root: rootURL)
        }
        if hasFile("Cargo.toml", in: rootURL) || ext == "rs" {
            return config(language: "rust", binary: settings.servers["rust"] ?? "rust-analyzer", args: [], root: rootURL)
        }
        if hasFile("go.mod", in: rootURL) || ext == "go" {
            return config(language: "go", binary: settings.servers["go"] ?? "gopls", args: [], root: rootURL)
        }
        return nil
    }

    private func config(language: String, binary: String, args: [String], root: URL) -> LSPServerConfiguration {
        LSPServerConfiguration(language: language, executablePath: resolve(binary), arguments: args, rootURL: root)
    }

    private func projectRoot(containing fileURL: URL) -> URL? {
        var url = fileURL.hasDirectoryPath ? fileURL : fileURL.deletingLastPathComponent()
        while url.path != "/" {
            if hasFile(".git", in: url)
                || hasFile("Package.swift", in: url)
                || hasFile("package.json", in: url)
                || hasFile("pyproject.toml", in: url)
                || hasFile("Cargo.toml", in: url)
                || hasFile("go.mod", in: url) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    private func hasFile(_ name: String, in directory: URL) -> Bool {
        fileManager.fileExists(atPath: directory.appendingPathComponent(name).path)
    }

    private func resolve(_ binary: String) -> String {
        if binary.hasPrefix("/") || binary.hasPrefix("~") {
            return (binary as NSString).expandingTildeInPath
        }
        let candidates = [
            "/opt/homebrew/bin/\(binary)",
            "/usr/local/bin/\(binary)",
            "/usr/bin/\(binary)",
        ]
        return candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) ?? binary
    }
}
