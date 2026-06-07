import AppKit
import HarnessCore

@MainActor
final class GitPanelView: NSView {
    private var currentPath: String?
    private var didCommitSinceLastSync = false
    private var selectedCommitHash: String?
    private nonisolated(unsafe) var watchSource: DispatchSourceFileSystemObject?
    private nonisolated(unsafe) var watchFd: Int32 = -1
    private nonisolated(unsafe) var watchDebounce: DispatchWorkItem?

    // Top tabs: Changes | History | Worktrees
    private let tabSelector = NSSegmentedControl(labels: ["Changes", "History", "Worktrees"], trackingMode: .selectOne, target: nil, action: nil)
    private let changesContainer = NSView()
    private let historyContainer = NSView()
    private let worktreesContainer = NSView()

    // Changes view
    private let changesScroll = NSScrollView()
    private let changesStack = FlippedStackView()
    private let stageAllButton = NSButton(title: "Stage All", target: nil, action: nil)

    // Commit area (bottom of changes)
    private let commitField = NSTextField()
    private let commitButton = NSButton(title: "Commit Tracked", target: nil, action: nil)

    // History view
    private let historyScroll = NSScrollView()
    private let historyStack = FlippedStackView()
    private let historyDetailContainer = NSView()
    private let historyFilesScroll = NSScrollView()
    private let historyFilesStack = FlippedStackView()
    private let historyPreviewScroll = NSScrollView()
    private let historyPreviewTextView = NSTextView()
    private let historyEmptyLabel = NSTextField(labelWithString: "Select a commit to inspect changed files")

    // Worktrees view
    private let worktreesScroll = NSScrollView()
    private let worktreesStack = FlippedStackView()
    private let addWorktreeButton = NSButton(title: "+", target: nil, action: nil)

    // Empty state shown when not inside a git repo
    private let noRepoView = NSTextField(labelWithString: "Open a terminal session\nin a git repository")

    // Bottom bar: branch + fetch
    private let bottomBar = NSView()
    private let branchLabel = NSTextField(labelWithString: "")
    private let syncButton = NSButton(title: "Fetch ▼", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func updateRoot(path: String, force: Bool = false) {
        guard force || path != currentPath else { return }
        currentPath = path
        selectedCommitHash = nil
        startWatching(path: path)
        Task { [weak self] in await self?.refresh() }
    }

    func clearRoot() {
        currentPath = nil
        selectedCommitHash = nil
        stopWatching()
        Task { [weak self] in await self?.refresh() }
    }

    // MARK: - File Watcher

    private func startWatching(path: String) {
        stopWatching()
        let gitDir = path + "/.git"
        let watchPath = FileManager.default.fileExists(atPath: gitDir) ? gitDir : path
        let fd = open(watchPath, O_EVTONLY)
        guard fd >= 0 else { return }
        watchFd = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue.global(qos: .utility)
        )
        watchSource = source
        source.setEventHandler { [weak self] in
            self?.watchDebounce?.cancel()
            let work = DispatchWorkItem {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.refresh()
                }
            }
            self?.watchDebounce = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
        source.setCancelHandler { [fd] in close(fd) }
        source.resume()
    }

