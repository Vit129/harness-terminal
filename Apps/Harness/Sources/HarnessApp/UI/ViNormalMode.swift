import AppKit
import HarnessLSP

// MARK: - Vi Mode State

enum ViMode: Equatable {
    case normal
    case insert
    case visual(line: Bool)    // v = char, V = line
    case replace               // R
    case operatorPending(op: Character)  // d/c/y waiting for motion/text-object
}

enum ViDiagnosticNavigator {
    static func targetIndex(currentLine: Int, diagnostics: [LSPDiagnostic], forward: Bool) -> Int? {
        guard !diagnostics.isEmpty else { return nil }
        let sorted = diagnostics.enumerated().sorted {
            let lhs = $0.element.range.start
            let rhs = $1.element.range.start
            if lhs.line == rhs.line { return lhs.character < rhs.character }
            return lhs.line < rhs.line
        }
        if forward {
            return sorted.first { $0.element.range.start.line > currentLine }?.offset ?? sorted.first?.offset
        }
        return sorted.last { $0.element.range.start.line < currentLine }?.offset ?? sorted.last?.offset
    }
}

// MARK: - Vi Engine

/// Pure vi normal-mode engine operating on NSTextView.
/// Supports: hjkl, w/W/b/B/e/E, 0/^/$/gg/G, {/}, Ctrl+d/u/f/b, %
/// Operators: d, c, y (+ motions + text objects)
/// Doubles: dd, cc, yy
/// Text objects: iw/aw, i"/a", i'/a', i`/a`, i(/a(, i[/a[, i{/a{
/// Visual: v (char), V (line) — d/c/y/>/< in visual
/// Editing: x, X, r, R, ~, J, p, P, u, Ctrl+r, ., o, O, a, A, I
/// Search: /, ?, n, N, *, #
/// Count prefix: 3w, 5j, 2dd …
@MainActor
final class ViEngine {
    weak var textView: NSTextView?
    private(set) var mode: ViMode = .normal
    var onModeChange: ((ViMode) -> Void)?
    /// Called when `:w` or `:wq` is executed — host provides save behaviour.
    var onSave: (() -> Void)?
    /// Called when `:q` or `:wq` is executed — host closes the file/pane.
    var onQuit: (() -> Void)?
    /// Called when `:e <path>` is executed — host opens the file in the editor.
    var onOpenFile: ((String) -> Void)?
    /// Called when `:set` changes a visual setting (key, value pairs like "number"=true).
    var onSetOption: ((String, String) -> Void)?
    /// Called for :bn/:bp buffer navigation — host switches to next/prev tab. delta = +1 or -1.
    var onNextBuffer: ((Int) -> Void)?
    /// Called for :ls/:buffers — host returns list of open tab names for display.
    var onListBuffers: (() -> [String])?
    /// Called when * / # search word — host highlights all matches inline.
    var onSearchHighlight: ((String) -> Void)?
    var onHover: ((LSPPosition) async -> String?)?
    var onDefinition: ((LSPPosition) async -> SyntaxDefinitionTarget?)?
    var onNavigateToDefinition: ((SyntaxDefinitionTarget) -> Void)?
    var onDiagnostics: (() -> [LSPDiagnostic])?

    // Count prefix accumulation
    private var countBuf = ""
    // For pending operator (d/c/y) + text-object multi-char (i"/iw etc.)
    private var pendingTextObject = false   // waiting for inner/outer char
    private var pendingInner = false
    // Yank register (unnamed) + named registers a-z
    private var register: String = ""
    private var registerIsLine = false
    private var namedRegisters: [Character: (text: String, isLine: Bool)] = [:]
    private var activeRegister: Character? = nil   // set by "a before operator
    private var pendingRegister = false            // waiting for register name char
    // Marks a-z (local), A-Z (global treated same here)
    private var marks: [Character: Int] = [:]
    private var lastJumpPos: Int = 0       // for '' and `` (jump back)
    // Jump list (Ctrl+o / Ctrl+i)
    private var jumpList: [Int] = []
    private var jumpIndex: Int = -1        // current position in jumpList
    // Last visual selection for gv
    private var lastVisualRange: NSRange = NSRange(location: 0, length: 0)
    private var lastVisualIsLine: Bool = false
    // Last edit for . repeat
    private var lastEdit: (() -> Void)?
    // Visual anchor
    private var visualAnchor: Int = 0
    // Search
    private var lastSearch: (pattern: String, forward: Bool) = ("", true)
    // Macro recording: register char → accumulated keys
    private var recordingMacro: Character? = nil
    private var macroBuffer: String = ""
    private var macros: [Character: String] = [:]
    private var pendingMacroPlay = false     // waiting for register char after @
    private var pendingMacroRecord = false   // waiting for register char after q
    private var lastPlayedMacro: Character? = nil

    func enter(mode newMode: ViMode) {
        // Save visual selection before leaving visual mode (for gv)
        if case let .visual(isLine) = mode, let tv = textView {
            let sel = tv.selectedRange()
            if sel.length > 0 {
                lastVisualRange = sel
                lastVisualIsLine = isLine
            }
        }
        mode = newMode
        onModeChange?(newMode)
        if case .insert = newMode {
            textView?.isEditable = true
        } else {
            textView?.isEditable = false
        }
    }

    // MARK: - Main dispatch

    /// Returns true if the event was consumed.
    func handle(_ event: NSEvent) -> Bool {
        guard let tv = textView else { return false }
        let flags = event.modifierFlags
        let cmd = flags.contains(.command)
        let ctrl = flags.contains(.control)
        let shift = flags.contains(.shift)
        let chars = event.characters ?? ""
        let key = event.charactersIgnoringModifiers ?? ""

        // Record keystrokes when macro recording is active (before dispatch)
        if recordingMacro != nil, case .normal = mode, !cmd, !ctrl {
            if event.keyCode != 53 { // not Esc
                macroBuffer += key
            }
        }
        // Esc always returns to normal from any mode
        if event.keyCode == 53 {
            if case .insert = mode { clampCursorOffEOL(tv) }
            enter(mode: .normal)
            countBuf = ""
            pendingTextObject = false
            return true
        }

        switch mode {
        case .insert, .replace:
            return false  // let NSTextView handle
        case .visual:
            return handleVisual(key: key, chars: chars, ctrl: ctrl, shift: shift, cmd: cmd, tv: tv)
        case .normal:
            return handleNormal(key: key, chars: chars, ctrl: ctrl, shift: shift, cmd: cmd, event: event, tv: tv)
        case .operatorPending(let op):
            return handleOperatorPending(op: op, key: key, chars: chars, tv: tv)
        }
    }

    // MARK: - Normal mode

