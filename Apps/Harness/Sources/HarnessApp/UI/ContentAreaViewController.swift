import AppKit
import HarnessCore
import HarnessTerminalKit

@MainActor
final class ContentAreaViewController: NSViewController, TerminalTabBarDelegate {
    private let titleStrip = WindowTitleStripView()
    private let tabBar = TerminalTabBarView()
    private let terminalHost = NSView()
    private let sidebarToggle = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
    /// Thin separator under the tab bar so the chrome reads as its own band instead of
    /// relying on empty space to imply separation from the terminal canvas.
    private let tabBarDivider = HarnessDesign.divider()
    private var paneContainer: PaneContainerView?
    private let fileTabManager = FileTabManager()
    private var fileEditorView: FileEditorView?
    private var lastStructureKey = ""
    private var pendingReload: Bool?
    /// Pasteboard change counter captured at left-mouse-down. On mouse-up, if it
    /// has incremented inside the terminal area AND the user has `copy-on-select`
    /// enabled, that means the renderer just copied the selection — surface a brief
    /// "Selection copied" toast.
    private var pasteboardCountAtMouseDown: Int = NSPasteboard.general.changeCount
    private var copySelectionMonitor: Any?
    private var sidebarToggleConstraint: NSLayoutConstraint?

    override func loadView() {
        view = NSView()
        // The terminal area stays visually independent from app chrome. the renderer
        // owns its own background color, opacity, blur, and color pipeline here;
        // sidebar/tab chrome must not add an AppKit backdrop over or behind it.
        HarnessDesign.makeClear(view)
    }

    func applyChrome() {
        HarnessDesign.makeClear(view)
        refreshTerminalHostFill()
        refreshEditorPanelFill()
        titleStrip.applyColors()
        tabBar.applyChrome()
        paneContainer?.applyChrome()
        updateSidebarToggleConstraints()
    }

    /// Reflect the active tab's cwd in the title strip's folder/path readout. Hidden while a
    /// CLI agent (claude, codex, cursor-agent, …) owns the pane: the agent's own UI is the
    /// context then, and a shell-cwd readout over it is just noise. Returns when the tool exits.
    private func updateTitleStripPath() {
        let snap = SessionCoordinator.shared.snapshot
        guard let tab = snap.activeWorkspace?.activeTab else {
            titleStrip.setPath("")
            return
        }
        let agentActive = tab.agent != nil || AgentTitleInference.kind(from: tab.title) != nil
        titleStrip.setPath(agentActive ? "" : tab.cwd)
    }

    /// Back the terminal host so the canvas reads the same as the rest of the window.
    /// When the window is **opaque** (opacity ≥ 1) the host is a solid terminal-colored
    /// fill — this covers any resize gap before the renderer repaints, so the terminal
    /// shows true rich color. When **translucent** the host is `.clear`: the renderer
    /// already draws the canvas at `backgroundOpacity` alpha, so a clear host lets that
    /// single translucent layer composite over the one window-wide blur — exactly like
    /// the chrome (`sidebarBackground × opacity`). An opaque fill here would block the
    /// blur and make the terminal look solid while the chrome was see-through.
    private func refreshTerminalHostFill() {
        terminalHost.wantsLayer = true
        let opacity = HarnessSettings.clampedOpacity(SessionCoordinator.shared.settings.backgroundOpacity)
        terminalHost.layer?.backgroundColor = opacity >= 1
            ? HarnessChrome.current.terminalBackground.cgColor
            : NSColor.clear.cgColor
    }

