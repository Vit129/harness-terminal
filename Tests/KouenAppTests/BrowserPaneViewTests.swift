import AppKit
import XCTest
import WebKit
import KouenCore
@testable import KouenApp

@MainActor
final class BrowserPaneViewTests: XCTestCase {
    func testURLBarUpdatesOnCommitAndFinish() {
        let mockWebView = MockWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let testURL = URL(string: "https://example.com/test")!
        mockWebView.mockURL = testURL

        let paneView = BrowserPaneView(url: testURL, paneID: UUID(), webView: mockWebView)

        // Simulating didCommit
        paneView.webView(mockWebView, didCommit: nil)
        // Verify URL text field matches testURL
        XCTAssertEqual(paneView.urlTextField.stringValue, "https://example.com/test")

        // Simulating didFinish
        let finishURL = URL(string: "https://example.com/finish")!
        mockWebView.mockURL = finishURL
        paneView.webView(mockWebView, didFinish: nil)
        XCTAssertEqual(paneView.urlTextField.stringValue, "https://example.com/finish")
    }

    // Regression for the intermittent fully-black content area: WKWebView is
    // deliberately transparent (drawsBackground=false) so the container's solid
    // terminalBackground canvas shows through until WebKit actually composites the
    // page. didFinish must force that compositor commit (kickCompositorRelayout) so
    // a page that finishes loading but loses the paint race doesn't stay black
    // until a manual reload.
    func testDidFinishTriggersCompositorKickToForcePaint() {
        let mockWebView = MockWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let testURL = URL(string: "https://example.com/test")!
        mockWebView.mockURL = testURL
        mockWebView.allowsMagnification = true

        let paneView = BrowserPaneView(url: testURL, paneID: UUID(), webView: mockWebView)
        paneView.webView(mockWebView, didFinish: nil)

        XCTAssertFalse(mockWebView.setMagnificationCalls.isEmpty,
            "didFinish should kick the compositor so a completed load can't stay stuck black")
    }

    // Regression: a tab opened via createTab() (Cmd+T, or a link/window.open that pops
    // a new tab) must also get allowsMagnification=true, same as the pane's first tab —
    // otherwise kickCompositorRelayout()'s guard silently no-ops for it forever, and no
    // amount of reload can fix its stuck-black first paint.
    func testCreateTabSetsAllowsMagnificationForCompositorKick() {
        let testURL = URL(string: "https://example.com/test")!
        let mockWebView = MockWebView(frame: .zero, configuration: WKWebViewConfiguration())
        mockWebView.mockURL = testURL
        let paneView = BrowserPaneView(url: testURL, paneID: UUID(), webView: mockWebView)

        let newTabWebView = paneView.createTab(url: URL(string: "https://example.com/new-tab")!)

        XCTAssertTrue(newTabWebView.allowsMagnification,
            "createTab()'s webview must allow magnification, or the compositor kick in didFinish is a permanent no-op for this tab")
    }

    // Regression for the black screen on tab switch: PaneLifecycleManager's fast path
    // reveals a cached (previously hidden) pane container by toggling `isHidden` alone,
    // never re-adding it to the view hierarchy — so WKWebView's remote layer can stay
    // stale/black unless something explicitly nudges its compositor. forceRepaint()
    // is that nudge; it must actually fire once the pane is attached to a real window.
    func testForceRepaintWakesWebViewWhenAttachedToWindow() {
        let mockWebView = MockWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let testURL = URL(string: "https://example.com/test")!
        mockWebView.mockURL = testURL
        mockWebView.allowsMagnification = true
        let paneView = BrowserPaneView(url: testURL, paneID: UUID(), webView: mockWebView)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView?.addSubview(paneView)
        mockWebView.evaluateJavaScriptCalls.removeAll()

        paneView.forceRepaint()

        XCTAssertFalse(mockWebView.evaluateJavaScriptCalls.isEmpty,
            "forceRepaint() must wake WKWebView's compositor once the pane is in a real window, or a revealed-from-cache tab stays black")
        // setNeedsDisplay/evaluateJavaScript alone don't force a synchronous compositor
        // commit — the magnification-nudge kick (already proven in didFinish, see
        // testDidFinishTriggersCompositorKickToForcePaint) must fire too.
        XCTAssertFalse(mockWebView.setMagnificationCalls.isEmpty,
            "forceRepaint() must also kick the compositor via magnification nudge, or a revealed-from-cache tab can still stay stuck black")
    }