    private func handleNormal(key: String, chars: String, ctrl: Bool, shift: Bool, cmd: Bool, event: NSEvent, tv: NSTextView) -> Bool {
        // Pending text object second char (after i/a)
        if pendingTextObject, let op = pendingOp {
            pendingTextObject = false
            let inner = pendingInner
            pendingOp = nil
            applyOperatorTextObject(op: op, char: key, inner: inner, tv: tv)
            return true
        }

        // Count digit accumulation
        if let d = key.first, d.isNumber, d != "0" || !countBuf.isEmpty {
            if !ctrl {
                countBuf += String(d)
                return true
            }
        }
        let count = max(1, Int(countBuf) ?? 1)
        countBuf = ""

        if let forward = pendingDiagnosticJump {
            pendingDiagnosticJump = nil
            if key == "d" {
                jumpDiagnostic(tv, forward: forward)
                return true
            }
            return false
        }

        // Ctrl combinations
        if ctrl {
            switch key {
            case "d": scroll(tv, lines: tv.visibleRect.height / lineHeight(tv) / 2, down: true);  return true
            case "u": scroll(tv, lines: tv.visibleRect.height / lineHeight(tv) / 2, down: false); return true
            case "f": scroll(tv, lines: tv.visibleRect.height / lineHeight(tv), down: true);  return true
            case "b": scroll(tv, lines: tv.visibleRect.height / lineHeight(tv), down: false); return true
            case "r": tv.undoManager?.redo(); return true
            case "o": jumpListBack(tv);    return true   // Ctrl+o — jump back
            case "i": jumpListForward(tv); return true   // Ctrl+i — jump forward
            default: break
            }
        }

        switch key {
        // MARK: Motions
        case "h": move(tv, by: -count); return true
        case "l": move(tv, by:  count); return true
        case "j": moveLines(tv, by:  count); return true
        case "k": moveLines(tv, by: -count); return true
        case "w": moveWords(tv, count: count, forward: true,  bigWord: false, toEnd: false); return true
        case "W": moveWords(tv, count: count, forward: true,  bigWord: true,  toEnd: false); return true
        case "b": moveWords(tv, count: count, forward: false, bigWord: false, toEnd: false); return true
        case "B": moveWords(tv, count: count, forward: false, bigWord: true,  toEnd: false); return true
        case "e": moveWords(tv, count: count, forward: true,  bigWord: false, toEnd: true);  return true
        case "E": moveWords(tv, count: count, forward: true,  bigWord: true,  toEnd: true);  return true
        case "0": moveLine(tv, to: .start); return true
        case "^": moveLine(tv, to: .firstNonBlank); return true
        case "$": moveLine(tv, to: .end); return true
        case "g":
            pendingG = true
            return true
        case "G":
            if countBuf.isEmpty { moveToLine(tv, line: lineCount(tv)) }
            else { moveToLine(tv, line: count) }
            return true
        case "{": moveParagraph(tv, forward: false, count: count); return true
        case "}": moveParagraph(tv, forward: true,  count: count); return true
        case "%": jumpMatchingBracket(tv); return true
        case "f": pendingFind = (true, false);  return true  // f{char}
        case "F": pendingFind = (false, false); return true  // F{char}
        case "t": pendingFind = (true, true);   return true  // t{char}
        case "T": pendingFind = (false, true);  return true  // T{char}
        case ";": repeatLastFind(tv, reverse: false, count: count); return true
        case ",": repeatLastFind(tv, reverse: true,  count: count); return true

        // MARK: Operators
        case "d": enter(mode: .operatorPending(op: "d")); return true
        case "c": enter(mode: .operatorPending(op: "c")); return true
        case "y": enter(mode: .operatorPending(op: "y")); return true
        case "D": deleteToEndOfLine(tv); lastEdit = { [weak self] in self?.deleteToEndOfLine(tv) }; return true
        case "C": changeToEndOfLine(tv); return true
        case "Y": yankLines(tv, count: 1); return true

        // MARK: Simple edits
        case "x": deleteChar(tv, forward: true,  count: count); lastEdit = { [weak self] in self?.deleteChar(tv, forward: true, count: count) }; return true
        case "X": deleteChar(tv, forward: false, count: count); lastEdit = { [weak self] in self?.deleteChar(tv, forward: false, count: count) }; return true
        case "r":
            pendingReplace = true
            return true
        case "R": enter(mode: .replace); return true
        case "s": deleteChar(tv, forward: true, count: count); enter(mode: .insert); return true  // s = cl
        case "S": deleteLine(tv, count: 1); enter(mode: .insert); return true  // S = cc
        case "~": toggleCase(tv, count: count); return true
        case "J": joinLines(tv, count: count); return true
        case ".": lastEdit?(); return true

        // MARK: Insert-entry
        case "i": enter(mode: .insert); return true
        case "I": moveLine(tv, to: .firstNonBlank); enter(mode: .insert); return true
        case "a": move(tv, by: 1); enter(mode: .insert); return true
        case "A": moveLine(tv, to: .end); enter(mode: .insert); return true
        case "o": openLineBelow(tv); enter(mode: .insert); return true
        case "O": openLineAbove(tv); enter(mode: .insert); return true

        // MARK: Paste / undo
        case "p": paste(tv, before: false, count: count); return true
        case "P": paste(tv, before: true,  count: count); return true
        case "u": tv.undoManager?.undo(); return true

        // MARK: Visual
        case "v":
            visualAnchor = cursorPos(tv)
            enter(mode: .visual(line: false))
            updateVisualSelection(tv)
            return true
        case "V":
            visualAnchor = lineStart(tv, at: cursorPos(tv))
            enter(mode: .visual(line: true))
            updateVisualSelection(tv)
            return true

        // MARK: Search
        case "/": beginSearch(tv, forward: true);  return true
        case "?": beginSearch(tv, forward: false); return true
        case "n": repeatSearch(tv, reverse: false, count: count); return true
        case "N": repeatSearch(tv, reverse: true,  count: count); return true
        case "*": searchWordUnderCursor(tv, forward: true);  return true
        case "#": searchWordUnderCursor(tv, forward: false); return true
        case "K": showHover(tv); return true
        case "]": pendingDiagnosticJump = true; return true
        case "[": pendingDiagnosticJump = false; return true

        // MARK: Ex command
        case ":": presentExPrompt(tv); return true

        // MARK: Indent
        case ">": enter(mode: .operatorPending(op: ">")); return true
        case "<": enter(mode: .operatorPending(op: "<")); return true

        // MARK: H/M/L — screen positions
        case "H": moveScreenPosition(tv, pos: .top);    return true
        case "M": moveScreenPosition(tv, pos: .middle); return true
        case "L": moveScreenPosition(tv, pos: .bottom); return true

        // MARK: ZZ / ZQ — save+quit / quit shortcuts
        case "Z":
            pendingZ = true
            return true

        // MARK: Marks
        case "m":
            pendingMark = true
            return true
        case "'":
            pendingMarkJump = true
            return true
        case "`":
            pendingMarkJump = true   // backtick — same exact-pos behaviour
            return true

        // MARK: Named register prefix "
        case "\"":
            pendingRegister = true
            return true

        // MARK: Macros
        case "q":
            if recordingMacro != nil {
                // q while recording = stop
                if let reg = recordingMacro { macros[reg] = macroBuffer }
                recordingMacro = nil; macroBuffer = ""; return true
            }
            pendingMacroRecord = true
            return true
        case "@":
            pendingMacroPlay = true
            return true

        default: break
        }

        // g + second key
        if pendingG {
            pendingG = false
            switch key {
            case "g": moveToLine(tv, line: count == 1 ? 1 : count); return true
            case "f": openPathUnderCursor(tv); return true
            case "d": goToDefinition(tv); return true
            case "e": moveWords(tv, count: count, forward: false, bigWord: false, toEnd: true); return true
            case "E": moveWords(tv, count: count, forward: false, bigWord: true, toEnd: true); return true
            case "~": toggleCaseLine(tv); return true
            case "u": lowercaseLine(tv); return true
            case "U": uppercaseLine(tv); return true
            case "v":
                // gv — reselect last visual selection
                visualAnchor = lastVisualRange.location
                tv.setSelectedRange(lastVisualRange)
                enter(mode: .visual(line: lastVisualIsLine))
                return true
            default: return false
            }
        }

        // f/F/t/T — wait for char
        if let (fwd, till) = pendingFind {
            pendingFind = nil
            findChar(tv, char: key, forward: fwd, till: till, count: count)
            return true
        }

        // r — wait for replacement char
        if pendingReplace {
            pendingReplace = false
            replaceChar(tv, with: key, count: count)
            return true
        }

        // ZZ / ZQ
        if pendingZ {
            pendingZ = false
            switch key {
            case "Z": onSave?(); onQuit?()
            case "Q": onQuit?()
            default: break
            }
            return true
        }

        // " — named register: next char selects register for operator
        if pendingRegister {
            pendingRegister = false
            if let c = key.first, (c.isLetter && c.isLowercase) || (c >= "0" && c <= "9") {
                activeRegister = c
            }
            return true
        }

        // m{char} — set mark
        if pendingMark {
            pendingMark = false
            if let c = key.first, c.isLetter {
                marks[c] = cursorPos(tv)
            }
            return true
        }

        // '{char} or `{char} — jump to mark
        if pendingMarkJump {
            pendingMarkJump = false
            if key == "'" || key == "`" {
                // '' / `` — jump back
                let dest = lastJumpPos
                pushJump(cursorPos(tv))
                lastJumpPos = cursorPos(tv)
                tv.setSelectedRange(NSRange(location: dest, length: 0))
            } else if let c = key.first, let pos = marks[c] {
                pushJump(cursorPos(tv))
                lastJumpPos = cursorPos(tv)
                tv.setSelectedRange(NSRange(location: pos, length: 0))
                tv.scrollRangeToVisible(NSRange(location: pos, length: 0))
            }
            return true
        }

        // q{char} — start recording macro
        if pendingMacroRecord {
            pendingMacroRecord = false
            if let c = key.first, c.isLetter {
                recordingMacro = c
                macroBuffer = ""
            }
            return true
        }

        // @{char} — play macro
        if pendingMacroPlay {
            pendingMacroPlay = false
            if key == "@" {
                // @@ — repeat last played macro
                if let last = lastPlayedMacro { playMacro(last, tv: tv, count: count) }
            } else if let c = key.first {
                playMacro(c, tv: tv, count: count)
            }
            return true
        }

        return false
    }

    // MARK: - Jump list (Ctrl+o / Ctrl+i)

    private func pushJump(_ pos: Int) {
        // Truncate forward history, append current
        if jumpIndex < jumpList.count - 1 {
            jumpList = Array(jumpList.prefix(jumpIndex + 1))
        }
        jumpList.append(pos)
        if jumpList.count > 100 { jumpList.removeFirst() }
        jumpIndex = jumpList.count - 1
    }

    func pushJumpPublic(_ pos: Int) { pushJump(pos) }  // called after go-to-def