    private func refreshEditorPanelFill() {
        guard let panel = fileEditorPanel else { return }
        let opacity = CGFloat(HarnessSettings.clampedOpacity(SessionCoordinator.shared.settings.backgroundOpacity))
        panel.layer?.backgroundColor = HarnessChrome.current.terminalBackground
            .withAlphaComponent(opacity).cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBarDivider.translatesAutoresizingMaskIntoConstraints = false
        terminalHost.translatesAutoresizingMaskIntoConstraints = false
        refreshTerminalHostFill()

        view.addSubview(terminalHost)
        view.addSubview(titleStrip)
        view.addSubview(tabBar)
        view.addSubview(tabBarDivider)
        setupSidebarToggle()

        NSLayoutConstraint.activate([
            // Draggable title strip above the tabs: window-move grab area + Ghostty-style
            // folder/path readout. Pushes the tab pills below the traffic-light band.
            titleStrip.topAnchor.constraint(equalTo: view.topAnchor),
            titleStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleStrip.heightAnchor.constraint(equalToConstant: WindowTitleStripView.height),

            tabBar.topAnchor.constraint(equalTo: titleStrip.bottomAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // No divider line under the tab bar: the elevated chrome background now
            // provides the tab-strip/terminal boundary (see HarnessChromePalette).
            tabBarDivider.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            tabBarDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarDivider.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            terminalHost.topAnchor.constraint(equalTo: tabBarDivider.bottomAnchor),
            terminalHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            terminalHost.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let leading = terminalHost.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        leading.isActive = true
        terminalHostLeading = leading

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(snapshotChanged(_:)),
            name: NotificationBus.shared.snapshotChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viQuitCommand(_:)),
            name: .viQuitCommand,
            object: nil
        )
        NotificationCenter.default.addObserver(self, selector: #selector(viOpenFileCommand(_:)), name: .viOpenFileCommand, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viSplitFileCommand(_:)), name: .viSplitFileCommand, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viFindFileCommand(_:)), name: .viFindFileCommand, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viNextBufferCommand(_:)), name: .viNextBufferCommand, object: nil)
        installCopySelectionToast()
        reloadTabBar()
        restoreEditorState()
    }

    private func installCopySelectionToast() {
        copySelectionMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            if event.type == .leftMouseDown {
                self.pasteboardCountAtMouseDown = NSPasteboard.general.changeCount
            } else if event.type == .leftMouseUp,
                      SessionCoordinator.shared.settings.copyOnSelect,
                      self.eventIsInsideTerminalArea(event),
                      NSPasteboard.general.changeCount > self.pasteboardCountAtMouseDown
            {
                Toast.show("Selection copied", in: self.terminalHost)
            }
            return event
        }
    }

    private func eventIsInsideTerminalArea(_ event: NSEvent) -> Bool {
        guard let window = event.window, window === view.window else { return false }
        let pointInHost = terminalHost.convert(event.locationInWindow, from: nil)
        return terminalHost.bounds.contains(pointInHost)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard paneContainer == nil || pendingReload != nil else { return }
        guard terminalHost.bounds.width > 1, terminalHost.bounds.height > 1 else { return }
        let force = pendingReload ?? true
        pendingReload = nil
        reloadIfNeeded(force: force)
    }

    @objc private func viQuitCommand(_ note: Notification) {
        if let activeID = fileTabManager.activeTab()?.id {
            closeFileTab(id: activeID)
        }
    }

    @objc private func viOpenFileCommand(_ note: Notification) {
        guard let path = note.userInfo?["path"] as? String else { return }
        guard let resolved = resolveViPath(path, command: "edit") else { return }
        openFileTab(path: resolved)
    }

    @objc private func viSplitFileCommand(_ note: Notification) {
        guard let path = note.userInfo?["path"] as? String, !path.isEmpty else { return }
        let direction = (note.userInfo?["direction"] as? String) == "vertical"
            ? SplitDirection.vertical
            : SplitDirection.horizontal
        guard let expanded = resolveViPath(path, command: "split") else { return }
        SessionCoordinator.shared.splitActivePaneAndRun(
            direction: direction,
            command: "${EDITOR:-vi} \(Self.shellQuote(expanded))"
        )
    }

    @objc private func viFindFileCommand(_ note: Notification) {
        guard let query = note.userInfo?["query"] as? String, !query.isEmpty else { return }
        let root = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd ?? FileManager.default.currentDirectoryPath
        switch FuzzyPathResolver.resolve(query: query, root: root, limit: 5) {
        case .none:
            DisplayMessage.show("find: no match")
        case .unique(let path):
            openFileTab(path: path)
        case .ambiguous(let matches):
            DisplayMessage.show(matches.enumerated().map { "\($0.offset + 1): \($0.element)" }.joined(separator: "\n"))
        }
    }

    @objc private func viNextBufferCommand(_ note: Notification) {
        guard let delta = note.userInfo?["delta"] as? Int else { return }
        let tabs = fileTabManager.openTabs
        guard !tabs.isEmpty, let active = fileTabManager.activeTab() else { return }
        let idx = tabs.firstIndex(where: { $0.id == active.id }) ?? 0
        let newIdx = (idx + delta + tabs.count) % tabs.count
        selectFileTab(id: tabs[newIdx].id)
    }

    @objc private func snapshotChanged(_ note: Notification) {
        let structureChanged = note.userInfo?["structureChanged"] as? Bool ?? true
        let metadataOnly = note.userInfo?["metadataOnly"] as? Bool ?? false
        if metadataOnly && !structureChanged {
            refreshTabBarMetadata()
            return
        }
        reloadTabBar()
        reloadIfNeeded(force: structureChanged)
    }

    func reloadTabBar() {
        let snap = SessionCoordinator.shared.snapshot
        guard let workspace = snap.activeWorkspace else { return }
        // Each session = one tab pill (1 session = 1 project path)
        let sessionTabs = workspace.sessions.compactMap { session -> Tab? in
            guard let tab = session.activeTab ?? session.tabs.first else { return nil }
            return tab
        }
        let activeTabID = workspace.activeSession?.activeTab?.id ?? workspace.activeSession?.tabs.first?.id
        tabBar.reload(tabs: sessionTabs, activeTabID: activeTabID)
        updateTitleStripPath()
    }

    /// Leading inset so the title strip's path readout clears the macOS traffic lights when
    /// the sidebar is collapsed. Driven by `MainSplitViewController` during the toggle. The
    /// tab bar itself sits below the lights (the strip pushes it down) and needs no inset.
    func setTabBarLeadingInset(_ inset: CGFloat) {
        let settings = SessionCoordinator.shared.settings
        titleStrip.setLeadingInset(inset)
        
        let sidebarVisible = settings.sidebarVisible
        let sidebarOnRight = settings.sidebarOnRight
        
        if sidebarOnRight {
            tabBar.setLeadingInset(inset)
            tabBar.trailingInset = sidebarVisible ? 0 : 28
        } else {
            tabBar.setLeadingInset(sidebarVisible ? 0 : inset)
            tabBar.trailingInset = 0
        }
        
        sidebarToggle.isHidden = sidebarVisible
    }

    private func setupSidebarToggle() {
        sidebarToggle.toolTip = "Show sidebar (⌘\\)"
        sidebarToggle.target = self
        sidebarToggle.action = #selector(toggleSidebarClicked)
        sidebarToggle.translatesAutoresizingMaskIntoConstraints = false
        sidebarToggle.isHidden = true
        view.addSubview(sidebarToggle)
        NSLayoutConstraint.activate([
            sidebarToggle.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            sidebarToggle.widthAnchor.constraint(equalToConstant: 24),
            sidebarToggle.heightAnchor.constraint(equalToConstant: 24),
        ])
        updateSidebarToggleConstraints()
    }

    private func updateSidebarToggleConstraints() {
        sidebarToggleConstraint?.isActive = false
        let sidebarOnRight = SessionCoordinator.shared.settings.sidebarOnRight
        if sidebarOnRight {
            sidebarToggleConstraint = sidebarToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6)
        } else {
            sidebarToggleConstraint = sidebarToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6)
        }
        sidebarToggleConstraint?.isActive = true

