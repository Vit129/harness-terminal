import AppKit
import HarnessCore

extension HarnessSidebarPanelViewController {
    // MARK: - Session kebab menu

    /// Per-session actions shown on right-click of a session card (Warp-style).
    /// Items map to existing capabilities — rename via the `renameSession` IPC,
    /// close via `closeSession`, and clipboard copies handled locally. Returned for
    /// AppKit to position at the cursor (no manual `popUp`).
    func sessionActionsMenu(for session: SessionGroup) -> NSMenu {
        let menu = NSMenu()

        let rename = NSMenuItem(title: "Rename session…", action: #selector(renameSessionFromMenu(_:)), keyEquivalent: "")
        rename.target = self
        rename.representedObject = session.id
        menu.addItem(rename)

        let copyCwd = NSMenuItem(title: "Copy working directory", action: #selector(copySessionCwd(_:)), keyEquivalent: "")
        copyCwd.target = self
        copyCwd.representedObject = session.id
        menu.addItem(copyCwd)

        let copyTitle = NSMenuItem(title: "Copy session title", action: #selector(copySessionTitle(_:)), keyEquivalent: "")
        copyTitle.target = self
        copyTitle.representedObject = session.id
        menu.addItem(copyTitle)

        let copyID = NSMenuItem(title: "Copy Session ID", action: #selector(copySessionID(_:)), keyEquivalent: "")
        copyID.target = self
        copyID.representedObject = session.id
        menu.addItem(copyID)

        menu.addItem(.separator())

        let splitRight = NSMenuItem(title: "Split session right", action: #selector(splitSessionFromMenu(_:)), keyEquivalent: "")
        splitRight.target = self
        splitRight.representedObject = session.id
        splitRight.toolTip = SplitDirection.horizontal.rawValue
        menu.addItem(splitRight)

        let splitDown = NSMenuItem(title: "Split session down", action: #selector(splitSessionFromMenu(_:)), keyEquivalent: "")
        splitDown.target = self
        splitDown.representedObject = session.id
        splitDown.toolTip = SplitDirection.vertical.rawValue
        menu.addItem(splitDown)

        menu.addItem(.separator())

        let right = SessionCoordinator.shared.settings.sidebarOnRight
        let moveSidebar = NSMenuItem(title: right ? "Move Sidebar to Left" : "Move Sidebar to Right", action: #selector(toggleSidebarPositionFromMenu), keyEquivalent: "")
        moveSidebar.target = self
        menu.addItem(moveSidebar)

        menu.addItem(.separator())

        // Pin a session to survive a clean quit even in Plain mode (and the reverse). Always
        // offered for discoverability; the checkmark reflects the stored per-session intent. When
        // keep-on-quit is globally on, that intent is currently superseded (everything survives),
        // so the title says as much rather than hiding the control.
        let globallyKept = SessionCoordinator.shared.snapshot.keepSessionsOnQuit
        let pin = NSMenuItem(
            title: globallyKept ? "Keep running after quit (all sessions kept)" : "Keep running after quit",
            action: #selector(toggleSessionPersistent(_:)),
            keyEquivalent: ""
        )
        pin.target = self
        pin.representedObject = session.id
        pin.state = session.persistent ? .on : .off
        menu.addItem(pin)
        menu.addItem(.separator())

        let close = NSMenuItem(title: "Close session", action: #selector(closeSessionFromMenu(_:)), keyEquivalent: "")
        close.target = self
        close.representedObject = session.id
        menu.addItem(close)

        if sessions.count > 1 {
            let closeOthers = NSMenuItem(title: "Close other sessions", action: #selector(closeOtherSessionsFromMenu(_:)), keyEquivalent: "")
            closeOthers.target = self
            closeOthers.representedObject = session.id
            menu.addItem(closeOthers)
        }

        return menu
    }

    private func session(for id: SessionID) -> SessionGroup? {
        sessions.first { $0.id == id }
    }

    @objc private func renameSessionFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? SessionID, let session = session(for: id) else { return }
        let current = session.name.isEmpty ? sessionTitle(for: session) : session.name
        let alert = NSAlert()
        alert.messageText = "Rename session"
        alert.informativeText = "Enter a new name for this session."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        input.stringValue = current
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != session.name else { return }
        SessionCoordinator.shared.requestDaemon(.renameSession(sessionID: id, name: trimmed))
        SessionCoordinator.shared.syncFromDaemon()
    }

    @objc private func copySessionCwd(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? SessionID, let session = session(for: id),
              let tab = session.activeTab ?? session.tabs.first else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(tab.cwd, forType: .string)
    }

    @objc private func copySessionTitle(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? SessionID, let session = session(for: id) else { return }
        let title = session.name.isEmpty ? sessionTitle(for: session) : session.name
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(title, forType: .string)
    }

    @objc private func copySessionID(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? SessionID else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(id.uuidString, forType: .string)
    }

    @objc private func splitSessionFromMenu(_ sender: NSMenuItem) {
        guard let workspaceID = activeWorkspaceID,
              let sessionID = sender.representedObject as? SessionID,
              let rawDirection = sender.toolTip,
              let direction = SplitDirection(rawValue: rawDirection)
        else { return }
        SessionCoordinator.shared.splitSession(workspaceID: workspaceID, sessionID: sessionID, direction: direction)
    }

    @objc private func toggleSessionPersistent(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? SessionID, let session = session(for: id) else { return }
        SessionCoordinator.shared.requestDaemon(.setSessionPersistent(sessionID: id, persistent: !session.persistent))
        SessionCoordinator.shared.syncFromDaemon()
    }

    @objc private func closeSessionFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? SessionID, let session = session(for: id) else { return }
        confirmCloseSession(session)
    }

    @objc private func closeOtherSessionsFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? SessionID, let activeWorkspaceID else { return }
        let others = sessions.filter { $0.id != id }
        guard !others.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Close \(others.count) other session\(others.count == 1 ? "" : "s")?"
        alert.informativeText = "Their tabs and running shells will be closed. This can't be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close Others")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for session in others {
            // Through closeSession (not raw IPC) so each session's terminal hosts are
            // torn down too — otherwise stale TerminalHostViews linger in the registry.
            SessionCoordinator.shared.closeSession(session)
        }
        SessionCoordinator.shared.selectSession(workspaceID: activeWorkspaceID, sessionID: id)
        SessionCoordinator.shared.syncFromDaemon()
    }
}