    private func stopWatching() {
        watchDebounce?.cancel()
        watchDebounce = nil
        watchSource?.cancel()
        watchSource = nil
        watchFd = -1
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
        changesStack.orientation = .vertical; changesStack.alignment = .leading; changesStack.spacing = 0
        setupScrollView(changesScroll, with: changesStack, in: changesContainer)

        // Stage All button bar
        HarnessDesign.configurePillButton(stageAllButton, title: "Stage All", symbolName: "plus.circle")
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

        HarnessDesign.configurePillButton(commitButton, title: "Commit ▼", symbolName: "checkmark.circle")
        commitButton.target = self; commitButton.action = #selector(showCommitMenu)
        commitButton.translatesAutoresizingMaskIntoConstraints = false

        // History container
        historyContainer.translatesAutoresizingMaskIntoConstraints = false
        historyContainer.isHidden = true
        historyStack.orientation = .vertical; historyStack.alignment = .leading; historyStack.spacing = 0
        setupHistoryView()

        // Worktrees container
        worktreesContainer.translatesAutoresizingMaskIntoConstraints = false
        worktreesContainer.isHidden = true
        worktreesStack.orientation = .vertical; worktreesStack.alignment = .leading; worktreesStack.spacing = 0
        setupScrollView(worktreesScroll, with: worktreesStack, in: worktreesContainer)

        HarnessDesign.configurePillButton(addWorktreeButton, title: "", symbolName: "plus")
        addWorktreeButton.target = self; addWorktreeButton.action = #selector(addWorktreeAction)
        addWorktreeButton.translatesAutoresizingMaskIntoConstraints = false
        worktreesContainer.addSubview(addWorktreeButton)

        // Bottom bar
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        branchLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        branchLabel.textColor = HarnessDesign.chrome.textSecondary
        branchLabel.lineBreakMode = .byTruncatingTail
        branchLabel.translatesAutoresizingMaskIntoConstraints = false

        let branchClick = NSClickGestureRecognizer(target: self, action: #selector(showBranchMenu))
        branchLabel.addGestureRecognizer(branchClick)
        branchLabel.isSelectable = false

        HarnessDesign.configurePillButton(syncButton, title: "Fetch ▼", symbolName: "arrow.triangle.2.circlepath")
        syncButton.target = self; syncButton.action = #selector(showSyncMenu)
        syncButton.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.addSubview(branchLabel)
        bottomBar.addSubview(syncButton)

        noRepoView.font = .systemFont(ofSize: 12)
        noRepoView.textColor = HarnessDesign.chrome.textTertiary
        noRepoView.alignment = .center
        noRepoView.isHidden = true
        noRepoView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(tabSelector)
        addSubview(stageAllButton)
        addSubview(changesContainer)
        addSubview(commitField)
        addSubview(commitButton)
        addSubview(historyContainer)
        addSubview(worktreesContainer)
        addSubview(bottomBar)
        addSubview(noRepoView)

        NSLayoutConstraint.activate([
            tabSelector.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            tabSelector.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            tabSelector.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            stageAllButton.topAnchor.constraint(equalTo: tabSelector.bottomAnchor, constant: 4),
            stageAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            changesContainer.topAnchor.constraint(equalTo: stageAllButton.bottomAnchor, constant: 2),
            changesContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            changesContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            changesContainer.bottomAnchor.constraint(equalTo: commitField.topAnchor, constant: -6),

            commitField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            commitField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            commitField.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            commitField.bottomAnchor.constraint(equalTo: commitButton.topAnchor, constant: -4),

            commitButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            commitButton.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -6),

            historyContainer.topAnchor.constraint(equalTo: tabSelector.bottomAnchor, constant: 4),
            historyContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            historyContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            historyContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -4),

            worktreesContainer.topAnchor.constraint(equalTo: tabSelector.bottomAnchor, constant: 4),
            worktreesContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            worktreesContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            worktreesContainer.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -4),

            addWorktreeButton.topAnchor.constraint(equalTo: worktreesContainer.topAnchor, constant: 4),
            addWorktreeButton.trailingAnchor.constraint(equalTo: worktreesContainer.trailingAnchor, constant: -10),
            addWorktreeButton.widthAnchor.constraint(equalToConstant: 28),

            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            bottomBar.heightAnchor.constraint(equalToConstant: 22),

            branchLabel.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            branchLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            branchLabel.trailingAnchor.constraint(lessThanOrEqualTo: syncButton.leadingAnchor, constant: -8),
            syncButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            syncButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            noRepoView.centerXAnchor.constraint(equalTo: centerXAnchor),
            noRepoView.centerYAnchor.constraint(equalTo: centerYAnchor),
            noRepoView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            noRepoView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    private func setupScrollView(_ scroll: NSScrollView, with stack: NSStackView, in container: NSView) {
        stack.translatesAutoresizingMaskIntoConstraints = false

        scroll.documentView = stack
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
            stack.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
    }

    private func setupHistoryView() {
        historyStack.translatesAutoresizingMaskIntoConstraints = false
        historyDetailContainer.translatesAutoresizingMaskIntoConstraints = false
        historyFilesStack.orientation = .vertical
        historyFilesStack.alignment = .leading
        historyFilesStack.spacing = 0
        historyFilesStack.translatesAutoresizingMaskIntoConstraints = false

        historyScroll.documentView = historyStack
        historyScroll.hasVerticalScroller = true
        historyScroll.drawsBackground = false
        historyScroll.scrollerStyle = .overlay
        historyScroll.autohidesScrollers = true
        historyScroll.translatesAutoresizingMaskIntoConstraints = false

        historyFilesScroll.documentView = historyFilesStack
        historyFilesScroll.hasVerticalScroller = true
        historyFilesScroll.drawsBackground = false
        historyFilesScroll.scrollerStyle = .overlay
        historyFilesScroll.autohidesScrollers = true
        historyFilesScroll.translatesAutoresizingMaskIntoConstraints = false

        historyPreviewTextView.isEditable = false
        historyPreviewTextView.isSelectable = true
        historyPreviewTextView.drawsBackground = false
        historyPreviewTextView.textContainerInset = NSSize(width: HarnessDesign.Spacing.sm, height: HarnessDesign.Spacing.sm)
        historyPreviewTextView.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        historyPreviewTextView.textColor = HarnessDesign.chrome.textPrimary
        historyPreviewTextView.textContainer?.widthTracksTextView = false
        historyPreviewTextView.isHorizontallyResizable = true
        historyPreviewTextView.autoresizingMask = [.width]

        historyPreviewScroll.documentView = historyPreviewTextView
        historyPreviewScroll.hasVerticalScroller = true
        historyPreviewScroll.hasHorizontalScroller = true
        historyPreviewScroll.drawsBackground = false
        historyPreviewScroll.scrollerStyle = .overlay
        historyPreviewScroll.autohidesScrollers = true
        historyPreviewScroll.translatesAutoresizingMaskIntoConstraints = false

        historyEmptyLabel.font = .systemFont(ofSize: 11.5)
        historyEmptyLabel.textColor = HarnessDesign.chrome.textTertiary
        historyEmptyLabel.alignment = .center
        historyEmptyLabel.translatesAutoresizingMaskIntoConstraints = false

        historyContainer.addSubview(historyScroll)
        historyContainer.addSubview(historyDetailContainer)
        historyDetailContainer.addSubview(historyFilesScroll)
        historyDetailContainer.addSubview(historyPreviewScroll)
        historyDetailContainer.addSubview(historyEmptyLabel)

        NSLayoutConstraint.activate([
            historyScroll.topAnchor.constraint(equalTo: historyContainer.topAnchor),
            historyScroll.leadingAnchor.constraint(equalTo: historyContainer.leadingAnchor),
            historyScroll.trailingAnchor.constraint(equalTo: historyContainer.trailingAnchor),
            historyScroll.heightAnchor.constraint(equalTo: historyContainer.heightAnchor, multiplier: 0.42),
            historyStack.leadingAnchor.constraint(equalTo: historyScroll.contentView.leadingAnchor),
            historyStack.trailingAnchor.constraint(equalTo: historyScroll.contentView.trailingAnchor),
            historyStack.widthAnchor.constraint(equalTo: historyScroll.contentView.widthAnchor),

            historyDetailContainer.topAnchor.constraint(equalTo: historyScroll.bottomAnchor, constant: 4),
            historyDetailContainer.leadingAnchor.constraint(equalTo: historyContainer.leadingAnchor),
            historyDetailContainer.trailingAnchor.constraint(equalTo: historyContainer.trailingAnchor),
            historyDetailContainer.bottomAnchor.constraint(equalTo: historyContainer.bottomAnchor),

            historyFilesScroll.topAnchor.constraint(equalTo: historyDetailContainer.topAnchor),
            historyFilesScroll.leadingAnchor.constraint(equalTo: historyDetailContainer.leadingAnchor),
            historyFilesScroll.trailingAnchor.constraint(equalTo: historyDetailContainer.trailingAnchor),
            historyFilesScroll.heightAnchor.constraint(equalToConstant: 96),
            historyFilesStack.leadingAnchor.constraint(equalTo: historyFilesScroll.contentView.leadingAnchor),
            historyFilesStack.trailingAnchor.constraint(equalTo: historyFilesScroll.contentView.trailingAnchor),
            historyFilesStack.widthAnchor.constraint(equalTo: historyFilesScroll.contentView.widthAnchor),

            historyPreviewScroll.topAnchor.constraint(equalTo: historyFilesScroll.bottomAnchor, constant: 4),
            historyPreviewScroll.leadingAnchor.constraint(equalTo: historyDetailContainer.leadingAnchor),
            historyPreviewScroll.trailingAnchor.constraint(equalTo: historyDetailContainer.trailingAnchor),
            historyPreviewScroll.bottomAnchor.constraint(equalTo: historyDetailContainer.bottomAnchor),

            historyEmptyLabel.centerXAnchor.constraint(equalTo: historyDetailContainer.centerXAnchor),
            historyEmptyLabel.centerYAnchor.constraint(equalTo: historyDetailContainer.centerYAnchor),
            historyEmptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: historyDetailContainer.leadingAnchor, constant: 16),
            historyEmptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: historyDetailContainer.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Tab switching

    @objc private func tabChanged() {
        guard noRepoView.isHidden else { return }
        let selected = tabSelector.selectedSegment
        changesContainer.isHidden = selected != 0
        commitField.isHidden = selected != 0
        commitButton.isHidden = selected != 0
        stageAllButton.isHidden = selected != 0
        historyContainer.isHidden = selected != 1
        worktreesContainer.isHidden = selected != 2
    }

    // MARK: - Actions

    @objc private func showSyncMenu() {
        let menu = NSMenu()
        guard let path = currentPath else { return }
        
        Task {
            let remotes = await getRemotes(in: path)
            
            let fetch = NSMenuItem(title: "Fetch", action: #selector(doFetch), keyEquivalent: "")
            fetch.target = self
            fetch.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Fetch")
            menu.addItem(fetch)
            
            if !remotes.isEmpty {
                let fetchFrom = NSMenuItem(title: "Fetch From", action: nil, keyEquivalent: "")
                fetchFrom.image = NSImage(systemSymbolName: "arrow.down.left.circle", accessibilityDescription: "Fetch From")
                let fetchFromSubmenu = NSMenu()
                for remote in remotes {
                    let item = NSMenuItem(title: remote, action: #selector(doFetchFrom(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = remote
                    fetchFromSubmenu.addItem(item)
                }
                fetchFrom.submenu = fetchFromSubmenu
                menu.addItem(fetchFrom)
            }
            
            let pull = NSMenuItem(title: "Pull", action: #selector(doPull), keyEquivalent: "")
            pull.target = self
            pull.image = NSImage(systemSymbolName: "arrow.down", accessibilityDescription: "Pull")
            menu.addItem(pull)
            
            let pullRebase = NSMenuItem(title: "Pull (Rebase)", action: #selector(doPullRebase), keyEquivalent: "")
            pullRebase.target = self
            pullRebase.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Pull (Rebase)")
            menu.addItem(pullRebase)
            
            menu.addItem(NSMenuItem.separator())
            
            let push = NSMenuItem(title: "Push", action: #selector(doPush), keyEquivalent: "")
            push.target = self
            push.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "Push")
            menu.addItem(push)
            
            if !remotes.isEmpty {
                let pushTo = NSMenuItem(title: "Push To", action: nil, keyEquivalent: "")
                pushTo.image = NSImage(systemSymbolName: "arrow.up.right.circle", accessibilityDescription: "Push To")
                let pushToSubmenu = NSMenu()
                for remote in remotes {
                    let item = NSMenuItem(title: remote, action: #selector(doPushTo(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = remote
                    pushToSubmenu.addItem(item)
                }
                pushTo.submenu = pushToSubmenu
                menu.addItem(pushTo)
            }
            
            let forcePush = NSMenuItem(title: "Force Push", action: #selector(doForcePush), keyEquivalent: "")
            forcePush.target = self
            forcePush.image = NSImage(systemSymbolName: "arrow.up.to.line", accessibilityDescription: "Force Push")
            menu.addItem(forcePush)
            
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: syncButton.bounds.height), in: syncButton)
        }
    }

    private func getRemotes(in path: String) async -> [String] {
        let output = await runGit(["remote"], in: path)
        return output.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    @objc private func doFetch() { runAndRefresh(["fetch"]) }
    @objc private func doFetchFrom(_ sender: NSMenuItem) {
        guard let remote = sender.representedObject as? String else { return }
        runAndRefresh(["fetch", remote])
    }
    @objc private func doPull() { runAndRefresh(["pull"]) }
    @objc private func doPullRebase() { runAndRefresh(["pull", "--rebase"]) }
    @objc private func doPush() { runAndRefresh(["push"]) }
    @objc private func doPushTo(_ sender: NSMenuItem) {
        guard let remote = sender.representedObject as? String else { return }
        runAndRefresh(["push", remote])
    }
    @objc private func doForcePush() { runAndRefresh(["push", "--force-with-lease"]) }

    @objc private func stageAllAction() { runAndRefresh(["add", "-A"]) }

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

    @objc private func showCommitMenu() {
        let menu = NSMenu()
        
        let commit = NSMenuItem(title: "Commit Tracked", action: #selector(commitAction), keyEquivalent: "")
        commit.target = self
        commit.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Commit Tracked")
        
        let amend = NSMenuItem(title: "Amend", action: #selector(commitAmendAction), keyEquivalent: "")
        amend.target = self
        amend.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Amend")
        
        let signoff = NSMenuItem(title: "Signoff", action: #selector(commitSignoffAction), keyEquivalent: "")
        signoff.target = self
        signoff.image = NSImage(systemSymbolName: "signature", accessibilityDescription: "Signoff")
        
        menu.addItem(commit)
        menu.addItem(amend)
        menu.addItem(signoff)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: commitButton.bounds.height), in: commitButton)
    }

    @objc private func commitAction() {
        let msg = commitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        runAndRefresh(["commit", "-m", msg], clearField: true)
    }

    @objc private func commitAmendAction() {
        let msg = commitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if msg.isEmpty {
            runAndRefresh(["commit", "--amend", "--no-edit"], clearField: true)
        } else {
            runAndRefresh(["commit", "--amend", "-m", msg], clearField: true)
        }
    }

    @objc private func commitSignoffAction() {
        let msg = commitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        runAndRefresh(["commit", "-s", "-m", msg], clearField: true)
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

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let worktreePath = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = branchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !worktreePath.isEmpty, !branch.isEmpty else { return }

        Task {
            _ = await runGitWithToast(
                ["worktree", "add", worktreePath, branch],
                in: path,
                start: "Adding worktree \(branch)...",
                success: "Added worktree \(branch)"
            )
            await refresh()
        }
    }

    @objc private func removeWorktreeAction(_ sender: NSButton) {
        guard let path = currentPath, let worktreePath = sender.toolTip else { return }
        Task {
            let name = (worktreePath as NSString).lastPathComponent
            _ = await runGitWithToast(
                ["worktree", "remove", worktreePath],
                in: path,
                start: "Removing worktree \(name)...",
                success: "Removed worktree \(name)"
            )
            await refresh()
        }
    }

    @objc private func historyCommitClicked(_ sender: GitHistoryCommitCardView) {
        selectedCommitHash = sender.commitHash
        Task { [weak self] in
            await self?.loadCommitDetails(hash: sender.commitHash)
        }
    }

    @objc private func historyFileClicked(_ sender: GitHistoryFileButton) {
        Task { [weak self] in
            guard let self, let rootPath = self.currentPath else { return }
            await self.loadCommitFileDiff(commitHash: sender.commitHash, path: sender.filePath)
            // Also open in file editor panel (Zed-like)
            let fullPath = self.absolutePath(for: sender.filePath, rootPath: rootPath)
            if FileManager.default.fileExists(atPath: fullPath) {
                guard let split = self.window?.contentViewController as? MainSplitViewController else { return }
                split.contentVC.openFileTab(path: fullPath)
            }
        }
    }

    @objc private func toggleStage(_ sender: NSButton) {
        guard let path = currentPath, let file = sender.toolTip else { return }
        // After click, .on means user wants to stage, .off means unstage
        let wantsStaged = sender.state == .on
        NSLog("[GitPanel] toggleStage: file=%@ wantsStaged=%d path=%@", file, wantsStaged ? 1 : 0, path)
        pulseStageCheckbox(sender)
        Task {
            let fileName = (file as NSString).lastPathComponent
            let result = await runGitWithToast(
                wantsStaged ? ["add", file] : ["restore", "--staged", file],
                in: path,
                start: wantsStaged ? "Staging \(fileName)..." : "Unstaging \(fileName)...",
                success: wantsStaged ? "Staged \(fileName)" : "Unstaged \(fileName)"
            )
            NSLog("[GitPanel] git result: %@", result)
            await refresh()
        }
    }

    private func pulseStageCheckbox(_ checkbox: NSButton) {
        checkbox.wantsLayer = true
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.12
        animation.duration = HarnessDesign.Motion.microFast
        animation.autoreverses = true
        animation.timingFunction = HarnessDesign.Motion.standardEase
        checkbox.layer?.add(animation, forKey: "stage-pulse")
    }

    private func runAndRefresh(_ args: [String], clearField: Bool = false) {
        guard let path = currentPath else { return }
        Task {
            let toast = await gitToastMessages(for: args, in: path)
            if let toast {
                DisplayMessage.show(toast.start)
            }
            let (_, stderr, code) = await runGitResult(args, in: path)
            if code != 0, !stderr.isEmpty {
                let alert = NSAlert()
                alert.messageText = "git \(args.first ?? "") failed"
                alert.informativeText = stderr
                alert.alertStyle = .warning
                alert.runModal()
            }
            if code == 0 {
                if args.first == "commit" {
                    didCommitSinceLastSync = true
                } else if args.first == "push" {
                    didCommitSinceLastSync = false
                }
                if let toast {
                    DisplayMessage.show(toast.success)
                }
            }
            if clearField { commitField.stringValue = "" }
            await refresh()
        }
    }

    // MARK: - Refresh

    private func setRepoVisible(_ visible: Bool) {
        noRepoView.isHidden = visible
        tabSelector.isHidden = !visible
        stageAllButton.isHidden = !visible
        changesContainer.isHidden = !visible || tabSelector.selectedSegment != 0
        commitField.isHidden = !visible || tabSelector.selectedSegment != 0
        commitButton.isHidden = !visible || tabSelector.selectedSegment != 0
        historyContainer.isHidden = !visible || tabSelector.selectedSegment != 1
        worktreesContainer.isHidden = !visible || tabSelector.selectedSegment != 2
        bottomBar.isHidden = !visible
    }

    private func refresh() async {
        guard let path = currentPath else {
            setRepoVisible(false)
            return
        }
        let repoCheck = await runGit(["rev-parse", "--git-dir"], in: path)
        guard !repoCheck.isEmpty else {
            setRepoVisible(false)
            return
        }
        setRepoVisible(true)

        let branch = await runGit(["branch", "--show-current"], in: path)
        let porcelain = await runGit(["status", "--porcelain"], in: path)
        let log = await runGit(["log", "--format=%H%x1f%an%x1f%ar%x1f%s", "-25"], in: path)

        branchLabel.stringValue = "⎇ " + (branch.isEmpty ? "detached" : branch)

        let remotes = await runGit(["remote"], in: path)
        let hasRemotes = !remotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var isAhead = false
        if hasRemotes {
            let aheadStr = await runGit(["rev-list", "--count", "HEAD", "--not", "--remotes"], in: path)
            if let aheadCount = Int(aheadStr.trimmingCharacters(in: .whitespacesAndNewlines)), aheadCount > 0 {
                isAhead = true
            }
        }
        if isAhead || didCommitSinceLastSync {
            HarnessDesign.configurePillButton(syncButton, title: "Push ▼", symbolName: "arrow.up")
        } else {
            HarnessDesign.configurePillButton(syncButton, title: "Fetch ▼", symbolName: "arrow.triangle.2.circlepath")
        }

        let changeCount = porcelain.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        tabSelector.setLabel("Changes (\(changeCount))", forSegment: 0)

        // Changes
        changesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if porcelain.isEmpty {
            let label = makeLabel("Working tree clean")
            changesStack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: changesStack.widthAnchor).isActive = true
        } else {
            for line in porcelain.components(separatedBy: "\n").prefix(40) where !line.isEmpty {
                let row = makeChangeRow(line, rootPath: path)
                changesStack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: changesStack.widthAnchor).isActive = true
            }
        }

        // History
        historyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let commits = log.components(separatedBy: "\n").filter { !$0.isEmpty }
        tabSelector.setLabel("History", forSegment: 1)
        if commits.isEmpty {
            let label = makeLabel("No commits")
            historyStack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: historyStack.widthAnchor).isActive = true
            clearHistoryDetails(message: "No commits to inspect")
        } else {
            for line in commits.prefix(25) {
                let card = makeHistoryCard(line)
                historyStack.addArrangedSubview(card)
                card.widthAnchor.constraint(equalTo: historyStack.widthAnchor).isActive = true
            }
            if let selectedCommitHash {
                await loadCommitDetails(hash: selectedCommitHash)
            } else {
                clearHistoryDetails(message: "Select a commit to inspect changed files")
            }
        }

        await refreshWorktrees()
    }

    // MARK: - Row builders

    private struct WorktreeEntry {
        let path: String
        let head: String
        let branch: String
        let isMain: Bool
    }

    private struct CommitChangedFile {
        let status: String
        let path: String
    }

    private func makeChangeRow(_ line: String, rootPath: String) -> NSView {
        let xy = line.prefix(2)
        let indexStatus = String(xy.first ?? Character(" "))
        let file = displayPath(fromPorcelainPath: String(line.dropFirst(3)))
        let isStaged = indexStatus != " " && indexStatus != "?"
        let workTree = String(xy.last ?? Character(" "))

        let color: NSColor
        switch isStaged ? indexStatus : workTree {
        case "M": color = .systemOrange
        case "A": color = .systemGreen
        case "D": color = .systemRed
        case "?": color = .systemGreen
        default: color = HarnessDesign.chrome.textSecondary
        }

        let check = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleStage(_:)))
        check.state = isStaged ? .on : .off
        check.toolTip = file; check.controlSize = .small
        check.setContentHuggingPriority(.required, for: .horizontal)

        let name = NSTextField(labelWithString: (file as NSString).lastPathComponent)
        name.font = .systemFont(ofSize: 12)
        name.textColor = color
        name.lineBreakMode = .byTruncatingMiddle
        name.toolTip = file
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = GitChangeRowView(filePath: absolutePath(for: file, rootPath: rootPath), views: [check, name])
        row.orientation = .horizontal; row.spacing = 4
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        row.edgeInsets = NSEdgeInsets(top: 2, left: 10, bottom: 2, right: 10)
        return row
    }

    private func displayPath(fromPorcelainPath path: String) -> String {
        if let range = path.range(of: " -> ", options: .backwards) {
            return String(path[range.upperBound...])
        }
        return path
    }

    private func absolutePath(for path: String, rootPath: String) -> String {
        guard !path.hasPrefix("/") else { return path }
        return (rootPath as NSString).appendingPathComponent(path)
    }

    private func makeHistoryCard(_ line: String) -> NSView {
        let parts = line.components(separatedBy: "\u{1f}")
        guard parts.count >= 4 else { return makeLabel(line) }
        let fullHash = parts[0]
        let hash = String(fullHash.prefix(7))
        let author = parts[1]
        let time = parts[2]
        let subject = parts[3]

        let card = GitHistoryCommitCardView(commitHash: fullHash)
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.target = self
        card.action = #selector(historyCommitClicked(_:))

        // Subject line
        let subjectLabel = NSTextField(labelWithString: subject)
        subjectLabel.font = .systemFont(ofSize: 12)
        subjectLabel.textColor = HarnessDesign.chrome.textPrimary
        subjectLabel.lineBreakMode = .byTruncatingTail
        subjectLabel.translatesAutoresizingMaskIntoConstraints = false

        // Author · time · hash
        let meta = NSTextField(labelWithString: "\(author) · \(time) · \(hash)")
        meta.font = .systemFont(ofSize: 10)
        meta.textColor = HarnessDesign.chrome.textTertiary
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

    private func makeCommitFileRow(_ file: CommitChangedFile, commitHash: String) -> NSView {
        let button = GitHistoryFileButton(commitHash: commitHash, filePath: file.path)
        button.target = self
        button.action = #selector(historyFileClicked(_:))
        button.bezelStyle = NSButton.BezelStyle.inline
        button.isBordered = false
        button.alignment = NSTextAlignment.left
        button.translatesAutoresizingMaskIntoConstraints = false

        let statusLabel = NSTextField(labelWithString: file.status)
        statusLabel.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        statusLabel.textColor = historyStatusColor(file.status)
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: file.path)
        name.font = .systemFont(ofSize: 11)
        name.textColor = HarnessDesign.chrome.textPrimary
        name.lineBreakMode = .byTruncatingMiddle
        name.toolTip = file.path
        name.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(statusLabel)
        button.addSubview(name)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 10),
            statusLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 20),
            name.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 6),
            name.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -10),
            name.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        return button
    }

