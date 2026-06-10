import AppKit
import HarnessCore
import HarnessTerminalKit
import UserNotifications

extension SettingsViewController {
    // MARK: - Live theme re-skin

    /// Settings paints with `HarnessChrome.current`, so when the user switches theme (or
    /// edits bg/fg/cursor) from inside this window, observe the same chrome broadcast the
    /// main window uses and recolor every control + surface in step. Without this the
    /// Settings window would keep the palette it opened with.
    func observeChromeChanges() {
        lastChromeSignature = chromeSignature()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(chromeDidChange(_:)),
            name: NotificationBus.shared.snapshotChanged,
            object: nil
        )
    }

    @objc private func chromeDidChange(_ note: Notification) {
        guard note.userInfo?["chromeChanged"] as? Bool == true else { return }
        // `flushAndApply` posts `chromeChanged` on every control action (including
        // continuous opacity/blur drags), but the palette only actually changes on a
        // theme or bg/fg/cursor edit. Skip the re-skin walk when the colors are identical
        // so dragging a slider doesn't churn every control on each tick.
        let signature = chromeSignature()
        guard signature != lastChromeSignature else { return }
        lastChromeSignature = signature
        let c = HarnessChrome.current
        view.layer?.backgroundColor = c.terminalBackground.cgColor
        sidebarTitleLabel.textColor = c.textPrimary
        // System-colored text labels track the window's light/dark appearance; updating it
        // re-renders them for free, so only surfaces + custom controls need explicit recolor.
        view.window?.appearance = NSAppearance(named: c.isDark ? .darkAqua : .aqua)
        for surface in groupSurfaces {
            surface.layer?.backgroundColor = c.surfaceElevated.cgColor
            surface.layer?.borderColor = c.border.cgColor
        }
        for divider in groupDividers { divider.layer?.backgroundColor = c.border.cgColor }
        // Re-skin every themed control. Cached pages are walked directly since only the
        // visible page is in the view tree.
        reskinControls(in: view)
        for page in pages.values { reskinControls(in: page) }
        // Re-tint links (their accent color is baked into the attributed title).
        for link in linkButtons { styleAsLink(link) }
        // Auto light/dark lands here as a chrome change too: the color wells/placeholder hex
        // read from the *theme*, so without a refresh they keep showing the old appearance's
        // palette until the window reopens.
        refreshColorPlaceholders()
    }

    /// A cheap fingerprint of the palette colors that drive the control re-skin. Opacity /
    /// blur changes don't alter these, so they won't trigger a needless walk.
    private func chromeSignature() -> String {
        let c = HarnessChrome.current
        return [c.terminalBackground, c.textPrimary, c.accent]
            .map(hexString)
            .joined(separator: "|") + (c.isDark ? "·D" : "·L")
    }

    /// Recursively re-apply `applyChrome()` to every themed control under `root`.
    private func reskinControls(in root: NSView) {
        for sub in root.subviews {
            switch sub {
            case let v as HarnessTextField: v.applyChrome()
            case let v as HarnessSearchField: v.applyChrome()
            case let v as HarnessToggle: v.applyChrome()
            case let v as HarnessSlider: v.applyChrome()
            case let v as HarnessSwatchWell: v.applyChrome()
            case let v as HarnessSegmented: v.applyChrome()
            case let v as HarnessSelect: v.applyChrome()
            case let v as SettingsSidebarButton: v.applyChrome()
            default: break
            }
            reskinControls(in: sub)
        }
    }

    // MARK: - Live apply

    // The four continuous sliders apply live on every drag tick but persist only once on commit
    // (`onCommit`, wired in setup), so scrubbing never spams a JSON encode + atomic write per frame.

    @objc func opacityDidChange() {
        opacityLabel.stringValue = formatPercent(Float(opacitySlider.doubleValue))
        applySettingsLive()
    }

    @objc func blurDidChange() {
        let rounded = Int(blurSlider.doubleValue.rounded())
        blurLabel.stringValue = formatBlur(rounded)
        applySettingsLive()
    }

    @objc func windowBorderOpacityDidChange() {
        windowBorderOpacityLabel.stringValue = formatPercent(Float(windowBorderOpacitySlider.doubleValue))
        applySettingsLive()
    }

    @objc func themeDidChange() {
        guard let theme = themePopup.titleOfSelectedItem else { return }
        // A theme is a starting preset: seed the full editable color set, then
        // mirror it into the controls so the user edits from the theme's values.
        SessionCoordinator.shared.setTheme(theme)
        syncAppearanceControlsFromSettings()
        refreshColorPlaceholders()
    }

    func resizeOverlayTitle(_ mode: ResizeOverlayMode) -> String {
        switch mode {
        case .afterFirst: return "After first"
        case .always: return "Always"
        case .never: return "Never"
        }
    }

    private func resizeOverlayValue(_ title: String?) -> ResizeOverlayMode {
        switch title {
        case "Always": return .always
        case "Never": return .never
        default: return .afterFirst
        }
    }

    func resizeOverlayPositionTitle(_ position: ResizeOverlayPosition) -> String {
        switch position {
        case .center: return "Center"
        case .topRight: return "Top right"
        case .bottomRight: return "Bottom right"
        }
    }

    private func resizeOverlayPositionValue(_ title: String?) -> ResizeOverlayPosition {
        switch title {
        case "Top right": return .topRight
        case "Bottom right": return .bottomRight
        default: return .center
        }
    }

    func updateMinContrastLabel() {
        let value = minContrastSlider.doubleValue
        minContrastLabel.stringValue = value <= 1.01 ? "Off" : String(format: "%.1f:1", value)
    }

    @objc func minContrastChanged() {
        updateMinContrastLabel()
        applySettingsLive()
    }

    /// Enable/disable auto light/dark and apply it. Both theme names are set together (seeding from
    /// the current theme when unset); clearing either turns the feature off.
    @objc func autoThemeChanged() {
        // Flush any pending control edits (e.g. an unsaved color field) before
        // mutating theme names, so in-flight changes aren't silently discarded.
        flushAndApply()
        let coordinator = SessionCoordinator.shared
        let enabled = autoThemeToggle.state == .on
        coordinator.settings.lightThemeName = enabled
            ? (lightThemePopup.titleOfSelectedItem ?? coordinator.snapshot.themeName) : nil
        coordinator.settings.darkThemeName = enabled
            ? (darkThemePopup.titleOfSelectedItem ?? coordinator.snapshot.themeName) : nil
        try? coordinator.settings.save()
        lightThemePopup.isEnabled = enabled
        darkThemePopup.isEnabled = enabled
        themePopup.isEnabled = !enabled
        // Apply immediately (picks the theme matching the current system), then refresh the main
        // window chrome so it follows / un-follows the system appearance.
        coordinator.applyAutoThemeForCurrentAppearance()
        let mainWindow = NSApp.windows.first { $0.contentViewController is MainSplitViewController }
        (mainWindow?.windowController as? MainWindowController)?.applyChrome()
        syncAppearanceControlsFromSettings()
        refreshColorPlaceholders()
    }

    /// Re-seed all colors from the currently selected theme, discarding manual
    /// edits ("Reset to theme").
    @objc func useThemeColors() {
        SessionCoordinator.shared.setTheme(SessionCoordinator.shared.snapshot.themeName)
        syncAppearanceControlsFromSettings()
        refreshColorPlaceholders()
    }

    @objc func toggleKeepSessions() {
        let keep = keepSessionsToggle.state == .on
        SessionCoordinator.shared.requestDaemon(.setKeepSessionsOnQuit(keep))
    }

    @objc func setDefaultTerminalClicked() {
        defaultTerminalButton.isEnabled = false
        defaultTerminalButton.title = "Setting…"
        Task { @MainActor in
            do {
                try await DefaultTerminalManager.setAsDefault()
                Toast.show("Harness is now the default terminal", in: view)
            } catch {
                Toast.show("Couldn't set default terminal", in: view)
                defaultTerminalStatusField.stringValue = error.localizedDescription
            }
            defaultTerminalButton.isEnabled = true
            refreshDefaultTerminalStatus()
        }
    }

    func refreshDefaultTerminalStatus() {
        let status = DefaultTerminalManager.status()
        defaultTerminalStatusField.stringValue = status.summary
        defaultTerminalButton.title = status.isDefault ? "Default terminal set" : "Set Harness as default terminal"
    }

    /// The selected experience mode, derived from the segment position.
    private var selectedExperienceMode: ExperienceMode {
        let cases = ExperienceMode.allCases
        let i = experienceSegment.selectedSegment
        return cases.indices.contains(i) ? cases[i] : .plain
    }

    private var selectedNotchVisibilityMode: NotchVisibilityMode {
        let cases = NotchVisibilityMode.allCases
        let i = notchModeSegment.selectedSegment
        return cases.indices.contains(i) ? cases[i] : .automatic
    }

    func notchModeTitle(_ mode: NotchVisibilityMode) -> String {
        switch mode {
        case .automatic: return "Automatic"
        case .on: return "On"
        case .off: return "Off"
        }
    }

    func notchSummary(for mode: NotchVisibilityMode) -> String {
        switch mode {
        case .automatic:
            return "Automatic shows the top-center Agent HUD only in Agent Workspace. It passively summarizes sessions, agents, and hook-driven waiting state."
        case .on:
            return "The Agent HUD is always available at the top center of the main display as a session overview."
        case .off:
            return "The Agent HUD is disabled. Menu-bar sessions and normal notifications still work."
        }
    }

    @objc func notchSettingsChanged() {
        notchSummaryLabel.stringValue = notchSummary(for: selectedNotchVisibilityMode)
        flushAndApply()
    }

    /// Switching mode re-gates the chrome (prefix + status line), sets the default
    /// session-persistence policy on the daemon, and refreshes the live surfaces — all on the
    /// one session core. `flushAndApply` persists the setting and posts the chrome-changed
    /// notification the status line + prefix react to.
    @objc func experienceModeChanged() {
        let mode = selectedExperienceMode
        experienceSummaryLabel.stringValue = mode.summary
        flushAndApply()
        PrefixKeymap.shared.rebuildFromSettings()
        // Mode sets the default persistence: Plain is ephemeral (a clean quit closes its
        // sessions), the others keep sessions running. The user can still override via the
        // "Keep sessions running" toggle. Mirror the snapshot truth into that toggle so the
        // two controls stay consistent while the window is open.
        let keep = mode.persistsSessionsByDefault
        if SessionCoordinator.shared.requestDaemon(.setKeepSessionsOnQuit(keep)) != nil {
            // Record the live apply so the launch-time reconcile sees this mode as settled —
            // otherwise the next launch would treat the switch as a cross-launch mode change and
            // re-impose the default over any keep-on-quit override made after switching.
            AppDelegate.recordModePersistenceApplied(mode)
        }
        keepSessionsToggle.state = keep ? .on : .off
    }

    /// The per-component prefix override re-gates the prefix key independently of the status line
    /// (and of the experience mode). Mirrors the chrome-refresh path of `experienceModeChanged`.
    @objc func prefixControlChanged() {
        SessionCoordinator.shared.settings.prefixKeyEnabled = selectedPrefixEnabled
        flushAndApply()
        PrefixKeymap.shared.rebuildFromSettings()
    }

    /// The per-component status-line override re-gates the bottom status band independently of the
    /// prefix. `flushAndApply` posts the chrome-changed notification `StatusLineView` reacts to.
    @objc func statusLineControlChanged() {
        SessionCoordinator.shared.settings.statusLineEnabled = selectedStatusLineEnabled
        flushAndApply()
    }

    /// "Remember window size" applies to the live main window immediately, not just on the
    /// next launch: enabling it arms frame autosave (and snapshots the current frame so the
    /// very next quit/relaunch restores it); disabling it stops autosaving. Without this the
    /// toggle would appear to do nothing until two launches later. `MainWindowController.init`
    /// performs the launch-time restore using the same autosave name.
    @objc func restoreWindowSizeChanged() {
        flushAndApply()
        let enabled = restoreWindowSizeToggle.state == .on
        for window in NSApp.windows where window.contentViewController is MainSplitViewController {
            if enabled {
                window.setFrameAutosaveName(MainWindowController.frameAutosaveName)
                window.saveFrame(usingName: MainWindowController.frameAutosaveName)
            } else {
                // Empty name disables autosaving; the stored frame is ignored next launch
                // because `restoreWindowSize` is now false.
                window.setFrameAutosaveName("")
            }
        }
    }

    /// "Show sidebar" applies live to the main window's split (which also persists the
    /// setting), so the sidebar slides immediately rather than only on the next launch.
    @objc func sidebarVisibilityChanged() {
        let visible = sidebarVisibleToggle.state == .on
        for window in NSApp.windows {
            if let split = window.contentViewController as? MainSplitViewController {
                split.setSidebarVisible(visible, animated: true)
            }
        }
    }

    @objc func sidebarOnRightChanged() {
        let right = sidebarOnRightToggle.state == .on
        SessionCoordinator.shared.settings.sidebarOnRight = right
        try? SessionCoordinator.shared.settings.save()
        for window in NSApp.windows {
            if let split = window.contentViewController as? MainSplitViewController {
                split.updateSidebarPlacement()
            }
        }
    }

    @objc func appearanceTextDidCommit() {
        flushAndApply()
        // A hex field that committed non-empty-but-invalid text wrote `nil` (drop to theme) into
        // settings, yet the field still shows the rejected red text. Re-sync every hex field to the
        // resolved on-disk state so the UI never silently disagrees with what was actually saved.
        resyncColorFieldsFromSettings()
    }

    /// Write each color field back from the resolved setting it produced, then refresh its swatch.
    /// Invalid input resolved to `nil` → the field clears (the override dropped to the theme); valid
    /// input round-trips to its normalized form. Keeps the form honest after a commit.
    private func resyncColorFieldsFromSettings() {
        let settings = SessionCoordinator.shared.settings
        for binding in colorBindings {
            let resolved = settings[keyPath: binding.keyPath] ?? ""
            if binding.field.stringValue != resolved {
                binding.field.stringValue = resolved
            }
            refreshColorBinding(binding)
        }
    }

    @objc func appearanceTextDidChange(_ note: Notification) {
        guard let field = note.object as? NSTextField,
              let binding = colorBindings.first(where: { $0.field === field })
        else { return }
        refreshColorBinding(binding)
        let raw = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || normalizedHexOrNil(raw) != nil {
            flushAndApply()
        }
    }

    func configureColorWell(_ well: HarnessSwatchWell) {
        well.target = self
        well.action = #selector(colorWellChanged(_:))
        well.translatesAutoresizingMaskIntoConstraints = false
        well.widthAnchor.constraint(equalToConstant: ColorFormMetrics.swatchWidth).isActive = true
        well.heightAnchor.constraint(equalToConstant: ColorFormMetrics.swatchHeight).isActive = true
    }

    @objc func colorWellChanged(_ sender: HarnessSwatchWell) {
        guard let binding = colorBindings.first(where: { $0.well === sender }) else { return }
        binding.field.stringValue = hexString(sender.color)
        refreshColorBinding(binding)
        flushAndApply()
    }

    @objc func colorResetClicked(_ sender: NSButton) {
        guard let binding = colorBindings.first(where: { $0.reset === sender }) else { return }
        binding.field.stringValue = ""
        refreshColorBinding(binding)
        flushAndApply()
    }

    func refreshColorBinding(_ binding: ColorBinding) {
        validateHexField(binding.field)
        let hasOverride = normalizedHexOrNil(binding.field.stringValue) != nil
        let effective = normalizedHexOrNil(binding.field.stringValue) ?? binding.themeColor()
        binding.well.color = effective.flatMap(NSColor.fromHex) ?? HarnessChrome.current.terminalBackground
        binding.reset.isHidden = !hasOverride
    }

    func refreshColorPlaceholders() {
        for binding in colorBindings {
            binding.field.placeholderString = binding.themeColor()?.uppercased() ?? "—"
            refreshColorBinding(binding)
        }
    }

    @objc func paletteWellChanged(_ sender: HarnessSwatchWell) {
        guard let index = paletteWells.firstIndex(where: { $0 === sender }) else { return }
        paletteHexValues[index] = hexString(sender.color)
        flushAndApply()
    }

    @objc func agentColorWellChanged(_ sender: HarnessSwatchWell) {
        guard let kind = agentColorWells.first(where: { $0.value === sender })?.key else { return }
        let coordinator = SessionCoordinator.shared
        coordinator.settings.agentColorOverrides[kind.rawValue] = hexString(sender.color)
        coordinator.settings.agentColorOverrides = HarnessSettings.normalizedAgentColorOverrides(coordinator.settings.agentColorOverrides)
        retintAgentIcon(kind)
        try? coordinator.settings.save()
        coordinator.applySettingsToHosts()
    }

    /// Modal confirm for a destructive, instantly-applied reset. Mirrors the sidebar's delete/close
    /// alerts. Returns true only when the user explicitly confirms.
    func confirmDestructive(message: String, info: String, confirmTitle: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc func resetAgentColors() {
        guard confirmDestructive(
            message: "Reset agent colors?",
            info: "All custom agent color overrides will be removed. This can't be undone.",
            confirmTitle: "Reset"
        ) else { return }
        let coordinator = SessionCoordinator.shared
        coordinator.settings.agentColorOverrides.removeAll()
        for (kind, well) in agentColorWells {
            well.color = NSColor.fromHex(coordinator.settings.agentColorHex(for: kind)) ?? .gray
            retintAgentIcon(kind)
        }
        try? coordinator.settings.save()
        coordinator.applySettingsToHosts()
    }

    @objc func resetPalette() {
        for (index, well) in paletteWells.enumerated() {
            paletteHexValues[index] = nil
            well.color = NSColor.fromHex(Self.defaultAnsiPalette[index]) ?? .gray
        }
        flushAndApply()
    }

    private func syncAppearanceControlsFromSettings() {
        let settings = SessionCoordinator.shared.settings
        opacitySlider.doubleValue = Double(settings.backgroundOpacity)
        opacityLabel.stringValue = formatPercent(settings.backgroundOpacity)
        blurSlider.doubleValue = Double(settings.backgroundBlur)
        blurLabel.stringValue = formatBlur(settings.backgroundBlur)
        windowBorderOpacitySlider.doubleValue = Double(settings.windowBorderOpacity)
        windowBorderOpacityLabel.stringValue = formatPercent(settings.windowBorderOpacity)
        paddingXField.stringValue = String(Int(settings.windowPaddingX.rounded()))
        paddingYField.stringValue = String(Int(settings.windowPaddingY.rounded()))
        fontFamilyField.stringValue = settings.fontFamily
        fontSizeField.stringValue = String(Int(settings.fontSize.rounded()))
        experienceSegment.selectItem(withTitle: settings.experienceMode.displayName)
        experienceSummaryLabel.stringValue = settings.experienceMode.summary
        cursorStyleSegment.selectItem(withTitle: cursorStyleTitle(settings.cursorStyle))
        cursorBlinkToggle.state = settings.cursorBlink ? .on : .off
        copyOnSelectToggle.state = settings.copyOnSelect ? .on : .off
        keepSessionsToggle.state = SessionCoordinator.shared.snapshot.keepSessionsOnQuit ? .on : .off
        vividColorsToggle.state = settings.colorRendering == .vivid ? .on : .off
        textRenderingSegment.selectItem(withTitle: textRenderingTitle(settings.textRendering))
        themeTerminalOutputToggle.state = settings.applyThemeToTerminalOutput ? .on : .off
        ligaturesToggle.state = settings.ligatures ? .on : .off
        offMainPipelineToggle.state = settings.offMainParserFramePipeline ? .on : .off
        liveResizeReflowToggle.state = settings.liveResizeReflow ? .on : .off
        resizeOverlaySegment.selectItem(withTitle: resizeOverlayTitle(settings.resizeOverlay))
        resizeOverlayPositionSegment.selectItem(withTitle: resizeOverlayPositionTitle(settings.resizeOverlayPosition))
        paddingBalanceToggle.state = settings.windowPaddingBalance ? .on : .off
        minContrastSlider.doubleValue = settings.minimumContrast
        updateMinContrastLabel()
        pasteProtectionToggle.state = settings.pasteProtection ? .on : .off
        boldIsBrightToggle.state = settings.boldIsBright ? .on : .off
        for (event, toggle) in eventToggles {
            toggle.state = settings.isEventEnabled(event) ? .on : .off
        }
        commandFinishedThresholdField.stringValue = String(settings.commandFinishedThresholdSeconds)
        let autoThemeOn = settings.lightThemeName != nil && settings.darkThemeName != nil
        autoThemeToggle.state = autoThemeOn ? .on : .off
        lightThemePopup.isEnabled = autoThemeOn
        darkThemePopup.isEnabled = autoThemeOn
        themePopup.isEnabled = !autoThemeOn
        lightThemePopup.selectItem(withTitle: settings.lightThemeName ?? SessionCoordinator.shared.snapshot.themeName)
        darkThemePopup.selectItem(withTitle: settings.darkThemeName ?? SessionCoordinator.shared.snapshot.themeName)
        showStatusLineToggle.state = settings.showStatusLine ? .on : .off
        sidebarVisibleToggle.state = settings.sidebarVisible ? .on : .off
        sidebarOnRightToggle.state = settings.sidebarOnRight ? .on : .off
        restoreWindowSizeToggle.state = settings.restoreWindowSize ? .on : .off
        prefixControlSegment.selectItem(withTitle: harnessControlsTitle(settings.prefixKeyEnabled))
        statusLineControlSegment.selectItem(withTitle: harnessControlsTitle(settings.statusLineEnabled))
        systemNotificationsToggle.state = settings.systemNotificationsEnabled ? .on : .off
        notificationSoundToggle.state = settings.notificationSoundEnabled ? .on : .off
        notchModeSegment.selectItem(withTitle: notchModeTitle(settings.notchVisibilityMode))
        notchOpenOnHoverToggle.state = settings.notchOpenOnHover ? .on : .off
        notchSummaryLabel.stringValue = notchSummary(for: settings.notchVisibilityMode)
        for binding in colorBindings {
            binding.field.stringValue = settings[keyPath: binding.keyPath] ?? ""
            refreshColorBinding(binding)
        }
        paletteHexValues = HarnessSettings.normalizedPalette(settings.paletteHex)
        for (index, well) in paletteWells.enumerated() {
            well.color = paletteHexValues[index].flatMap(NSColor.fromHex)
                ?? NSColor.fromHex(Self.defaultAnsiPalette[index]) ?? .gray
        }
    }

    private func hexString(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func validateHexField(_ field: NSTextField) {
        let raw = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let valid = raw.isEmpty || normalizedHexOrNil(raw) != nil
        field.textColor = valid ? HarnessChrome.current.textPrimary : HarnessChrome.current.danger
    }

    @objc func resetToDefaults() {
        guard confirmDestructive(
            message: "Reset appearance to defaults?",
            info: "Colors, palette, font, padding, and other visual settings will be restored to their defaults. This can't be undone.",
            confirmTitle: "Reset"
        ) else { return }
        SessionCoordinator.shared.settings.resetToImportedConfig(imported: TerminalConfigImporter.load())
        syncAppearanceControlsFromSettings()
        flushAndApply()
    }

    func configureLiveAppearanceField(_ field: NSTextField) {
        field.target = self
        field.action = #selector(appearanceTextDidCommit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceTextDidChange(_:)),
            name: NSControl.textDidChangeNotification,
            object: field
        )
    }

    /// Single flush — push every field into HarnessSettings, save, and apply
    /// to the live terminal/window. Called from every control's action so the
    /// settings window behaves entirely live.
    func flushAndApply() {
        applySettingsLive()
        try? SessionCoordinator.shared.settings.save()
    }

    /// Push every field into HarnessSettings and apply it to the live surfaces, but DO NOT persist.
    /// Used on continuous slider drag ticks (60–120 Hz) so scrubbing never triggers a JSON encode +
    /// atomic write per tick; persistence happens once on the gesture's commit (`onCommit`). Every
    /// other control still goes through `flushAndApply`, which saves.
    private func applySettingsLive() {
        let coordinator = SessionCoordinator.shared
        coordinator.settings.backgroundOpacity = HarnessSettings.clampedOpacity(Float(opacitySlider.doubleValue))
        coordinator.settings.backgroundBlur = HarnessSettings.clampedBlur(Int(blurSlider.doubleValue.rounded()))
        coordinator.settings.windowBorderOpacity = max(0, min(1, Float(windowBorderOpacitySlider.doubleValue)))
        // Read every editable color from its control (bg/fg/cursor/cursor-text/
        // selection/bold + divider/status accents). nil = fall back to theme preset.
        for binding in colorBindings {
            coordinator.settings[keyPath: binding.keyPath] = normalizedHexOrNil(binding.field.stringValue)
        }
        coordinator.settings.paletteHex = HarnessSettings.normalizedPalette(paletteHexValues)
        coordinator.settings.transparentTitlebar = transparentTitlebarToggle.state == .on
        coordinator.settings.showStatusLine = showStatusLineToggle.state == .on
        coordinator.settings.sidebarVisible = sidebarVisibleToggle.state == .on
        coordinator.settings.sidebarOnRight = sidebarOnRightToggle.state == .on
        coordinator.settings.restoreWindowSize = restoreWindowSizeToggle.state == .on
        coordinator.settings.windowPaddingX = HarnessSettings.clampedPadding(Float(paddingXField.stringValue) ?? 12)
        coordinator.settings.windowPaddingY = HarnessSettings.clampedPadding(Float(paddingYField.stringValue) ?? 12)
        coordinator.settings.fontSize = HarnessSettings.clampedFontSize(Float(fontSizeField.stringValue) ?? 14)
        coordinator.settings.fontFamily = fontFamilyField.stringValue
        coordinator.settings.defaultShell = shellField.stringValue
        coordinator.settings.defaultCWD = cwdField.stringValue
        coordinator.settings.scrollbackLines = max(100, Int(scrollbackField.stringValue) ?? 10_000)
        coordinator.settings.cursorStyle = cursorStyleValue(cursorStyleSegment.titleOfSelectedItem)
        coordinator.settings.cursorBlink = cursorBlinkToggle.state == .on
        coordinator.settings.copyOnSelect = copyOnSelectToggle.state == .on
        coordinator.settings.systemNotificationsEnabled = systemNotificationsToggle.state == .on
        coordinator.settings.notificationSoundEnabled = notificationSoundToggle.state == .on
        coordinator.settings.notchVisibilityMode = selectedNotchVisibilityMode
        coordinator.settings.notchOpenOnHover = notchOpenOnHoverToggle.state == .on
        coordinator.settings.colorRendering = vividColorsToggle.state == .on ? .vivid : .accurate
        coordinator.settings.textRendering = textRenderingValue(textRenderingSegment.titleOfSelectedItem)
        coordinator.settings.applyThemeToTerminalOutput = themeTerminalOutputToggle.state == .on
        coordinator.settings.ligatures = ligaturesToggle.state == .on
        coordinator.settings.showPromptGutter = promptGutterToggle.state == .on
        coordinator.settings.offMainParserFramePipeline = offMainPipelineToggle.state == .on
        coordinator.settings.liveResizeReflow = liveResizeReflowToggle.state == .on
        coordinator.settings.resizeOverlay = resizeOverlayValue(resizeOverlaySegment.titleOfSelectedItem)
        coordinator.settings.resizeOverlayPosition = resizeOverlayPositionValue(resizeOverlayPositionSegment.titleOfSelectedItem)
        coordinator.settings.windowPaddingBalance = paddingBalanceToggle.state == .on
        coordinator.settings.minimumContrast = HarnessSettings.clampedContrast(minContrastSlider.doubleValue)
        coordinator.settings.pasteProtection = pasteProtectionToggle.state == .on
        coordinator.settings.boldIsBright = boldIsBrightToggle.state == .on
        for (event, toggle) in eventToggles {
            coordinator.settings.setEventEnabled(event, toggle.state == .on)
        }
        coordinator.settings.commandFinishedThresholdSeconds = max(1, Int(commandFinishedThresholdField.stringValue) ?? 10)
        // Reflect every clamped numeric field back into the UI so typing an out-of-range value
        // (fontSize "2", threshold "0", …) doesn't leave the field showing one number while the
        // setting — and the live terminals — silently use the clamped one. Non-numeric entries
        // reset to the persisted value the same way.
        reflectClamped(commandFinishedThresholdField, String(coordinator.settings.commandFinishedThresholdSeconds))
        reflectClamped(fontSizeField, String(format: "%.0f", coordinator.settings.fontSize))
        reflectClamped(paddingXField, String(format: "%.0f", coordinator.settings.windowPaddingX))
        reflectClamped(paddingYField, String(format: "%.0f", coordinator.settings.windowPaddingY))
        reflectClamped(scrollbackField, String(coordinator.settings.scrollbackLines))
        coordinator.settings.experienceMode = selectedExperienceMode
        coordinator.settings.prefixKeyEnabled = selectedPrefixEnabled
        coordinator.settings.statusLineEnabled = selectedStatusLineEnabled

        // Theme switching (and its color seeding) is handled by themeDidChange, so this only ever
        // pushes the current settings to the live surfaces — scrubbing a slider never fires a
        // setTheme IPC. Persistence is the caller's job (`flushAndApply` saves; drag ticks don't).
        coordinator.applySettingsToHosts()
        NotchPanelController.shared.refreshVisibility()
        updateFontReadout()
    }

    /// Rewrite a numeric field only when its committed text differs from the clamped setting —
    /// the UI must never show a value the terminals aren't actually using.
    private func reflectClamped(_ field: NSTextField, _ clamped: String) {
        if field.stringValue != clamped { field.stringValue = clamped }
    }

    /// Safety net for the apply-only/persist-on-commit split (#89): continuous sliders apply live on
    /// every drag tick but only persist in `HarnessSlider.mouseUp → onCommit`. If a drag never gets
    /// its mouse-up (window closed programmatically mid-drag, a modal steals the gesture, the app
    /// deactivates mid-track), the live-applied value would never be saved. Flushing on teardown
    /// guarantees the visible state is the persisted state. `flushAndApply` is idempotent (read
    /// controls → settings → save), so a redundant call after a normal commit is harmless.
    func persistPendingState() {
        flushAndApply()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        persistPendingState()
    }
}
