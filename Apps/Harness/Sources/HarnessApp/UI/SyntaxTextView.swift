import AppKit
import HarnessLSP

struct SyntaxDefinitionTarget {
    let url: URL
    let line: Int
    let column: Int
}

@MainActor
final class SyntaxTextView: NSView {
    enum DiffLineType { case added, modified, deleted }

    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let gutterView = SyntaxLineNumberGutterView()
    private var fileExtension = ""
    private var diagnostics: [LSPDiagnostic] = []
    private var hoverPopover: NSPopover?

    var onHover: ((LSPPosition) async -> String?)?
    var onDefinition: ((LSPPosition) async -> SyntaxDefinitionTarget?)?
    var onNavigateToDefinition: ((SyntaxDefinitionTarget) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var string: String { textView.string }

    func load(text: String, fileExtension ext: String) {
        fileExtension = ext.lowercased()
        textView.textStorage?.setAttributedString(SyntaxHighlighter.highlight(text, fileExtension: fileExtension))
        textView.scrollToBeginningOfDocument(nil)
        diagnostics = []
        gutterView.diagnostics = []
        gutterView.needsDisplay = true
    }

    func setDiagnostics(_ diagnostics: [LSPDiagnostic]) {
        self.diagnostics = diagnostics
        gutterView.diagnostics = diagnostics
        applyDiagnosticAttributes()
        gutterView.needsDisplay = true
    }

    func setDiffLines(_ diffLines: [Int: DiffLineType]) {
        gutterView.diffLines = diffLines
        gutterView.needsDisplay = true
    }

    /// Vi-like mode: read-only by default, press `i` to edit, `Esc` to return.
    private(set) var isEditMode = false
    /// Callback to save the current text content to disk.
    var onSave: ((String) -> Void)?
    /// Callback when edit mode changes (for status display).
    var onEditModeChange: ((Bool) -> Void)?

    func showFindBar() {
        textView.performFindPanelAction(NSTextFinder.Action.showFindInterface)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        let key = event.charactersIgnoringModifiers ?? ""
        if cmd && key == "f" {
            showFindBar()
            return
        }
        if cmd && key == "s" {
            if isEditMode {
                onSave?(textView.string)
                exitEditMode()
            }
            return
        }
        if !isEditMode && key == "i" && !cmd {
            enterEditMode()
            return
        }
        if isEditMode && event.keyCode == 53 { // Esc
            exitEditMode()
            return
        }
        super.keyDown(with: event)
    }

    private func enterEditMode() {
        isEditMode = true
        textView.isEditable = true
        onEditModeChange?(true)
    }

    private func exitEditMode() {
        isEditMode = false
        textView.isEditable = false
        onEditModeChange?(false)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let position = lspPosition(for: event), let onHover else { return }
        Task {
            guard let text = await onHover(position), !text.isEmpty else { return }
            await MainActor.run { [weak self] in
                self?.showHover(text, for: event)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), let position = lspPosition(for: event), let onDefinition {
            Task {
                guard let target = await onDefinition(position) else { return }
                await MainActor.run { [weak self] in
                    self?.onNavigateToDefinition?(target)
                }
            }
            return
        }
        super.mouseDown(with: event)
    }

    private func setup() {
        wantsLayer = true
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self
        ))

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        addSubview(scrollView)

        textView.isEditable = false
        textView.isSelectable = true
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

        NSLayoutConstraint.activate([
            gutterView.topAnchor.constraint(equalTo: topAnchor),
            gutterView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutterView.bottomAnchor.constraint(equalTo: bottomAnchor),
            gutterView.widthAnchor.constraint(equalToConstant: 44),

            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc private func textDidScroll() {
        gutterView.needsDisplay = true
    }

    private func applyDiagnosticAttributes() {
        let highlighted = SyntaxHighlighter.highlight(textView.string, fileExtension: fileExtension)
        let mutable = NSMutableAttributedString(attributedString: highlighted)
        for diagnostic in diagnostics {
            let range = nsRange(for: diagnostic.range)
            guard range.location != NSNotFound, range.length > 0, NSMaxRange(range) <= mutable.length else { continue }
            let color: NSColor = diagnostic.severity == .warning ? .systemYellow : .systemRed
            mutable.addAttributes([
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: color,
                .toolTip: diagnostic.message,
            ], range: range)
        }
        textView.textStorage?.setAttributedString(mutable)
    }

    private func nsRange(for range: LSPRange) -> NSRange {
        let ns = textView.string as NSString
        let start = offset(line: range.start.line, character: range.start.character, in: ns)
        let end = offset(line: range.end.line, character: range.end.character, in: ns)
        guard start != NSNotFound, end != NSNotFound, end >= start else {
            return NSRange(location: NSNotFound, length: 0)
        }
        return NSRange(location: start, length: max(1, end - start))
    }

    private func lspPosition(for event: NSEvent) -> LSPPosition? {
        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return nil }
        let pointInText = textView.convert(event.locationInWindow, from: nil)
        let containerPoint = NSPoint(
            x: pointInText.x - textView.textContainerOrigin.x,
            y: pointInText.y - textView.textContainerOrigin.y
        )
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        return lspPosition(characterOffset: charIndex)
    }

    private func lspPosition(characterOffset: Int) -> LSPPosition {
        let ns = textView.string as NSString
        var line = 0
        var lineStart = 0
        ns.enumerateSubstrings(in: NSRange(location: 0, length: min(characterOffset, ns.length)), options: [.byLines, .substringNotRequired]) { _, range, _, _ in
            line += 1
            lineStart = NSMaxRange(range)
        }
        return LSPPosition(line: max(0, line), character: max(0, characterOffset - lineStart))
    }

    private func offset(line: Int, character: Int, in text: NSString) -> Int {
        var currentLine = 0
        var result = NSNotFound
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: [.byLines, .substringNotRequired]) { _, range, _, stop in
            if currentLine == line {
                result = min(range.location + character, NSMaxRange(range))
                stop.pointee = true
            }
            currentLine += 1
        }
        if result == NSNotFound, line == currentLine {
            result = min(text.length, text.length + character)
        }
        return result
    }

    private func showHover(_ text: String, for event: NSEvent) {
        hoverPopover?.close()
        let controller = NSViewController()
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = HarnessDesign.chrome.textPrimary
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = HarnessDesign.chrome.sidebarBackground.cgColor
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
        ])
        controller.view = container
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        hoverPopover = popover
        let point = convert(event.locationInWindow, from: nil)
        popover.show(relativeTo: NSRect(origin: point, size: .zero), of: self, preferredEdge: .maxY)
    }
}

