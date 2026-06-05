import AppKit
import HarnessCore

@MainActor
final class GitPanelView: NSView {
    private var currentPath: String?

    // Top tabs: Changes | History
    private let tabSelector = NSSegmentedControl(labels: ["Changes", "History"], trackingMode: .selectOne, target: nil, action: nil)
    private let changesContainer = NSView()
    private let historyContainer = NSView()

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

    // Bottom bar: branch + fetch
    private let bottomBar = NSView()
    private let branchLabel = NSTextField(labelWithString: "")
    private let fetchButton = NSButton(title: "Fetch", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func updateRoot(path: String) {
        guard path != currentPath else { return }
        currentPath = path
        Task { [weak self] in await self?.refresh() }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        // Tab selector
        tabSelector.selectedSegment = 0
        tabSelector.target = self
        tabSelector.action = #selector(tabChanged)
        tabSelector.segmentStyle = .automatic
        tabSelector.translatesAutoresizingMaskIntoConstraints = false

        // Changes container
        changesContainer.translatesAutoresizingMaskIntoConstraints = false
        changesStack.orientation = .vertical; changesStack.alignment = .width; changesStack.spacing = 0
        setupScrollView(changesScroll, with: changesStack, in: changesContainer)

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

        // Bottom bar
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        branchLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        branchLabel.textColor = HarnessDesign.chrome.textSecondary
        branchLabel.lineBreakMode = .byTruncatingTail
        branchLabel.translatesAutoresizingMaskIntoConstraints = false

        let branchClick = NSClickGestureRecognizer(target: self, action: #selector(showBranchMenu))
        branchLabel.addGestureRecognizer(branchClick)
        branchLabel.isSelectable = false

        fetchButton.bezelStyle = .recessed; fetchButton.controlSize = .small
        fetchButton.font = .systemFont(ofSize: 11, weight: .medium)
        fetchButton.target = self; fetchButton.action = #selector(fetchAction)
        fetchButton.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.addSubview(branchLabel)
        bottomBar.addSubview(fetchButton)

        addSubview(tabSelector)
        addSubview(stageAllButton)
        addSubview(changesContainer)
        addSubview(commitField)
        addSubview(commitButton)
        addSubview(historyContainer)
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

            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            bottomBar.heightAnchor.constraint(equalToConstant: 22),

            branchLabel.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            branchLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            branchLabel.trailingAnchor.constraint(lessThanOrEqualTo: fetchButton.leadingAnchor, constant: -8),
            fetchButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            fetchButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
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
        let isHistory = tabSelector.selectedSegment == 1
        changesContainer.isHidden = isHistory
        commitField.isHidden = isHistory
        commitButton.isHidden = isHistory
        stageAllButton.isHidden = isHistory
        historyContainer.isHidden = !isHistory
    }

    // MARK: - Actions

    @objc private func fetchAction() { runAndRefresh(["fetch"]) }
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

    @objc private func toggleStage(_ sender: NSButton) {
        guard let path = currentPath, let file = sender.toolTip else { return }
        let isStaged = sender.state == .on
        Task {
            _ = await runGit(isStaged ? ["restore", "--staged", file] : ["add", file], in: path)
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
        let status = await runGit(["diff", "--stat", "--cached", "--numstat"], in: path)
        let porcelain = await runGit(["status", "--porcelain"], in: path)
        let log = await runGit(["log", "--format=%H|%an|%ar|%s", "-25"], in: path)

        branchLabel.stringValue = "⎇ " + (branch.isEmpty ? "detached" : branch)

        let changeCount = porcelain.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        tabSelector.setLabel("Changes (\(changeCount))", forSegment: 0)

        // Changes
        changesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if porcelain.isEmpty {
            changesStack.addArrangedSubview(makeLabel("Working tree clean"))
        } else {
            for line in porcelain.components(separatedBy: "\n").prefix(40) where !line.isEmpty {
                changesStack.addArrangedSubview(makeChangeRow(line))
            }
        }

        // History
        historyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for line in log.components(separatedBy: "\n").prefix(25) where !line.isEmpty {
            historyStack.addArrangedSubview(makeHistoryCard(line))
        }
    }

    // MARK: - Row builders

    private func makeChangeRow(_ line: String) -> NSView {
        let xy = line.prefix(2)
        let indexStatus = String(xy.first ?? Character(" "))
        let file = String(line.dropFirst(3))
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

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true

        let check = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleStage(_:)))
        check.state = isStaged ? .on : .off
        check.toolTip = file; check.controlSize = .small
        check.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: (file as NSString).lastPathComponent)
        name.font = .systemFont(ofSize: 12)
        name.textColor = color
        name.lineBreakMode = .byTruncatingMiddle
        name.toolTip = file
        name.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(check)
        row.addSubview(name)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 24),
            check.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            check.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            name.leadingAnchor.constraint(equalTo: check.trailingAnchor, constant: 4),
            name.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            name.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        return row
    }

    private func makeHistoryCard(_ line: String) -> NSView {
        let parts = line.split(separator: "|", maxSplits: 3).map(String.init)
        guard parts.count >= 4 else { return makeLabel(line) }
        let hash = String(parts[0].prefix(7))
        let author = parts[1]
        let time = parts[2]
        let subject = parts[3]

        let card = NSView()
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false

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

    private func makeLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 11.5); l.textColor = HarnessDesign.chrome.textTertiary
        return l
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
