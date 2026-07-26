import AppKit
import Foundation
import KouenCore
import KouenTerminalKit

/// Handles agent/notification delivery, dock badge, waiting rings, and inbox navigation.
@MainActor
final class NotificationCoordinator {
    private unowned let coord: SessionCoordinator
    private(set) var pushedNotificationKeys: Set<String> = []
    private var lastAgentActivity: [String: AgentActivity] = [:]
    private var lastStopNotifyAt: [String: Date] = [:]

    init(coordinator: SessionCoordinator) {
        self.coord = coordinator
    }

    // MARK: - Push notifications from snapshot

    func pushNewRemoteNotifications(from snapshot: SessionSnapshot) {
        for workspace in snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs where tab.status == .waiting {
                    guard let text = tab.notificationText, !text.isEmpty,
                          let surfaceID = tab.rootPane.allSurfaceIDs().first
                    else { continue }
                    let key = "\(surfaceID.uuidString)|\(text)"
                    guard !pushedNotificationKeys.contains(key) else { continue }
                    guard coord.settings.isEventEnabled(.agentWaiting) else { continue }
                    if NSApp.isActive, surfaceID == coord.activeSurfaceID { continue }
                    pushedNotificationKeys.insert(key)
                    let agentLabel = effectiveAgentKind(for: tab)?.displayName ?? "Kouen"
                    let title = "\(agentLabel) · \(tab.title.isEmpty ? "Terminal" : tab.title)"
                    deliverAgentAlert(event: .agentWaiting, title: title, body: text, surfaceID: surfaceID)
                }
            }
        }
        let live = Set(snapshot.workspaces.flatMap { ws in
            ws.sessions.flatMap { ses in
                ses.tabs.compactMap { tab -> String? in
                    guard tab.status == .waiting, let text = tab.notificationText, !text.isEmpty,
                          let surfaceID = tab.rootPane.allSurfaceIDs().first
                    else { return nil }
                    return "\(surfaceID.uuidString)|\(text)"
                }
            }
        })
        pushedNotificationKeys = pushedNotificationKeys.intersection(live)
    }

    func pushAgentActivityNotifications(from snapshot: SessionSnapshot) {
        var live: Set<String> = []
        for workspace in snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs {
                    guard let agent = tab.agent,
                          let surfaceID = tab.rootPane.allSurfaceIDs().first
                    else { continue }
                    let key = surfaceID.uuidString
                    live.insert(key)
                    let previous = lastAgentActivity[key]
                    lastAgentActivity[key] = agent.activity

                    // Broadcast any activity change to kouen.events + BoardViewController.
                    if previous != agent.activity {
                        NotificationBus.shared.postAgentStateChanged(
                            surfaceID: key, activity: agent.activity.rawValue
                        )
                    }

                    let stopped = previous == .working
                        && (agent.activity == .idle || agent.activity == .awaiting)
                    guard stopped else { continue }
                    if tab.status == .waiting { continue }
                    if NSApp.isActive, surfaceID == coord.activeSurfaceID { continue }
                    guard coord.settings.isEventEnabled(.agentFinished) else { continue }
                    if let last = lastStopNotifyAt[key], Date().timeIntervalSince(last) < 30 { continue }
                    lastStopNotifyAt[key] = Date()

                    let folder = KouenDesign.pathDisplayName(tab.cwd)
                    let title = "\(agent.kind.displayName) · \(folder)"
                    deliverAgentAlert(event: .agentFinished, title: title, body: "Finished — waiting for you", surfaceID: surfaceID)
                }
            }
        }
        lastAgentActivity = lastAgentActivity.filter { live.contains($0.key) }
        lastStopNotifyAt = lastStopNotifyAt.filter { live.contains($0.key) }
    }

    func deliverAgentAlert(event: NotificationEvent, title: String, body: String, surfaceID: SurfaceID? = nil) {
        guard coord.settings.isEventEnabled(event) else { return }
        let wantBanner = coord.settings.systemNotificationsEnabled
        let wantChime = coord.settings.notificationSoundEnabled
        guard wantBanner || wantChime else { return }
        // Played manually, independent of banner delivery — DesktopNotifier.show is always
        // called with withSound: false so the OS never also auto-sounds the banner (that'd
        // double-ding). This is what makes distinct per-event sounds possible: the banner
        // API only ever offers "default sound or none," never a per-event named sound.
        if wantChime {
            NSSound(named: event.soundName)?.play()
        }
        if wantBanner {
            DesktopNotifier.show(title: title, body: body, withSound: false, surfaceID: surfaceID?.uuidString)
        }
    }

    func updateDockBadge(from snapshot: SessionSnapshot) {
        guard let app = NSApplication.shared as AnyObject? as? NSApplication else { return }
        let waiting = snapshot.workspaces.reduce(into: 0) { count, workspace in
            count += workspace.sessions
                .flatMap(\.tabs)
                .filter { $0.status == .waiting }
                .count
        }
        app.dockTile.badgeLabel = waiting > 0 ? "\(waiting)" : nil
    }

    func syncWaitingRings() {
        for host in coord.terminalHosts.allHosts() {
            host.isWaiting = coord.isSurfaceWaiting(host.surfaceID)
        }
    }

    // MARK: - Notification list and navigation

    func notificationsList() -> [NotificationEntry] {
        var entries: [NotificationEntry] = []
        for workspace in coord.snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs where tab.status == .waiting {
                    guard let surfaceID = tab.rootPane.allSurfaceIDs().first else { continue }
                    entries.append(NotificationEntry(
                        workspaceID: workspace.id,
                        workspaceName: workspace.name,
                        sessionID: session.id,
                        tabID: tab.id,
                        tabTitle: tab.title.isEmpty ? (session.name.isEmpty ? "Terminal" : session.name) : tab.title,
                        surfaceID: surfaceID,
                        agentKind: effectiveAgentKind(for: tab),
                        body: tab.notificationText ?? "Needs attention"
                    ))
                }
            }
        }
        return entries
    }

    func agentsList() -> [AgentSessionSummary] {
        SessionEditor(snapshot: coord.snapshot).listAgents()
            .sorted { lhs, rhs in
                if lhs.waiting != rhs.waiting { return lhs.waiting }
                return lhs.lastActivityAt > rhs.lastActivityAt
            }
    }

    func openAgent(_ agent: AgentSessionSummary) {
        guard let workspace = coord.snapshot.workspaces.first(where: { ws in
            ws.sessions.contains { $0.id == agent.sessionID }
        }) else { return }
        coord.selectWorkspace(workspace.id)
        coord.selectTab(workspaceID: workspace.id, tabID: agent.tabID)
    }

    func openNotification(_ entry: NotificationEntry) {
        coord.selectWorkspace(entry.workspaceID)
        coord.selectTab(workspaceID: entry.workspaceID, tabID: entry.tabID)
        coord.terminalHosts.host(for: entry.surfaceID)?.focusTerminal()
        clearNotification(surfaceID: entry.surfaceID)
    }

    func clearNotification(surfaceID: SurfaceID) {
        coord.requestDaemon(.clearNotification(surfaceID: surfaceID.uuidString))
        coord.syncFromDaemon()
    }

    func clearAllNotifications() {
        for entry in notificationsList() {
            coord.requestDaemon(.clearNotification(surfaceID: entry.surfaceID.uuidString))
        }
        coord.syncFromDaemon()
    }

    func jumpToLatestNotification() {
        guard let waiting = firstWaitingTab() else { return }
        coord.selectWorkspace(waiting.workspaceID)
        coord.selectTab(workspaceID: waiting.workspaceID, tabID: waiting.tabID)
        if let surfaceID = coord.splitPaneCoordinator.firstSurfaceID(forTab: waiting.tabID) {
            coord.setActiveSurface(surfaceID)
            coord.terminalHosts.host(for: surfaceID)?.focusTerminal()
        }
    }

    func isSurfaceWaiting(_ surfaceID: UUID) -> Bool {
        for workspace in coord.snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs where tab.status == .waiting {
                    if tab.rootPane.allSurfaceIDs().contains(surfaceID) {
                        return true
                    }
                }
            }
        }
        return false
    }

    func handleNotification(for surfaceID: SurfaceID, event: NotificationEvent, title: String, body: String) {
        let key = "\(canonicalNotificationSurface(for: surfaceID).uuidString)|\(body)"
        guard !pushedNotificationKeys.contains(key) else { return }
        coord.requestDaemon(.notify(
            surfaceID: surfaceID.uuidString,
            title: title,
            body: body
        ))
        pushedNotificationKeys.insert(key)
        if NSApp.isActive == false {
            deliverAgentAlert(event: event, title: title, body: body, surfaceID: surfaceID)
        }
        coord.syncFromDaemon()
    }

    /// Routes a clicked macOS notification to the same place as clicking its notch/inbox entry:
    /// select the owning workspace + tab, focus the pane, clear the waiting state.
    func openSurface(_ surfaceID: SurfaceID) {
        guard let tabID = coord.activePaneService.tabID(forSurface: surfaceID) else { return }
        guard let workspace = coord.snapshot.workspaces.first(where: { ws in
            ws.sessions.contains { session in session.tabs.contains { $0.id == tabID } }
        }) else { return }
        coord.selectWorkspace(workspace.id)
        coord.selectTab(workspaceID: workspace.id, tabID: tabID)
        coord.setActiveSurface(surfaceID)
        coord.terminalHosts.host(for: surfaceID)?.focusTerminal()
        clearNotification(surfaceID: surfaceID)
    }

    /// Copies the latest command output (or visible lines fallback) for a surface to the pasteboard.
    func copyOutput(for surfaceID: SurfaceID) {
        guard let host = coord.terminalHosts.host(for: surfaceID) else { return }
        let surfaceView = host.surfaceView
        let textToCopy: String
        if let lastBlock = surfaceView.blocks.last(where: { $0.outputEndLine != nil }),
           let end = lastBlock.outputEndLine {
            textToCopy = surfaceView.text(fromLine: lastBlock.outputStartLine, toLine: end)
        } else if let lastBlock = surfaceView.blocks.last, let end = lastBlock.outputEndLine {
            textToCopy = surfaceView.text(fromLine: lastBlock.outputStartLine, toLine: end)
        } else {
            textToCopy = host.captureVisibleLines(maxLines: 200)
        }
        guard !textToCopy.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToCopy, forType: .string)
    }

    /// Resends the last recorded command for a surface back to the PTY via daemon input IPC.
    func rerunCommand(for surfaceID: SurfaceID) {
        guard let host = coord.terminalHosts.host(for: surfaceID) else { return }
        if let lastCommand = host.surfaceView.blocks.last?.command, !lastCommand.isEmpty {
            coord.requestDaemon(.send(surfaceID: surfaceID.uuidString, text: lastCommand + "\n"))
        }
    }

    // MARK: - Private helpers

    private func firstWaitingTab() -> (workspaceID: WorkspaceID, tabID: TabID)? {
        for workspace in coord.snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs {
                    let isWaiting = tab.status == .waiting
                    let agentBlocked = tab.agent?.activity == .awaiting
                    let agentBusy = tab.agent?.activity == .working
                    if (isWaiting && !agentBusy) || agentBlocked {
                        return (workspace.id, tab.id)
                    }
                }
            }
        }
        for workspace in coord.snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs where tab.status == .waiting {
                    return (workspace.id, tab.id)
                }
            }
        }
        return nil
    }

    private func canonicalNotificationSurface(for surfaceID: SurfaceID) -> SurfaceID {
        for workspace in coord.snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs where tab.rootPane.allSurfaceIDs().contains(surfaceID) {
                    return tab.rootPane.allSurfaceIDs().first ?? surfaceID
                }
            }
        }
        return surfaceID
    }

    private func effectiveAgentKind(for tab: Tab) -> AgentKind? {
        tab.effectiveAgentKind
    }
}