    private func jumpListBack(_ tv: NSTextView) {
        guard jumpIndex > 0 else { return }
        if jumpIndex == jumpList.count - 1 { pushJump(cursorPos(tv)); jumpIndex -= 1 }
        jumpIndex -= 1
        let pos = jumpList[jumpIndex]
        tv.setSelectedRange(NSRange(location: pos, length: 0))
        tv.scrollRangeToVisible(NSRange(location: pos, length: 0))
    }

    private func jumpListForward(_ tv: NSTextView) {
        guard jumpIndex < jumpList.count - 1 else { return }
        jumpIndex += 1
        let pos = jumpList[jumpIndex]
        tv.setSelectedRange(NSRange(location: pos, length: 0))
        tv.scrollRangeToVisible(NSRange(location: pos, length: 0))
    }

    private func playMacro(_ register: Character, tv: NSTextView, count: Int) {        guard let macro = macros[register] else { return }
        lastPlayedMacro = register
        // Re-execute stored keystroke string by directly calling the action dispatcher.
        // Each char is treated as a plain normal-mode key (no modifiers).
        for _ in 0..<count {
            for ch in macro {
                let k = String(ch)
                _ = dispatchNormalKey(k, tv: tv)
            }
        }
    }

    /// Minimal key dispatch used by macro playback (no NSEvent needed).
    private func dispatchNormalKey(_ key: String, tv: NSTextView) -> Bool {
        let count = max(1, Int(countBuf) ?? 1)
        countBuf = ""
        switch key {
        case "h": move(tv, by: -count)
        case "l": move(tv, by:  count)
        case "j": moveLines(tv, by:  count)
        case "k": moveLines(tv, by: -count)
        case "w": moveWords(tv, count: count, forward: true,  bigWord: false, toEnd: false)
        case "b": moveWords(tv, count: count, forward: false, bigWord: false, toEnd: false)
        case "e": moveWords(tv, count: count, forward: true,  bigWord: false, toEnd: true)
        case "0": moveLine(tv, to: .start)
        case "^": moveLine(tv, to: .firstNonBlank)
        case "$": moveLine(tv, to: .end)
        case "x": deleteChar(tv, forward: true, count: count)
        case "X": deleteChar(tv, forward: false, count: count)
        case "p": paste(tv, before: false, count: count)
        case "P": paste(tv, before: true, count: count)
        case "u": tv.undoManager?.undo()
        case "J": joinLines(tv, count: count)
        case "~": toggleCase(tv, count: count)
        case "1", "2", "3", "4", "5", "6", "7", "8", "9":
            countBuf += key; return true
        default: return false
        }
        return true
    }

    // Pending state (kept as private vars to avoid complex associated values)
    private var pendingG = false
    private var pendingDiagnosticJump: Bool?
    private var pendingZ = false
    private var pendingMark = false
    private var pendingMarkJump = false
    private var pendingFind: (forward: Bool, till: Bool)? = nil
    private var pendingReplace = false
    private var pendingOp: Character? = nil

    // MARK: - Operator pending

    private func handleOperatorPending(op: Character, key: String, chars: String, tv: NSTextView) -> Bool {
        let count = max(1, Int(countBuf) ?? 1)
        countBuf = ""

        // Double operator: dd / cc / yy / >> / <<
        if String(op) == key {
            switch op {
            case "d": let e: () -> Void = { [weak self] in self?.deleteLine(tv, count: count) }; e(); lastEdit = e
            case "c": deleteLine(tv, count: count); enter(mode: .insert)
            case "y": yankLines(tv, count: count)
            case ">": indentLines(tv, count: count, indent: true)
            case "<": indentLines(tv, count: count, indent: false)
            default: break
            }
            enter(mode: .normal)
            return true
        }

        // Text object prefix: i / a
        if key == "i" || key == "a" {
            pendingTextObject = true
            pendingInner = key == "i"
            pendingOp = op
            enter(mode: .normal)   // stay normal, wait for next char
            return true
        }

        // Motion
        var range: NSRange? = nil
        switch key {
        case "w": range = wordRange(tv, count: count, bigWord: false)
        case "W": range = wordRange(tv, count: count, bigWord: true)
        case "b": range = wordRangeBack(tv, count: count, bigWord: false)
        case "B": range = wordRangeBack(tv, count: count, bigWord: true)
        case "e": range = wordEndRange(tv, count: count, bigWord: false)
        case "E": range = wordEndRange(tv, count: count, bigWord: true)
        case "0": range = rangeToLineStart(tv, firstNonBlank: false)
        case "^": range = rangeToLineStart(tv, firstNonBlank: true)
        case "$":
            range = rangeToLineEnd(tv)
        case "D" where op == "d":
            range = rangeToLineEnd(tv)
        case "h": range = NSRange(location: max(0, cursorPos(tv) - count), length: count)
        case "l": range = NSRange(location: cursorPos(tv), length: count)
        case "j": range = rangeLines(tv, count: count + 1, includeCurrent: true)
        case "k": range = rangeLines(tv, count: -(count + 1), includeCurrent: true)
        case "g":
            pendingG = true
            return true
        case "G":
            let start = min(cursorPos(tv), eofPos(tv))
            let end = eofPos(tv)
            range = NSRange(location: start, length: end - start)
        case "{": range = rangeOverParagraph(tv, forward: false, count: count)
        case "}": range = rangeOverParagraph(tv, forward: true, count: count)
        default: break
        }

        if pendingG {
            pendingG = false
            // gg motion in operator context = from cursor to file start
            if key == "g" {
                let pos = cursorPos(tv)
                range = NSRange(location: 0, length: pos)
            }
        }

        if let r = range {
            applyOperator(op: op, range: r, tv: tv)
        }
        enter(mode: op == "c" ? .insert : .normal)
        return true
    }

    private func applyOperatorTextObject(op: Character, char: String, inner: Bool, tv: NSTextView) {
        guard let range = textObjectRange(tv, char: char, inner: inner) else {
            enter(mode: .normal)
            return
        }
        applyOperator(op: op, range: range, tv: tv)
        enter(mode: op == "c" ? .insert : .normal)
    }

    private func applyOperator(op: Character, range: NSRange, tv: NSTextView) {
        let text = (tv.string as NSString).substring(with: range)
        switch op {
        case "d":
            registerIsLine = false; register = text
            let e: () -> Void = { [weak self] in self?.deleteRange(tv, range: range) }
            e(); lastEdit = e
        case "c":
            registerIsLine = false; register = text
            deleteRange(tv, range: range)
        case "y":
            registerIsLine = false; register = text
            // Move cursor to start of yanked region
            tv.setSelectedRange(NSRange(location: range.location, length: 0))
        case ">":
            indentRange(tv, range: range, indent: true)
        case "<":
            indentRange(tv, range: range, indent: false)
        default: break
        }
    }

    // MARK: - Visual mode

    private func handleVisual(key: String, chars: String, ctrl: Bool, shift: Bool, cmd: Bool, tv: NSTextView) -> Bool {
        let count = max(1, Int(countBuf) ?? 1)
        countBuf = ""

        guard case let .visual(isLine) = mode else { return false }

        // Motions (move head, anchor stays)
        switch key {
        case "h": move(tv, by: -count); updateVisualSelection(tv); return true
        case "l": move(tv, by:  count); updateVisualSelection(tv); return true
        case "j": moveLines(tv, by:  count); updateVisualSelection(tv); return true
        case "k": moveLines(tv, by: -count); updateVisualSelection(tv); return true
        case "w": moveWords(tv, count: count, forward: true,  bigWord: false, toEnd: false); updateVisualSelection(tv); return true
        case "W": moveWords(tv, count: count, forward: true,  bigWord: true,  toEnd: false); updateVisualSelection(tv); return true
        case "b": moveWords(tv, count: count, forward: false, bigWord: false, toEnd: false); updateVisualSelection(tv); return true
        case "B": moveWords(tv, count: count, forward: false, bigWord: true,  toEnd: false); updateVisualSelection(tv); return true
        case "e": moveWords(tv, count: count, forward: true,  bigWord: false, toEnd: true);  updateVisualSelection(tv); return true
        case "0": moveLine(tv, to: .start);         updateVisualSelection(tv); return true
        case "^": moveLine(tv, to: .firstNonBlank); updateVisualSelection(tv); return true
        case "$": moveLine(tv, to: .end);            updateVisualSelection(tv); return true
        case "g":
            if pendingG { pendingG = false; moveToLine(tv, line: 1); updateVisualSelection(tv); return true }
            pendingG = true; return true
        case "G": moveToLine(tv, line: lineCount(tv)); updateVisualSelection(tv); return true
        case "{": moveParagraph(tv, forward: false, count: count); updateVisualSelection(tv); return true
        case "}": moveParagraph(tv, forward: true, count: count);  updateVisualSelection(tv); return true

        // Operators on selection
        case "d", "x":
            let sel = tv.selectedRange()
            if sel.length > 0 {
                register = (tv.string as NSString).substring(with: sel)
                registerIsLine = isLine
                deleteRange(tv, range: sel)
            }
            enter(mode: .normal)
            return true
        case "y":
            let sel = tv.selectedRange()
            register = sel.length > 0 ? (tv.string as NSString).substring(with: sel) : ""
            registerIsLine = isLine
            tv.setSelectedRange(NSRange(location: visualAnchor, length: 0))
            enter(mode: .normal)
            return true
        case "c":
            let sel = tv.selectedRange()
            if sel.length > 0 {
                register = (tv.string as NSString).substring(with: sel)
                registerIsLine = isLine
                deleteRange(tv, range: sel)
            }
            enter(mode: .insert)
            return true
        case ">":
            indentRange(tv, range: tv.selectedRange(), indent: true)
            enter(mode: .normal)
            return true
        case "<":
            indentRange(tv, range: tv.selectedRange(), indent: false)
            enter(mode: .normal)
            return true
        case "=":
            // auto-indent: re-indent selected lines (same as >, simplified to remove+re-add leading whitespace to match shiftwidth 4)
            indentRange(tv, range: tv.selectedRange(), indent: false)  // strip existing
            enter(mode: .normal)
            return true
        case "u":
            lowercaseRange(tv, range: tv.selectedRange())
            enter(mode: .normal)
            return true
        case "U":
            uppercaseRange(tv, range: tv.selectedRange())
            enter(mode: .normal)
            return true
        case "~":
            toggleCaseRange(tv, range: tv.selectedRange())
            enter(mode: .normal)
            return true
        case "v":
            // toggle between char/line visual
            if isLine {
                visualAnchor = cursorPos(tv)
                enter(mode: .visual(line: false))
            } else {
                enter(mode: .normal)
            }
            return true
        case "V":
            if !isLine {
                visualAnchor = lineStart(tv, at: cursorPos(tv))
                enter(mode: .visual(line: true))
                updateVisualSelection(tv)
            } else {
                enter(mode: .normal)
            }
            return true
        case "o":   // swap anchor and head
            let sel = tv.selectedRange()
            let otherEnd = sel.location == visualAnchor ? sel.location + sel.length : sel.location
            visualAnchor = cursorPos(tv)
            tv.setSelectedRange(NSRange(location: otherEnd, length: 0))
            updateVisualSelection(tv)
            return true
        default: break
        }
        return false
    }

