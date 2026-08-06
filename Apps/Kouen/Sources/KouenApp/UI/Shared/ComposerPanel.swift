import AppKit

/// Floating multi-line input panel that sends text to the active PTY on ⌘↩.
///
/// Open with ⌘⇧E. Esc dismisses without sending.
/// Key routing: ⌘↩ is a key equivalent so AppKit delivers it via
/// `performKeyEquivalent` before NSTextView sees it; Esc arrives as
/// `cancelOperation` through NSTextViewDelegate.
@MainActor
final class ComposerPanel: NSPanel, NSTextViewDelegate {
    static let shared = ComposerPanel()
    var onSubmit: ((String) -> Void)?

    private let textView: NSTextView
    private let scrollView = NSScrollView()
    private let hintLabel = NSTextField(labelWithString: "⌘↩ send · Esc dismiss")
    private var slashCompletionPopup: CompletionPopupView?

    /// M9: rich composer — `/` slash-command discoverability. Text already passes through
    /// to the active CLI unmodified on submit (Claude Code/Codex handle `/model` etc.
    /// natively), so this is a picker UI over the CLI's own commands, not a new capability
    /// Kouen implements itself. `@file` mention autocomplete (the other half of M9's
    /// original scope) is cut for this session — same UI pattern would extend to it, but
    /// there wasn't time to build+verify a second picker tonight. Documented, not silent.
    static let slashCommands = [
        "/clear", "/compact", "/model", "/agents", "/continue", "/resume", "/help", "/cost",
    ]

    /// Pure: given the full composer text and the cursor position, returns the slash-prefix
    /// and matching commands if the cursor is inside a `/`-prefixed token at the START of its
    /// line (mirrors how these CLIs themselves only treat a leading `/` as a command, not one
    /// mid-sentence). No AppKit dependency — testable without a real NSTextView.
    static func slashMatch(text: String, cursorLocation: Int) -> (prefix: String, candidates: [String])? {
        let ns = text as NSString
        guard cursorLocation >= 0, cursorLocation <= ns.length else { return nil }
        let upToCursor = ns.substring(to: cursorLocation)
        guard let lastNewline = upToCursor.range(of: "\n", options: .backwards) else {
            return matchIfSlashPrefixed(upToCursor)
        }
        let lineSoFar = String(upToCursor[upToCursor.index(after: lastNewline.lowerBound)...])
        return matchIfSlashPrefixed(lineSoFar)
    }

    private static func matchIfSlashPrefixed(_ lineSoFar: String) -> (prefix: String, candidates: [String])? {
        guard lineSoFar.hasPrefix("/") else { return nil }
        let candidates = slashCommands.filter { $0.hasPrefix(lineSoFar) }
        guard !candidates.isEmpty else { return nil }
        return (lineSoFar, candidates)
    }