@MainActor
private final class SyntaxLineNumberGutterView: NSView {
    weak var textView: NSTextView?
    var diffLines: [Int: SyntaxTextView.DiffLineType] = [:]
    var diagnostics: [LSPDiagnostic] = []

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let textView, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else { return }
        let c = HarnessDesign.chrome
        c.sidebarBackground.withAlphaComponent(0.5).setFill()
        dirtyRect.fill()

        let visibleRect = textView.enclosingScrollView?.contentView.bounds ?? textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let text = textView.string as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: c.textTertiary,
        ]

        var lineNumber = 1
        text.enumerateSubstrings(in: NSRange(location: 0, length: charRange.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineNumber += 1
        }

        let diagnosticLines = Set(diagnostics.map { $0.range.start.line + 1 })
        let inset = textView.textContainerInset.height
        text.enumerateSubstrings(in: charRange, options: [.byLines, .substringNotRequired]) { [weak self] _, range, _, _ in
            guard let self else { return }
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: range.location)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            lineRect.origin.y += inset - visibleRect.origin.y

            if let diffType = self.diffLines[lineNumber] {
                let color: NSColor
                switch diffType {
                case .added: color = .systemGreen
                case .modified: color = .systemYellow
                case .deleted: color = .systemRed
                }
                color.setFill()
                NSRect(x: 0, y: lineRect.origin.y, width: 3, height: lineRect.height).fill()
            }

            if diagnosticLines.contains(lineNumber) {
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: NSRect(x: 6, y: lineRect.midY - 3, width: 6, height: 6)).fill()
            }

            let value = "\(lineNumber)" as NSString
            let size = value.size(withAttributes: attrs)
            value.draw(at: NSPoint(x: bounds.width - size.width - 8, y: lineRect.origin.y + (lineRect.height - size.height) / 2), withAttributes: attrs)
            lineNumber += 1
        }
    }
}

