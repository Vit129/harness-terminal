import AppKit
import KouenCore

// MARK: - Session rows

@MainActor
final class SessionGroupHeaderRowView: NSView {
    var onAdd: (() -> Void)?
    var onToggleCollapse: (() -> Void)?
    var onOptions: ((NSView) -> Void)?
    var onContextMenu: (() -> NSMenu?)?

    private let leftStack = NSStackView()
    private let rightStack = NSStackView()
    private let disclosureImage = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let boardStatusDot = NSView()
    private let boardStatusLabel = NSTextField(labelWithString: "")
    private let addButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    private let optionsButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    private var isCollapsed = false
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        disclosureImage.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(KouenDesign.symbolConfig(pointSize: KouenDesign.IconSize.tiny, weight: .regular))
        disclosureImage.translatesAutoresizingMaskIntoConstraints = false
        disclosureImage.setContentHuggingPriority(.required, for: .horizontal)

        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        boardStatusDot.wantsLayer = true
        boardStatusDot.layer?.cornerRadius = 3
        boardStatusDot.layer?.cornerCurve = .continuous
        boardStatusDot.translatesAutoresizingMaskIntoConstraints = false

        boardStatusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        boardStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        boardStatusLabel.setContentHuggingPriority(.required, for: .horizontal)
        boardStatusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        addButton.setSymbol("plus", accessibilityDescription: "New session in group", pointSize: 10, weight: .medium)
        addButton.toolTip = "New session in group"
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.target = self
        addButton.action = #selector(addClicked)
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        optionsButton.setSymbol("ellipsis", accessibilityDescription: "Group options", pointSize: 10, weight: .medium)
        optionsButton.toolTip = "Group options"
        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        optionsButton.target = self
        optionsButton.action = #selector(optionsClicked)
        optionsButton.setContentHuggingPriority(.required, for: .horizontal)
        optionsButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 6
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        leftStack.addArrangedSubview(disclosureImage)
        leftStack.addArrangedSubview(label)
        leftStack.addArrangedSubview(boardStatusDot)
        leftStack.addArrangedSubview(boardStatusLabel)

        rightStack.orientation = .horizontal
        rightStack.alignment = .centerY
        rightStack.spacing = 4
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.addArrangedSubview(addButton)
        rightStack.addArrangedSubview(optionsButton)

