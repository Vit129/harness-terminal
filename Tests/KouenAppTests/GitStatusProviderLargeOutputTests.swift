import XCTest
@testable import KouenApp

/// Regression test for the process leak fixed 2026-08-19 (see agent-memory/GATE-STATE.md,
/// gate `git-status-process-leak`): `GitStatusProvider` drained stdout via
/// `Task.detached { readDataToEndOfFile() }`, a blocking call sharing Swift's cooperative
/// thread pool. Under concurrent load that pool could saturate, leaving a process's pipe
/// undrained — if its `git status --porcelain -z` output exceeded the kernel pipe buffer
/// (~16KB), `write()` blocked forever and the process never exited. This test reproduces
/// the >16KB-output condition directly; before the fix it hung indefinitely.
final class GitStatusProviderLargeOutputTests: XCTestCase {

    func testStatusCompletesWithoutHangingOnLargeOutput() async throws {
        let root = try makeTempGitRepo()
        defer { try? FileManager.default.removeItem(at: root) }

        // Each untracked entry costs ~19 bytes ("?? fileNNNN.txt\0"). 2000 files
        // comfortably exceeds the 16KB pipe buffer that triggered the deadlock.
        let fileCount = 2000
        for i in 0..<fileCount {
            try Data("x".utf8).write(to: root.appendingPathComponent("file\(i).txt"))
        }

        let provider = GitStatusProvider()

        let result = try await withThrowingTaskGroup(of: [String: GitStatusType].self) { group in
            group.addTask { await provider.status(rootPath: root.path) }
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw TimeoutError()
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }

        XCTAssertEqual(result.count, fileCount)
        XCTAssertEqual(result["file0.txt"], .untracked)
    }

    // MARK: - Helpers

    private struct TimeoutError: Error {}

    private func makeTempGitRepo() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("git-status-large-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init", "-q", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        return url
    }
}
