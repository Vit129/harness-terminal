import XCTest
import KouenIPC
@testable import KouenCore

final class AgentRoutingRuleStoreTests: XCTestCase {
    private func tmpURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("kouen-routing-rules-\(UUID().uuidString).json")
    }

    func testCreateListGetUpdateDeleteRoundTrip() {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AgentRoutingRuleStore(url: url)

        let created = store.create(kind: .path, pattern: "~/Git/Company/**", targetAgent: .codex)
        XCTAssertEqual(store.get(id: created.id)?.pattern, "~/Git/Company/**")
        XCTAssertEqual(store.list().count, 1)

        let updated = store.update(id: created.id, pattern: "~/Git/Personal/**", targetAgent: nil, enabled: nil)
        XCTAssertEqual(updated?.pattern, "~/Git/Personal/**")
        XCTAssertEqual(updated?.targetAgent, .codex, "unspecified fields must not change")

        XCTAssertTrue(store.delete(id: created.id))
        XCTAssertNil(store.get(id: created.id))
        XCTAssertFalse(store.delete(id: created.id))
    }

    func testCreateAssignsAscendingOrderPerKindIndependently() {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AgentRoutingRuleStore(url: url)

        let path1 = store.create(kind: .path, pattern: "a", targetAgent: .claudeCode)
        let stack1 = store.create(kind: .stack, pattern: "swift", targetAgent: .claudeCode)
        let path2 = store.create(kind: .path, pattern: "b", targetAgent: .claudeCode)

        XCTAssertEqual(path1.order, 0)
        XCTAssertEqual(stack1.order, 0, "stack ordering is independent of path ordering")
        XCTAssertEqual(path2.order, 1)
    }

    func testReorderIsScopedToItsOwnKind() {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AgentRoutingRuleStore(url: url)

        let pathA = store.create(kind: .path, pattern: "a", targetAgent: .claudeCode)
        let pathB = store.create(kind: .path, pattern: "b", targetAgent: .claudeCode)
        let stackA = store.create(kind: .stack, pattern: "swift", targetAgent: .claudeCode)

        let reordered = store.reorder(kind: .path, orderedIDs: [pathB.id, pathA.id])
        XCTAssertEqual(reordered.map(\.id), [pathB.id, pathA.id])
        XCTAssertEqual(store.get(id: pathB.id)?.order, 0)
        XCTAssertEqual(store.get(id: pathA.id)?.order, 1)
        XCTAssertEqual(store.get(id: stackA.id)?.order, 0, "reordering path rules must not touch stack rules")
    }

    func testReorderOmittedRuleKeepsRelativeOrderAppendedAfterNamed() {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AgentRoutingRuleStore(url: url)

        let a = store.create(kind: .path, pattern: "a", targetAgent: .claudeCode)
        let b = store.create(kind: .path, pattern: "b", targetAgent: .claudeCode)
        let c = store.create(kind: .path, pattern: "c", targetAgent: .claudeCode)

        // Only reorder b ahead of the pack — a and c are omitted, must not be dropped.
        let reordered = store.reorder(kind: .path, orderedIDs: [b.id])
        XCTAssertEqual(reordered.map(\.id), [b.id, a.id, c.id])
    }

    func testPersistsAcrossReopen() {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let created: AgentRoutingRule
        do {
            let store = AgentRoutingRuleStore(url: url)
            created = store.create(kind: .stack, pattern: "python", targetAgent: .codex)
        }
        let reopened = AgentRoutingRuleStore(url: url)
        XCTAssertEqual(reopened.get(id: created.id)?.pattern, "python")
    }

    func testUpdateOnMissingIDReturnsNil() {
        let url = tmpURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let store = AgentRoutingRuleStore(url: url)
        XCTAssertNil(store.update(id: UUID(), pattern: "nope", targetAgent: nil, enabled: nil))
    }
}
