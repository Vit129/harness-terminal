import AppKit
import KouenCore
import SwiftUI

/// Left session rail — workspace pill, sessions list, and a quiet footer.
@MainActor
final class KouenSidebarPanelViewController: NSViewController {
    private let chromeHeader = SidebarTitlebarHeaderView()
    let workspacePillModel = WorkspacePillModel()
    lazy var workspacePill: NSView = NSHostingView(
        rootView: WorkspacePillView(
            model: workspacePillModel,
            onClick: { [weak self] in self?.showWorkspaceMenu() },
            onMoreClick: { [weak self] in
                guard let self else { return }
                self.showActiveWorkspaceActions(from: self.workspacePill)
            }
        )
    )
    /// Collapses the sidebar (⌘\). Lives at the sidebar's top-trailing edge, against
    /// the divider; when the sidebar is collapsed it's gone with it (re-open via ⌘\).
    /// Flat `.plain` style + 30×30 so it matches the neighbouring notification bell.
    private let sidebarToggleButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
    private var tabBarHostingView: NSView!
    let sidebarSectionModel = SidebarSectionModel()
    private var sectionLabelHostingView: NSView!
    let fileTreeView = WorkspaceFileTreeView()
    private let fileViewerVC = FileViewerViewController()
    let gitPanelView = GitPanelView()
    private lazy var boardVC = BoardViewController()
    let sidebarFooterModel = SidebarFooterModel()
    private var footerHostingView: NSView!
    let sidebarListModel = SidebarListModel()
    private var sessionHostingView: NSView?
    var workspaces: [Workspace] = []
    var sessions: [SessionGroup] = []
    var activeWorkspaceID: WorkspaceID?
    private var activeSessionID: SessionID?
    var workspaceDropdown: WorkspaceSwitcherPanelView?
    nonisolated(unsafe) var workspaceDropdownMonitor: Any?
    /// Last session ID sent to fileTreeView so we can detect session changes even
    /// when the CWD is the same (e.g. two sessions sharing the same repo root).
    var lastFileTreeSessionID: SessionID?
    var lastFileTreeGitBranch: String?
    var lastFileTreeCWD: String?
    private var lastRepoHeaderPath = ""
    private var lastRepoHeaderFetch = Date.distantPast

    deinit {
        if let monitor = workspaceDropdownMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = notificationsDropdownMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = agentsInboxMonitor { NSEvent.removeMonitor(monitor) }
    }

