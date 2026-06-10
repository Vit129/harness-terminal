import AppKit
import HarnessCore

extension HarnessSidebarPanelViewController {
    // MARK: - Recent Projects

    private static let recentProjectsKey = "RecentProjectPaths"
    private static let maxRecents = 10

    private static func recentProjects() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentProjectsKey) ?? []
    }

    static func recordRecentProject(_ path: String) {
        var recents = recentProjects()
        recents.removeAll { $0 == path }
        recents.insert(path, at: 0)
        if recents.count > maxRecents { recents = Array(recents.prefix(maxRecents)) }
        UserDefaults.standard.set(recents, forKey: recentProjectsKey)
    }

    @objc func showRecentProjects(_ sender: NSView) {
        let menu = NSMenu()
        let recents = Self.recentProjects()
        if recents.isEmpty {
            menu.addItem(NSMenuItem(title: "No recent projects", action: nil, keyEquivalent: ""))
        } else {
            for path in recents {
                let item = NSMenuItem(title: (path as NSString).lastPathComponent, action: #selector(openRecentProject(_:)), keyEquivalent: "")
                item.target = self
                item.toolTip = path
                item.representedObject = path
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }

    @objc private func openRecentProject(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String, let id = activeWorkspaceID else { return }
        // Switch to existing session if one already has this cwd
        if let existing = sessions.first(where: { $0.tabs.contains(where: { $0.cwd == path }) }) {
            SessionCoordinator.shared.selectSession(workspaceID: id, sessionID: existing.id)
            return
        }
        SessionCoordinator.shared.addSession(to: id, cwd: path, name: (path as NSString).lastPathComponent)
    }

    @objc func sessionDoubleClick() {
        selectSessionRow()
    }

    @objc private func showWorkspaceMenu() {
        if workspaceDropdown != nil {
            dismissWorkspaceDropdown()
            return
        }
        let dropdown = WorkspaceSwitcherPanelView(
            workspaces: workspaces,
            activeWorkspaceID: activeWorkspaceID,
            onSelect: { [weak self] id in
                self?.dismissWorkspaceDropdown()
                SessionCoordinator.shared.selectWorkspace(id)
            },
            onNew: { [weak self] in
                self?.dismissWorkspaceDropdown()
                self?.addWorkspace()
            },
            onDelete: { [weak self] workspace, anchor in
                self?.confirmDeleteWorkspace(workspace, anchor: anchor)
            }
        )
        dropdown.alphaValue = 0
        dropdown.translatesAutoresizingMaskIntoConstraints = false
        dropdown.layer?.zPosition = 100
        view.addSubview(dropdown)
        workspaceDropdown = dropdown
        NSLayoutConstraint.activate([
            dropdown.topAnchor.constraint(equalTo: workspacePill.bottomAnchor, constant: 6),
            dropdown.leadingAnchor.constraint(equalTo: workspacePill.leadingAnchor),
            dropdown.trailingAnchor.constraint(equalTo: workspacePill.trailingAnchor),
            dropdown.heightAnchor.constraint(equalToConstant: clampedDropdownHeight(dropdown.preferredHeight)),
        ])
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            dropdown.animator().alphaValue = 1
        }
        installWorkspaceDropdownMonitor()
    }

    func dismissWorkspaceDropdown() {
        workspaceDropdown?.removeFromSuperview()
        workspaceDropdown = nil
        if let workspaceDropdownMonitor {
            NSEvent.removeMonitor(workspaceDropdownMonitor)
            self.workspaceDropdownMonitor = nil
        }
    }

    private func installWorkspaceDropdownMonitor() {
        if let workspaceDropdownMonitor {
            NSEvent.removeMonitor(workspaceDropdownMonitor)
        }
        workspaceDropdownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let dropdown = self.workspaceDropdown else { return event }
            guard event.window === self.view.window else {
                self.dismissWorkspaceDropdown()
                return event
            }
            let point = event.locationInWindow
            let dropdownPoint = dropdown.convert(point, from: nil)
            let pillPoint = self.workspacePill.convert(point, from: nil)
            if dropdown.bounds.contains(dropdownPoint) || self.workspacePill.bounds.contains(pillPoint) {
                return event
            }
            self.dismissWorkspaceDropdown()
            return event
        }
    }

    /// Keep the workspace dropdown on-screen: never extend past the footer. If the
    /// ideal height doesn't fit, the dropdown scrolls internally.
    private func clampedDropdownHeight(_ preferred: CGFloat) -> CGFloat {
        let available = view.bounds.height
            - HarnessDesign.titlebarChromeHeight
            - HarnessDesign.workspaceBarHeight
            - HarnessDesign.footerHeight
            - 20
        return min(preferred, max(120, available))
    }

    @objc func openPalette() {
        if let window = view.window {
            CommandPaletteController.present(relativeTo: window)
        }
    }

    @objc func openSettings() {
        SettingsWindowController.show()
    }

    func selectSessionRow() {
        let row = sessionTable.selectedRow
        guard let session = sessionRow(at: row), let activeWorkspaceID else { return }
        SessionCoordinator.shared.selectSession(workspaceID: activeWorkspaceID, sessionID: session.id)
        // Force file tree + git panel refresh even if daemon thinks session was already active.
        // This covers the case where snapshotChanged arrived asynchronously before the click.
        if let cwd = session.activeTab?.cwd ?? session.tabs.first?.cwd {
            fileTreeView.updateRoot(path: cwd, sessionID: session.id)
            gitPanelView.updateRoot(path: cwd)
            lastFileTreeSessionID = session.id
            lastFileTreeGitBranch = nil
        }
    }

    func confirmCloseSession(_ session: SessionGroup) {
        let title = session.name.isEmpty ? sessionTitle(for: session) : session.name
        let alert = NSAlert()
        alert.messageText = "Close session \"\(title)\"?"
        alert.informativeText = session.tabs.count > 1
            ? "This will close \(session.tabs.count) tabs and their running shells."
            : "This will close the session and its running shell."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close Session")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        // Close by ID — selecting first and then closing "the active session" could
        // close the wrong session if the selection IPC failed or raced a snapshot change
        // while the confirmation alert was up.
        SessionCoordinator.shared.closeSession(session)
    }

    func sessionTitle(for session: SessionGroup) -> String {
        guard let tab = session.activeTab ?? session.tabs.first else { return "Session" }
        return HarnessDesign.pathDisplayName(tab.cwd)
    }
}