    // MARK: - Design Mode (M3)

    func testDesignModeButtonHasExpectedIdentifierAndTooltip() {
        let testURL = URL(string: "https://example.com/test")!
        let mockWebView = MockWebView(frame: .zero, configuration: WKWebViewConfiguration())
        mockWebView.mockURL = testURL
        let paneView = BrowserPaneView(url: testURL, paneID: UUID(), webView: mockWebView)

        XCTAssertEqual(paneView.designModeButton.accessibilityIdentifier(), "browser-design-mode-button")
        XCTAssertNotNil(paneView.designModeButton.toolTip)
    }

    func testCssPropertyNameConvertsCamelCaseToKebabCase() {
        XCTAssertEqual(BrowserPaneView.cssPropertyName("backgroundColor"), "background-color")
        XCTAssertEqual(BrowserPaneView.cssPropertyName("fontSize"), "font-size")
        XCTAssertEqual(BrowserPaneView.cssPropertyName("color"), "color")
        XCTAssertEqual(BrowserPaneView.cssPropertyName("border"), "border")
    }

    func testCssSelectorPrefersID() {
        let info = BrowserPaneView.DesignModeElementInfo(tag: "button", id: "submit-btn", className: "btn btn-primary", styles: [:])
        XCTAssertEqual(BrowserPaneView.cssSelector(for: info), "#submit-btn")
    }

    func testCssSelectorFallsBackToTagAndAllClasses() {
        let info = BrowserPaneView.DesignModeElementInfo(tag: "button", id: "", className: "btn btn-primary", styles: [:])
        XCTAssertEqual(BrowserPaneView.cssSelector(for: info), "button.btn.btn-primary")
    }

    func testCssSelectorFallsBackToBareTagWhenNoIdOrClass() {
        let info = BrowserPaneView.DesignModeElementInfo(tag: "div", id: "", className: "", styles: [:])
        XCTAssertEqual(BrowserPaneView.cssSelector(for: info), "div")
    }

    func testViewSourceButtonVisibleOnlyForLocalHTML() {
        let mockWebView = MockWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let testURL = URL(string: "https://example.com/test")!
        mockWebView.mockURL = testURL

        let paneView = BrowserPaneView(url: testURL, paneID: UUID(), webView: mockWebView)
        paneView.webView(mockWebView, didCommit: nil)
        XCTAssertTrue(paneView.viewSourceButton.isHidden, "remote URL should not show View Source")

        let fileURL = URL(fileURLWithPath: "/tmp/report.html")
        mockWebView.mockURL = fileURL
        paneView.webView(mockWebView, didCommit: nil)
        XCTAssertFalse(paneView.viewSourceButton.isHidden, "local .html file:// URL should show View Source")
    }

    func testRemovePaneNodeCollapsesBranch() {
        let coordinator = SessionCoordinator.shared.splitPaneCoordinator
        let firstBrowserID = UUID()
        let secondBrowserID = UUID()
        let termLeaf = PaneLeaf()

        // Test split: [ firstBrowser | [ secondBrowser | termLeaf ] ]
        let innerBranch = PaneNode.branch(
            direction: .vertical,
            ratio: 0.5,
            first: .browser(BrowserLeaf(id: secondBrowserID, url: URL(string: "https://example.com/2")!)),
            second: .leaf(termLeaf)
        )

        var root = PaneNode.branch(
            direction: .horizontal,
            ratio: 0.5,
            first: .browser(BrowserLeaf(id: firstBrowserID, url: URL(string: "https://example.com/1")!)),
            second: innerBranch
        )

        // 1. Remove secondBrowserID, should collapse innerBranch to just termLeaf
        let removedSecond = coordinator.removePaneNode(paneID: secondBrowserID, from: &root)
        XCTAssertTrue(removedSecond)

        // Verify root is now: [ firstBrowser | termLeaf ]
        guard case let .branch(_, _, firstNode, secondNode) = root else {
            XCTFail("Root should still be a branch after nested collapse")
            return
        }
        XCTAssertEqual(firstNode.paneID, firstBrowserID)
        XCTAssertEqual(secondNode.paneID, termLeaf.id)

        // 2. Remove firstBrowserID, should collapse the whole tree to just termLeaf
        let removedFirst = coordinator.removePaneNode(paneID: firstBrowserID, from: &root)
        XCTAssertTrue(removedFirst)
        XCTAssertEqual(root.paneID, termLeaf.id)
    }