    override func loadView() {
        let root = NSView()
        KouenDesign.applySidebarChrome(to: root)
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupChromeHeader()
        setupWorkspaceBar()
        setupSidebarTabs()
        setupSectionLabel()
        setupFooterView()
        setupSessionList()
        setupFileTree()
        setupFileViewer()
        setupGitPlaceholder()
        setupBoardView()
        sidebarSectionModel.onToggleBoardView = { [weak self] in
            guard let self else { return }
            sidebarSectionModel.showBoardView.toggle()
            selectSidebarTab(index: sidebarSectionModel.selectedTab)
        }
        selectSidebarTab(index: 0)
        reload()
        applyChromeColors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshMetadata),
            name: Notification.Name("KouenActiveTabGitBranchDidChange"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viViewFileCommand(_:)),
            name: .viViewFileCommand,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenGitPanel(_:)),
            name: .kouenOpenGitPanel,
            object: nil
        )
    }

    func applyChromeColors() {
        KouenDesign.applySidebarChrome(to: view)
        KouenDesign.makeClear(chromeHeader)
        KouenDesign.makeClear(gitPanelView)
        workspacePillModel.chromeEpoch += 1
        sidebarSectionModel.chromeEpoch += 1
        sidebarFooterModel.chromeEpoch += 1

        let sidebarOnRight = SessionCoordinator.shared.settings.sidebarOnRight
        let symbol = sidebarOnRight ? "sidebar.right" : "sidebar.left"
        sidebarToggleButton.setSymbol(symbol, accessibilityDescription: "Toggle sidebar", pointSize: 13, weight: .medium)
        sidebarToggleButton.applyChrome()

        dismissWorkspaceDropdown()
    }

    private func setupChromeHeader() {
        chromeHeader.translatesAutoresizingMaskIntoConstraints = false
        KouenDesign.makeClear(chromeHeader)
        view.addSubview(chromeHeader)
        NSLayoutConstraint.activate([
            chromeHeader.topAnchor.constraint(equalTo: view.topAnchor),
            chromeHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chromeHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chromeHeader.heightAnchor.constraint(equalToConstant: WindowTitleStripView.height + KouenDesign.tabBarHeight),
        ])
    }

    /// The sidebar toggle lives in `chromeHeader` so it aligns with the window chrome.
    /// Workspaces are deliberately not surfaced here (single active workspace);
    /// the switcher machinery stays dormant so it can be re-enabled later.
    private func setupWorkspaceBar() {
        sidebarToggleButton.toolTip = "Hide sidebar (⌘\\)"
        sidebarToggleButton.target = self
        sidebarToggleButton.action = #selector(sidebarToggleClicked)
        sidebarToggleButton.translatesAutoresizingMaskIntoConstraints = false
        updateSidebarToggleMenu()

        chromeHeader.addSubview(sidebarToggleButton)

        NSLayoutConstraint.activate([
            // Toggle pinned to the top chrome, against the divider; 30×30.
            sidebarToggleButton.trailingAnchor.constraint(equalTo: chromeHeader.trailingAnchor, constant: -KouenDesign.horizontalInset),
            sidebarToggleButton.centerYAnchor.constraint(
                equalTo: chromeHeader.topAnchor,
                constant: WindowTitleStripView.height + KouenDesign.tabBarHeight / 2
            ),
            sidebarToggleButton.widthAnchor.constraint(equalToConstant: 30),
            sidebarToggleButton.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    @objc private func sidebarToggleClicked() {
        (view.window?.contentViewController as? MainSplitViewController)?.toggleSidebar()
    }

    private func updateSidebarToggleMenu() {
        let menu = NSMenu()
        let right = SessionCoordinator.shared.settings.sidebarOnRight
        let item = NSMenuItem(title: right ? "Move Sidebar to Left" : "Move Sidebar to Right", action: #selector(toggleSidebarPositionFromMenu), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        sidebarToggleButton.menu = menu
    }

    @objc func toggleSidebarPositionFromMenu() {
        (view.window?.contentViewController as? MainSplitViewController)?.toggleSidebarPosition()
        updateSidebarToggleMenu()
    }

    private var notificationsDropdown: NotificationDropdownPanelView?
    private nonisolated(unsafe) var notificationsDropdownMonitor: Any?
    private weak var notificationsDropdownPreviousResponder: NSResponder?

    func showNotificationsDropdown() {
        if notificationsDropdown != nil {
            dismissNotificationsDropdown()
            return
        }
        let coordinator = SessionCoordinator.shared
        let snapshot = coordinator.snapshot
        // Agent notifications first, then board error/needs-attention sessions
        var entries = coordinator.notificationsList()
        let agentTabIDs = Set(entries.map(\.tabID))
        for ws in snapshot.workspaces {
            for session in ws.sessions {
                for tab in session.tabs {
                    guard !agentTabIDs.contains(tab.id) else { continue }
                    let kind = BoardModel.columnKind(for: tab)
                    guard kind == .needsAttention || kind == .error else { continue }
                    let body = kind == .error ? "Exit error" : "Needs attention"
                    let entry = NotificationEntry(
                        workspaceID: ws.id,
                        workspaceName: ws.name,
                        sessionID: session.id,
                        tabID: tab.id,
                        tabTitle: tab.title.isEmpty ? tab.cwd : tab.title,
                        surfaceID: tab.id,
                        agentKind: tab.effectiveAgentKind,
                        body: body
                    )
                    entries.append(entry)
                }
            }
        }
        let dropdown = NotificationDropdownPanelView(
            entries: entries,
            onSelect: { [weak self] entry in
                self?.dismissNotificationsDropdown()
                coordinator.openNotification(entry)
            },
            onClearAll: { [weak self] in
                self?.dismissNotificationsDropdown()
                coordinator.clearAllNotifications()
            },
            onDismiss: { [weak self] in
                self?.dismissNotificationsDropdown()
            }
        )
        dropdown.alphaValue = 0
        dropdown.translatesAutoresizingMaskIntoConstraints = true
        dropdown.layer?.zPosition = 100

        // Float the panel over the window's content view rather than inside the narrow
        // sidebar: anchored to the content view it can use a comfortable fixed width and
        // overhang the terminal, fully visible. It dismisses on any outside click so it
        // needn't track resizes.
        let host = view.window?.contentView ?? view
        let width: CGFloat = 300
        let height = dropdown.preferredHeight
        let originX: CGFloat = 8
        let originY: CGFloat = host.bounds.maxY - 52 - height
        dropdown.frame = NSRect(x: originX, y: originY, width: width, height: height)
        host.addSubview(dropdown)
        notificationsDropdown = dropdown
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            dropdown.animator().alphaValue = 1
        }
        installNotificationsDropdownMonitor()
        // Take first responder so arrow keys / Enter / Escape reach the dropdown.
        // Deferred to the next run-loop turn so the view is fully inserted before
        // makeFirstResponder fires — same pattern used by picker panels elsewhere.
        notificationsDropdownPreviousResponder = view.window?.firstResponder
        DispatchQueue.main.async { [weak self, weak dropdown] in
            guard let self, let dropdown, dropdown.superview != nil else { return }
            self.view.window?.makeFirstResponder(dropdown)
        }
    }

    private func dismissNotificationsDropdown() {
        notificationsDropdown?.removeFromSuperview()
        notificationsDropdown = nil
        if let monitor = notificationsDropdownMonitor {
            NSEvent.removeMonitor(monitor)
            notificationsDropdownMonitor = nil
        }
        if let previous = notificationsDropdownPreviousResponder {
            view.window?.makeFirstResponder(previous)
            notificationsDropdownPreviousResponder = nil
        }
    }

    private func installNotificationsDropdownMonitor() {
        notificationsDropdownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let dropdown = self.notificationsDropdown else { return event }
            let point = dropdown.convert(event.locationInWindow, from: nil)
            if !dropdown.bounds.contains(point) {
                self.dismissNotificationsDropdown()
            }
            return event
        }
    }

    @objc private func agentsButtonClicked() {
        showAgentsInbox()
    }

    private var agentsInbox: AgentInboxPanelView?
    private nonisolated(unsafe) var agentsInboxMonitor: Any?

    /// Float the Agent Inbox over the window's content view, anchored just above the
    /// footer's agents button. Mirrors `showNotificationsDropdown`'s presentation so the
    /// two panels feel identical; dismisses on any outside click.
    private func showAgentsInbox() {
        if agentsInbox != nil {
            dismissAgentsInbox()
            return
        }
        let coordinator = SessionCoordinator.shared
        let inbox = AgentInboxPanelView(
            agents: coordinator.agentsList(),
            onSelect: { [weak self] agent in
                self?.dismissAgentsInbox()
                coordinator.openAgent(agent)
            }
        )
        inbox.alphaValue = 0
        inbox.translatesAutoresizingMaskIntoConstraints = true
        inbox.layer?.zPosition = 100

        let host = view.window?.contentView ?? view
        let width: CGFloat = 300
        let height = inbox.preferredHeight
        // Anchor above the footer — mirrors showNotificationsDropdown positioning.
        let footerInHost = host.convert(footerHostingView.bounds, from: footerHostingView)
        let originX: CGFloat = 8
        let originY = footerInHost.maxY + 6
        inbox.frame = NSRect(x: originX, y: originY, width: width, height: height)
        host.addSubview(inbox)
        agentsInbox = inbox
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            inbox.animator().alphaValue = 1
        }
        installAgentsInboxMonitor()
    }

    private func dismissAgentsInbox() {
        agentsInbox?.removeFromSuperview()
        agentsInbox = nil
        if let monitor = agentsInboxMonitor {
            NSEvent.removeMonitor(monitor)
            agentsInboxMonitor = nil
        }
    }

    private func installAgentsInboxMonitor() {
        agentsInboxMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let inbox = self.agentsInbox else { return event }
            let inboxPoint = inbox.convert(event.locationInWindow, from: nil)
            if inbox.bounds.contains(inboxPoint) { return event }
            // Clicks in the footer let the SwiftUI button action handle toggle.
            let footerPoint = self.footerHostingView.convert(event.locationInWindow, from: nil)
            if self.footerHostingView.bounds.contains(footerPoint) { return event }
            self.dismissAgentsInbox()
            return event
        }
    }

    private var taskDashboard: TaskDashboardView?
    private nonisolated(unsafe) var taskDashboardMonitor: Any?

    /// P40 F1-H: float the Task Dashboard over the window's content view, same
    /// anchor-above-footer presentation as `showAgentsInbox`.
    private func showTaskDashboard() {
        if taskDashboard != nil {
            dismissTaskDashboard()
            return
        }
        let coordinator = SessionCoordinator.shared
        let dashboard = TaskDashboardView(onJumpToSession: { [weak self] sessionID in
            self?.dismissTaskDashboard()
            guard let workspaceID = coordinator.snapshot.workspaces.first(where: { workspace in
                workspace.sessions.contains { $0.id == sessionID }
            })?.id else { return }
            coordinator.selectSession(workspaceID: workspaceID, sessionID: sessionID)
        })
        dashboard.alphaValue = 0
        dashboard.translatesAutoresizingMaskIntoConstraints = true
        dashboard.layer?.zPosition = 100

        let host = view.window?.contentView ?? view
        let width: CGFloat = 320
        let height = dashboard.preferredHeight
        let footerInHost = host.convert(footerHostingView.bounds, from: footerHostingView)
        let originX: CGFloat = 8
        let originY = footerInHost.maxY + 6
        dashboard.frame = NSRect(x: originX, y: originY, width: width, height: height)
        host.addSubview(dashboard)
        taskDashboard = dashboard
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            dashboard.animator().alphaValue = 1
        }
        installTaskDashboardMonitor()
    }

    private func dismissTaskDashboard() {
        taskDashboard?.removeFromSuperview()
        taskDashboard = nil
        if let monitor = taskDashboardMonitor {
            NSEvent.removeMonitor(monitor)
            taskDashboardMonitor = nil
        }
    }

    private func installTaskDashboardMonitor() {
        taskDashboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let dashboard = self.taskDashboard else { return event }
            let dashboardPoint = dashboard.convert(event.locationInWindow, from: nil)
            if dashboard.bounds.contains(dashboardPoint) { return event }
            let footerPoint = self.footerHostingView.convert(event.locationInWindow, from: nil)
            if self.footerHostingView.bounds.contains(footerPoint) { return event }
            self.dismissTaskDashboard()
            return event
        }
    }

    private func setupSectionLabel() {
        let hosting = NSHostingView(rootView: SidebarSectionLabelView(model: sidebarSectionModel))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        sectionLabelHostingView = hosting
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: chromeHeader.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func setupSidebarTabs() {
        let hosting = NSHostingView(rootView: SidebarTabBarView(
            model: sidebarSectionModel,
            onTabChange: { [weak self] index in self?.selectSidebarTab(index: index) }
        ))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        tabBarHostingView = hosting
        chromeHeader.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: chromeHeader.leadingAnchor, constant: KouenDesign.horizontalInset),
            hosting.trailingAnchor.constraint(equalTo: sidebarToggleButton.leadingAnchor, constant: -8),
            hosting.topAnchor.constraint(equalTo: chromeHeader.topAnchor, constant: WindowTitleStripView.height + 4),
            hosting.heightAnchor.constraint(equalToConstant: 26),
        ])
    }

    private func setupSessionList() {
        let listView = SidebarSessionListView(
            model: sidebarListModel,
            onSelect: { [weak self] id in
                guard let self, let wsID = self.activeWorkspaceID else { return }
                SessionCoordinator.shared.selectSession(workspaceID: wsID, sessionID: id)
            },
            onAddInGroup: { [weak self] rootPath in
                self?.addSessionInGroup(rootPath: rootPath)
            },
            onCloseSession: { [weak self] id in
                guard let self, let session = self.sessions.first(where: { $0.id == id }) else { return }
                SessionCoordinator.shared.closeSession(session)
            },
            onPRClick: { urlString in
                guard let url = URL(string: urlString) else { return }
                SessionCoordinator.shared.splitPaneCoordinator.openBrowserPane(url: url, direction: .horizontal)
            },
            onWorktreeActivate: { [weak self] entry, wsID in
                guard let wsID else { return }
                Self.recordRecentProject(entry.path)
                SessionCoordinator.shared.addSession(
                    to: wsID, cwd: entry.path,
                    name: (entry.path as NSString).lastPathComponent
                )
                self?.sidebarListModel.updateWorktrees(force: true)
            }
        )
        let hosting = NSHostingView(rootView: listView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        sessionHostingView = hosting
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: sectionLabelHostingView.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: footerHostingView.topAnchor),
        ])
    }

    private func setupFileTree() {
        fileTreeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fileTreeView)
        NSLayoutConstraint.activate([
            fileTreeView.topAnchor.constraint(equalTo: sectionLabelHostingView.bottomAnchor),
            fileTreeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fileTreeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fileTreeView.bottomAnchor.constraint(equalTo: footerHostingView.topAnchor),
        ])
        fileTreeView.onFilePreview = { [weak self] node in
            guard let self, let split = self.view.window?.contentViewController as? MainSplitViewController else { return }
            let coordinator = SessionCoordinator.shared
            let action = coordinator.settings.fileClickAction
            if action == "preview" {
                self.previewFile(path: node.path)
            } else if action == "editor" {
                split.contentVC.openFileTab(path: node.path)
            } else if action == "cat" || action == "vi" || action == "terminalOnly" {
                guard let surfaceID = coordinator.activeSurfaceID else { return }
                let cmd: String
                if action == "cat" {
                    cmd = "cat \(node.path)\r"
                } else if action == "vi" {
                    cmd = "vi \(node.path)\r"
                } else {
                    // terminalOnly does nothing on single click to prevent navigation command spam
                    return
                }
                coordinator.requestDaemon(.sendData(surfaceID: surfaceID.uuidString, data: Data(cmd.utf8)))
            } else {
                split.contentVC.openFileTab(path: node.path)
            }
        }
    }

    /// Hosted in the same area as the file tree; shown in its place when the
    /// user clicks a file (back button restores the tree).
    private func setupFileViewer() {
        addChild(fileViewerVC)
        let viewerView = fileViewerVC.view
        viewerView.translatesAutoresizingMaskIntoConstraints = false
        viewerView.isHidden = true
        view.addSubview(viewerView)
        NSLayoutConstraint.activate([
            viewerView.topAnchor.constraint(equalTo: sectionLabelHostingView.bottomAnchor),
            viewerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewerView.bottomAnchor.constraint(equalTo: footerHostingView.topAnchor),
        ])
        fileViewerVC.onBack = { [weak self] in
            guard let self else { return }
            self.fileViewerVC.view.isHidden = true
            self.fileTreeView.isHidden = false
        }
    }

    private func setupGitPlaceholder() {
        view.addSubview(gitPanelView)
        NSLayoutConstraint.activate([
            gitPanelView.topAnchor.constraint(equalTo: sectionLabelHostingView.bottomAnchor),
            gitPanelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gitPanelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gitPanelView.bottomAnchor.constraint(equalTo: footerHostingView.topAnchor),
        ])
    }

    private func setupBoardView() {
        addChild(boardVC)
        boardVC.view.translatesAutoresizingMaskIntoConstraints = false
        boardVC.view.isHidden = true
        view.addSubview(boardVC.view)
        NSLayoutConstraint.activate([
            boardVC.view.topAnchor.constraint(equalTo: sectionLabelHostingView.bottomAnchor),
            boardVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            boardVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            boardVC.view.bottomAnchor.constraint(equalTo: footerHostingView.topAnchor),
        ])
    }

    @objc private func handleOpenGitPanel(_ note: Notification) {
        let repoPath = note.userInfo?["repoPath"] as? String
        sidebarSectionModel.selectedTab = 2
        selectSidebarTab(index: 2)
        if let path = repoPath {
            gitPanelView.updateRoot(path: path)
        }
    }



    /// Switches the sidebar to the Git tab (used by the "Show Git Panel" ⌘G shortcut).
    func selectGitTab() {
        sidebarSectionModel.selectedTab = 2
        selectSidebarTab(index: 2)
    }

    /// Scrolls/highlights `path` in the file tree in the background — unlike
    /// `selectFilesTab(revealPath:)`, does not switch sidebar sections or force it visible.
    /// Mirrors the passive cwd-follow in `reload()`, for callers (e.g. `kouen cat`/`view`) that
    /// want the tree ready without yanking focus off whatever section is currently showing.
    func revealFileInTreeQuietly(path: String) {
        let parentDir = (path as NSString).deletingLastPathComponent
        let root = WorktreeManager().repoRoot(for: parentDir) ?? parentDir
        let activeSessionID = SessionCoordinator.shared.snapshot.activeWorkspace?.activeSessionID
        fileTreeView.updateRoot(path: root, sessionID: activeSessionID)
        fileTreeView.revealFileInTree(path: path)
    }

    /// Switches the sidebar to the Files tab and reveals `path` in the file tree
    /// (expands ancestors, highlights the row, and scrolls to it).
    func selectFilesTab(revealPath path: String) {
        sidebarSectionModel.selectedTab = 1
        selectSidebarTab(index: 1)
        // Ensure the tree is shown, not the inline file viewer.
        fileViewerVC.view.isHidden = true
        fileTreeView.isHidden = false
        fileTreeView.revealFileInTree(path: path)
    }

    func previewFile(path: String) {
        sidebarSectionModel.selectedTab = 1
        selectSidebarTab(index: 1)
        fileTreeView.isHidden = true
        fileViewerVC.view.isHidden = false
        fileViewerVC.load(path: path)
    }

    /// Full "Open With" entry point: shows file in viewer AND routes the terminal to the
    /// project root (git root if found, else file's parent). The snapshot update that follows
    /// addSession/selectSession wires the file tree root automatically.
    func openExternalFile(path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        let cwd = Self.gitRoot(for: expanded) ?? (expanded as NSString).deletingLastPathComponent
        previewFile(path: expanded)
        guard let wsID = activeWorkspaceID else { return }
        if let existing = sessions.first(where: { $0.tabs.contains(where: { $0.cwd == cwd }) }) {
            SessionCoordinator.shared.selectSession(workspaceID: wsID, sessionID: existing.id)
        } else {
            Self.recordRecentProject(cwd)
            SessionCoordinator.shared.addSession(to: wsID, cwd: cwd, name: (cwd as NSString).lastPathComponent)
        }
    }

    private static func gitRoot(for path: String) -> String? {
        var dir = (path as NSString).deletingLastPathComponent
        while dir != "/" {
            if FileManager.default.fileExists(atPath: dir + "/.git") { return dir }
            let parent = (dir as NSString).deletingLastPathComponent
            if parent == dir { break }
            dir = parent
        }
        return nil
    }

    @objc private func viViewFileCommand(_ note: Notification) {
        guard let path = note.userInfo?["path"] as? String else { return }
        var expanded = (path as NSString).expandingTildeInPath
        if !expanded.hasPrefix("/"), let cwd = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd {
            expanded = (cwd as NSString).appendingPathComponent(expanded)
        }
        if !FileManager.default.fileExists(atPath: expanded) {
            let root = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd ?? FileManager.default.currentDirectoryPath
            switch FuzzyPathResolver.resolve(query: path, root: root, limit: 5) {
            case .none:
                DisplayMessage.show("view: no match")
                return
            case .unique(let match):
                expanded = match
            case .ambiguous(let matches):
                DisplayMessage.show(matches.enumerated().map { "\($0.offset + 1): \($0.element)" }.joined(separator: "\n"))
                return
            }
        }
        previewFile(path: expanded)
    }

    private func selectSidebarTab(index: Int) {
        sessionHostingView?.isHidden = index != 0 || sidebarSectionModel.showBoardView
        if index != 1 {
            // Leaving the Files tab: collapse any open preview back to the tree
            // so returning to Files always starts from the file list.
            fileViewerVC.view.isHidden = true
            fileTreeView.isHidden = true
        } else {
            fileTreeView.isHidden = fileViewerVC.view.isHidden == false
        }
        gitPanelView.isHidden = index != 2
        let showBoard = index == 0 && sidebarSectionModel.showBoardView
        // Unhide BEFORE forcing layout: AutoLayout skips a hidden view's subtree, so
        // laying out while boardVC.view.isHidden was still true never resolved its
        // internal scrollView/columnsStack frame — that's what squashed the first
        // column header into a sliver on the Sessions → Board switch.
        boardVC.view.isHidden = !showBoard
        if showBoard {
            // Force-rebuild columns before laying out. While hidden, the existing
            // NSTextField column headers keep a stale cached intrinsicContentSize;
            // force: true guarantees fresh label subviews so layoutSubtreeIfNeeded()
            // below measures correct frames instead of the stale cropped ones.
            boardVC.reload(force: true)
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            boardVC.scrollToTop()
        }
        switch index {
        case 1:
            sidebarSectionModel.text = "FILES"
            sidebarSectionModel.isRepoHeader = false
            if let cwd = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd {
                let activeSessionID = SessionCoordinator.shared.snapshot.activeWorkspace?.activeSessionID
                let root = WorktreeManager().repoRoot(for: cwd) ?? cwd
                fileTreeView.updateRoot(path: root, sessionID: activeSessionID)
                fileTreeView.revealFileInTree(path: cwd)
            }
        case 2:
            sidebarSectionModel.text = "GIT"
            sidebarSectionModel.isRepoHeader = false
            if let cwd = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd {
                gitPanelView.updateRoot(path: cwd)
            } else {
                gitPanelView.clearRoot()
            }
        default:
            sidebarSectionModel.isRepoHeader = true
            updateRepoSectionHeader()
        }
    }

    private func setupFooterView() {
        let hosting = NSHostingView(rootView: SidebarFooterView(
            model: sidebarFooterModel,
            onSettings: { [weak self] in self?.openSettings() },
            onAgents: { [weak self] in self?.showAgentsInbox() },
            onTasks: { [weak self] in self?.showTaskDashboard() },
            onOpenRecent: { [weak self] path in self?.openRecentPath(path) },
            onNewSession: { [weak self] in self?.addSession() },
            onPalette: { [weak self] in self?.openPalette() },
            recentProjectsProvider: { KouenSidebarPanelViewController.recentProjectsList() }
        ))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        footerHostingView = hosting
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.heightAnchor.constraint(equalToConstant: KouenDesign.footerHeight + 6),
        ])
    }

    private func openRecentPath(_ path: String) {
        guard let id = activeWorkspaceID else { return }
        if let existing = sessions.first(where: { $0.tabs.contains(where: { $0.cwd == path }) }) {
            SessionCoordinator.shared.selectSession(workspaceID: id, sessionID: existing.id)
            return
        }
        Self.recordRecentProject(path)
        SessionCoordinator.shared.addSession(to: id, cwd: path, name: (path as NSString).lastPathComponent)
    }

    @objc func reload() {
        let snap = SessionCoordinator.shared.snapshot
        workspaces = snap.workspaces
        activeWorkspaceID = snap.activeWorkspaceID
        let newActiveSessionID = snap.activeWorkspace?.activeSessionID
        activeSessionID = newActiveSessionID
        sessions = snap.activeWorkspace?.sessions ?? []
        let name = snap.activeWorkspace?.name ?? "Workspace"
        workspacePillModel.name = name
        sidebarListModel.update(from: snap)
        sidebarListModel.updateWorktrees()

        if let cwd = snap.activeWorkspace?.activeTab?.cwd {
            let activeSessionID = snap.activeWorkspace?.activeSessionID
            let gitBranch = snap.activeWorkspace?.activeTab?.gitBranch
            let sessionChanged = activeSessionID != lastFileTreeSessionID
            if sessionChanged {
                lastFileTreeGitBranch = nil
                lastFileTreeCWD = nil
            }

            let root = WorktreeManager().repoRoot(for: cwd) ?? cwd
            fileTreeView.updateRoot(path: root, sessionID: activeSessionID)
            if cwd != lastFileTreeCWD {
                fileTreeView.revealFileInTree(path: cwd)
                lastFileTreeCWD = cwd
            }
            gitPanelView.updateRoot(path: cwd)
            lastFileTreeSessionID = activeSessionID
            lastFileTreeGitBranch = gitBranch
            let home = NSHomeDirectory()
            if cwd != home, cwd != "/" {
                Self.recordRecentProject(cwd)
            }
        } else {
            gitPanelView.clearRoot()
        }
        updateRepoSectionHeader()
    }

    /// Updates session card labels in place (title/cwd/branch/agent) without
    /// rebuilding the table — preserves selection + scroll position.
    @objc func refreshMetadata() {
        let snap = SessionCoordinator.shared.snapshot
        let newSessions = snap.activeWorkspace?.sessions ?? []
        let activeID = snap.activeWorkspace?.activeSessionID
        // Structural changes still take the full reload path.
        if newSessions.map(\.id) != sessions.map(\.id) {
            reload()
            return
        }
        sessions = newSessions
        activeWorkspaceID = snap.activeWorkspaceID
        activeSessionID = activeID
        workspaces = snap.workspaces
        let name = snap.activeWorkspace?.name ?? "Workspace"
        workspacePillModel.name = name
        if let cwd = snap.activeWorkspace?.activeTab?.cwd {
            let activeSessionID = snap.activeWorkspace?.activeSessionID
            let gitBranch = snap.activeWorkspace?.activeTab?.gitBranch
            let sessionChanged = activeSessionID != lastFileTreeSessionID
            if sessionChanged {
                lastFileTreeGitBranch = nil
                lastFileTreeCWD = nil
            }
            let branchChanged = gitBranch != lastFileTreeGitBranch
            if sessionChanged || branchChanged {
                let root = WorktreeManager().repoRoot(for: cwd) ?? cwd
                fileTreeView.updateRoot(path: root, sessionID: activeSessionID)
            }
            if cwd != lastFileTreeCWD {
                fileTreeView.revealFileInTree(path: cwd)
                lastFileTreeCWD = cwd
            }
            gitPanelView.updateRoot(path: cwd)
            lastFileTreeSessionID = activeSessionID
            lastFileTreeGitBranch = gitBranch
        } else {
            gitPanelView.clearRoot()
        }
        // Rebuild cache once; iterate the stored result — no redundant recomputation.
        // Skip entirely when session data hasn't changed (common on metadata-only ticks).
        // SwiftUI model sync — always update so badges/agent status stay fresh
        sidebarListModel.update(from: snap)

        updateRepoSectionHeader()
    }

    @objc func addWorkspace() {
        let count = SessionCoordinator.shared.snapshot.workspaces.count + 1
        SessionCoordinator.shared.addWorkspace(name: "Workspace \(count)")
    }

    /// Quick-actions menu opened from a row's ellipsis (inside the workspace
    /// dropdown). Just "Delete workspace…" — rename lives on the pill itself.
    func confirmDeleteWorkspace(_ workspace: Workspace, anchor: NSView) {
        let menu = NSMenu()
        let delete = NSMenuItem(title: "Delete workspace…", action: #selector(deleteWorkspaceFromMenu(_:)), keyEquivalent: "")
        delete.target = self
        delete.representedObject = workspace.id
        menu.addItem(delete)
        let point = NSPoint(x: 0, y: anchor.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: anchor)
    }

    /// Quick-actions menu opened from the workspace pill's ellipsis (top-level).
    /// Rename and Delete for the active workspace. Delete is disabled when this
    /// is the only workspace (you can't remove the last one).
    private func showActiveWorkspaceActions(from anchor: NSView) {
        guard let active = workspaces.first(where: { $0.id == activeWorkspaceID }) else { return }
        let menu = NSMenu()
        let rename = NSMenuItem(title: "Rename workspace…", action: #selector(renameActiveWorkspace(_:)), keyEquivalent: "")
        rename.target = self
        rename.representedObject = active.id
        menu.addItem(rename)

        menu.addItem(.separator())

        let delete = NSMenuItem(title: "Delete workspace…", action: #selector(deleteWorkspaceFromMenu(_:)), keyEquivalent: "")
        delete.target = self
        delete.representedObject = active.id
        delete.isEnabled = workspaces.count > 1
        menu.addItem(delete)

        let point = NSPoint(x: 0, y: anchor.bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: anchor)
    }

    @objc private func renameActiveWorkspace(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? WorkspaceID,
              let workspace = workspaces.first(where: { $0.id == id })
        else { return }
        let alert = NSAlert()
        alert.messageText = "Rename workspace"
        alert.informativeText = "Enter a new name for \"\(workspace.name)\"."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        input.stringValue = workspace.name
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != workspace.name else { return }
        SessionCoordinator.shared.renameWorkspace(id: id, name: trimmed)
    }

    @objc private func deleteWorkspaceFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? WorkspaceID,
              let workspace = workspaces.first(where: { $0.id == id })
        else { return }
        dismissWorkspaceDropdown()
        let alert = NSAlert()
        alert.messageText = "Delete \"\(workspace.name)\"?"
        alert.informativeText = "All sessions and tabs in this workspace will be closed. This can't be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = ""
        if alert.runModal() == .alertFirstButtonReturn {
            SessionCoordinator.shared.closeWorkspace(id: id)
        }
    }

    @objc private func addSession() {
        guard let activeWorkspaceID else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a project folder"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                guard let self, let id = self.activeWorkspaceID ?? activeWorkspaceID as WorkspaceID? else { return }
                Self.recordRecentProject(url.path)
                SessionCoordinator.shared.addSession(to: id, cwd: url.path, name: url.lastPathComponent)
            }
        }
    }

    private func addSessionInGroup(rootPath: String) {
        guard let activeWorkspaceID else { return }
        let name = KouenDesign.pathDisplayName(rootPath)
        Self.recordRecentProject(rootPath)
        SessionCoordinator.shared.addSession(to: activeWorkspaceID, cwd: rootPath, name: name)
    }

    // MARK: - Git & Worktrees Helpers

    private func fetchRepoName(for path: String) async -> String {
        let folderName = KouenDesign.projectGroupName(for: path)
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return folderName }
        // Run git off the main actor — readDataToEndOfFile + waitUntilExit block the
        // calling thread, causing a 1s+ hang report when executed on main.
        let repoName: String? = await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["config", "--get", "remote.origin.url"]
            process.currentDirectoryURL = URL(fileURLWithPath: path)
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus == 0,
                   let urlString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !urlString.isEmpty {
                    let lastPathComponent = (urlString as NSString).lastPathComponent
                    var repo = lastPathComponent
                    if repo.hasSuffix(".git") {
                        repo = String(repo.dropLast(4))
                    }
                    if !repo.isEmpty { return repo }
                }
            } catch {}
            return nil
        }.value
        return repoName ?? folderName
    }

    private func updateRepoSectionHeader() {
        guard sidebarSectionModel.selectedTab == 0 else { return }
        let path = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd ?? ""
        if path.isEmpty {
            self.sidebarSectionModel.text = "SESSIONS"
            return
        }
        // Skip the git subprocess when the active path hasn't changed and we fetched recently.
        let now = Date()
        guard path != lastRepoHeaderPath || now.timeIntervalSince(lastRepoHeaderFetch) > 5 else { return }
        lastRepoHeaderPath = path
        lastRepoHeaderFetch = now
        Task {
            let repoName = await fetchRepoName(for: path)
            await MainActor.run {
                if self.sidebarSectionModel.selectedTab == 0 {
                    self.sidebarSectionModel.text = repoName.hasSuffix("/") ? repoName : "\(repoName)/"
                }
            }
        }
    }

}

extension Notification.Name {
    static let kouenOpenGitPanel = Notification.Name("KouenOpenGitPanel")
}

