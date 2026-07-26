import AppKit
import Foundation
import KouenCore
import KouenTerminalEngine
import KouenTerminalKit
import KouenTheme
import UserNotifications

@MainActor
final class SessionCoordinator: NSObject {
    static let shared = SessionCoordinator()

    // MARK: - Services

    private(set) lazy var daemonSyncService: DaemonSyncService = DaemonSyncService(coordinator: self)
    private(set) lazy var splitPaneCoordinator: SplitPaneCoordinator = SplitPaneCoordinator(coordinator: self)
    private(set) lazy var sessionLifecycleService: SessionLifecycleService = SessionLifecycleService(coordinator: self)
    private(set) lazy var notificationCoordinator: NotificationCoordinator = NotificationCoordinator(coordinator: self)
    private(set) lazy var themeService: ThemeService = ThemeService(coordinator: self)
    private(set) lazy var activePaneService: ActivePaneService = ActivePaneService(coordinator: self)

    // MARK: - State

    var snapshot: SessionSnapshot { daemonSyncService.snapshot }
    var settings = KouenSettings.load()
    private(set) var activeEndpoint: Endpoint = .localControlSocket
    var activeSurfaceID: SurfaceID?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    var lastActiveSurfaceID: SurfaceID?
    var suppressActivePaneSync = false
    var structureRevision = 0
    var appliedThemeKey = ""
    var surfaceIndex: [SurfaceID: (tab: Tab, tabID: TabID)] = [:]
    var lastClosedTab: (cwd: String, title: String)?
    let terminalHosts = TerminalPaneRegistry()
    /// One inline AI completion controller per terminal pane — keyed by surface UUID string.
    private var inlineAIControllers: [String: InlineAICompletionController] = [:]
    private var lastDaemonErrorNotice: Date?
    private let snapshotCoalescer = SnapshotCoalescer()

    var activeTabCWD: String? {
        guard let cwd = snapshot.activeWorkspace?.activeTab?.cwd, !cwd.isEmpty else { return nil }
        return cwd
    }

    private override init() {
        super.init()
        // Drop the per-surface AI controllers when their host is retired.
        terminalHosts.onRetire = { [weak self] surfaceID in
            self?.inlineAIControllers.removeValue(forKey: surfaceID.uuidString)
            SecureInputMonitor.shared.release(surfaceID)
            ActivityAssertionManager.shared.releaseAssertions(forSurface: surfaceID)
            if self?.runSurfaceID == surfaceID { self?.runSurfaceID = nil }
        }
        // Update the floating queue bar whenever a surface's queue changes.
        PromptQueue.shared.onQueueChanged = { [weak self] surfaceID in
            guard let self, surfaceID == self.activeSurfaceID else { return }
            PromptQueueBar.shared.update(
                count: PromptQueue.shared.count(for: surfaceID),
                anchoredTo: NSApp.mainWindow)
        }
        observeNotifications()
        _ = daemonSyncService; _ = notificationCoordinator
        _ = splitPaneCoordinator; _ = sessionLifecycleService
        _ = themeService; _ = activePaneService
        daemonSyncService.startMetadataRefresh()
        startMemoryPressureMonitor()
    }

