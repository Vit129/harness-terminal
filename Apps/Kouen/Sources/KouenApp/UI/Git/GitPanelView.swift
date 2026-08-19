// ponytail: intentionally AppKit — NSAttributedString diffstat rendering + per-file row menus need NSTableView; SwiftUI Table lacks row actions and custom cell editing as of macOS 26.
import AppKit
import KouenCore
import CoreServices

@MainActor
final class GitPanelView: NSView {
    private var currentPath: String?
    private var manuallyUnstagedFiles = Set<String>()
    /// Bumped on every `refresh()` call so a slower, stale refresh can detect
    /// that a newer one has superseded it and discard its results.
    private var refreshGeneration = 0
    private var lastWorktreeOutput = ""
    /// Keyed by the **source** worktree path (the branch being merged), not the repo — a
    /// merge is something the user triggered from that specific row, so the conflict card
    /// renders in that row's place on the next render (see `makeWorktreeRow`'s early check).
    /// Carries the main worktree path too so `reconcileMergeConflicts` can verify `MERGE_HEAD`
    /// still exists there before trusting this stale-by-construction dictionary.
    private var activeMergeConflicts: [String: (mainWorktreePath: String, files: [String])] = [:]
    private var lastBranch = ""
    private var lastAheadBehind = ""
    private var lastNumstat = ""
    private var lastPorcelain = ""
    private var lastLog = ""
    private var historyLimit = 25
    private let historyPageSize = 25

    private nonisolated(unsafe) var watchStream: FSEventStreamRef?
    private nonisolated(unsafe) var contextPointer: UnsafeMutableRawPointer?
    private nonisolated(unsafe) var watchDebounce: DispatchWorkItem?
    /// Set true while our own git operations run to suppress FSEvent self-triggering.
    private nonisolated(unsafe) var suppressingFSEvents = false

    deinit {
        if let stream = watchStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        if let ptr = contextPointer { Unmanaged<WatcherContext>.fromOpaque(ptr).release() }
        watchDebounce?.cancel()
    }

    private final class WatcherContext: @unchecked Sendable {
        let onChange: @MainActor () -> Void
        init(onChange: @MainActor @escaping () -> Void) {
            self.onChange = onChange
        }
    }

    // Top tabs: Changes | History | Worktrees
    private let tabSelector = NSSegmentedControl(labels: ["Changes", "History", "Worktrees"], trackingMode: .selectOne, target: nil, action: nil)
    private let changesContainer = NSView()
    private let historyContainer = NSView()
    private let worktreesContainer = NSView()

    // Changes view
    private let changesScroll = NSScrollView()
    private let changesStack = NSStackView()
    private let stageAllButton = NSButton(title: "Stage All", target: nil, action: nil)

    // Commit area (bottom of changes)
    private let commitField = NSTextField()
    private let commitButton = NSButton(title: "Commit Tracked", target: nil, action: nil)

    // History view
    private let historyScroll = NSScrollView()
    private let historyStack = NSStackView()

    // Worktrees view
    private let worktreesScroll = NSScrollView()
    private let worktreesStack = NSStackView()
    private let addWorktreeButton = NSButton(title: "+", target: nil, action: nil)
    private var worktreesExpanded = true