        let symbol = sidebarOnRight ? "sidebar.right" : "sidebar.left"
        sidebarToggle.setSymbol(symbol, accessibilityDescription: "Show sidebar", pointSize: 12, weight: .medium)
    }

    @objc private func toggleSidebarClicked() {
        (view.window?.contentViewController as? MainSplitViewController)?.toggleSidebar()
    }

    func refreshTabBarMetadata() {
        let snap = SessionCoordinator.shared.snapshot
        guard let workspace = snap.activeWorkspace else { return }
        let sessionTabs = workspace.sessions.compactMap { session -> Tab? in
            session.activeTab ?? session.tabs.first
        }
        let activeTabID = workspace.activeSession?.activeTab?.id ?? workspace.activeSession?.tabs.first?.id
        tabBar.refreshMetadata(tabs: sessionTabs, activeTabID: activeTabID)
        updateTitleStripPath()
    }

    func tabBarDidSelect(tabID: TabID) {
        let coordinator = SessionCoordinator.shared
        guard let workspaceID = coordinator.snapshot.activeWorkspaceID,
              let workspace = coordinator.snapshot.activeWorkspace,
              let session = workspace.sessions.first(where: { $0.tabs.contains(where: { $0.id == tabID }) })
        else { return }
        coordinator.selectSession(workspaceID: workspaceID, sessionID: session.id)
    }

    func tabBarDidRequestNewTab() {
        guard let workspaceID = SessionCoordinator.shared.snapshot.activeWorkspaceID else { return }
        SessionCoordinator.shared.addSession(to: workspaceID)
    }

    func tabBarDidRequestClose(tabID: TabID) {
        let coordinator = SessionCoordinator.shared
        guard let workspaceID = coordinator.snapshot.activeWorkspaceID,
              let workspace = coordinator.snapshot.activeWorkspace,
              let session = workspace.sessions.first(where: { $0.tabs.contains(where: { $0.id == tabID }) })
        else { return }
        coordinator.selectSession(workspaceID: workspaceID, sessionID: session.id)
        coordinator.closeActiveSession()
    }

    func tabBarDidReorder(tabID: TabID, toIndex: Int) {
        let coordinator = SessionCoordinator.shared
        guard let workspaceID = coordinator.snapshot.activeWorkspaceID,
              let workspace = coordinator.snapshot.activeWorkspace,
              let session = workspace.sessions.first(where: { $0.tabs.contains(where: { $0.id == tabID }) })
        else { return }
        coordinator.reorderSession(workspaceID: workspaceID, sessionID: session.id, toIndex: toIndex)
    }

    func tabBarDidRequestCloseOthers(tabID: TabID) {
        SessionCoordinator.shared.closeOtherTabs(keeping: tabID)
    }

    func tabBarDidRequestRename(tabID: TabID) {
        let coordinator = SessionCoordinator.shared
        guard let workspaceID = coordinator.snapshot.activeWorkspaceID else { return }
        coordinator.selectTab(workspaceID: workspaceID, tabID: tabID)
        coordinator.beginRenameActiveTab()
    }

    func tabBarDidRequestSplit(tabID: TabID, direction: SplitDirection) {
        guard let workspaceID = SessionCoordinator.shared.snapshot.activeWorkspaceID else { return }
        SessionCoordinator.shared.splitTab(workspaceID: workspaceID, tabID: tabID, direction: direction)
    }

    func tabBarDidRequestTogglePersistent(tabID: TabID) {
        // Flip the tab's persistence pin via the daemon (mirrors the session pin in the sidebar).
        // Read the current value from the snapshot so the menu item toggles rather than forces a
        // state; the resulting commit refreshes the pill's checkmark on the next reload.
        let coordinator = SessionCoordinator.shared
        let current = coordinator.snapshot.workspaces
            .flatMap(\.sessions).flatMap(\.tabs)
            .first(where: { $0.id == tabID })?.persistent ?? false
        coordinator.requestDaemon(.setTabPersistent(tabID: tabID, persistent: !current))
    }

    private func reloadAll(force: Bool) {
        reloadTabBar()
        reloadIfNeeded(force: force)
    }

    func reloadIfNeeded(force: Bool) {
        guard terminalHost.bounds.width > 1, terminalHost.bounds.height > 1 else {
            pendingReload = (pendingReload ?? false) || force
            return
        }

        let coordinator = SessionCoordinator.shared
        guard let workspace = coordinator.snapshot.activeWorkspace,
              let tab = workspace.activeTab
        else { return }

        let displayNode = zoomedNode(for: tab) ?? tab.rootPane
        let key = "\(coordinator.structureRevision)|\(workspace.id)|\(tab.id)|\(tab.zoomedPaneID?.uuidString ?? "all")|\(paneKey(displayNode))"
        guard force || key != lastStructureKey else {
            paneContainer?.refreshChrome(snapshot: coordinator.snapshot)
            return
        }
        fputs("BLINKDBG reloadIfNeeded REBUILD: force=\(force) oldKey=\(lastStructureKey) newKey=\(key)\n", harnessStderr)
        lastStructureKey = key

        // Incremental update: detach existing terminal hosts from old container
        // (without removing them from window) then rebuild container around them.
        let existingHosts = paneContainer?.collectTerminalHosts() ?? [:]
        paneContainer?.detachHostsOnly()
        paneContainer?.removeFromSuperview()

        let container = PaneContainerView(
            node: displayNode,
            cwd: tab.cwd,
            themeName: coordinator.snapshot.themeName,
            existingHosts: existingHosts
        )
        container.translatesAutoresizingMaskIntoConstraints = false
        terminalHost.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: terminalHost.topAnchor),
            container.leadingAnchor.constraint(equalTo: terminalHost.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: terminalHost.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: terminalHost.bottomAnchor),
        ])
        paneContainer = container
        // Re-assert the focused-pane border after the (re)mount — reused hosts keep
        // their flag, but a freshly shown tab needs its active pane established.
        coordinator.ensureActivePane(for: tab)
    }

    private func paneKey(_ node: PaneNode) -> String {
        switch node {
        case let .leaf(leaf):
            return "l:\((leaf.activeSurfaceID ?? leaf.surfaceID).uuidString)"
        case let .branch(direction, _, first, second):
            // Ratio is intentionally excluded from the rebuild key: a divider drag
            // persists the ratio but must not force a pane remount (that was the
            // resize flicker). Ratio is re-applied via setPosition on (re)mount.
            return "b:\(direction.rawValue):\(paneKey(first)):\(paneKey(second))"
        }
    }

    private func zoomedNode(for tab: Tab) -> PaneNode? {
        guard let zoomedPaneID = tab.zoomedPaneID else { return nil }
        return leafNode(paneID: zoomedPaneID, in: tab.rootPane)
    }

    private func leafNode(paneID: PaneID, in node: PaneNode) -> PaneNode? {
        switch node {
        case let .leaf(leaf) where leaf.id == paneID:
            return .leaf(leaf)
        case let .branch(_, _, first, second):
            return leafNode(paneID: paneID, in: first) ?? leafNode(paneID: paneID, in: second)
        default:
            return nil
        }
    }

    // MARK: - File Tabs

    func openFileTab(path: String) {
        fileTabManager.open(path: path)
        showFileEditorSplit()
        loadActiveFileTab()
        persistEditorState()
    }

    private func resolveViPath(_ path: String, command: String) -> String? {
        var expanded = (path as NSString).expandingTildeInPath
        if !expanded.hasPrefix("/"), let cwd = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd {
            expanded = (cwd as NSString).appendingPathComponent(expanded)
        }
        if !FileManager.default.fileExists(atPath: expanded) {
            let root = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd ?? FileManager.default.currentDirectoryPath
            switch FuzzyPathResolver.resolve(query: path, root: root, limit: 5) {
            case .none:
                DisplayMessage.show("\(command): no match")
                return nil
            case .unique(let match):
                return match
            case .ambiguous(let matches):
                DisplayMessage.show(matches.enumerated().map { "\($0.offset + 1): \($0.element)" }.joined(separator: "\n"))
                return nil
            }
        }
        return expanded
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    func closeFileTab(id: FileTabID) {
        fileTabManager.close(id: id)
        if fileTabManager.hasOpenTabs {
            loadActiveFileTab()
        } else {
            hideFileEditorSplit()
        }
        persistEditorState()
    }

    func selectFileTab(id: FileTabID) {
        fileTabManager.activate(id: id)
        loadActiveFileTab()
        persistEditorState()
    }

    private func loadActiveFileTab() {
        guard let tab = fileTabManager.activeTab() else { return }
        fileEditorView?.load(path: tab.path)
        fileEditorTabBar?.reload(tabs: fileTabManager.openTabs, activeID: fileTabManager.activeFileTabID)
    }

    private var fileEditorPanel: NSView?
    var isFileEditorVisible: Bool {
        fileEditorPanel != nil
    }
    private var fileEditorTabBar: FileEditorTabBarView?
    private var terminalHostLeading: NSLayoutConstraint?
    private var editorWidthConstraint: NSLayoutConstraint?
    private var editorDivider: NSView?

    func showFileEditorSplit() {
        fputs("BLINKDBG showFileEditorSplit: alreadyOpen=\(fileEditorPanel != nil)\n", harnessStderr)
        if fileEditorPanel != nil {
            loadActiveFileTab()
            return
        }
        // Add editor panel to the left of terminalHost — no reparenting terminal views.
        let panel = NSView()
        panel.wantsLayer = true
        let c = HarnessDesign.chrome
        // No opaque background — let window vibrancy show through (same as terminal)
        panel.layer?.borderColor = c.border.cgColor
        panel.layer?.borderWidth = 1
        panel.translatesAutoresizingMaskIntoConstraints = false

        let tabBarView = FileEditorTabBarView()
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        tabBarView.onSelect = { [weak self] id in self?.selectFileTab(id: id) }
        tabBarView.onClose = { [weak self] id in self?.closeFileTab(id: id) }
        panel.addSubview(tabBarView)
        fileEditorTabBar = tabBarView

        let editor = FileEditorView(frame: .zero)
        editor.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(editor)
        fileEditorView = editor

        NSLayoutConstraint.activate([
            tabBarView.topAnchor.constraint(equalTo: panel.topAnchor),
            tabBarView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            tabBarView.heightAnchor.constraint(equalToConstant: 34),
            editor.topAnchor.constraint(equalTo: tabBarView.bottomAnchor),
            editor.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
        ])

        view.addSubview(panel)
        // Editor: start at 40% width, draggable
        let initialWidth = view.bounds.width > 0 ? view.bounds.width * 0.4 : 400
        let widthC = panel.widthAnchor.constraint(equalToConstant: initialWidth)
        widthC.priority = .defaultHigh
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: tabBarDivider.bottomAnchor, constant: 2),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            widthC,
            panel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
        editorWidthConstraint = widthC

        // Drag divider between editor and terminal
        let divider = EditorDividerView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthConstraint = widthC
        divider.containerView = view
        view.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: panel.topAnchor),
            divider.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -2),
            divider.widthAnchor.constraint(equalToConstant: 5),
        ])
        editorDivider = divider

        // Shift terminalHost leading to make room
        if let existing = terminalHostLeading {
            existing.isActive = false
        }
        let leading = terminalHost.leadingAnchor.constraint(equalTo: panel.trailingAnchor)
        leading.isActive = true
        terminalHostLeading = leading

        fileEditorPanel = panel
        refreshEditorPanelFill()
        layoutFileEditorSplitSynchronously()
        persistEditorState()
    }

    func hideFileEditorSplit() {
        guard let panel = fileEditorPanel else { return }
        panel.removeFromSuperview()
        editorDivider?.removeFromSuperview()
        fileEditorPanel = nil
        fileEditorView = nil
        fileEditorTabBar = nil
        editorWidthConstraint = nil
        editorDivider = nil
        // Restore terminalHost leading to view edge
        if let lc = terminalHostLeading {
            lc.isActive = false
            terminalHostLeading = nil
        }
        let restored = terminalHost.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        restored.isActive = true
        terminalHostLeading = restored
        layoutFileEditorSplitSynchronously()
        persistEditorState()
    }

    private func layoutFileEditorSplitSynchronously() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.layoutSubtreeIfNeeded()
        terminalHost.layoutSubtreeIfNeeded()
        CATransaction.commit()
    }

    private func persistEditorState() {
        let visible = isFileEditorVisible
        let paths = fileTabManager.openTabs.map { $0.path }
        let activePath = fileTabManager.activeTab()?.path
        
        UserDefaults.standard.set(visible, forKey: "harness.fileEditorVisible")
        UserDefaults.standard.set(paths, forKey: "harness.fileEditorPaths")
        if let activePath {
            UserDefaults.standard.set(activePath, forKey: "harness.fileEditorActivePath")
        } else {
            UserDefaults.standard.removeObject(forKey: "harness.fileEditorActivePath")
        }
    }

    private func restoreEditorState() {
        let visible = UserDefaults.standard.bool(forKey: "harness.fileEditorVisible")
        let paths = UserDefaults.standard.stringArray(forKey: "harness.fileEditorPaths") ?? []
        let activePath = UserDefaults.standard.string(forKey: "harness.fileEditorActivePath")
        
        for path in paths {
            fileTabManager.open(path: path)
        }
        if let activePath {
            fileTabManager.open(path: activePath)
        }
        
        if visible && fileTabManager.hasOpenTabs {
            showFileEditorSplit()
            loadActiveFileTab()
        }
    }

    func activateTerminalTab() {
        // no-op — terminal is always visible in split mode
    }
}

