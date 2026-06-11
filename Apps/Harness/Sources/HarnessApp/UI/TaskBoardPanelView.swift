import AppKit
import HarnessCore

/// A beautiful Task Board panel showing Makefile targets and package.json scripts,
/// allowing the user to run them with a single click in the active terminal pane.
@MainActor
final class TaskBoardPanelView: NSView {

    struct TaskItem: Sendable {
        let name: String
        let command: String
        let source: String // "Makefile" or "package.json"
    }

    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "No tasks found in active workspace.\nCreate a Makefile or package.json.")
    
    private var rootPath: String = ""
    private var tasks: [TaskItem] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateRoot(path: String) {
        guard path != rootPath else { return }
        rootPath = path
        reloadTasks()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // Allow stackView to size vertically based on its content, but stretch horizontally.
        stackView.setHuggingPriority(.defaultHigh, for: .vertical)
        stackView.setHuggingPriority(.defaultLow, for: .horizontal)

        // Set stackView as the documentView of the scroll view.
        let clipView = NSClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView
        scrollView.documentView = stackView

        // Constraint stackView width to clipView width.
        stackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor).isActive = true

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = NSFont.systemFont(ofSize: 12)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    private func reloadTasks() {
        let path = rootPath
        guard !path.isEmpty else {
            self.tasks = []
            self.rebuildUI()
            return
        }

        Task.detached(priority: .userInitiated) {
            let items = Self.parseTasks(at: path)
            await MainActor.run {
                self.tasks = items
                self.rebuildUI()
            }
        }
    }

    private func rebuildUI() {
        // Clear previous views.
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        emptyLabel.isHidden = !tasks.isEmpty
        scrollView.isHidden = tasks.isEmpty

        // Group tasks by source.
        let makefileTasks = tasks.filter { $0.source == "Makefile" }
        let packageTasks = tasks.filter { $0.source == "package.json" }

        if !makefileTasks.isEmpty {
            addSectionHeader(title: "Makefile Targets")
            for task in makefileTasks {
                addTaskRow(task: task)
            }
        }

        if !packageTasks.isEmpty {
            addSectionHeader(title: "package.json Scripts")
            for task in packageTasks {
                addTaskRow(task: task)
            }
        }
    }

    private func addSectionHeader(title: String) {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = HarnessDesign.chrome.textTertiary
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        stackView.addArrangedSubview(container)
        container.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
        container.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
    }

    private func addTaskRow(task: TaskItem) {
        let row = TaskRowButton(task: task) { [weak self] in
            self?.executeTask(task)
        }
        stackView.addArrangedSubview(row)
        row.leadingAnchor.constraint(equalTo: stackView.leadingAnchor).isActive = true
        row.trailingAnchor.constraint(equalTo: stackView.trailingAnchor).isActive = true
    }

    private func executeTask(_ task: TaskItem) {
        guard let activeSurfaceID = SessionCoordinator.shared.activeSurfaceID else {
            return
        }
        let cmd = task.source == "Makefile" ? "make \(task.name)" : "npm run \(task.name)"
        Task {
            _ = await SessionCoordinator.shared.requestDaemon(.send(surfaceID: activeSurfaceID.uuidString, text: cmd + "\r"))
        }
    }

    nonisolated private static func parseTasks(at path: String) -> [TaskItem] {
        var items: [TaskItem] = []
        let fm = FileManager.default
        
        // 1. Parse Makefile
        let makefilePath = (path as NSString).appendingPathComponent("Makefile")
        if fm.fileExists(atPath: makefilePath),
           let content = try? String(contentsOfFile: makefilePath, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.contains(":") else { continue }
                // Skip lines that start with comment or are indentation recipes
                guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix("\t") else { continue }
                
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                let target = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !target.isEmpty else { continue }
                guard !target.hasPrefix(".") else { continue }
                guard !target.contains("$") && !target.contains("%") && !target.contains("/") && !target.contains("=") else { continue }
                guard target != "PHONY" else { continue }
                
                if !items.contains(where: { $0.name == target && $0.source == "Makefile" }) {
                    items.append(TaskItem(name: target, command: "make \(target)", source: "Makefile"))
                }
            }
        }
        
        // 2. Parse package.json
        let pkgPath = (path as NSString).appendingPathComponent("package.json")
        if fm.fileExists(atPath: pkgPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: pkgPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let scripts = json["scripts"] as? [String: String] {
            for (key, val) in scripts.sorted(by: { $0.key < $1.key }) {
                items.append(TaskItem(name: key, command: val, source: "package.json"))
            }
        }
        
        return items
    }
}

// MARK: - TaskRowButton

@MainActor
fileprivate final class TaskRowButton: NSView {
    
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let playButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
    private let onClick: () -> Void
    
    private var trackingArea: NSTrackingArea?

    init(task: TaskBoardPanelView.TaskItem, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
        
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = HarnessDesign.Radius.control
        layer?.backgroundColor = HarnessDesign.chrome.surfaceElevated.cgColor
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = HarnessDesign.chrome.textPrimary
        titleLabel.stringValue = task.name
        addSubview(titleLabel)
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 10)
        subtitleLabel.textColor = HarnessDesign.chrome.textSecondary
        subtitleLabel.stringValue = task.command
        subtitleLabel.lineBreakMode = .byTruncatingTail
        addSubview(subtitleLabel)
        
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setSymbol("play.fill", accessibilityDescription: "Run script", pointSize: 10, weight: .bold)
        playButton.target = self
        playButton.action = #selector(buttonClicked)
        playButton.applyChrome()
        addSubview(playButton)
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -8),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            subtitleLabel.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            playButton.widthAnchor.constraint(equalToConstant: 24),
            playButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func buttonClicked() {
        onClick()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        layer?.backgroundColor = HarnessDesign.chrome.rowHoverFill.cgColor
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        layer?.backgroundColor = HarnessDesign.chrome.surfaceElevated.cgColor
    }
}
