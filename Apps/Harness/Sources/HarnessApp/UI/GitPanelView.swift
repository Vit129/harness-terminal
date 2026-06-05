import AppKit
import HarnessCore

@MainActor
final class GitPanelView: NSView {
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private var currentPath: String?

    // Push/Pull header
    private let actionBar = NSStackView()
    private let branchLabel = NSTextField(labelWithString: "")
    private let pullButton = NSButton(title: "Pull", target: nil, action: nil)
    private let pushButton = NSButton(title: "Push", target: nil, action: nil)

    // Commit section
    private let commitField = NSTextField()
    private let commitButton = NSButton(title: "Commit", target: nil, action: nil)
    private let commitPushButton = NSButton(title: "Commit+Push", target: nil, action: nil)
    private let commitAmendButton = NSButton(title: "Amend", target: nil, action: nil)
    private let stageAllButton = NSButton(title: "Stage All", target: nil, action: nil)

    // Changes & log
    private let statusHeader = NSTextField(labelWithString: "CHANGES")
    private let logHeader = NSTextField(labelWithString: "COMMITS")
    private let statusStack = NSStackView()
    private let logStack = NSStackView()

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

        // Branch + push/pull bar
        branchLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        branchLabel.textColor = HarnessDesign.chrome.textPrimary
        branchLabel.lineBreakMode = .byTruncatingTail
        branchLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        for btn in [pullButton, pushButton, stageAllButton, commitButton, commitPushButton, commitAmendButton] {
            btn.bezelStyle = .recessed
            btn.controlSize = .small
            btn.font = .systemFont(ofSize: 11, weight: .medium)
        }
        pullButton.target = self; pullButton.action = #selector(pullAction)
        pushButton.target = self; pushButton.action = #selector(pushAction)
        stageAllButton.target = self; stageAllButton.action = #selector(stageAllAction)
        commitButton.target = self; commitButton.action = #selector(commitAction)
        commitPushButton.target = self; commitPushButton.action = #selector(commitPushAction)
        commitAmendButton.target = self; commitAmendButton.action = #selector(commitAmendAction)

        actionBar.orientation = .horizontal
        actionBar.spacing = 6
        actionBar.addArrangedSubview(branchLabel)
        actionBar.addArrangedSubview(pullButton)
        actionBar.addArrangedSubview(pushButton)

        // Commit message area (larger box)
        commitField.placeholderString = "Commit message…"
        commitField.font = .systemFont(ofSize: 12)
        commitField.isBezeled = true
        commitField.bezelStyle = .roundedBezel
        commitField.focusRingType = .none
        commitField.usesSingleLineMode = false
        commitField.lineBreakMode = .byWordWrapping
        commitField.maximumNumberOfLines = 6
        commitField.translatesAutoresizingMaskIntoConstraints = false
        commitField.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true

        let commitButtonRow = NSStackView()
        commitButtonRow.orientation = .horizontal
        commitButtonRow.spacing = 6
        commitButtonRow.addArrangedSubview(stageAllButton)
        commitButtonRow.addArrangedSubview(commitButton)
        commitButtonRow.addArrangedSubview(commitPushButton)
        commitButtonRow.addArrangedSubview(commitAmendButton)

        let commitBar = NSStackView()
        commitBar.orientation = .vertical
        commitBar.alignment = .width
        commitBar.spacing = 6
        commitBar.addArrangedSubview(commitField)
        commitBar.addArrangedSubview(commitButtonRow)

        // Headers
        for header in [statusHeader, logHeader] {
            header.font = .systemFont(ofSize: 10, weight: .semibold)
            header.textColor = HarnessDesign.chrome.textTertiary
        }

        statusStack.orientation = .vertical
        statusStack.alignment = .width
        statusStack.spacing = 1
        logStack.orientation = .vertical
        logStack.alignment = .width
        logStack.spacing = 1

        stackView.orientation = .vertical
        stackView.alignment = .width
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(actionBar)
        stackView.addArrangedSubview(statusHeader)
        stackView.addArrangedSubview(statusStack)
        stackView.addArrangedSubview(commitBar)
        stackView.addArrangedSubview(logHeader)
        stackView.addArrangedSubview(logStack)