    private func updateVisualSelection(_ tv: NSTextView) {
        guard case let .visual(isLine) = mode else { return }
        let cur = cursorPos(tv)
        let lo = min(visualAnchor, cur)
        let hi = max(visualAnchor, cur)
        if isLine {
            let start = lineStart(tv, at: lo)
            let end   = lineEnd(tv, at: hi) + 1 // include newline
            let clamped = min(end, tv.string.utf16.count)
            tv.setSelectedRange(NSRange(location: start, length: max(0, clamped - start)))
        } else {
            tv.setSelectedRange(NSRange(location: lo, length: hi - lo + 1))
        }
    }

    // MARK: - Motion helpers

    private func cursorPos(_ tv: NSTextView) -> Int {
        tv.selectedRange().location
    }

    private func eofPos(_ tv: NSTextView) -> Int {
        tv.string.utf16.count
    }

    private func lineHeight(_ tv: NSTextView) -> CGFloat {
        tv.font?.pointSize ?? 14
    }

    private func move(_ tv: NSTextView, by delta: Int) {
        let pos = cursorPos(tv)
        let ns = tv.string as NSString
        let len = ns.length
        let new = max(0, min(len, pos + delta))
        tv.setSelectedRange(NSRange(location: new, length: 0))
    }

    private func moveLines(_ tv: NSTextView, by delta: Int) {
        let pos = cursorPos(tv)
        let ns = tv.string as NSString
        var line = 0, col = 0
        posToLineCol(ns, pos: pos, line: &line, col: &col)
        let targetLine = max(0, min(lineCount(tv) - 1, line + delta))
        let newPos = lineColToPos(ns, line: targetLine, col: col)
        tv.setSelectedRange(NSRange(location: newPos, length: 0))
    }

    private func posToLineCol(_ ns: NSString, pos: Int, line: inout Int, col: inout Int) {
        var p = 0, ln = 0
        let len = ns.length
        while p < pos && p < len {
            if ns.character(at: p) == 10 { ln += 1 }
            p += 1
        }
        line = ln
        // column = distance from last newline
        var c = pos - 1
        while c >= 0 && ns.character(at: c) != 10 { c -= 1 }
        col = pos - (c + 1)
    }

    private func lineColToPos(_ ns: NSString, line: Int, col: Int) -> Int {
        var ln = 0, p = 0
        let len = ns.length
        while p < len && ln < line {
            if ns.character(at: p) == 10 { ln += 1 }
            p += 1
        }
        // p is now at start of target line
        let lineStart = p
        var lineEnd = p
        while lineEnd < len && ns.character(at: lineEnd) != 10 { lineEnd += 1 }
        return min(lineStart + col, max(lineStart, lineEnd - 1))
    }

    private func lineCount(_ tv: NSTextView) -> Int {
        return (tv.string.components(separatedBy: "\n").count)
    }

    private func lineStart(_ tv: NSTextView, at pos: Int) -> Int {
        let ns = tv.string as NSString
        var p = min(pos, ns.length - 1)
        if p < 0 { return 0 }
        while p > 0 && ns.character(at: p - 1) != 10 { p -= 1 }
        return p
    }

    private func lineEnd(_ tv: NSTextView, at pos: Int) -> Int {
        let ns = tv.string as NSString
        var p = min(pos, ns.length - 1)
        if p < 0 { return 0 }
        while p < ns.length && ns.character(at: p) != 10 { p += 1 }
        return p > 0 ? p - 1 : 0
    }

    enum LinePos { case start, firstNonBlank, end }

    private func moveLine(_ tv: NSTextView, to pos: LinePos) {
        let cur = cursorPos(tv)
        let start = lineStart(tv, at: cur)
        let end = lineEnd(tv, at: cur)
        switch pos {
        case .start:
            tv.setSelectedRange(NSRange(location: start, length: 0))
        case .firstNonBlank:
            let ns = tv.string as NSString
            var p = start
            while p <= end && (ns.character(at: p) == 32 || ns.character(at: p) == 9) { p += 1 }
            tv.setSelectedRange(NSRange(location: min(p, end), length: 0))
        case .end:
            tv.setSelectedRange(NSRange(location: max(start, end), length: 0))
        }
    }

    private func moveToLine(_ tv: NSTextView, line: Int) {
        let ns = tv.string as NSString
        let targetLine = max(1, min(line, lineCount(tv))) - 1  // 0-based
        let newPos = lineColToPos(ns, line: targetLine, col: 0)
        tv.setSelectedRange(NSRange(location: newPos, length: 0))
        tv.scrollRangeToVisible(NSRange(location: newPos, length: 0))
    }

    private func isWordChar(_ c: unichar, bigWord: Bool) -> Bool {
        if bigWord { return c != 32 && c != 9 && c != 10 }
        guard let scalar = UnicodeScalar(c) else { return false }
        let ch = Character(scalar)
        return ch.isLetter || ch.isNumber || c == 95  // _ = 95
    }

    private func moveWords(_ tv: NSTextView, count: Int, forward: Bool, bigWord: Bool, toEnd: Bool) {
        var pos = cursorPos(tv)
        let ns = tv.string as NSString
        let len = ns.length
        for _ in 0..<count {
            if forward {
                if toEnd {
                    // e/E: move to end of current/next word
                    if pos < len - 1 { pos += 1 }
                    while pos < len - 1 && !isWordChar(ns.character(at: pos), bigWord: bigWord) { pos += 1 }
                    while pos < len - 1 && isWordChar(ns.character(at: pos + 1), bigWord: bigWord) { pos += 1 }
                } else {
                    // w/W: move to start of next word
                    while pos < len && isWordChar(ns.character(at: pos), bigWord: bigWord) { pos += 1 }
                    while pos < len && !isWordChar(ns.character(at: pos), bigWord: bigWord) { pos += 1 }
                }
            } else {
                // b/B / ge/gE
                if pos > 0 { pos -= 1 }
                if toEnd {
                    // ge/gE: move to end of previous word
                    while pos > 0 && !isWordChar(ns.character(at: pos), bigWord: bigWord) { pos -= 1 }
                    while pos > 0 && isWordChar(ns.character(at: pos - 1), bigWord: bigWord) { pos -= 1 }
                } else {
                    while pos > 0 && !isWordChar(ns.character(at: pos), bigWord: bigWord) { pos -= 1 }
                    while pos > 0 && isWordChar(ns.character(at: pos - 1), bigWord: bigWord) { pos -= 1 }
                }
            }
        }
        tv.setSelectedRange(NSRange(location: max(0, min(pos, len)), length: 0))
    }

