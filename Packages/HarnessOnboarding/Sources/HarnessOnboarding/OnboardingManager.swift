import SwiftUI
import AppKit

/// Public entry point for the immersive first-run wizard, embedded inside Harness.app.
///
/// The wizard is a borderless glass takeover (`ImmersiveOnboardingWindowController`). Unlike
/// the original standalone app, finishing the wizard here **dismisses the panel and reveals
/// Harness** — it never terminates the host app.
@MainActor
public enum HarnessOnboarding {
    /// First-run flag. Reuses the app's historical key so an upgraded install that already
    /// completed onboarding is not re-shown.
    private static let shownKey = "HarnessOnboardingShown_v1"

    /// Strong reference so the controller (and its window/closures) stay alive for the
    /// duration of the experience — without it the temporary would deallocate and the
    /// finish/skip callbacks would never fire.
    private static var activeController: ImmersiveOnboardingWindowController?

    /// Present on true first run only (or when `force` is set). Completion is recorded when the
    /// wizard is *dismissed* (see `showController`), not here — so a launch where the panel never
    /// actually reaches the screen (early exit, the async present losing the race) doesn't burn the
    /// one-shot flag and skip onboarding forever.
    public static func presentIfNeeded(force: Bool = false) {
        let defaults = UserDefaults.standard
        if !force && defaults.bool(forKey: shownKey) { return }
        // `force` (Help → Welcome) is a deliberate re-show and must never re-arm the first-run flag.
        let persistOnDismiss = !force
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showController(persistOnDismiss: persistOnDismiss) }
    }

    /// Force re-show even if the flag is set (Help → Welcome to Harness).
    public static func present() {
        presentIfNeeded(force: true)
    }

    /// Reset for development / QA.
    public static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: shownKey)
    }

    private static func showController(persistOnDismiss: Bool) {
        // Already on screen — bring it forward instead of stacking a second panel.
        if let existing = activeController {
            existing.showWindow(nil)
            return
        }
        let controller = ImmersiveOnboardingWindowController(onDismiss: {
            // Record completion now that the user has actually seen + dismissed the wizard.
            if persistOnDismiss { UserDefaults.standard.set(true, forKey: shownKey) }
            activeController = nil
        })
        activeController = controller
        controller.showWindow(nil)
    }
}
