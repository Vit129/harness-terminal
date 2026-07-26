import AppKit
import KouenCore

/// Popover-style panel that the notification bell shows. Lists every tab in
/// `.waiting` state with its agent and a short body; clicking a row (or
/// arrow-keying to it and pressing Return) jumps to that pane and clears the
/// notification. `Escape` dismisses without selecting.
@MainActor
final class NotificationDropdownPanelView: NSView {
    private let entries: [NotificationEntry]
    private let onSelect: (NotificationEntry) -> Void
    private let onClearAll: () -> Void
    private let onDismiss: () -> Void
    let preferredHeight: CGFloat

    private var rows: [NotificationRowView] = []
    private var scrollView: NSScrollView?
    private var highlightedIndex: Int?

    init(
        entries: [NotificationEntry],
        onSelect: @escaping (NotificationEntry) -> Void,
        onClearAll: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.entries = entries
        self.onSelect = onSelect
        self.onClearAll = onClearAll
        self.onDismiss = onDismiss
        // Header (28) + rows (52 each, max 6 shown then scrolls) + footer (38).
        let visibleRowCount = min(entries.count, 6)
        let bodyHeight = entries.isEmpty ? 64 : CGFloat(visibleRowCount * 52 + 10)
        self.preferredHeight = 28 + bodyHeight + 38
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = KouenDesign.Radius.overlay
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = false
        let c = KouenDesign.chrome
        layer?.backgroundColor = (c.terminalBackground.blended(withFraction: c.isDark ? 0.06 : 0.04, of: c.textPrimary) ?? c.sidebarBackground).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = c.textPrimary.withAlphaComponent(c.isDark ? 0.11 : 0.14).cgColor
        KouenDesign.applyShadow(.overlay, to: layer)

        setupContent()
        if !entries.isEmpty {
            highlightedIndex = 0
            updateHighlight()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

#if compiler(>=6.4)
    @available(macOS 27.0, *)
    override var cornerConfiguration: NSViewCornerConfiguration? {
        .corners(radius: .containerConcentric)
    }
#endif

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: // Down arrow
            move(by: 1)
        case 126: // Up arrow
            move(by: -1)
        case 36, 76: // Return / keypad Enter
            if let index = highlightedIndex {
                onSelect(entries[index])
            }
        case 53: // Escape
            onDismiss()
        default:
            super.keyDown(with: event)
        }
    }

    private func move(by delta: Int) {
        guard !rows.isEmpty else { return }
        let current = highlightedIndex ?? (delta > 0 ? -1 : rows.count)
        let next = (current + delta + rows.count) % rows.count
        highlightedIndex = next
        updateHighlight()
    }

    private func updateHighlight() {
        for (index, row) in rows.enumerated() {
            row.isHighlighted = index == highlightedIndex
        }
        if let index = highlightedIndex {
            rows[index].scrollToVisible(rows[index].bounds)
        }
    }

    private func setupContent() {
        let header = NSTextField(labelWithString: "Notifications")
        header.font = .systemFont(ofSize: 11, weight: .semibold)
        header.textColor = KouenDesign.chrome.textTertiary
        header.translatesAutoresizingMaskIntoConstraints = false

        let bodyContainer = NSView()
        bodyContainer.translatesAutoresizingMaskIntoConstraints = false

        if entries.isEmpty {
            let empty = NSTextField(labelWithString: "You're all caught up.")
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = KouenDesign.chrome.textSecondary
            empty.translatesAutoresizingMaskIntoConstraints = false
            bodyContainer.addSubview(empty)
            NSLayoutConstraint.activate([
                empty.centerXAnchor.constraint(equalTo: bodyContainer.centerXAnchor),
                empty.centerYAnchor.constraint(equalTo: bodyContainer.centerYAnchor),
            ])
        } else {
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .width
            stack.spacing = 2
            stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
            stack.translatesAutoresizingMaskIntoConstraints = false
            for entry in entries {
                let row = NotificationRowView(entry: entry)
                row.onClick = { [onSelect] in
                    onSelect(entry)
                }
                stack.addArrangedSubview(row)
                rows.append(row)
            }
            let scroll = NSScrollView()
            scroll.drawsBackground = false
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = true
            scroll.scrollerStyle = .overlay
            scroll.documentView = stack
            scroll.translatesAutoresizingMaskIntoConstraints = false
            bodyContainer.addSubview(scroll)
            scrollView = scroll
            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: bodyContainer.topAnchor),
                scroll.leadingAnchor.constraint(equalTo: bodyContainer.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: bodyContainer.trailingAnchor),
                scroll.bottomAnchor.constraint(equalTo: bodyContainer.bottomAnchor),
                stack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            ])
        }

        let footer = NSView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        let clearAll = NSButton(title: "Clear all", target: self, action: #selector(clearAllClicked))
        clearAll.bezelStyle = .accessoryBarAction
        clearAll.isBordered = false
        clearAll.contentTintColor = KouenDesign.chrome.textSecondary
        clearAll.font = .systemFont(ofSize: 11.5, weight: .medium)
        clearAll.isEnabled = !entries.isEmpty
        clearAll.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(clearAll)

        addSubview(header)
        addSubview(bodyContainer)
        addSubview(footer)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            header.heightAnchor.constraint(equalToConstant: 20),

            bodyContainer.topAnchor.constraint(equalTo: header.bottomAnchor),
            bodyContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            bodyContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            bodyContainer.bottomAnchor.constraint(equalTo: footer.topAnchor),

            footer.leadingAnchor.constraint(equalTo: leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 32),
            clearAll.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -10),
            clearAll.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])
    }

    @objc private func clearAllClicked() {
        onClearAll()
    }
}

@MainActor
private final class NotificationRowView: NSView {
    var onClick: (() -> Void)?

    private let entry: NotificationEntry
    private var trackingArea: NSTrackingArea?
    private var isHovered = false { didSet { applyChrome() } }
    var isHighlighted = false { didSet { applyChrome() } }

    init(entry: NotificationEntry) {
        self.entry = entry
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 50).isActive = true

        let coordinator = SessionCoordinator.shared

        let dot = StatusDotView()
        if let kind = entry.agentKind {
            dot.style = .agent(hex: coordinator.settings.agentColorHex(for: kind))
        } else {
            // Theme accent rather than the hardcoded `.waiting` blue, so the dot fits the theme.
            dot.style = .accent
        }
        dot.applyStyle()
        dot.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: entry.tabTitle)
        title.font = .systemFont(ofSize: 12.5, weight: .semibold)
        title.textColor = KouenDesign.chrome.textPrimary
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false

        let agentLabel = entry.agentKind?.displayName ?? "Agent"
        let bodyLabel = NSTextField(labelWithString: "\(agentLabel) · \(entry.body)")
        bodyLabel.font = .systemFont(ofSize: 11)
        bodyLabel.textColor = KouenDesign.chrome.textTertiary
        bodyLabel.lineBreakMode = .byTruncatingTail
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [title, bodyLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(dot)
        addSubview(textStack)
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        applyChrome()
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

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) { onClick?() }
    }

    private func applyChrome() {
        let c = KouenDesign.chrome
        layer?.backgroundColor = (isHovered || isHighlighted)
            ? c.textPrimary.withAlphaComponent(0.06).cgColor
            : NSColor.clear.cgColor
    }
}