@MainActor
final class PaneContainerView: NSView {
    private let coordinator = SessionCoordinator.shared
    private let tabID: TabID?
    private var existingHosts: [SurfaceID: TerminalHostView]

    init(node: PaneNode, cwd: String, themeName: String, existingHosts: [SurfaceID: TerminalHostView] = [:]) {
        self.existingHosts = existingHosts
        self.tabID = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.id
        super.init(frame: .zero)
        HarnessDesign.makeClear(self)
        build(node: node, cwd: cwd, into: self)
    }

    func applyChrome() {
        HarnessDesign.makeClear(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Collect all terminal hosts keyed by surfaceID before teardown.
    func collectTerminalHosts() -> [SurfaceID: TerminalHostView] {
        var result: [SurfaceID: TerminalHostView] = [:]
        collectHosts(in: self, into: &result)
        return result
    }

    private func collectHosts(in view: NSView, into result: inout [SurfaceID: TerminalHostView]) {
        for sub in view.subviews {
            if let host = sub as? TerminalHostView {
                result[host.surfaceID] = host
            } else {
                collectHosts(in: sub, into: &result)
            }
        }
    }

    /// Remove terminal hosts from the view hierarchy without triggering dealloc —
    /// they'll be re-inserted into the new container.
    func detachHostsOnly() {
        detachHosts(in: self)
    }

    private func detachHosts(in view: NSView) {
        for sub in view.subviews {
            if sub is TerminalHostView {
                sub.removeFromSuperview()
            } else {
                detachHosts(in: sub)
            }
        }
    }

    func refreshChrome(snapshot: SessionSnapshot) {
        applyChrome()
    }

    private func tabFor(surfaceID: SurfaceID, in snapshot: SessionSnapshot) -> Tab? {
        for workspace in snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs where tab.rootPane.allSurfaceIDs().contains(surfaceID) {
                    return tab
                }
            }
        }
        return nil
    }

