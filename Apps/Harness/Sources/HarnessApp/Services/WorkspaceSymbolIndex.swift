import Foundation

/// Scans workspace files and extracts identifiers for local completion.
/// Runs off-main. Debounced rescan on file changes.
@MainActor
final class WorkspaceSymbolIndex {
    private(set) var symbols: Set<String> = []
    private(set) var currentFileSymbols: Set<String> = []
    private var scanTask: Task<Void, Never>?

    func scan(root: String) {
        scanTask?.cancel()
        scanTask = Task.detached(priority: .utility) {
            let result = Self.extractSymbols(root: root)
            await MainActor.run { [weak self] in
                self?.symbols = result
            }
        }
    }

    /// Extract identifiers from source files using a simple regex.
    /// Matches: func/class/struct/enum/let/var/def/const/function declarations.
    nonisolated private static func extractSymbols(root: String) -> Set<String> {
        var result = Set<String>()
        let expanded = (root as NSString).expandingTildeInPath
        let rootURL = URL(fileURLWithPath: expanded).resolvingSymlinksInPath()
        let allowedExtensions: Set<String> = ["swift", "ts", "js", "py", "go", "rs", "rb"]
        
        crawl(url: rootURL, depth: 1, maxDepth: 4, allowedExtensions: allowedExtensions, symbols: &result)
        return result
    }

    nonisolated private static func crawl(url: URL, depth: Int, maxDepth: Int, allowedExtensions: Set<String>, symbols: inout Set<String>) {
        guard depth <= maxDepth else { return }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey], options: []) else {
            return
        }
        for fileURL in contents {
            let name = fileURL.lastPathComponent
            if name.hasPrefix(".") { continue }
            if name == "node_modules" || name == "build" || name == "dist" { continue }
            
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: fileURL.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    crawl(url: fileURL, depth: depth + 1, maxDepth: maxDepth, allowedExtensions: allowedExtensions, symbols: &symbols)
                } else {
                    let ext = fileURL.pathExtension.lowercased()
                    if allowedExtensions.contains(ext) {
                        // Check file size
                        if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                           let size = attrs[.size] as? Int,
                           size <= 100_000 { // Skip files > 100KB
                            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                                parseSymbols(from: content, into: &symbols)
                            }
                        }
                    }
                }
            }
            if symbols.count >= 10_000 {
                return
            }
        }
    }

    nonisolated private static func parseSymbols(from content: String, into symbols: inout Set<String>) {
        let pattern = "\\b(?:func|class|struct|enum|protocol|let|var|def|const|function|type|interface)\\s+([A-Za-z_]\\w*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let nsString = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
        for match in matches {
            if match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if range.location != NSNotFound {
                    let symbol = nsString.substring(with: range)
                    symbols.insert(symbol)
                    if symbols.count >= 10_000 {
                        return
                    }
                }
            }
        }
    }

    func updateCurrentFileSymbols(text: String) {
        let pattern = "\\b[A-Za-z_]\\w{3,}\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        var temp = Set<String>()
        for match in matches {
            let symbol = nsString.substring(with: match.range)
            temp.insert(symbol)
            if temp.count >= 2000 {
                break
            }
        }
        self.currentFileSymbols = temp
    }

    func completions(prefix: String, limit: Int = 20) -> [String] {
        let allSymbols = symbols.union(currentFileSymbols)
        return allSymbols.filter { $0.hasPrefix(prefix) && $0 != prefix }
            .sorted()
            .prefix(limit)
            .map { String($0) }
    }
}
