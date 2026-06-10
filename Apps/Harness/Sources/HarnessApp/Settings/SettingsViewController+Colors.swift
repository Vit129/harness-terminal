import AppKit
import HarnessCore
import HarnessTerminalKit
import UserNotifications

extension SettingsViewController {
    // MARK: - Page: Colors

    func buildColorsPage() -> NSView {
        let header = pageHeader(title: "Colors", trailing: nil)

        // colorBindings 0–6 are the terminal colors; 7–8 are the chrome accents. The
        // selected theme seeds every one; the user can then edit any swatch.
        let colorsGroup = colorGrid(
            left: [
                ("Background", colorBindings[0]),
                ("Cursor", colorBindings[2]),
                ("Selection", colorBindings[4]),
                ("Bold", colorBindings[6]),
            ],
            right: [
                ("Foreground", colorBindings[1]),
                ("Cursor text", colorBindings[3]),
                ("Selection text", colorBindings[5]),
            ]
        )

        let minContrastRow = NSStackView(views: [minContrastSlider, minContrastLabel])
        minContrastRow.orientation = .horizontal
        minContrastRow.spacing = 12
        minContrastSlider.widthAnchor.constraint(equalToConstant: 260).isActive = true
        minContrastLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true
        minContrastLabel.alignment = .right

        let renderingGroup = settingsGroup("Color rendering", [
            settingsToggleRow("Wide gamut", vividColorsToggle, hint: "Opt-in Display P3 conversion."),
            settingsRow("Text rendering", textRenderingSegment,
                        hint: "Glyph weight: Native, Crisp (lighter), or Soft (heavier)."),
            settingsRow("Minimum contrast", minContrastRow,
                        hint: "Lift dim text to a WCAG contrast ratio (1 = off)."),
            settingsToggleRow("Bold is bright", boldIsBrightToggle,
                              hint: "Bold text in colors 0–7 uses the bright palette (8–15)."),
            settingsToggleRow("Theme program output", themeTerminalOutputToggle),
            settingsToggleRow("Ligatures", ligaturesToggle),
            settingsToggleRow("Prompt gutter", promptGutterToggle),
        ])

        let chromeAccents = colorGrid(
            left: [("Divider lines", colorBindings[7]), ("Window border", colorBindings[9])],
            right: [("Status line text", colorBindings[8])]
        )

        let stack = NSStackView(views: [
            header,
            settingsGroup("Terminal colors", [colorsGroup]),
            renderingGroup,
            settingsGroup("ANSI palette", [buildPaletteSection()]),
            settingsGroup("Chrome", [chromeAccents]),
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        return scrollWrap(stack)
    }

    func makeLinkButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        styleAsLink(button)
        return button
    }

    func makeRoundedButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        return button
    }

    func styleAsLink(_ button: NSButton) {
        button.bezelStyle = .accessoryBarAction
        button.isBordered = false
        // The theme accent (derived from the cursor color) — never the macOS system blue.
        let link = HarnessChrome.current.accent
        let attr = NSAttributedString(string: button.title, attributes: [
            .foregroundColor: link,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
        ])
        button.attributedTitle = attr
        button.contentTintColor = link
        if !linkButtons.contains(where: { $0 === button }) { linkButtons.append(button) }
    }
}
