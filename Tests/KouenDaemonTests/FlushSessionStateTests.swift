import XCTest
@testable import KouenCore
@testable import KouenDaemonCore

/// Regression test for the incident where `install-graceful.sh`'s protocol-forced daemon
/// restart raced a blind `sleep 1` against `SessionStore`'s 0.5s debounced write — with no
/// confirmation the write landed before the daemon was killed. `.flushSessionState` forces
/// a synchronous write; this asserts a mutation is on disk the instant the request returns,
/// with no `sleep` in the test at all — if the write were still debounced/async, this would
/// fail (or flake) exactly the way the original bug did.
final class FlushSessionStateTests: XCTestCase {
    private var root: URL!
    private var previousHome: String?

    override func setUpWithError() throws {
        previousHome = getenv("KOUEN_HOME").map { String(cString: $0) }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kouen-flush-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        root = dir
        setenv("KOUEN_HOME", dir.path, 1)
        try KouenPaths.ensureDirectories()
    }

    override func tearDownWithError() throws {
        if let previousHome { setenv("KOUEN_HOME", previousHome, 1) } else { unsetenv("KOUEN_HOME") }
        try? FileManager.default.removeItem(at: root)
    }

    func testFlushWritesMutationToDiskWithNoWait() throws {
        let registry = SurfaceRegistry()

        guard case let .workspaceID(id) = registry.handle(.newWorkspace(name: "regression-marker")) else {
            return XCTFail("Expected .workspaceID from newWorkspace")
        }

        // No sleep here — this is the whole point. Immediately after the mutation, force
        // the flush and assert it already reflects on disk in the very next read.
        guard case .ok = registry.handle(.flushSessionState) else {
            return XCTFail("Expected .ok from flushSessionState")
        }

        let data = try Data(contentsOf: KouenPaths.snapshotURL)
        let onDisk = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(onDisk.contains("regression-marker"), "flush must persist the mutation synchronously")
        XCTAssertTrue(onDisk.contains(id.uuidString))
    }

    func testFlushIsANoOpErrorFreeCallEvenWithNoPendingChanges() {
        let registry = SurfaceRegistry()
        guard case .ok = registry.handle(.flushSessionState) else {
            return XCTFail("Expected .ok from flushSessionState with nothing pending")
        }
    }
}