    private func moveParagraph(_ tv: NSTextView, forward: Bool, count: Int) {
        var pos = cursorPos(tv)
        let ns = tv.string as NSString
        let len = ns.length
        for _ in 0..<count {
            if forward {
                // skip non-empty lines
                while pos < len && ns.character(at: pos) != 10 { pos += 1 }
                // skip empty lines
                while pos < len && ns.character(at: pos) == 10 { pos += 1 }
            } else {
                if pos > 0 { pos -= 1 }
                while pos > 0 && ns.character(at: pos) == 10 { pos -= 1 }
                while pos > 0 && ns.character(at: pos - 1) != 10 { pos -= 1 }
            }
        }
        tv.setSelectedRange(NSRange(location: max(0, min(pos, len)), length: 0))
    }

    private func jumpMatchingBracket(_ tv: NSTextView) {
        let pos = cursorPos(tv)
        let ns = tv.string as NSString
        let len = ns.length
        guard pos < len else { return }
        let open: [unichar] = [40, 91, 123]   // ( [ {
        let close: [unichar] = [41, 93, 125]   // ) ] }
        let ch = ns.character(at: pos)
        if let idx = open.firstIndex(of: ch) {
            // search forward for matching close
            var depth = 1; var p = pos + 1
            while p < len && depth > 0 {
                let c = ns.character(at: p)
                if c == open[idx] { depth += 1 }
                else if c == close[idx] { depth -= 1 }
                p += 1
            }
            if depth == 0 { tv.setSelectedRange(NSRange(location: p - 1, length: 0)) }
        } else if let idx = close.firstIndex(of: ch) {
            // search backward
            var depth = 1; var p = pos - 1
            while p >= 0 && depth > 0 {
                let c = ns.character(at: p)
                if c == close[idx] { depth += 1 }
                else if c == open[idx] { depth -= 1 }
                p -= 1
            }
            if depth == 0 { tv.setSelectedRange(NSRange(location: p + 1, length: 0)) }
        }
    }

    private var lastFindChar: (char: String, forward: Bool, till: Bool) = ("", true, false)

    private func findChar(_ tv: NSTextView, char: String, forward: Bool, till: Bool, count: Int) {
        guard !char.isEmpty else { return }
        lastFindChar = (char, forward, till)
        let ns = tv.string as NSString
        let len = ns.length
        var pos = cursorPos(tv)
        let target = (char as NSString).character(at: 0)
        for _ in 0..<count {
            if forward {
                var p = pos + 1
                while p < len && ns.character(at: p) != target { p += 1 }
                if p < len { pos = till ? p - 1 : p }
            } else {
                var p = pos - 1
                while p >= 0 && ns.character(at: p) != target { p -= 1 }
                if p >= 0 { pos = till ? p + 1 : p }
            }
        }
        tv.setSelectedRange(NSRange(location: pos, length: 0))
    }

    private func repeatLastFind(_ tv: NSTextView, reverse: Bool, count: Int) {
        let (char, fwd, till) = lastFindChar
        guard !char.isEmpty else { return }
        findChar(tv, char: char, forward: reverse ? !fwd : fwd, till: till, count: count)
    }

    private func scroll(_ tv: NSTextView, lines: CGFloat, down: Bool) {
        let lh = lineHeight(tv)
        let delta = lh * lines * (down ? 1 : -1)
        let origin = NSPoint(x: tv.visibleRect.origin.x, y: tv.visibleRect.origin.y + delta)
        tv.scroll(origin)
    }

    // MARK: - Range helpers for operators

    private func wordRange(_ tv: NSTextView, count: Int, bigWord: Bool) -> NSRange {
        let start = cursorPos(tv)
        moveWords(tv, count: count, forward: true, bigWord: bigWord, toEnd: false)
        let end = cursorPos(tv)
        tv.setSelectedRange(NSRange(location: start, length: 0))
        return NSRange(location: start, length: max(0, end - start))
    }

    private func wordRangeBack(_ tv: NSTextView, count: Int, bigWord: Bool) -> NSRange {
        let end = cursorPos(tv)
        moveWords(tv, count: count, forward: false, bigWord: bigWord, toEnd: false)
        let start = cursorPos(tv)
        tv.setSelectedRange(NSRange(location: start, length: 0))
        return NSRange(location: start, length: max(0, end - start))
    }

    private func wordEndRange(_ tv: NSTextView, count: Int, bigWord: Bool) -> NSRange {
        let start = cursorPos(tv)
        moveWords(tv, count: count, forward: true, bigWord: bigWord, toEnd: true)
        let end = cursorPos(tv) + 1
        tv.setSelectedRange(NSRange(location: start, length: 0))
        return NSRange(location: start, length: max(0, end - start))
    }

    private func rangeToLineStart(_ tv: NSTextView, firstNonBlank: Bool) -> NSRange {
        let pos = cursorPos(tv)
        let start = lineStart(tv, at: pos)
        if firstNonBlank {
            let ns = tv.string as NSString
            let end = lineEnd(tv, at: pos)
            var p = start
            while p <= end && (ns.character(at: p) == 32 || ns.character(at: p) == 9) { p += 1 }
            return NSRange(location: min(p, end), length: max(0, pos - min(p, end)))
        }
        return NSRange(location: start, length: max(0, pos - start))
    }

    private func rangeToLineEnd(_ tv: NSTextView) -> NSRange {
        let pos = cursorPos(tv)
        let end = lineEnd(tv, at: pos)
        return NSRange(location: pos, length: max(0, end - pos + 1))
    }

    private func rangeLines(_ tv: NSTextView, count: Int, includeCurrent: Bool) -> NSRange {
        let pos = cursorPos(tv)
        let curLine = lineStart(tv, at: pos)
        if count > 0 {
            var end = lineEnd(tv, at: pos)
            var remaining = count - 1
            while remaining > 0 && end < tv.string.utf16.count - 1 {
                end = lineEnd(tv, at: end + 1)
                remaining -= 1
            }
            return NSRange(location: curLine, length: end - curLine + 1)
        } else {
            var start = curLine
            var remaining = -count - 1
            while remaining > 0 && start > 0 {
                start = lineStart(tv, at: start - 1)
                remaining -= 1
            }
            let endLine = lineEnd(tv, at: pos)
            return NSRange(location: start, length: endLine - start + 1)
        }
    }

    private func rangeOverParagraph(_ tv: NSTextView, forward: Bool, count: Int) -> NSRange {
        let start = cursorPos(tv)
        moveParagraph(tv, forward: forward, count: count)
        let end = cursorPos(tv)
        tv.setSelectedRange(NSRange(location: start, length: 0))
        let lo = min(start, end), hi = max(start, end)
        return NSRange(location: lo, length: hi - lo)
    }

    // MARK: - Text objects

    private func textObjectRange(_ tv: NSTextView, char: String, inner: Bool) -> NSRange? {
        let pos = cursorPos(tv)
        let ns = tv.string as NSString
        let len = ns.length
        switch char {
        case "w", "W":
            let bigWord = char == "W"
            // find start of word
            var start = pos
            while start > 0 && isWordChar(ns.character(at: start - 1), bigWord: bigWord) { start -= 1 }
            var end = pos
            while end < len && isWordChar(ns.character(at: end), bigWord: bigWord) { end += 1 }
            if !inner {
                // aw: include trailing whitespace
                while end < len && (ns.character(at: end) == 32 || ns.character(at: end) == 9) { end += 1 }
            }
            return NSRange(location: start, length: max(0, end - start))
        case "\"", "'", "`":
            return quoteRange(ns, pos: pos, quote: (char as NSString).character(at: 0), inner: inner)
        case "(", ")", "b":
            return bracketRange(ns, pos: pos, open: 40, close: 41, inner: inner)   // ( )
        case "[", "]":
            return bracketRange(ns, pos: pos, open: 91, close: 93, inner: inner)   // [ ]
        case "{", "}", "B":
            return bracketRange(ns, pos: pos, open: 123, close: 125, inner: inner) // { }
        case "<", ">":
            return bracketRange(ns, pos: pos, open: 60, close: 62, inner: inner)   // < >
        case "p":
            // paragraph
            var start = pos
            while start > 0 && ns.character(at: start - 1) != 10 { start -= 1 }
            // skip backward past empty lines for 'ap'
            if !inner {
                while start > 1 && ns.character(at: start - 1) == 10 && ns.character(at: start - 2) == 10 { start -= 1 }
            }
            var end = pos
            while end < len && ns.character(at: end) != 10 { end += 1 }
            if !inner { while end < len && ns.character(at: end) == 10 { end += 1 } }
            return NSRange(location: start, length: max(0, end - start))
        case "s":
            // sentence: up to . ? ! followed by space/newline
            var start = pos
            while start > 0 {
                let c = ns.character(at: start - 1)
                if c == 46 || c == 63 || c == 33 { break }  // . ? !
                start -= 1
            }
            var end = pos
            while end < len {
                let c = ns.character(at: end)
                if (c == 46 || c == 63 || c == 33) && end + 1 < len { end += 1; break }
                end += 1
            }
            if !inner { while end < len && (ns.character(at: end) == 32 || ns.character(at: end) == 10) { end += 1 } }
            return NSRange(location: start, length: max(0, end - start))
        default: return nil
        }
    }

