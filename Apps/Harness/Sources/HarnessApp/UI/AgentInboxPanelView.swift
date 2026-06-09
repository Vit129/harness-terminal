import AppKit
import HarnessCore

/// Popover-style panel listing **every running agent** (not just the ones that
/// have pinged you), waiting agents first. Clicking a row jumps to that agent's
/// pane. A minimal read-only "Agent Inbox" built on the same row/panel idiom as
/// `NotificationDropdownPanelView`, fed by `SessionCoordinator.agentsList()`.
///
/// Distinct from the notification bell + dropdown, which only surfaces tabs in
/// `.waiting` state and clears the alert on open; this inbox is a passive roster
/// and never clears notifications.
@MainActor
final class AgentInboxPanelView: NSView {
    private let agents: [AgentSessionSummary]
    private let onSelect: (AgentSessionSummary) -> Void
    let preferredHeight: CGFloat

    init(
        agents: [AgentSessionSummary],
        onSelect: @escaping (AgentSessionSummary) -> Void
    ) {
        self.agents = agents
        self.onSelect = onSelect
        // Header (28) + rows (52 each, max 6 shown then scrolls) + a slim footer (12).
        let visibleRowCount = min(agents.count, 6)
        let bodyHeight = agents.isEmpty ? 64 : CGFloat(visibleRowCount * 52 + 10)
        self.preferredHeight = 28 + bodyHeight + 12
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = HarnessDesign.Radius.overlay
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = false
        let c = HarnessDesign.chrome
        layer?.backgroundColor = (c.terminalBackground.blended(withFraction: c.isDark ? 0.06 : 0.04, of: c.textPrimary) ?? c.sidebarBackground).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = c.textPrimary.withAlphaComponent(c.isDark ? 0.11 : 0.14).cgColor
        HarnessDesign.applyShadow(.overlay, to: layer)

        setupContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupContent() {
        let header = NSTextField(labelWithString: "Agents")
        header.font = .systemFont(ofSize: 11, weight: .semibold)
        header.textColor = HarnessDesign.chrome.textTertiary
        header.translatesAutoresizingMaskIntoConstraints = false

        let bodyContainer = NSView()
        bodyContainer.translatesAutoresizingMaskIntoConstraints = false

        if agents.isEmpty {
            let empty = NSTextField(labelWithString: "No agents running.")
            empty.font = .systemFont(ofSize: 12)
            empty.textColor = HarnessDesign.chrome.textSecondary
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
            for agent in agents {
                let row = AgentInboxRowView(agent: agent)
                row.onClick = { [onSelect] in
                    onSelect(agent)
                }
                stack.addArrangedSubview(row)
            }
            let scroll = NSScrollView()
            scroll.drawsBackground = false
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = true
            scroll.scrollerStyle = .overlay
            scroll.documentView = stack
            scroll.translatesAutoresizingMaskIntoConstraints = false
            bodyContainer.addSubview(scroll)
            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: bodyContainer.topAnchor),
                scroll.leadingAnchor.constraint(equalTo: bodyContainer.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: bodyContainer.trailingAnchor),
                scroll.bottomAnchor.constraint(equalTo: bodyContainer.bottomAnchor),
                stack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            ])
        }

        addSubview(header)
        addSubview(bodyContainer)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            header.heightAnchor.constraint(equalToConstant: 20),

            bodyContainer.topAnchor.constraint(equalTo: header.bottomAnchor),
            bodyContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            bodyContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            bodyContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }
}

@MainActor
private final class AgentInboxRowView: NSView {
    var onClick: (() -> Void)?

    private let agent: AgentSessionSummary
    private var trackingArea: NSTrackingArea?
    private var isHovered = false { didSet { applyChrome() } }

    init(agent: AgentSessionSummary) {
        self.agent = agent
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 50).isActive = true

        let coordinator = SessionCoordinator.shared

        let dot = StatusDotView()
        if agent.waiting {
            dot.style = .waiting
        } else {
            dot.style = .agent(hex: coordinator.settings.agentColorHex(for: agent.kind))
        }
        dot.applyStyle()
        dot.translatesAutoresizingMaskIntoConstraints = false

        // Title: agent name ("Claude Code", "Kiro", …)
        let title = NSTextField(labelWithString: agent.agentName)
        title.font = .systemFont(ofSize: 12.5, weight: .semibold)
        title.textColor = HarnessDesign.chrome.textPrimary
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false

        // Body: "project (branch) · tab-title · workspace"
        let bodyLabel = NSTextField(labelWithString: agentDetail(agent))
        bodyLabel.font = .systemFont(ofSize: 11)
        bodyLabel.textColor = HarnessDesign.chrome.textTertiary
        bodyLabel.lineBreakMode = .byTruncatingTail
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        // Trailing time ("now", "2m", …)
        let timeLabel = NSTextField(labelWithString: AgentListFormatter.age(from: agent.lastActivityAt))
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)
        timeLabel.textColor = HarnessDesign.chrome.textTertiary
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [title, bodyLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(dot)
        addSubview(textStack)
        addSubview(timeLabel)
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),

            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        applyChrome()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
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
        let c = HarnessDesign.chrome
        layer?.backgroundColor = isHovered
            ? c.textPrimary.withAlphaComponent(0.06).cgColor
            : NSColor.clear.cgColor
    }
}

/// Mirrors `AgentNotchProjection.agentDetail`: `project (branch) · tab-title · workspace`.
private func agentDetail(_ agent: AgentSessionSummary) -> String {
    var parts: [String] = []
    let path = (agent.cwd as NSString).lastPathComponent
    if !path.isEmpty {
        parts.append(agent.gitBranch.map { "\(path) (\($0))" } ?? path)
    }
    if !agent.tabTitle.isEmpty, agent.tabTitle != agent.agentName, agent.tabTitle != path {
        parts.append(agent.tabTitle)
    }
    parts.append(agent.workspaceName)
    if !agent.sessionName.isEmpty, agent.sessionName != path {
        parts.append(agent.sessionName)
    }
    return parts.joined(separator: " · ")
}