        addSubview(leftStack)
        addSubview(rightStack)

        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KouenDesign.horizontalInset - 4),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),

            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(KouenDesign.horizontalInset - 4)),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            disclosureImage.widthAnchor.constraint(equalToConstant: 10),
            disclosureImage.heightAnchor.constraint(equalToConstant: 10),

            boardStatusDot.widthAnchor.constraint(equalToConstant: 6),
            boardStatusDot.heightAnchor.constraint(equalToConstant: 6),

            addButton.widthAnchor.constraint(equalToConstant: 20),
            addButton.heightAnchor.constraint(equalToConstant: 20),

            optionsButton.widthAnchor.constraint(equalToConstant: 20),
            optionsButton.heightAnchor.constraint(equalToConstant: 20),
        ])

        let press = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        press.minimumPressDuration = 0.5
        addGestureRecognizer(press)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func menu(for event: NSEvent) -> NSMenu? {
        return onContextMenu?()
    }

    @objc private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        if let menu = onContextMenu?() {
            let point = gesture.location(in: self)
            menu.popUp(positioning: nil, at: point, in: self)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        guard window != nil else { trackingArea = nil; return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refresh()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refresh()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let addFrame = convert(addButton.bounds, from: addButton)
        let optFrame = convert(optionsButton.bounds, from: optionsButton)
        if addFrame.contains(point) || optFrame.contains(point) {
            super.mouseDown(with: event)
        } else {
            onToggleCollapse?()
        }
    }

    func configure(name: String, count: Int, isCollapsed: Bool, status: BoardColumnKind) {
        label.stringValue = name
        toolTip = name
        self.isCollapsed = isCollapsed
        disclosureImage.image = NSImage(
            systemSymbolName: isCollapsed ? "chevron.right" : "chevron.down",
            accessibilityDescription: isCollapsed ? "Collapsed" : "Expanded"
        )?.withSymbolConfiguration(KouenDesign.symbolConfig(pointSize: KouenDesign.IconSize.tiny, weight: .regular))
        disclosureImage.needsDisplay = true

        let dotColor: NSColor
        let statusText: String
        switch status {
        case .needsAttention:
            dotColor = .systemOrange
            statusText = "Needs Attention"
        case .running:
            dotColor = .systemBlue
            statusText = "Running"
        case .done:
            dotColor = .systemGreen
            statusText = "Done"
        case .error:
            dotColor = .systemRed
            statusText = "Error"
        case .idle:
            dotColor = .systemGray
            statusText = "Idle"
        }
        boardStatusDot.layer?.backgroundColor = dotColor.cgColor
        boardStatusLabel.stringValue = "\(count) \(count == 1 ? "worktree" : "worktrees")"
        boardStatusLabel.toolTip = statusText

        refresh()
    }

    @objc private func addClicked() {
        onAdd?()
    }

    @objc private func optionsClicked() {
        onOptions?(optionsButton)
    }

    private func refresh() {
        let c = KouenDesign.chrome
        label.textColor = c.textPrimary
        disclosureImage.contentTintColor = isHovered ? c.textPrimary : c.textSecondary
        boardStatusLabel.textColor = isHovered ? c.textSecondary : c.textTertiary
        addButton.alphaValue = isHovered ? 1 : 0
        optionsButton.alphaValue = isHovered ? 1 : 0
    }
}

@MainActor
final class WorktreeRowView: NSView {
    var onContextMenu: (() -> NSMenu?)?
    var onClose: (() -> Void)?
    var onPRClick: (() -> Void)?

    private let fill = NSView()
    private let agentStatusDot = NSView()
    private let agentIconView = NSImageView()
    private let branchIcon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let prBadge = SidebarBadgeView()
    private let aheadBadge = SidebarBadgeView()
    private let behindBadge = SidebarBadgeView()
    private let notificationBadge = SidebarBadgeView()
    private let closeButton = NSButton()
    private let badgeStack = NSStackView()
    private var isSelected = false
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        fill.wantsLayer = true
        fill.layer?.cornerRadius = KouenDesign.Radius.card
        fill.layer?.cornerCurve = .continuous
        fill.layer?.borderWidth = 1
        fill.layer?.masksToBounds = false
        fill.translatesAutoresizingMaskIntoConstraints = false

        agentStatusDot.wantsLayer = true
        agentStatusDot.layer?.cornerRadius = 3
        agentStatusDot.layer?.cornerCurve = .continuous
        agentStatusDot.translatesAutoresizingMaskIntoConstraints = false
        agentStatusDot.setContentHuggingPriority(.required, for: .horizontal)
        agentStatusDot.setContentCompressionResistancePriority(.required, for: .horizontal)

        agentIconView.imageScaling = .scaleProportionallyUpOrDown
        agentIconView.translatesAutoresizingMaskIntoConstraints = false
        agentIconView.isHidden = true