        let doc = NSView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stackView)

        scrollView.documentView = doc
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            doc.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            doc.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            doc.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stackView.topAnchor.constraint(equalTo: doc.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -8),
        ])
    }

    // MARK: - Actions

    @objc private func pullAction() {
        guard let path = currentPath else { return }
        Task {
            _ = await runGit(["pull"], in: path)
            await refresh()
        }
    }

    @objc private func pushAction() {
        guard let path = currentPath else { return }
        Task {
            _ = await runGit(["push"], in: path)
            await refresh()
        }
    }

    @objc private func stageAllAction() {
        guard let path = currentPath else { return }
        Task {
            _ = await runGit(["add", "-A"], in: path)
            await refresh()
        }
    }

    @objc private func commitAction() {
        guard let path = currentPath else { return }
        let message = commitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        Task {
            _ = await runGit(["commit", "-m", message], in: path)
            commitField.stringValue = ""
            await refresh()
        }
    }

    @objc private func commitPushAction() {
        guard let path = currentPath else { return }
        let message = commitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        Task {
            _ = await runGit(["commit", "-m", message], in: path)
            _ = await runGit(["push"], in: path)
            commitField.stringValue = ""
            await refresh()
        }
    }

    @objc private func commitAmendAction() {
        guard let path = currentPath else { return }
        let message = commitField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if message.isEmpty {
                _ = await runGit(["commit", "--amend", "--no-edit"], in: path)
            } else {
                _ = await runGit(["commit", "--amend", "-m", message], in: path)
            }
            commitField.stringValue = ""
            await refresh()
        }
    }

    @objc private func toggleStage(_ sender: NSButton) {
        guard let path = currentPath, let file = sender.toolTip else { return }
        let isStaged = sender.state == .on
        Task {
            if isStaged {
                _ = await runGit(["restore", "--staged", file], in: path)
            } else {
                _ = await runGit(["add", file], in: path)
            }
            await refresh()
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        guard let path = currentPath else { return }
        let branch = await runGit(["branch", "--show-current"], in: path)
        let status = await runGit(["status", "--porcelain"], in: path)
        let log = await runGit(["log", "--oneline", "-10"], in: path)

        branchLabel.stringValue = "⎇ " + (branch.isEmpty ? "detached" : branch)

        statusStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        logStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if status.isEmpty {
            statusStack.addArrangedSubview(makeLabel("Working tree clean"))
        } else {
            for line in status.components(separatedBy: "\n").prefix(30) where !line.isEmpty {
                statusStack.addArrangedSubview(makeStatusRow(line))
            }
        }

        for line in log.components(separatedBy: "\n").prefix(10) where !line.isEmpty {
            logStack.addArrangedSubview(makeCommitRow(line))
        }
    }

    // MARK: - Row builders

    private func makeStatusRow(_ line: String) -> NSView {
        let xy = line.prefix(2)
        let indexStatus = String(xy.first ?? Character(" "))
        let file = String(line.dropFirst(3))
        let isStaged = indexStatus != " " && indexStatus != "?"

        let color: NSColor
        let workTree = String(xy.last ?? Character(" "))
        switch isStaged ? indexStatus : workTree {
        case "M": color = .systemOrange
        case "A": color = .systemGreen
        case "D": color = .systemRed
        case "R": color = .systemBlue
        case "?": color = .systemGreen
        default: color = HarnessDesign.chrome.textSecondary
        }

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 4

        let check = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleStage(_:)))
        check.state = isStaged ? .on : .off
        check.toolTip = file
        check.controlSize = .small

        let badge = NSTextField(labelWithString: String(xy))
        badge.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        badge.textColor = color
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let name = NSTextField(labelWithString: (file as NSString).lastPathComponent)
        name.font = .systemFont(ofSize: 11.5)
        name.textColor = HarnessDesign.chrome.textSecondary
        name.lineBreakMode = .byTruncatingMiddle
        name.toolTip = file

        row.addArrangedSubview(check)
        row.addArrangedSubview(badge)
        row.addArrangedSubview(name)
        return row
    }

    private func makeCommitRow(_ line: String) -> NSView {
        let parts = line.split(separator: " ", maxSplits: 1)
        let hash = parts.first.map(String.init) ?? ""
        let msg = parts.count > 1 ? String(parts[1]) : ""

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6

        let hashLabel = NSTextField(labelWithString: hash)
        hashLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        hashLabel.textColor = HarnessDesign.chrome.textTertiary
        hashLabel.setContentHuggingPriority(.required, for: .horizontal)

        let msgLabel = NSTextField(labelWithString: msg)
        msgLabel.font = .systemFont(ofSize: 11.5)
        msgLabel.textColor = HarnessDesign.chrome.textSecondary
        msgLabel.lineBreakMode = .byTruncatingTail

        row.addArrangedSubview(hashLabel)
        row.addArrangedSubview(msgLabel)
        return row
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = HarnessDesign.chrome.textTertiary
        return label
    }

    // MARK: - Git runner

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