    private init() {
        let tv = NSTextView()
        tv.isRichText = false
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.font = font
        tv.backgroundColor = NSColor(white: 0.12, alpha: 1)
        tv.textColor = NSColor(white: 0.9, alpha: 1)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        // `.textColor` alone doesn't reliably reach `typingAttributes` for text the user is
        // about to type into a freshly created NSTextView — it can default to black,
        // rendering invisible against this dark background until something else (e.g.
        // pasting) resets attributes. Pre-existing bug, not introduced by M9 — set
        // typingAttributes explicitly so every typed character uses the intended color.
        tv.typingAttributes = [.foregroundColor: NSColor(white: 0.9, alpha: 1), .font: font]
        self.textView = tv

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 180),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered, defer: false
        )
        self.isFloatingPanel = true
        self.title = "Composer"
        self.backgroundColor = NSColor(white: 0.12, alpha: 0.97)
        self.isMovableByWindowBackground = true
        setup()
    }

    override var canBecomeKey: Bool { true }

    private func setup() {
        textView.delegate = self

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        let cv = contentView!
        cv.addSubview(scrollView)
        cv.addSubview(hintLabel)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: cv.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -4),
            hintLabel.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 12),
            hintLabel.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -8),
        ])
    }

    func present(relativeTo window: NSWindow?, initialText: String = "") {
        if let w = window {
            let wf = w.frame
            setFrameOrigin(NSPoint(x: wf.midX - 310, y: wf.midY - 90))
        } else {
            center()
        }
        textView.string = initialText
        // Singleton panel reused across opens — `.string =` can reset typingAttributes on
        // each reuse, so reassert it every time the panel is (re)shown, not just at init.
        textView.typingAttributes = [.foregroundColor: NSColor(white: 0.9, alpha: 1), .font: textView.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)]
        makeKeyAndOrderFront(nil)
        makeFirstResponder(textView)
    }

    // MARK: - Key handling

    /// ⌘↩ is a key equivalent — AppKit delivers it here before NSTextView sees it.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.keyCode == 36 /* Return */ {
            submit()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Esc → `cancelOperation` selector via NSTextViewDelegate (same pattern as CommandPromptController).
    /// When the slash-command popup is showing, arrow/tab/return/esc drive it first instead.
    /// AppKit resets `typingAttributes` internally around first-responder/selection settling —
    /// the one-shot assignments in init/present() don't survive that. Reasserting here, which
    /// fires before every keystroke including the first, closes the gap.
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        textView.typingAttributes = [.foregroundColor: NSColor(white: 0.9, alpha: 1), .font: textView.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular)]
        return true
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if let popup = slashCompletionPopup {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                return popup.moveSelection(down: false)
            case #selector(NSResponder.moveDown(_:)):
                return popup.moveSelection(down: true)
            case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertNewline(_:)):
                popup.confirmSelection()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                dismissSlashCompletionPopup()
                return true
            default:
                break
            }
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            dismissSlashCompletionPopup()
            orderOut(nil)
            return true
        }
        return false
    }

    // MARK: - Slash commands (M9)

    func textDidChange(_ notification: Notification) {
        let cursor = textView.selectedRange().location
        guard let match = Self.slashMatch(text: textView.string, cursorLocation: cursor) else {
            dismissSlashCompletionPopup()
            return
        }
        showSlashCompletionPopup(prefix: match.prefix, candidates: match.candidates)
    }

    private func showSlashCompletionPopup(prefix: String, candidates: [String]) {
        if slashCompletionPopup == nil {
            let popup = CompletionPopupView(frame: .zero)
            popup.onConfirm = { [weak self] completion in
                self?.insertSlashCompletion(completion, prefix: prefix)
                self?.dismissSlashCompletionPopup()
            }
            popup.onDismiss = { [weak self] in self?.dismissSlashCompletionPopup() }
            contentView?.addSubview(popup)
            slashCompletionPopup = popup
        }
        guard let popup = slashCompletionPopup else { return }
        popup.update(candidates: candidates)

        let selectedRange = textView.selectedRange()
        guard selectedRange.location != NSNotFound else { return }
        let charRange = NSRange(location: selectedRange.location, length: 0)
        let screenRect = textView.firstRect(forCharacterRange: charRange, actualRange: nil)
        guard screenRect.origin.x != .infinity, let cv = contentView else { return }
        let windowRect = self.convertFromScreen(screenRect)
        let localPoint = cv.convert(windowRect.origin, from: nil)
        let width: CGFloat = 200
        let height = min(160, CGFloat(candidates.count) * 24 + 10)
        popup.frame = CGRect(x: localPoint.x, y: localPoint.y + screenRect.height + 4, width: width, height: height)
    }

    private func dismissSlashCompletionPopup() {
        slashCompletionPopup?.removeFromSuperview()
        slashCompletionPopup = nil
    }

    private func insertSlashCompletion(_ completion: String, prefix: String) {
        let selectedRange = textView.selectedRange()
        let replaceRange = NSRange(location: selectedRange.location - (prefix as NSString).length, length: (prefix as NSString).length)
        guard textView.shouldChangeText(in: replaceRange, replacementString: completion) else { return }
        textView.textStorage?.replaceCharacters(in: replaceRange, with: completion + " ")
        textView.didChangeText()
    }

    // MARK: - Submit

    private func submit() {
        dismissSlashCompletionPopup()
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { orderOut(nil); return }
        onSubmit?(text)
        orderOut(nil)
    }
}