        branchIcon.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?
            .withSymbolConfiguration(KouenDesign.symbolConfig(pointSize: 10, weight: .semibold))
        branchIcon.contentTintColor = KouenDesign.chrome.textTertiary
        branchIcon.translatesAutoresizingMaskIntoConstraints = false
        branchIcon.setContentHuggingPriority(.required, for: .horizontal)
        branchIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subtitleLabel.font = .systemFont(ofSize: 10)
        subtitleLabel.usesSingleLineMode = true
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        prBadge.isHidden = true
        let prClick = NSClickGestureRecognizer(target: self, action: #selector(handlePRClick))
        prBadge.addGestureRecognizer(prClick)
        aheadBadge.isHidden = true
        behindBadge.isHidden = true
        notificationBadge.isHidden = true

        closeButton.title = "×"
        closeButton.bezelStyle = .accessoryBarAction
        closeButton.isBordered = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.toolTip = "Close session"
        closeButton.alphaValue = 0
        closeButton.setContentHuggingPriority(.required, for: .horizontal)
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        badgeStack.orientation = .horizontal
        badgeStack.alignment = .centerY
        badgeStack.spacing = 4
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        badgeStack.addArrangedSubview(prBadge)
        badgeStack.addArrangedSubview(aheadBadge)
        badgeStack.addArrangedSubview(behindBadge)
        badgeStack.addArrangedSubview(notificationBadge)
        badgeStack.addArrangedSubview(closeButton)

        addSubview(fill)
        fill.addSubview(agentStatusDot)
        fill.addSubview(agentIconView)
        fill.addSubview(branchIcon)
        fill.addSubview(titleLabel)
        fill.addSubview(subtitleLabel)
        fill.addSubview(badgeStack)

        NSLayoutConstraint.activate([
            fill.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            fill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KouenDesign.horizontalInset + 8),
            fill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(KouenDesign.horizontalInset - 4)),

            agentStatusDot.leadingAnchor.constraint(equalTo: fill.leadingAnchor, constant: 8),
            agentStatusDot.centerYAnchor.constraint(equalTo: fill.centerYAnchor),
            agentStatusDot.widthAnchor.constraint(equalToConstant: 6),
            agentStatusDot.heightAnchor.constraint(equalToConstant: 6),

            agentIconView.leadingAnchor.constraint(equalTo: fill.leadingAnchor, constant: 5),
            agentIconView.centerYAnchor.constraint(equalTo: fill.centerYAnchor),
            agentIconView.widthAnchor.constraint(equalToConstant: 14),
            agentIconView.heightAnchor.constraint(equalToConstant: 14),

            branchIcon.leadingAnchor.constraint(equalTo: agentStatusDot.trailingAnchor, constant: 6),
            branchIcon.centerYAnchor.constraint(equalTo: fill.centerYAnchor),
            branchIcon.widthAnchor.constraint(equalToConstant: 12),
            branchIcon.heightAnchor.constraint(equalToConstant: 12),

            titleLabel.leadingAnchor.constraint(equalTo: branchIcon.trailingAnchor, constant: 6),
            titleLabel.topAnchor.constraint(equalTo: fill.topAnchor, constant: 5),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeStack.leadingAnchor, constant: -6),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeStack.leadingAnchor, constant: -6),

            badgeStack.trailingAnchor.constraint(equalTo: fill.trailingAnchor, constant: -6),
            badgeStack.centerYAnchor.constraint(equalTo: fill.centerYAnchor),
            
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    @objc private func closeClicked() {
        onClose?()
    }

    @objc private func handlePRClick() {
        onPRClick?()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        guard window != nil else { trackingArea = nil; return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    func configure(session: SessionGroup, isSelected: Bool, metadata: RepoGitMetadata?) {
        let tab = session.activeTab ?? session.tabs.first ?? Tab()
        let c = KouenDesign.chrome

        let title = session.name.isEmpty ? KouenDesign.pathDisplayName(tab.cwd) : session.name
        let branch = tab.gitBranch?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        titleLabel.stringValue = branch.isEmpty ? title : branch
        titleLabel.textColor = isSelected ? c.textPrimary : c.textSecondary
        subtitleLabel.stringValue = KouenDesign.shortenPath(tab.cwd)
        subtitleLabel.textColor = c.textSecondary.withAlphaComponent(0.6)
        
        toolTip = "\(title)\n\(tab.cwd)"

        let waitingCount = session.tabs.filter { $0.status == .waiting }.count
        notificationBadge.configure(text: "\(waitingCount)", color: c.danger)
        notificationBadge.isHidden = waitingCount == 0

        let (dotColor, dotTooltip) = agentDotAppearance(for: session)
        agentStatusDot.layer?.backgroundColor = dotColor.cgColor
        agentStatusDot.toolTip = dotTooltip
        // Show agent brand icon when detected, hide plain dot
        let agentKind = session.tabs.compactMap({ $0.effectiveAgentKind }).first
        if let agentKind {
            agentIconView.image = AgentIconRenderer.templateOrMonogramImage(for: agentKind, size: 14)
            agentIconView.contentTintColor = NSColor.fromHex(SessionCoordinator.shared.settings.agentColorHex(for: agentKind))
                ?? KouenDesign.chrome.textSecondary
            agentIconView.isHidden = false
            agentStatusDot.isHidden = true
        } else {
            agentIconView.isHidden = true
            agentStatusDot.isHidden = false
        }
        // Branch icon matches agent status color for visual pop
        branchIcon.contentTintColor = dotColor

        if let metadata {
            if let pr = metadata.prNumber {
                let prColor: NSColor = (metadata.aheadCount ?? 0) > 0 ? .systemGreen : c.accent
                prBadge.configure(text: "#\(pr)", color: prColor)
                prBadge.isHidden = false
            } else {
                prBadge.isHidden = true
            }
            
            if let ahead = metadata.aheadCount, ahead > 0 {
                aheadBadge.configure(text: "+\(ahead)", color: .systemGreen)
                aheadBadge.isHidden = false
            } else {
                aheadBadge.isHidden = true
            }
            
            if let behind = metadata.behindCount, behind > 0 {
                behindBadge.configure(text: "-\(behind)", color: .systemRed)
                behindBadge.isHidden = false
            } else {
                behindBadge.isHidden = true
            }
        } else {
            prBadge.isHidden = true
            aheadBadge.isHidden = true
            behindBadge.isHidden = true
        }

        setSelected(isSelected)
    }

    private func agentDotAppearance(for session: SessionGroup) -> (NSColor, String) {
        let tabsWithAgents = session.tabs.filter { $0.effectiveAgentKind != nil }
        guard !tabsWithAgents.isEmpty else {
            return (KouenDesign.chrome.idleStatus, "No agent")
        }
        if tabsWithAgents.contains(where: { $0.agent?.activity == .errored }) {
            return (.systemRed, "Agent errored")
        }
        if tabsWithAgents.contains(where: { $0.agent?.activity == .awaiting }) {
            return (.systemOrange, "Agent waiting for input")
        }
        if tabsWithAgents.contains(where: { $0.agent?.activity == .working }) {
            return (.systemGreen, "Agent active")
        }
        return (.systemYellow, "Agent idle")
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        onContextMenu?()
    }

    private func setSelected(_ selected: Bool) {
        isSelected = selected
        refresh()
    }

    private func refresh() {
        let c = KouenDesign.chrome
        titleLabel.font = .systemFont(ofSize: 12, weight: isSelected ? .semibold : .regular)
        closeButton.alphaValue = isHovered ? 1 : 0
        let closeColor = c.textSecondary
        closeButton.attributedTitle = NSAttributedString(
            string: "×",
            attributes: [
                .foregroundColor: closeColor,
                .font: NSFont.systemFont(ofSize: 16, weight: .regular),
            ]
        )
        if isSelected {
            let selectedFill = c.accent.withAlphaComponent(c.isDark ? 0.13 : 0.10)
            fill.layer?.backgroundColor = selectedFill.cgColor
            fill.layer?.borderColor = c.focusRing.withAlphaComponent(c.isDark ? 0.48 : 0.52).cgColor
            KouenDesign.applyShadow(.elevation1, to: fill.layer)
        } else if isHovered {
            fill.layer?.backgroundColor = c.rowHoverFill.cgColor
            fill.layer?.borderColor = NSColor.clear.cgColor
            KouenDesign.applyShadow(.none, to: fill.layer)
        } else {
            fill.layer?.backgroundColor = NSColor.clear.cgColor
            fill.layer?.borderColor = NSColor.clear.cgColor
            KouenDesign.applyShadow(.none, to: fill.layer)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        KouenMotion.animate(KouenDesign.Motion.microFast) { _ in
            self.refresh()
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        KouenMotion.animate(KouenDesign.Motion.microFast) { _ in
            self.refresh()
        }
    }
}

@MainActor
private final class SidebarBadgeView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = KouenDesign.Radius.badge
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        label.font = .monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 16),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(text: String, color: NSColor) {
        label.stringValue = text
        label.textColor = color
        layer?.backgroundColor = color.withAlphaComponent(0.16).cgColor
    }
}

@MainActor
final class SidebarTitlebarHeaderView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount >= 2,
           let controller = window?.windowController as? MainWindowController
        {
            controller.toggleVisibleFrameZoom(self)
            return
        }
        super.mouseUp(with: event)
    }
}