    private func quoteRange(_ ns: NSString, pos: Int, quote: unichar, inner: Bool) -> NSRange? {
        let len = ns.length
        var lo = pos - 1
        while lo >= 0 && ns.character(at: lo) != quote { lo -= 1 }
        guard lo >= 0 else { return nil }
        var hi = pos
        while hi < len && ns.character(at: hi) != quote { hi += 1 }
        guard hi < len else { return nil }
        if inner { return NSRange(location: lo + 1, length: max(0, hi - lo - 1)) }
        return NSRange(location: lo, length: max(0, hi - lo + 1))
    }

    private func bracketRange(_ ns: NSString, pos: Int, open: unichar, close: unichar, inner: Bool) -> NSRange? {
        let len = ns.length
        // find enclosing open bracket scanning left
        var depth = 0, lo = pos
        while lo >= 0 {
            let c = ns.character(at: lo)
            if c == close { depth += 1 }
            else if c == open {
                if depth == 0 { break }
                depth -= 1
            }
            lo -= 1
        }
        guard lo >= 0 else { return nil }
        depth = 0
        var hi = lo + 1
        while hi < len {
            let c = ns.character(at: hi)
            if c == open { depth += 1 }
            else if c == close {
                if depth == 0 { break }
                depth -= 1
            }
            hi += 1
        }
        guard hi < len else { return nil }
        if inner { return NSRange(location: lo + 1, length: max(0, hi - lo - 1)) }
        return NSRange(location: lo, length: max(0, hi - lo + 1))
    }

    // MARK: - Edit operations

    private func deleteRange(_ tv: NSTextView, range: NSRange) {
        let clamped = NSRange(location: range.location,
                              length: min(range.length, tv.string.utf16.count - range.location))
        guard clamped.length > 0 else { return }
        tv.isEditable = true
        tv.replaceCharacters(in: clamped, with: "")
        tv.isEditable = (mode == .insert)
        tv.setSelectedRange(NSRange(location: min(clamped.location, tv.string.utf16.count), length: 0))
    }

    private func deleteChar(_ tv: NSTextView, forward: Bool, count: Int) {
        let pos = cursorPos(tv)
        let len = tv.string.utf16.count
        if forward {
            let end = min(pos + count, len)
            register = (tv.string as NSString).substring(with: NSRange(location: pos, length: end - pos))
            deleteRange(tv, range: NSRange(location: pos, length: end - pos))
        } else {
            let start = max(0, pos - count)
            register = (tv.string as NSString).substring(with: NSRange(location: start, length: pos - start))
            deleteRange(tv, range: NSRange(location: start, length: pos - start))
        }
    }

    private func deleteLine(_ tv: NSTextView, count: Int) {
        let pos = cursorPos(tv)
        let start = lineStart(tv, at: pos)
        var end = lineEnd(tv, at: pos)
        for _ in 1..<count {
            if end + 1 < tv.string.utf16.count { end = lineEnd(tv, at: end + 1) }
        }
        // include trailing newline
        let includeNewline = end + 1 <= tv.string.utf16.count
        let len = includeNewline ? end - start + 2 : end - start + 1
        let range = NSRange(location: start, length: min(len, tv.string.utf16.count - start))
        register = (tv.string as NSString).substring(with: range)
        registerIsLine = true
        deleteRange(tv, range: range)
    }

    private func yankLines(_ tv: NSTextView, count: Int) {
        let pos = cursorPos(tv)
        let start = lineStart(tv, at: pos)
        var end = lineEnd(tv, at: pos)
        for _ in 1..<count {
            if end + 1 < tv.string.utf16.count { end = lineEnd(tv, at: end + 1) }
        }
        let len = min(end - start + 2, tv.string.utf16.count - start)
        register = (tv.string as NSString).substring(with: NSRange(location: start, length: len))
        registerIsLine = true
    }

    private func deleteToEndOfLine(_ tv: NSTextView) {
        let pos = cursorPos(tv)
        let end = lineEnd(tv, at: pos)
        register = (tv.string as NSString).substring(with: NSRange(location: pos, length: max(0, end - pos + 1)))
        deleteRange(tv, range: NSRange(location: pos, length: max(0, end - pos + 1)))
    }

    private func changeToEndOfLine(_ tv: NSTextView) {
        deleteToEndOfLine(tv)
        enter(mode: .insert)
    }

    private func paste(_ tv: NSTextView, before: Bool, count: Int) {
        guard !register.isEmpty else { return }
        let pos = cursorPos(tv)
        let text = String(repeating: register, count: count)
        tv.isEditable = true
        if registerIsLine {
            let insertPos = before ? lineStart(tv, at: pos) : (lineEnd(tv, at: pos) + 1)
            let clamped = min(insertPos, tv.string.utf16.count)
            let insertText = text.hasSuffix("\n") ? text : text + "\n"
            tv.replaceCharacters(in: NSRange(location: clamped, length: 0), with: insertText)
            tv.setSelectedRange(NSRange(location: clamped, length: 0))
        } else {
            let insertPos = before ? pos : min(pos + 1, tv.string.utf16.count)
            tv.replaceCharacters(in: NSRange(location: insertPos, length: 0), with: text)
            tv.setSelectedRange(NSRange(location: insertPos + text.utf16.count - 1, length: 0))
        }
        tv.isEditable = false
    }

    private func replaceChar(_ tv: NSTextView, with char: String, count: Int) {
        let pos = cursorPos(tv)
        let len = tv.string.utf16.count
        let replaceLen = min(count, len - pos)
        guard replaceLen > 0 else { return }
        tv.isEditable = true
        tv.replaceCharacters(in: NSRange(location: pos, length: replaceLen), with: String(repeating: char, count: replaceLen))
        tv.isEditable = false
        tv.setSelectedRange(NSRange(location: pos + replaceLen - 1, length: 0))
        let cap = char; let c = replaceLen
        lastEdit = { [weak self] in self?.replaceChar(tv, with: cap, count: c) }
    }

    private func toggleCase(_ tv: NSTextView, count: Int) {
        let pos = cursorPos(tv)
        let len = tv.string.utf16.count
        let end = min(pos + count, len)
        let range = NSRange(location: pos, length: end - pos)
        let text = (tv.string as NSString).substring(with: range)
        let toggled = String(text.map { c in c.isUppercase ? Character(c.lowercased()) : Character(c.uppercased()) })
        tv.isEditable = true
        tv.replaceCharacters(in: range, with: toggled)
        tv.isEditable = false
        tv.setSelectedRange(NSRange(location: end, length: 0))
    }

    private func toggleCaseLine(_ tv: NSTextView) {
        let pos = cursorPos(tv)
        let range = NSRange(location: lineStart(tv, at: pos), length: lineEnd(tv, at: pos) - lineStart(tv, at: pos))
        toggleCaseRange(tv, range: range)
    }

    private func toggleCaseRange(_ tv: NSTextView, range: NSRange) {
        let text = (tv.string as NSString).substring(with: range)
        let toggled = String(text.map { c in c.isUppercase ? Character(c.lowercased()) : Character(c.uppercased()) })
        tv.isEditable = true
        tv.replaceCharacters(in: range, with: toggled)
        tv.isEditable = false
    }

    private func lowercaseLine(_ tv: NSTextView) {
        let pos = cursorPos(tv)
        let start = lineStart(tv, at: pos); let end = lineEnd(tv, at: pos)
        lowercaseRange(tv, range: NSRange(location: start, length: end - start))
    }

    private func uppercaseLine(_ tv: NSTextView) {
        let pos = cursorPos(tv)
        let start = lineStart(tv, at: pos); let end = lineEnd(tv, at: pos)
        uppercaseRange(tv, range: NSRange(location: start, length: end - start))
    }

    private func lowercaseRange(_ tv: NSTextView, range: NSRange) {
        let text = (tv.string as NSString).substring(with: range).lowercased()
        tv.isEditable = true; tv.replaceCharacters(in: range, with: text); tv.isEditable = false
    }

    private func uppercaseRange(_ tv: NSTextView, range: NSRange) {
        let text = (tv.string as NSString).substring(with: range).uppercased()
        tv.isEditable = true; tv.replaceCharacters(in: range, with: text); tv.isEditable = false
    }

    private func joinLines(_ tv: NSTextView, count: Int) {
        let pos = cursorPos(tv)
        var end = pos
        for _ in 0..<count {
            let lineE = lineEnd(tv, at: end)
            if lineE + 1 < tv.string.utf16.count { end = lineE + 1 }
        }
        let range = NSRange(location: lineStart(tv, at: pos), length: lineEnd(tv, at: end) - lineStart(tv, at: pos))
        let text = (tv.string as NSString).substring(with: range)
        let joined = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        tv.isEditable = true
        tv.replaceCharacters(in: range, with: joined)
        tv.isEditable = false
    }

