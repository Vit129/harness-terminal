// ponytail: intentionally AppKit — syntax highlight uses custom NSTextStorage + layout manager; SwiftUI TextEditor has no equivalent hook.
import AppKit
import KouenCore
import QuickLookUI
import KouenLSP

/// Read-only preview of a file's contents, hosted in the sidebar in place of
/// the file tree.
@MainActor
final class FileViewerViewController: NSViewController {
    /// Files larger than this are not loaded into the text view.
    private static let maxPreviewBytes = 1_000_000

    private let header = NSView()
    private let backButton = KouenDesign.softIconButton(symbol: "chevron.left", tooltip: "Back to file tree")
    private let pathLabel = NSTextField(labelWithString: "")
    private let syntaxView = SyntaxTextView()
    private let quickLookView = QLPreviewView(frame: .zero, style: .normal)
    private let messageLabel = NSTextField(labelWithString: "")
    private let fileWatcher = FileChangeWatcher()
    // LSP integration (hover, go-to-definition, diagnostics) enabled.
    private let lspSession = LSPFileSession()

    /// Invoked when the user taps the back button.
    var onBack: (() -> Void)?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHeader()
        setupPreviewViews()
        setupMessageLabel()
    }

    /// Reads `path` from disk and displays it. Shows a placeholder message for
    /// binary/oversized files or read failures.
    func load(path: String) {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if (cleanPath.hasPrefix("'") && cleanPath.hasSuffix("'")) ||
           (cleanPath.hasPrefix("\"") && cleanPath.hasSuffix("\"")) {
            cleanPath = String(cleanPath.dropFirst().dropLast())
        }
        let isReloadingSamePath = pathLabel.toolTip == cleanPath
        pathLabel.stringValue = (cleanPath as NSString).lastPathComponent
        pathLabel.toolTip = cleanPath

        let expanded = (cleanPath as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).resolvingSymlinksInPath()
        let ext = url.pathExtension.lowercased()

        fileWatcher.start(path: expanded) { [weak self] in
            guard let self, self.pathLabel.toolTip == cleanPath else { return }
            self.load(path: cleanPath)
        }

        if Self.quickLookExtensions.contains(ext) {
            showQuickLook(url)
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
            showMessage("Unable to preview this file (binary or unsupported encoding).")
            return
        }
        showText(contents, url: url, fileExtension: ext, resetScroll: !isReloadingSamePath)
    }

    // MARK: - Setup

    private func setupHeader() {
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.target = self
        backButton.action = #selector(backTapped)
        header.addSubview(backButton)

        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.font = KouenDesign.Typography.sidebarLabel
        pathLabel.textColor = KouenDesign.chrome.textPrimary
        pathLabel.lineBreakMode = .byTruncatingMiddle
        header.addSubview(pathLabel)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 36),

            backButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: KouenDesign.Spacing.sm),
            backButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            pathLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: KouenDesign.Spacing.xs),
            pathLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -KouenDesign.Spacing.sm),
            pathLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
    }

    private func setupPreviewViews() {
        syntaxView.translatesAutoresizingMaskIntoConstraints = false
        syntaxView.onSave = { [weak self] text in
            guard let path = self?.pathLabel.toolTip, !path.isEmpty else { return }
            let expanded = (path as NSString).expandingTildeInPath
            try? text.write(toFile: expanded, atomically: true, encoding: .utf8)
            DisplayMessage.show("Saved \((path as NSString).lastPathComponent)")
        }
        // LSP hooks
        syntaxView.onHover = { [weak self] position in await self?.lspSession.hover(position: position) }
        syntaxView.onDefinition = { [weak self] position in await self?.lspSession.definition(position: position) }
        syntaxView.onNavigateToDefinition = { [weak self] target in
            self?.load(path: target.url.path)
        }
        view.addSubview(syntaxView)

        if let quickLookView {
            quickLookView.translatesAutoresizingMaskIntoConstraints = false
            quickLookView.autostarts = true
            quickLookView.isHidden = true
            view.addSubview(quickLookView)
        }

        // LSP diagnostics
        lspSession.onDiagnostics = { [weak self] diagnostics in
            self?.syntaxView.setDiagnostics(diagnostics)
        }

        var constraints = [
            syntaxView.topAnchor.constraint(equalTo: header.bottomAnchor),
            syntaxView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            syntaxView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            syntaxView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        if let quickLookView {
            constraints.append(contentsOf: [
                quickLookView.topAnchor.constraint(equalTo: header.bottomAnchor),
                quickLookView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                quickLookView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                quickLookView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func setupMessageLabel() {
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = KouenDesign.Typography.sidebarLabel
        messageLabel.textColor = KouenDesign.chrome.textTertiary
        messageLabel.alignment = .center
        messageLabel.isHidden = true
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: KouenDesign.Spacing.lg),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -KouenDesign.Spacing.lg),
        ])
    }

    // MARK: - Display state

    private func showText(_ text: String, url: URL, fileExtension ext: String, resetScroll: Bool) {
        messageLabel.isHidden = true
        quickLookView?.isHidden = true
        syntaxView.isHidden = false
        syntaxView.load(text: text, fileExtension: ext, resetScroll: resetScroll)
        if ["diff", "patch"].contains(ext) {
            let diffLines = GitDiffGutter.contentLines(text)
            syntaxView.setDiffLines(diffLines)
            if resetScroll, let firstChangedLine = diffLines.keys.min() {
                syntaxView.navigateTo(line: firstChangedLine, column: 1)
            }
        } else {
            let path = url.path
            Task.detached(priority: .utility) {
                let diffLines = await GitDiffGutter.diffLines(for: path)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.syntaxView.setDiffLines(diffLines)
                    if resetScroll, let firstChangedLine = diffLines.keys.min() {
                        self.syntaxView.navigateTo(line: firstChangedLine, column: 1)
                    }
                }
            }
        }
        lspSession.open(url: url, text: text, fileExtension: ext)
        view.window?.makeFirstResponder(syntaxView)
    }

    private func showQuickLook(_ url: URL) {
        lspSession.close()
        guard let quickLookView else {
            showMessage("Unable to start Quick Look preview.")
            return
        }
        messageLabel.isHidden = true
        syntaxView.isHidden = true
        if quickLookView.previewItem?.previewItemURL == url {
            quickLookView.refreshPreviewItem()
        } else {
            quickLookView.previewItem = url as NSURL
        }
        quickLookView.isHidden = false
    }

    private func showMessage(_ message: String) {
        lspSession.close()
        syntaxView.isHidden = true
        quickLookView?.isHidden = true
        messageLabel.isHidden = false
        messageLabel.stringValue = message
    }

    @objc private func backTapped() {
        onBack?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onBack?()
            return
        }
        super.keyDown(with: event)
    }

    override var acceptsFirstResponder: Bool { true }

    private static let quickLookExtensions: Set<String> = loadQuickLookExtensions()

    private static func loadQuickLookExtensions() -> Set<String> {
        let file = KouenPaths.applicationSupport.appendingPathComponent("quicklook-extensions.json")
        if let data = try? Data(contentsOf: file),
           let list = try? JSONDecoder().decode([String].self, from: data),
           !list.isEmpty { return Set(list) }
        return [
            "png", "jpg", "jpeg", "gif", "webp", "svg", "ico", "bmp", "tiff", "heic",
            "pdf", "rtf", "rtfd", "doc", "docx", "pages", "key", "keynote", "numbers",
            "csv", "xls", "xlsx",
        ]
    }
}
