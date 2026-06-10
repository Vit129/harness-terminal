import AppKit
import HarnessCore
import HarnessTerminalKit
import UserNotifications

extension SettingsViewController {
    // MARK: - Page: Advanced (harness-cli set-option surface)

    func buildAdvancedPage() -> NSView {
        let header = pageHeader(title: "Advanced", trailing: nil)
        advDaemonControls.removeAll() // repopulated by the adv* factories below
        // The adv* controls are rebuilt on every Advanced-page show, so the prior batch's identifiers
        // are stale (keyed by ObjectIdentifier of freed controls). Clear the map alongside the control
        // list, otherwise it grows unbounded across reopens.
        advOptKeys.removeAll()
        loadAdvancedValues()
        // The performance toggles are member controls (not rebuilt by the adv* factories), so unlike
        // the daemon-backed controls they don't get refreshed by `loadAdvancedValues`. Re-read their
        // state from settings here so a rebuilt page reflects changes made since the last build.
        let perfSettings = SessionCoordinator.shared.settings
        offMainPipelineToggle.state = perfSettings.offMainParserFramePipeline ? .on : .off
        liveResizeReflowToggle.state = perfSettings.liveResizeReflow ? .on : .off

        let statusGroup = settingsGroup("Status bar", [
            settingsCaption("Format the bottom status bar (FormatString tokens like #{cwd_basename}, #{git_branch}, #{time:%H:%M}). The on/off switch is in Appearance ▸ Window."),
            settingsRow("Status position", advSegment("status-position", ["bottom", "top"])),
            settingsRow("Status left", advField("status-left", width: 260)),
            settingsRow("Status right", advField("status-right", width: 260)),
        ])

        let inputGroup = settingsGroup("Input", [
            settingsToggleRow("Mouse reporting", advToggle("mouse", "")),
            settingsRow("Copy-mode keys", advSegment("mode-keys", ["vi", "emacs"])),
            settingsToggleRow("OSC 52 clipboard", advToggle("set-clipboard", "")),
        ])

        let identityGroup = settingsGroup("Terminal identity", [
            settingsCaption("How Harness identifies itself to programs (TERM_PROGRAM + XTVERSION). Compatible reports a protocol-compatible identity so tools like Claude Code enable Shift+Enter immediately. Harness reports its true name and version. Applies to newly-opened panes."),
            settingsRow("Reported identity", advSegment(TerminalIdentity.optionKey, TerminalIdentity.Mode.allCases.map(\.rawValue))),
        ])

        let indexGroup = settingsGroup("Indexing", [
            settingsRow("Window base index", advSegment("base-index", ["0", "1"])),
            settingsRow("Pane base index", advSegment("pane-base-index", ["0", "1"])),
            settingsToggleRow("Renumber windows", advToggle("renumber-windows", "")),
        ])

        let titleGroup = settingsGroup("Titles & monitoring", [
            settingsToggleRow("Program tab titles", advToggle("allow-rename", "")),
            settingsToggleRow("Automatic rename", advToggle("automatic-rename", "")),
            settingsToggleRow("Monitor activity", advToggle("monitor-activity", "")),
            settingsToggleRow("Monitor bell", advToggle("monitor-bell", "")),
            settingsRow("Silence alert (s)", advField("monitor-silence", width: 80)),
        ])

        let lifecycleGroup = settingsGroup("Lifecycle", [
            settingsToggleRow("Remain on exit", advToggle("remain-on-exit", "")),
            settingsRow("Prefix repeat (ms)", advField("repeat-time", width: 100)),
            settingsRow("History limit", advField("history-limit", width: 120), hint: "Session scrollback; the renderer's own scrollback is in Terminal ▸ Behavior."),
        ])

        let borderGroup = settingsGroup("Pane borders", [
            settingsRow("Pane border labels", advSegment("pane-border-status", ["off", "top", "bottom"])),
            settingsRow("Border format", advField("pane-border-format", width: 260)),
        ])

        let performanceGroup = settingsGroup("Performance", [
            settingsToggleRow("Off-main render pipeline", offMainPipelineToggle,
                              hint: "Parse + build frames off the main thread. On is recommended."),
            settingsToggleRow("Real-time resize", liveResizeReflowToggle,
                              hint: "Reflow and redraw the running program live while dragging the "
                                  + "window edge, instead of on release. On is recommended."),
        ])

        let intro = settingsCaption("Power-user options shared with the harness-cli set-option command surface. Changes apply globally and persist immediately.")
        // When the daemon is unreachable these groups show builtin defaults, NOT the live state, and
        // a change can't be applied — so disable the daemon-backed controls and warn inline at the
        // top. The performance toggles (local settings) stay usable. Re-checked each time the page is
        // shown (see `showPage`). The set-option surface depends on the daemon, so it's gated here.
        if !advDaemonReachable {
            for control in advDaemonControls { control.isEnabled = false }
        }
        var views: [NSView] = [header, intro]
        if !advDaemonReachable {
            views.append(advUnreachableBanner())
        }
        views.append(contentsOf: [
            performanceGroup,
            statusGroup,
            inputGroup,
            identityGroup,
            indexGroup,
            titleGroup,
            lifecycleGroup,
            borderGroup,
        ])
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        return scrollWrap(stack)
    }

