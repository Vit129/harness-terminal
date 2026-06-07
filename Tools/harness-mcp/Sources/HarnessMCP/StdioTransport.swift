import Foundation
import HarnessCore

/// Reads JSON-RPC messages from stdin and writes responses to stdout using
/// Content-Length framing (LSP/MCP standard).
final class StdioTransport: @unchecked Sendable {
    let incoming: AsyncStream<ACPMessage>
    private let continuation: AsyncStream<ACPMessage>.Continuation

    init() {
        var cont: AsyncStream<ACPMessage>.Continuation?
        incoming = AsyncStream { cont = $0 }
        continuation = cont!
        startReading()
    }

    func send(_ message: ACPMessage) {
        guard let data = try? ACPTransport.encode(message) else { return }
        FileHandle.standardOutput.write(data)
    }

    private func startReading() {
        let cont = continuation
        Thread.detachNewThread {
            let buffer = TransportBuffer()
            while true {
                let data = FileHandle.standardInput.availableData
                if data.isEmpty { break }
                buffer.append(data)
                while let message = try? buffer.nextMessage() {
                    cont.yield(message)
                }
            }
            cont.finish()
        }
    }
}
