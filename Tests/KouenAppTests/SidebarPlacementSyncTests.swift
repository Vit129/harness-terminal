import AppKit
import KouenCore
import XCTest
@testable import KouenApp

/// Regression test for the Cmd+\ "black panel" bug: the Settings window's "Sidebar on
/// right" toggle persisted `sidebarOnRight` without reordering the live NSSplitView
/// subviews — only `toggleSidebarPosition()` (the menu command) did both together.
/// The next sidebar toggle then read the new flag for divider-position math but
/// resized/hid the OLD physical view, squeezing the real terminal pane down to
/// sidebar width and leaving the real sidebar (never touched) showing blank.
@MainActor
final class SidebarPlacementSyncTests: XCTestCase {

    /// Redirects `KouenPaths.settingsURL` (env-var based, re-read on every call) to a
    /// throwaway directory so `settings.save()` inside this test never touches the
    /// real `~/Library/Application Support/Kouen/settings.json`. Also restores
    /// `SessionCoordinator.shared.settings` sidebar fields, since that singleton
    /// outlives any one test.
    private func withTemporaryKouenHome(_ body: () -> Void) {
        let previousHome = getenv("KOUEN_HOME").map { String(cString: $0) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        setenv("KOUEN_HOME", root.path, 1)
        let originalSidebarOnRight = SessionCoordinator.shared.settings.sidebarOnRight
        let originalSidebarVisible = SessionCoordinator.shared.settings.sidebarVisible
        // This file's assertions are hardcoded against KouenDesign.sidebarWidth (220) — force
        // that default explicitly rather than just restoring whatever was there, so a leaked
        // non-nil width from another test (or a real user-drag width on a dev machine's real
        // settings.json, if this ever ran without KOUEN_HOME isolation) can't silently throw
        // off every pixel-width expectation in this file.
        let originalSidebarWidth = SessionCoordinator.shared.settings.sidebarWidth
        SessionCoordinator.shared.settings.sidebarWidth = nil
        defer {
            SessionCoordinator.shared.settings.sidebarOnRight = originalSidebarOnRight
            SessionCoordinator.shared.settings.sidebarVisible = originalSidebarVisible
            SessionCoordinator.shared.settings.sidebarWidth = originalSidebarWidth
            if let previousHome { setenv("KOUEN_HOME", previousHome, 1) } else { unsetenv("KOUEN_HOME") }
            try? FileManager.default.removeItem(at: root)
        }
        body()
    }

    private func makeSplitController(width: CGFloat = 1000) -> MainSplitViewController {
        let vc = MainSplitViewController()
        vc.view.setFrameSize(NSSize(width: width, height: 600))
        vc.view.layoutSubtreeIfNeeded()
        // Off-window, so viewDidLayout()'s isVisible guard no-ops applyInitialSidebarState() —
        // the two tests below use setSidebarVisible() directly instead, which doesn't need it.
        vc.viewDidLayout()
        return vc
    }

    func testSidebarOnRightChangeWithoutNotificationSqueezesContentPane() {
        withTemporaryKouenHome {
            SessionCoordinator.shared.settings.sidebarOnRight = false
            SessionCoordinator.shared.settings.sidebarVisible = false
            let vc = makeSplitController()

            // Simulate the bug: flip the flag the way the OLD Settings toggle did —
            // no updateSidebarPlacement(), no notification.
            SessionCoordinator.shared.settings.sidebarOnRight = true
            vc.setSidebarVisible(true, animated: false)

            // Wrong view resized: the real terminal content pane got squeezed to
            // sidebar width because sidebarContainerView now (mis)resolves to it.
            XCTAssertEqual(vc.contentVC.view.frame.width, KouenDesign.sidebarWidth, accuracy: 1)
        }
    }

    func testSidebarOnRightChangeWithNotificationKeepsContentPaneWide() {
        withTemporaryKouenHome {
            SessionCoordinator.shared.settings.sidebarOnRight = false
            SessionCoordinator.shared.settings.sidebarVisible = false
            let vc = makeSplitController()

            SessionCoordinator.shared.settings.sidebarOnRight = true
            // What the fixed Settings toggle now does after model.update(\.sidebarOnRight, _):
            NotificationCenter.default.post(
                name: Notification.Name("KouenSidebarPlacementChanged"), object: nil)
            vc.setSidebarVisible(true, animated: false)

            // Correct view resized: content pane stays wide, sidebar gets the fixed width.
            XCTAssertEqual(
                vc.contentVC.view.frame.width, 1000 - KouenDesign.sidebarWidth, accuracy: 1)
        }
    }

    /// Regression test for a second, distinct Cmd+\ "black panel" bug: AppKit runs
    /// several `viewDidLayout()` passes on window construction before the window is
    /// ever shown — at that point it's still pinned to `minSize` (480x400), not its
    /// real launch frame, which lands a few passes later once the window is actually
    /// visible. Applying the initial sidebar state against that transient size raced
    /// the window's own resize-to-real-size and could leave the divider at a stale
    /// width. `viewDidLayout()` now gates on `view.window?.isVisible`, so with no
    /// window at all (`view.window == nil`, `isVisible` is nil, never `== true`) it
    /// must no-op instead of auto-applying state against a not-yet-real size.
    func testViewDidLayoutDoesNotAutoApplyStateWithoutAWindow() {
        withTemporaryKouenHome {
            SessionCoordinator.shared.settings.sidebarOnRight = true
            SessionCoordinator.shared.settings.sidebarVisible = true
            let vc = MainSplitViewController()
            vc.view.setFrameSize(NSSize(width: 1000, height: 600))
            vc.view.layoutSubtreeIfNeeded()

            XCTAssertNil(vc.view.window)
            vc.viewDidLayout()

            // No window → the guard returns early → applyInitialSidebarState() never
            // ran, so the content pane must NOT already be at the correct post-expand
            // width (the real code path, tested below, is otherwise correct).
            XCTAssertNotEqual(
                vc.contentVC.view.frame.width, 1000 - KouenDesign.sidebarWidth, accuracy: 1)

            vc.setSidebarVisible(true, animated: false)
            XCTAssertEqual(
                vc.contentVC.view.frame.width, 1000 - KouenDesign.sidebarWidth, accuracy: 1)
        }
    }

    /// Regression test for cmd-backslash-sidebar-zero-width: a persisted `sidebarWidth: 0`
    /// (e.g. from a stuck `allowFullCollapse` letting a real user drag reach 0, see
    /// `handlePotentialUserSidebarResize`) made `applySidebarVisibility` compute
    /// `target == 0` for both show and hide — the toggle looked completely dead on every
    /// press, keyboard and menu alike, on a real release build. `persistedWidth` must now
    /// clamp to the same floor `SplitChromeDelegate` enforces on user drags, so expanding
    /// a corrupted-zero-width sidebar still produces a real, visible width.
    func testCorruptedZeroSidebarWidthStillExpandsToAVisibleWidth() {
        withTemporaryKouenHome {
            SessionCoordinator.shared.settings.sidebarOnRight = false
            SessionCoordinator.shared.settings.sidebarVisible = false
            SessionCoordinator.shared.settings.sidebarWidth = 0
            let vc = makeSplitController()

            vc.setSidebarVisible(true, animated: false)

            // Bug reproduced would leave content pane at the full 1000pt (sidebar
            // effectively still 0-width/invisible). Fixed behavior clamps to the same
            // 200pt floor `SplitChromeDelegate` enforces on manual drags.
            XCTAssertEqual(vc.contentVC.view.frame.width, 1000 - 200, accuracy: 1)
        }
    }

    /// Regression test for the collapsed-sidebar screen-change/resize bug: with the
    /// sidebar collapsed (`isHidden == true`) but idle (`allowFullCollapse == false`),
    /// `SplitChromeDelegate`'s constrain methods used to still reserve the ~200pt drag
    /// floor for a relayout (screen change, window resize), pulling a blank (still
    /// hidden) sidebar-shaped gap back into view. `isSubviewCollapsed` and the
    /// hidden-aware constrain floors must relax the moment the sidebar panel is
    /// hidden, not only mid-animation (`allowFullCollapse`).
    ///
    /// Exercises the delegate directly rather than through a real NSSplitView
    /// relayout: `shouldAdjustSizeOfSubview` already opts the sidebar out of
    /// AppKit's automatic subview resize on a plain window/view resize, so a
    /// synthetic `setFrameSize` never reaches the broken constrain path — the
    /// delegate's own return values are the actual mechanism that broke.
    func testCollapsedSidebarConstraintsRelaxWhenHiddenAtRest() {
        withTemporaryKouenHome {
            let split = NSSplitView(frame: NSRect(x: 0, y: 0, width: 1000, height: 600))
            let panel = NSView()
            panel.isHidden = true
            let delegate = SplitChromeDelegate()
            delegate.sidebarPanel = panel
            XCTAssertFalse(delegate.allowFullCollapse)

            XCTAssertTrue(delegate.splitView(split, isSubviewCollapsed: panel))

            SessionCoordinator.shared.settings.sidebarOnRight = true
            XCTAssertEqual(
                delegate.splitView(split, constrainMaxCoordinate: 0, ofSubviewAt: 0), 1000, accuracy: 0.5,
                "right-side sidebar hidden at rest must let the content pane reach full width")

            SessionCoordinator.shared.settings.sidebarOnRight = false
            XCTAssertEqual(
                delegate.splitView(split, constrainMinCoordinate: 0, ofSubviewAt: 0), 0, accuracy: 0.5,
                "left-side sidebar hidden at rest must let the divider reach 0")

            // Once visible again, the ~200pt drag floor must still apply.
            panel.isHidden = false
            XCTAssertFalse(delegate.splitView(split, isSubviewCollapsed: panel))
            SessionCoordinator.shared.settings.sidebarOnRight = true
            XCTAssertEqual(
                delegate.splitView(split, constrainMaxCoordinate: 0, ofSubviewAt: 0), 800, accuracy: 0.5)
            SessionCoordinator.shared.settings.sidebarOnRight = false
            XCTAssertEqual(
                delegate.splitView(split, constrainMinCoordinate: 0, ofSubviewAt: 0), 200, accuracy: 0.5)
        }
    }
}
