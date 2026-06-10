import AppKit
import HarnessCore
import HarnessTerminalKit
import UserNotifications

extension SettingsViewController {
    // MARK: - Layout helpers

    func pageHeader(title: String, trailing: NSButton? = nil) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .labelColor
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.addArrangedSubview(titleLabel)
        if let trailing {
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            stack.addArrangedSubview(spacer)
            stack.addArrangedSubview(trailing)
        }
        return stack
    }

    // MARK: - Grouped settings primitives

    /// One settings row: label column, flexible middle, trailing control.
    func settingsRow(_ label: String, _ control: NSView, hint: String? = nil) -> NSView {
        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false

        func makeSpacer() -> NSView {
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return spacer
        }

        if label.isEmpty {
            row.addArrangedSubview(control)
            row.addArrangedSubview(makeSpacer())
        } else {
            let titleLabel = NSTextField(labelWithString: label)
            titleLabel.font = .systemFont(ofSize: 13)
            titleLabel.textColor = .labelColor
            titleLabel.alignment = .right
            titleLabel.widthAnchor.constraint(equalToConstant: 150).isActive = true
            titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            let labelCol: NSView
            if let hint {
                let hintLabel = NSTextField(wrappingLabelWithString: hint)
                hintLabel.font = .systemFont(ofSize: 11)
                hintLabel.textColor = .secondaryLabelColor
                hintLabel.alignment = .right
                hintLabel.preferredMaxLayoutWidth = 150
                let col = NSStackView(views: [titleLabel, hintLabel])
                col.orientation = .vertical
                col.alignment = .trailing
                col.spacing = 2
                labelCol = col
            } else {
                labelCol = titleLabel
            }
            row.addArrangedSubview(labelCol)
            row.addArrangedSubview(makeSpacer())
            row.addArrangedSubview(control)
        }
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        return row
    }

    /// Convenience: build a list of `settingsRow`s from `(label, control)` pairs.
    func settingsRows(_ items: [(String, NSView)]) -> [NSView] {
        items.map { settingsRow($0.0, $0.1) }
    }

    func settingsToggleRow(_ title: String, _ toggle: HarnessToggle, hint: String? = nil) -> NSView {
        toggle.title = ""
        toggle.setAccessibilityLabel(title)
        return settingsRow(title, toggle, hint: hint)
    }

    func settingsGroup(_ title: String?, _ rows: [NSView]) -> NSView {
        let outer = NSStackView()
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = 8
        outer.translatesAutoresizingMaskIntoConstraints = false

        if let title, !title.isEmpty {
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .secondaryLabelColor
            outer.addArrangedSubview(label)
        }

        let surface = NSView()
        surface.wantsLayer = true
        surface.layer?.backgroundColor = HarnessChrome.current.surfaceElevated.cgColor
        surface.layer?.cornerRadius = HarnessDesign.Radius.card
        surface.layer?.cornerCurve = .continuous
        surface.layer?.borderWidth = 1
        surface.layer?.borderColor = HarnessChrome.current.border.cgColor
        surface.translatesAutoresizingMaskIntoConstraints = false
        groupSurfaces.append(surface)

        let rowStack = NSStackView()
        rowStack.orientation = .vertical
        rowStack.alignment = .width
        rowStack.spacing = 0
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        for (index, content) in rows.enumerated() {
            if index > 0 { rowStack.addArrangedSubview(groupDivider()) }
            rowStack.addArrangedSubview(paddedRow(content))
        }

        surface.addSubview(rowStack)
        outer.addArrangedSubview(surface)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: surface.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
            surface.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
        ])
        return outer
    }

    /// Uniform insets around one group row (content provides its own height).
    private func paddedRow(_ content: NSView) -> NSView {
        content.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 9),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -9),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
        ])
        return container
    }

    private func groupDivider() -> NSView {
        let wrap = NSView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = HarnessChrome.current.border.cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        groupDividers.append(line)
        wrap.addSubview(line)
        NSLayoutConstraint.activate([
            wrap.heightAnchor.constraint(equalToConstant: 1),
            line.topAnchor.constraint(equalTo: wrap.topAnchor),
            line.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 18),
            line.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
        ])
        return wrap
    }

    func colorGrid(
        left: [(title: String, binding: ColorBinding)],
        right: [(title: String, binding: ColorBinding)]
    ) -> NSView {
        let leftColumn = colorColumn(left)
        let rightColumn = colorColumn(right)
        let row = NSStackView(views: [leftColumn, rightColumn])
        row.orientation = .horizontal
        row.alignment = .top
        row.distribution = .fillEqually
        row.spacing = 28
        return row
    }

    private func colorColumn(_ items: [(title: String, binding: ColorBinding)]) -> NSView {
        let column = NSStackView(views: items.map { colorHexRow(title: $0.title, binding: $0.binding) })
        column.orientation = .vertical
        column.alignment = .width
        column.spacing = 10
        return column
    }

    /// `[swatch] Name [hex] [reset-slot]` with fixed subcolumns so every row aligns.
    private func colorHexRow(title: String, binding: ColorBinding) -> NSView {
        binding.field.widthAnchor.constraint(equalToConstant: ColorFormMetrics.fieldWidth).isActive = true
        binding.field.placeholderString = binding.themeColor()?.uppercased() ?? "—"
        binding.field.font = .monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
        binding.field.usesSingleLineMode = true

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12.5, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.widthAnchor.constraint(equalToConstant: ColorFormMetrics.labelWidth).isActive = true

        let resetSlot = NSView()
        resetSlot.translatesAutoresizingMaskIntoConstraints = false
        binding.reset.translatesAutoresizingMaskIntoConstraints = false
        resetSlot.addSubview(binding.reset)
        NSLayoutConstraint.activate([
            resetSlot.widthAnchor.constraint(equalToConstant: ColorFormMetrics.resetSlotWidth),
            resetSlot.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
            binding.reset.centerXAnchor.constraint(equalTo: resetSlot.centerXAnchor),
            binding.reset.centerYAnchor.constraint(equalTo: resetSlot.centerYAnchor),
        ])

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [binding.well, label, binding.field, resetSlot, spacer])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        return row
    }

    /// 16 ANSI swatches in two rows of eight plus a reset link.
    func buildPaletteSection() -> NSView {
        let topRow = NSStackView(views: (0 ..< 8).map(paletteCell))
        topRow.orientation = .horizontal
        topRow.spacing = 8
        topRow.alignment = .top
        let bottomRow = NSStackView(views: (8 ..< 16).map(paletteCell))
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .top
        let resetLink = makeLinkButton("Reset palette", action: #selector(resetPalette))
        let group = NSStackView(views: [topRow, bottomRow, resetLink])
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = 10
        return group
    }

    /// Wraps a page's content stack in a vertical scroll view so it remains
    /// reachable on shorter window heights without forcing every section to
    /// scroll all together.
    func scrollWrap(_ content: NSStackView) -> NSView {
        let documentView = SettingsFlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(content)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        scroll.contentView.drawsBackground = false
        documentView.wantsLayer = true
        documentView.layer?.backgroundColor = NSColor.clear.cgColor
        scroll.documentView = documentView
        scroll.translatesAutoresizingMaskIntoConstraints = false

        content.alignment = .leading
        NSLayoutConstraint.activate([
            documentView.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            documentView.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),

            content.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 34),
            content.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 36),
            content.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -36),
            content.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -34),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 720),
        ])
        for section in content.arrangedSubviews {
            NSLayoutConstraint.activate([
                section.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                section.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            ])
        }
        return scroll
    }

    func makeResetButton() -> NSButton {
        let button = NSButton()
        button.bezelStyle = .shadowlessSquare
        button.image = NSImage(systemSymbolName: "arrow.uturn.backward.circle",
                               accessibilityDescription: "Reset to theme color")
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = .tertiaryLabelColor
        button.target = self
        button.action = #selector(colorResetClicked(_:))
        button.toolTip = "Use theme color"
        return button
    }

    func configureResetButton(_ button: NSButton) {
        button.widthAnchor.constraint(equalToConstant: 22).isActive = true
        button.heightAnchor.constraint(equalToConstant: 22).isActive = true
    }

    func buildPaletteWells() {
        paletteWells.removeAll()
        for index in 0 ..< 16 {
            let well = HarnessSwatchWell(frame: .zero)
            well.translatesAutoresizingMaskIntoConstraints = false
            well.widthAnchor.constraint(equalToConstant: 40).isActive = true
            well.heightAnchor.constraint(equalToConstant: 32).isActive = true
            well.color = paletteHexValues[index].flatMap(NSColor.fromHex)
                ?? NSColor.fromHex(Self.defaultAnsiPalette[index]) ?? .gray
            well.target = self
            well.action = #selector(paletteWellChanged(_:))
            well.toolTip = Self.ansiNames[index]
            paletteWells.append(well)
        }
    }

    func buildAgentColorWells(settings: HarnessSettings) {
        agentColorWells.removeAll()
        for kind in Self.agentColorKinds {
            let well = HarnessSwatchWell(frame: .zero)
            well.translatesAutoresizingMaskIntoConstraints = false
            well.widthAnchor.constraint(equalToConstant: 38).isActive = true
            well.heightAnchor.constraint(equalToConstant: 22).isActive = true
            well.color = NSColor.fromHex(settings.agentColorHex(for: kind)) ?? .gray
            well.target = self
            well.action = #selector(agentColorWellChanged(_:))
            well.toolTip = kind.displayName
            agentColorWells[kind] = well
        }
    }

    private func paletteCell(_ index: Int) -> NSView {
        let label = NSTextField(labelWithString: "\(index)")
        label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        let cell = NSStackView(views: [paletteWells[index], label])
        cell.orientation = .vertical
        cell.spacing = 4
        cell.alignment = .centerX
        return cell
    }

    // MARK: - Formatting / utilities

    func formatPercent(_ value: Float) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    func formatBlur(_ value: Int) -> String {
        value == 0 ? "off" : "\(value) px"
    }

    func cursorStyleTitle(_ value: String) -> String {
        switch value {
        case "bar": return "Beam"
        case "underline": return "Underline"
        default: return "Block"
        }
    }

    func cursorStyleValue(_ title: String?) -> String {
        switch title {
        case "Beam": return "bar"
        case "Underline": return "underline"
        default: return "block"
        }
    }

    func textRenderingTitle(_ value: TerminalTextRenderingMode) -> String {
        switch value {
        case .crisp: return "Crisp"
        case .soft: return "Soft"
        case .native: return "Native"
        }
    }

    func textRenderingValue(_ title: String?) -> TerminalTextRenderingMode {
        switch title {
        case "Crisp": return .crisp
        case "Soft": return .soft
        default: return .native
        }
    }

    /// Tri-state mapping for the optional Harness-controls override: Auto = `nil`
    /// (follow the experience mode), On/Off force `true`/`false`.
    func harnessControlsTitle(_ value: Bool?) -> String {
        switch value {
        case .some(true): return "On"
        case .some(false): return "Off"
        case .none: return "Auto"
        }
    }

    /// Tri-state segment title → `Bool?` override (Auto = nil). Shared by the prefix and status
    /// line segments since both map Auto/On/Off the same way.
    private func tristateOverride(from segment: HarnessSegmented) -> Bool? {
        switch segment.titleOfSelectedItem {
        case "On": return true
        case "Off": return false
        default: return nil
        }
    }

    var selectedPrefixEnabled: Bool? { tristateOverride(from: prefixControlSegment) }
    var selectedStatusLineEnabled: Bool? { tristateOverride(from: statusLineControlSegment) }

    func updateFontReadout() {
        let s = SessionCoordinator.shared.settings
        fontReadout.stringValue = "\(s.fontFamily) · \(Int(s.fontSize.rounded()))pt"
    }
}
