import Foundation
import HarnessCore

public struct LSPPosition: Codable, Equatable, Sendable {
    public var line: Int
    public var character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

public struct LSPRange: Codable, Equatable, Sendable {
    public var start: LSPPosition
    public var end: LSPPosition

    public init(start: LSPPosition, end: LSPPosition) {
        self.start = start
        self.end = end
    }
}

public enum LSPDiagnosticSeverity: Int, Codable, Sendable {
    case error = 1
    case warning = 2
    case information = 3
    case hint = 4
}

public struct LSPDiagnostic: Codable, Equatable, Sendable {
    public var range: LSPRange
    public var severity: LSPDiagnosticSeverity?
    public var message: String

    public init(range: LSPRange, severity: LSPDiagnosticSeverity?, message: String) {
        self.range = range
        self.severity = severity
        self.message = message
    }
}

public struct LSPLocation: Codable, Equatable, Sendable {
    public var uri: String
    public var range: LSPRange

    public init(uri: String, range: LSPRange) {
        self.uri = uri
        self.range = range
    }
}

public struct LSPHover: Codable, Equatable, Sendable {
    public var contents: AnyCodable
    public var range: LSPRange?

    public init(contents: AnyCodable, range: LSPRange? = nil) {
        self.contents = contents
        self.range = range
    }

    public var plainText: String {
        Self.plainText(from: contents)
    }

    private static func plainText(from value: AnyCodable) -> String {
        switch value {
        case let .string(text):
            return text
        case let .object(object):
            if let value = object["value"] { return plainText(from: value) }
            if let language = object["language"], let text = object["value"] {
                return "\(plainText(from: language))\n\(plainText(from: text))"
            }
            return object.values.map(plainText(from:)).joined(separator: "\n")
        case let .array(values):
            return values.map(plainText(from:)).filter { !$0.isEmpty }.joined(separator: "\n\n")
        case let .int(value):
            return String(value)
        case let .double(value):
            return String(value)
        case let .bool(value):
            return String(value)
        case .null:
            return ""
        }
    }
}

public enum LSPMessage: Codable, Equatable, Sendable {
    case request(id: JSONRPCId, method: String, params: AnyCodable?)
    case response(id: JSONRPCId, result: AnyCodable?, error: JSONRPCError?)
    case notification(method: String, params: AnyCodable?)

    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
        case result
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(String.self, forKey: .jsonrpc)
        guard version == "2.0" else {
            throw DecodingError.dataCorruptedError(
                forKey: .jsonrpc,
                in: container,
                debugDescription: "Expected JSON-RPC 2.0"
            )
        }
        if let method = try container.decodeIfPresent(String.self, forKey: .method) {
            let params = try Self.decodeNullable(from: container, forKey: .params)
            if let id = try container.decodeIfPresent(JSONRPCId.self, forKey: .id) {
                self = .request(id: id, method: method, params: params)
            } else {
                self = .notification(method: method, params: params)
            }
            return
        }
        let id = try container.decode(JSONRPCId.self, forKey: .id)
        let result = try Self.decodeNullable(from: container, forKey: .result)
        let error = try container.decodeIfPresent(JSONRPCError.self, forKey: .error)
        self = .response(id: id, result: result, error: error)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("2.0", forKey: .jsonrpc)
        switch self {
        case let .request(id, method, params):
            try container.encode(id, forKey: .id)
            try container.encode(method, forKey: .method)
            try container.encodeIfPresent(params, forKey: .params)
        case let .response(id, result, error):
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(result, forKey: .result)
            try container.encodeIfPresent(error, forKey: .error)
        case let .notification(method, params):
            try container.encode(method, forKey: .method)
            try container.encodeIfPresent(params, forKey: .params)
        }
    }

    private static func decodeNullable(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> AnyCodable? {
        guard container.contains(key) else { return nil }
        if try container.decodeNil(forKey: key) { return .null }
        return try container.decode(AnyCodable.self, forKey: key)
    }
}
