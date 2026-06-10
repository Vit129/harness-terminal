import AppKit
import HarnessCore
import HarnessTerminalKit
import UserNotifications

extension SettingsViewController {
    // MARK: - Page: Keys

    func buildKeysPage() -> NSView {
        let header = pageHeader(title: "Keys", trailing: nil)

        let prefixGroup = settingsGroup("Prefix", [
            settingsRow("Prefix key", keyRecorder, hint: "Click to record a new shortcut. Esc cancels."),
        ])

        let stack = NSStackView(views: [header, prefixGroup])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        return scrollWrap(stack)
    }
}