    private func build(node: PaneNode, cwd: String, into parent: NSView) {
        switch node {
        case let .leaf(leaf):
            let paneShell = NSView()
            HarnessDesign.makeClear(paneShell)
            paneShell.translatesAutoresizingMaskIntoConstraints = false
            parent.addSubview(paneShell)
            NSLayoutConstraint.activate([
                paneShell.topAnchor.constraint(equalTo: parent.topAnchor),
                paneShell.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                paneShell.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
                paneShell.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            ])

            let surfaceID = leaf.activeSurfaceID ?? leaf.surfaceID
            let host: TerminalHostView
            if let existing = existingHosts.removeValue(forKey: surfaceID) {
                host = existing
            } else {
                host = coordinator.terminalHost(for: surfaceID, cwd: cwd)
            }
            host.translatesAutoresizingMaskIntoConstraints = false
            paneShell.addSubview(host)
            NSLayoutConstraint.activate([
                host.topAnchor.constraint(equalTo: paneShell.topAnchor),
                host.leadingAnchor.constraint(equalTo: paneShell.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: paneShell.trailingAnchor),
                host.bottomAnchor.constraint(equalTo: paneShell.bottomAnchor),
            ])

            // CMUX-style split buttons at top-right, above Metal via zPosition
            if let tabID {
                let splitButtons = PaneSplitButtonsView(tabID: tabID, paneID: leaf.id)
                splitButtons.translatesAutoresizingMaskIntoConstraints = false
                splitButtons.wantsLayer = true
                splitButtons.layer?.zPosition = 1000
                paneShell.addSubview(splitButtons)
                NSLayoutConstraint.activate([
                    splitButtons.trailingAnchor.constraint(equalTo: paneShell.trailingAnchor, constant: -8),
                    splitButtons.topAnchor.constraint(equalTo: paneShell.topAnchor, constant: 8),
                ])
            }
        case let .branch(direction, ratio, first, second):
            // Flatten same-direction chain into a single NSSplitView with N children
            let flatChildren = flattenSameDirection(node, direction: direction)
            let split = HarnessSplitView()
            split.dividerStyle = .thin
            split.isVertical = direction == .horizontal
            split.tabID = tabID
            split.direction = direction
            if flatChildren.count == 2 {
                split.firstPaneID = firstLeafID(first)
                split.secondPaneID = firstLeafID(second)
                split.ratio = ratio
            } else {
                split.ratio = nil  // signal: distribute equally among N children
            }
            split.delegate = split
            split.translatesAutoresizingMaskIntoConstraints = false

            parent.addSubview(split)
            NSLayoutConstraint.activate([
                split.topAnchor.constraint(equalTo: parent.topAnchor),
                split.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                split.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
                split.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            ])

            for child in flatChildren {
                let container = NSView()
                container.autoresizingMask = [.width, .height]
                split.addSubview(container)
                build(node: child, cwd: cwd, into: container)
            }
        }
    }

