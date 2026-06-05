import Foundation

public enum ACPTransport {
    public enum TransportError: Error, Equatable {
        case malformedHeader
        case missingContentLength
        case invalidContentLength
        case invalidUTF8Header
    }

    public static func encode(_ message: ACPMessage) throws -> Data {
        let body = try JSONEncoder().encode(message)
        var frame = Data("Content-Length: \(body.count)\r\n\r\n".utf8)
        frame.append(body)
        return frame
    }

    public static func decode(from data: Data) throws -> ACPMessage {
        var buffer = data
        guard let message = try decodeNextMessage(from: &buffer) else {
            throw TransportError.malformedHeader
        }
        return message
    }

    fileprivate static func decodeNextMessage(from buffer: inout Data) throws -> ACPMessage? {
        guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        let headerData = buffer[..<headerRange.lowerBound]
        guard let header = String(data: headerData, encoding: .utf8) else {
            throw TransportError.invalidUTF8Header
        }

        let contentLength = try parseContentLength(from: header)
        let bodyStart = headerRange.upperBound
        let bodyEnd = bodyStart + contentLength
        guard buffer.count >= bodyEnd else {
            return nil
        }

        let body = buffer[bodyStart..<bodyEnd]
        let message = try JSONDecoder().decode(ACPMessage.self, from: Data(body))
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
            let rawValue = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let length = Int(rawValue), length >= 0 else {
                throw TransportError.invalidContentLength
            }
            return length
        }
        throw TransportError.missingContentLength
    }
}

public final class TransportBuffer {
    private var buffer = Data()

    public init() {}

    public func append(_ data: Data) {
        buffer.append(data)
    }

    public func nextMessage() throws -> ACPMessage? {
        try ACPTransport.decodeNextMessage(from: &buffer)
    }
}