    private func openLineBelow(_ tv: NSTextView) {
        let pos = cursorPos(tv)
        let end = lineEnd(tv, at: pos)
        let insertPos = min(end + 1, tv.string.utf16.count)
        tv.isEditable = true
        tv.replaceCharacters(in: NSRange(location: insertPos, length: 0), with: "\n")
        tv.setSelectedRange(NSRange(location: insertPos + 1, length: 0))
    }

    private func openLineAbove(_ tv: NSTextView) {
        let pos = cursorPos(tv)
        let start = lineStart(tv, at: pos)
        tv.isEditable = true
        tv.replaceCharacters(in: NSRange(location: start, length: 0), with: "\n")
        tv.setSelectedRange(NSRange(location: start, length: 0))
    }

    private func indentLines(_ tv: NSTextView, count: Int, indent: Bool) {
        let pos = cursorPos(tv)
        let range = rangeLines(tv, count: count, includeCurrent: true)
        indentRange(tv, range: range, indent: indent)
        tv.setSelectedRange(NSRange(location: pos, length: 0))
    }

    private func indentRange(_ tv: NSTextView, range: NSRange, indent: Bool) {
        let ns = tv.string as NSString
        let text = ns.substring(with: range)
        let indented = text.components(separatedBy: "\n").map { line in
            indent ? "    " + line : String(line.drop(while: { $0 == " " || $0 == "\t" }).prefix(999999))
        }.joined(separator: "\n")
        tv.isEditable = true
        tv.replaceCharacters(in: range, with: indented)
        tv.isEditable = false
    }

    private func clampCursorOffEOL(_ tv: NSTextView) {
        let pos = cursorPos(tv)
        let end = lineEnd(tv, at: pos)
        let start = lineStart(tv, at: pos)
        if pos > end && end >= start {
            tv.setSelectedRange(NSRange(location: end, length: 0))
        }
    }

    // MARK: - Search

    private func beginSearch(_ tv: NSTextView, forward: Bool) {
        // Use NSTextView's built-in find panel
        tv.performFindPanelAction(NSTextFinder.Action.showFindInterface)
        lastSearch.forward = forward
    }

    private func repeatSearch(_ tv: NSTextView, reverse: Bool, count: Int) {
        let fwd = reverse ? !lastSearch.forward : lastSearch.forward
        for _ in 0..<count {
            if fwd {
                tv.performFindPanelAction(NSTextFinder.Action.nextMatch)
            } else {
                tv.performFindPanelAction(NSTextFinder.Action.previousMatch)
            }
        }
    }

    private func searchWordUnderCursor(_ tv: NSTextView, forward: Bool) {
        let pos = cursorPos(tv)
        let ns = tv.string as NSString
        var start = pos, end = pos
        while start > 0 && isWordChar(ns.character(at: start - 1), bigWord: false) { start -= 1 }
        while end < ns.length && isWordChar(ns.character(at: end), bigWord: false) { end += 1 }
        let word = ns.substring(with: NSRange(location: start, length: end - start))
        lastSearch = (word, forward)
        onSearchHighlight?(word)
        repeatSearch(tv, reverse: false, count: 1)
    }

    private func openPathUnderCursor(_ tv: NSTextView) {
        guard let raw = pathTokenUnderCursor(tv) else {
            displayExMessage("gf: no path under cursor")
            return
        }
        onOpenFile?(Self.stripLineColumnSuffix(raw))
    }