    private func historyStatusColor(_ status: String) -> NSColor {
        switch status.first {
        case "M": return .systemOrange
        case "A": return .systemGreen
        case "D": return .systemRed
        case "R": return .systemBlue
        default: return HarnessDesign.chrome.textSecondary
        }
    }

    private func makeWorktreeRow(_ worktree: WorktreeEntry) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: (worktree.path as NSString).lastPathComponent)
        name.font = .systemFont(ofSize: 12, weight: .bold)
        name.textColor = HarnessDesign.chrome.textPrimary
        name.lineBreakMode = .byTruncatingTail
        name.toolTip = worktree.path
        name.translatesAutoresizingMaskIntoConstraints = false

        let meta = NSTextField(labelWithString: "\(worktree.branch) · \(String(worktree.head.prefix(7)))")
        meta.font = .systemFont(ofSize: 10)
        meta.textColor = HarnessDesign.chrome.textTertiary
        meta.lineBreakMode = .byTruncatingTail
        meta.translatesAutoresizingMaskIntoConstraints = false

        let removeButton = NSButton(title: "", target: self, action: #selector(removeWorktreeAction(_:)))
        removeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Remove worktree")?
            .withSymbolConfiguration(HarnessDesign.symbolConfig(pointSize: HarnessDesign.IconSize.small, weight: .semibold))
        removeButton.imagePosition = .imageOnly
        removeButton.bezelStyle = .recessed; removeButton.controlSize = .small
        removeButton.toolTip = worktree.path
        removeButton.isHidden = worktree.isMain
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(name)
        card.addSubview(meta)
        card.addSubview(removeButton)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 40),
            name.topAnchor.constraint(equalTo: card.topAnchor, constant: 5),
            name.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            name.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -8),
            meta.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 1),
            meta.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            meta.trailingAnchor.constraint(equalTo: removeButton.leadingAnchor, constant: -8),
            removeButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            removeButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 24),
        ])
        return card
    }

    private func makeFieldRow(_ label: String, field: NSTextField) -> NSView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 12)
        labelView.textColor = HarnessDesign.chrome.textSecondary
        labelView.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [labelView, field])
        row.orientation = .horizontal; row.alignment = .centerY; row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            labelView.widthAnchor.constraint(equalToConstant: 52),
        ])
        return row
    }

    private func makeLabel(_ text: String) -> NSView {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 11.5); l.textColor = HarnessDesign.chrome.textTertiary
        let container = NSStackView(views: [l])
        container.orientation = .horizontal
        container.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }

    private func refreshWorktrees() async {
        guard let path = currentPath else { return }
        let output = await runGit(["worktree", "list", "--porcelain"], in: path)

        worktreesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

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
            return WorktreeEntry(path: worktreePath, head: head, branch: branch, isMain: index == 0)
        }

        if entries.isEmpty {
            let label = makeLabel("No worktrees")
            worktreesStack.addArrangedSubview(label)
            label.widthAnchor.constraint(equalTo: worktreesStack.widthAnchor).isActive = true
        } else {
            entries.forEach { entry in
                let row = makeWorktreeRow(entry)
                worktreesStack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: worktreesStack.widthAnchor).isActive = true
            }
        }
    }

    private func loadCommitDetails(hash: String) async {
        guard let path = currentPath else {
            clearHistoryDetails(message: "Open a terminal session in a git repository")
            return
        }

        historyFilesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let output = await runGit(["diff-tree", "--root", "--no-commit-id", "--name-status", "-r", "-M", hash], in: path)
        let files = parseCommitChangedFiles(output)

        guard !files.isEmpty else {
            clearHistoryDetails(message: "No changed files for \(String(hash.prefix(7)))")
            return
        }

        historyEmptyLabel.isHidden = true
        historyFilesScroll.isHidden = false
        historyPreviewScroll.isHidden = false

        for file in files {
            let row = makeCommitFileRow(file, commitHash: hash)
            historyFilesStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: historyFilesStack.widthAnchor).isActive = true
        }

        if let first = files.first {
            await loadCommitFileDiff(commitHash: hash, path: first.path)
        }
    }

    private func loadCommitFileDiff(commitHash: String, path filePath: String) async {
        guard let path = currentPath else { return }
        let diff = await runGit(["show", "--format=", "--find-renames", commitHash, "--", filePath], in: path)
        if diff.isEmpty {
            let contents = await runGit(["show", "\(commitHash):\(filePath)"], in: path)
            historyPreviewTextView.string = contents.isEmpty ? "No preview available for \(filePath)." : contents
        } else {
            historyPreviewTextView.string = diff
        }
        historyPreviewTextView.scrollToBeginningOfDocument(nil)
    }

    private func parseCommitChangedFiles(_ output: String) -> [CommitChangedFile] {
        output.components(separatedBy: "\n").compactMap { line in
            let fields = line.components(separatedBy: "\t")
            guard fields.count >= 2 else { return nil }
            let status = fields[0]
            let path = fields.count >= 3 && status.hasPrefix("R") ? fields[2] : fields[1]
            return CommitChangedFile(status: status, path: path)
        }
    }

    private func clearHistoryDetails(message: String) {
        historyFilesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        historyPreviewTextView.string = ""
        historyFilesScroll.isHidden = true
        historyPreviewScroll.isHidden = true
        historyEmptyLabel.stringValue = message
        historyEmptyLabel.isHidden = false
    }

    // MARK: - Git

    private func runGitResult(_ args: [String], in directory: String) async -> (String, String, Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = URL(fileURLWithPath: directory)
                let outPipe = Pipe(); let errPipe = Pipe()
                process.standardOutput = outPipe; process.standardError = errPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: (out, err, process.terminationStatus))
                } catch {
                    continuation.resume(returning: ("", error.localizedDescription, -1))
                }
            }
        }
    }

    private func runGit(_ args: [String], in directory: String) async -> String {
        let (out, _, _) = await runGitResult(args, in: directory)
        return out
    }

    private func runGitWithToast(_ args: [String], in directory: String, start: String, success: String) async -> String {
        DisplayMessage.show(start)
        let (out, stderr, code) = await runGitResult(args, in: directory)
        if code == 0 {
            DisplayMessage.show(success)
        } else if !stderr.isEmpty {
            let alert = NSAlert()
            alert.messageText = "git \(args.first ?? "") failed"
            alert.informativeText = stderr
            alert.alertStyle = .warning
            alert.runModal()
        }
        return out
    }

    private func gitToastMessages(for args: [String], in directory: String) async -> (start: String, success: String)? {
        guard let command = args.first, command != "commit" else { return nil }

        switch command {
        case "fetch":
            let remote = args.dropFirst().first
            if let remote, !remote.isEmpty {
                return ("Fetching from \(remote)...", "Fetched from \(remote)")
            }
            return ("Fetching...", "Fetch succeeded")
        case "pull":
            if args.contains("--rebase") {
                return ("Pulling with rebase...", "Pull rebase succeeded")
            }
            return ("Pulling...", "Pull succeeded")
        case "push":
            let target = await pushTargetDescription(for: args, in: directory)
            let force = args.contains("--force-with-lease")
            return (
                force ? "Force pushing to \(target)..." : "Pushing to \(target)...",
                force ? "Force push to \(target) succeeded" : "Push to \(target) succeeded"
            )
        case "add":
            return ("Staging changes...", "Staged changes")
        case "checkout":
            let branch = args.dropFirst().first ?? "branch"
            return ("Switching to \(branch)...", "Switched to \(branch)")
        default:
            return nil
        }
    }

    private func pushTargetDescription(for args: [String], in directory: String) async -> String {
        let remote = args.dropFirst().first { !$0.hasPrefix("-") }
        let branch = await runGit(["branch", "--show-current"], in: directory)
        let targetBranch = branch.isEmpty ? "detached HEAD" : branch
        guard let remote, !remote.isEmpty else { return targetBranch }
        return "\(remote)/\(targetBranch)"
    }
}

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

