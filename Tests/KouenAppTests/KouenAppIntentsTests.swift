import XCTest
import KouenCore
@testable import KouenApp

@available(macOS 13.0, *)
final class KouenAppIntentsTests: XCTestCase {
    func testSplitDirectionAppEnumMapsToMatchingIPCDirection() {
        XCTAssertEqual(SplitDirectionAppEnum.horizontal.ipcDirection, .horizontal)
        XCTAssertEqual(SplitDirectionAppEnum.vertical.ipcDirection, .vertical)
    }

    func testKouenIntentErrorMessagesAreNonEmptyAndDistinct() {
        let noPane = String(localized: KouenIntentError.noActivePane.localizedStringResource)
        let noWorkspace = String(localized: KouenIntentError.workspaceNotFound("staging").localizedStringResource)
        XCTAssertFalse(noPane.isEmpty)
        XCTAssertFalse(noWorkspace.isEmpty)
        XCTAssertNotEqual(noPane, noWorkspace)
        XCTAssertTrue(noWorkspace.contains("staging"), "the workspace name should surface in the error so the user knows what didn't match")
    }
}
