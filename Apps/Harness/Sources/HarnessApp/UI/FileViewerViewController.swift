import AppKit
import HarnessCore
import QuickLookUI

/// Read-only preview of a file's contents, hosted in the sidebar in place of
/// the file tree.
@MainActor
final class FileViewerViewController: NSViewController {
    /// Files larger than this are not loaded into the text view.
    private static let maxPreviewBytes = 1_000_000

    private let header = NSView()
    private let backButton = HarnessDesign.softIconButton(symbol: "chevron.left", tooltip: "Back to file tree")
    private let pathLabel = NSTextField(labelWithString: "")
    private let syntaxView = SyntaxTextView()
    private let quickLookView = QLPreviewView(frame: .zero, style: .normal)
    private let messageLabel = NSTextField(labelWithString: "")
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
        pathLabel.stringValue = (path as NSString).lastPathComponent
        pathLabel.toolTip = path

        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        let ext = url.pathExtension.lowercased()

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
        showText(contents, url: url, fileExtension: ext)
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
        pathLabel.font = HarnessDesign.Typography.sidebarLabel
        pathLabel.textColor = HarnessDesign.chrome.textPrimary
        pathLabel.lineBreakMode = .byTruncatingMiddle
        header.addSubview(pathLabel)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 36),

            backButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: HarnessDesign.Spacing.sm),
            backButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),

            pathLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: HarnessDesign.Spacing.xs),
            pathLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -HarnessDesign.Spacing.sm),
            pathLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
    }

    private func setupPreviewViews() {
        syntaxView.translatesAutoresizingMaskIntoConstraints = false
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
        messageLabel.font = HarnessDesign.Typography.sidebarLabel
        messageLabel.textColor = HarnessDesign.chrome.textTertiary
        messageLabel.alignment = .center
        messageLabel.isHidden = true
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: HarnessDesign.Spacing.lg),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -HarnessDesign.Spacing.lg),
        ])
    }

    // MARK: - Display state

    private func showText(_ text: String, url: URL, fileExtension ext: String) {
        messageLabel.isHidden = true
        quickLookView?.isHidden = true
        syntaxView.isHidden = false
        syntaxView.load(text: text, fileExtension: ext)
        lspSession.open(url: url, text: text, fileExtension: ext)
    }

    private func showQuickLook(_ url: URL) {
        lspSession.close()
        guard let quickLookView else {
            showMessage("Unable to start Quick Look preview.")
            return
        }
        messageLabel.isHidden = true
        syntaxView.isHidden = true
        quickLookView.isHidden = false
        quickLookView.previewItem = url as NSURL
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

    private static let quickLookExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "svg", "ico", "bmp", "tiff", "heic",
        "pdf", "rtf", "rtfd", "doc", "docx", "pages", "key", "keynote", "numbers",
    ]
}