@MainActor
private final class GitHistoryCommitCardView: NSControl {
    let commitHash: String

    init(commitHash: String) {
        self.commitHash = commitHash
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

@MainActor
private final class GitHistoryFileButton: NSButton {
    let commitHash: String
    let filePath: String

    init(commitHash: String, filePath: String) {
        self.commitHash = commitHash
        self.filePath = filePath
        super.init(frame: .zero)
        title = ""
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

@MainActor
private final class GitChangeRowView: NSStackView {
    private let filePath: String
    private var mouseDownLocation: NSPoint?

    init(filePath: String, views: [NSView]) {
        self.filePath = filePath
        super.init(frame: .zero)
        views.forEach { addArrangedSubview($0) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        if event.clickCount == 2 {
            // Double-click: open file in editor panel
            if let split = window?.contentViewController as? MainSplitViewController {
                split.contentVC.openFileTab(path: filePath)
            }
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if let start = mouseDownLocation,
           hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) < 4 {
            return
        }
        let item = NSPasteboardItem()
        item.setString(URL(fileURLWithPath: filePath).absoluteString, forType: .fileURL)
        let draggingItem = NSDraggingItem(pasteboardWriter: item)
        let image = NSImage(systemSymbolName: "doc", accessibilityDescription: "Changed file") ?? NSImage(size: NSSize(width: 16, height: 16))
        let rect = NSRect(origin: convert(event.locationInWindow, from: nil), size: NSSize(width: 18, height: 18))
        draggingItem.setDraggingFrame(rect, contents: image)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
}

extension GitChangeRowView: NSDraggingSource {
    nonisolated func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    nonisolated var ignoreModifierKeysForDraggingSession: Bool { true }
}
