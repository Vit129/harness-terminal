import AppKit
import HarnessCore
import QuickLookUI

/// File ID for GUI-only file tabs (not daemon-managed).
typealias FileTabID = UUID

/// A read-only file editor panel shown in the content area when a file tab is active.
/// Features: line numbers gutter, syntax highlighting, Quick Look for non-text.
@MainActor
final class FileEditorView: NSView {
    private let syntaxView = SyntaxTextView()
    private let messageLabel = NSTextField(labelWithString: "")
    private let quickLookContainer = NSView()
    private let lspSession = LSPFileSession()

    private static let maxPreviewBytes = 5_000_000
    private(set) var filePath: String = ""
    private let fileWatcher = FileChangeWatcher()
    private let symbolIndex = WorkspaceSymbolIndex()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func load(path: String) {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if (cleanPath.hasPrefix("'") && cleanPath.hasSuffix("'")) ||
           (cleanPath.hasPrefix("\"") && cleanPath.hasSuffix("\"")) {
            cleanPath = String(cleanPath.dropFirst().dropLast())
        }
        let isReloadingSamePath = filePath == cleanPath
        filePath = cleanPath
        quickLookContainer.isHidden = true
        let expanded = (cleanPath as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).resolvingSymlinksInPath()

        fileWatcher.start(path: expanded) { [weak self] in
            guard let self, self.filePath == cleanPath else { return }
            self.load(path: cleanPath)
        }

        // Quick Look for images/PDFs
        let ext = (cleanPath as NSString).pathExtension.lowercased()
        let imageExts = Set(["png", "jpg", "jpeg", "gif", "webp", "svg", "ico", "bmp", "tiff", "heic"])
        let qlExts = imageExts.union(["pdf", "rtf", "rtfd", "doc", "docx", "pages", "key", "keynote", "numbers", "xlsx", "xls", "csv"])
        if qlExts.contains(ext) {
            showQuickLook(url: url)
            return
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: expanded),
              let size = attributes[.size] as? Int else {
            showMessage("Unable to read file.")
            return
        }
        guard size <= Self.maxPreviewBytes else {
            showMessage("File too large to preview (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))).")
            return
        }
        guard let data = try? Data(contentsOf: url), let contents = String(data: data, encoding: .utf8) else {
            showMessage("Binary file — cannot preview.")
            return
        }
        showText(contents, fileExtension: ext, resetScroll: !isReloadingSamePath)
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = .clear

        syntaxView.translatesAutoresizingMaskIntoConstraints = false
        syntaxView.onSave = { [weak self] text in
            guard let self, !self.filePath.isEmpty else { return }
            try? text.write(toFile: self.filePath, atomically: true, encoding: .utf8)
            DisplayMessage.show("Saved \((self.filePath as NSString).lastPathComponent)")
        }
        // LSP hooks
        syntaxView.onHover = { [weak self] position in await self?.lspSession.hover(position: position) }
        syntaxView.onDefinition = { [weak self] position in await self?.lspSession.definition(position: position) }
        syntaxView.onNavigateToDefinition = { [weak self] target in
            self?.load(path: target.url.path)
            self?.syntaxView.navigateTo(line: target.line, column: target.column)
        }
        addSubview(syntaxView)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = HarnessDesign.Typography.sidebarLabel
        messageLabel.textColor = HarnessDesign.chrome.textTertiary
        messageLabel.alignment = .center
        messageLabel.isHidden = true
        addSubview(messageLabel)

        quickLookContainer.translatesAutoresizingMaskIntoConstraints = false
        quickLookContainer.isHidden = true
        addSubview(quickLookContainer)

        NSLayoutConstraint.activate([
            syntaxView.topAnchor.constraint(equalTo: topAnchor),
            syntaxView.leadingAnchor.constraint(equalTo: leadingAnchor),
            syntaxView.trailingAnchor.constraint(equalTo: trailingAnchor),
            syntaxView.bottomAnchor.constraint(equalTo: bottomAnchor),

            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            quickLookContainer.topAnchor.constraint(equalTo: topAnchor),
            quickLookContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            quickLookContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            quickLookContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        lspSession.onDiagnostics = { [weak self] diagnostics in
            self?.syntaxView.setDiagnostics(diagnostics)
        }
    }

    // MARK: - Git Diff Gutter

    /// For .diff/.patch files: parse `+`/`-` line prefixes directly from the content.
    private func loadDiffContentGutter(_ text: String) {
        var result: [Int: SyntaxTextView.DiffLineType] = [:]
        for (i, line) in text.components(separatedBy: "\n").enumerated() {
            let lineNum = i + 1
            if line.hasPrefix("+") && !line.hasPrefix("+++") {
                result[lineNum] = .added
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                result[lineNum] = .deleted
            } else if line.hasPrefix("@@") {
                result[lineNum] = .modified
            }
        }
        syntaxView.setDiffLines(result)
    }

    private func loadGitDiff() {
        let path = filePath
        Task.detached(priority: .utility) {
            let diffLines = await Self.parseGitDiff(for: path)
            await MainActor.run { [weak self] in
                self?.syntaxView.setDiffLines(diffLines)
            }
        }
    }

    private static func parseGitDiff(for path: String) async -> [Int: SyntaxTextView.DiffLineType] {
        let dir = (path as NSString).deletingLastPathComponent
        let file = (path as NSString).lastPathComponent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "--unified=0", "--", file]
        process.currentDirectoryURL = URL(fileURLWithPath: dir)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return [:] }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var result: [Int: SyntaxTextView.DiffLineType] = [:]
        // Parse @@ -a,b +c,d @@ hunks
        for line in output.components(separatedBy: "\n") {
            guard line.hasPrefix("@@") else { continue }
            // Extract +start,count
            guard let plusRange = line.range(of: "+") else { continue }
            let afterPlus = line[plusRange.upperBound...]
            guard let spaceOrComma = afterPlus.firstIndex(where: { $0 == "," || $0 == " " }) else { continue }
            let startStr = String(afterPlus[..<spaceOrComma])
            guard let start = Int(startStr) else { continue }
            var count = 1
            if afterPlus[spaceOrComma] == "," {
                let afterComma = afterPlus[afterPlus.index(after: spaceOrComma)...]
                if let end = afterComma.firstIndex(of: " ") {
                    count = Int(afterComma[..<end]) ?? 1
                }
            }
            // Check if it's add or modify by looking at the - side
            let hasRemoved = line.contains("-") && !line.hasPrefix("---")
            let type: SyntaxTextView.DiffLineType = count == 0 ? .deleted : (hasRemoved ? .modified : .added)
            if count == 0 {
                result[start] = .deleted
            } else {
                for i in start..<(start + count) {
                    result[i] = type
                }
            }
        }
        return result
    }

