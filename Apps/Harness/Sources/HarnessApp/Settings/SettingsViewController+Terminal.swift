import AppKit
import HarnessCore
import HarnessTerminalKit
import UserNotifications

extension SettingsViewController {
    // MARK: - Page: Terminal

    func buildTerminalPage() -> NSView {
        let header = pageHeader(title: "Terminal", trailing: nil)

        let chooseFontButton = makeRoundedButton("Choose Font…", action: #selector(chooseFont))
        fontReadout.font = .systemFont(ofSize: 12)
        fontReadout.textColor = .secondaryLabelColor
        let fontRow = NSStackView(views: [chooseFontButton, fontReadout])
        fontRow.orientation = .horizontal
        fontRow.spacing = 12
        fontRow.alignment = .centerY

        fontSizeField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        shellField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        cwdField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        scrollbackField.widthAnchor.constraint(equalToConstant: 100).isActive = true

        let fontGroup = settingsGroup("Font", settingsRows([
            ("Font", fontRow),
            ("Size", fontSizeField),
        ]))
        let shellGroup = settingsGroup("Shell", settingsRows([
            ("Shell", shellField),
            ("Default directory", cwdField),
        ]))
        let defaultTerminalGroup = settingsGroup("Default terminal", [
            settingsCaption("Use Harness for SSH/Telnet links, man-page links, and .command/.tool files."),
            leadingRow(defaultTerminalButton),
            defaultTerminalStatusField,
        ])
        let behaviorGroup = settingsGroup("Behavior", [
            settingsRow("Cursor style", cursorStyleSegment),
            settingsRow("Scrollback", scrollbackField),
            settingsToggleRow("Blink cursor", cursorBlinkToggle),
            settingsToggleRow("Copy on select", copyOnSelectToggle),
            settingsToggleRow("Paste protection", pasteProtectionToggle),
            settingsToggleRow("Keep sessions running", keepSessionsToggle),
        ])

        // Experience mode: how much of Harness is exposed (controls + default session
        // persistence). It governs terminal behavior, so it lives here rather than under
        // Appearance. The summary updates live so the choice is self-explanatory.
        experienceSegment.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let experienceContent = NSStackView(views: [experienceSegment, experienceSummaryLabel])
        experienceContent.orientation = .vertical
        experienceContent.alignment = .leading
        experienceContent.spacing = 8
        experienceSegment.widthAnchor.constraint(equalTo: experienceContent.widthAnchor).isActive = true
        let experienceGroup = settingsGroup("Experience", [
            experienceContent,
            settingsRow("Command prefix", prefixControlSegment,
                        hint: "Arm the prefix key. Auto follows the mode above."),
            settingsRow("Status line", statusLineControlSegment,
                        hint: "Show the bottom status band. Auto follows the mode above."),
        ])

        let stack = NSStackView(views: [
            header,
            experienceGroup,
            fontGroup,
            shellGroup,
            defaultTerminalGroup,
            behaviorGroup,
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        return scrollWrap(stack)
    }

    // MARK: - Font picker (Terminal page)

    @objc private func chooseFont() {
        let current = NSFont(name: SessionCoordinator.shared.settings.fontFamily,
                             size: CGFloat(SessionCoordinator.shared.settings.fontSize))
            ?? .monospacedSystemFont(ofSize: CGFloat(SessionCoordinator.shared.settings.fontSize), weight: .regular)
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.setSelectedFont(current, isMultiple: false)
        let panel = fontManager.fontPanel(true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func changeFont(_ sender: NSFontManager?) {
        guard let manager = sender else { return }
        let base = NSFont(name: fontFamilyField.stringValue,
                          size: CGFloat(Float(fontSizeField.stringValue) ?? 14))
            ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
        let converted = manager.convert(base)
        fontFamilyField.stringValue = converted.familyName ?? converted.fontName
        fontSizeField.stringValue = String(format: "%.0f", converted.pointSize)
        flushAndApply()
    }

    func validModesForFontPanel(_ fontPanel: NSFontPanel) -> NSFontPanel.ModeMask {
        [.collection, .face, .size]
    }

    func normalizedHexOrNil(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let cleaned = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard cleaned.count == 6,
              cleaned.allSatisfy({ $0.isHexDigit })
        else { return nil }
        return "#\(cleaned)"
    }

    @objc func openAgentsJSON() {
        let url = HarnessPaths.applicationSupport.appendingPathComponent("agents.json")
        if !FileManager.default.fileExists(atPath: url.path) {
            let defaults = AgentTable.default
            if let data = try? JSONEncoder().encode(defaults) {
                try? data.write(to: url, options: .atomic)
            }
        }
        NSWorkspace.shared.open(url)
    }
}
