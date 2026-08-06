import XCTest
@testable import KouenCore
@testable import KouenDaemonCore

/// Integration tests for Saved Layout IPC (M5) via SurfaceRegistry.handle() directly,
/// same pattern as AutomationIPCDaemonTests/AgentRoutingRuleIPCDaemonTests.
final class SavedLayoutIPCDaemonTests: XCTestCase {
    private var root: URL!
    private var previousHome: String?

    override func setUpWithError() throws {
        previousHome = getenv("KOUEN_HOME").map { String(cString: $0) }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kouen-saved-layout-daemon-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        root = dir
        setenv("KOUEN_HOME", dir.path, 1)
        try KouenPaths.ensureDirectories()
    }

    override func tearDownWithError() throws {
        if let previousHome { setenv("KOUEN_HOME", previousHome, 1) } else { unsetenv("KOUEN_HOME") }
        try? FileManager.default.removeItem(at: root)
    }

    private func firstWorkspaceID(_ registry: SurfaceRegistry) -> UUID? {
        guard case let .snapshot(snap) = registry.handle(.getSnapshot) else { return nil }
        return snap.workspaces.first?.id
    }

    func testSaveListDeleteRoundTripViaIPC() throws {
        let registry = SurfaceRegistry()
        let workspaceID = try XCTUnwrap(firstWorkspaceID(registry))
        guard case let .tabID(tabID) = registry.handle(.newTab(workspaceID: workspaceID, cwd: root.path, shell: nil)) else {
            return XCTFail("Expected .tabID from newTab")
        }

        guard case let .savedLayoutInfo(saved?) = registry.handle(.savedLayoutSave(name: "single-pane", tabID: tabID)) else {
            return XCTFail("Expected .savedLayoutInfo from savedLayoutSave")
        }
        XCTAssertEqual(saved.name, "single-pane")
        XCTAssertEqual(saved.shape, .leaf, "a freshly created tab has one pane, no splits")

        guard case let .savedLayouts(list) = registry.handle(.savedLayoutList) else {
            return XCTFail("Expected .savedLayouts from savedLayoutList")
        }
        XCTAssertEqual(list.count, 1)

        guard case .ok = registry.handle(.savedLayoutDelete(id: saved.id)) else {
            return XCTFail("Expected .ok from savedLayoutDelete")
        }
        guard case let .savedLayouts(afterDelete) = registry.handle(.savedLayoutList) else {
            return XCTFail("Expected .savedLayouts from savedLayoutList after delete")
        }
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testSaveOnMissingTabReturnsError() {
        let registry = SurfaceRegistry()
        guard case .error = registry.handle(.savedLayoutSave(name: "nope", tabID: UUID())) else {
            return XCTFail("Expected .error from savedLayoutSave on missing tab")
        }
    }

    func testDeleteOnMissingIDReturnsError() {
        let registry = SurfaceRegistry()
        guard case .error = registry.handle(.savedLayoutDelete(id: UUID())) else {
            return XCTFail("Expected .error from savedLayoutDelete on missing id")
        }
    }

    func testSaveCapturesSplitShape() throws {
        let registry = SurfaceRegistry()
        let workspaceID = try XCTUnwrap(firstWorkspaceID(registry))
        guard case let .tabID(tabID) = registry.handle(.newTab(workspaceID: workspaceID, cwd: root.path, shell: nil)) else {
            return XCTFail("Expected .tabID from newTab")
        }
        guard case let .snapshot(snap) = registry.handle(.getSnapshot),
              let tab = snap.workspaces.flatMap({ $0.sessions.flatMap { $0.tabs } }).first(where: { $0.id == tabID }),
              let rootLeafID = tab.rootPane.allPaneIDs().first
        else { return XCTFail("Expected the new tab to have one leaf") }

        guard case .paneID = registry.handle(.newSplit(tabID: tabID, paneID: rootLeafID, direction: .horizontal, shell: nil, before: false)) else {
            return XCTFail("Expected .paneID from newSplit")
        }

        guard case let .savedLayoutInfo(saved?) = registry.handle(.savedLayoutSave(name: "split", tabID: tabID)) else {
            return XCTFail("Expected .savedLayoutInfo from savedLayoutSave")
        }
        guard case .branch(let direction, _, .leaf, .leaf) = saved.shape else {
            return XCTFail("Expected a 2-leaf horizontal branch, got \(saved.shape)")
        }
        XCTAssertEqual(direction, .horizontal)
    }
}
