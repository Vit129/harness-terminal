import AppKit
import KouenCore

/// macOS menu-bar status item: the Kouen mark, whose menu lists active agent
/// sessions and your sessions. All state comes from the daemon-backed snapshot
/// (`SessionCoordinator`), which owns session truth independently of the user's
/// shell — so the menu works identically for zsh, fish, bash, etc.
///
/// Owned by the `AppDelegate` for the app lifetime. The menu is rebuilt on each open
/// (`menuNeedsUpdate`) so it always reflects live state.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = Self.markImage(pointSize: 17)
            button.imagePosition = .imageOnly
            button.toolTip = "Kouen — sessions & agents"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        let coordinator = SessionCoordinator.shared
        // Pull the latest daemon truth so the menu is correct even if the app was idle.
        coordinator.syncFromDaemon(metadataOnly: true)
        rebuild(menu, snapshot: coordinator.snapshot)
    }

    private func rebuild(_ menu: NSMenu, snapshot: SessionSnapshot) {
        menu.removeAllItems()

        addHeader("Sessions", to: menu)
        let rows = sessionRows(snapshot)
        if rows.isEmpty {
            let empty = NSMenuItem(title: "No sessions", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for row in rows { menu.addItem(sessionItem(row)) }
        }

        menu.addItem(.separator())
        let openNotch = NSMenuItem(title: "Open Notch HUD", action: #selector(openNotchHUD), keyEquivalent: "")
        openNotch.target = self
        menu.addItem(openNotch)
        let closeNotch = NSMenuItem(title: "Close Notch HUD", action: #selector(closeNotchHUD), keyEquivalent: "")
        closeNotch.target = self
        menu.addItem(closeNotch)
        let notchSettings = NSMenuItem(title: "Notch HUD Settings…", action: #selector(openNotchSettings), keyEquivalent: "")
        notchSettings.target = self
        menu.addItem(notchSettings)

        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open Kouen", action: #selector(openKouen), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
    }

    // MARK: - Item builders

    private func addHeader(_ text: String, to menu: NSMenu) {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(string: text.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.tertiaryLabelColor,
            .kern: 0.6,
        ])
        menu.addItem(item)
    }

    private func sessionItem(_ row: SessionRow) -> NSMenuItem {
        let workspace = row.workspace
        let session = row.session
        let item = NSMenuItem(title: session.name, action: #selector(activate(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = MenuRef(workspace.id, session.id)
        item.state = workspace.activeSessionID == session.id ? .on : .off

        let name = session.name.isEmpty ? sessionFolder(session) : session.name
        let title = NSMutableAttributedString(string: name, attributes: [
            .font: NSFont.systemFont(ofSize: 12.5, weight: row.agentKind != nil ? .medium : .regular),
            .foregroundColor: NSColor.labelColor,
        ])
        let detail = sessionDetail(session)
        if !detail.isEmpty {
            title.append(NSAttributedString(string: "   \(detail)", attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor,
            ]))
        }
        item.attributedTitle = title

        if let kind = row.agentKind {
            let tint = NSColor.fromHex(SessionCoordinator.shared.settings.agentColorHex(for: kind)) ?? .secondaryLabelColor
            item.image = AgentIconRenderer.coloredOrMonogramImage(for: kind, size: 14, color: tint)
        }
        if let activity = row.activity, let badge = stateLabel(activity) {
            item.badge = NSMenuItemBadge(string: badge)
        }
        return item
    }

    // MARK: - Data

    private struct SessionRow {
        let workspace: Workspace
        let session: SessionGroup
        let agentKind: AgentKind?
        let activity: AgentActivity?
    }

    /// One row per session, carrying its highest-attention agent state (if any tab has a
    /// detected agent). Sorted so sessions needing input (awaiting/errored) sit on top.
    private func sessionRows(_ snapshot: SessionSnapshot) -> [SessionRow] {
        var rows: [SessionRow] = []
        for workspace in snapshot.workspaces {
            for session in workspace.sessions {
                var best: (AgentKind, AgentActivity)?
                for tab in session.tabs {
                    guard let kind = tab.effectiveAgentKind else { continue }
                    let activity = tab.agent?.activity ?? (tab.status == .waiting ? .awaiting : .idle)
                    if best == nil || rank(activity) > rank(best!.1) { best = (kind, activity) }
                }
                rows.append(SessionRow(workspace: workspace, session: session, agentKind: best?.0, activity: best?.1))
            }
        }
        return rows.sorted { rank($0.activity) > rank($1.activity) }
    }

    private func rank(_ activity: AgentActivity?) -> Int {
        switch activity {
        case .awaiting: return 3
        case .errored: return 2
        case .working: return 1
        case .idle: return 0
        case nil: return -1
        }
    }

    private func stateLabel(_ activity: AgentActivity) -> String? {
        switch activity {
        case .awaiting: return "Awaiting"
        case .errored: return "Error"
        case .working: return "Working"
        case .idle: return nil
        }
    }

    private func sessionFolder(_ session: SessionGroup) -> String {
        guard let tab = session.activeTab ?? session.tabs.first else { return "Session" }
        let name = KouenDesign.pathDisplayName(tab.cwd)
        return name.isEmpty ? "Session" : name
    }

    private func sessionDetail(_ session: SessionGroup) -> String {
        guard let tab = session.activeTab ?? session.tabs.first else { return "" }
        var parts: [String] = []
        if session.tabs.count > 1 { parts.append("\(session.tabs.count) tabs") }
        let folder = KouenDesign.shortenPath(tab.cwd)
        if !folder.isEmpty { parts.append(folder) }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: - Actions

    /// `representedObject` payload: a workspace, optionally narrowed to one session.
    private final class MenuRef {
        let workspace: WorkspaceID
        let session: SessionID?
        init(_ workspace: WorkspaceID, _ session: SessionID? = nil) {
            self.workspace = workspace
            self.session = session
        }
    }

    @objc private func activate(_ sender: NSMenuItem) {
        guard let ref = sender.representedObject as? MenuRef else { return }
        if let session = ref.session {
            SessionCoordinator.shared.selectSession(workspaceID: ref.workspace, sessionID: session)
        } else {
            SessionCoordinator.shared.selectWorkspace(ref.workspace)
        }
        bringToFront()
    }

    @objc private func openKouen() { bringToFront() }

    @objc private func openNotchHUD() {
        NotchPanelController.shared.openFromMenu()
    }

    @objc private func closeNotchHUD() {
        NotchPanelController.shared.closeFromMenu()
    }

    @objc private func openNotchSettings() {
        SettingsWindowController.show()
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    // MARK: - Status-item mark (a minimal "K" glyph, as a template)

    /// A simplified Kouen "K" monogram, drawn as strokes so it stays legible at
    /// menu-bar size — the full tree/leaves brand mark (`KouenLogo.png`) turns
    /// into an illegible blob once scaled down to ~17pt.
    static func markImage(pointSize: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let viewBox: CGFloat = 100
            let scale = min(rect.width, rect.height) / viewBox
            var transform = CGAffineTransform(
                translationX: rect.minX + (rect.width - viewBox * scale) / 2,
                y: rect.minY + (rect.height - viewBox * scale) / 2
            ).scaledBy(x: scale, y: scale)

            let path = CGMutablePath()
            path.move(to: CGPoint(x: 26, y: 15))
            path.addLine(to: CGPoint(x: 26, y: 85))
            path.move(to: CGPoint(x: 26, y: 50))
            path.addLine(to: CGPoint(x: 78, y: 85))
            path.move(to: CGPoint(x: 26, y: 50))
            path.addLine(to: CGPoint(x: 78, y: 15))

            guard let scaled = path.copy(using: &transform) else { return false }
            ctx.addPath(scaled)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(16 * scale)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }
}