@MainActor
enum SyntaxHighlighter {
    static func highlight(_ text: String, fileExtension ext: String) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let c = HarnessDesign.chrome
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: c.textPrimary,
        ])
        let fullRange = NSRange(location: 0, length: attributed.length)
        let comments = commentPattern(for: ext)
        let strings = stringPattern(for: ext)

        if let comments, let regex = try? NSRegularExpression(pattern: comments, options: .anchorsMatchLines) {
            regex.matches(in: text, range: fullRange).forEach {
                attributed.addAttribute(.foregroundColor, value: NSColor.systemGreen.withAlphaComponent(0.8), range: $0.range)
            }
        }
        if let regex = try? NSRegularExpression(pattern: strings, options: [.anchorsMatchLines]) {
            regex.matches(in: text, range: fullRange).forEach {
                attributed.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: $0.range)
            }
        }
        let keywords = keywords(for: ext)
        if !keywords.isEmpty {
            let pattern = "\\b(" + keywords.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                regex.matches(in: text, range: fullRange).forEach {
                    attributed.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: $0.range)
                }
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"\b\d+(?:\.\d+)?\b"#) {
            regex.matches(in: text, range: fullRange).forEach {
                attributed.addAttribute(.foregroundColor, value: NSColor.systemCyan, range: $0.range)
            }
        }
        if ["md", "markdown"].contains(ext), let regex = try? NSRegularExpression(pattern: #"^#{1,6}\s+.*$|`[^`]+`|\*\*[^*]+\*\*"#, options: .anchorsMatchLines) {
            regex.matches(in: text, range: fullRange).forEach {
                attributed.addAttribute(.foregroundColor, value: HarnessDesign.chrome.accent, range: $0.range)
            }
        }
        return attributed
    }

    private static func stringPattern(for ext: String) -> String {
        if ["yaml", "yml"].contains(ext) {
            return #""[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*'"#
        }
        return #""[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*'|`[^`\\]*(?:\\.[^`\\]*)*`"#
    }

    private static func keywords(for ext: String) -> [String] {
        switch ext {
        case "swift":
            return ["import", "func", "var", "let", "class", "struct", "enum", "protocol", "extension", "if", "else", "guard", "return", "switch", "case", "for", "while", "in", "where", "self", "Self", "nil", "true", "false", "private", "public", "internal", "final", "static", "override", "init", "deinit", "throw", "throws", "try", "catch", "await", "async", "actor", "some", "any", "weak", "unowned", "mutating", "typealias"]
        case "ts", "tsx", "js", "jsx":
            return ["import", "export", "from", "function", "const", "let", "var", "class", "interface", "type", "if", "else", "return", "switch", "case", "for", "while", "of", "in", "this", "null", "undefined", "true", "false", "new", "async", "await", "try", "catch", "throw", "extends", "implements", "default", "break", "continue"]
        case "py":
            return ["import", "from", "def", "class", "if", "elif", "else", "return", "for", "while", "in", "is", "not", "and", "or", "True", "False", "None", "self", "with", "as", "try", "except", "finally", "raise", "yield", "async", "await", "pass", "lambda"]
        case "rs":
            return ["fn", "let", "mut", "const", "struct", "enum", "impl", "trait", "pub", "use", "mod", "if", "else", "match", "for", "while", "loop", "return", "self", "Self", "true", "false", "async", "await", "move", "where", "type", "unsafe"]
        case "go":
            return ["package", "import", "func", "var", "const", "type", "struct", "interface", "if", "else", "for", "range", "switch", "case", "return", "go", "defer", "chan", "map", "nil", "true", "false", "select", "break", "continue"]
        case "kt", "kts":
            return ["fun", "val", "var", "class", "object", "interface", "import", "package", "if", "else", "when", "for", "while", "do", "return", "throw", "try", "catch", "finally", "is", "as", "in", "null", "true", "false", "this", "super", "override", "open", "abstract", "sealed", "data", "companion", "suspend", "lateinit", "by", "lazy"]
        case "java":
            return ["import", "package", "class", "interface", "extends", "implements", "public", "private", "protected", "static", "final", "abstract", "void", "new", "return", "if", "else", "for", "while", "do", "switch", "case", "break", "continue", "try", "catch", "finally", "throw", "throws", "this", "super", "null", "true", "false", "synchronized", "volatile"]
        case "c", "h":
            return ["include", "define", "ifdef", "ifndef", "endif", "if", "else", "for", "while", "do", "switch", "case", "break", "continue", "return", "void", "int", "char", "float", "double", "long", "short", "unsigned", "signed", "const", "static", "extern", "struct", "enum", "typedef", "sizeof", "NULL"]
        case "cpp", "hpp", "cc", "cxx":
            return ["include", "define", "ifdef", "ifndef", "endif", "if", "else", "for", "while", "do", "switch", "case", "break", "continue", "return", "void", "int", "char", "float", "double", "long", "short", "unsigned", "signed", "const", "static", "extern", "struct", "enum", "typedef", "sizeof", "NULL", "class", "public", "private", "protected", "virtual", "override", "new", "delete", "namespace", "using", "template", "typename", "auto", "nullptr", "true", "false", "throw", "try", "catch", "constexpr", "noexcept"]
        case "sh", "bash", "zsh":
            return ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "in", "function", "return", "local", "export", "source", "echo", "exit", "true", "false", "set", "unset", "readonly"]
        case "rb":
            return ["def", "class", "module", "if", "elsif", "else", "unless", "end", "do", "while", "for", "in", "return", "yield", "begin", "rescue", "ensure", "raise", "nil", "true", "false", "self", "require", "include", "attr_accessor", "attr_reader", "puts", "lambda", "proc"]
        case "toml":
            return ["true", "false"]
        case "json", "yaml", "yml":
            return ["true", "false", "null", "yes", "no"]
        case "html", "htm":
            return ["html", "head", "body", "div", "span", "p", "a", "img", "script", "style", "link", "meta", "title", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "table", "tr", "td", "th", "form", "input", "button", "select", "option", "textarea"]
        case "css", "scss", "sass":
            return ["import", "media", "keyframes", "font-face", "supports", "inherit", "initial", "unset", "none", "auto", "block", "inline", "flex", "grid", "absolute", "relative", "fixed", "sticky", "hidden", "visible", "solid", "dashed", "dotted"]
        case "sql":
            return ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "ALTER", "DROP", "INDEX", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "AND", "OR", "NOT", "NULL", "IS", "IN", "LIKE", "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET", "AS", "DISTINCT", "COUNT", "SUM", "AVG", "MAX", "MIN", "TRUE", "FALSE"]
        case "dart":
            return ["import", "class", "extends", "implements", "mixin", "abstract", "final", "const", "var", "void", "if", "else", "for", "while", "do", "switch", "case", "break", "continue", "return", "async", "await", "Future", "Stream", "null", "true", "false", "this", "super", "new", "throw", "try", "catch", "finally", "late", "required"]
        case "lua":
            return ["local", "function", "end", "if", "then", "else", "elseif", "for", "while", "do", "repeat", "until", "return", "nil", "true", "false", "and", "or", "not", "in", "require"]
        case "php":
            return ["function", "class", "interface", "extends", "implements", "public", "private", "protected", "static", "final", "abstract", "new", "return", "if", "else", "elseif", "for", "foreach", "while", "do", "switch", "case", "break", "continue", "try", "catch", "finally", "throw", "null", "true", "false", "echo", "require", "include", "namespace", "use", "as"]
        default:
            return []
        }
    }

    private static func commentPattern(for ext: String) -> String? {
        switch ext {
        case "swift", "ts", "tsx", "js", "jsx", "rs", "go", "c", "cpp", "h", "hpp", "cc", "cxx", "java", "kt", "kts", "dart", "scss":
            return #"//.*$|/\*[\s\S]*?\*/"#
        case "py", "rb", "sh", "bash", "zsh", "yaml", "yml", "toml":
            return "#.*$"
        case "lua":
            return #"--.*$|--\[\[[\s\S]*?\]\]"#
        case "php":
            return #"//.*$|/\*[\s\S]*?\*/|#.*$"#
        case "sql":
            return #"--.*$|/\*[\s\S]*?\*/"#
        case "html", "htm":
            return #"<!--[\s\S]*?-->"#
        case "css", "sass":
            return #"/\*[\s\S]*?\*/"#
        default:
            return nil
        }
    }
}
