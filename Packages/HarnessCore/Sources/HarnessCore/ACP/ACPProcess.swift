import Foundation

public enum ACPProcessError: Error, Equatable {
    case binaryNotExecutable(String)
    case processNotRunning
    case missingPipe
}

public actor ACPProcess {
    public var onCrash: (@Sendable () -> Void)?
    public let incomingMessages: AsyncStream<ACPMessage>

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var readerTask: Task<Void, Never>?
    private let continuation: AsyncStream<ACPMessage>.Continuation

    public init() {
        var streamContinuation: AsyncStream<ACPMessage>.Continuation?
        incomingMessages = AsyncStream { continuation in
            streamContinuation = continuation
        }
        continuation = streamContinuation!
    }

    public func launch(config: AgentConfig) async throws {
        guard FileManager.default.isExecutableFile(atPath: config.binaryPath) else {
            throw ACPProcessError.binaryNotExecutable(config.binaryPath)
        }

        let proc = Process()
        let input = Pipe()
        let output = Pipe()
        proc.executableURL = URL(fileURLWithPath: config.binaryPath)
        proc.arguments = config.args
        proc.standardInput = input
        proc.standardOutput = output

        try proc.run()

        process = proc
        stdinPipe = input
        stdoutPipe = output
        startReading(fileHandle: output.fileHandleForReading)
    }

    public func send(_ message: ACPMessage) async throws {
        guard let process, process.isRunning else {
            throw ACPProcessError.processNotRunning
        }
        guard let stdinPipe else {
            throw ACPProcessError.missingPipe
        }
        let data = try ACPTransport.encode(message)
        try stdinPipe.fileHandleForWriting.write(contentsOf: data)
    }

    public func terminate() async {
        readerTask?.cancel()
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
    }

    private func startReading(fileHandle: FileHandle) {
        let continuation = continuation
        readerTask?.cancel()
        readerTask = Task { [weak self] in
            let buffer = TransportBuffer()
            while !Task.isCancelled {
                let data = fileHandle.availableData
                if data.isEmpty { break }
                buffer.append(data)
                do {
                    while let message = try buffer.nextMessage() {
                        continuation.yield(message)
                    }
                } catch {
                    break
                }
            }
            continuation.finish()
            await self?.handleExit()
        }
    }

    private func handleExit() {
        if process?.terminationStatus != 0 {
            onCrash?()
        }
    }
}
