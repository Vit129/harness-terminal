import AppKit
import KouenCore
import UserNotifications

struct NotificationEntry: Identifiable, Equatable {
    let workspaceID: WorkspaceID
    let workspaceName: String
    let sessionID: SessionID
    let tabID: TabID
    let tabTitle: String
    let surfaceID: SurfaceID
    let agentKind: AgentKind?
    let body: String
    var id: TabID { tabID }
}

/// Presents notifications even while Kouen is the frontmost app — without a delegate,
/// UNUserNotificationCenter suppresses foreground notifications by default (Step 3 of
/// REVIEW-graphify-kouen-2026-07-03.md Part 3's fix plan). Stateless, so @unchecked Sendable
/// is safe here (no mutable state to race on), matching this codebase's existing pattern for
/// simple singleton delegates.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationPresenter()
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        var options: UNNotificationPresentationOptions = [.banner]
        if notification.request.content.sound != nil { options.insert(.sound) }
        completionHandler(options)
    }

    /// Clicking the banner or an action button routes to SessionCoordinator.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let idString = response.notification.request.content.userInfo["surfaceID"] as? String,
           let surfaceID = UUID(uuidString: idString) {
            let actionID = response.actionIdentifier
            Task { @MainActor in
                switch actionID {
                case DesktopNotifier.Action.focusPane, UNNotificationDefaultActionIdentifier:
                    SessionCoordinator.shared.notificationCoordinator.openSurface(surfaceID)
                case DesktopNotifier.Action.rerunCommand:
                    SessionCoordinator.shared.notificationCoordinator.rerunCommand(for: surfaceID)
                case DesktopNotifier.Action.copyOutput:
                    SessionCoordinator.shared.notificationCoordinator.copyOutput(for: surfaceID)
                default:
                    SessionCoordinator.shared.notificationCoordinator.openSurface(surfaceID)
                }
            }
        }
        completionHandler()
    }
}

enum DesktopNotifier {
    static let categoryIdentifier = "terminal-job"

    enum Action {
        static let focusPane = "focus-pane"
        static let rerunCommand = "rerun-command"
        static let copyOutput = "copy-output"
    }

    // UNUserNotificationCenter.current() crashes on some macOS 26 installs due to a corrupted
    // NSCalendarDate in the notification database (NotificationCenterProbe guards against this —
    // see its doc comment). When the probe hasn't run yet or has marked the center bad, every
    // method below falls back to NSAppleScript in-process: Standard Additions attributes
    // `display notification` to the process that executes it, so running inside Kouen
    // attributes the notification to Kouen rather than to the frontmost app.
    private static var isUNNotificationCenterAvailable: Bool {
        guard !NotificationCenterProbe.isKnownBad else { return false }
        guard let bundleID = Bundle.main.bundleIdentifier,
              !bundleID.hasPrefix("com.apple.dt.xctest"),
              NSClassFromString("XCTestCase") == nil else { return false }
        return true
    }

    static func requestAuthorizationIfNeeded() {
        guard isUNNotificationCenterAvailable else { return }
        NotificationCenterProbe.runAtLaunch()
        guard !NotificationCenterProbe.isKnownBad else { return }

        let focusAction = UNNotificationAction(
            identifier: Action.focusPane,
            title: "Focus Pane",
            options: [.foreground]
        )
        let rerunAction = UNNotificationAction(
            identifier: Action.rerunCommand,
            title: "Rerun Command",
            options: [.foreground]
        )
        let copyAction = UNNotificationAction(
            identifier: Action.copyOutput,
            title: "Copy Output",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [focusAction, rerunAction, copyAction],
            intentIdentifiers: [],
            options: []
        )

        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationPresenter.shared
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("DesktopNotifier: requestAuthorization failed: %@", error.localizedDescription)
            }
        }
    }
    /// - Parameter completion: reports whether the notification was actually delivered — via the
    ///   real API when safe, or via AppleScript's error result as a fallback.
    ///   `NSAppleScript` is main-thread-only, so the fallback path always dispatches there —
    ///   running it on a background queue (a previous version's behavior) could fail silently
    ///   depending on caller context.
    static func show(
        title: String, body: String, withSound: Bool = true, surfaceID: String? = nil,
        completion: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) {
        guard isUNNotificationCenterAvailable else {
            if NSClassFromString("XCTestCase") != nil {
                Task { @MainActor in completion?(true) }
                return
            }
            let soundClause = withSound ? " sound name \"Glass\"" : ""
            let script = """
                display notification "\(Self.escape(body))" with title "\(Self.escape(title))"\(soundClause)
                """
            DispatchQueue.main.async {
                var error: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&error)
                if let error {
                    NSLog("DesktopNotifier: display notification failed: %@", error)
                }
                let succeeded = error == nil
                Task { @MainActor in completion?(succeeded) }
            }
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = categoryIdentifier
        if withSound { content.sound = .default }
        if let surfaceID { content.userInfo = ["surfaceID": surfaceID] }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("DesktopNotifier: add(request:) failed: %@", error.localizedDescription)
            }
            let succeeded = error == nil
            Task { @MainActor in completion?(succeeded) }
        }
    }
    static func authorizationStatus(_ completion: @escaping @MainActor (UNAuthorizationStatus) -> Void) {
        guard isUNNotificationCenterAvailable else {
            Task { @MainActor in completion(.notDetermined) }
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in completion(status) }
        }
    }
    static func requestOrOpenSettings() { openSystemNotificationSettings() }
    static func openSystemNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }
    static func sendTest(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        show(title: "Kouen", body: "Notifications are working!", completion: completion)
    }
    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum KouenPathDisplay {
    static func title(for path: String, fallback: String) -> String {
        if path == "/" { return "/" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        let shortened = path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
        let last = (String(shortened) as NSString).lastPathComponent
        if !last.isEmpty { return last }
        if !fallback.isEmpty, fallback != "Shell" { return fallback }
        return "Terminal"
    }
}