    /// Inline warning shown atop the Advanced page when the daemon is unreachable: the controls
    /// below show builtin defaults, not live state, and edits can't be applied. Uses the chrome's
    /// danger color so it reads as a real warning, consistent with the rest of Settings.
    private func advUnreachableBanner() -> NSView {
        let banner = NSView()
        banner.wantsLayer = true
        banner.layer?.cornerRadius = 6
        banner.layer?.backgroundColor = HarnessChrome.current.danger.withAlphaComponent(0.12).cgColor
        banner.layer?.borderWidth = 1
        banner.layer?.borderColor = HarnessChrome.current.danger.withAlphaComponent(0.35).cgColor
        let label = NSTextField(wrappingLabelWithString:
            "Daemon unreachable — showing defaults; changes can't be applied.")
        label.font = .systemFont(ofSize: 11.5, weight: .medium)
        label.textColor = HarnessChrome.current.danger
        label.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 9),
            label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -9),
        ])
        return banner
    }

    private func loadAdvancedValues() {
        advValues.removeAll()
        for (key, value) in OptionStore.builtinDefaults { advValues[key] = value.stringValue }
        // `requestDaemon` returns nil when the daemon is unreachable. Distinguish that from a real
        // empty-options reply: only overlay (and mark reachable) on an actual `.options` response,
        // so an unreachable daemon renders builtin defaults that the page flags as not-live.
        if case let .options(entries)? = SessionCoordinator.shared.requestDaemon(.showOptions(scope: nil)) {
            for entry in entries where entry.scope == "global" { advValues[entry.key] = entry.value }
            advDaemonReachable = true
        } else {
            advDaemonReachable = false
        }
    }

    private func advToggle(_ key: String, _ title: String) -> HarnessToggle {
        let toggle = HarnessToggle(title: title)
        let raw = (advValues[key] ?? "off").lowercased()
        toggle.state = (raw == "on" || raw == "true" || raw == "1") ? .on : .off
        toggle.target = self
        toggle.action = #selector(advChanged(_:))
        advOptKeys[ObjectIdentifier(toggle)] = (key, .toggle)
        advDaemonControls.append(toggle)
        return toggle
    }

    private func advSegment(_ key: String, _ values: [String]) -> HarnessSegmented {
        let segment = HarnessSegmented(frame: .zero)
        segment.setSegments(values.map { $0.capitalized })
        if let current = advValues[key] { segment.selectItem(withTitle: current.capitalized) }
        segment.target = self
        segment.action = #selector(advChanged(_:))
        advOptKeys[ObjectIdentifier(segment)] = (key, .segment)
        advDaemonControls.append(segment)
        return segment
    }

    private func advField(_ key: String, width: CGFloat) -> HarnessTextField {
        let field = HarnessTextField()
        field.stringValue = advValues[key] ?? ""
        field.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        field.target = self
        field.action = #selector(advChanged(_:))
        advOptKeys[ObjectIdentifier(field)] = (key, .field)
        advDaemonControls.append(field)
        return field
    }

    @objc private func advChanged(_ sender: NSObject) {
        guard let entry = advOptKeys[ObjectIdentifier(sender)] else { return }
        let raw: String
        switch entry.kind {
        case .toggle: raw = (sender as? HarnessToggle)?.state == .on ? "on" : "off"
        case .segment: raw = (sender as? HarnessSegmented)?.titleOfSelectedItem?.lowercased() ?? ""
        case .field: raw = (sender as? NSTextField)?.stringValue ?? ""
        }
        setDaemonOption(key: entry.key, rawValue: raw)
    }

    private func setDaemonOption(key: String, rawValue: String) {
        SessionCoordinator.shared.requestDaemon(.setOption(scope: "global", target: nil, key: key, rawValue: rawValue))
        advValues[key] = rawValue
        HarnessOptions.reloadFromDisk()
        // Nudge the status line + chrome to re-read the new option value.
        NotificationCenter.default.post(
            name: NotificationBus.shared.snapshotChanged,
            object: nil,
            userInfo: ["revision": SessionCoordinator.shared.snapshot.revision,
                       "structureChanged": false,
                       "chromeChanged": false,
                       "metadataOnly": true]
        )
    }

    func settingsCaption(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11.5)
        label.textColor = .secondaryLabelColor
        return label
    }

    /// Wrap a control so it sits flush-left in a `.width`-aligned stack (trailing spacer).
    func leadingRow(_ control: NSView) -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [control, spacer])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }
}
