import Foundation

/// Git-diff gutter parsing shared by `FileEditorView` (read/write) and
/// `FileViewerViewController` (read-only sidebar preview) — both render the
/// same `+`/`-`/modified markers via `SyntaxTextView.setDiffLines`.
enum GitDiffGutter {
    /// For .diff/.patch files: parse `+`/`-` line prefixes directly from the content.
    static func contentLines(_ text: String) -> [Int: SyntaxTextView.DiffLineType] {
        var result: [Int: SyntaxTextView.DiffLineType] = [:]
        for (i, line) in text.components(separatedBy: "\n").enumerated() {
            let lineNum = i + 1
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                result[lineNum] = .added
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                result[lineNum] = .deleted
            } else if line.hasPrefix("@@") {
                result[lineNum] = .modified
            }
        }
        return result
    }

    static func diffLines(for path: String) async -> [Int: SyntaxTextView.DiffLineType] {
        let dir = (path as NSString).deletingLastPathComponent
        let file = (path as NSString).lastPathComponent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "HEAD", "--unified=0", "--", file]
        process.currentDirectoryURL = URL(fileURLWithPath: dir)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [:] }
        // Drain stdout before waitUntilExit(): a large diff can exceed the pipe's kernel
        // buffer, so reading only after the child exits deadlocks (child blocks on
        // write(), waitUntilExit() blocks on the child exiting).
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        // "-start[,count]" or "+start[,count]" — count defaults to 1 when omitted.
        func parseRange(_ spec: Substring) -> (start: Int, count: Int)? {
            let body = spec.dropFirst()
            let comps = body.split(separator: ",")
            guard let start = Int(comps.first ?? "") else { return nil }
            let count = comps.count > 1 ? (Int(comps[1]) ?? 1) : 1
            return (start, count)
        }

        var result: [Int: SyntaxTextView.DiffLineType] = [:]
        // Parse "@@ -oldStart,oldCount +newStart,newCount @@" hunks
        for line in output.components(separatedBy: "\n") {
            guard line.hasPrefix("@@") else { continue }
            let parts = line.split(separator: " ")
            guard parts.count >= 3, parts[1].hasPrefix("-"), parts[2].hasPrefix("+"),
                  let old = parseRange(parts[1]), let new = parseRange(parts[2]) else { continue }
            if new.count == 0 {
                result[new.start] = .deleted
            } else {
                let type: SyntaxTextView.DiffLineType = old.count == 0 ? .added : .modified
                for i in new.start..<(new.start + new.count) {
                    result[i] = type
                }
            }
        }
        return result
    }
}