@MainActor
final class SessionWorktreeHeaderRowView: NSView {
    var onToggleCollapse: (() -> Void)?

    private let leftStack = NSStackView()
    private let disclosureImage = NSImageView()
    private let label = NSTextField(labelWithString: "WORKTREES")
    private let countLabel = NSTextField(labelWithString: "")
    private var isCollapsed = false
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        disclosureImage.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(KouenDesign.symbolConfig(pointSize: KouenDesign.IconSize.tiny, weight: .regular))
        disclosureImage.translatesAutoresizingMaskIntoConstraints = false
        disclosureImage.setContentHuggingPriority(.required, for: .horizontal)

        label.font = .systemFont(ofSize: 10.5, weight: .bold)
        label.alignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        countLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.setContentHuggingPriority(.required, for: .horizontal)

        leftStack.orientation = .horizontal
        leftStack.alignment = .centerY
        leftStack.spacing = 6
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        leftStack.addArrangedSubview(disclosureImage)
        leftStack.addArrangedSubview(label)
        leftStack.addArrangedSubview(countLabel)

        addSubview(leftStack)

        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KouenDesign.horizontalInset + 8),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            disclosureImage.widthAnchor.constraint(equalToConstant: 10),
            disclosureImage.heightAnchor.constraint(equalToConstant: 10),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        guard window != nil else { trackingArea = nil; return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refresh()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refresh()
    }

    override func mouseDown(with event: NSEvent) {
        onToggleCollapse?()
    }

    func configure(count: Int, isCollapsed: Bool) {
        self.isCollapsed = isCollapsed
        disclosureImage.image = NSImage(
            systemSymbolName: isCollapsed ? "chevron.right" : "chevron.down",
            accessibilityDescription: isCollapsed ? "Collapsed" : "Expanded"
        )?.withSymbolConfiguration(KouenDesign.symbolConfig(pointSize: KouenDesign.IconSize.tiny, weight: .regular))
        countLabel.stringValue = "\(count)"
        refresh()
    }

    private func refresh() {
        let c = KouenDesign.chrome
        label.textColor = isHovered ? c.textPrimary : c.textSecondary
        disclosureImage.contentTintColor = isHovered ? c.textPrimary : c.textSecondary
        countLabel.textColor = isHovered ? c.textSecondary : c.textTertiary
    }
}

