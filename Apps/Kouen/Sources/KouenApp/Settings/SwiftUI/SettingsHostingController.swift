import AppKit
import SwiftUI
import KouenCore

@MainActor
final class SettingsHostingController: NSHostingController<SettingsRootView> {
    init(page: SettingsRootView.Page = .appearance) {
        let model = SettingsModel()
        super.init(rootView: SettingsRootView(model: model, initialPage: page))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

@MainActor
final class SettingsWindowController: NSObject {
    /// Page index for the Remote page — kept as Int for call-site compatibility.
    static let pageRemote = SettingsRootView.Page.remote.rawValue

    private static var window: NSWindow?

    static func show(page: Int = 0) {
        window?.close()
        let initialPage = SettingsRootView.Page(rawIndex: page) ?? .appearance
        let controller = SettingsHostingController(page: initialPage)
        let win = NSWindow(contentViewController: controller)
        win.title = "Settings"
        win.styleMask = [.titled, .closable, .resizable]
        win.titlebarAppearsTransparent = false
        win.titleVisibility = .visible
        win.isMovableByWindowBackground = false
        win.isRestorable = false
        win.preventsApplicationTerminationWhenModal = false
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 840, height: 600)
        win.setContentSize(NSSize(width: 940, height: 680))
        window = win
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: win
        )
        win.appearance = NSAppearance(named: KouenChrome.current.isDark ? .darkAqua : .aqua)
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private static func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: notification.object)
        window = nil
    }
}
