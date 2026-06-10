import AppKit
import HarnessCore
import HarnessTerminalKit
import UserNotifications

extension SettingsViewController {
    // MARK: - Page: Agents

    func buildAgentsPage() -> NSView {
        let header = pageHeader(title: "Agents", trailing: nil)

        systemNotificationsToggle.state = SessionCoordinator.shared.settings.systemNotificationsEnabled ? .on : .off
        systemNotificationsToggle.target = self
        systemNotificationsToggle.action = #selector(systemNotificationsToggled)
        notificationSoundToggle.state = SessionCoordinator.shared.settings.notificationSoundEnabled ? .on : .off
        notificationSoundToggle.target = self
        notificationSoundToggle.action = #selector(appearanceTextDidCommit)
        notchModeSegment.setSegments(NotchVisibilityMode.allCases.map(notchModeTitle))
        notchModeSegment.selectItem(withTitle: notchModeTitle(SessionCoordinator.shared.settings.notchVisibilityMode))
        notchModeSegment.target = self
        notchModeSegment.action = #selector(notchSettingsChanged)
        notchOpenOnHoverToggle.state = SessionCoordinator.shared.settings.notchOpenOnHover ? .on : .off
        notchOpenOnHoverToggle.target = self
        notchOpenOnHoverToggle.action = #selector(notchSettingsChanged)
        notchSummaryLabel.font = .systemFont(ofSize: 11)
        notchSummaryLabel.textColor = .secondaryLabelColor
        notchSummaryLabel.stringValue = notchSummary(for: SessionCoordinator.shared.settings.notchVisibilityMode)

        notificationStatusField.font = .systemFont(ofSize: 11)
        notificationStatusField.textColor = .secondaryLabelColor
        notificationStatusField.lineBreakMode = .byWordWrapping
        notificationStatusField.maximumNumberOfLines = 2
        notificationTestButton.target = self
        notificationTestButton.action = #selector(sendTestNotification)
        notificationTestButton.bezelStyle = .rounded
        notificationTestButton.controlSize = .regular
        notificationPermissionButton.target = self
        notificationPermissionButton.action = #selector(openNotificationPermission)
        notificationPermissionButton.bezelStyle = .rounded
        notificationPermissionButton.controlSize = .regular
        let notifButtons = NSStackView(views: [notificationTestButton, notificationPermissionButton])
        notifButtons.orientation = .horizontal
        notifButtons.spacing = 10
        let notifStatusBlock = NSStackView(views: [notificationStatusField, leadingRow(notifButtons)])
        notifStatusBlock.orientation = .vertical
        notifStatusBlock.alignment = .leading
        notifStatusBlock.spacing = 10
        refreshNotificationStatus()
        commandFinishedThresholdField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        // "Which events notify me" — one row per NotificationEvent, in enum order. The
        // command-finished row carries its runtime threshold as a sub-row. State/target are
        // already wired in `configureControls` (the authoritative seed, so a flush can never
        // clobber settings with unseeded toggles); here we only lay out the rows.
        var eventRows: [NSView] = []
        for event in NotificationEvent.allCases {
            guard let toggle = eventToggles[event] else { continue }
            eventRows.append(settingsToggleRow(event.title, toggle, hint: event.detail))
            if event == .commandFinished {
                eventRows.append(settingsRow("Threshold (seconds)", commandFinishedThresholdField,
                                             hint: "Only commands that ran at least this long trigger the notification."))
            }
        }
        let notifyGroup = settingsGroup("Notify me about", eventRows)
        // "How notifications are delivered" — the two global channel toggles + permission status.
        let deliveryGroup = settingsGroup("Delivery", [
            settingsToggleRow("macOS banner", systemNotificationsToggle),
            settingsToggleRow("Sound", notificationSoundToggle),
            notifStatusBlock,
        ])
        let notchGroup = settingsGroup("Notch HUD", [
            settingsRow("Visibility", notchModeSegment, hint: "Automatic shows the notch in Agent Workspace only."),
            settingsToggleRow("Hover", notchOpenOnHoverToggle),
            notchSummaryLabel,
        ])

        let detectionCaption = settingsCaption("Harness identifies agents by walking each pane's process tree and matching the executables shown below — it works for any shell, no setup. Install hooks so an agent can ping you the moment it stops or needs input (the config is merged into the agent's own file and backed up first). Customize matching in agents.json.")
        let editAgents = makeRoundedButton("Edit agents.json…", action: #selector(openAgentsJSON))
        let detectionBox = NSStackView(views: [detectionCaption, leadingRow(editAgents)])
        detectionBox.orientation = .vertical
        detectionBox.alignment = .leading
        detectionBox.spacing = 12

        let reset = makeRoundedButton("Reset Agent Colors", action: #selector(resetAgentColors))

        let promptCaption = settingsCaption("Trouble with one-click install (or a tool Harness doesn't manage)? Copy this prompt and paste it into any coding agent/IDE running on this Mac — it will wire up its own Harness hook.")
        let promptPreview = NSTextField(wrappingLabelWithString: AgentHookInstaller.setupPrompt)
        promptPreview.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        promptPreview.textColor = .secondaryLabelColor
        promptPreview.isSelectable = true
        let copyPrompt = makeRoundedButton("Copy Setup Prompt", action: #selector(copySetupPrompt))
        let promptBox = NSStackView(views: [promptCaption, promptPreview, leadingRow(copyPrompt)])
        promptBox.orientation = .vertical
        promptBox.alignment = .leading
        promptBox.spacing = 12

        let stack = NSStackView(views: [
            header,
            notifyGroup,
            deliveryGroup,
            notchGroup,
            settingsGroup("Detection & hooks", [detectionBox]),
            settingsGroup("Set up via your IDE", [promptBox]),
            settingsGroup("Agents", Self.agentColorKinds.map(agentRow) + [leadingRow(reset)]),
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        return scrollWrap(stack)
    }

    // MARK: - ACP Agent Configs

    private func buildACPAgentsGroup() -> NSView {
        let store = AgentRegistryStore()
        let configs = store.load()

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 6
        acpAgentRows = rows

        for config in configs {
            rows.addArrangedSubview(makeACPAgentRow(config))
        }

        let addButton = makeRoundedButton("Add Agent…", action: #selector(addACPAgent))
        let caption = settingsCaption("Add CLI agents that support ACP (Agent Client Protocol) over stdio. Use the Agent sidebar tab to chat with the active agent.")

        return settingsGroup("ACP Agents (Chat)", [caption, rows, leadingRow(addButton)])
    }

    private func makeACPAgentRow(_ config: AgentConfig) -> NSView {
        let nameLabel = NSTextField(labelWithString: config.name)
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let pathLabel = NSTextField(labelWithString: config.binaryPath)
        pathLabel.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let enableToggle = NSButton(checkboxWithTitle: "", target: self, action: #selector(acpAgentToggled(_:)))
        enableToggle.state = config.isEnabled ? .on : .off
        enableToggle.tag = config.id.hashValue
        enableToggle.identifier = NSUserInterfaceItemIdentifier(config.id.uuidString)

        let removeButton = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove")!, target: self, action: #selector(removeACPAgent(_:)))
        removeButton.bezelStyle = .inline
        removeButton.isBordered = false
        removeButton.identifier = NSUserInterfaceItemIdentifier(config.id.uuidString)

        let left = NSStackView(views: [nameLabel, pathLabel])
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 2

        let row = NSStackView(views: [enableToggle, left, removeButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.identifier = NSUserInterfaceItemIdentifier(config.id.uuidString)
        left.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        return row
    }

    @objc private func addACPAgent() {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Add ACP Agent"
        alert.informativeText = "Enter agent name and binary path."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let fieldW: CGFloat = 300
        let fieldH: CGFloat = 24
        let spacing: CGFloat = 8
        let container = NSView(frame: NSRect(x: 0, y: 0, width: fieldW, height: fieldH * 3 + spacing * 2))

        let nameField = NSTextField(frame: NSRect(x: 0, y: spacing * 2 + fieldH * 2, width: fieldW, height: fieldH))
        nameField.placeholderString = "Name (e.g. Claude)"
        let pathField = NSTextField(frame: NSRect(x: 0, y: spacing + fieldH, width: fieldW, height: fieldH))
        pathField.placeholderString = "Binary path (e.g. /usr/local/bin/claude)"
        let argsField = NSTextField(frame: NSRect(x: 0, y: 0, width: fieldW, height: fieldH))
        argsField.placeholderString = "Args (space-separated, e.g. --acp --chat)"

        container.addSubview(nameField)
        container.addSubview(pathField)
        container.addSubview(argsField)
        alert.accessoryView = container

        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            let path = pathField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !path.isEmpty else { return }
            let args = argsField.stringValue.split(separator: " ").map(String.init)

            let store = AgentRegistryStore()
            var configs = store.load()
            let config = AgentConfig(name: name, binaryPath: path, args: args)
            configs.append(config)
            store.save(configs)
            self?.acpAgentRows?.addArrangedSubview(self?.makeACPAgentRow(config) ?? NSView())
        }
    }

    @objc private func removeACPAgent(_ sender: NSButton) {
        guard let idStr = sender.identifier?.rawValue,
              let uuid = UUID(uuidString: idStr) else { return }
        let store = AgentRegistryStore()
        var configs = store.load()
        configs.removeAll { $0.id == uuid }
        store.save(configs)
        // Remove the row from UI
        if let row = acpAgentRows?.arrangedSubviews.first(where: { $0.identifier?.rawValue == idStr }) {
            row.removeFromSuperview()
        }
    }

    @objc private func acpAgentToggled(_ sender: NSButton) {
        guard let idStr = sender.identifier?.rawValue,
              let uuid = UUID(uuidString: idStr) else { return }
        let store = AgentRegistryStore()
        var configs = store.load()
        if let idx = configs.firstIndex(where: { $0.id == uuid }) {
            configs[idx].isEnabled = sender.state == .on
            store.save(configs)
        }
    }

    /// One per-agent row: brand icon + name + the executables it matches + a color-override
    /// swatch + a one-click "Install hooks" button (with installed status) where supported.
    private func agentRow(_ kind: AgentKind) -> NSView {
        let c = HarnessChrome.current
        let colorHex = SessionCoordinator.shared.settings.agentColorHex(for: kind)

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.imageScaling = .scaleProportionallyUpOrDown
        // Brand mark when one exists, else a tinted monogram (e.g. Aider) — never a blank slot.
        icon.image = AgentIconRenderer.templateOrMonogramImage(for: kind, size: 18)
        icon.contentTintColor = NSColor.fromHex(colorHex) ?? c.textSecondary
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
        agentIconViews[kind] = icon

        let name = NSTextField(labelWithString: kind.displayName)
        name.font = .systemFont(ofSize: 13, weight: .medium)
        name.textColor = .labelColor
        let execs = NSTextField(labelWithString: executablesString(for: kind))
        execs.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        execs.textColor = .secondaryLabelColor
        execs.lineBreakMode = .byTruncatingTail
        let textCol = NSStackView(views: [name, execs])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 1

        let leading = NSStackView(views: [icon, textCol])
        leading.orientation = .horizontal
        leading.alignment = .centerY
        leading.spacing = 10

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let trailing = NSStackView()
        trailing.orientation = .horizontal
        trailing.alignment = .centerY
        trailing.spacing = 10
        if let well = agentColorWells[kind] { trailing.addArrangedSubview(well) }

        // "Chat" toggle — enables this agent as an ACP chat agent
        let chatToggle = NSButton(checkboxWithTitle: "Chat", target: self, action: #selector(chatToggleClicked(_:)))
        chatToggle.tag = kind.hashValue
        chatToggle.identifier = NSUserInterfaceItemIdentifier(kind.rawValue)
        let store = AgentRegistryStore()
        let isRegistered = store.load().contains { $0.name == kind.displayName && $0.isEnabled }
        chatToggle.state = isRegistered ? .on : .off
        chatToggles[kind] = chatToggle
        trailing.addArrangedSubview(chatToggle)

        if AgentHookInstaller.canInstall(kind) {
            let installed = AgentHookInstaller.isInstalled(agent: kind)
            let button = NSButton(title: installed ? "Reinstall Hooks" : "Install Hooks", target: self, action: #selector(installHooksClicked(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .regular
            hookButtons[kind] = button
            trailing.addArrangedSubview(button)
        }

        let row = NSStackView(views: [leading, spacer, trailing])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func executablesString(for kind: AgentKind) -> String {
        let execs = AgentTable.default.entries.first { $0.kind == kind }?.executables ?? []
        return execs.isEmpty ? "—" : execs.joined(separator: ", ")
    }

    func retintAgentIcon(_ kind: AgentKind) {
        let hex = SessionCoordinator.shared.settings.agentColorHex(for: kind)
        agentIconViews[kind]?.contentTintColor = NSColor.fromHex(hex) ?? HarnessChrome.current.textSecondary
    }

    @objc private func sendTestNotification() {
        DesktopNotifier.sendTest()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.refreshNotificationStatus() }
    }

    /// Toggling banners on is only meaningful if macOS is also allowing them. So when the user
    /// enables the setting, trigger the system permission prompt (or route to System Settings if
    /// already denied) — otherwise the toggle would silently produce nothing on a fresh install.
    @objc private func systemNotificationsToggled() {
        flushAndApply()
        if systemNotificationsToggle.state == .on {
            DesktopNotifier.requestOrOpenSettings()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.refreshNotificationStatus() }
    }

    @objc private func openNotificationPermission() {
        DesktopNotifier.requestOrOpenSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.refreshNotificationStatus() }
    }

    /// Pull the live macOS permission state into the caption so the user can tell whether the
    /// system is allowing alerts at all (the common reason agent notifications never appear).
    private func refreshNotificationStatus() {
        DesktopNotifier.authorizationStatus { [weak self] status in
            guard let self else { return }
            let text: String
            let needsAllow: Bool
            switch status {
            case .authorized, .provisional:
                text = "macOS is allowing notifications."
                needsAllow = false
            case .denied:
                text = "macOS is blocking notifications for Harness. Click below to allow them in System Settings ▸ Notifications."
                needsAllow = true
            case .notDetermined:
                text = "Notifications haven't been authorized yet. Send a test to grant them."
                needsAllow = true
            @unknown default:
                text = ""
                needsAllow = true
            }
            self.notificationStatusField.stringValue = text
            self.notificationPermissionButton.isHidden = !needsAllow
        }
    }

    @objc private func copySetupPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AgentHookInstaller.setupPrompt, forType: .string)
        Toast.show("Setup prompt copied — paste it into your IDE/agent", in: view)
    }

    @objc private func installHooksClicked(_ sender: NSButton) {
        guard let kind = hookButtons.first(where: { $0.value === sender })?.key else { return }
        sender.title = "Installing…"
        sender.isEnabled = false
        // File I/O off-main; weak captures so a closed Settings window isn't kept alive.
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak sender] in
            let outcome = Result { try AgentHookInstaller.install(agent: kind) }
            DispatchQueue.main.async {
                guard let sender else { return }
                sender.isEnabled = true
                let host = self?.view
                switch outcome {
                case .success(let result):
                    sender.title = "Reinstall Hooks"
                    sender.toolTip = result.backedUp.map { "Backed up your previous config to \($0.lastPathComponent)" }
                        ?? "Installed at \(result.path.path)"
                    if let host { Toast.show("Installed \(kind.displayName) hooks", in: host) }
                case .failure(let error):
                    sender.title = "Install Hooks"
                    sender.toolTip = "Failed: \(error.localizedDescription)"
                    if let host { Toast.show("Couldn't install \(kind.displayName) hooks", in: host) }
                }
            }
        }
    }

    @objc private func chatToggleClicked(_ sender: NSButton) {
        guard let kindRaw = sender.identifier?.rawValue,
              let kind = AgentKind(rawValue: kindRaw) else { return }
        let store = AgentRegistryStore()
        var configs = store.load()

        if sender.state == .on {
            let (binary, args) = acpBinaryInfo(for: kind)
            guard let binaryPath = resolveBinaryPath([binary]) ?? resolveBinaryPath(
                AgentTable.default.entries.first { $0.kind == kind }?.executables ?? []
            ) else {
                sender.state = .off
                Toast.show("\(kind.displayName) not found on PATH", in: view)
                return
            }
            // Don't duplicate
            if !configs.contains(where: { $0.name == kind.displayName }) {
                let config = AgentConfig(name: kind.displayName, binaryPath: binaryPath, args: args)
                configs.append(config)
            }
            store.save(configs)
            Toast.show("\(kind.displayName) enabled for Chat", in: view)
        } else {
            configs.removeAll { $0.name == kind.displayName }
            store.save(configs)
            Toast.show("\(kind.displayName) removed from Chat", in: view)
        }
    }

    /// Find the first executable on $PATH from the given list.
    private func resolveBinaryPath(_ executables: [String]) -> String? {
        let pathDirs = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map(String.init)
        let fm = FileManager.default
        for exe in executables {
            for dir in pathDirs {
                let full = dir + "/" + exe
                if fm.isExecutableFile(atPath: full) { return full }
            }
        }
        return nil
    }

    /// Returns (binary name to search on PATH, args) for ACP mode per agent.
    private func acpBinaryInfo(for kind: AgentKind) -> (String, [String]) {
        switch kind {
        case .claudeCode: return ("claude-agent-acp", [])
        case .codex: return ("codex", ["--acp"])
        case .gemini: return ("gemini", ["--acp"])
        case .antigravity: return ("agy", ["--acp"])
        case .kiro: return ("kiro", ["--acp"])
        case .openCode: return ("opencode", ["--acp"])
        case .openClaw: return ("openclaw", ["--acp"])
        case .goose: return ("goose", ["--acp"])
        default: return (kind.rawValue, ["--acp"])
        }
    }
}
