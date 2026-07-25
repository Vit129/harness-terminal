import AppKit
import KouenCore
import KouenTerminalKit
import KouenLSP

@MainActor
final class ContentAreaViewController: NSViewController, TerminalTabBarDelegate {
    private let titleStrip = WindowTitleStripView()
    private let tabBar = TerminalTabBarView()
    private let terminalHost = NSView()
    private let sidebarToggle = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
    private let tabBarDivider = KouenDesign.divider()
    private var sidebarToggleConstraint: NSLayoutConstraint?

    private nonisolated(unsafe) var copySelectionMonitor: Any?
    private var pasteboardCountAtMouseDown: Int = NSPasteboard.general.changeCount

    // Coordinators — initialized in viewDidLoad once views exist.
    private var filePreview: FilePreviewCoordinator!
    private var paneLifecycle: PaneLifecycleManager!

    // MARK: - Pass-throughs (callers see these on ContentAreaVC unchanged)

    var isFileEditorVisible: Bool { filePreview.isFileEditorVisible }
    var activeDiagnostics: [LSPDiagnostic] { filePreview.activeDiagnostics }
    var currentFilePath: String? { filePreview.currentFilePath }

    func openFileTab(path: String) { filePreview.openFileTab(path: path) }
    func resolveTerminalLinkPath(_ path: String) -> String? { filePreview.resolveTerminalLinkPath(path) }
    func closeFileTab(id: FileTabID) { filePreview.closeFileTab(id: id) }
    func selectFileTab(id: FileTabID) { filePreview.selectFileTab(id: id) }
    func navigateCurrentFile(line: Int, column: Int) { filePreview.navigateCurrentFile(line: line, column: column) }
    func showFileEditorSplit() { filePreview.showFileEditorSplit() }
    func hideFileEditorSplit() { filePreview.hideFileEditorSplit() }
    func activateTerminalTab() { filePreview.activateTerminalTab() }
    func paneShell(for paneID: PaneID) -> NSView? { paneLifecycle.paneShell(for: paneID) }
    func collectTerminalHosts() -> [SurfaceID: TerminalHostView] { paneLifecycle.paneContainer?.collectTerminalHosts() ?? [:] }

