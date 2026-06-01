import Foundation

public enum DaemonSessionError: Error, CustomStringConvertible {
    case daemonError(String)
    case unexpectedResponse

    public var description: String {
        switch self {
        case let .daemonError(msg): msg
        case .unexpectedResponse: "Unexpected response from HarnessDaemon"
        }
    }
}

/// Client wrapper used by Harness.app for all session mutations.
/// @unchecked Sendable: holds only an immutable, thread-safe `DaemonClient`.
public final class DaemonSessionService: @unchecked Sendable {
    private let client = DaemonClient()

    public init() {}

    @discardableResult
    public func request(_ ipcRequest: IPCRequest) throws -> IPCResponse {
        try request(ipcRequest, timeout: 2)
    }

    /// Timeout-tunable variant. Quit-time reaping (`closeEphemeralSessions`) wants a longer window
    /// than the snappy default so a momentarily busy daemon still confirms before the process exits.
    @discardableResult
    public func request(_ ipcRequest: IPCRequest, timeout: TimeInterval) throws -> IPCResponse {
        let response = try client.request(ipcRequest, timeout: timeout)
        if case let .error(message) = response {
            throw DaemonSessionError.daemonError(message)
        }
        return response
    }

    public func fetchSnapshot() throws -> SessionSnapshot {
        let response = try request(.getSnapshot)
        guard case let .snapshot(snapshot) = response else {
            throw DaemonSessionError.unexpectedResponse
        }
        return snapshot
    }

    public func ping() -> Bool {
        guard let response = try? request(.ping) else { return false }
        if case .pong = response { return true }
        return false
    }
}
