import AppKit
import HarnessCore
import HarnessTerminalKit
import UserNotifications

extension SettingsViewController {
    // MARK: - Page: Appearance

    func buildAppearancePage() -> NSView {
        let header = pageHeader(title: "Appearance", trailing: nil)

        useThemeColorsButton.title = "Use theme colors"
        styleAsLink(useThemeColorsButton)
        let resetDefaults = makeLinkButton("Reset to defaults", action: #selector(resetToDefaults))
        for link in [useThemeColorsButton, resetDefaults] {
            link.lineBreakMode = .byClipping
            link.setContentCompressionResistancePriority(.required, for: .horizontal)
            link.setContentHuggingPriority(.required, for: .horizontal)
        }
        themePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true

        let opacityRow = NSStackView(views: [opacitySlider, opacityLabel])
        opacityRow.orientation = .horizontal
        opacityRow.spacing = 12
        opacitySlider.widthAnchor.constraint(equalToConstant: 260).isActive = true
        opacityLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        opacityLabel.alignment = .right

        let blurRow = NSStackView(views: [blurSlider, blurLabel])
        blurRow.orientation = .horizontal
        blurRow.spacing = 12
        blurSlider.widthAnchor.constraint(equalToConstant: 260).isActive = true
        blurLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        blurLabel.alignment = .right

        let windowBorderRow = NSStackView(views: [windowBorderOpacitySlider, windowBorderOpacityLabel])
        windowBorderRow.orientation = .horizontal
        windowBorderRow.spacing = 12
        windowBorderOpacitySlider.widthAnchor.constraint(equalToConstant: 260).isActive = true
        windowBorderOpacityLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        windowBorderOpacityLabel.alignment = .right

        paddingXField.widthAnchor.constraint(equalToConstant: 70).isActive = true
        paddingYField.widthAnchor.constraint(equalToConstant: 70).isActive = true
        let paddingRow = NSStackView(views: [
            paddingXField,
            NSTextField(labelWithString: "×"),
            paddingYField,
            NSTextField(labelWithString: "pt"),
        ])
        paddingRow.orientation = .horizontal
        paddingRow.spacing = 6
        paddingRow.alignment = .centerY

        let themeActions = NSStackView(views: [useThemeColorsButton, resetDefaults])
        themeActions.orientation = .horizontal
        themeActions.spacing = 16
        themeActions.alignment = .centerY

        lightThemePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        darkThemePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        let themeGroup = settingsGroup("Theme", [
            settingsRow("Theme", themePopup),
            settingsToggleRow("Auto light/dark", autoThemeToggle,
                              hint: "Switch theme with the macOS system appearance."),
            settingsRow("Light theme", lightThemePopup),
            settingsRow("Dark theme", darkThemePopup),
            settingsRow("", themeActions),
        ])
        let windowGroup = settingsGroup("Window", [
            settingsRow("Opacity", opacityRow),
            settingsRow("Blur", blurRow),
            settingsRow("Edge border", windowBorderRow,
                        hint: "Faint hairline around the window edge — 0% hides it."),
            settingsRow("Padding", paddingRow),
            settingsToggleRow("Center grid", paddingBalanceToggle,
                              hint: "Distribute leftover padding evenly so the grid is centered."),
            settingsRow("Resize overlay", resizeOverlaySegment,
                        hint: "Show the grid size while resizing the window."),
            settingsRow("Overlay position", resizeOverlayPositionSegment,
                        hint: "Where the resize overlay is drawn within the surface."),
            settingsToggleRow("Transparent title bar", transparentTitlebarToggle),
            settingsToggleRow("Status line", showStatusLineToggle),
            settingsToggleRow("Sidebar", sidebarVisibleToggle),
            settingsToggleRow("Sidebar on right", sidebarOnRightToggle),
            settingsToggleRow("Always collapse sidebar on launch", sidebarCollapsedOnLaunchToggle),
            settingsToggleRow("Remember window size", restoreWindowSizeToggle,
                              hint: "Reopen at the last size and position."),
        ])

        let stack = NSStackView(views: [
            header,
            themeGroup,
            windowGroup,
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        return scrollWrap(stack)
    }
}