    private func startMemoryPressureMonitor() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let isCritical = source.data.contains(.critical)
                // Inactive sessions: trim to 1 000 lines (warning) or 0 (critical).
                // Focused session: spared on warning, trimmed to 1 000 on critical.
                let inactiveLimit = isCritical ? 0 : 1_000
                let focusedLimit  = isCritical ? 1_000 : Int.max
                let focused = self.activeSurfaceID
                for host in self.terminalHosts.allHosts() {
                    let limit = host.surfaceID == focused ? focusedLimit : inactiveLimit
                    if limit < self.settings.scrollbackLines {
                        host.surfaceView.trimScrollback(to: limit)
                    }
                }
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(snapshotChangedNotification(_:)),
            name: NotificationBus.shared.snapshotChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationPosted(_:)),
            name: NotificationBus.shared.notificationPosted, object: nil)
    }

    @objc private func snapshotChangedNotification(_ note: Notification) {
        let revision = note.snapshotPayload.revision
        guard revision != daemonSyncService.lastRevision,
              revision != daemonSyncService.pendingSnapshotRevision else { return }
        daemonSyncService.pendingSnapshotRevision = revision
        // Coalesce burst pings (rapid cwd timer / agent scanner commits) into one sync per
        // runloop turn. pendingSnapshotRevision is already updated above; the flushed action
        // always reads the latest value so no revision is silently dropped.
        snapshotCoalescer.signal { [weak self] in
            self?.daemonSyncService.scheduleSnapshotRefresh()
        }
    }

    @objc private func notificationPosted(_ note: Notification) {
        guard note.userInfo?["notification"] is AgentNotification else { return }
        NotificationCenter.default.post(name: NotificationBus.shared.tabStatusChanged, object: nil)
    }

    // MARK: - Remote daemon

    /// Guard against concurrent SSH spawns — only one connect can be in-flight at a time.
    private var isConnectingRemote = false

    func connectToRemote(named name: String) {
        guard !isConnectingRemote else { return }
        isConnectingRemote = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var resolved: Endpoint?; var failureMessage: String?
            do { resolved = try RemoteHostsService.shared.connect(named: name) }
            catch { failureMessage = "\(error)" }
            let endpoint = resolved; let message = failureMessage
            Task { @MainActor in
                guard let self else { return }
                self.isConnectingRemote = false
                if let endpoint { self.applyEndpointSwitch(endpoint) }
                else {
                    self.noteDaemonError(DaemonSessionError.daemonError(message ?? "connection failed"))
                    NotificationCenter.default.post(
                        name: RemoteHostsService.connectionDidFail,
                        object: nil,
                        userInfo: ["error": message ?? "connection failed"]
                    )
                }
            }
        }
    }

    func disconnectRemote() {
        RemoteHostsService.shared.disconnect()
        applyEndpointSwitch(.localControlSocket)
    }

    func applyEndpointSwitch(_ endpoint: Endpoint) {
        activeEndpoint = endpoint
        daemonSyncService.switchEndpoint(endpoint)
        terminalHosts.prune(keeping: [])
        _ = syncFromDaemon()
    }

    // MARK: - Sync (facade → DaemonSyncService)

    @discardableResult func syncFromDaemon(metadataOnly: Bool = false) -> Bool {
        daemonSyncService.sync(metadataOnly: metadataOnly)
    }
    @discardableResult func syncFromDaemon(metadataOnly: Bool = false) async -> Bool {
        await daemonSyncService.sync(metadataOnly: metadataOnly)
    }
    func closeEphemeralSessionsBeforeQuit() { daemonSyncService.closeEphemeralSessionsBeforeQuit() }
    func saveImmediately() { syncFromDaemon() }

    @discardableResult func requestDaemon(_ request: IPCRequest) -> IPCResponse? {
        daemonSyncService.request(request)
    }
    @discardableResult func requestDaemon(_ request: IPCRequest) async -> IPCResponse? {
        await daemonSyncService.request(request)
    }

    func noteDaemonError(_ error: Error) {
        let now = Date()
        if let last = lastDaemonErrorNotice, now.timeIntervalSince(last) < 8 { return }
        lastDaemonErrorNotice = now
        guard let host = (NSApp.keyWindow ?? NSApp.mainWindow)?.contentView else { return }
        Toast.show("Reconnecting to KouenDaemon…", in: host)
    }

    // MARK: - Session lifecycle (facade → SessionLifecycleService)

    func addWorkspace(name: String) { sessionLifecycleService.addWorkspace(name: name) }
    func addSession(
        to workspaceID: WorkspaceID,
        cwd: String? = nil,
        name: String? = nil,
        worktreePath: String? = nil,
        parentRepoPath: String? = nil,
        taskName: String? = nil
    ) {
        sessionLifecycleService.addSession(
            to: workspaceID,
            cwd: cwd,
            name: name,
            worktreePath: worktreePath,
            parentRepoPath: parentRepoPath,
            taskName: taskName
        )
    }
    func addTab(to workspaceID: WorkspaceID, cwd: String? = nil) { sessionLifecycleService.addTab(to: workspaceID, cwd: cwd) }
    @discardableResult
    func addAgentTask(to workspaceID: WorkspaceID, taskName: String) -> String? {
        sessionLifecycleService.addAgentTask(to: workspaceID, taskName: taskName)
    }
    func forkTab() {
        guard let wsID = snapshot.activeWorkspace?.id else { return }
        addTab(to: wsID, cwd: activeTabCWD)
    }
    func openDefaultTerminalLaunch(_ launch: DefaultTerminalLaunchRequest) { sessionLifecycleService.openDefaultTerminalLaunch(launch) }
    func selectWorkspace(_ id: WorkspaceID) { sessionLifecycleService.selectWorkspace(id) }
    func selectSession(workspaceID: WorkspaceID, sessionID: SessionID) { sessionLifecycleService.selectSession(workspaceID: workspaceID, sessionID: sessionID) }
    func selectTab(workspaceID: WorkspaceID, tabID: TabID) { sessionLifecycleService.selectTab(workspaceID: workspaceID, tabID: tabID) }
    func selectAdjacentSession(offset: Int) { sessionLifecycleService.selectAdjacentSession(offset: offset) }
    func moveActiveSession(offset: Int) { sessionLifecycleService.moveActiveSession(offset: offset) }
    func closeActiveTab() { sessionLifecycleService.closeActiveTab() }
    func closeActiveTabWithConfirmation() { sessionLifecycleService.closeActiveTabWithConfirmation() }
    func closeActiveSession() { sessionLifecycleService.closeActiveSession() }
    func closeSession(_ session: SessionGroup) { sessionLifecycleService.closeSession(session) }
    func openTabInActiveWorkspace() { sessionLifecycleService.openTabInActiveWorkspace() }
    func closeOtherTabs(keeping keepID: TabID) { sessionLifecycleService.closeOtherTabs(keeping: keepID) }
    func closeTabs(under path: String) async { await sessionLifecycleService.closeTabs(under: path) }
    func reopenLastClosedTab() { sessionLifecycleService.reopenLastClosedTab() }
    var canReopenClosedTab: Bool { lastClosedTab != nil }
    func closeActiveWorkspace() { sessionLifecycleService.closeActiveWorkspace() }
    func closeWorkspace(id: WorkspaceID) { sessionLifecycleService.closeWorkspace(id: id) }

    // MARK: - Split pane (facade → SplitPaneCoordinator)

    func splitActivePane(direction: SplitDirection, before: Bool = false) { splitPaneCoordinator.splitActivePane(direction: direction, before: before) }

    // MARK: - Project scripts (⌘R / ⌘.)

    /// Surface ID of the dedicated RUN pane, tracked per active session.
    private var runSurfaceID: SurfaceID?

    func runProjectScript() {
        guard let tab = snapshot.activeWorkspace?.activeTab else { return }
        let cwd = tab.cwd
        guard let config = ProjectConfig.load(from: cwd), let script = config.runScript, !script.isEmpty else { return }
        // If RUN surface already exists and is alive, re-send the script
        if let existing = runSurfaceID, tab.rootPane.allSurfaceIDs().contains(existing) {
            // Kill existing process and re-run
            requestDaemon(.sendData(surfaceID: existing.uuidString, data: Data("\u{03}".utf8))) // Ctrl-C
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                await self.requestDaemon(.sendData(surfaceID: existing.uuidString, data: Data((script + "\r").utf8)))
            }
            return
        }
        // Create a new split pane for RUN
        splitPaneCoordinator.splitActivePaneAndRun(direction: .horizontal, command: script)
        // After sync, capture the new pane's surface as runSurfaceID
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await syncFromDaemon()
            if let newTab = self.snapshot.activeWorkspace?.activeTab,
               let sid = newTab.rootPane.allSurfaceIDs().last {
                self.runSurfaceID = sid
            }
        }
    }

    func stopProjectScript() {
        guard let sid = runSurfaceID else { return }
        // Send SIGTERM via Ctrl-C
        requestDaemon(.sendData(surfaceID: sid.uuidString, data: Data("\u{03}".utf8)))
    }
    func splitActivePaneAndRun(direction: SplitDirection, command: String) { splitPaneCoordinator.splitActivePaneAndRun(direction: direction, command: command) }
    func focusPaneDirectional(_ direction: DirectionalAxis) { splitPaneCoordinator.focusPaneDirectional(direction) }
    func splitPaneSurface(tabID: TabID, sourcePaneID: PaneID, surfaceID: SurfaceID, targetPaneID: PaneID, direction: SplitDirection, beforeTarget: Bool) {
        splitPaneCoordinator.splitPaneSurface(tabID: tabID, sourcePaneID: sourcePaneID, surfaceID: surfaceID, targetPaneID: targetPaneID, direction: direction, beforeTarget: beforeTarget)
    }
    func splitTab(workspaceID: WorkspaceID, tabID: TabID, direction: SplitDirection) { splitPaneCoordinator.splitTab(workspaceID: workspaceID, tabID: tabID, direction: direction) }
    func splitSession(workspaceID: WorkspaceID, sessionID: SessionID, direction: SplitDirection) { splitPaneCoordinator.splitSession(workspaceID: workspaceID, sessionID: sessionID, direction: direction) }
    func killActivePane() { splitPaneCoordinator.killActivePane() }

    /// Close active pane (⌘W behavior): if single pane → close tab; otherwise kill pane.
    func closeActivePane() {
        if case .leaf = snapshot.activeWorkspace?.activeTab?.rootPane {
            closeActiveTab()
        } else {
            killActivePane()
        }
    }
    func killPane(paneID: PaneID) { splitPaneCoordinator.killPane(paneID: paneID) }
    func paneID(for surfaceID: SurfaceID, in node: PaneNode) -> PaneID? { splitPaneCoordinator.paneID(for: surfaceID, in: node) }
    func firstSurfaceID(forTab tabID: TabID) -> SurfaceID? { splitPaneCoordinator.firstSurfaceID(forTab: tabID) }

    // MARK: - Notifications (facade → NotificationCoordinator)

    func jumpToLatestNotification() { notificationCoordinator.jumpToLatestNotification() }
    func isSurfaceWaiting(_ surfaceID: UUID) -> Bool { notificationCoordinator.isSurfaceWaiting(surfaceID) }
    func notificationsList() -> [NotificationEntry] { notificationCoordinator.notificationsList() }
    func agentsList() -> [AgentSessionSummary] { notificationCoordinator.agentsList() }
    func openAgent(_ agent: AgentSessionSummary) { notificationCoordinator.openAgent(agent) }
    func openNotification(_ entry: NotificationEntry) { notificationCoordinator.openNotification(entry) }
    func clearNotification(surfaceID: SurfaceID) { notificationCoordinator.clearNotification(surfaceID: surfaceID) }
    func clearAllNotifications() { notificationCoordinator.clearAllNotifications() }
    func handleNotification(for surfaceID: SurfaceID, event: NotificationEvent, title: String, body: String) { notificationCoordinator.handleNotification(for: surfaceID, event: event, title: title, body: body) }
    func syncWaitingRings() { notificationCoordinator.syncWaitingRings() }

    // MARK: - Theme (facade → ThemeService)

    func applySettingsToHosts() { themeService.applySettingsToHosts() }
    func applyThemeToAllHosts() { themeService.applyThemeToAllHosts() }
    func setTheme(_ name: String, seedColors: Bool = true) { themeService.setTheme(name, seedColors: seedColors) }
    func applyImportedTheme(_ document: ThemeDocument) { themeService.applyImportedTheme(document) }
    func applyAutoThemeForCurrentAppearance() { themeService.applyAutoThemeForCurrentAppearance() }
    func reimportTerminalConfig() { themeService.reimportTerminalConfig() }

    static var isSystemAppearanceDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    // MARK: - Active pane (facade → ActivePaneService)

    func setActiveSurface(_ surfaceID: SurfaceID?) { activePaneService.setActiveSurface(surfaceID) }
    func reflectRemoteActivePane() { activePaneService.reflectRemoteActivePane() }
    func refreshPaneStyles() { activePaneService.refreshPaneStyles() }
    func refreshPaneBorders() { activePaneService.refreshPaneBorders() }
    func setMarkedPane(_ set: Bool) { activePaneService.setMarkedPane(set) }
    var markedSurfaceID: SurfaceID? { activePaneService.markedSurfaceID }
    func reassertMarkedPane() { activePaneService.reassertMarkedPane() }
    func setSynchronizePanes(_ on: Bool?) { activePaneService.setSynchronizePanes(on) }
    func adoptSynchronizeOptions() { activePaneService.adoptSynchronizeOptions() }
    func refreshSyncSiblings() { activePaneService.refreshSyncSiblings() }
    func zoomActivePane() { activePaneService.zoomActivePane() }
    func cycleActivePane(forward: Bool) { activePaneService.cycleActivePane(forward: forward) }
    func ensureActivePane(for tab: Tab) { activePaneService.ensureActivePane(for: tab) }
    func selectLastPane() { activePaneService.selectLastPane() }

    // MARK: - Pane operations (kept here — use coordinator state directly)

    func joinMarkedPane(direction: SplitDirection) {
        guard let markedSurface = activePaneService.markedSurfaceID,
              let tab = snapshot.activeWorkspace?.activeTab,
              let activeSurface = activeSurfaceID,
              let destPane = paneID(for: activeSurface, in: tab.rootPane)
        else { DisplayMessage.show("join-pane: no marked pane"); return }
        let sourcePane = snapshot.workspaces.flatMap(\.sessions).flatMap(\.tabs)
            .compactMap { paneID(for: markedSurface, in: $0.rootPane) }.first
        guard let sourcePane, sourcePane != destPane else { DisplayMessage.show("join-pane: invalid mark"); return }
        _ = requestDaemon(.joinPane(sourcePaneID: sourcePane, destPaneID: destPane, direction: direction))
        setMarkedPane(false)
        syncFromDaemon()
    }

    func setSplitRatio(tabID: TabID, firstPaneID: PaneID, secondPaneID: PaneID, ratio: Double) {
        // Browser panes are local-only (SplitPaneCoordinator.openBrowserPane inserts them via
        // applyLocalSnapshot, deliberately bypassing daemon sync) — the daemon's own pane tree
        // never learns about them, so persisting a ratio for a divider touching one always
        // fails with "Split not found" and fires the daemon-error toast. Skip the round trip.
        if let tab = snapshot.workspaces.flatMap(\.sessions).flatMap(\.tabs).first(where: { $0.id == tabID }) {
            let browserPaneIDs = Set(tab.rootPane.allBrowserLeaves().map(\.id))
            if browserPaneIDs.contains(firstPaneID) || browserPaneIDs.contains(secondPaneID) {
                return
            }
        }
        requestDaemon(.resizePaneRatio(tabID: tabID, firstPaneID: firstPaneID, secondPaneID: secondPaneID, ratio: ratio))
        syncFromDaemon(metadataOnly: true)
    }

    func showHintMode() {
        guard let surfaceID = activeSurfaceID,
              let host = terminalHosts.host(for: surfaceID) else { return }
        HintModeOverlay.shared.show(on: host.surfaceView)
    }

    func showDisplayPanes() {
        guard let tab = snapshot.activeWorkspace?.activeTab else { return }
        let panes = tab.rootPane.allSurfaceIDs().enumerated().compactMap { index, sid -> (number: Int, host: TerminalHostView)? in
            guard let host = terminalHosts.host(for: sid) else { return nil }
            return (number: index, host: host)
        }
        DisplayPanesOverlay.shared.show(panes: panes) { [weak self] surfaceID in
            self?.setActiveSurface(surfaceID)
            self?.terminalHosts.host(for: surfaceID)?.focusTerminal()
        }
    }

    func reorderSession(workspaceID: WorkspaceID, sessionID: SessionID, toIndex: Int) {
        requestDaemon(.reorderSession(workspaceID: workspaceID, sessionID: sessionID, toIndex: toIndex))
        syncFromDaemon()
    }

    func renameWorkspace(id: WorkspaceID, name: String) {
        requestDaemon(.renameWorkspace(workspaceID: id, name: name))
        syncFromDaemon()
    }

    func reorderTab(workspaceID: WorkspaceID, tabID: TabID, toIndex: Int) {
        requestDaemon(.reorderTab(workspaceID: workspaceID, tabID: tabID, toIndex: toIndex))
        syncFromDaemon()
    }

    func newSurface(tabID: TabID, paneID: PaneID) {
        Task {
            guard case let .surfaceID(raw)? = await requestDaemon(.newSurface(tabID: tabID, paneID: paneID, shell: settings.defaultShell)),
                  let surfaceID = UUID(uuidString: raw)
            else { await syncFromDaemon(); return }
            await syncFromDaemon()
            setActiveSurface(surfaceID)
            terminalHosts.host(for: surfaceID)?.focusTerminal()
        }
    }

    func selectPaneSurface(tabID: TabID, paneID: PaneID, surfaceID: SurfaceID) {
        Task {
            await requestDaemon(.selectPaneSurface(tabID: tabID, paneID: paneID, surfaceID: surfaceID))
            await syncFromDaemon()
            setActiveSurface(surfaceID)
            terminalHosts.host(for: surfaceID)?.focusTerminal()
        }
    }

    // MARK: - Terminal host management

    func terminalHostIfExists(for surfaceID: SurfaceID) -> TerminalHostView? { terminalHosts.host(for: surfaceID) }

    func terminalHost(for surfaceID: SurfaceID, cwd: String) -> TerminalHostView {
        if let existing = terminalHosts.host(for: surfaceID) { return existing }
        let host = TerminalHostView(
            surfaceID: surfaceID, workingDirectory: cwd,
            kouenSurfaceEnv: surfaceID.uuidString, settings: settings,
            themeName: snapshot.themeName, endpoint: activeEndpoint
        )
        host.hostDelegate = self
        host.applyTheme(named: snapshot.themeName)
        host.applySettings(settings)
        themeService.applyTerminalIdentity(to: host)
        themeService.pushBorderColors(to: host)
        terminalHosts.register(host)
        // Wire the inline AI completion overlay (⌥Space → Claude command suggestion).
        let aiController = InlineAICompletionController()
        aiController.install(in: host)
        inlineAIControllers[surfaceID.uuidString] = aiController
        // Block output tint + AI explain action bar (Phase 12b).
        let tintOverlay = BlockTintOverlay(surfaceView: host.surfaceView)
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(tintOverlay)
        NSLayoutConstraint.activate([
            tintOverlay.topAnchor.constraint(equalTo: host.topAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        // Auto-enable macOS Secure Input on password prompt patterns (Phase 6).
        SecureInputMonitor.shared.observeSurface(host)
        // OSC 26 agent status: update AgentDetector + show/hide approval bar.
        host.surfaceView.onAgentStatus = { [weak host] identity, activity, prompt in
            let resolved = AgentActivity(rawValue: activity == "waiting_input" ? "awaiting" : activity) ?? .idle
            let kind = identity.flatMap { AgentKind(rawValue: $0) }
            AgentDetector.setActivity(resolved, kind: kind, forSurfaceKey: surfaceID.uuidString)
            guard let host else { return }
            switch AgentApprovalBar.action(for: activity, prompt: prompt) {
            case .show(let p): AgentApprovalBar.show(on: host, prompt: p, kind: kind)
            case .hide:        AgentApprovalBar.hide(from: host)
            case .noop:        break
            }
        }
        // Dequeue the next queued command each time a shell prompt appears (OSC 133).
        let existingOnFinished = host.surfaceView.onCommandFinished
        host.surfaceView.onCommandFinished = { [weak host] duration, exitCode in
            existingOnFinished?(duration, exitCode)
            guard let host else { return }
            PromptQueue.shared.dequeueAndRun(for: host.surfaceID, via: host)
        }
        return host
    }

    // MARK: - Composer (⌘⇧E)

    func openComposer(withInitialText text: String = "") {
        ComposerPanel.shared.onSubmit = { [weak self] text in
            guard let surfaceID = self?.activeSurfaceID,
                  let host = self?.terminalHosts.host(for: surfaceID) else { return }
            host.sendInput((text + "\n").data(using: .utf8) ?? Data())
        }
        ComposerPanel.shared.present(relativeTo: NSApp.keyWindow, initialText: text)
    }

    // MARK: - Find bar / Copy mode / Detach / Prompts

    func toggleFindBar() {
        guard let surfaceID = activeSurfaceID, let host = terminalHosts.host(for: surfaceID) else { return }
        host.toggleFind()
    }

    func toggleCopyMode() {
        guard let surfaceID = activeSurfaceID, let host = TerminalPaneRegistryAccess.host(for: surfaceID) else { return }
        if host.isInCopyMode { host.exitCopyMode() }
        else { host.enterCopyMode(modeKeys: KouenOptions.shared.get("mode-keys", scope: .global)?.stringValue ?? "vi") }
    }

    func performCopyModeAction(_ action: CopyModeAction) {
        guard let surfaceID = activeSurfaceID, let host = TerminalPaneRegistryAccess.host(for: surfaceID) else { return }
        host.performCopyModeAction(action)
    }

    func toggleViMode() {
        guard let surfaceID = activeSurfaceID, let host = TerminalPaneRegistryAccess.host(for: surfaceID) else { return }
        let sv = host.surfaceView
        sv.viModeEnabled.toggle()
        if !sv.viModeEnabled { sv.setViMode(.insert) }
    }

    func detachActiveSurface() {
        guard let surfaceID = activeSurfaceID, let host = TerminalPaneRegistryAccess.host(for: surfaceID) else { return }
        host.detachFromDaemonSurface()
    }

    func reattachActiveSurface() {
        guard let surfaceID = activeSurfaceID, let host = TerminalPaneRegistryAccess.host(for: surfaceID) else { return }
        host.reattachToDaemonSurface()
    }

    var activePaneIsDetached: Bool {
        guard let surfaceID = activeSurfaceID, let host = TerminalPaneRegistryAccess.host(for: surfaceID) else { return false }
        return host.isDetachedFromDaemon
    }

    func jumpToPreviousPrompt() {
        guard let surfaceID = activeSurfaceID, let host = TerminalPaneRegistryAccess.host(for: surfaceID) else { return }
        host.jumpToPreviousPrompt()
    }

    func jumpToNextPrompt() {
        guard let surfaceID = activeSurfaceID, let host = TerminalPaneRegistryAccess.host(for: surfaceID) else { return }
        host.jumpToNextPrompt()
    }

    // MARK: - Prompt Queue

    func enqueueCommand(_ command: String) {
        guard let surfaceID = activeSurfaceID else { return }
        PromptQueue.shared.enqueue(command, for: surfaceID)
    }

    func cancelQueue() {
        guard let surfaceID = activeSurfaceID else { return }
        PromptQueue.shared.cancel(for: surfaceID)
    }

    // MARK: - Misc

    func paneBorderContext(forSurface surfaceID: SurfaceID) -> FormatContext {
        let owningTab = surfaceIndex[surfaceID]?.tab
        let paneIndex = owningTab.flatMap { tab in tab.rootPane.allSurfaceIDs().firstIndex(of: surfaceID) }
        return FormatContext(
            paneID: surfaceID.uuidString, paneTitle: owningTab?.title, paneCwd: owningTab?.cwd,
            paneActive: surfaceID == activeSurfaceID, paneIndex: paneIndex,
            tabName: owningTab?.title, workspaceName: snapshot.activeWorkspace?.name,
            agentKind: owningTab?.agent?.kind.rawValue, agentChip: owningTab?.agent?.kind.chip,
            gitBranch: owningTab?.gitBranch, clientName: "Kouen.app"
        )
    }

    func currentFormatContext() -> FormatContext {
        let workspace = snapshot.activeWorkspace
        let session = workspace?.activeSession
        let tab = workspace?.activeTab
        var context = FormatContext(
            paneID: activeSurfaceID?.uuidString, paneTitle: tab?.title, paneCwd: tab?.cwd,
            paneActive: activeSurfaceID != nil, paneIndex: nil,
            sessionName: session?.name.isEmpty == false ? session?.name : nil,
            tabName: tab?.title, tabIndex: session?.tabs.firstIndex(where: { $0.id == tab?.id }),
            workspaceName: workspace?.name, agentKind: tab?.agent?.kind.rawValue,
            agentActivity: tab?.agent?.activity.rawValue, agentChip: tab?.agent?.kind.chip,
            gitBranch: tab?.gitBranch, clientName: "Kouen.app"
        )
        context.paneCurrentCommand = tab?.currentCommand
        context.paneDead = tab.map { $0.exitStatus != nil }
        context.paneExitStatus = tab?.exitStatus
        context.sessionID = session?.id.uuidString
        context.windowID = tab?.id.uuidString
        context.sessionWindows = session?.tabs.count
        context.windowPanes = tab?.rootPane.allPaneIDs().count
        if let tab, let session { context.windowActive = tab.id == session.activeTabID }
        context.sessionGroup = session.flatMap { snapshot.groupName(of: $0) }
        context.windowFlags = tab.map { ($0.zoomedPaneID != nil ? "Z" : "") + $0.alertFlags }
        return context
    }

    func selectWorkspace(byIndex index: Int) {
        guard index >= 0, index < snapshot.workspaces.count else { return }
        selectWorkspace(snapshot.workspaces[index].id)
    }

    func beginRenameActiveTab() {
        NotificationCenter.default.post(name: NotificationBus.shared.snapshotChanged, object: nil, userInfo: ["beginRenameActiveTab": true])
    }

    private var preToggleBackgroundOpacity: Float?

    func toggleWindowOpacity() {
        if let saved = preToggleBackgroundOpacity {
            settings.backgroundOpacity = saved
            preToggleBackgroundOpacity = nil
            if let view = NSApp.mainWindow?.contentView {
                Toast.show("Glass Mode (\(Int(saved * 100))%)", in: view)
            }
        } else {
            preToggleBackgroundOpacity = settings.backgroundOpacity
            settings.backgroundOpacity = 1.0
            if let view = NSApp.mainWindow?.contentView {
                Toast.show("Solid Opaque Mode (100%)", in: view)
            }
        }
        KouenChrome.update(
            themeName: snapshot.themeName,
            opacity: CGFloat(settings.backgroundOpacity),
            blur: settings.backgroundBlur,
            backgroundHex: settings.customBackgroundHex,
            foregroundHex: settings.customForegroundHex,
            cursorHex: settings.customCursorHex
        )
        if let main = NSApp.mainWindow?.windowController as? MainWindowController {
            main.applyChrome()
        }
    }

    func updateFontSize(delta: Float) { applyFontSize(settings.fontSize + delta) }
    func resetFontSize() { applyFontSize(KouenSettings().fontSize) }
    private func applyFontSize(_ size: Float) {
        settings.fontSize = max(8, min(32, size))
        try? settings.save()
        for host in terminalHosts.allHosts() { host.applySettings(settings) }
    }
}

// MARK: - TerminalHostDelegate — see SessionCoordinator+HostDelegate.swift

// MARK: - Supporting types — see SessionCoordinatorTypes.swift
