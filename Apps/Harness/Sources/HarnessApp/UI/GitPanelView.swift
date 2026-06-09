import AppKit
import HarnessCore
import CoreServices

@MainActor
final class GitPanelView: NSView {
    private var currentPath: String?
    private nonisolated(unsafe) var watchStream: FSEventStreamRef?
    private nonisolated(unsafe) var contextPointer: UnsafeMutableRawPointer?
    private nonisolated(unsafe) var watchDebounce: DispatchWorkItem?

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

    func updateRoot(path: String) {
        guard path != currentPath else { return }
        currentPath = path
        startWatching()
        Task { [weak self] in await self?.refresh() }
    }

    func clearRoot() {
        currentPath = nil
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
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagUseCFTypes)
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
        branchLabel.textColor = HarnessDesign.chrome.textSecondary
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
        menu.addItem(fetch)
        menu.addItem(pull)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(push)
        menu.addItem(forcePush)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: syncButton.bounds.height), in: syncButton)
    }

    @objc private func doFetch() { runAndRefresh(["fetch"]) }
    @objc private func doPull() { runAndRefresh(["pull"]) }
    @objc private func doPush() { runAndRefresh(["push"]) }
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

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let worktreePath = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = branchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !worktreePath.isEmpty, !branch.isEmpty else { return }

        Task {
            _ = await runGit(["worktree", "add", worktreePath, branch], in: path)
            await refresh()
        }
    }

    @objc private func removeWorktreeAction(_ sender: NSButton) {
        guard let path = currentPath, let worktreePath = sender.toolTip else { return }
        Task {
            _ = await runGit(["worktree", "remove", worktreePath], in: path)
            await refresh()
        }
    }

    @objc private func showCommitDetail(_ sender: NSClickGestureRecognizer) {
        guard let path = currentPath,
              let card = sender.view,
              let hash = card.identifier?.rawValue else { return }
        Task {
            let detail = await runGit(["show", "--stat", "--patch", hash], in: path)
            let shortHash = String(hash.prefix(7))
            let tmpDir = NSTemporaryDirectory() + "harness-diff/"
            try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
            let tmpPath = tmpDir + "\(shortHash).diff"
            try? detail.write(toFile: tmpPath, atomically: true, encoding: .utf8)
            guard let split = self.window?.contentViewController as? MainSplitViewController else { return }
            split.contentVC.openFileTab(path: tmpPath)
        }
    }

    private func presentCommitDetail(_ text: String, anchor: NSView) {
        let mono = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let monoBold = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        let baseAttrs: [NSAttributedString.Key: Any] = [.font: mono, .foregroundColor: NSColor.labelColor]

        // Build attributed string with diff coloring
        let attributed = NSMutableAttributedString()
        let lines = text.components(separatedBy: "\n")
        // Track diff file header ranges for navigation
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

        // Diff text view
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.textStorage?.setAttributedString(attributed)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

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
                textView.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            ])
        } else {
            contentView.addSubview(scroll)
            NSLayoutConstraint.activate([
                scroll.topAnchor.constraint(equalTo: contentView.topAnchor),
                scroll.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                scroll.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                textView.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
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

    @objc private func toggleStage(_ sender: NSButton) {
        guard let path = currentPath, let file = sender.toolTip else { return }
        // After click, .on means user wants to stage, .off means unstage
        let wantsStaged = sender.state == .on
        NSLog("[GitPanel] toggleStage: file=%@ wantsStaged=%d path=%@", file, wantsStaged ? 1 : 0, path)
        Task {
            let result = await runGit(wantsStaged ? ["add", file] : ["restore", "--staged", file], in: path)
            NSLog("[GitPanel] git result: %@", result)
            await refresh()
        }
    }

    private func runAndRefresh(_ args: [String], clearField: Bool = false) {
        guard let path = currentPath else { return }
        Task {
            _ = await runGit(args, in: path)
            if clearField { commitField.stringValue = "" }
            await refresh()
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        guard let path = currentPath else { return }
        let branch = await runGit(["branch", "--show-current"], in: path)
        let numstat = await runGit(["diff", "--numstat", "HEAD"], in: path)
        let porcelain = await runGit(["status", "--porcelain"], in: path)
        let log = await runGit(["log", "--format=%H|%an|%ar|%s", "-25"], in: path)

        branchLabel.stringValue = "⎇ " + (branch.isEmpty ? "detached" : branch)

        let changeCount = porcelain.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        tabSelector.setLabel("Changes (\(changeCount))", forSegment: 0)

        // Map file path -> (additions, deletions) from `git diff --numstat HEAD`
        var stats: [String: (Int, Int)] = [:]
        for line in numstat.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 3, let added = Int(parts[0]), let deleted = Int(parts[1]) else { continue }
            stats[parts[2]] = (added, deleted)
        }

        // Changes
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

        // History
        historyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for line in log.components(separatedBy: "\n").prefix(25) where !line.isEmpty {
            let card = makeHistoryCard(line)
            historyStack.addArrangedSubview(card)
            card.leadingAnchor.constraint(equalTo: historyStack.leadingAnchor).isActive = true
            card.trailingAnchor.constraint(equalTo: historyStack.trailingAnchor).isActive = true
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
        default: color = HarnessDesign.chrome.textSecondary; letter = "M"
        }

        let badge = makeStatusBadge(letter: letter, color: color)

        let check = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleStage(_:)))
        check.state = isStaged ? .on : .off
        check.toolTip = file; check.controlSize = .small

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

        check.setContentHuggingPriority(.required, for: .horizontal)
        rowViews.append(check)

        let row = NSStackView(views: rowViews)
        row.orientation = .horizontal; row.spacing = 6; row.alignment = .centerY
        row.distribution = .fill
        row.edgeInsets = NSEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        return row
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
        card.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(showCommitDetail(_:))))

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

        let removeButton = NSButton(title: "✕", target: self, action: #selector(removeWorktreeAction(_:)))
        removeButton.bezelStyle = .recessed; removeButton.controlSize = .small
        removeButton.font = .systemFont(ofSize: 11, weight: .medium)
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

    private func makeLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 11.5); l.textColor = HarnessDesign.chrome.textTertiary
        return l
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
            worktreesStack.addArrangedSubview(makeLabel("No worktrees"))
        } else {
            for entry in entries {
                let row = makeWorktreeRow(entry)
                worktreesStack.addArrangedSubview(row)
                row.leadingAnchor.constraint(equalTo: worktreesStack.leadingAnchor).isActive = true
                row.trailingAnchor.constraint(equalTo: worktreesStack.trailingAnchor).isActive = true
            }
        }
    }

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
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
