import AppKit
import HarnessCore

/// Read-only preview of a file's contents, hosted in the sidebar in place of
/// the file tree. Plain-text MVP: no syntax highlighting (P4 Track 1 follow-up).
@MainActor
final class FileViewerViewController: NSViewController {
    /// Files larger than this are not loaded into the text view.
    private static let maxPreviewBytes = 1_000_000

    private let header = NSView()
    private let backButton = HarnessDesign.softIconButton(symbol: "chevron.left", tooltip: "Back to file tree")
    private let pathLabel = NSTextField(labelWithString: "")
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let messageLabel = NSTextField(labelWithString: "")

    /// Invoked when the user taps the back button.
    var onBack: (() -> Void)?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHeader()
        setupTextView()
        setupMessageLabel()
    }

    /// Reads `path` from disk and displays it. Shows a placeholder message for
    /// binary/oversized files or read failures.
    func load(path: String) {
        pathLabel.stringValue = (path as NSString).lastPathComponent
        pathLabel.toolTip = path

        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)

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
        showText(contents)
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

    private func setupTextView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        view.addSubview(scrollView)

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: HarnessDesign.Spacing.sm, height: HarnessDesign.Spacing.sm)
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = HarnessDesign.chrome.textPrimary
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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

    private func showText(_ text: String) {
        messageLabel.isHidden = true
        scrollView.isHidden = false
        textView.string = text
        textView.scrollToBeginningOfDocument(nil)
    }

    private func showMessage(_ message: String) {
        scrollView.isHidden = true
        messageLabel.isHidden = false
        messageLabel.stringValue = message
    }

    @objc private func backTapped() {
        onBack?()
    }
}
