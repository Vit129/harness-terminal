import AppKit
import XCTest
@testable import HarnessApp

@MainActor
final class HarnessSplitViewTests: XCTestCase {
    func testFirstLayoutRelaysPostDividerFramesToChildren() {
        let split = HarnessSplitView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        split.isVertical = true
        split.direction = .horizontal
        split.ratio = nil

        let first = LayoutProbeView()
        let second = LayoutProbeView()
        split.addSubview(first)
        split.addSubview(second)

        split.needsLayout = true
        split.layoutSubtreeIfNeeded()

        XCTAssertEqual(first.lastLayoutWidth, first.frame.width, accuracy: 0.001)
        XCTAssertEqual(second.lastLayoutWidth, second.frame.width, accuracy: 0.001)
        XCTAssertLessThan(first.frame.width, split.bounds.width)
        XCTAssertLessThan(second.frame.width, split.bounds.width)
    }
}

@MainActor
private final class LayoutProbeView: NSView {
    private(set) var lastLayoutWidth: CGFloat = -1

    override func layout() {
        super.layout()
        lastLayoutWidth = frame.width
    }
}