@MainActor
final class SessionWorktreeRowView: NSView {
    var onSelect: (() -> Void)?

    private let fill = NSView()
    private let branchIcon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let prBadge = SidebarBadgeView()
    private let aheadBadge = SidebarBadgeView()
    private let behindBadge = SidebarBadgeView()
    private let badgeStack = NSStackView()
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        fill.wantsLayer = true
        fill.layer?.cornerRadius = KouenDesign.Radius.card
        fill.layer?.cornerCurve = .continuous
        fill.layer?.borderWidth = 1
        fill.layer?.borderColor = NSColor.clear.cgColor
        fill.translatesAutoresizingMaskIntoConstraints = false

        branchIcon.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?
            .withSymbolConfiguration(KouenDesign.symbolConfig(pointSize: 10, weight: .semibold))
        branchIcon.contentTintColor = KouenDesign.chrome.textTertiary
        branchIcon.translatesAutoresizingMaskIntoConstraints = false
        branchIcon.setContentHuggingPriority(.required, for: .horizontal)
        branchIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        prBadge.isHidden = true
        aheadBadge.isHidden = true
        behindBadge.isHidden = true

        badgeStack.orientation = .horizontal
        badgeStack.alignment = .centerY
        badgeStack.spacing = 4
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        badgeStack.addArrangedSubview(prBadge)
        badgeStack.addArrangedSubview(aheadBadge)
        badgeStack.addArrangedSubview(behindBadge)