    func testBrowserPaneHitTestAndActions() {
        let mockWebView = MockWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let testURL = URL(string: "https://example.com/test")!
        mockWebView.mockURL = testURL

        let paneView = BrowserPaneView(url: testURL, paneID: UUID(), webView: mockWebView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = paneView

        // Force layout
        window.contentView?.layoutSubtreeIfNeeded()
        paneView.layoutSubtreeIfNeeded()

        // Assert initial state: errorBanner is hidden
        XCTAssertTrue(paneView.errorBanner.isHidden)
        XCTAssertEqual(paneView.errorBannerHeightConstraint?.constant, 0)

        // Compute center point of closePaneButton
        let closeCenter = CGPoint(x: paneView.closePaneButton.bounds.midX, y: paneView.closePaneButton.bounds.midY)
        guard let superview = paneView.superview else {
            XCTFail("Expected paneView to have a superview")
            return
        }
        let closeCenterInSuper = superview.convert(closeCenter, from: paneView.closePaneButton)
        let hitViewClose = paneView.hitTest(closeCenterInSuper)
        XCTAssertNotNil(hitViewClose)
        XCTAssertTrue(hitViewClose === paneView.closePaneButton || hitViewClose!.isDescendant(of: paneView.closePaneButton))
        XCTAssertNotEqual(hitViewClose, paneView.errorDismissButton)
        XCTAssertFalse(hitViewClose!.isDescendant(of: paneView.errorDismissButton))

        // Compute center point of reloadStopButton
        let reloadCenter = CGPoint(x: paneView.reloadStopButton.bounds.midX, y: paneView.reloadStopButton.bounds.midY)
        let reloadCenterInSuper = superview.convert(reloadCenter, from: paneView.reloadStopButton)
        let hitViewReload = paneView.hitTest(reloadCenterInSuper)
        XCTAssertNotNil(hitViewReload)
        XCTAssertTrue(hitViewReload === paneView.reloadStopButton || hitViewReload!.isDescendant(of: paneView.reloadStopButton))

        // Action test: close pane
        var closeCalled = false
        paneView.onClosePaneRequested = {
            closeCalled = true
        }
        paneView.closePaneButton.performClick(nil)
        XCTAssertTrue(closeCalled)

        // Action test: reload click when webView is not loading
        mockWebView.mockIsLoading = false
        paneView.reloadStopButton.performClick(nil)
        XCTAssertTrue(mockWebView.reloadCalled)

        // Action test: stop click when webView is loading
        mockWebView.mockIsLoading = true
        paneView.webView(mockWebView, didStartProvisionalNavigation: nil)
        paneView.reloadStopButton.performClick(nil)
        XCTAssertTrue(mockWebView.stopLoadingCalled)
    }
}

private final class MockWebView: WKWebView {
    var mockURL: URL?
    override var url: URL? {
        return mockURL
    }

    var mockIsLoading: Bool = false
    override var isLoading: Bool {
        return mockIsLoading
    }

    var reloadCalled = false
    override func reload() -> WKNavigation? {
        reloadCalled = true
        return nil
    }

    var stopLoadingCalled = false
    override func stopLoading() {
        stopLoadingCalled = true
    }

    var setMagnificationCalls: [(magnification: CGFloat, centeredAt: CGPoint)] = []
    override func setMagnification(_ magnification: CGFloat, centeredAt point: CGPoint) {
        setMagnificationCalls.append((magnification, point))
    }

    var evaluateJavaScriptCalls: [String] = []
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
        evaluateJavaScriptCalls.append(javaScriptString)
        completionHandler?(nil, nil)
    }
}