    deinit {
        if let monitor = copySelectionMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override func loadView() {
        view = NSView()
        KouenDesign.makeClear(view)
    }

    func applyChrome() {
        KouenDesign.makeClear(view)
        refreshTerminalHostFill()
        filePreview.refreshEditorPanelFill()
        titleStrip.applyColors()
        tabBar.applyChrome()
        paneLifecycle.paneContainer?.applyChrome()
        updateSidebarToggleConstraints()
    }

    private func updateTitleStripPath() {
        let snap = SessionCoordinator.shared.snapshot
        guard let tab = snap.activeWorkspace?.activeTab else {
            titleStrip.setPath("")
            return
        }
        let agentActive = tab.effectiveAgentKind != nil
        titleStrip.setPath(agentActive ? "" : tab.cwd, gitBranch: tab.gitBranch)
    }

    private func refreshTerminalHostFill() {
        terminalHost.wantsLayer = true
        let opacity = KouenSettings.clampedOpacity(SessionCoordinator.shared.settings.backgroundOpacity)
        if opacity >= 1 {
            terminalHost.layer?.backgroundColor = KouenChrome.current.terminalBackground.cgColor
        } else {
            let isDark = KouenChrome.current.isDark
            let minTint: CGFloat = isDark ? 0.3 : 0.5
            let effectiveAlpha = max(CGFloat(opacity), minTint)
            terminalHost.layer?.backgroundColor = KouenChrome.current.terminalBackground
                .withAlphaComponent(effectiveAlpha).cgColor
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        filePreview = FilePreviewCoordinator(containerView: view, terminalHost: terminalHost, tabBarDivider: tabBarDivider)
        paneLifecycle = PaneLifecycleManager(terminalHost: terminalHost, containerView: view)

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
            titleStrip.topAnchor.constraint(equalTo: view.topAnchor),
            titleStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleStrip.heightAnchor.constraint(equalToConstant: WindowTitleStripView.height),

            tabBar.topAnchor.constraint(equalTo: titleStrip.bottomAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tabBarDivider.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            tabBarDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarDivider.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            terminalHost.topAnchor.constraint(equalTo: tabBarDivider.bottomAnchor),
            terminalHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            terminalHost.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        filePreview.setupInitialLeadingConstraint()

        NotificationCenter.default.addObserver(
            self, selector: #selector(snapshotChanged(_:)),
            name: NotificationBus.shared.snapshotChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(viQuitCommand(_:)),
            name: .viQuitCommand, object: nil
        )
        NotificationCenter.default.addObserver(self, selector: #selector(viOpenFileCommand(_:)), name: .viOpenFileCommand, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viSplitFileCommand(_:)), name: .viSplitFileCommand, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viFindFileCommand(_:)), name: .viFindFileCommand, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viNextBufferCommand(_:)), name: .viNextBufferCommand, object: nil)
        installCopySelectionToast()
        reloadTabBar()
        filePreview.switchToTab(tabID: SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.id.uuidString)
        filePreview.restoreEditorState()
    }

    private func installCopySelectionToast() {
        copySelectionMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            guard self.viewIfLoaded?.window != nil else { return event }
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
        guard paneLifecycle.paneContainer == nil || paneLifecycle.pendingReload != nil else { return }
        guard terminalHost.bounds.width > 1, terminalHost.bounds.height > 1 else { return }
        let force = paneLifecycle.pendingReload ?? true
        paneLifecycle.pendingReload = nil
        paneLifecycle.reloadIfNeeded(force: force)
    }

    // MARK: - Vi Notification Handlers

    @objc private func viQuitCommand(_ note: Notification) {
        filePreview.handleViQuit()
    }

    @objc private func viOpenFileCommand(_ note: Notification) {
        guard let path = note.userInfo?["path"] as? String else { return }
        filePreview.handleViOpen(path: path)
    }

    @objc private func viSplitFileCommand(_ note: Notification) {
        guard let path = note.userInfo?["path"] as? String, !path.isEmpty else { return }
        let direction = (note.userInfo?["direction"] as? String) == "vertical"
            ? SplitDirection.vertical : SplitDirection.horizontal
        filePreview.handleViSplit(path: path, direction: direction)
    }

    @objc private func viFindFileCommand(_ note: Notification) {
        guard let query = note.userInfo?["query"] as? String, !query.isEmpty else { return }
        filePreview.handleViFind(query: query)
    }

    @objc private func viNextBufferCommand(_ note: Notification) {
        guard let delta = note.userInfo?["delta"] as? Int else { return }
        filePreview.handleViNextBuffer(delta: delta)
    }

    // MARK: - Snapshot

    @objc private func snapshotChanged(_ note: Notification) {
        // Phase-1 revision pings carry no typed payload; skip until DaemonSyncService applies
        // the snapshot and re-posts with real flags (Phase 2). Acting on Phase 1 causes a full
        // reload with worst-case fallback flags before the data is actually updated.
        guard note.userInfo?["payload"] is SnapshotChangedPayload else { return }
        let payload = note.snapshotPayload
        let structureChanged = payload.structureChanged
        let metadataOnly = payload.metadataOnly
        filePreview.switchToTab(tabID: SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.id.uuidString)
        if metadataOnly && !structureChanged {
            refreshTabBarMetadata()
            return
        }
        reloadTabBar()
        if structureChanged {
            let snap = SessionCoordinator.shared.snapshot
            let liveTabIDs = Set(snap.workspaces.flatMap { ws in
                ws.sessions.flatMap { $0.tabs.map { $0.id.uuidString } }
            })
            paneLifecycle.pruneCache(keepingTabIDs: liveTabIDs)
            filePreview.pruneFileTabManagers(keepingTabIDs: liveTabIDs)
        }
        paneLifecycle.reloadIfNeeded(force: structureChanged)
    }

    // MARK: - Tab Bar

    func reloadTabBar() {
        let snap = SessionCoordinator.shared.snapshot
        guard let workspace = snap.activeWorkspace else { return }
        let sessionTabs = workspace.sessions.compactMap { session -> Tab? in
            guard var tab = session.activeTab ?? session.tabs.first else { return nil }
            let kind = BoardModel.columnKind(for: tab)
            switch kind {
            case .needsAttention: tab.status = .waiting
            case .running:        tab.status = .running
            case .done:           tab.status = .done
            case .error:          tab.status = .error
            case .idle:           tab.status = .idle
            }
            return tab
        }
        let activeTabID = workspace.activeSession?.activeTab?.id ?? workspace.activeSession?.tabs.first?.id
        tabBar.reload(tabs: sessionTabs, activeTabID: activeTabID)
        updateTitleStripPath()
    }

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

    // MARK: - TerminalTabBarDelegate

    func tabBarDidSelect(tabID: TabID) {
        let coordinator = SessionCoordinator.shared
        guard let workspaceID = coordinator.snapshot.activeWorkspaceID,
              let workspace = coordinator.snapshot.activeWorkspace,
              let session = workspace.sessions.first(where: { $0.tabs.contains(where: { $0.id == tabID }) })
        else { return }
        coordinator.selectSession(workspaceID: workspaceID, sessionID: session.id)
    }

    func tabBarDidRequestNewTab() {
        let coordinator = SessionCoordinator.shared
        coordinator.syncFromDaemon()
        guard let workspaceID = coordinator.snapshot.activeWorkspaceID else { return }
        coordinator.addSession(to: workspaceID)
    }

    func tabBarDidRequestClose(tabID: TabID) {
        let coordinator = SessionCoordinator.shared
        guard let workspaceID = coordinator.snapshot.activeWorkspaceID,
              let workspace = coordinator.snapshot.activeWorkspace,
              let session = workspace.sessions.first(where: { $0.tabs.contains(where: { $0.id == tabID }) })
        else { return }
        coordinator.selectSession(workspaceID: workspaceID, sessionID: session.id)
        coordinator.closeActivePane()
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
        let coordinator = SessionCoordinator.shared
        let current = coordinator.snapshot.workspaces
            .flatMap(\.sessions).flatMap(\.tabs)
            .first(where: { $0.id == tabID })?.persistent ?? false
        coordinator.requestDaemon(.setTabPersistent(tabID: tabID, persistent: !current))
    }
}

// MARK: - PaneContainerView

@MainActor
final class PaneContainerView: NSView {
    private let coordinator = SessionCoordinator.shared
    private let tabID: TabID?
    private var existingHosts: [SurfaceID: TerminalHostView]
    private let browserController: BrowserIntegrationController

    init(node: PaneNode, cwd: String, themeName: String, existingHosts: [SurfaceID: TerminalHostView] = [:], existingBrowserPanes: [PaneID: BrowserPaneView] = [:]) {
        self.existingHosts = existingHosts
        self.browserController = BrowserIntegrationController(existingPanes: existingBrowserPanes)
        self.tabID = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.id
        super.init(frame: .zero)
        KouenDesign.makeClear(self)
        build(node: node, cwd: cwd, into: self)
        // Unclaimed entries are closed panes or other tabs' surfaces — already held by
        // ZombieHoldRegistry for 1.5s. Drop the strong ref here so they can deallocate.
        self.existingHosts.removeAll()
    }

    func findDescendant(withIdentifier id: NSUserInterfaceItemIdentifier) -> NSView? {
        func search(_ view: NSView) -> NSView? {
            if view.identifier == id { return view }
            for child in view.subviews {
                if let found = search(child) { return found }
            }
            return nil
        }
        return search(self)
    }

    func applyChrome() {
        KouenDesign.makeClear(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func collectTerminalHosts() -> [SurfaceID: TerminalHostView] {
        var result: [SurfaceID: TerminalHostView] = [:]
        collectHosts(in: self, into: &result)
        return result
    }

    func collectBrowserPanes() -> [PaneID: BrowserPaneView] {
        browserController.collectBrowserPanes(in: self)
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

    func detachHostsOnly() {
        detachHosts(in: self)
        browserController.detachBrowsers(in: self)
    }

    private func detachHosts(in view: NSView) {
        for sub in view.subviews {
            if let host = sub as? TerminalHostView {
                host.resignIfFirstResponder()
                host.stopSurfaceDisplayLink()
                host.removeFromSuperview()
                ZombieHoldRegistry.shared.hold(host)
            } else {
                detachHosts(in: sub)
            }
        }
    }

    func refreshChrome(snapshot: SessionSnapshot) {
        applyChrome()
    }

    private func build(node: PaneNode, cwd: String, into parent: NSView) {
        switch node {
        case let .browser(bl):
            browserController.buildNode(bl, into: parent)

        case let .leaf(leaf):
            let paneShell = NSView()
            KouenDesign.makeClear(paneShell)
            paneShell.translatesAutoresizingMaskIntoConstraints = false
            paneShell.identifier = NSUserInterfaceItemIdentifier("pane-\(leaf.id.uuidString)")
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
            let flatChildren = flattenSameDirection(node, direction: direction)
            let split = KouenSplitView()
            split.dividerStyle = .thin
            split.isVertical = direction == .horizontal
            split.tabID = tabID
            split.direction = direction
            if flatChildren.count == 2 {
                split.firstPaneID = firstLeafID(first)
                split.secondPaneID = firstLeafID(second)
                split.ratio = ratio
            } else {
                split.ratio = nil
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

    private func firstLeafID(_ node: PaneNode) -> PaneID? {
        switch node {
        case let .leaf(leaf): return leaf.id
        case let .browser(leaf): return leaf.id
        case let .branch(_, _, first, _): return firstLeafID(first)
        }
    }
}

// MARK: - HitTestPassthroughView

@MainActor
private final class HitTestPassthroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

// MARK: - PaneSplitButtonsView

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

    private var paneTrackingArea: NSTrackingArea?
    private weak var paneTrackingOwner: NSView?

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        layer?.cornerRadius = 6
        layer?.zPosition = 1000

        stack.orientation = .horizontal
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let dragGrip = PaneDragGripView(paneID: paneID)
        dragGrip.translatesAutoresizingMaskIntoConstraints = false
        dragGrip.widthAnchor.constraint(equalToConstant: 24).isActive = true
        dragGrip.heightAnchor.constraint(equalToConstant: 22).isActive = true
        let splitRight = makeButton("rectangle.righthalf.inset.filled", tooltip: "Split Right (⌘D)", action: #selector(doSplitRight))
        let splitDown = makeButton("rectangle.bottomhalf.inset.filled", tooltip: "Split Down (⌘⇧D)", action: #selector(doSplitDown))
        let openBrowser = makeButton("safari", tooltip: "Open Browser Pane (⌘B)", action: #selector(openBrowserPane))
        let closeBtn = makeButton("xmark", tooltip: "Close Pane (⌥⇧⌘W)", action: #selector(closePane))

        stack.addArrangedSubview(dragGrip)
        stack.addArrangedSubview(splitRight)
        stack.addArrangedSubview(splitDown)
        stack.addArrangedSubview(openBrowser)
        stack.addArrangedSubview(closeBtn)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
        ])
        // Keep alphaValue = 1 so macOS 26 hitTest (which skips alpha < 0.01 views) never
        // excludes this overlay. Visual fade is driven by layer.opacity via Core Animation.
        layer?.opacity = 0
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if let old = paneTrackingArea {
            paneTrackingOwner?.removeTrackingArea(old)
            paneTrackingArea = nil
            paneTrackingOwner = nil
        }
        guard let parent = superview else { return }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        parent.addTrackingArea(area)
        paneTrackingArea = area
        paneTrackingOwner = parent
    }

    // alphaValue stays 1 so paneShell's hitTest (macOS 26 skips alpha<0.01 subviews) always
    // calls us. We then decide visibility from the presentation layer's opacity — this
    // correctly reflects in-progress CA animations and keeps clicks from falling into the
    // invisible overlay when it's faded out.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let currentOpacity = layer?.presentation()?.opacity ?? layer?.opacity ?? 0
        #if DEBUG
        if currentOpacity <= 0.01 {
            print("[DBG-BTN] hitTest BLOCKED opacity=\(currentOpacity)")
        }
        #endif
        guard currentOpacity > 0.01 else { return nil }
        return super.hitTest(point)
    }

    override func mouseEntered(with event: NSEvent) {
        #if DEBUG
        print("[DBG-BTN] mouseEntered — setting opacity=1")
        #endif
        guard window != nil else { return }
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = layer?.presentation()?.opacity ?? layer?.opacity ?? 0
        anim.toValue = Float(1)
        anim.duration = 0.15
        layer?.add(anim, forKey: "fade")
        layer?.opacity = 1
    }

    override func mouseExited(with event: NSEvent) {
        guard window != nil else { return }
        guard !PaneDragController.shared.isDragging else { return }
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = layer?.presentation()?.opacity ?? layer?.opacity ?? 1
        anim.toValue = Float(0)
        anim.duration = 0.25
        layer?.add(anim, forKey: "fade")
        layer?.opacity = 0
    }

    private func makeButton(_ symbol: String, tooltip: String, action: Selector) -> NSButton {
        let btn = PaneHoverButton(frame: .zero)
        btn.wantsLayer = true
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.isTransparent = false
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

    @objc private func doSplitRight() { SessionCoordinator.shared.splitActivePane(direction: .horizontal) }
    @objc private func doSplitDown() { SessionCoordinator.shared.splitActivePane(direction: .vertical) }
    @objc private func openBrowserPane() {
        let home = SessionCoordinator.shared.settings.browserHomePage
        SessionCoordinator.shared.splitPaneCoordinator.openBrowserPane(
            url: URL(string: home) ?? URL(string: "https://www.google.com")!,
            direction: .horizontal
        )
    }
    @objc private func closePane() { SessionCoordinator.shared.killPane(paneID: paneID) }
}

private final class PaneHoverButton: NSButton {
    private var trackingArea_: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea_ { removeTrackingArea(old) }
        guard window != nil else { trackingArea_ = nil; return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea_ = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard window != nil else { return }
        contentTintColor = .white
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        layer?.cornerRadius = 4
    }

    override func mouseExited(with event: NSEvent) {
        guard window != nil else { return }
        contentTintColor = .white.withAlphaComponent(0.7)
        layer?.backgroundColor = nil
    }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard bounds.contains(loc), let target = target, let action = action else {
            super.mouseUp(with: event)
            return
        }
        NSApp.sendAction(action, to: target, from: self)
    }
}

// MARK: - PaneDragGripView

@MainActor
private final class PaneDragGripView: NSView {
    private let paneID: PaneID
    private var dragStarted = false

    init(paneID: PaneID) {
        self.paneID = paneID
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 4
        toolTip = "Drag to reorder pane"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let color = NSColor.white.withAlphaComponent(0.7)
        ctx.setFillColor(color.cgColor)
        let dotSize: CGFloat = 2.5
        let spacingX: CGFloat = 5
        let spacingY: CGFloat = 4
        let startX = (bounds.width - spacingX * 2) / 2
        let startY = (bounds.height - spacingY * 2) / 2
        for row in 0..<3 {
            for col in 0..<2 {
                let x = startX + CGFloat(col) * spacingX
                let y = startY + CGFloat(row) * spacingY
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
            }
        }
    }

    override func mouseDown(with event: NSEvent) { dragStarted = false }

    override func mouseDragged(with event: NSEvent) {
        if !dragStarted {
            dragStarted = true
            guard let paneShell = superview?.superview else { return }
            PaneDragController.shared.beginDrag(paneID: paneID, from: paneShell)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        NSCursor.openHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
        NSCursor.pop()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        guard window != nil else { return }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        ))
    }
}

// MARK: - KouenSplitView

@MainActor
final class KouenSplitView: NSSplitView, NSSplitViewDelegate {
    var tabID: TabID?
    var firstPaneID: PaneID?
    var secondPaneID: PaneID?
    var ratio: Double?
    var direction: SplitDirection?
    private var appliedRatio = false
    private var isApplyingPositions = false
    private var ratioDebounce: DispatchWorkItem?

    override var dividerColor: NSColor { KouenChrome.current.paneDivider }
    override var dividerThickness: CGFloat { KouenDesign.Divider.thickness }

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
            let paneSize = totalSize / CGFloat(count)
            for i in 0..<(count - 1) {
                setPosition(paneSize * CGFloat(i + 1), ofDividerAt: i)
            }
        } else if let ratio {
            let position = totalSize * ratio
            if position > 0, position < totalSize {
                setPosition(position, ofDividerAt: 0)
            }
        }
        subviews.forEach {
            $0.needsLayout = true
            $0.layoutSubtreeIfNeeded()
        }
        updateTrackingAreas()
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
        var rect = proposedEffectiveRect
        if isVertical { rect.size.width = 8 } else { rect.size.height = 8 }
        return rect
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard notification.userInfo?["NSSplitViewDividerIndex"] != nil else { return }
        persistRatio()
        // Refresh corner handle position for self and any enclosing outer split.
        updateTrackingAreas()
        (superview?.superview as? KouenSplitView)?.updateTrackingAreas()
    }

    // MARK: — Corner handle (3-way intersection drag)

    private struct CornerInfo {
        let outerDividerIndex: Int
        weak var innerSplit: KouenSplitView?
        let innerDividerIndex: Int
        let rect: NSRect  // in self's coordinate space
    }

    private var _cornerInfo: CornerInfo?
    private var _cornerTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let a = _cornerTrackingArea { removeTrackingArea(a); _cornerTrackingArea = nil }
        guard let info = buildCornerInfo() else { _cornerInfo = nil; return }
        _cornerInfo = info
        let area = NSTrackingArea(
            rect: info.rect,
            options: [.cursorUpdate, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        _cornerTrackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let info = _cornerInfo, info.rect.contains(p) {
            NSCursor.crosshair.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let info = _cornerInfo, info.rect.contains(p), let inner = info.innerSplit else {
            super.mouseDown(with: event)
            return
        }
        runCornerDrag(startEvent: event, inner: inner,
                      outerIdx: info.outerDividerIndex, innerIdx: info.innerDividerIndex)
    }

    private func runCornerDrag(startEvent: NSEvent, inner: KouenSplitView, outerIdx: Int, innerIdx: Int) {
        // Positions measured from leading edge: left for isVertical=true, top for isVertical=false.
        let outerStart: CGFloat = isVertical
            ? subviews[outerIdx].frame.maxX
            : subviews[outerIdx].frame.height
        let innerStart: CGFloat = inner.isVertical
            ? inner.subviews[innerIdx].frame.maxX
            : inner.subviews[innerIdx].frame.height
        let startPt = convert(startEvent.locationInWindow, from: nil)

        while true {
            guard let e = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { break }
            if e.type == .leftMouseUp { break }
            let cur = convert(e.locationInWindow, from: nil)
            let dx = cur.x - startPt.x
            // dy is positive-up in AppKit; "from top" = innerStart - dy (down drag = smaller dy = larger from-top)
            let dy = cur.y - startPt.y
            setPosition(isVertical ? outerStart + dx : outerStart - dy, ofDividerAt: outerIdx)
            inner.setPosition(inner.isVertical ? innerStart + dx : innerStart - dy, ofDividerAt: innerIdx)
        }
    }

    private func buildCornerInfo() -> CornerInfo? {
        guard subviews.count >= 2 else { return nil }
        for i in subviews.indices {
            // Walk one level into each container to find a nested opposite-axis KouenSplitView.
            guard let inner = subviews[i].subviews.first(where: { $0 is KouenSplitView }) as? KouenSplitView,
                  inner.isVertical != self.isVertical,
                  inner.subviews.count >= 2 else { continue }

            // Outer divider is between subviews[outerDividerIndex] and subviews[outerDividerIndex+1].
            let outerDividerIndex = max(0, i - 1)
            guard outerDividerIndex + 1 < subviews.count else { continue }

            let cornerX: CGFloat
            let cornerY: CGFloat

            if isVertical {
                // Outer splits left/right — divider is vertical.
                cornerX = (subviews[outerDividerIndex].frame.maxX + subviews[outerDividerIndex + 1].frame.minX) / 2
                // Inner splits top/bottom: divider is the gap between inner.subviews[0] (top) and [1] (bottom).
                // In AppKit Y-up, top pane's bottom edge = subviews[0].frame.minY.
                let divCenterInInner = (inner.subviews[0].frame.minY + inner.subviews[1].frame.maxY) / 2
                cornerY = inner.convert(NSPoint(x: 0, y: divCenterInInner), to: self).y
            } else {
                // Outer splits top/bottom — divider is horizontal.
                // In AppKit Y-up, top subview's bottom = subviews[outerDividerIndex].frame.minY.
                cornerY = (subviews[outerDividerIndex].frame.minY + subviews[outerDividerIndex + 1].frame.maxY) / 2
                // Inner splits left/right.
                let divCenterInInner = (inner.subviews[0].frame.maxX + inner.subviews[1].frame.minX) / 2
                cornerX = inner.convert(NSPoint(x: divCenterInInner, y: 0), to: self).x
            }

            let size: CGFloat = 20
            return CornerInfo(
                outerDividerIndex: outerDividerIndex,
                innerSplit: inner,
                innerDividerIndex: 0,
                rect: NSRect(x: cornerX - size / 2, y: cornerY - size / 2, width: size, height: size)
            )
        }
        return nil
    }

    private func persistRatio() {
        guard let tabID, let firstPaneID, let secondPaneID, subviews.count >= 2 else { return }
        let total = isVertical ? bounds.width : bounds.height
        guard total > 1 else { return }
        let firstSize = isVertical ? subviews[0].frame.width : subviews[0].frame.height
        let ratio = Double(firstSize / total)
        ratioDebounce?.cancel()
        let work = DispatchWorkItem {
            Task { @MainActor in
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

// MARK: - EditorDividerView

@MainActor
final class EditorDividerView: NSView {
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
