import XCTest
@testable import HarnessCore
@testable import HarnessDaemonCore

/// Daemon-side extended format-context fields: the PTY-backed values (`pane_pid`,
/// `pane_current_command`, `pane_width/height`, `history_bytes`) and the metadata scan's
/// `currentCommand` commit. Runs against an isolated `HARNESS_HOME` like `SurfaceRegistryTests`.
final class FormatContextDaemonTests: XCTestCase {
    private var root: URL?
    private var previousHome: String?

    override func setUpWithError() throws {
        previousHome = getenv("HARNESS_HOME").map { String(cString: $0) }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("harness-fmtctx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        root = dir
        setenv("HARNESS_HOME", dir.path, 1)
        try HarnessPaths.ensureDirectories()
    }

    override func tearDownWithError() throws {
        if let previousHome { setenv("HARNESS_HOME", previousHome, 1) } else { unsetenv("HARNESS_HOME") }
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    func testBuildFormatContextFillsPTYBackedFields() throws {
        try skipUnlessLiveDaemonTests()
        let registry = SurfaceRegistry()
        guard case let .surfaces(list) = registry.handle(.listSurfaces), let surface = list.first else {
            return XCTFail("expected a seeded surface")
        }
        // Give the spawned shell a beat to come up so the foreground pgrp exists.
        usleep(300_000)
        let context = registry.buildFormatContext(surfaceKey: surface.surfaceID)

        XCTAssertGreaterThan(context.panePID ?? 0, 0, "pane_pid must be the live shell PID")
        XCTAssertFalse(
            context.paneCurrentCommand?.isEmpty ?? true,
            "pane_current_command must name the foreground process"
        )
        // Spawn size is the 24×80 placeholder until a client votes.
        XCTAssertEqual(context.paneWidth, 80)
        XCTAssertEqual(context.paneHeight, 24)
        XCTAssertEqual(context.paneDead, false)
        XCTAssertNotNil(context.historyBytes)
        XCTAssertNotNil(context.sessionID)
        XCTAssertNotNil(context.windowID)
        XCTAssertEqual(context.windowPanes, 1)
        XCTAssertEqual(context.sessionWindows, 1)
        XCTAssertEqual(context.serverPID, Int(getpid()))
        // Rendered IDs carry the target-grammar prefixes.
        let rendered = FormatString.evaluate("#{session_id}", context: context)
        XCTAssertTrue(rendered.hasPrefix("$"))
    }

    func testMetadataScanCommitsCurrentCommand() throws {
        try skipUnlessLiveDaemonTests()
        let registry = SurfaceRegistry()
        guard case let .surfaces(list) = registry.handle(.listSurfaces), let surface = list.first else {
            return XCTFail("expected a seeded surface")
        }
        // The scan only commits when the probe succeeds — poll a few cycles like the
        // daemon's own ~1.5s timer would.
        var command: String?
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            registry.refreshSurfaceMetadata()
            command = registry.snapshot.workspaces
                .flatMap(\.sessions).flatMap(\.tabs)
                .first { $0.rootPane.allSurfaceIDs().map(\.uuidString).contains(surface.surfaceID) }?
                .currentCommand
            if command?.isEmpty == false { break }
            usleep(200_000)
        }
        XCTAssertFalse(command?.isEmpty ?? true, "scan never committed a foreground command")
    }
}