        addSubview(fill)
        fill.addSubview(branchIcon)
        fill.addSubview(titleLabel)
        fill.addSubview(badgeStack)

        NSLayoutConstraint.activate([
            fill.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            fill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KouenDesign.horizontalInset + 12),
            fill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(KouenDesign.horizontalInset - 4)),

            branchIcon.leadingAnchor.constraint(equalTo: fill.leadingAnchor, constant: 8),
            branchIcon.centerYAnchor.constraint(equalTo: fill.centerYAnchor),
            branchIcon.widthAnchor.constraint(equalToConstant: 12),
            branchIcon.heightAnchor.constraint(equalToConstant: 12),

            titleLabel.leadingAnchor.constraint(equalTo: branchIcon.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: fill.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeStack.leadingAnchor, constant: -6),

            badgeStack.trailingAnchor.constraint(equalTo: fill.trailingAnchor, constant: -6),
            badgeStack.centerYAnchor.constraint(equalTo: fill.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        guard window != nil else { trackingArea = nil; return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    func configure(path: String, branch: String, metadata: RepoGitMetadata?) {
        titleLabel.stringValue = branch.isEmpty ? (path as NSString).lastPathComponent : branch
        toolTip = "Click to open session\n\(path)"
        
        let c = KouenDesign.chrome
        
        if let metadata {
            if let pr = metadata.prNumber {
                prBadge.configure(text: "#\(pr)", color: c.accent)
                prBadge.isHidden = false
            } else {
                prBadge.isHidden = true
            }
            
            if let ahead = metadata.aheadCount, ahead > 0 {
                aheadBadge.configure(text: "+\(ahead)", color: .systemGreen)
                aheadBadge.isHidden = false
            } else {
                aheadBadge.isHidden = true
            }
            
            if let behind = metadata.behindCount, behind > 0 {
                behindBadge.configure(text: "-\(behind)", color: .systemRed)
                behindBadge.isHidden = false
            } else {
                behindBadge.isHidden = true
            }
        } else {
            prBadge.isHidden = true
            aheadBadge.isHidden = true
            behindBadge.isHidden = true
        }
        
        refresh()
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }

    private func refresh() {
        let c = KouenDesign.chrome
        titleLabel.textColor = c.textSecondary
        branchIcon.contentTintColor = c.textTertiary
        
        if isHovered {
            fill.layer?.backgroundColor = c.rowHoverFill.cgColor
            fill.layer?.borderColor = NSColor.clear.cgColor
        } else {
            fill.layer?.backgroundColor = NSColor.clear.cgColor
            fill.layer?.borderColor = NSColor.clear.cgColor
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        KouenMotion.animate(KouenDesign.Motion.microFast) { _ in
            self.refresh()
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        KouenMotion.animate(KouenDesign.Motion.microFast) { _ in
            self.refresh()
        }
    }
}

@MainActor
final class SessionDividerRowView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let line = KouenDesign.divider()
        addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: KouenDesign.horizontalInset + 8),
            line.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(KouenDesign.horizontalInset - 4)),
            line.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
}
