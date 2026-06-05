import Foundation

public enum JSONRPCId: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        throw DecodingError.typeMismatch(
            JSONRPCId.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or int JSON-RPC id")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        }
    }
}

public struct JSONRPCError: Codable, Equatable, Sendable {
    public var code: Int
    public var message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

public enum ACPMessage: Codable, Equatable, Sendable {
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
                debugDescription: "Expected JSON-RPC 2.0 message"
            )
        }

        if let method = try container.decodeIfPresent(String.self, forKey: .method) {
            let params = try Self.decodeExplicitNullableValue(from: container, forKey: .params)
            if let id = try container.decodeIfPresent(JSONRPCId.self, forKey: .id) {
                self = .request(id: id, method: method, params: params)
            } else {
                self = .notification(method: method, params: params)
            }
            return
        }

        let id = try container.decode(JSONRPCId.self, forKey: .id)
        let result = try Self.decodeExplicitNullableValue(from: container, forKey: .result)
        let error = try container.decodeIfPresent(JSONRPCError.self, forKey: .error)
        self = .response(id: id, result: result, error: error)
    }

    private static func decodeExplicitNullableValue(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> AnyCodable? {
        guard container.contains(key) else { return nil }
        if try container.decodeNil(forKey: key) {
            return .null
        }
        return try container.decode(AnyCodable.self, forKey: key)
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
}

public indirect enum AnyCodable: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodable])
    case object([String: AnyCodable])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnyCodable].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self = .object(value)
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
