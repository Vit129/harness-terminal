import AppKit
import KouenCore

@MainActor
enum MainMenuBuilder {
    /// Create an NSMenuItem from a registry Keybinding.
    private static func menuItem(_ title: String, action: Selector, binding: Keybinding) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: binding.keyChar)
        item.keyEquivalentModifierMask = binding.modifiers.modifierFlags
        item.target = MenuTarget.shared
        return item
    }

    static func build() -> NSMenu {
        let main = NSMenu()

        let app = NSMenuItem()
        app.submenu = NSMenu(title: "Kouen")
        let aboutItem = NSMenuItem(title: "About Kouen", action: #selector(MenuTarget.showAbout), keyEquivalent: "")
        aboutItem.target = MenuTarget.shared
        app.submenu?.addItem(aboutItem)
        app.submenu?.addItem(.separator())
        let checkUpdates = NSMenuItem(title: "Check for Updates…", action: SparkleUpdater.checkForUpdatesAction, keyEquivalent: "")
        checkUpdates.target = SparkleUpdater.shared.controller
        app.submenu?.addItem(checkUpdates)
        app.submenu?.addItem(.separator())
        let installItem = NSMenuItem(title: "Install kouen-cli…", action: #selector(MenuTarget.installCLI), keyEquivalent: "")
        installItem.target = MenuTarget.shared
        app.submenu?.addItem(installItem)
        app.submenu?.addItem(.separator())
        let prefs = NSMenuItem(title: "Settings…", action: #selector(MenuTarget.openSettings), keyEquivalent: ",")
        prefs.target = MenuTarget.shared
        app.submenu?.addItem(prefs)
        app.submenu?.addItem(.separator())
        let hide = NSMenuItem(title: "Hide Kouen", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.submenu?.addItem(hide)
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        app.submenu?.addItem(hideOthers)
        app.submenu?.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        app.submenu?.addItem(.separator())
        app.submenu?.addItem(NSMenuItem(title: "Quit Kouen", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        main.addItem(app)

        // Edit — standard responder-chain actions so Copy/Paste/Select All work in
        // the focused terminal (and any text field). Target nil routes through the
        // responder chain to whichever view is first responder.
        let edit = NSMenuItem()
        edit.submenu = NSMenu(title: "Edit")
        edit.submenu?.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.submenu?.addItem(redo)
        edit.submenu?.addItem(.separator())
        edit.submenu?.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.submenu?.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.submenu?.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.submenu?.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        main.addItem(edit)

        let workspace = NSMenuItem()
        workspace.submenu = NSMenu(title: "Session")
        let newSessionItem = menuItem("New Session", action: #selector(MenuTarget.newSession), binding: BannerShortcutRegistry.newSession)
        workspace.submenu?.addItem(newSessionItem)
        let closeTab = menuItem("Close Tab", action: #selector(MenuTarget.closeTab), binding: BannerShortcutRegistry.closeTab)
        workspace.submenu?.addItem(closeTab)
        let closeSession = NSMenuItem(title: "Close Session", action: #selector(MenuTarget.closeSession), keyEquivalent: "")
        closeSession.target = MenuTarget.shared
        workspace.submenu?.addItem(closeSession)
        workspace.submenu?.addItem(.separator())
        for index in 1...9 {
            let item = NSMenuItem(
                title: "Switch to Session \(index)",
                action: #selector(MenuTarget.selectWorkspaceNumber(_:)),
                keyEquivalent: "\(index)"
            )
            item.tag = index
            item.target = MenuTarget.shared
            workspace.submenu?.addItem(item)
        }
        let prevSession = menuItem("Previous Session", action: #selector(MenuTarget.previousSession), binding: BannerShortcutRegistry.previousSession)
        workspace.submenu?.addItem(prevSession)
        let nextSession = menuItem("Next Session", action: #selector(MenuTarget.nextSession), binding: BannerShortcutRegistry.nextSession)
        workspace.submenu?.addItem(nextSession)
        workspace.submenu?.addItem(.separator())
        let moveSessionLeft = menuItem("Move Session Left", action: #selector(MenuTarget.moveSessionLeft), binding: BannerShortcutRegistry.moveSessionLeft)
        workspace.submenu?.addItem(moveSessionLeft)
        let moveSessionRight = menuItem("Move Session Right", action: #selector(MenuTarget.moveSessionRight), binding: BannerShortcutRegistry.moveSessionRight)
        workspace.submenu?.addItem(moveSessionRight)
        main.addItem(workspace)

        let view = NSMenuItem()
        view.submenu = NSMenu(title: "View")
        let splitHItem = menuItem("Split Right", action: #selector(MenuTarget.splitH), binding: BannerShortcutRegistry.splitRight)
        view.submenu?.addItem(splitHItem)

        let splitVItem = menuItem("Split Down", action: #selector(MenuTarget.splitV), binding: BannerShortcutRegistry.splitDown)
        view.submenu?.addItem(splitVItem)

        // M4: branch the active pane's running agent conversation into a new split, in the
        // same cwd, continuing from where it is now. Only enabled for agents with a real,
        // CLI-native fork mechanism (validateMenuItem below) — Kouen wraps opaque CLI
        // subprocesses and has no visibility into an agent's conversation state on its own,
        // so this can't be a generic feature the way it might be in a tool that owns its
        // own LLM orchestration.
        let forkConversationItem = NSMenuItem(title: "Fork Conversation", action: #selector(MenuTarget.forkConversation), keyEquivalent: "")
        forkConversationItem.target = MenuTarget.shared
        view.submenu?.addItem(forkConversationItem)

        // M5: named, reusable split arrangements — shape only (directions/ratios/leaf
        // positions), never running processes. Distinct from the pre-existing daemon
        // session-restore (which snapshots one specific session's live state).
        let saveLayoutItem = NSMenuItem(title: "Save Current Layout as Template…", action: #selector(MenuTarget.saveCurrentLayout), keyEquivalent: "")
        saveLayoutItem.target = MenuTarget.shared
        view.submenu?.addItem(saveLayoutItem)
        let applyLayoutItem = NSMenuItem(title: "Apply Saved Layout…", action: #selector(MenuTarget.applySavedLayout), keyEquivalent: "")
        applyLayoutItem.target = MenuTarget.shared
        view.submenu?.addItem(applyLayoutItem)

        let peerReviewItem = NSMenuItem(title: "Request Peer Review", action: #selector(MenuTarget.requestPeerReview), keyEquivalent: "")
        peerReviewItem.target = MenuTarget.shared
        view.submenu?.addItem(peerReviewItem)
        view.submenu?.addItem(.separator())

        let prevPane = menuItem("Previous Pane", action: #selector(MenuTarget.previousPane), binding: BannerShortcutRegistry.previousPane)
        view.submenu?.addItem(prevPane)
        let nextPane = menuItem("Next Pane", action: #selector(MenuTarget.nextPane), binding: BannerShortcutRegistry.nextPane)
        view.submenu?.addItem(nextPane)
        view.submenu?.addItem(.separator())

        let focusLeft = NSMenuItem(title: "Focus Pane Left", action: #selector(MenuTarget.focusPaneLeft), keyEquivalent: "\u{F702}")
        focusLeft.keyEquivalentModifierMask = [.command, .shift]
        focusLeft.target = MenuTarget.shared
        view.submenu?.addItem(focusLeft)
        let focusRight = NSMenuItem(title: "Focus Pane Right", action: #selector(MenuTarget.focusPaneRight), keyEquivalent: "\u{F703}")
        focusRight.keyEquivalentModifierMask = [.command, .shift]
        focusRight.target = MenuTarget.shared
        view.submenu?.addItem(focusRight)
        let focusUp = NSMenuItem(title: "Focus Pane Up", action: #selector(MenuTarget.focusPaneUp), keyEquivalent: "\u{F700}")
        focusUp.keyEquivalentModifierMask = [.command, .shift]
        focusUp.target = MenuTarget.shared
        view.submenu?.addItem(focusUp)
        let focusDown = NSMenuItem(title: "Focus Pane Down", action: #selector(MenuTarget.focusPaneDown), keyEquivalent: "\u{F701}")
        focusDown.keyEquivalentModifierMask = [.command, .shift]
        focusDown.target = MenuTarget.shared
        view.submenu?.addItem(focusDown)

        let closePane = menuItem("Close Pane", action: #selector(MenuTarget.closePane), binding: BannerShortcutRegistry.closePane)
        view.submenu?.addItem(closePane)
        view.submenu?.addItem(.separator())

        let detachItem = NSMenuItem(title: "Detach Pane", action: #selector(MenuTarget.detachPane), keyEquivalent: "")
        detachItem.target = MenuTarget.shared
        view.submenu?.addItem(detachItem)
        let reattachItem = NSMenuItem(title: "Reattach Pane", action: #selector(MenuTarget.reattachPane), keyEquivalent: "")
        reattachItem.target = MenuTarget.shared
        view.submenu?.addItem(reattachItem)
        view.submenu?.addItem(.separator())
        let jumpItem = NSMenuItem(title: "Show Notifications", action: #selector(MenuTarget.jumpNotification), keyEquivalent: "i")
        jumpItem.keyEquivalentModifierMask = [.command, .control]
        jumpItem.target = MenuTarget.shared
        view.submenu?.addItem(jumpItem)
        let notchItem = NSMenuItem(title: "Toggle Agent Notch", action: #selector(MenuTarget.toggleAgentNotch), keyEquivalent: "i")
        notchItem.keyEquivalentModifierMask = [.command, .shift]
        notchItem.target = MenuTarget.shared
        view.submenu?.addItem(notchItem)
        let paletteItem = menuItem("Command Palette", action: #selector(MenuTarget.commandPalette), binding: BannerShortcutRegistry.commandPalette)
        view.submenu?.addItem(paletteItem)
        let promptItem = menuItem("Command Prompt", action: #selector(MenuTarget.commandPrompt), binding: BannerShortcutRegistry.commandPrompt)
        view.submenu?.addItem(promptItem)
        let queueItem = NSMenuItem(title: "Add Clipboard to Queue", action: #selector(MenuTarget.addToQueue), keyEquivalent: "\r")
        queueItem.keyEquivalentModifierMask = [.command, .shift]
        queueItem.target = MenuTarget.shared
        view.submenu?.addItem(queueItem)
        let searchHistoryItem = NSMenuItem(title: "Search Command History...", action: #selector(MenuTarget.searchCommandHistory), keyEquivalent: "r")
        searchHistoryItem.keyEquivalentModifierMask = [.control]
        searchHistoryItem.target = MenuTarget.shared
        view.submenu?.addItem(searchHistoryItem)
        let scrollbackSearchItem = menuItem("Find in Scrollback", action: #selector(MenuTarget.find), binding: BannerShortcutRegistry.scrollbackSearch)
        view.submenu?.addItem(scrollbackSearchItem)
        let findItem = menuItem("Find in Files…", action: #selector(MenuTarget.findInFiles), binding: BannerShortcutRegistry.findInFiles)
        view.submenu?.addItem(findItem)
        let sidebarItem = menuItem("Toggle Sidebar", action: #selector(MenuTarget.toggleSidebar), binding: BannerShortcutRegistry.toggleSidebar)
        view.submenu?.addItem(sidebarItem)
        let hintItem = menuItem("Hint Mode (Open Link by Key)", action: #selector(MenuTarget.hintMode), binding: BannerShortcutRegistry.hintMode)
        view.submenu?.addItem(hintItem)
        let composerItem = menuItem("Composer", action: #selector(MenuTarget.openComposer), binding: BannerShortcutRegistry.composer)
        view.submenu?.addItem(composerItem)
        let recipesItem = menuItem("Recipes & History…", action: #selector(MenuTarget.recipes), binding: BannerShortcutRegistry.recipes)
        view.submenu?.addItem(recipesItem)
        let jumpToDirItem = menuItem("Jump to Directory…", action: #selector(MenuTarget.jumpToDirectory), binding: BannerShortcutRegistry.jumpToDirectory)
        view.submenu?.addItem(jumpToDirItem)
let exportLayoutItem = NSMenuItem(title: "Export Layout…", action: #selector(MenuTarget.exportLayout), keyEquivalent: "")
        exportLayoutItem.target = MenuTarget.shared
        view.submenu?.addItem(exportLayoutItem)
        let importLayoutItem = NSMenuItem(title: "Import Layout…", action: #selector(MenuTarget.importLayout), keyEquivalent: "")
        importLayoutItem.target = MenuTarget.shared
        view.submenu?.addItem(importLayoutItem)
        let viModeItem = menuItem("Toggle Vi Mode", action: #selector(MenuTarget.toggleViMode), binding: BannerShortcutRegistry.toggleViMode)
        view.submenu?.addItem(viModeItem)
        let floatingPaneItem = menuItem("Floating Terminal", action: #selector(MenuTarget.openFloatingPane), binding: BannerShortcutRegistry.floatingPane)
        view.submenu?.addItem(floatingPaneItem)
        let tabOverviewItem = menuItem("Tab Overview", action: #selector(MenuTarget.tabOverview), binding: BannerShortcutRegistry.tabOverview)
        view.submenu?.addItem(tabOverviewItem)
        let forkTabItem = menuItem("Fork Tab", action: #selector(MenuTarget.forkTab), binding: BannerShortcutRegistry.forkTab)
        view.submenu?.addItem(forkTabItem)
        view.submenu?.addItem(.separator())
        let runItem = menuItem("Run Script", action: #selector(MenuTarget.runScript), binding: BannerShortcutRegistry.runScript)
        view.submenu?.addItem(runItem)
        let stopItem = menuItem("Stop Script", action: #selector(MenuTarget.stopScript), binding: BannerShortcutRegistry.stopScript)
        view.submenu?.addItem(stopItem)
        let sidebarPosItem = NSMenuItem(title: "Move Sidebar to Right", action: #selector(MenuTarget.toggleSidebarPosition), keyEquivalent: "")
        sidebarPosItem.target = MenuTarget.shared
        view.submenu?.addItem(sidebarPosItem)
        view.submenu?.addItem(.separator())
        let zoomIn = NSMenuItem(title: "Increase Font Size", action: #selector(MenuTarget.zoomIn), keyEquivalent: "+")
        zoomIn.keyEquivalentModifierMask = [.command]
        zoomIn.target = MenuTarget.shared
        view.submenu?.addItem(zoomIn)
        // ⌘= alias so zooming in doesn't require Shift to reach "+". Marked as an
        // alternate of the item above with the same modifier mask, so AppKit keeps
        // its key equivalent live without showing a duplicate menu row.
        let zoomInAlias = NSMenuItem(title: "Increase Font Size", action: #selector(MenuTarget.zoomIn), keyEquivalent: "=")
        zoomInAlias.keyEquivalentModifierMask = [.command]
        zoomInAlias.isAlternate = true
        zoomInAlias.target = MenuTarget.shared
        view.submenu?.addItem(zoomInAlias)
        let zoomOut = NSMenuItem(title: "Decrease Font Size", action: #selector(MenuTarget.zoomOut), keyEquivalent: "-")
        zoomOut.keyEquivalentModifierMask = [.command]
        zoomOut.target = MenuTarget.shared
        view.submenu?.addItem(zoomOut)
        let zoomReset = NSMenuItem(title: "Reset Font Size", action: #selector(MenuTarget.zoomReset), keyEquivalent: "0")
        zoomReset.keyEquivalentModifierMask = [.command]
        zoomReset.target = MenuTarget.shared
        view.submenu?.addItem(zoomReset)
        view.submenu?.addItem(.separator())
        let opacityItem = NSMenuItem(title: "Toggle Solid/Glass Opacity Mode", action: #selector(MenuTarget.toggleWindowOpacity), keyEquivalent: "u")
        opacityItem.keyEquivalentModifierMask = [.command, .shift]
        opacityItem.target = MenuTarget.shared
        view.submenu?.addItem(opacityItem)
        main.addItem(view)

        // Remote — connect the GUI to a KouenDaemon on another machine over an SSH tunnel.
        // The submenu is rebuilt on open (NSMenuDelegate) so it reflects saved hosts + which one
        // is currently connected.
        let remote = NSMenuItem()
        let remoteMenu = NSMenu(title: "Remote")
        remoteMenu.delegate = MenuTarget.shared
        remote.submenu = remoteMenu
        main.addItem(remote)

        // Window — standard macOS window management. Registered as windowsMenu so
        // AppKit auto-populates the open-windows list and the standard actions work.
        let window = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        window.submenu = windowMenu
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(MainWindowController.toggleVisibleFrameZoom(_:)), keyEquivalent: ""))
        // Non-native ("fast") full screen: fills the screen without the macOS Space animation.
        let fastFullScreen = NSMenuItem(
            title: "Toggle Fast Full Screen",
            action: #selector(MainWindowController.toggleNonNativeFullscreen(_:)),
            keyEquivalent: "f"
        )
        fastFullScreen.keyEquivalentModifierMask = [.command, .control, .shift]
        windowMenu.addItem(fastFullScreen)
        windowMenu.addItem(.separator())
        let openBrowserItem = menuItem(
            "Open Browser Pane",
            action: #selector(MenuTarget.openBrowserPane),
            binding: BannerShortcutRegistry.browserPane
        )
        windowMenu.addItem(openBrowserItem)
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        main.addItem(window)
        NSApp.windowsMenu = windowMenu

        // Help
        let help = NSMenuItem()
        help.submenu = NSMenu(title: "Help")
        let welcome = NSMenuItem(title: "Welcome to Kouen", action: #selector(MenuTarget.showOnboarding), keyEquivalent: "")
        welcome.target = MenuTarget.shared
        help.submenu?.addItem(welcome)
        let shortcuts = NSMenuItem(title: "Keyboard Shortcuts", action: #selector(MenuTarget.showShortcuts), keyEquivalent: "/")
        shortcuts.keyEquivalentModifierMask = [.command]
        shortcuts.target = MenuTarget.shared
        help.submenu?.addItem(shortcuts)
        main.addItem(help)

        return main
    }
}

@MainActor
final class MenuTarget: NSObject, NSMenuItemValidation, NSMenuDelegate {
    static let shared = MenuTarget()

    /// Enable Detach only when the active pane is attached, Reattach only when it's released.
    /// Every other MenuTarget item stays enabled (default true), preserving prior behavior.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(detachPane): return !SessionCoordinator.shared.activePaneIsDetached
        case #selector(reattachPane): return SessionCoordinator.shared.activePaneIsDetached
        case #selector(reopenClosedTab): return SessionCoordinator.shared.canReopenClosedTab
        case #selector(toggleSidebarPosition):
            let right = SessionCoordinator.shared.settings.sidebarOnRight
            menuItem.title = right ? "Move Sidebar to Left" : "Move Sidebar to Right"
            return true
        case #selector(forkConversation):
            guard let kind = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.effectiveAgentKind else { return false }
            return MenuTarget.forkCommand(for: kind) != nil
        default: return true
        }
    }

    // MARK: - Remote menu (rebuilt on open)

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "Remote" else { return }
        menu.removeAllItems()
        let add = NSMenuItem(title: "Add Remote Host…", action: #selector(addRemoteHost), keyEquivalent: "")
        add.target = self
        menu.addItem(add)
        menu.addItem(.separator())

        let hosts = RemoteHostsService.shared.hosts()
        let active = RemoteHostsService.shared.activeHostName
        if hosts.isEmpty {
            let none = NSMenuItem(title: "No saved hosts", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        } else {
            for host in hosts {
                let item = NSMenuItem(
                    title: "\(host.name) — \(host.sshTarget)",
                    action: #selector(connectRemoteHost(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = host.name
                item.state = (host.name == active) ? .on : .off
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        let local = NSMenuItem(title: "Use Local Daemon", action: #selector(useLocalDaemon), keyEquivalent: "")
        local.target = self
        local.state = (active == nil) ? .on : .off
        menu.addItem(local)
    }

    @objc func addRemoteHost() {
        let alert = NSAlert()
        alert.messageText = "Add Remote Host"
        alert.informativeText = "Run KouenDaemon on the remote machine (kouen-cli install), "
            + "then connect to it over SSH."
        alert.addButton(withTitle: "Save & Connect")
        alert.addButton(withTitle: "Cancel")
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 320, height: 92))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 22))
        nameField.placeholderString = "Name (e.g. devbox)"
        let sshField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 22))
        sshField.placeholderString = "SSH target (user@host)"
        let sockField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 22))
        sockField.placeholderString = "Remote socket path"
        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(sshField)
        stack.addArrangedSubview(sockField)
        alert.accessoryView = stack
        alert.window.initialFirstResponder = nameField
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let ssh = sshField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !ssh.isEmpty else { return }
        let socketPath = sockField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if socketPath.isEmpty {
            let warn = NSAlert()
            warn.messageText = "Remote socket path required"
            warn.informativeText = "Use the path shown by `kouen-cli doctor` on the remote host."
            warn.runModal()
            return
        }
        RemoteHostsService.shared.addHost(
            RemoteHost(name: name, sshTarget: ssh, remoteSocketPath: socketPath))
        SessionCoordinator.shared.connectToRemote(named: name)
    }

    @objc func connectRemoteHost(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        SessionCoordinator.shared.connectToRemote(named: name)
    }

    @objc func useLocalDaemon() {
        SessionCoordinator.shared.disconnectRemote()
    }

    @objc func newSession() {
        let coordinator = SessionCoordinator.shared
        // Force a sync to ensure activeSession/activeTab reflect the currently visible tab,
        // not a stale snapshot from before the user's last tab switch.
        coordinator.syncFromDaemon()
        guard let id = coordinator.snapshot.activeWorkspaceID else { return }
        coordinator.addSession(to: id)
    }

    @objc func closeSession() {
        SessionCoordinator.shared.closeActiveSession()
    }

    @objc func closeTab() {
        SessionCoordinator.shared.closeActiveTab()
    }

    @objc func reopenClosedTab() {
        SessionCoordinator.shared.reopenLastClosedTab()
    }

    /// ⌘F contract (same "contextual, not a rewrite" principle as the thread-overlay
    /// cmd-F contract in p38-phase-c-thread-overlay/design.md): a fixed-target menu item
    /// always wins AppKit's key-equivalent dispatch before any focused view's own keyDown
    /// gets a chance to run — confirmed via trace, this is why `SyntaxTextView`'s own
    /// `if cmd && key == "f" { showFindBar() }` never fired even when the file preview
    /// had focus. Route by first responder instead of hardcoding the terminal find bar.
    @objc func find() {
        let responder = NSApp.keyWindow?.firstResponder
        NSLog("[DBG-cmdf] find() called, firstResponder=\(String(describing: responder)) class=\(type(of: responder))")
        if let syntaxView = Self.enclosingSyntaxTextView(of: responder) {
            NSLog("[DBG-cmdf] routing to SyntaxTextView.showFindBar()")
            syntaxView.showFindBar()
            return
        }
        NSLog("[DBG-cmdf] no enclosing SyntaxTextView found, falling back to terminal toggleFindBar()")
        SessionCoordinator.shared.toggleFindBar()
    }

    /// The first responder may be `SyntaxTextView` itself (it accepts first responder and
    /// handles `keyDown` directly) or its inner `NSTextView` — walk up either way.
    private static func enclosingSyntaxTextView(of responder: NSResponder?) -> SyntaxTextView? {
        var view = responder as? NSView
        while let current = view {
            NSLog("[DBG-cmdf] walk ancestor: \(type(of: current))")
            if let syntaxView = current as? SyntaxTextView { return syntaxView }
            view = current.superview
        }
        return nil
    }

    @objc func findInFiles() {
        CommandPaletteController.present(relativeTo: NSApp.keyWindow, mode: .grep(query: ""))
    }

    @objc func toggleWindowOpacity() {
        SessionCoordinator.shared.toggleWindowOpacity()
    }


    /// ⌘1–9 switch to the session (workspace) at that position in the sidebar.
    @objc func selectWorkspaceNumber(_ sender: NSMenuItem) {
        let index = sender.tag - 1
        let coordinator = SessionCoordinator.shared
        guard let workspace = coordinator.snapshot.activeWorkspace,
              index >= 0, index < workspace.sessions.count else { return }
        coordinator.selectSession(workspaceID: workspace.id, sessionID: workspace.sessions[index].id)
    }

    @objc func previousSession() {
        SessionCoordinator.shared.selectAdjacentSession(offset: -1)
    }

    @objc func nextSession() {
        SessionCoordinator.shared.selectAdjacentSession(offset: 1)
    }

    @objc func moveSessionLeft() {
        SessionCoordinator.shared.moveActiveSession(offset: -1)
    }

    @objc func moveSessionRight() {
        SessionCoordinator.shared.moveActiveSession(offset: 1)
    }

    @objc func splitH() {
        SessionCoordinator.shared.splitActivePane(direction: .horizontal)
    }

    @objc func splitV() {
        SessionCoordinator.shared.splitActivePane(direction: .vertical)
    }

    /// M4: per-agent-kind CLI-native fork command. Verified against each CLI's own
    /// `--help` (2026-08-05) — `claude --continue --fork-session` continues the most recent
    /// conversation in the current directory as a new session; `codex fork --last` forks the
    /// most recently recorded session the same way. Neither needs Kouen to discover/track a
    /// session ID itself. Every other AgentKind returns nil (menu item disabled instead —
    /// see `validateMenuItem`) rather than silently doing something that only looks like a
    /// fork (e.g. a fresh session in the same cwd, with no conversation history at all).
    static func forkCommand(for kind: AgentKind) -> String? {
        switch kind {
        case .claudeCode: return "claude --continue --fork-session"
        case .codex: return "codex fork --last"
        default: return nil
        }
    }

    @objc func forkConversation() {
        guard let kind = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.effectiveAgentKind,
              let command = Self.forkCommand(for: kind)
        else { return }
        SessionCoordinator.shared.splitActivePaneAndRun(direction: .horizontal, command: command)
    }

    // MARK: - Workgroup Review (M7)

    /// First surface in `candidates` that isn't `excluding` and passes `hasAgent`. Pure,
    /// no AppKit/daemon dependency — testable in isolation from the actual pane lookup.
    static func firstPeerSurfaceID(
        among candidates: [SurfaceID], excluding activeSurfaceID: SurfaceID, hasAgent: (SurfaceID) -> Bool
    ) -> SurfaceID? {
        candidates.first { $0 != activeSurfaceID && hasAgent($0) }
    }

    /// Human-triggered, not automatic-on-idle (the competitive-doc description) — reliably
    /// detecting "peer went idle" + capturing its response text + auto-pasting it back into
    /// the requesting pane needs an async wait/poll + text-extraction round trip this
    /// session didn't have time to build and verify against a real running agent. v1
    /// automates the ASKING step only (a real, cited manual habit) — the human reads the
    /// peer's review themselves. Documented cut, not an oversight.
    @objc func requestPeerReview() {
        let coord = SessionCoordinator.shared
        guard let tab = coord.snapshot.activeWorkspace?.activeTab else {
            let alert = NSAlert()
            alert.messageText = "No Active Tab"
            alert.informativeText = "Open a tab with a split pane running an agent to request a review."
            alert.runModal()
            return
        }

        // Bug found live (2026-08-06), 1st pass: originally gated peer-eligibility on
        // `AgentDetector.snapshot(...) != nil`, but that cache is populated ONLY by OSC 26
        // `waiting_input` status events (SessionCoordinator.swift's onAgentStatus handler) —
        // a narrow, CLI-cooperative signal. Claude Code emits it; other CLIs (confirmed:
        // Antigravity/"agy") may not, even though their pane correctly shows an agent icon
        // elsewhere via a *different*, daemon-sourced signal (Tab.effectiveAgentKind) with
        // no per-pane equivalent for a split tab. Fix: accept any other pane in the tab as a
        // peer — sending the review prompt to a plain idle shell is harmless.
        //
        // Bug found live, 2nd pass: after the above fix, "nothing happens" (no alert either)
        // — `coord.activeSurfaceID` is a KNOWN-stale GUI-side cache, not reliably reset on
        // tab/pane switches (see agent-memory/knowledge/focus-persistence.md, RL-043). Two
        // failure modes, both silent: nil → the old top-level guard returned bare with zero
        // feedback; stale-to-a-different-tab's-surface → `excluding:` never matched either
        // candidate, so `.first` silently picked candidate[0] (possibly the REQUESTING pane
        // itself) instead of erroring. Fix: resolve "who is asking" from the
        // daemon-authoritative `tab.activePaneID` (same source `focus-persistence.md`
        // recommends) instead of the GUI cache, and never return bare — every failure path
        // alerts now, so the next bug in this function (if any) reports itself instead of
        // requiring a 3rd guess-and-rebuild cycle.
        let leaves = tab.rootPane.allLeaves()
        guard let activePaneID = tab.activePaneID,
              let activeLeaf = leaves.first(where: { $0.id == activePaneID })
        else {
            // `allLeaves()` excludes browser leaves — an active browser pane legitimately
            // can't resolve here; that's a real "can't do this" case, not a bug to silence.
            let alert = NSAlert()
            alert.messageText = "Can't Determine Active Pane"
            alert.informativeText = "Click directly inside a terminal pane (not a browser pane), then try again."
            alert.runModal()
            return
        }
        let activeSurfaceID = activeLeaf.activeSurfaceID ?? activeLeaf.surfaceID

        let candidates = leaves.map { $0.activeSurfaceID ?? $0.surfaceID }
        let peerSurfaceID = Self.firstPeerSurfaceID(among: candidates, excluding: activeSurfaceID) { _ in true }

        NSLog("PEER_REVIEW_DEBUG: activePaneID=%@ activeSurfaceID=%@ candidates=%@ peer=%@",
              activePaneID.uuidString, activeSurfaceID.uuidString,
              candidates.map(\.uuidString).joined(separator: ","), peerSurfaceID?.uuidString ?? "nil")

        guard let peerSurfaceID else {
            let alert = NSAlert()
            alert.messageText = "No Peer Agent Found"
            alert.informativeText = "Open another split/tab with an agent running in this repo to request a review."
            alert.runModal()
            return
        }

        let prompt = "Please run `git diff` in the current repo, review the changes, and summarize any issues you find."
        Task {
            await coord.requestDaemon(.sendData(surfaceID: peerSurfaceID.uuidString, data: Data((prompt + "\n").utf8)))
        }
    }

    // MARK: - Saved Layouts (M5)

    @objc func saveCurrentLayout() {
        let alert = NSAlert()
        alert.messageText = "Save Current Layout"
        alert.informativeText = "Captures this tab's split structure (shape only — no running processes) as a reusable template."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        nameField.placeholderString = "Name (e.g. 3-pane dev)"
        alert.accessoryView = nameField
        alert.window.initialFirstResponder = nameField
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        SessionCoordinator.shared.saveCurrentLayout(name: name)
    }

    @objc func applySavedLayout() {
        Task { @MainActor in
            let layouts = await SessionCoordinator.shared.listSavedLayouts()
            guard !layouts.isEmpty else {
                let alert = NSAlert()
                alert.messageText = "No Saved Layouts"
                alert.informativeText = "Use \"Save Current Layout as Template…\" first."
                alert.runModal()
                return
            }
            let alert = NSAlert()
            alert.messageText = "Apply Saved Layout"
            alert.informativeText = "Creates a new tab with this layout's split structure (empty shells, no running processes)."
            alert.addButton(withTitle: "Apply")
            alert.addButton(withTitle: "Cancel")
            let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 26))
            popup.addItems(withTitles: layouts.map(\.name))
            alert.accessoryView = popup
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let index = popup.indexOfSelectedItem
            guard layouts.indices.contains(index) else { return }
            SessionCoordinator.shared.applySavedLayout(layouts[index])
        }
    }

    @objc func runScript() {
        SessionCoordinator.shared.runProjectScript()
    }

    @objc func stopScript() {
        SessionCoordinator.shared.stopProjectScript()
    }

    @objc func focusPaneLeft() { SessionCoordinator.shared.focusPaneDirectional(.left) }
    @objc func focusPaneRight() { SessionCoordinator.shared.focusPaneDirectional(.right) }
    @objc func focusPaneUp() { SessionCoordinator.shared.focusPaneDirectional(.up) }
    @objc func focusPaneDown() { SessionCoordinator.shared.focusPaneDirectional(.down) }
    @objc func closePane() {
        SessionCoordinator.shared.closeActivePane()
    }

    @objc func previousPane() { SessionCoordinator.shared.cycleActivePane(forward: false) }
    @objc func nextPane() { SessionCoordinator.shared.cycleActivePane(forward: true) }

    @objc func detachPane() {
        SessionCoordinator.shared.detachActiveSurface()
    }

    @objc func reattachPane() {
        SessionCoordinator.shared.reattachActiveSurface()
    }

    @objc func jumpNotification() {
        // Iterate all windows so the lookup succeeds even when the key window is a
        // panel or sheet rather than the main content window.
        for window in NSApp.windows {
            if let split = window.contentViewController as? MainSplitViewController {
                split.showNotificationsDropdown()
                return
            }
        }
    }

    @objc func toggleAgentNotch() {
        NotchPanelController.shared.toggleFromMenu()
    }

    @objc func openComposer() {
        SessionCoordinator.shared.openComposer()
    }

    @objc func recipes() {
        if let window = NSApp.keyWindow {
            RecipePickerController.present(relativeTo: window)
        }
    }

    @objc func jumpToDirectory() {
        if let window = NSApp.keyWindow {
            DirectoryPickerController.present(relativeTo: window)
        }
    }

    @objc func showOnboarding() {
        OnboardingController.present()
    }

    @objc func showShortcuts() {
        PrefixCheatsheetWindow.shared.toggle()
    }

    @objc func commandPalette() {
        if let window = NSApp.keyWindow {
            CommandPaletteController.present(relativeTo: window)
        }
    }

    @objc func commandPrompt() {
        CommandPromptController.shared.present()
    }

    @objc func searchCommandHistory() {
        CommandHistorySearchController.shared.present()
    }

    @objc func addToQueue() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        SessionCoordinator.shared.enqueueCommand(text)
    }

    @objc func openSettings() {
        SettingsWindowController.show()
    }

    @objc func hintMode() { SessionCoordinator.shared.showHintMode() }

@objc func exportLayout() { LayoutFileStore.exportCurrentLayout() }
    @objc func importLayout() { LayoutFileStore.importLayout() }
    @objc func toggleViMode() { SessionCoordinator.shared.toggleViMode() }
    @objc func openFloatingPane() { FloatingPaneController.shared.toggle() }
    @objc func tabOverview() { TabOverviewController.shared.toggle() }
    @objc func forkTab() { SessionCoordinator.shared.forkTab() }

    @objc func toggleSidebar() {
        // `keyWindow ?? mainWindow` short-circuits on any non-nil keyWindow — Agent Notch
        // and Composer are both `canBecomeKey` floating panels, so this silently no-op'd
        // whenever either had focus. Iterate all windows instead, same fix as jumpNotification().
        for window in NSApp.windows {
            if let split = window.contentViewController as? MainSplitViewController {
                split.toggleSidebar()
                return
            }
        }
    }

    @objc func toggleSidebarPosition() {
        for window in NSApp.windows {
            if let split = window.contentViewController as? MainSplitViewController {
                split.toggleSidebarPosition()
                return
            }
        }
    }

    @objc func zoomIn() {
        SessionCoordinator.shared.updateFontSize(delta: 1)
    }

    @objc func zoomOut() {
        SessionCoordinator.shared.updateFontSize(delta: -1)
    }

    @objc func zoomReset() {
        SessionCoordinator.shared.resetFontSize()
    }

    @objc func installCLI() {
        CLIInstaller.install()
    }

    @objc func showAbout() {
        AboutPanelController.show()
    }

    @objc func openBrowserPane() {
        let home = SessionCoordinator.shared.settings.browserHomePage
        SessionCoordinator.shared.splitPaneCoordinator.openBrowserPane(
            url: URL(string: home) ?? URL(string: "https://www.google.com")!,
            direction: .horizontal
        )
    }
}
