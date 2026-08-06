import XCTest
import KouenIPC
@testable import KouenCore

final class SavedLayoutStoreTests: XCTestCase {
    private func tmpURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("kouen-saved-layouts-\(UUID().uuidString).json")
    }

    func testCreateListGetDeleteRoundTrip() {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SavedLayoutStore(url: url)

        let shape = PaneLayoutShape.branch(direction: .horizontal, ratio: 0.5, first: .leaf, second: .leaf)
        let created = store.create(name: "3-pane dev", shape: shape)
        XCTAssertEqual(store.get(id: created.id)?.name, "3-pane dev")
        XCTAssertEqual(store.list().count, 1)

        XCTAssertTrue(store.delete(id: created.id))
        XCTAssertNil(store.get(id: created.id))
        XCTAssertFalse(store.delete(id: created.id))
    }

    func testPersistsAcrossReopen() {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let shape = PaneLayoutShape.branch(
            direction: .vertical, ratio: 0.3,
            first: .leaf,
            second: .branch(direction: .horizontal, ratio: 0.5, first: .leaf, second: .leaf)
        )
        let created: SavedLayout
        do {
            let store = SavedLayoutStore(url: url)
            created = store.create(name: "nested", shape: shape)
        }
        let reopened = SavedLayoutStore(url: url)
        XCTAssertEqual(reopened.get(id: created.id)?.shape, shape)
    }
}

final class PaneNodeLayoutShapeTests: XCTestCase {
    func testLeafReducesToShapeLeaf() {
        let leaf = PaneNode.leaf(PaneLeaf())
        XCTAssertEqual(leaf.paneLayoutShape, .leaf)
    }

    func testBrowserLeafReducesToShapeLeaf() {
        let browser = PaneNode.browser(BrowserLeaf(url: URL(string: "https://example.com")!))
        XCTAssertEqual(browser.paneLayoutShape, .leaf, "v1 doesn't capture browser panes — documented cut, not a bug")
    }

    func testBranchPreservesDirectionAndRatioStripsIdentity() {
        let node = PaneNode.branch(
            direction: .horizontal, ratio: 0.618,
            first: .leaf(PaneLeaf()),
            second: .branch(direction: .vertical, ratio: 0.5, first: .leaf(PaneLeaf()), second: .browser(BrowserLeaf(url: URL(string: "https://x.com")!)))
        )
        let expected = PaneLayoutShape.branch(
            direction: .horizontal, ratio: 0.618,
            first: .leaf,
            second: .branch(direction: .vertical, ratio: 0.5, first: .leaf, second: .leaf)
        )
        XCTAssertEqual(node.paneLayoutShape, expected)
    }
}
