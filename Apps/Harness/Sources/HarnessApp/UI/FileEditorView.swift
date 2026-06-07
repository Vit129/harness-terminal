import AppKit
import HarnessCore
import QuickLookUI

/// File ID for GUI-only file tabs (not daemon-managed).
typealias FileTabID = UUID

/// A read-only file editor panel shown in the content area when a file tab is active.
/// Features: line numbers gutter, syntax highlighting, Quick Look for non-text.
@MainActor
final class FileEditorView: NSView {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let gutterView = LineNumberGutterView()
    private let messageLabel = NSTextField(labelWithString: "")
    private let quickLookContainer = NSView()

    private static let maxPreviewBytes = 5_000_000
    private(set) var filePath: String = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func load(path: String) {
        filePath = path
        quickLookContainer.isHidden = true
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)

        // Quick Look for images/PDFs
        let ext = (path as NSString).pathExtension.lowercased()
        let imageExts = Set(["png", "jpg", "jpeg", "gif", "webp", "svg", "ico", "bmp", "tiff", "heic"])
        let qlExts = imageExts.union(["pdf"])
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
        showText(contents, fileExtension: ext)
    }

    // MARK: - Setup

    private func setup() {
        wantsLayer = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        addSubview(scrollView)

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = HarnessDesign.chrome.textPrimary
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        scrollView.documentView = textView

        gutterView.translatesAutoresizingMaskIntoConstraints = false
        gutterView.textView = textView
        addSubview(gutterView)

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
            gutterView.topAnchor.constraint(equalTo: topAnchor),
            gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),
            gutterView.widthAnchor.constraint(equalToConstant: 44),

            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            quickLookContainer.topAnchor.constraint(equalTo: topAnchor),
            quickLookContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            quickLookContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            quickLookContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Sync gutter on scroll
        NotificationCenter.default.addObserver(self, selector: #selector(textDidScroll), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        scrollView.contentView.postsBoundsChangedNotifications = true
        // Track edits
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: NSText.didChangeNotification, object: textView)
    }

    @objc private func textDidScroll() {
        gutterView.needsDisplay = true
    }

    @objc private func textDidChange() {
        isModified = true
        gutterView.needsDisplay = true
    }

    // MARK: - Editing

    private var isModified = false

    /// Save current content back to disk.
    func save() {
        guard !filePath.isEmpty, isModified else { return }
        let expanded = (filePath as NSString).expandingTildeInPath
        let content = textView.string
        do {
            try content.write(toFile: expanded, atomically: true, encoding: .utf8)
            isModified = false
        } catch {
            NSSound.beep()
        }
    }

    /// Show macOS standard find bar.
    func showFindBar() {
        textView.performFindPanelAction(NSTextFinder.Action.showFindInterface)
    }

    /// Show find & replace bar.
    func showFindAndReplace() {
        textView.performFindPanelAction(NSTextFinder.Action.showReplaceInterface)
    }

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.keyDown(with: event)
            return
        }
        switch event.charactersIgnoringModifiers {
        case "s":
            save()
        case "f":
            if event.modifierFlags.contains(.shift) {
                showFindAndReplace()
            } else {
                showFindBar()
            }
        case "z":
            if event.modifierFlags.contains(.shift) {
                textView.undoManager?.redo()
            } else {
                textView.undoManager?.undo()
            }
        default:
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Display

    private func showText(_ text: String, fileExtension ext: String) {
        messageLabel.isHidden = true
        scrollView.isHidden = false
        gutterView.isHidden = false
        quickLookContainer.isHidden = true

        let attributed = SyntaxHighlighter.highlight(text, fileExtension: ext)
        textView.textStorage?.setAttributedString(attributed)
        textView.scrollToBeginningOfDocument(nil)
        gutterView.needsDisplay = true
    }

    private func showMessage(_ message: String) {
        scrollView.isHidden = true
        gutterView.isHidden = true
        quickLookContainer.isHidden = true
        messageLabel.isHidden = false
        messageLabel.stringValue = message
    }

    private func showQuickLook(url: URL) {
        scrollView.isHidden = true
        gutterView.isHidden = true
        messageLabel.isHidden = true
        quickLookContainer.isHidden = false
        quickLookContainer.subviews.forEach { $0.removeFromSuperview() }

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = NSImage(contentsOf: url)
        quickLookContainer.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: quickLookContainer.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: quickLookContainer.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: quickLookContainer.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: quickLookContainer.bottomAnchor, constant: -16),
        ])
    }
}

// MARK: - Line Number Gutter

