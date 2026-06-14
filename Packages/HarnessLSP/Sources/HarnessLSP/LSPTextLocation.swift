import Foundation

public struct LSPTextLocation: Equatable, Sendable {
    public var fileURL: URL
    public var line: Int
    public var column: Int

    public init(fileURL: URL, line: Int, column: Int) {
        self.fileURL = fileURL
        self.line = line
        self.column = column
    }

    public var position: LSPPosition {
        LSPPosition(line: max(0, line - 1), character: max(0, column - 1))
    }
}

public enum LSPTextLocationParser {
    public static func parse(_ raw: String, relativeTo baseURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> LSPTextLocation? {
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              let line = Int(parts[parts.count - 2]),
              let column = Int(parts[parts.count - 1]),
              line > 0,
              column > 0
        else { return nil }

        let pathPart = parts.dropLast(2).joined(separator: ":")
        guard !pathPart.isEmpty else { return nil }

        let expanded = (pathPart as NSString).expandingTildeInPath
        let url: URL
        if expanded.hasPrefix("/") {
            url = URL(fileURLWithPath: expanded)
        } else {
            url = baseURL.appendingPathComponent(expanded)
        }
        return LSPTextLocation(fileURL: url.standardizedFileURL, line: line, column: column)
    }
}
