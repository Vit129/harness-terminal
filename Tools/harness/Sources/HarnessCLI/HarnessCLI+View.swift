import Foundation
import HarnessCore

enum HarnessViewError: Error, Equatable {
    case missingPath
    case unreadable
    case tooLarge(Int)
    case binaryOrUnsupportedEncoding
}

enum HarnessFilePreviewLoader {
    static let maxPreviewBytes = 1_000_000

    static func load(path: String, fileManager: FileManager = .default) throws -> String {
        let expanded = (path.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        guard !expanded.isEmpty else { throw HarnessViewError.missingPath }
        guard let attributes = try? fileManager.attributesOfItem(atPath: expanded),
              let size = attributes[.size] as? Int
        else { throw HarnessViewError.unreadable }
        guard size <= maxPreviewBytes else { throw HarnessViewError.tooLarge(size) }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: expanded)),
              let text = String(data: data, encoding: .utf8)
        else { throw HarnessViewError.binaryOrUnsupportedEncoding }
        return text
    }
}

extension HarnessCLI {
    static func handleView(_ args: [String]) -> Int {
        let paths = positionalArgs(args, skippingValuesFor: [])
        guard let path = paths.first else {
            fputs("Usage: harness-cli view <file>\n", harnessStderr)
            return 64
        }
        do {
            print(try HarnessFilePreviewLoader.load(path: path), terminator: "")
            return 0
        } catch HarnessViewError.tooLarge(let size) {
            print("File too large to preview (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))).")
            return 1
        } catch HarnessViewError.binaryOrUnsupportedEncoding {
            print("Unable to preview this file (binary or unsupported encoding).")
            return 1
        } catch {
            print("Unable to read file.")
            return 1
        }
    }
}