    /// Flatten a chain of same-direction branches into a flat list of child nodes.
    /// e.g., branch(H, branch(H, L1, L2), L3) → [L1, L2, L3]
    /// Different-direction branches are kept as single nodes in the list.
    private func flattenSameDirection(_ node: PaneNode, direction: SplitDirection) -> [PaneNode] {
        switch node {
        case .leaf:
            return [node]
        case let .branch(d, _, first, second) where d == direction:
            return flattenSameDirection(first, direction: direction) + flattenSameDirection(second, direction: direction)
        default:
            return [node]
        }
    }

    /// Representative leaf of a subtree (its first leaf in traversal order). Paired
    /// across both children, it uniquely identifies a branch for ratio persistence.
    private func firstLeafID(_ node: PaneNode) -> PaneID? {
        switch node {
        case let .leaf(leaf): return leaf.id
        case let .branch(_, _, first, _): return firstLeafID(first)
        }
    }
}

/// Transparent overlay that passes all hits through to the view behind it,
/// except for clicks that land on one of its subviews (the split buttons).
@MainActor
private final class HitTestPassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

/// CMUX-style split buttons: small icon buttons at the bottom-right corner of each pane.
@MainActor
private final class PaneSplitButtonsView: NSView {
    private let tabID: TabID
    private let paneID: PaneID
    private let stack = NSStackView()