@MainActor
final class LineNumberGutterView: NSView {
    weak var textView: NSTextView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let textView, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let c = HarnessDesign.chrome
        c.sidebarBackground.withAlphaComponent(0.5).setFill()
        dirtyRect.fill()

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let text = textView.string as NSString
        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: c.textTertiary,
        ]

        var lineNumber = 1
        // Count lines before visible range
        text.enumerateSubstrings(in: NSRange(location: 0, length: charRange.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineNumber += 1
        }

        let inset = textView.textContainerInset.height
        text.enumerateSubstrings(in: charRange, options: [.byLines, .substringNotRequired]) { [weak self] _, range, _, _ in
            guard let self else { return }
            let glyphIdx = layoutManager.glyphIndexForCharacter(at: range.location)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            lineRect.origin.y += inset - visibleRect.origin.y

            let numStr = "\(lineNumber)" as NSString
            let strSize = numStr.size(withAttributes: attrs)
            let x = self.bounds.width - strSize.width - 8
            let y = lineRect.origin.y + (lineRect.height - strSize.height) / 2
            numStr.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            lineNumber += 1
        }
    }
}

// MARK: - Syntax Highlighter

@MainActor
enum SyntaxHighlighter {
    static func highlight(_ text: String, fileExtension ext: String) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let c = HarnessDesign.chrome
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: c.textPrimary,
        ]

        let attributed = NSMutableAttributedString(string: text, attributes: baseAttrs)
        let fullRange = NSRange(location: 0, length: attributed.length)

        // Language-specific keyword highlighting
        let keywords = Self.keywords(for: ext)
        let commentPattern = Self.commentPattern(for: ext)
        let stringPattern = #""[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*'"#

        // Comments (green)
        if let commentPattern, let regex = try? NSRegularExpression(pattern: commentPattern, options: .anchorsMatchLines) {
            for match in regex.matches(in: text, range: fullRange) {
                attributed.addAttribute(.foregroundColor, value: NSColor.systemGreen.withAlphaComponent(0.8), range: match.range)
            }
        }

        // Strings (orange)
        if let regex = try? NSRegularExpression(pattern: stringPattern) {
            for match in regex.matches(in: text, range: fullRange) {
                attributed.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: match.range)
            }
        }

        // Keywords (blue/purple)
        if !keywords.isEmpty {
            let pattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                for match in regex.matches(in: text, range: fullRange) {
                    attributed.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                }
            }
        }

        // Numbers (cyan)
        if let regex = try? NSRegularExpression(pattern: #"\b\d+\.?\d*\b"#) {
            for match in regex.matches(in: text, range: fullRange) {
                attributed.addAttribute(.foregroundColor, value: NSColor.systemCyan, range: match.range)
            }
        }

        return attributed
    }

    private static func keywords(for ext: String) -> [String] {
        switch ext {
        case "swift":
            return ["import", "func", "var", "let", "class", "struct", "enum", "protocol", "extension",
                    "if", "else", "guard", "return", "switch", "case", "for", "while", "in", "where",
                    "self", "Self", "nil", "true", "false", "private", "public", "internal", "final",
                    "static", "override", "init", "deinit", "throw", "throws", "try", "catch", "await",
                    "async", "actor", "some", "any", "weak", "unowned", "mutating", "typealias"]
        case "ts", "tsx", "js", "jsx":
            return ["import", "export", "from", "function", "const", "let", "var", "class", "interface",
                    "type", "if", "else", "return", "switch", "case", "for", "while", "of", "in",
                    "this", "null", "undefined", "true", "false", "new", "async", "await", "try",
                    "catch", "throw", "extends", "implements", "default", "break", "continue"]
        case "py":
            return ["import", "from", "def", "class", "if", "elif", "else", "return", "for", "while",
                    "in", "is", "not", "and", "or", "True", "False", "None", "self", "with", "as",
                    "try", "except", "finally", "raise", "yield", "async", "await", "pass", "lambda"]
        case "rs":
            return ["fn", "let", "mut", "const", "struct", "enum", "impl", "trait", "pub", "use",
                    "mod", "if", "else", "match", "for", "while", "loop", "return", "self", "Self",
                    "true", "false", "async", "await", "move", "where", "type", "unsafe"]
        case "go":
            return ["package", "import", "func", "var", "const", "type", "struct", "interface",
                    "if", "else", "for", "range", "switch", "case", "return", "go", "defer",
                    "chan", "map", "nil", "true", "false", "select", "break", "continue"]
        case "json":
            return ["true", "false", "null"]
        case "yaml", "yml":
            return ["true", "false", "null", "yes", "no"]
        default:
            return []
        }
    }

    private static func commentPattern(for ext: String) -> String? {
        switch ext {
        case "swift", "ts", "tsx", "js", "jsx", "rs", "go", "c", "cpp", "h", "java", "kt":
            return #"//.*$|/\*[\s\S]*?\*/"#
        case "py", "rb", "sh", "bash", "zsh", "yaml", "yml", "toml":
            return "#.*$"
        case "md":
            return nil // No comment highlighting for markdown
        default:
            return #"//.*$|#.*$"#
        }
    }
}
