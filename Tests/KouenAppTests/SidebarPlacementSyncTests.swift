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

    /// Regression test for the 2026-09-06 cross-screen/resize "content pane stuck at
    /// old width" bug: confirmed live (device logs, moving the window from a MacBook
    /// display to an external Dell display and then zooming to fill it) that
    /// `NSSplitView.setPosition` — documented as advisory — silently clamped against a
    /// stale internally-cached arrangement that never recomputed for the split view's
    /// live bounds after a real resize while the sidebar sat collapsed. The delegate's
    /// own constrain methods returned the correct, unclamped values throughout; the
    /// divider position itself just didn't move. Net effect: ~480pt of the split view
    /// belonged to neither subview (nothing drawn there — the wallpaper showing through
    /// in the original report), no matter what position was requested.
    ///
    /// Root-cause fix: `setSidebarWidth` no longer trusts `setPosition` at all — it
    /// assigns `content.view.frame` / the sidebar panel's frame directly (the same
    /// escape hatch `updateSidebarPlacement()` already uses), which guarantees by
    /// construction that content + divider + sidebar always sum to the split view's
    /// current bounds, live-resize staleness or not.
    func testContentPaneFillsBoundsAcrossAResizeWhileCollapsed() {
        withTemporaryKouenHome {
            SessionCoordinator.shared.settings.sidebarOnRight = true
            SessionCoordinator.shared.settings.sidebarVisible = false
            let vc = makeSplitController(width: 1440)
            vc.setSidebarVisible(false, animated: false)
            XCTAssertEqual(vc.contentVC.view.frame.width, 1440, accuracy: 2)

            // Simulate the real repro: window moved to a wider display, then zoomed,
            // while the sidebar is still collapsed.
            vc.view.setFrameSize(NSSize(width: 1920, height: 600))
            vc.view.layoutSubtreeIfNeeded()
            vc.setSidebarVisible(false, animated: false)

            XCTAssertEqual(
                vc.contentVC.view.frame.width, 1920, accuracy: 2,
                "content pane must fill the new bounds after a resize while the sidebar is collapsed")

            vc.setSidebarVisible(true, animated: false)
            XCTAssertEqual(
                vc.contentVC.view.frame.width, 1920 - KouenDesign.sidebarWidth, accuracy: 2,
                "expanding after a resize must use the live bounds, not a stale pre-resize width")
        }
    }
}