    // MARK: - Editing

    func showFindBar() {
        syntaxView.showFindBar()
    }

    func showFindAndReplace() {
        syntaxView.showFindBar()
    }

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        let key = event.charactersIgnoringModifiers ?? ""

        if cmd {
            switch key {
            case "s": NSSound.beep()
            case "f":
                showFindBar()
            default: super.keyDown(with: event)
            }
            return
        }
        super.keyDown(with: event)
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Display

    private func showText(_ text: String, fileExtension ext: String, resetScroll: Bool) {
        messageLabel.isHidden = true
        syntaxView.isHidden = false
        quickLookContainer.isHidden = true

        syntaxView.load(text: text, fileExtension: ext, resetScroll: resetScroll)
        if ["diff", "patch"].contains(ext) {
            loadDiffContentGutter(text)
        } else {
            loadGitDiff()
        }
        
        let fileDir = (filePath as NSString).deletingLastPathComponent
        let root = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd ?? fileDir
        symbolIndex.scan(root: root)
        syntaxView.symbolIndex = symbolIndex
        lspSession.open(url: URL(fileURLWithPath: filePath), text: text, fileExtension: ext)
    }

    private func showMessage(_ message: String) {
        lspSession.close()
        syntaxView.isHidden = true
        quickLookContainer.isHidden = true
        messageLabel.isHidden = false
        messageLabel.stringValue = message
    }

    private func showQuickLook(url: URL) {
        lspSession.close()
        syntaxView.isHidden = true
        messageLabel.isHidden = true
        quickLookContainer.isHidden = false
        quickLookContainer.subviews.forEach { $0.removeFromSuperview() }

        guard let preview = QLPreviewView(frame: .zero, style: .normal) else {
            showMessage("Unable to start Quick Look preview.")
            return
        }
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.autostarts = true
        preview.previewItem = url as NSURL
        quickLookContainer.addSubview(preview)
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: quickLookContainer.topAnchor),
            preview.leadingAnchor.constraint(equalTo: quickLookContainer.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: quickLookContainer.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: quickLookContainer.bottomAnchor),
        ])
    }
}
