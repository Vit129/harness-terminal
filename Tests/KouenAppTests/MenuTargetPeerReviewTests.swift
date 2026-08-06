import XCTest
import KouenCore
@testable import KouenApp

/// M7: `MenuTarget.firstPeerSurfaceID` — the pure selection logic behind "Request Peer
/// Review". Actual daemon send happens via `requestDaemon`, needs a live daemon — not
/// unit-tested here, same ceiling as every other coordinator-effect call in this project.
@MainActor
final class MenuTargetPeerReviewTests: XCTestCase {
    func testSkipsActiveSurfaceEvenIfItHasAnAgent() {
        let active = UUID()
        let other = UUID()
        let result = MenuTarget.firstPeerSurfaceID(among: [active, other], excluding: active) { _ in true }
        XCTAssertEqual(result, other)
    }

    func testSkipsSurfacesWithoutAnAgent() {
        let active = UUID()
        let noAgent = UUID()
        let hasAgent = UUID()
        let result = MenuTarget.firstPeerSurfaceID(among: [active, noAgent, hasAgent], excluding: active) { $0 == hasAgent }
        XCTAssertEqual(result, hasAgent)
    }

    func testReturnsNilWhenNoPeerQualifies() {
        let active = UUID()
        let noAgent = UUID()
        let result = MenuTarget.firstPeerSurfaceID(among: [active, noAgent], excluding: active) { _ in false }
        XCTAssertNil(result)
    }

    func testEmptyCandidatesReturnsNil() {
        let active = UUID()
        XCTAssertNil(MenuTarget.firstPeerSurfaceID(among: [], excluding: active) { _ in true })
    }
}