    private func goToDefinition(_ tv: NSTextView) {
        let position = lspPosition(tv)
        Task { [weak self] in
            guard let self else { return }
            if let target = await self.onDefinition?(position) {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.pushJumpPublic(self.cursorPos(tv))
                    self.onNavigateToDefinition?(target)
                }
                return
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let raw = self.pathTokenUnderCursor(tv) {
                    self.onOpenFile?(Self.stripLineColumnSuffix(raw))
                } else {
                    self.displayExMessage("gd: no definition")
                }
            }
        }
    }

    private func showHover(_ tv: NSTextView) {
        let position = lspPosition(tv)
        Task { [weak self] in
            guard let self else { return }
            let text = await self.onHover?(position)
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard let text, !text.isEmpty else {
                    self.displayExMessage("K: no hover")
                    return
                }
                self.displayExMessage(text)
            }
        }
    }

    private func jumpDiagnostic(_ tv: NSTextView, forward: Bool) {
        let diagnostics = onDiagnostics?() ?? []
        let currentLine = lspPosition(tv).line
        guard let index = ViDiagnosticNavigator.targetIndex(currentLine: currentLine, diagnostics: diagnostics, forward: forward) else {
            displayExMessage("no diagnostics")
            return
        }
        let diagnostic = diagnostics[index]
        moveToLSPPosition(tv, diagnostic.range.start)
        displayExMessage(diagnostic.message.isEmpty ? "diagnostic" : diagnostic.message)
    }

    private func moveToLSPPosition(_ tv: NSTextView, _ position: LSPPosition) {
        let ns = tv.string as NSString
        let lineStart = offset(line: position.line, character: 0, in: ns)
        guard lineStart != NSNotFound else { return }
        let target = min(lineEnd(tv, at: lineStart), lineStart + max(0, position.character))
        tv.setSelectedRange(NSRange(location: target, length: 0))
        tv.scrollRangeToVisible(NSRange(location: target, length: 0))
    }

    private func lspPosition(_ tv: NSTextView) -> LSPPosition {
        let ns = tv.string as NSString
        let offset = min(cursorPos(tv), ns.length)
        var line = 0
        var lineStart = 0
        ns.enumerateSubstrings(
            in: NSRange(location: 0, length: offset),
            options: [.byLines, .substringNotRequired]
        ) { _, range, _, _ in
            line += 1
            lineStart = NSMaxRange(range)
        }
        return LSPPosition(line: max(0, line), character: max(0, offset - lineStart))
    }

    private func offset(line: Int, character: Int, in text: NSString) -> Int {
        var currentLine = 0
        var result = NSNotFound
        text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: [.byLines, .substringNotRequired]) { _, range, _, stop in
            if currentLine == line {
                result = min(range.location + max(0, character), NSMaxRange(range))
                stop.pointee = true
            }
            currentLine += 1
        }
        if result == NSNotFound, line == currentLine {
            result = text.length
        }
        return result
    }

    private func pathTokenUnderCursor(_ tv: NSTextView) -> String? {
        let ns = tv.string as NSString
        guard ns.length > 0 else { return nil }
        let pos = min(cursorPos(tv), max(0, ns.length - 1))
        var start = pos
        var end = pos
        while start > 0 && Self.isPathTokenChar(ns.character(at: start - 1)) { start -= 1 }
        while end < ns.length && Self.isPathTokenChar(ns.character(at: end)) { end += 1 }
        let token = ns.substring(with: NSRange(location: start, length: end - start))
            .trimmingCharacters(in: CharacterSet(charactersIn: "'\"`()[]{}<>"))
        return token.contains("/") || token.contains(".") || token.hasPrefix("~") ? token : nil
    }

    private static func isPathTokenChar(_ c: unichar) -> Bool {
        guard let scalar = UnicodeScalar(c) else { return false }
        if CharacterSet.alphanumerics.contains(scalar) { return true }
        return "/._-~:@+".unicodeScalars.contains(scalar)
    }

    private static func stripLineColumnSuffix(_ token: String) -> String {
        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 2, let last = parts.last, Int(last) != nil else { return token }
        if parts.count >= 3, Int(parts[parts.count - 2]) != nil {
            return parts.dropLast(2).joined(separator: ":")
        }
        return parts.dropLast().joined(separator: ":")
    }

    // MARK: - Screen position motions (H/M/L)

    enum ScreenPos { case top, middle, bottom }

    private func moveScreenPosition(_ tv: NSTextView, pos: ScreenPos) {
        guard let lm = tv.layoutManager, let tc = tv.textContainer else { return }
        let visRect = tv.visibleRect
        let targetY: CGFloat
        switch pos {
        case .top:    targetY = visRect.minY + 1
        case .middle: targetY = visRect.midY
        case .bottom: targetY = visRect.maxY - 1
        }
        let glyphIdx = lm.glyphIndex(for: NSPoint(x: visRect.minX + 1, y: targetY), in: tc)
        let charIdx = lm.characterIndexForGlyph(at: glyphIdx)
        let ns = tv.string as NSString
        let lineStart = lineStart(tv, at: charIdx)
        var lineEnd = lineStart
        while lineEnd < ns.length && ns.character(at: lineEnd) != 10 { lineEnd += 1 }
        var firstNonBlank = lineStart
        while firstNonBlank < lineEnd && (ns.character(at: firstNonBlank) == 32 || ns.character(at: firstNonBlank) == 9) { firstNonBlank += 1 }
        tv.setSelectedRange(NSRange(location: firstNonBlank, length: 0))
    }

    // MARK: - Named register helpers

    private func yankToRegister(_ text: String, isLine: Bool) {
        if let reg = activeRegister {
            namedRegisters[reg] = (text, isLine)
            activeRegister = nil
        } else {
            register = text
            registerIsLine = isLine
        }
    }

    private func pasteRegister() -> (text: String, isLine: Bool) {
        if let reg = activeRegister, let entry = namedRegisters[reg] {
            activeRegister = nil
            return entry
        }
        return (register, registerIsLine)
    }

    // MARK: - Ex command prompt

    private weak var exPanel: NSPanel?
    private weak var exField: NSTextField?

    private func presentExPrompt(_ tv: NSTextView) {
        guard let win = tv.window else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: win.frame.width, height: 28),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = NSColor(white: 0.12, alpha: 0.97)
        panel.isOpaque = false

        let field = NSTextField(frame: NSRect(x: 24, y: 4, width: win.frame.width - 32, height: 20))
        field.isBordered = false
        field.drawsBackground = false
        field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        field.textColor = .white
        field.placeholderString = ""
        let colon = NSTextField(labelWithString: ":")
        colon.frame = NSRect(x: 4, y: 4, width: 18, height: 20)
        colon.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        colon.textColor = .white

        panel.contentView?.addSubview(colon)
        panel.contentView?.addSubview(field)

        let winFrame = win.frame
        panel.setFrame(NSRect(x: winFrame.minX, y: winFrame.minY, width: winFrame.width, height: 28), display: false)
        win.addChildWindow(panel, ordered: .above)
        panel.makeFirstResponder(field)
        exPanel = panel
        exField = field

        // Monitor Enter and Esc
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel, weak field] event in
            guard let panel else { return event }
            switch event.keyCode {
            case 36, 76: // Return / Enter
                let cmd = field?.stringValue ?? ""
                panel.orderOut(nil)
                panel.parent?.removeChildWindow(panel)
                self?.execEx(cmd, tv: tv)
                return nil
            case 53: // Esc
                panel.orderOut(nil)
                panel.parent?.removeChildWindow(panel)
                return nil
            default:
                return event
            }
        }
    }

    private func execEx(_ raw: String, tv: NSTextView) {
        let cmd = raw.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }

        // :N  go to line number
        if let n = Int(cmd), n > 0 {
            moveToLine(tv, line: n)
            return
        }

        switch cmd {
        case "w":
            onSave?()
        case "q":
            onQuit?()
        case "wq", "x":
            onSave?(); onQuit?()
        case "wq!", "x!":
            onSave?(); onQuit?()
        case "q!":
            onQuit?()
        case "bn", "bnext":
            onNextBuffer?(1)
        case "bp", "bprev", "bprevious":
            onNextBuffer?(-1)
        case "ls", "buffers", "files":
            let list = onListBuffers?() ?? []
            let text = list.isEmpty ? "no open buffers" : list.enumerated().map { "\($0.offset + 1): \($0.element)" }.joined(separator: "\n")
            // Display via NSAlert-style toast or reuse the ex panel label
            displayExMessage(text)
            return
        case "noh", "nohlsearch":
            tv.performFindPanelAction(NSTextFinder.Action.hideFindInterface)
            onSearchHighlight?("")  // clear inline highlights
        default:
            // :set option  — notify host to apply setting
            if cmd.hasPrefix("set ") || cmd == "set" {
                execSet(String(cmd.dropFirst(4)).trimmingCharacters(in: .whitespaces), tv: tv)
                return
            }
            // :e/:edit file  — notify host to open file
            if cmd.hasPrefix("e ") || cmd.hasPrefix("edit ") {
                let dropCount = cmd.hasPrefix("edit ") ? 5 : 2
                let path = String(cmd.dropFirst(dropCount)).trimmingCharacters(in: .whitespaces)
                onOpenFile?(path)
                return
            }
            if cmd.hasPrefix("view ") {
                let path = String(cmd.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                NotificationCenter.default.post(name: .viViewFileCommand, object: self, userInfo: ["path": path])
                return
            }
            if cmd.hasPrefix("find ") {
                let query = String(cmd.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                NotificationCenter.default.post(name: .viFindFileCommand, object: self, userInfo: ["query": query])
                return
            }
            if cmd.hasPrefix("split ") || cmd.hasPrefix("sp ") || cmd.hasPrefix("vsplit ") || cmd.hasPrefix("vsp ") {
                let isVertical = cmd.hasPrefix("vsplit ") || cmd.hasPrefix("vsp ")
                let dropCount = cmd.hasPrefix("vsplit ") ? 7 : (cmd.hasPrefix("split ") ? 6 : 3)
                let path = String(cmd.dropFirst(dropCount)).trimmingCharacters(in: .whitespaces)
                NotificationCenter.default.post(
                    name: .viSplitFileCommand,
                    object: self,
                    userInfo: ["path": path, "direction": isVertical ? "vertical" : "horizontal"]
                )
                return
            }
            // :s/old/new/flags  or  :%s/old/new/flags
            if cmd.hasPrefix("%s/") || cmd.hasPrefix("s/") {
                execSubstitute(cmd, tv: tv)
            } else if cmd.hasPrefix("s") {
                execSubstitute(cmd, tv: tv)
            }
        }
    }

    /// Handles :s/old/new/[g]  and :%s/old/new/[g]
    private func displayExMessage(_ text: String) {
        guard let tv = textView, let win = tv.window else { return }
        // Reuse the ex panel style — show briefly then auto-dismiss
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: win.frame.width, height: CGFloat(22 + text.components(separatedBy: "\n").count * 18)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true; panel.level = .floating
        panel.backgroundColor = NSColor(white: 0.12, alpha: 0.95)
        let label = NSTextField(wrappingLabelWithString: text)
        label.frame = NSRect(x: 8, y: 4, width: win.frame.width - 16, height: panel.frame.height - 8)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .white
        panel.contentView?.addSubview(label)
        let wf = win.frame
        panel.setFrame(NSRect(x: wf.minX, y: wf.minY, width: wf.width, height: panel.frame.height), display: false)
        win.addChildWindow(panel, ordered: .above)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            panel.orderOut(nil); panel.parent?.removeChildWindow(panel)
        }
    }

    private func execSet(_ setting: String, tv: NSTextView) {        // Handle boolean toggles and key=value pairs
        switch setting {
        case "number", "nu":         onSetOption?("number", "true")
        case "nonumber", "nonu":     onSetOption?("number", "false")
        case "relativenumber", "rnu": onSetOption?("relativenumber", "true")
        case "norelativenumber", "nornu": onSetOption?("relativenumber", "false")
        case "hlsearch", "hls":      onSetOption?("hlsearch", "true")
        case "nohlsearch", "nohls":
            onSetOption?("hlsearch", "false")
            tv.performFindPanelAction(NSTextFinder.Action.hideFindInterface)
        case "ignorecase", "ic":     onSetOption?("ignorecase", "true")
        case "noignorecase", "noic": onSetOption?("ignorecase", "false")
        case "wrap":                 onSetOption?("wrap", "true")
        case "nowrap":               onSetOption?("wrap", "false")
        default:
            if setting.contains("=") {
                let parts = setting.components(separatedBy: "=")
                if parts.count == 2 { onSetOption?(parts[0], parts[1]) }
            }
        }
    }

    private func execSubstitute(_ cmd: String, tv: NSTextView) {
        let global = cmd.hasPrefix("%")
        let body = global ? String(cmd.dropFirst()) : cmd          // strip %
        // parse  s/old/new/flags
        guard body.hasPrefix("s") else { return }
        let rest = String(body.dropFirst())                         // /old/new/flags
        guard rest.hasPrefix("/") else { return }
        let parts = rest.dropFirst().components(separatedBy: "/")  // ["old","new","flags"]
        guard parts.count >= 2 else { return }
        let pattern = parts[0], replacement = parts[1]
        let flags = parts.count > 2 ? parts[2] : ""
        let replaceAll = flags.contains("g") || global
        let ns = tv.string as NSString
        tv.isEditable = true
        if global || replaceAll {
            let replaced = ns.replacingOccurrences(of: pattern, with: replacement,
                options: .literal, range: NSRange(location: 0, length: ns.length))
            tv.replaceCharacters(in: NSRange(location: 0, length: ns.length), with: replaced)
        } else {
            // current line only, first occurrence
            let pos = cursorPos(tv)
            let lineR = NSRange(location: lineStart(tv, at: pos), length: lineEnd(tv, at: pos) - lineStart(tv, at: pos))
            let lineText = ns.substring(with: lineR)
            let replaced = (lineText as NSString).replacingOccurrences(of: pattern, with: replacement,
                options: .literal, range: NSRange(location: 0, length: (lineText as NSString).length))
            tv.replaceCharacters(in: lineR, with: replaced)
        }
        tv.isEditable = false
    }
}
