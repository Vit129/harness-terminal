import AppKit
import UserNotifications

/// Lets the first-run wizard ask macOS for notification permission with context, so a freshly
/// downloaded Harness can alert on agent activity without the user hunting through Settings.
///
/// The app installs the foreground-presentation delegate at launch (`DesktopNotifier`); this
/// helper only drives the system prompt, or routes to System Settings when already denied
/// (macOS never re-prompts after a denial).
enum NotificationPermission {
    enum State: Equatable, Sendable { case granted, denied, undetermined }

    private static func map(_ status: UNAuthorizationStatus) -> State {
        switch status {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        default: return .undetermined
        }
    }

    /// Current permission, delivered on the main queue.
    /// Disabled: UNUserNotificationCenter.current() crashes on macOS 26 beta.
    static func current(_ completion: @escaping @MainActor @Sendable (State) -> Void) {
        deliver(.undetermined, to: completion)
    }

    /// Prompt when undecided; open System Settings ▸ Notifications when already denied.
    /// Disabled: UNUserNotificationCenter.current() crashes on macOS 26 beta.
    static func request(_ completion: @escaping @MainActor @Sendable (State) -> Void) {
        openSystemSettings()
        deliver(.undetermined, to: completion)
    }

    private static func deliver(_ state: State, to completion: @escaping @MainActor @Sendable (State) -> Void) {
        Task { @MainActor in completion(state) }
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }
}