    init(tabID: TabID, paneID: PaneID) {
        self.tabID = tabID
        self.paneID = paneID
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        layer?.cornerRadius = 6
        layer?.zPosition = 1000

        stack.orientation = .horizontal
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let splitRight = makeButton("square.split.2x1", tooltip: "Split Right (⌘D)", action: #selector(splitH))
        let splitDown = makeButton("square.split.1x2", tooltip: "Split Down (⌘⇧D)", action: #selector(splitV))
        let closeBtn = makeButton("xmark", tooltip: "Close Pane (⌥⇧⌘W)", action: #selector(closePane))
        stack.addArrangedSubview(splitRight)
        stack.addArrangedSubview(splitDown)
        stack.addArrangedSubview(closeBtn)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
        ])

        alphaValue = 1
    }

    private func makeButton(_ symbol: String, tooltip: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: .zero)
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        btn.imagePosition = .imageOnly
        btn.toolTip = tooltip
        btn.target = self
        btn.action = action
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 24).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        btn.contentTintColor = .white.withAlphaComponent(0.7)
        return btn
    }

    @objc private func splitH() {
        SessionCoordinator.shared.splitActivePane(direction: .horizontal)
    }

    @objc private func splitV() {
        SessionCoordinator.shared.splitActivePane(direction: .vertical)
    }

    @objc private func closePane() {
        SessionCoordinator.shared.killPane(paneID: paneID)
    }
}

