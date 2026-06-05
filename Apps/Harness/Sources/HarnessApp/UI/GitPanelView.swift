import AppKit
import HarnessCore

@MainActor
final class GitPanelView: NSView {
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let statusHeader = NSTextField(labelWithString: "CHANGES")
    private let logHeader = NSTextField(labelWithString: "COMMITS")
    private let statusStack = NSStackView()
    private let logStack = NSStackView()
    private var currentPath: String?

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

        for header in [statusHeader, logHeader] {
            header.font = .systemFont(ofSize: 10, weight: .semibold)
            header.textColor = HarnessDesign.chrome.textTertiary
            header.translatesAutoresizingMaskIntoConstraints = false
        }

        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 2
        logStack.orientation = .vertical
        logStack.alignment = .leading
        logStack.spacing = 2

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(statusHeader)
        stackView.addArrangedSubview(statusStack)
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

    private func refresh() async {
        guard let path = currentPath else { return }
        let status = await runGit(["status", "--porcelain"], in: path)
        let log = await runGit(["log", "--oneline", "-15"], in: path)

        statusStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        logStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if status.isEmpty {
            statusStack.addArrangedSubview(makeLabel("No changes", color: HarnessDesign.chrome.textTertiary))
        } else {
            for line in status.components(separatedBy: "\n").prefix(30) where !line.isEmpty {
                statusStack.addArrangedSubview(makeStatusRow(line))
            }
        }

        if log.isEmpty {
            logStack.addArrangedSubview(makeLabel("No commits", color: HarnessDesign.chrome.textTertiary))
        } else {
            for line in log.components(separatedBy: "\n").prefix(15) where !line.isEmpty {
                logStack.addArrangedSubview(makeCommitRow(line))
            }
        }
    }

    private func makeStatusRow(_ line: String) -> NSView {
        let status = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
        let file = String(line.dropFirst(3))
        let color: NSColor
        switch status {
        case "M": color = .systemOrange
        case "A", "?": color = .systemGreen
        case "D": color = .systemRed
        case "R": color = .systemBlue
        default: color = HarnessDesign.chrome.textSecondary
        }

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6

        let badge = NSTextField(labelWithString: status.isEmpty ? "?" : status)
        badge.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        badge.textColor = color
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let name = NSTextField(labelWithString: file)
        name.font = .systemFont(ofSize: 12)
        name.textColor = HarnessDesign.chrome.textSecondary
        name.lineBreakMode = .byTruncatingMiddle

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
        hashLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        hashLabel.textColor = HarnessDesign.chrome.textTertiary
        hashLabel.setContentHuggingPriority(.required, for: .horizontal)

        let msgLabel = NSTextField(labelWithString: msg)
        msgLabel.font = .systemFont(ofSize: 12)
        msgLabel.textColor = HarnessDesign.chrome.textSecondary
        msgLabel.lineBreakMode = .byTruncatingTail

        row.addArrangedSubview(hashLabel)
        row.addArrangedSubview(msgLabel)
        return row
    }

    private func makeLabel(_ text: String, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = color
        return label
    }

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
