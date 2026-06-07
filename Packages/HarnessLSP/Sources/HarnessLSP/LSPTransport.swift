import Foundation

public enum LSPTransport {
    public enum TransportError: Error, Equatable {
        case malformedHeader
        case missingContentLength
        case invalidContentLength
        case invalidUTF8Header
    }

    public static func encode(_ message: LSPMessage) throws -> Data {
        let body = try JSONEncoder().encode(message)
        var frame = Data("Content-Length: \(body.count)\r\n\r\n".utf8)
        frame.append(body)
        return frame
    }

    fileprivate static func decodeNextMessage(from buffer: inout Data) throws -> LSPMessage? {
        guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = buffer[..<headerRange.lowerBound]
        guard let header = String(data: headerData, encoding: .utf8) else {
            throw TransportError.invalidUTF8Header
        }
        let length = try parseContentLength(from: header)
        let bodyStart = headerRange.upperBound
        let bodyEnd = bodyStart + length
        guard buffer.count >= bodyEnd else { return nil }
        let body = buffer[bodyStart..<bodyEnd]
        let message = try JSONDecoder().decode(LSPMessage.self, from: Data(body))
        buffer.removeSubrange(..<bodyEnd)
        return message
    }

    private static func parseContentLength(from header: String) throws -> Int {
        for line in header.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            guard parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "content-length" else {
                continue
            }
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let length = Int(value), length >= 0 else {
                throw TransportError.invalidContentLength
            }
            return length
        }
        throw TransportError.missingContentLength
    }
}

public final class LSPTransportBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()

    public init() {}

    public func append(_ data: Data) {
        lock.withLock {
            buffer.append(data)
        }
    }

    public func nextMessage() throws -> LSPMessage? {
        try lock.withLock {
            try LSPTransport.decodeNextMessage(from: &buffer)
        }
    }
}