/// NSSplitView for terminal panes: tints its divider to the theme, widens the grab
/// (and cursor) area beyond the 1px thin divider, and persists user divider drags to
/// the daemon so split ratios survive relaunch. Acts as its own delegate.
@MainActor
final class HarnessSplitView: NSSplitView, NSSplitViewDelegate {
    var tabID: TabID?
    var firstPaneID: PaneID?
    var secondPaneID: PaneID?
    var ratio: Double?
    var direction: SplitDirection?
    private var appliedRatio = false
    private var isApplyingPositions = false
    private var ratioDebounce: DispatchWorkItem?

    override var dividerColor: NSColor { HarnessChrome.current.border }

    override func layout() {
        super.layout()
        guard !appliedRatio, !isApplyingPositions else { return }
        let count = subviews.count
        guard count >= 2 else { return }
        let totalSize = (direction == .horizontal) ? frame.width : frame.height
        guard totalSize > 0 else { return }

        isApplyingPositions = true
        defer { isApplyingPositions = false }
        appliedRatio = true

        if ratio == nil {
            // N children: distribute equally
            let paneSize = totalSize / CGFloat(count)
            for i in 0..<(count - 1) {
                setPosition(paneSize * CGFloat(i + 1), ofDividerAt: i)
            }
        } else if let ratio {
            // 2 children: use stored ratio
            let position = totalSize * ratio
            if position > 0, position < totalSize {
                setPosition(position, ofDividerAt: 0)
            }
        }
        subviews.forEach {
            $0.needsLayout = true
            $0.layoutSubtreeIfNeeded()
        }
    }

    override func adjustSubviews() {
        guard !isApplyingPositions else { super.adjustSubviews(); return }
        super.adjustSubviews()
    }

    func splitView(
        _ splitView: NSSplitView,
        effectiveRect proposedEffectiveRect: NSRect,
        forDrawnRect drawnRect: NSRect,
        ofDividerAt dividerIndex: Int
    ) -> NSRect {
        // Widen the interactive/cursor zone past the 1px thin divider. NSSplitView
        // shows the resize cursor over the effective rect, so this covers the cursor.
        var rect = proposedEffectiveRect
        if isVertical { rect.size.width = 8 } else { rect.size.height = 8 }
        return rect
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        // The divider-index key is present only when the user dragged a divider —
        // skip programmatic setPosition and window/layout resizes.
        guard notification.userInfo?["NSSplitViewDividerIndex"] != nil else { return }
        persistRatio()
    }

    private func persistRatio() {
        guard let tabID, let firstPaneID, let secondPaneID, subviews.count >= 2 else { return }
        let total = isVertical ? bounds.width : bounds.height
        guard total > 1 else { return }
        let firstSize = isVertical ? subviews[0].frame.width : subviews[0].frame.height
        let ratio = Double(firstSize / total)
        // Coalesce the stream of drag events into one write after the drag settles.
        ratioDebounce?.cancel()
        let work = DispatchWorkItem {
            MainActor.assumeIsolated {
                SessionCoordinator.shared.setSplitRatio(
                    tabID: tabID,
                    firstPaneID: firstPaneID,
                    secondPaneID: secondPaneID,
                    ratio: ratio
                )
            }
        }
        ratioDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}

// MARK: - Draggable divider between file editor and terminal

@MainActor
private final class EditorDividerView: NSView {
    weak var widthConstraint: NSLayoutConstraint?
    weak var containerView: NSView?
    private var dragStartX: CGFloat = 0
    private var dragStartWidth: CGFloat = 0

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartX = event.locationInWindow.x
        dragStartWidth = widthConstraint?.constant ?? 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard let wc = widthConstraint, let container = containerView else { return }
        let delta = event.locationInWindow.x - dragStartX
        let maxWidth = container.bounds.width - 200
        let newWidth = min(max(200, dragStartWidth + delta), maxWidth)
        wc.constant = newWidth
    }
}