    // Bottom bar: branch + fetch
    private let bottomBar = NSView()
    private let branchLabel = NSTextField(labelWithString: "")
    private let syncButton = NSButton(title: "Fetch ▾", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startWatching()
        } else {
            stopWatching()
        }
    }

    // ponytail: updateRoot()'s `path != currentPath` dedup can set currentPath
    // while this view is still hidden (refresh() itself bails out via the
    // isHiddenOrHasHiddenAncestor guard below), so becoming visible again with
    // an unchanged path would otherwise never repaint. Force one refresh on
    // hidden->visible transitions to close that gap.
    override var isHidden: Bool {
        didSet {
            if oldValue, !isHidden {
                Task { [weak self] in await self?.refresh() }
            }
        }
    }

    func updateRoot(path: String) {
        guard path != currentPath else { return }
        currentPath = path
        lastBranch = ""
        lastAheadBehind = ""
        lastNumstat = ""
        lastPorcelain = ""
        lastLog = ""
        invalidateWorktreeCaches()
        startWatching()
        Task { [weak self] in await self?.refresh() }
    }

    /// Paths under `.git/` written on every auto-stage/commit that would
    /// self-trigger a refresh loop if they scheduled one. Everything else
    /// under `.git/` (HEAD, refs/**, logs/**, COMMIT_EDITMSG, FETCH_HEAD) is
    /// treated as relevant, since an external `git commit`/`push` only
    /// touches paths there — never the working tree.
    nonisolated static func isNoisyGitInternalPath(_ path: String) -> Bool {
        path.hasSuffix("/.git/index") || path.hasSuffix("/.git/index.lock") || path.contains("/.git/objects/")
    }

    func clearRoot() {
        currentPath = nil
        manuallyUnstagedFiles.removeAll()
        lastBranch = ""
        lastAheadBehind = ""
        lastNumstat = ""
        lastPorcelain = ""
        lastLog = ""
        invalidateWorktreeCaches()
        stopWatching()
    }

    private func startWatching() {
        stopWatching()
        guard let path = currentPath else { return }

        let contextWrapper = WatcherContext { [weak self] in
            self?.debouncedRefresh()
        }
        let ptr = UnsafeMutableRawPointer(Unmanaged.passRetained(contextWrapper).toOpaque())
        contextPointer = ptr

        var context = FSEventStreamContext(
            version: 0,
            info: ptr,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { (streamRef, clientInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let clientInfo = clientInfo else { return }
            // Filter: ignore noisy internal .git/ writes (index, index.lock, loose/pack
            // objects) that fire on every auto-stage and would self-trigger a refresh loop.
            // Do NOT filter all of .git/ — HEAD/refs/logs changes from an external
            // `git commit`/`push` live there too and must still trigger a refresh.
            let cfPaths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            var hasRelevantChange = false
            for i in 0..<numEvents {
                let p = unsafeBitCast(CFArrayGetValueAtIndex(cfPaths, i), to: CFString.self) as String
                if !GitPanelView.isNoisyGitInternalPath(p) {
                    hasRelevantChange = true
                    break
                }
            }
            guard hasRelevantChange else { return }
            let wrapper = Unmanaged<WatcherContext>.fromOpaque(clientInfo).takeUnretainedValue()
            Task { @MainActor in
                wrapper.onChange()
            }
        }

        let paths = [path] as CFArray
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            Unmanaged<WatcherContext>.fromOpaque(ptr).release()
            contextPointer = nil
            return
        }

        let queue = DispatchQueue.global(qos: .utility)
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        watchStream = stream
    }

    private func stopWatching() {
        if let stream = watchStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            watchStream = nil
        }
        if let ptr = contextPointer {
            Unmanaged<WatcherContext>.fromOpaque(ptr).release()
            contextPointer = nil
        }
        watchDebounce?.cancel()
        watchDebounce = nil
    }

    private func debouncedRefresh() {
        // Fix 6: Ignore FSEvents triggered by our own git operations
        guard !suppressingFSEvents else { return }
        watchDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { await self.refresh() }
        }
        watchDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        // Tab selector
        tabSelector.selectedSegment = 0
        tabSelector.target = self
        tabSelector.action = #selector(tabChanged)
        tabSelector.segmentStyle = .automatic
        tabSelector.translatesAutoresizingMaskIntoConstraints = false

        // Changes container — scrollable list
        changesContainer.translatesAutoresizingMaskIntoConstraints = false
        changesStack.orientation = .vertical; changesStack.alignment = .width; changesStack.spacing = 0
        changesStack.translatesAutoresizingMaskIntoConstraints = false
        changesStack.detachesHiddenViews = false

        let changesFlipped = FlippedView()
        changesFlipped.translatesAutoresizingMaskIntoConstraints = false
        changesFlipped.addSubview(changesStack)
        NSLayoutConstraint.activate([
            changesStack.topAnchor.constraint(equalTo: changesFlipped.topAnchor),
            changesStack.leadingAnchor.constraint(equalTo: changesFlipped.leadingAnchor),
            changesStack.trailingAnchor.constraint(equalTo: changesFlipped.trailingAnchor),
            changesStack.bottomAnchor.constraint(equalTo: changesFlipped.bottomAnchor),
        ])

        changesScroll.documentView = changesFlipped
        changesScroll.hasVerticalScroller = true
        changesScroll.drawsBackground = false
        changesScroll.scrollerStyle = .overlay
        changesScroll.autohidesScrollers = true
        changesScroll.translatesAutoresizingMaskIntoConstraints = false

        changesContainer.addSubview(changesScroll)
        NSLayoutConstraint.activate([
            changesScroll.topAnchor.constraint(equalTo: changesContainer.topAnchor),
            changesScroll.leadingAnchor.constraint(equalTo: changesContainer.leadingAnchor),
            changesScroll.trailingAnchor.constraint(equalTo: changesContainer.trailingAnchor),
            changesScroll.bottomAnchor.constraint(equalTo: changesContainer.bottomAnchor),
            changesFlipped.widthAnchor.constraint(equalTo: changesScroll.contentView.widthAnchor),
        ])

        // Stage All button bar
        stageAllButton.bezelStyle = .recessed; stageAllButton.controlSize = .small
        stageAllButton.font = .systemFont(ofSize: 11, weight: .medium)
        stageAllButton.target = self; stageAllButton.action = #selector(stageAllAction)
        stageAllButton.translatesAutoresizingMaskIntoConstraints = false

        // Commit area
        commitField.placeholderString = "Commit message…"
        commitField.font = .systemFont(ofSize: 12)
        commitField.isBezeled = true; commitField.bezelStyle = .roundedBezel
        commitField.focusRingType = .none
        commitField.usesSingleLineMode = false
        commitField.lineBreakMode = .byWordWrapping
        commitField.maximumNumberOfLines = 4
        commitField.translatesAutoresizingMaskIntoConstraints = false

        commitButton.bezelStyle = .recessed; commitButton.controlSize = .small
        commitButton.font = .systemFont(ofSize: 11, weight: .medium)
        commitButton.target = self; commitButton.action = #selector(commitAction)
        commitButton.translatesAutoresizingMaskIntoConstraints = false

        // History container
        historyContainer.translatesAutoresizingMaskIntoConstraints = false
        historyContainer.isHidden = true
        historyStack.orientation = .vertical; historyStack.alignment = .width; historyStack.spacing = 0
        setupScrollView(historyScroll, with: historyStack, in: historyContainer)

        // Worktrees container
        worktreesContainer.translatesAutoresizingMaskIntoConstraints = false
        worktreesContainer.isHidden = true
        worktreesStack.orientation = .vertical; worktreesStack.alignment = .width; worktreesStack.spacing = 0
        setupScrollView(worktreesScroll, with: worktreesStack, in: worktreesContainer)

        addWorktreeButton.bezelStyle = .recessed; addWorktreeButton.controlSize = .small
        addWorktreeButton.font = .systemFont(ofSize: 12, weight: .semibold)
        addWorktreeButton.target = self; addWorktreeButton.action = #selector(addWorktreeAction)
        addWorktreeButton.isHidden = true
        addWorktreeButton.translatesAutoresizingMaskIntoConstraints = false

        // Bottom bar
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        branchLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        branchLabel.textColor = KouenDesign.chrome.textSecondary
        branchLabel.lineBreakMode = .byTruncatingTail
        branchLabel.translatesAutoresizingMaskIntoConstraints = false

        let branchClick = NSClickGestureRecognizer(target: self, action: #selector(showBranchMenu))
        branchLabel.addGestureRecognizer(branchClick)
        branchLabel.isSelectable = false

        syncButton.bezelStyle = .recessed; syncButton.controlSize = .small
        syncButton.font = .systemFont(ofSize: 11, weight: .medium)
        syncButton.target = self; syncButton.action = #selector(showSyncMenu)
        syncButton.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.addSubview(branchLabel)
        bottomBar.addSubview(syncButton)

        addSubview(tabSelector)
        addSubview(stageAllButton)
        addSubview(changesContainer)
        addSubview(commitField)
        addSubview(commitButton)
        addSubview(historyContainer)
        addSubview(addWorktreeButton)
        addSubview(worktreesContainer)
        addSubview(bottomBar)

        NSLayoutConstraint.activate([
            tabSelector.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            tabSelector.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            tabSelector.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            stageAllButton.topAnchor.constraint(equalTo: tabSelector.bottomAnchor, constant: 4),
            stageAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            changesContainer.topAnchor.constraint(equalTo: stageAllButton.bottomAnchor, constant: 2),
            changesContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            changesContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            changesContainer.bottomAnchor.constraint(equalTo: commitField.topAnchor, constant: -6),

            commitField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            commitField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            commitField.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            commitField.bottomAnchor.constraint(equalTo: commitButton.topAnchor, constant: -4),

            commitButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            commitButton.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -6),

            historyContainer.topAnchor.constraint(equalTo: tabSelector.bottomAnchor, constant: 4),
            historyContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            historyContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            historyContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -4),

            addWorktreeButton.topAnchor.constraint(equalTo: tabSelector.bottomAnchor, constant: 4),
            addWorktreeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            addWorktreeButton.widthAnchor.constraint(equalToConstant: 28),

            worktreesContainer.topAnchor.constraint(equalTo: addWorktreeButton.bottomAnchor, constant: 2),
            worktreesContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            worktreesContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            worktreesContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -4),

            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            bottomBar.heightAnchor.constraint(equalToConstant: 22),

            branchLabel.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            branchLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            branchLabel.trailingAnchor.constraint(lessThanOrEqualTo: syncButton.leadingAnchor, constant: -8),
            syncButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            syncButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
        ])
    }

    private func setupScrollView(_ scroll: NSScrollView, with stack: NSStackView, in container: NSView) {
        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)

        scroll.documentView = doc
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
        ])
    }

    // MARK: - Tab switching

    @objc private func tabChanged() {
        let selected = tabSelector.selectedSegment
        changesContainer.isHidden = selected != 0
        commitField.isHidden = selected != 0
        commitButton.isHidden = selected != 0
        stageAllButton.isHidden = selected != 0
        historyContainer.isHidden = selected != 1
        worktreesContainer.isHidden = selected != 2
        addWorktreeButton.isHidden = selected != 2
    }

    // MARK: - Actions

    @objc private func showSyncMenu() {
        let menu = NSMenu()
        let fetch = NSMenuItem(title: "Fetch", action: #selector(doFetch), keyEquivalent: "")
        fetch.target = self
        let pull = NSMenuItem(title: "Pull", action: #selector(doPull), keyEquivalent: "")
        pull.target = self
        let push = NSMenuItem(title: "Push", action: #selector(doPush), keyEquivalent: "")
        push.target = self
        let forcePush = NSMenuItem(title: "Force Push", action: #selector(doForcePush), keyEquivalent: "")
        forcePush.target = self
        let commitAndPush = NSMenuItem(title: "Commit & Push", action: #selector(doCommitAndPush), keyEquivalent: "")
        commitAndPush.target = self
        menu.addItem(fetch)
        menu.addItem(pull)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(push)
        menu.addItem(forcePush)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(commitAndPush)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: syncButton.bounds.height), in: syncButton)
    }

    @objc private func doCommitAndPush() {
        let msg = commitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else {
            Toast.show("Enter a commit message first", in: self, hold: 2.0)
            return
        }
        guard let path = currentPath else { return }
        syncButton.isEnabled = false
        syncButton.title = "Committing…"
        Task {
            let commit = await runGitWithStatus(["commit", "-m", msg], in: path)
            if !commit.success {
                syncButton.isEnabled = true
                syncButton.title = "Sync ▾"
                let msg = GitPanelView.toastErrorSummary(commit.stderr)
                Toast.show("✗ Commit failed: \(msg)", in: self, hold: 4.0)
                await refresh()
                watchDebounce?.cancel()
                return
            }
            commitField.stringValue = ""
            syncButton.title = "Pushing…"
            let push = await runGitWithStatus(["push"], in: path)
            syncButton.isEnabled = true
            syncButton.title = "Sync ▾"
            if push.success {
                Toast.show("✓ Committed & pushed", in: self)
            } else {
                let errMsg = GitPanelView.toastErrorSummary(push.stderr)
                Toast.show("✗ Push failed: \(errMsg)", in: self, hold: 4.0)
            }
            await refresh()
            watchDebounce?.cancel()
        }
    }

    @objc private func doFetch() { runAndRefresh(["fetch"]) }
    @objc private func doPull() { runAndRefresh(["pull"]) }
    @objc private func doPush() { runAndRefresh(["push"]) }
    @objc private func doForcePush() { runAndRefresh(["push", "--force-with-lease"]) }

    @objc private func stageAllAction() {
        if stageAllButton.title == "Unstage All" {
            guard let path = currentPath else { return }
            Task {
                let porcelain = await runGit(["status", "--porcelain"], in: path)
                for line in porcelain.components(separatedBy: "\n") where !line.isEmpty {
                    let file = String(line.dropFirst(3))
                    self.manuallyUnstagedFiles.insert(file)
                }
                self.runAndRefresh(["reset"])
            }
        } else {
            manuallyUnstagedFiles.removeAll()
            runAndRefresh(["add", "-A"])
        }
    }

    @objc private func showBranchMenu() {
        guard let path = currentPath else { return }
        Task {
            let output = await runGit(["branch", "--format=%(refname:short)"], in: path)
            let branches = output.components(separatedBy: "\n").filter { !$0.isEmpty }
            let current = await runGit(["branch", "--show-current"], in: path)
            let menu = NSMenu()
            for branch in branches {
                let item = NSMenuItem(title: branch, action: #selector(switchBranch(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = branch
                if branch == current { item.state = .on }
                menu.addItem(item)
            }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: branchLabel.bounds.height), in: branchLabel)
        }
    }

    @objc private func switchBranch(_ sender: NSMenuItem) {
        guard let branch = sender.representedObject as? String else { return }
        runAndRefresh(["checkout", branch])
    }

    @objc private func commitAction() {
        let msg = commitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        runAndRefresh(["commit", "-m", msg], clearField: true)
    }

    @objc private func addWorktreeAction() {
        guard let path = currentPath else { return }

        let alert = NSAlert()
        alert.messageText = "Add Worktree"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .width; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let pathField = NSTextField()
        pathField.placeholderString = "/path/to/worktree"
        pathField.translatesAutoresizingMaskIntoConstraints = false

        let branchField = NSTextField()
        branchField.placeholderString = "branch"
        branchField.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeFieldRow("Path:", field: pathField))
        stack.addArrangedSubview(makeFieldRow("Branch:", field: branchField))

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 58))
        accessory.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: accessory.topAnchor),
            stack.leadingAnchor.constraint(equalTo: accessory.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: accessory.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: accessory.bottomAnchor),
            pathField.widthAnchor.constraint(equalToConstant: 240),
        ])
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = pathField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let worktreePath = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = branchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !worktreePath.isEmpty, !branch.isEmpty else { return }

        Task {
            _ = await runGit(["worktree", "add", worktreePath, branch], in: path)
            if FileManager.default.fileExists(atPath: worktreePath) {
                let coordinator = SessionCoordinator.shared
                if let workspaceID = coordinator.snapshot.activeWorkspaceID {
                    coordinator.addSession(to: workspaceID, cwd: worktreePath, name: (worktreePath as NSString).lastPathComponent)
                }
            }
            await refresh()
        }
    }

    @objc private func removeWorktreeAction(_ sender: NSButton) {
        guard let worktreePath = sender.identifier?.rawValue else { return }
        removeWorktreeAction(path: worktreePath)
    }

    @objc private func toggleWorktreesSection() {
        worktreesExpanded.toggle()
        Task { await refresh() }
    }

    @objc private func openWorktree(_ sender: NSClickGestureRecognizer) {
        guard let card = sender.view, let path = card.identifier?.rawValue else { return }
        cdToWorktree(path)
    }

    /// Finds the tab already tracking `path` (as `cwd` or `worktreePath`) across every
    /// workspace, mirroring `agentInfo(forWorktreePath:tabs:)`'s matching rule — same
    /// nonisolated-static/private-wrapper split so this is directly unit-testable.
    nonisolated static func matchingTab(forPath path: String, workspaces: [Workspace]) -> (workspaceID: WorkspaceID, tabID: TabID)? {
        for workspace in workspaces {
            for tab in workspace.sessions.flatMap(\.tabs) where tab.cwd == path || tab.worktreePath == path {
                return (workspace.id, tab.id)
            }
        }
        return nil
    }

    nonisolated static func getParentRepoPath(forWorktreePath path: String) -> String? {
        let gitFileURL = URL(fileURLWithPath: path).appendingPathComponent(".git")
        guard let content = try? String(contentsOf: gitFileURL, encoding: .utf8) else { return nil }
        guard content.hasPrefix("gitdir: ") else { return nil }
        let gitDir = content.dropFirst("gitdir: ".count).trimmingCharacters(in: .whitespacesAndNewlines)
        let gitDirURL = URL(fileURLWithPath: gitDir)
        let parentRepoURL = gitDirURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return parentRepoURL.path
    }

    private func cdToWorktree(_ path: String) {
        let coordinator = SessionCoordinator.shared
        // Switch to an existing tab already cd'd into this worktree — sending `cd <path>`
        // keystrokes to whatever surface happens to be focused (the old behavior) silently
        // no-ops or types into the wrong pane (e.g. an agent CLI's prompt) instead of
        // navigating there.
        if let match = Self.matchingTab(forPath: path, workspaces: coordinator.snapshot.workspaces) {
            coordinator.selectWorkspace(match.workspaceID)
            coordinator.selectTab(workspaceID: match.workspaceID, tabID: match.tabID)
            tabSelector.selectedSegment = 0
            tabChanged()
            return
        }
        guard let workspaceID = coordinator.snapshot.activeWorkspaceID else { return }
        
        let parentRepo = Self.getParentRepoPath(forWorktreePath: path)
        coordinator.addSession(
            to: workspaceID,
            cwd: path,
            name: (path as NSString).lastPathComponent,
            worktreePath: path,
            parentRepoPath: parentRepo
        )
        tabSelector.selectedSegment = 0
        tabChanged()
    }

    private func removeWorktreeAction(path worktreePath: String) {
        let alert = NSAlert()
        alert.messageText = "Remove worktree?"
        alert.informativeText = worktreePath
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.buttons.first?.keyEquivalent = ""
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            await SessionCoordinator.shared.closeTabs(under: worktreePath)
            // Anchor at the repo's main worktree, not `worktreePath` itself — git refuses to
            // remove a worktree while cwd'd inside it — resolved fresh so this is correct both
            // from the single-repo Worktrees tab AND the cross-repo Agents tab, where
            // `worktreePath` may belong to a repo that isn't `currentPath` at all.
            guard let anchor = await resolveMainWorktreePath(from: worktreePath) else {
                let errAlert = NSAlert()
                errAlert.messageText = "Failed to remove worktree"
                errAlert.informativeText = "Couldn't resolve the repo for \(worktreePath) — it may already be gone."
                errAlert.runModal()
                invalidateWorktreeCaches()
                await refresh()
                return
            }
            let result = await runGitWithStatus(["worktree", "remove", "--force", worktreePath], in: anchor)
            if !result.success {
                let errAlert = NSAlert()
                errAlert.messageText = "Failed to remove worktree"
                errAlert.informativeText = result.stderr.isEmpty ? result.output : result.stderr
                errAlert.runModal()
            }
            invalidateWorktreeCaches()
            await refresh()
        }
    }

    /// Resets every worktree-related skip-rebuild cache. Every mutation site that changes
    /// worktree state (remove, merge success, merge abort) must call this — a single choke
    /// point so a future new cache can't be forgotten at one of the sites.
    private func invalidateWorktreeCaches() {
        lastWorktreeOutput = ""
    }

    /// Resolves the repo's main worktree path by listing worktrees from `path` itself — this
    /// works no matter which specific worktree/repo `path` belongs to, so repo-wide git
    /// operations (worktree remove, merge) can anchor correctly from either the single-repo
    /// Worktrees tab or the cross-repo Agents tab, without depending on `currentPath` (which on
    /// the Agents tab may be an entirely different repo than the row being acted on).
    private func resolveMainWorktreePath(from path: String) async -> String? {
        let output = await runGit(["worktree", "list", "--porcelain"], in: path)
        return Self.parseWorktreePorcelain(output, mergedBranchOutput: "").first(where: { $0.isMain })?.path
    }

    /// Drops any stale conflict card whose merge is no longer actually in progress (resolved
    /// or aborted outside this UI, e.g. via terminal) — `activeMergeConflicts` is a snapshot
    /// from the moment `runGitWithStatus(["merge", ...])` failed, not a live view, so it must
    /// be reconciled against real `MERGE_HEAD` state before every render.
    private func reconcileMergeConflicts(generation: Int) async {
        guard !activeMergeConflicts.isEmpty else { return }
        var stillActive: [String: (mainWorktreePath: String, files: [String])] = [:]
        for (sourcePath, conflict) in activeMergeConflicts {
            let check = await runGitWithStatus(["rev-parse", "-q", "--verify", "MERGE_HEAD"], in: conflict.mainWorktreePath)
            guard generation == refreshGeneration else { return }
            if check.success {
                stillActive[sourcePath] = conflict
            }
        }
        if stillActive.count != activeMergeConflicts.count {
            activeMergeConflicts = stillActive
            invalidateWorktreeCaches()
        }
    }

    /// Shared by `previewCommitDetail` and `showCommitDetail` so the two diff views (popover
    /// vs full tab) can never drift apart on the underlying `git show` invocation.
    private func fetchCommitDiff(hash: String, path: String) async -> String {
        await Self.runGitDiff(["show", "--stat", "--patch", hash], in: path)
    }

    /// Everything a worktree's branch changed since it diverged from `main` — a three-dot diff
    /// against the merge-base, not just the latest commit. Matches `refreshWorktrees`' existing
    /// `git branch --merged main` base-branch assumption rather than introducing a second one.
    private func fetchWorktreeDiff(worktreePath: String) async -> String {
        await Self.runGitDiff(["diff", "--stat", "--patch", "main...HEAD"], in: worktreePath)
    }

    @objc private func previewWorktreeDiffAction(_ sender: NSButton) {
        guard let worktreePath = sender.identifier?.rawValue else { return }
        Task {
            let detail = await fetchWorktreeDiff(worktreePath: worktreePath)
            guard !detail.isEmpty else {
                DisplayMessage.show("No changes vs main")
                return
            }
            guard sender.window != nil else { return }
            self.presentCommitDetail(detail, anchor: sender)
        }
    }

    @objc private func mergeWorktreeAction(_ sender: NSButton) {
        guard let sourcePath = sender.identifier?.rawValue else { return }
        guard sender.isEnabled else { return } // validate already running for this row — ignore the extra click
        sender.isEnabled = false
        Task {
            // RL-063 shape: `sender` is captured across a multi-minute await (validate can run
            // that long) — a worktree-list refresh could rebuild this row's button out from
            // under us in the meantime. Re-enabling a still-attached button is the only real
            // case; touching a detached one is harmless but the guard makes that explicit.
            defer { if sender.window != nil { sender.isEnabled = true } }
            let output = await runGit(["worktree", "list", "--porcelain"], in: sourcePath)
            let entries = Self.parseWorktreePorcelain(output, mergedBranchOutput: "")
            guard let mainEntry = entries.first(where: { $0.isMain }),
                  let sourceEntry = entries.first(where: { $0.path == sourcePath }) else {
                Toast.show("✗ Couldn't resolve this worktree's repo — it may already be gone", in: self, hold: 4.0)
                return
            }
            Toast.show("Validating \(sourceEntry.branch)…", in: self)
            let validation = await validateWorktree(at: sourcePath)
            await performMerge(
                branch: sourceEntry.branch, sourcePath: sourcePath, mainWorktreePath: mainEntry.path, validation: validation
            )
        }
    }

    private struct ValidateOutcome { let ran: Bool; let success: Bool; let summary: String }

    /// MAW-style handoff gate (P39): auto-detects the worktree's stack (`SignalFileRouter`,
    /// reused as-is) and runs its build/test steps before the merge confirm dialog — but this
    /// is validate-then-inform, never validate-then-auto-merge. The result only ever changes
    /// what the NSAlert below says; `performMerge`'s own confirm click is still the only thing
    /// that can trigger a merge, same as before this change.
    private func validateWorktree(at path: String) async -> ValidateOutcome {
        let steps = SignalFileRouter.validationSteps(at: path)
        guard !steps.isEmpty else {
            return ValidateOutcome(ran: false, success: true, summary: "No validate command detected for this stack — skipped.")
        }
        for step in steps {
            let result = await runShellCommand(step[0], Array(step.dropFirst()), in: path)
            guard result.success else {
                // Live-tested (2026-07-23): `resolveExecutablePath`'s candidate list can still
                // miss a real toolchain (e.g. a version manager other than Volta) and fall back
                // to `env`, which fails with a `env: <name>: No such file or directory` line and
                // nothing else — that's an environment gap, not the worktree's tests actually
                // failing, and phrasing it as "failed" would read as a code-quality signal it
                // isn't.
                let missingTool = result.stderr.hasPrefix("env: ") && result.stderr.contains("No such file or directory")
                return ValidateOutcome(
                    ran: true, success: false,
                    summary: missingTool
                        ? "`\(step[0])` not found — validate couldn't run (not a code failure): \(Self.toastErrorSummary(result.stderr))"
                        : "`\(step.joined(separator: " "))` failed: \(Self.toastErrorSummary(result.stderr))"
                )
            }
        }
        return ValidateOutcome(ran: true, success: true, summary: "\(steps.map { $0.joined(separator: " ") }.joined(separator: " && ")) passed.")
    }

    /// Like `runGit`, but for an arbitrary build/test command instead of git — used only by
    /// `validateWorktree`. Merges stdout+stderr into one pipe (unlike `runGitDiff`'s separate
    /// pipes) because build/test tools can write far more volume than a git diff, and draining
    /// two pipes sequentially risks the classic `Process` deadlock if the unread one fills first.
    /// ponytail: 5-minute ceiling — a hung/slow test suite (this repo's own full `swift test`
    /// has a known crash, see `agent-memory/knowledge/bugs/sidebar-cmdbackslash-toggle.md`) kills
    /// the process and reports failure rather than blocking the merge dialog forever.
    private func runShellCommand(_ executable: String, _ args: [String], in directory: String) async -> GitResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                if let resolved = Process.resolveExecutablePath(executable) {
                    process.executableURL = URL(fileURLWithPath: resolved)
                    process.arguments = args
                } else {
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = [executable] + args
                }
                process.currentDirectoryURL = URL(fileURLWithPath: directory)
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 300, execute: timeout)
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timeout.cancel()
                    let combined = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: GitResult(output: combined, stderr: combined, success: process.terminationStatus == 0))
                } catch {
                    continuation.resume(returning: GitResult(output: "", stderr: error.localizedDescription, success: false))
                }
            }
        }
    }

    /// A3 handoff: plain `git merge` (never `--no-ff`, never rebase — rebase would rewrite the
    /// agent branch's history while an agent may still be running in that worktree). Runs
    /// entirely in the destination (main worktree); the source branch is never touched. On
    /// conflict, the merge is left paused in the main worktree exactly as `git merge` leaves
    /// it — no auto-resolve of any kind, ever; the user resolves via the existing Changes tab
    /// or aborts explicitly.
    private func performMerge(branch: String, sourcePath: String, mainWorktreePath: String, validation: ValidateOutcome) async {
        let sourceStatus = await runGit(["status", "--porcelain"], in: sourcePath)

        let alert = NSAlert()
        alert.messageText = "Merge \"\(branch)\" into \(KouenDesign.shortenPath(mainWorktreePath))?"
        var info = "This runs `git merge \(branch)` in the main worktree. \(branch) itself is not modified."
        info += validation.ran
            ? "\n\n\(validation.success ? "✓" : "⚠️ Validate failed —") \(validation.summary)"
            : "\n\n\(validation.summary)"
        if let handoff = SignalFileRouter.handoffInfo(at: sourcePath) {
            let preview = handoff.note.count > 400 ? String(handoff.note.prefix(400)) + "…" : handoff.note
            info += "\n\n📋 Handoff note left by this worktree's agent:\n\(preview)"
        }
        if !sourceStatus.isEmpty {
            info += "\n\n⚠️ This worktree has uncommitted changes — they will NOT be included in the merge."
        }
        alert.informativeText = info
        alert.addButton(withTitle: "Merge")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = (validation.ran && !validation.success) ? .warning : .informational
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // Preflight: merging into a dirty target tree is the likeliest way to accidentally
        // clobber uncommitted work sitting in the destination — abort instead of risking that.
        let targetStatus = await runGit(["status", "--porcelain"], in: mainWorktreePath)
        guard targetStatus.isEmpty else {
            Toast.show("✗ Target has uncommitted changes — merge aborted", in: self, hold: 4.0)
            return
        }

        suppressingFSEvents = true
        let result = await runGitWithStatus(["merge", branch], in: mainWorktreePath)
        suppressingFSEvents = false

        if result.success {
            activeMergeConflicts.removeValue(forKey: sourcePath)
            invalidateWorktreeCaches()
            Toast.show("✓ Merged \(branch)", in: self)
            watchDebounce?.cancel()
            await refresh()
            return
        }

        let mergeHeadCheck = await runGitWithStatus(["rev-parse", "-q", "--verify", "MERGE_HEAD"], in: mainWorktreePath)
        if mergeHeadCheck.success {
            let conflictedOutput = await runGit(["diff", "--name-only", "--diff-filter=U"], in: mainWorktreePath)
            let conflictedFiles = conflictedOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
            activeMergeConflicts[sourcePath] = (mainWorktreePath: mainWorktreePath, files: conflictedFiles)
            invalidateWorktreeCaches()
            await refresh()
        } else {
            Toast.show("✗ Merge failed: \(GitPanelView.toastErrorSummary(result.stderr))", in: self, hold: 4.0)
        }
    }

    /// `git merge --abort` does `git reset --merge` back to the pre-merge HEAD — this discards
    /// working-tree edits to EVERY file touched by the operation's index, not just the merge's
    /// own changes, including any manual conflict-resolution edits made after the merge started
    /// (RL-060, agent-memory/knowledge/rl-lessons.md). A user who's fixed 3 of 5 conflicted
    /// files then mis-clicks Abort would silently lose that work — so this confirms first.
    private func abortMergeAction(sourcePath: String, mainWorktreePath: String) {
        let alert = NSAlert()
        alert.messageText = "Abort merge?"
        alert.informativeText = "This discards any edits made to conflicted files while resolving — including manual fixes not yet committed. This cannot be undone."
        alert.addButton(withTitle: "Abort Merge")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            let result = await runGitWithStatus(["merge", "--abort"], in: mainWorktreePath)
            guard result.success else {
                Toast.show("✗ Abort failed: \(GitPanelView.toastErrorSummary(result.stderr))", in: self, hold: 4.0)
                return
            }
            activeMergeConflicts.removeValue(forKey: sourcePath)
            invalidateWorktreeCaches()
            Toast.show("Merge aborted", in: self)
            await refresh()
        }
    }

    private func resolveMergeInChangesAction(mainWorktreePath: String) {
        updateRoot(path: mainWorktreePath)
        tabSelector.selectedSegment = 0
        tabChanged()
    }

    /// Quick-look popover — file-nav bar + colored diff, anchored to the commit card, no tab
    /// opened. This is the default click action; `showCommitDetail` (full tab) stays reachable
    /// via the "Open Full Diff in Tab" context-menu item for the copy/search/keep-open case.
    @objc private func previewCommitDetail(_ sender: NSClickGestureRecognizer) {
        guard let card = sender.view,
              let path = currentPath,
              let hash = card.identifier?.rawValue else { return }
        Task {
            let detail = await fetchCommitDiff(hash: hash, path: path)
            guard !detail.isEmpty else {
                DisplayMessage.show("No diff for \(String(hash.prefix(7)))")
                return
            }
            // `refresh()` (FSEventStream-driven, debounced) rebuilds the commit-history list —
            // `applyState` detaches every existing card via `removeFromSuperview()` — and can
            // fire while the git-show above was in flight. Presenting a popover anchored to a
            // now-detached view is invalid; bail rather than anchor to stale/removed geometry.
            guard card.window != nil else { return }
            self.presentCommitDetail(detail, anchor: card)
        }
    }

    @objc private func showCommitDetail(_ sender: Any) {
        let card: NSView?
        if let gesture = sender as? NSClickGestureRecognizer {
            card = gesture.view
        } else if let menuItem = sender as? NSMenuItem {
            card = menuItem.representedObject as? NSView
        } else { return }
        guard let path = currentPath,
              let card,
              let hash = card.identifier?.rawValue else { return }
        Task {
            let detail = await fetchCommitDiff(hash: hash, path: path)
            let shortHash = String(hash.prefix(7))
            let tmpDir = NSTemporaryDirectory() + "kouen-diff/"
            try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
            let tmpPath = tmpDir + "\(shortHash).diff"
            try? detail.write(toFile: tmpPath, atomically: true, encoding: .utf8)
            guard let split = self.window?.contentViewController as? MainSplitViewController else { return }
            split.contentVC.openFileTab(path: tmpPath)
        }
    }

    @objc private func copyCommitID(_ sender: NSMenuItem) {
        guard let hash = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hash, forType: .string)
    }

    @objc private func copyCommitMessage(_ sender: NSMenuItem) {
        guard let msg = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(msg, forType: .string)
    }

    @objc private func copyCommitSummary(_ sender: NSMenuItem) {
        guard let summary = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    /// Colors a `git show`/`git diff` text blob (file headers blue, hunks purple, +/- green/red)
    /// and returns a scroll view ready to embed. Pure/testable: no popover, no window.
    ///
    /// Uses `NSTextView.scrollableTextView()` rather than a bare `NSTextView()` + manual
    /// `scroll.documentView =` — the manual path never got `isVerticallyResizable`,
    /// `textContainer.widthTracksTextView`, or a height/leading/trailing constraint for the text
    /// view, so the popover chrome rendered but the text never actually laid out: `textStorage`
    /// had the diff, the view just never sized itself to show it.
    static func makeDiffScrollView(_ text: String) -> (scroll: NSScrollView, textView: NSTextView, fileRanges: [(name: String, location: Int)]) {
        let mono = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let monoBold = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        let baseAttrs: [NSAttributedString.Key: Any] = [.font: mono, .foregroundColor: NSColor.labelColor]

        let attributed = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        var fileRanges: [(name: String, location: Int)] = []

        for (i, line) in lines.enumerated() {
            let suffix = i < lines.count - 1 ? "\n" : ""
            let full = line + suffix
            if line.hasPrefix("diff --git ") {
                // Extract file name from "diff --git a/foo b/foo"
                let parts = line.split(separator: " ")
                let name = parts.count >= 4 ? String(parts.last!.dropFirst(2)) : line
                fileRanges.append((name: name, location: attributed.length))
                attributed.append(NSAttributedString(string: full, attributes: [.font: monoBold, .foregroundColor: NSColor.systemBlue]))
            } else if line.hasPrefix("@@") {
                attributed.append(NSAttributedString(string: full, attributes: [.font: monoBold, .foregroundColor: NSColor.systemPurple]))
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                attributed.append(NSAttributedString(string: full, attributes: [.font: mono, .foregroundColor: NSColor.systemGreen]))
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                attributed.append(NSAttributedString(string: full, attributes: [.font: mono, .foregroundColor: NSColor.systemRed]))
            } else if line.hasPrefix("+++") || line.hasPrefix("---") {
                attributed.append(NSAttributedString(string: full, attributes: [.font: monoBold, .foregroundColor: NSColor.labelColor]))
            } else {
                attributed.append(NSAttributedString(string: full, attributes: baseAttrs))
            }
        }

        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.textStorage?.setAttributedString(attributed)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return (scroll, textView, fileRanges)
    }

    // MARK: - Hunk staging (P39 G4)

    /// Splits `git diff`/`git diff --cached` output for a single file into the shared file
    /// header (`diff --git`/`index`/`---`/`+++` lines, needed on every per-hunk patch for
    /// `git apply` to accept it) and each individual `@@ …` hunk's lines. Pure/testable —
    /// no process spawn, no popover.
    nonisolated static func parseDiffHunks(_ text: String) -> (header: [String], hunks: [[String]]) {
        let lines = text.components(separatedBy: "\n")
        guard let firstHunkIndex = lines.firstIndex(where: { $0.hasPrefix("@@") }) else {
            return (lines, [])
        }
        let header = Array(lines[0..<firstHunkIndex])
        var hunks: [[String]] = []
        var current: [String] = []
        for line in lines[firstHunkIndex...] {
            if line.hasPrefix("@@") {
                if !current.isEmpty { hunks.append(current) }
                current = [line]
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { hunks.append(current) }
        // Drop a trailing empty element from the final line's "\n" split — not a real hunk line.
        if hunks.last?.last == "" { hunks[hunks.count - 1].removeLast() }
        return (header, hunks)
    }

    /// A single hunk's patch text, valid on its own for `git apply --cached [-R]`.
    nonisolated static func patchText(header: [String], hunk: [String]) -> String {
        (header + hunk).joined(separator: "\n") + "\n"
    }

    /// Applies (or reverses) one hunk's patch against the index only, via a temp file — `runGit`
    /// goes through `Process` args, not stdin, so the patch is written to disk first, same
    /// tmp-file pattern `showChangedFileDiff`/`showCommitDetail` already use for diff text.
    private func applyHunkPatch(header: [String], hunk: [String], reverse: Bool, path: String) async -> GitResult {
        let tmpDir = NSTemporaryDirectory() + "kouen-patch/"
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        let tmpPath = tmpDir + "\(UUID().uuidString).patch"
        let patch = Self.patchText(header: header, hunk: hunk)
        do {
            try patch.write(toFile: tmpPath, atomically: true, encoding: .utf8)
        } catch {
            return GitResult(output: "", stderr: "Failed to write patch: \(error.localizedDescription)", success: false)
        }
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }
        var args = ["apply", "--cached"]
        if reverse { args.append("-R") }
        args.append(tmpPath)
        return await runGitWithStatus(args, in: path)
    }

    @objc private func showHunkStaging(_ sender: NSButton) {
        guard let path = currentPath, let file = sender.toolTip else { return }
        Task {
            async let unstagedTask = runGit(["diff", "--", file], in: path)
            async let stagedTask = runGit(["diff", "--cached", "--", file], in: path)
            let unstaged = await unstagedTask
            let staged = await stagedTask
            guard sender.window != nil else { return }
            presentHunkStagingPopover(unstagedDiff: unstaged, stagedDiff: staged, anchor: sender)
        }
    }

    private func presentHunkStagingPopover(unstagedDiff: String, stagedDiff: String, anchor: NSView) {
        let (unstagedHeader, unstagedHunks) = Self.parseDiffHunks(unstagedDiff)
        let (stagedHeader, stagedHunks) = Self.parseDiffHunks(stagedDiff)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false

        if unstagedHunks.isEmpty && stagedHunks.isEmpty {
            stack.addArrangedSubview(makeLabel("No hunks — file is fully staged, fully unstaged, or untracked."))
        }
        if !unstagedHunks.isEmpty {
            let label = makeLabel("Unstaged")
            label.font = .boldSystemFont(ofSize: 12)
            stack.addArrangedSubview(label)
            for hunk in unstagedHunks {
                stack.addArrangedSubview(makeHunkCard(header: unstagedHeader, hunk: hunk, reverse: false))
            }
        }
        if !stagedHunks.isEmpty {
            let label = makeLabel("Staged")
            label.font = .boldSystemFont(ofSize: 12)
            stack.addArrangedSubview(label)
            for hunk in stagedHunks {
                stack.addArrangedSubview(makeHunkCard(header: stagedHeader, hunk: hunk, reverse: true))
            }
        }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = stack
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 420))
        contentView.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: contentView.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
        ])

        let controller = NSViewController()
        controller.view = contentView
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxX)
    }

    private func makeHunkCard(header: [String], hunk: [String], reverse: Bool) -> NSView {
        let (scroll, _, _) = Self.makeDiffScrollView(hunk.joined(separator: "\n"))
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: min(180, CGFloat(hunk.count) * 14 + 16)).isActive = true

        let button = HunkActionButton(title: reverse ? "Unstage" : "Stage") { [weak self] in
            guard let self, let path = self.currentPath else { return }
            Task {
                let result = await self.applyHunkPatch(header: header, hunk: hunk, reverse: reverse, path: path)
                if result.success {
                    Toast.show("✓ Hunk \(reverse ? "unstaged" : "staged")", in: self)
                } else {
                    Toast.show("✗ \(GitPanelView.toastErrorSummary(result.stderr))", in: self, hold: 4.0)
                }
                await self.refresh()
            }
        }

        let card = NSStackView(views: [scroll, button])
        card.orientation = .vertical
        card.alignment = .trailing
        card.spacing = 4
        card.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 440).isActive = true
        return card
    }

    private func presentCommitDetail(_ text: String, anchor: NSView) {
        let (scroll, textView, fileRanges) = Self.makeDiffScrollView(text)

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 400))

        // File navigation bar (if files found)
        if !fileRanges.isEmpty {
            let navScroll = NSScrollView()
            navScroll.hasVerticalScroller = false
            navScroll.hasHorizontalScroller = true
            navScroll.drawsBackground = false
            navScroll.translatesAutoresizingMaskIntoConstraints = false

            let navStack = NSStackView()
            navStack.orientation = .horizontal
            navStack.spacing = 4
            navStack.translatesAutoresizingMaskIntoConstraints = false

            for entry in fileRanges {
                let btn = NSButton(title: entry.name, target: nil, action: nil)
                btn.bezelStyle = .inline
                btn.isBordered = true
                btn.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
                btn.tag = entry.location
                btn.target = self
                btn.action = #selector(scrollToFileInDiff(_:))
                btn.identifier = NSUserInterfaceItemIdentifier("diffNav")
                navStack.addArrangedSubview(btn)
            }

            navScroll.documentView = navStack
            contentView.addSubview(navScroll)
            contentView.addSubview(scroll)

            NSLayoutConstraint.activate([
                navScroll.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
                navScroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
                navScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
                navScroll.heightAnchor.constraint(equalToConstant: 24),
                navStack.topAnchor.constraint(equalTo: navScroll.contentView.topAnchor),
                navStack.leadingAnchor.constraint(equalTo: navScroll.contentView.leadingAnchor),
                navStack.heightAnchor.constraint(equalTo: navScroll.contentView.heightAnchor),
                scroll.topAnchor.constraint(equalTo: navScroll.bottomAnchor, constant: 4),
                scroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                scroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        } else {
            contentView.addSubview(scroll)
            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: contentView.topAnchor),
                scroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                scroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }

        // Store textView ref for scroll action
        contentView.identifier = NSUserInterfaceItemIdentifier("commitDetailContent")
        textView.identifier = NSUserInterfaceItemIdentifier("commitDiffTextView")

        let controller = NSViewController()
        controller.view = contentView

        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxX)
    }

    @objc private func scrollToFileInDiff(_ sender: NSButton) {
        // Walk up to find the text view via identifier
        var view: NSView? = sender
        while let v = view {
            if v.identifier?.rawValue == "commitDetailContent" {
                if let textView = findSubview(of: v, identifier: "commitDiffTextView") as? NSTextView {
                    let location = sender.tag
                    let length = textView.textStorage?.length ?? 0
                    guard location < length else { return }
                    textView.scrollRangeToVisible(NSRange(location: location, length: 0))
                    textView.setSelectedRange(NSRange(location: location, length: 0))
                }
                return
            }
            view = v.superview
        }
    }

    private func findSubview(of view: NSView, identifier: String) -> NSView? {
        if view.identifier?.rawValue == identifier { return view }
        for sub in view.subviews {
            if let found = findSubview(of: sub, identifier: identifier) { return found }
        }
        return nil
    }

    @objc private func toggleStage(_ sender: StageToggleButton) {
        guard let path = currentPath, let file = sender.toolTip else { return }
        let wantsStaged = !sender.isStaged
        sender.isStaged = wantsStaged
        if wantsStaged {
            manuallyUnstagedFiles.remove(file)
        } else {
            manuallyUnstagedFiles.insert(file)
        }
        NSLog("[GitPanel] toggleStage: file=%@ wantsStaged=%d path=%@", file, wantsStaged ? 1 : 0, path)
        Task {
            let result = await runGit(wantsStaged ? ["add", file] : ["restore", "--staged", file], in: path)
            NSLog("[GitPanel] git result: %@", result)
            await refresh()
        }
    }

    private func runAndRefresh(_ args: [String], clearField: Bool = false) {
        guard let path = currentPath else { return }
        let label = args.first?.capitalized ?? "Git"
        syncButton.isEnabled = false
        syncButton.title = "\(label)…"
        Task {
            let result = await runGitWithStatus(args, in: path)
            syncButton.isEnabled = true
            syncButton.title = "Sync ▾"
            if result.success {
                if clearField { commitField.stringValue = "" }
                Toast.show("✓ \(label) complete", in: self)
            } else {
                let msg = GitPanelView.toastErrorSummary(result.stderr)
                Toast.show("✗ \(label) failed: \(msg)", in: self, hold: 4.0)
            }
            await refresh()
            // Git ops modify .git/ and fire FSEvents — cancel the debounced refresh
            // that would trigger a second full rebuild 0.5 s later.
            watchDebounce?.cancel()
        }
    }

    private struct GitResult { let output: String; let stderr: String; let success: Bool }

    /// Reduces raw git stderr (often multi-line, full of `hint:` boilerplate) to a
    /// single line fit for a toast: prefers `error:`/`fatal:` lines over noise like
    /// the `To <remote>` / `hint:` lines git prints alongside the real failure, and
    /// marks truncation with `…` so a cut string doesn't read as a complete one.
    nonisolated static func toastErrorSummary(_ stderr: String) -> String {
        let lines = stderr.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("hint:") }
        let errorLines = lines.filter { $0.hasPrefix("error:") || $0.hasPrefix("fatal:") }
        let summary = (errorLines.isEmpty ? lines : errorLines).joined(separator: " ")
        let fallback = summary.isEmpty ? stderr.trimmingCharacters(in: .whitespacesAndNewlines) : summary
        guard fallback.count > 120 else { return fallback }
        return String(fallback.prefix(120)) + "…"
    }

    /// `DaemonClient.request()` is synchronous under the hood (blocking queue.sync + poll/read
    /// loop, up to its 2s timeout) despite this function's own `async` signature — without
    /// `Task.detached` here, every caller's `Task { }` (implicitly @MainActor, since this is an
    /// NSView) blocks the main thread for the full IPC round-trip. Found via review while adding
    /// hunk staging (P39 C1) — fixed at the shared call site so the pre-existing Sync/Pull/Push
    /// button and worktree-remove get the same fix, not just the new caller (RL-052).
    /// `DaemonClient.request()` defaults to a 2s timeout — fine for local ops (`status`, `log`)
    /// but too short for anything touching the network. `fetch`/`pull`/`push` routinely take
    /// 3+ seconds for the SSH handshake + GitHub round trip alone (measured directly: a plain
    /// `git fetch` on this repo took 3.48s) — every caller here (Sync/Pull/Push button,
    /// `doCommitAndPush`'s push half, worktree-remove) was silently timing out on ordinary
    /// network latency, not a real failure. Same class of bug as RL-048 (WKWebView ops needing
    /// `timeout:35` instead of the 2s default) — that fix never got applied to git. 30s matches
    /// the daemon's own internal 60s kill-ceiling for a hung `git` process (`runGitCommandInDaemon`)
    /// with room to spare, while still failing well before a truly stuck operation would hang the UI.
    private func runGitWithStatus(_ args: [String], in directory: String) async -> GitResult {
        await Task.detached(priority: .utility) {
            do {
                let client = DaemonClient()
                let response = try client.request(.runGit(args: args, cwd: directory), timeout: 30)
                if case let .gitResult(output, stderr, success) = response {
                    return GitResult(output: output, stderr: stderr, success: success)
                } else if case let .error(err) = response {
                    return GitResult(output: "", stderr: err, success: false)
                } else {
                    return GitResult(output: "", stderr: "Unexpected daemon response", success: false)
                }
            } catch {
                // `DaemonClientError` is `CustomStringConvertible`, not `LocalizedError` — plain
                // `.localizedDescription` falls back to Foundation's generic NSError bridging
                // ("The operation couldn't be completed (KouenCore.DaemonClientError error 1.)"),
                // which is what actually showed in the Git panel instead of a readable message.
                let message = (error as? DaemonClientError)?.description ?? error.localizedDescription
                return GitResult(output: "", stderr: message, success: false)
            }
        }.value
    }

    // MARK: - Refresh

    private func refresh() async {
        guard let path = currentPath else { return }
        // Fix 5: Skip refresh when panel is not visible
        guard window != nil, !isHiddenOrHasHiddenAncestor else { return }
        refreshGeneration += 1
        let generation = refreshGeneration

        // Fix 4: Run independent git queries in parallel
        async let branchTask = runGit(["branch", "--show-current"], in: path)
        async let aheadBehindTask = runGit(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], in: path)
        async let numstatTask = runGit(["diff", "--numstat", "HEAD"], in: path)
        async let porcelainTask = runGit(["status", "--porcelain"], in: path)
        async let logTask = runGit(["log", "--format=%H|%an|%ar|%s", "-\(historyLimit)"], in: path)

        let branch = await branchTask
        let aheadBehind = await aheadBehindTask
        let numstat = await numstatTask
        let porcelain = await porcelainTask
        let log = await logTask

        // A newer refresh started while these git calls were in flight — its
        // result will supersede ours, so discard this stale snapshot instead
        // of overwriting the UI with out-of-date staged/changed state.
        guard generation == refreshGeneration else { return }

        // Paint immediately from this first fetch — don't block the initial
        // render on the auto-stage round trip below.
        applyState(branch: branch, aheadBehind: aheadBehind, numstat: numstat, porcelain: porcelain, log: log)
        await reconcileMergeConflicts(generation: generation)
        await refreshWorktrees(generation: generation)

        // Auto-stage unstaged changes that are not manually unstaged, then
        // repaint in the background if that changed anything.
        var filesToAutoStage: [String] = []
        for line in porcelain.components(separatedBy: "\n") where !line.isEmpty {
            let indexStatus = String(line.prefix(1))
            let workTreeStatus = String(line.dropFirst().prefix(1))
            let file = String(line.dropFirst(3))

            let isUnstaged = workTreeStatus != " " || indexStatus == "?"
            if isUnstaged && !manuallyUnstagedFiles.contains(file) {
                filesToAutoStage.append(file)
            }
        }

        guard !filesToAutoStage.isEmpty else { return }

        suppressingFSEvents = true
        _ = await runGit(["add", "--"] + filesToAutoStage, in: path)
        suppressingFSEvents = false
        let restagedPorcelain = await runGit(["status", "--porcelain"], in: path)
        let restagedNumstat = await runGit(["diff", "--numstat", "HEAD"], in: path)
        guard generation == refreshGeneration else { return }
        applyState(branch: branch, aheadBehind: aheadBehind, numstat: restagedNumstat, porcelain: restagedPorcelain, log: log)
    }

    private func applyState(branch: String, aheadBehind: String, numstat: String, porcelain: String, log: String) {
        if porcelain.isEmpty {
            manuallyUnstagedFiles.removeAll()
        }

        let stateChanged = branch != lastBranch ||
                           aheadBehind != lastAheadBehind ||
                           numstat != lastNumstat ||
                           porcelain != lastPorcelain ||
                           log != lastLog

        if !stateChanged {
            return
        }

        lastBranch = branch
        lastAheadBehind = aheadBehind
        lastNumstat = numstat
        lastPorcelain = porcelain
        lastLog = log

        branchLabel.stringValue = "⎇ " + (branch.isEmpty ? "detached" : branch)

        // Update sync button to reflect ahead/behind state
        let parts = aheadBehind.components(separatedBy: "\t")
        let behind = Int(parts.first ?? "") ?? 0
        let ahead = Int(parts.last ?? "") ?? 0
        if ahead > 0 && behind > 0 {
            syncButton.title = "↑\(ahead) ↓\(behind)"
        } else if ahead > 0 {
            syncButton.title = "Push ↑\(ahead)"
        } else if behind > 0 {
            syncButton.title = "Pull ↓\(behind)"
        } else {
            syncButton.title = "Sync ▾"
        }

        let changeCount = porcelain.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        tabSelector.setLabel("Changes (\(changeCount))", forSegment: 0)

        var hasUnstaged = false
        var hasStaged = false
        for line in porcelain.components(separatedBy: "\n") where !line.isEmpty {
            let xy = line.prefix(2)
            let indexStatus = String(xy.first ?? Character(" "))
            let workTreeStatus = String(xy.last ?? Character(" "))

            let isStaged = indexStatus != " " && indexStatus != "?"
            if isStaged {
                hasStaged = true
            }
            let isUnstaged = workTreeStatus != " " || indexStatus == "?"
            if isUnstaged {
                hasUnstaged = true
            }
        }

        if hasUnstaged {
            stageAllButton.title = "Stage All"
        } else if hasStaged {
            stageAllButton.title = "Unstage All"
        } else {
            stageAllButton.title = "Stage All"
        }

        // Map file path -> (additions, deletions) from `git diff --numstat HEAD`
        var stats: [String: (Int, Int)] = [:]
        for line in numstat.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 3, let added = Int(parts[0]), let deleted = Int(parts[1]) else { continue }
            stats[parts[2]] = (added, deleted)
        }

        // Changes
        // CATransaction with actions disabled: without it, removeFromSuperview + addArrangedSubview
        // implicitly animate, and a leftover badge layer can paint over the new row's label for one
        // frame — clips the filename's first character (e.g. "README.md" renders as "EADME.md").
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if porcelain.isEmpty {
            changesStack.addArrangedSubview(makeLabel("Working tree clean"))
        } else {
            for line in porcelain.components(separatedBy: "\n").prefix(40) where !line.isEmpty {
                let file = String(line.dropFirst(3))
                let row = makeChangeRow(line, stats: stats[file])
                changesStack.addArrangedSubview(row)
                row.leadingAnchor.constraint(equalTo: changesStack.leadingAnchor).isActive = true
                row.trailingAnchor.constraint(equalTo: changesStack.trailingAnchor).isActive = true
            }
        }
        changesStack.layoutSubtreeIfNeeded()
        CATransaction.commit()

        // History
        historyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let logLines = log.components(separatedBy: "\n").filter { !$0.isEmpty }
        for line in logLines {
            let card = makeHistoryCard(line)
            historyStack.addArrangedSubview(card)
            card.leadingAnchor.constraint(equalTo: historyStack.leadingAnchor).isActive = true
            card.trailingAnchor.constraint(equalTo: historyStack.trailingAnchor).isActive = true
        }
        // `git log -N` returning exactly N commits means there may be more — offer to fetch
        // another page rather than silently capping history at historyLimit forever.
        if logLines.count >= historyLimit {
            let loadMore = NSButton(title: "Load more", target: self, action: #selector(loadMoreHistoryAction))
            loadMore.bezelStyle = .recessed
            loadMore.controlSize = .small
            loadMore.font = .systemFont(ofSize: 11, weight: .medium)
            loadMore.translatesAutoresizingMaskIntoConstraints = false
            historyStack.addArrangedSubview(loadMore)
            loadMore.leadingAnchor.constraint(equalTo: historyStack.leadingAnchor).isActive = true
        }
    }

    @objc private func loadMoreHistoryAction() {
        historyLimit += historyPageSize
        Task { await refresh() }
    }

    // MARK: - Row builders

    /// Finds the agent (if any) running in a tab whose cwd or tracked worktree root matches
    /// `path`, so the worktree card can show who's working there — the same `Tab.agent` data
    /// the Board/Notch HUD already read, just not previously surfaced next to the worktree list.
    /// `nonisolated static` + explicit `tabs` (mirrors `isNoisyGitInternalPath`) so this stays
    /// unit-testable without a live `SessionCoordinator`.
    /// Parses `git worktree list --porcelain` output (blank-line-separated blocks) plus
    /// `git branch --merged main --format=%(refname:short)` output into entries.
    nonisolated static func parseWorktreePorcelain(_ output: String, mergedBranchOutput: String) -> [WorktreeEntry] {
        let entries = output.components(separatedBy: "\n\n").enumerated().compactMap { index, block -> WorktreeEntry? in
            let lines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard let worktreeLine = lines.first(where: { $0.hasPrefix("worktree ") }),
                  let headLine = lines.first(where: { $0.hasPrefix("HEAD ") }) else { return nil }
            let worktreePath = String(worktreeLine.dropFirst("worktree ".count))
            let head = String(headLine.dropFirst("HEAD ".count))
            let branchLine = lines.first(where: { $0.hasPrefix("branch ") })
            let branch = branchLine.map { line in
                let ref = String(line.dropFirst("branch ".count))
                return ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
            } ?? "detached"
            let isLocked = lines.contains { line in
                line == "locked" || line.hasPrefix("locked ")
            }
            return WorktreeEntry(path: worktreePath, head: head, branch: branch, isMain: index == 0, isLocked: isLocked, isMerged: false)
        }

        let mergedBranches = Set(mergedBranchOutput.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        return entries.map { entry in
            WorktreeEntry(path: entry.path, head: entry.head, branch: entry.branch, isMain: entry.isMain, isLocked: entry.isLocked, isMerged: mergedBranches.contains(entry.branch))
        }
    }

    nonisolated static func agentInfo(forWorktreePath path: String, tabs: [Tab]) -> (kind: AgentKind, activity: AgentActivity)? {
        for tab in tabs {
            guard tab.cwd == path || tab.worktreePath == path, let agent = tab.agent else { continue }
            return (agent.kind, agent.activity)
        }
        return nil
    }

    private func agentInfo(forWorktreePath path: String) -> (kind: AgentKind, activity: AgentActivity)? {
        let tabs = SessionCoordinator.shared.snapshot.workspaces.flatMap { $0.sessions.flatMap(\.tabs) }
        return Self.agentInfo(forWorktreePath: path, tabs: tabs)
    }

    private func makeStatusBadge(letter: String, color: NSColor) -> NSView {
        let badge = NSView()
        badge.wantsLayer = true
        badge.layer?.backgroundColor = color.withAlphaComponent(0.18).cgColor
        badge.layer?.cornerRadius = 4
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: letter)
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = color
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 18),
            badge.heightAnchor.constraint(equalToConstant: 18),
            label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])
        return badge
    }

    private func makeChangeRow(_ line: String, stats: (Int, Int)?) -> NSView {
        let xy = line.prefix(2)
        let indexStatus = String(xy.first ?? Character(" "))
        let file = String(line.dropFirst(3))
        let isStaged = indexStatus != " " && indexStatus != "?"
        let workTree = String(xy.last ?? Character(" "))

        let statusKey = isStaged ? indexStatus : workTree
        let color: NSColor
        let letter: String
        switch statusKey {
        case "M": color = .systemOrange; letter = "M"
        case "A": color = .systemGreen; letter = "A"
        case "D": color = .systemRed; letter = "D"
        case "?": color = .systemGreen; letter = "U"
        default: color = KouenDesign.chrome.textSecondary; letter = "M"
        }

        let badge = makeStatusBadge(letter: letter, color: color)

        let check = StageToggleButton()
        check.isStaged = isStaged
        check.toolTip = file
        check.target = self
        check.action = #selector(toggleStage(_:))

        let name = NSTextField(labelWithString: (file as NSString).lastPathComponent)
        name.font = .systemFont(ofSize: 12)
        name.textColor = color
        name.lineBreakMode = .byTruncatingMiddle
        name.toolTip = file
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)

        var rowViews: [NSView] = [badge, name]

        if let (added, deleted) = stats, added + deleted > 0 {
            let statsLabel = NSTextField(labelWithString: "")
            statsLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            let attributed = NSMutableAttributedString()
            if added > 0 {
                attributed.append(NSAttributedString(string: "+\(added) ", attributes: [.foregroundColor: NSColor.systemGreen]))
            }
            if deleted > 0 {
                attributed.append(NSAttributedString(string: "-\(deleted)", attributes: [.foregroundColor: NSColor.systemRed]))
            }
            statsLabel.attributedStringValue = attributed
            statsLabel.setContentHuggingPriority(.required, for: .horizontal)
            statsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            rowViews.append(statsLabel)
        }

        // P39 G4: per-hunk stage/unstage, separate from the whole-file `check` toggle above.
        // Bug found in manual testing: no explicit size constraint meant a plain NSButton with
        // only an image (no intrinsic content size guarantee) collapsed to zero-width inside the
        // .fill-distribution NSStackView — same class of issue StageToggleButton avoids with its
        // explicit 16x16 constraints. Symbol falls back to a certainly-valid one if
        // "square.split.2x1" ever fails to resolve, so a bad symbol name can't reproduce this.
        let hunksButton = NSButton(
            image: NSImage(systemSymbolName: "square.split.2x1", accessibilityDescription: "Stage hunks")
                ?? NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Stage hunks")
                ?? NSImage(),
            target: self, action: #selector(showHunkStaging(_:)))
        hunksButton.translatesAutoresizingMaskIntoConstraints = false
        hunksButton.isBordered = false
        hunksButton.bezelStyle = .inline
        hunksButton.toolTip = file
        hunksButton.setContentHuggingPriority(.required, for: .horizontal)
        hunksButton.setButtonType(.momentaryChange)
        (hunksButton.cell as? NSButtonCell)?.imageScaling = .scaleProportionallyDown
        hunksButton.widthAnchor.constraint(equalToConstant: 16).isActive = true
        hunksButton.heightAnchor.constraint(equalToConstant: 16).isActive = true
        rowViews.append(hunksButton)

        check.setContentHuggingPriority(.required, for: .horizontal)
        rowViews.append(check)

        let row = NSStackView(views: rowViews)
        row.orientation = .horizontal; row.spacing = 6; row.alignment = .centerY
        row.distribution = .fill
        row.edgeInsets = NSEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        row.identifier = NSUserInterfaceItemIdentifier(file)
        let click = NSClickGestureRecognizer(target: self, action: #selector(showChangedFileDiff(_:)))
        click.delegate = self
        row.addGestureRecognizer(click)
        return row
    }

    @objc private func showChangedFileDiff(_ sender: NSClickGestureRecognizer) {
        guard let path = currentPath,
              let row = sender.view,
              let file = row.identifier?.rawValue else { return }
        guard let split = self.window?.contentViewController as? MainSplitViewController else { return }

        // File still exists on disk (modified/added/untracked): open it as a normal
        // syntax-highlighted preview — FileEditorView colors the changed lines itself.
        let fullPath = path + "/" + file
        if FileManager.default.fileExists(atPath: fullPath) {
            split.contentVC.openFileTab(path: fullPath)
            return
        }

        // Deleted file: nothing on disk to preview, fall back to the raw diff text.
        Task {
            let diff = await runGit(["diff", "HEAD", "--", file], in: path)
            let tmpDir = NSTemporaryDirectory() + "kouen-diff/"
            try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
            let safeName = file.replacingOccurrences(of: "/", with: "_")
            let tmpPath = tmpDir + "\(safeName).diff"
            try? diff.write(toFile: tmpPath, atomically: true, encoding: .utf8)
            split.contentVC.openFileTab(path: tmpPath)
        }
    }

    private func makeHistoryCard(_ line: String) -> NSView {
        let parts = line.split(separator: "|", maxSplits: 3).map(String.init)
        guard parts.count >= 4 else { return makeLabel(line) }
        let fullHash = parts[0]
        let hash = String(fullHash.prefix(7))
        let author = parts[1]
        let time = parts[2]
        let subject = parts[3]

        let card = NSView()
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.identifier = NSUserInterfaceItemIdentifier(fullHash)
        card.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(previewCommitDetail(_:))))

        // Right-click context menu
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy Commit ID", action: #selector(copyCommitID(_:)), keyEquivalent: "").representedObject = fullHash
        menu.addItem(withTitle: "Copy Commit Message", action: #selector(copyCommitMessage(_:)), keyEquivalent: "").representedObject = subject
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Copy \(hash) — \(subject)", action: #selector(copyCommitSummary(_:)), keyEquivalent: "").representedObject = "\(hash) \(subject)"
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Open Full Diff in Tab", action: #selector(showCommitDetail(_:)), keyEquivalent: "").representedObject = card
        menu.items.forEach { $0.target = self }
        // Fix: showCommitDetail needs the card view via representedObject for menu path
        menu.items.last?.representedObject = card
        card.menu = menu

        // Subject line
        let subjectLabel = NSTextField(labelWithString: subject)
        subjectLabel.font = .systemFont(ofSize: 12)
        subjectLabel.textColor = KouenDesign.chrome.textPrimary
        subjectLabel.lineBreakMode = .byTruncatingTail
        subjectLabel.translatesAutoresizingMaskIntoConstraints = false

        // Author · time · hash
        let meta = NSTextField(labelWithString: "\(author) · \(time) · \(hash)")
        meta.font = .systemFont(ofSize: 10)
        meta.textColor = KouenDesign.chrome.textTertiary
        meta.lineBreakMode = .byTruncatingTail
        meta.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(subjectLabel)
        card.addSubview(meta)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 40),
            subjectLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 5),
            subjectLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            subjectLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            meta.topAnchor.constraint(equalTo: subjectLabel.bottomAnchor, constant: 1),
            meta.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            meta.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
        ])
        return card
    }

    private func makeWorktreeRow(_ worktree: WorktreeEntry) -> NSView {
        if let conflict = activeMergeConflicts[worktree.path] {
            return makeConflictCard(sourcePath: worktree.path, branch: worktree.branch, conflict: conflict)
        }

        let card = WorktreeCardView()
        card.onSelect = { [weak self] in self?.cdToWorktree(worktree.path) }
        card.onClose = { [weak self] in self?.removeWorktreeAction(path: worktree.path) }
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.identifier = NSUserInterfaceItemIdentifier(worktree.path)

        if isCurrentWorktree(worktree.path) {
            card.layer?.backgroundColor = KouenDesign.chrome.accent.withAlphaComponent(0.14).cgColor
            card.layer?.cornerRadius = 6
            card.layer?.borderColor = KouenDesign.chrome.accent.withAlphaComponent(0.45).cgColor
            card.layer?.borderWidth = 1
        }

        // Click handling: use mouseUp on card (same as BrowserTabButton pattern)
        // SoftIconButton is isTransparent=true so target/action won't fire — handle in mouseUp
        card.identifier = NSUserInterfaceItemIdentifier(worktree.path)

        let name = NSTextField(labelWithString: KouenDesign.shortenPath(worktree.path))
        name.font = .systemFont(ofSize: 12, weight: .bold)
        name.textColor = KouenDesign.chrome.textPrimary
        name.lineBreakMode = .byTruncatingMiddle
        name.toolTip = worktree.path
        name.translatesAutoresizingMaskIntoConstraints = false

        let agent = agentInfo(forWorktreePath: worktree.path)

        var titleViews: [NSView] = [name]
        if let agent {
            let dotColor = NSColor.fromHex(agent.kind.dotHex) ?? .secondaryLabelColor
            let icon = AgentIconRenderer.coloredOrMonogramImage(for: agent.kind, size: 12, color: dotColor)
            let agentIcon = NSImageView(image: icon)
            agentIcon.translatesAutoresizingMaskIntoConstraints = false
            agentIcon.toolTip = "\(agent.kind.displayName) — \(agent.activity.rawValue)"
            agentIcon.setContentHuggingPriority(.required, for: .horizontal)
            agentIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
            NSLayoutConstraint.activate([
                agentIcon.widthAnchor.constraint(equalToConstant: 12),
                agentIcon.heightAnchor.constraint(equalToConstant: 12),
            ])
            titleViews.append(agentIcon)
        }
        if worktree.isLocked,
           let image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Locked")?
            .withSymbolConfiguration(KouenDesign.symbolConfig(pointSize: 10, weight: .semibold)) {
            let lock = NSImageView(image: image)
            lock.contentTintColor = KouenDesign.chrome.textTertiary
            lock.translatesAutoresizingMaskIntoConstraints = false
            lock.setContentHuggingPriority(.required, for: .horizontal)
            lock.setContentCompressionResistancePriority(.required, for: .horizontal)
            titleViews.append(lock)
        }

        let titleRow = NSStackView(views: titleViews)
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 5
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        var metaText: String
        if worktree.isMerged {
            metaText = "✓ merged · \(worktree.branch)"
        } else if let agent {
            metaText = "\(worktree.branch) · \(agent.kind.displayName) — \(agent.activity.rawValue)"
        } else {
            metaText = worktree.branch
        }
        let meta = NSTextField(labelWithString: metaText)
        meta.font = .systemFont(ofSize: 10)
        meta.textColor = worktree.isMerged ? NSColor.systemGreen : KouenDesign.chrome.textTertiary
        meta.lineBreakMode = .byTruncatingTail
        meta.translatesAutoresizingMaskIntoConstraints = false

        let removeButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        removeButton.setSymbol("xmark", accessibilityDescription: "Remove worktree", pointSize: 9, weight: .semibold)
        removeButton.target = self
        removeButton.action = #selector(removeWorktreeAction(_:))
        removeButton.identifier = NSUserInterfaceItemIdentifier(worktree.path)
        removeButton.toolTip = worktree.isMerged ? "Remove (merged — safe)" : "Remove (unmerged)"
        removeButton.isHidden = worktree.isMain
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        let diffButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        diffButton.setSymbol("magnifyingglass", accessibilityDescription: "Diff vs main", pointSize: 9, weight: .semibold)
        diffButton.target = self
        diffButton.action = #selector(previewWorktreeDiffAction(_:))
        diffButton.identifier = NSUserInterfaceItemIdentifier(worktree.path)
        diffButton.toolTip = "Everything on \(worktree.branch) since it diverged from main"
        diffButton.isHidden = worktree.isMain
        diffButton.translatesAutoresizingMaskIntoConstraints = false

        let mergeButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        mergeButton.setSymbol("arrow.triangle.merge", accessibilityDescription: "Merge into main", pointSize: 9, weight: .semibold)
        mergeButton.target = self
        mergeButton.action = #selector(mergeWorktreeAction(_:))
        mergeButton.identifier = NSUserInterfaceItemIdentifier(worktree.path)
        mergeButton.toolTip = "Merge \(worktree.branch) into the main worktree"
        // "detached" (parseWorktreePorcelain's placeholder for a HEAD with no branch) isn't a
        // real branch git can merge — hide the button rather than let it fail confusingly.
        mergeButton.isHidden = worktree.isMain || worktree.isMerged || worktree.branch == "detached"
        mergeButton.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(titleRow)
        card.addSubview(meta)
        card.addSubview(diffButton)
        card.addSubview(mergeButton)
        card.addSubview(removeButton)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 40),
            titleRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 5),
            titleRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            titleRow.trailingAnchor.constraint(equalTo: diffButton.leadingAnchor, constant: -4),
            meta.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 1),
            meta.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            meta.trailingAnchor.constraint(equalTo: diffButton.leadingAnchor, constant: -4),
            diffButton.trailingAnchor.constraint(equalTo: mergeButton.leadingAnchor, constant: -2),
            diffButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            diffButton.widthAnchor.constraint(equalToConstant: 24),
            mergeButton.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -2),
            mergeButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            mergeButton.widthAnchor.constraint(equalToConstant: 24),
            removeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            removeButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 24),
        ])
        return card
    }

    /// Red-tinted conflict card, rendered in place of the normal worktree row (see
    /// `makeWorktreeRow`'s early check) whenever `activeMergeConflicts` has an entry for that
    /// row's path. Shows the conflicted files and offers exactly two actions — abort, or go
    /// resolve manually — never an auto-resolve.
    private func makeConflictCard(sourcePath: String, branch: String, conflict: (mainWorktreePath: String, files: [String])) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.12).cgColor
        card.layer?.cornerRadius = 6
        card.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.4).cgColor
        card.layer?.borderWidth = 1
        card.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "⚠ Merge conflict — \(branch)")
        title.font = .systemFont(ofSize: 12, weight: .bold)
        title.textColor = .systemRed
        title.translatesAutoresizingMaskIntoConstraints = false

        let fileList = conflict.files.isEmpty ? "(no conflicted files reported)" : conflict.files.joined(separator: ", ")
        let files = NSTextField(labelWithString: fileList)
        files.font = .systemFont(ofSize: 10)
        files.textColor = KouenDesign.chrome.textSecondary
        files.lineBreakMode = .byTruncatingTail
        files.translatesAutoresizingMaskIntoConstraints = false

        let abortButton = HunkActionButton(title: "Abort Merge") { [weak self] in
            self?.abortMergeAction(sourcePath: sourcePath, mainWorktreePath: conflict.mainWorktreePath)
        }
        let resolveButton = HunkActionButton(title: "Resolve in Changes") { [weak self] in
            self?.resolveMergeInChangesAction(mainWorktreePath: conflict.mainWorktreePath)
        }
        let buttonRow = NSStackView(views: [abortButton, resolveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 6
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(title)
        card.addSubview(files)
        card.addSubview(buttonRow)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            title.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -10),

            files.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            files.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            files.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -10),

            buttonRow.topAnchor.constraint(equalTo: files.bottomAnchor, constant: 6),
            buttonRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            buttonRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -6),
        ])
        return card
    }

    private func makeWorktreesSectionHeader(count: Int) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true

        let button = NSButton(title: "", target: self, action: #selector(toggleWorktreesSection))
        button.isBordered = false
        button.image = NSImage(
            systemSymbolName: worktreesExpanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: worktreesExpanded ? "Collapse Worktrees" : "Expand Worktrees"
        )?.withSymbolConfiguration(KouenDesign.symbolConfig(pointSize: 9, weight: .semibold))
        button.imagePosition = .imageOnly
        button.contentTintColor = KouenDesign.chrome.textTertiary
        button.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "WORKTREES")
        label.font = KouenDesign.Typography.sectionLabel
        label.textColor = KouenDesign.chrome.textTertiary
        label.translatesAutoresizingMaskIntoConstraints = false

        let countLabel = NSTextField(labelWithString: "\(count)")
        countLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        countLabel.textColor = KouenDesign.chrome.textTertiary
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(button)
        row.addSubview(label)
        row.addSubview(countLabel)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 26),
            button.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            button.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 18),
            button.heightAnchor.constraint(equalToConstant: 18),
            label.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 2),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            countLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
            countLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        return row
    }

    private func isCurrentWorktree(_ path: String) -> Bool {
        guard let currentPath else { return false }
        let worktreePath = URL(fileURLWithPath: path).standardizedFileURL.path
        let activePath = URL(fileURLWithPath: currentPath).standardizedFileURL.path
        return activePath == worktreePath || activePath.hasPrefix(worktreePath + "/")
    }

    private func makeFieldRow(_ label: String, field: NSTextField) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = KouenDesign.chrome.textSecondary
        labelView.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [labelView, field])
        row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            labelView.widthAnchor.constraint(equalToConstant: 52),
        ])
        return row
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 11.5); l.textColor = KouenDesign.chrome.textTertiary
        return l
    }

    /// Shared by the single-repo Worktrees tab and the cross-repo Agents dashboard so both
    /// read worktree state through one code path instead of two copies drifting apart.
    private func fetchWorktreeEntries(repoPath: String) async -> (entries: [WorktreeEntry], rawOutput: String) {
        let output = await runGit(["worktree", "list", "--porcelain"], in: repoPath)
        let mergedOutput = await runGit(["branch", "--merged", "main", "--format=%(refname:short)"], in: repoPath)
        return (Self.parseWorktreePorcelain(output, mergedBranchOutput: mergedOutput), output)
    }

    private func refreshWorktrees(generation: Int) async {
        guard let path = currentPath else { return }
        let (finalEntries, output) = await fetchWorktreeEntries(repoPath: path)
        guard generation == refreshGeneration else { return }

        // Skip rebuild if nothing changed (prevents flicker from FSEvent re-triggers)
        if output == lastWorktreeOutput { return }
        lastWorktreeOutput = output

        worktreesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let header = makeWorktreesSectionHeader(count: finalEntries.count)
        worktreesStack.addArrangedSubview(header)
        header.leadingAnchor.constraint(equalTo: worktreesStack.leadingAnchor).isActive = true
        header.trailingAnchor.constraint(equalTo: worktreesStack.trailingAnchor).isActive = true

        if !worktreesExpanded {
            return
        } else if finalEntries.isEmpty {
            worktreesStack.addArrangedSubview(makeLabel("No worktrees"))
        } else {
            for entry in finalEntries {
                let row = makeWorktreeRow(entry)
                worktreesStack.addArrangedSubview(row)
                row.leadingAnchor.constraint(equalTo: worktreesStack.leadingAnchor).isActive = true
                row.trailingAnchor.constraint(equalTo: worktreesStack.trailingAnchor).isActive = true
            }
        }
    }

    // MARK: - Agents review dashboard

    // MARK: - Git

    private func runGit(_ args: [String], in directory: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = URL(fileURLWithPath: directory)
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    // Drain stdout before waitUntilExit(): for output >64KB the pipe
                    // buffer fills and git blocks on write() while we'd be blocked in
                    // waitUntilExit(), deadlocking (e.g. diffing graphify-out/graph.json).
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    /// Like `runGit`, but also surfaces stderr on failure instead of discarding it — used only
    /// by the two diff-preview call sites (`fetchCommitDiff`, `fetchWorktreeDiff`), where a
    /// silent empty result means the popover click does nothing with zero feedback. Kept
    /// separate from `runGit` rather than changing its shared behavior: ~20 other call sites
    /// (branch queries, ahead/behind counts, porcelain status) parse `runGit`'s output as
    /// structured data and already treat "" as their failure/empty case — swapping in an error
    /// string there risks a git failure rendering as garbage instead of the current graceful
    /// "nothing changed" fallback.
    nonisolated static func runGitDiff(_ args: [String], in directory: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = URL(fileURLWithPath: directory)
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                do {
                    try process.run()
                    // Drain both pipes concurrently, before waitUntilExit(): reading them
                    // sequentially deadlocks if the unread one fills its kernel buffer
                    // first while the child blocks writing to it (e.g. a large diff on
                    // stdout racing verbose warnings on stderr).
                    let errBox = DataBox()
                    let errGroup = DispatchGroup()
                    errGroup.enter()
                    DispatchQueue.global(qos: .userInitiated).async {
                        errBox.value = errPipe.fileHandleForReading.readDataToEndOfFile()
                        errGroup.leave()
                    }
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    errGroup.wait()
                    process.waitUntilExit()
                    let out = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if out.isEmpty, process.terminationStatus != 0 {
                        let err = String(data: errBox.value, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        continuation.resume(returning: err.isEmpty ? "" : "git \(args.first ?? "") failed: \(err)")
                        return
                    }
                    continuation.resume(returning: out)
                } catch {
                    continuation.resume(returning: "git \(args.first ?? "") failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Hands a pipe-read result across the `DispatchGroup`-synchronized background read in
    /// `runGitDiff` without the Sendable-closure-capture warning a plain `var` triggers —
    /// `errGroup.wait()` is the actual synchronization point, so the mutation is safe despite
    /// the compiler not being able to see it through the closure boundary.
    private final class DataBox: @unchecked Sendable {
        var value = Data()
    }

}

struct WorktreeEntry {
    let path: String
    let head: String
    let branch: String
    let isMain: Bool
    let isLocked: Bool
    let isMerged: Bool
}

private final class StageToggleButton: NSButton {
    var isStaged = false {
        didSet { updateAppearance() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        imagePosition = .imageOnly
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        widthAnchor.constraint(equalToConstant: 16).isActive = true
        heightAnchor.constraint(equalToConstant: 16).isActive = true
        updateAppearance()
    }

    private func updateAppearance() {
        let accent = NSColor.systemBlue
        layer?.backgroundColor = isStaged ? accent.cgColor : NSColor.black.withAlphaComponent(0.28).cgColor
        layer?.borderColor = (isStaged ? accent : KouenDesign.chrome.border).cgColor
        image = isStaged
            ? NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Staged")
            : nil
        image?.isTemplate = true
        contentTintColor = .white
        setAccessibilityLabel(isStaged ? "Unstage file" : "Stage file")
    }
}

/// A small `NSButton` that runs a closure instead of a target/action pair — used for the
/// dynamically-built hunk-staging popover (P39 G4), where each button's action needs to close
/// over that specific hunk's patch text.
private final class HunkActionButton: NSButton {
    private let onClick: () -> Void

    init(title: String, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
        self.title = title
        bezelStyle = .recessed
        controlSize = .small
        font = .systemFont(ofSize: 11, weight: .medium)
        translatesAutoresizingMaskIntoConstraints = false
        target = self
        action = #selector(handleClick)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func handleClick() { onClick() }
}

private final class FlippedView: NSView {
    // RL-040: `nonisolated` prevents the Swift 6.3 `@objc` thunk from performing an
    // actor-isolation check that dereferences metadata — this view is explicitly held
    // alive past `removeFromSuperview()` (see below) specifically because AppKit can
    // still dispatch layout/scroll callbacks like `isFlipped` to it during that window.
    nonisolated override var isFlipped: Bool { true }
    override func removeFromSuperview() {
        ZombieHoldRegistry.shared.hold(self)
        super.removeFromSuperview()
    }
}

extension GitPanelView: NSGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        guard let view = gestureRecognizer.view else { return true }
        let point = view.convert(event.locationInWindow, from: nil)
        if let hitView = view.hitTest(point) {
            var current: NSView? = hitView
            while let v = current {
                if v is StageToggleButton || v is NSButton {
                    return false
                }
                current = v.superview
            }
        }
        return true
    }
}


// MARK: - WorktreeCardView (mouseUp pattern — same as BrowserTabButton)

private final class WorktreeCardView: NSView {
    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        // Check if click landed on the remove button (SoftIconButton)
        for sub in subviews where sub is SoftIconButton {
            if sub.frame.contains(loc) {
                onClose?()
                return
            }
        }
        onSelect?()
    }
}
