import AppKit
import HarnessCopyMode
import HarnessCore
import HarnessTerminalEngine
import HarnessTerminalRenderer
import HarnessTheme
import Metal
import QuartzCore

extension HarnessTerminalSurfaceView {
    // MARK: - IME preedit

    /// Draw the marked (composing) text over the grid starting at the cursor, and park the
    /// cursor at its end. Combining marks (Thai vowels/tones, accents) are folded onto the base
    /// cell — never given their own column — so composing Thai through the IME renders the same as
    /// committed text, instead of dropping vowels / exploding tone marks.
    func overlayPreedit(into frame: inout TerminalFrame) {
        Self.applyPreedit(into: &frame, text: markedText, builder: frameBuilder,
                          canvasForeground: canvasForeground, canvasBackground: canvasBackground)
    }

    /// Per-row fingerprint of the cell-overlay pass (selection + find shading + IME preedit):
    /// what the pass paints on each row, hashed from the overlay GEOMETRY (no cell walks). Two
    /// builds whose fingerprints agree for a row shaded it identically, so the rows whose
    /// fingerprint changed — plus rows that left the overlay — are exactly the extra render
    /// damage the pass needs. A selection drag therefore re-encodes the rows it crossed, not
    /// the grid. Keys exist only for rows the overlay touches now.
    nonisolated static func overlayRowKeys(
        selection: SelectionRegion?,
        findHits: [TerminalSelection],
        preedit: String,
        preeditCursor: (row: Int, column: Int),
        rows: Int, cols: Int
    ) -> [Int: UInt64] {
        var keys: [Int: UInt64] = [:]
        func fold(_ row: Int, _ value: UInt64) {
            guard row >= 0, row < rows else { return }
            let h = keys[row] ?? 0xCBF2_9CE4_8422_2325 // FNV-64 offset basis
            keys[row] = (h ^ value) &* 0x0000_0100_0000_01B3
        }
        // Column extents pack into one word; the tag keeps a selection span from ever colliding
        // with an identical find span (they shade with different colors).
        func pack(_ a: Int, _ b: Int, _ tag: UInt64) -> UInt64 {
            (UInt64(UInt32(bitPattern: Int32(a))) << 34)
                ^ (UInt64(UInt32(bitPattern: Int32(b))) << 3) ^ tag
        }
        switch selection {
        case let .linear(s):
            if s.endRow >= 0, s.startRow < rows {
                for row in max(0, s.startRow) ... min(rows - 1, s.endRow) {
                    let a = row == s.startRow ? s.startColumn : 0
                    let b = row == s.endRow ? s.endColumn : cols - 1
                    fold(row, pack(a, b, 1))
                }
            }
        case let .block(b):
            if b.endRow >= 0, b.startRow < rows {
                for row in max(0, b.startRow) ... min(rows - 1, b.endRow) {
                    fold(row, pack(b.startColumn, b.endColumn, 2))
                }
            }
        case nil:
            break
        }
        for hit in findHits where hit.endRow >= 0 && hit.startRow < rows {
            for row in max(0, hit.startRow) ... min(rows - 1, hit.endRow) {
                let a = row == hit.startRow ? hit.startColumn : 0
                let b = row == hit.endRow ? hit.endColumn : cols - 1
                fold(row, pack(a, b, 3))
            }
        }
        if !preedit.isEmpty {
            var h: UInt64 = 0xCBF2_9CE4_8422_2325
            for byte in preedit.utf8 { h = (h ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
            fold(preeditCursor.row, h ^ pack(preeditCursor.column, 0, 4))
        }
        return keys
    }

    nonisolated static func applyPreedit(
        into frame: inout TerminalFrame,
        text: String,
        builder: FrameBuilder,
        canvasForeground: RGBColor,
        canvasBackground: RGBColor
    ) {
        let row = frame.cursor.row
        guard row >= 0, row < frame.rows else { return }
        var col = frame.cursor.column
        let fg = builder.renderColor(canvasForeground)
        let bg = builder.renderColor(canvasBackground)
        var lastBaseIdx: Int? = nil
        for scalar in text.unicodeScalars {
            // Zero-width scalar: fold a TRUE combining mark onto the preceding preedit base cell
            // (mirrors the engine's attachCombining); drop a non-extending format scalar (ZWSP, BOM,
            // bidi) so the cell's cluster stays one grapheme. Never advances the column.
            if CharacterWidth.width(of: scalar) == 0 {
                if scalar.properties.isGraphemeExtend, let bi = lastBaseIdx {
                    if frame.cells[bi].combining0 == 0 { frame.cells[bi].combining0 = scalar.value }
                    else if frame.cells[bi].combining1 == 0 { frame.cells[bi].combining1 = scalar.value }
                }
                continue
            }
            let width = max(1, CharacterWidth.width(of: scalar))
            guard col >= 0, col + width <= frame.columns else { break }
            let idx = row * frame.columns + col
            guard idx >= 0, idx < frame.cells.count else { break }
            frame.cells[idx].codepoint = scalar.value
            frame.cells[idx].combining0 = 0
            frame.cells[idx].combining1 = 0
            frame.cells[idx].foreground = fg
            frame.cells[idx].underline = .single
            frame.cells[idx].width = (width == 2) ? .wide : .normal
            // Preedit sits on the *canvas* background: reset the background to it and clear
            // `drawBackground` (canvas cells draw no quad, so window translucency is preserved).
            // Without this the cell kept whatever the overlay pass painted — composing over a
            // selection or find hit rendered the preedit indistinguishable from highlighted text.
            frame.cells[idx].background = bg
            frame.cells[idx].drawBackground = false
            // Mark the trailing cell of a wide composing glyph as its spacer.
            if width == 2, idx + 1 < frame.cells.count {
                frame.cells[idx + 1].codepoint = 0
                frame.cells[idx + 1].width = .spacerTail
                frame.cells[idx + 1].underline = .single
                frame.cells[idx + 1].background = bg
                frame.cells[idx + 1].drawBackground = false
            }
            lastBaseIdx = idx
            col += width
        }
        frame.cursor.column = min(col, frame.columns - 1)
    }

    // MARK: - Input

    public override var acceptsFirstResponder: Bool { true }

    public override func becomeFirstResponder() -> Bool {
        focused = true
        cursorBlinkVisible = true
        focusStateChanged()
        return true
    }

    public override func resignFirstResponder() -> Bool {
        focused = false
        // A modifier released while we're unfocused never reaches `flagsChanged`, so drop the
        // press-tracking state to keep Kitty modifier-key press/release reporting in sync on return.
        pressedModifierKeyCodes.removeAll()
        focusStateChanged()
        return true
    }

    /// React to any change of the effective focus state (first responder × key window):
    /// repaint (hollow cursor) and report DECSET 1004 focus in/out to the program exactly
    /// once per transition. Programs that enabled it (vim, tmux, …) get `CSI I` on
    /// focus-in and `CSI O` on focus-out.
    func focusStateChanged() {
        let now = effectivelyFocused
        if lastReportedFocus != now {
            lastReportedFocus = now
            if now { cursorBlinkVisible = true; onBecameFocused?() }
            if inputModes().focusReporting {
                emit([0x1B, 0x5B, now ? 0x49 : 0x4F]) // ESC [ I / ESC [ O
            }
        }
        scheduleRender()
    }

    public override func keyDown(with event: NSEvent) {
        // Copy mode is modal: it consumes every key (motions, search entry, copy/cancel)
        // and nothing reaches the PTY. ⌘ shortcuts still fall through to the app.
        if copyMode != nil, !event.modifierFlags.contains(.command) {
            handleCopyModeKey(event)
            return
        }
        // Let the app handle Command shortcuts (menus, palette, etc.).
        if event.modifierFlags.contains(.command) {
            // ⌘ + an editing key drives readline line-editing (⌘ is otherwise reserved for the
            // app), matching macOS terminal convention: ⌘⌫ = delete to line start (^U), ⌘← / ⌘→ =
            // line start / end (^A / ^E). Other ⌘ keys keep falling through to the app.
            if let special = Self.specialKey(for: event) {
                let lineEdit: [UInt8]?
                switch special {
                case .backspace: lineEdit = [0x15] // ^U
                case .left: lineEdit = [0x01]      // ^A
                case .right: lineEdit = [0x05]     // ^E
                default: lineEdit = nil
                }
                if let bytes = lineEdit {
                    wakeCursor()
                    snapToBottom()
                    clearSelection()
                    emit(bytes)
                    return
                }
            }
            // ⌘C / ⌘X copy the active selection (a read-only terminal can't truly cut, so ⌘X
            // behaves as copy), ⌘V pastes. These also work via the Edit menu's key equivalents
            // (which fire copy:/cut:/paste: on the first responder before keyDown); handling them
            // here keeps copy/paste working even without the menu.
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c", "x":
                // Copy/cut the selection; with no selection, let the app handle ⌘C/⌘X.
                if currentSelectionRegion != nil { copySelection(); return }
                super.keyDown(with: event)
                return
            case "v":
                paste(nil)
                return
            default:
                super.keyDown(with: event)
                return
            }
        }
        wakeCursor()
        // While an IME composition (preedit) is active, the input method owns every key:
        // Backspace edits the preedit, arrows/Space/Tab move or pick candidates, Return
        // commits, Escape cancels. Route the whole event through the input context — updated
        // or committed text comes back via setMarkedText / insertText — rather than letting
        // the special-key path below send Backspace, Return, etc. straight to the PTY (which
        // is why the composition couldn't be edited mid-typing).
        if hasMarkedText() {
            interpretKeyEvents([event])
            return
        }
        // Shift+PageUp/PageDown page through scrollback instead of going to the app.
        if event.modifierFlags.contains(.shift), let sk = Self.specialKey(for: event),
           sk == .pageUp || sk == .pageDown {
            scrollBy(lines: sk == .pageUp ? rows : -rows)
            return
        }
        // Any other key returns to the live bottom.
        snapToBottom()
        clearSelection()

        var mods: KeyModifiers = []
        let flags = event.modifierFlags
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.control) { mods.insert(.control) }

        let modes = inputModes()
        // A held key auto-repeats; under Kitty "report event types" each repeat is tagged `:2`.
        let eventType: KeyEventType = event.isARepeat ? .repeat : .press

        if let special = Self.specialKey(for: event) {
            emit(inputEncoder.encode(special, modifiers: mods, event: eventType, modes: modes))
            return
        }

        // Control/Option — or Kitty "report all keys as escape codes" — take the encoder path:
        // Meta prefix + Control collapsing in legacy mode, full CSI-u (with alternate-key and
        // associated-text fields) under Kitty. Plain keys otherwise go through the input context so
        // dead keys and IME composition work — committed text arrives via `insertText`.
        let reportAllKeys = modes.kittyKeyboardFlags & 0b1000 != 0
        if mods.contains(.control) || mods.contains(.option) || reportAllKeys {
            let rawUnshifted = event.charactersIgnoringModifiers ?? ""
            let unshifted = ControlKeyNormalizer.normalizedKey(
                from: rawUnshifted,
                controlPressed: mods.contains(.control)
            )
            emit(inputEncoder.encode(
                text: unshifted,
                shifted: event.characters,
                modifiers: mods,
                event: eventType,
                associatedText: event.characters,
                modes: modes
            ))
            return
        }
        interpretKeyEvents([event])
    }

    public override func keyUp(with event: NSEvent) {
        // Terminals never report key release — except under the Kitty keyboard protocol's "report
        // event types" flag (0b10), which a program must explicitly enable. No-op otherwise.
        let modes = inputModes()
        guard modes.kittyKeyboardFlags & 0b10 != 0,
              copyMode == nil, !hasMarkedText(),
              !event.modifierFlags.contains(.command) else { return }

        var mods: KeyModifiers = []
        let flags = event.modifierFlags
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.control) { mods.insert(.control) }

        if let special = Self.specialKey(for: event) {
            emit(inputEncoder.encode(special, modifiers: mods, event: .release, modes: modes))
            return
        }
        // Plain (text-producing) keys only have a release event when they're reported as escape
        // codes in the first place: Ctrl/Option-modified, or under "report all keys" (0b1000).
        let modified = mods.contains(.control) || mods.contains(.option)
        guard modified || modes.kittyKeyboardFlags & 0b1000 != 0 else { return }
        let unshifted = event.charactersIgnoringModifiers ?? ""
        guard !unshifted.isEmpty else { return }
        emit(inputEncoder.encode(
            text: unshifted, shifted: event.characters, modifiers: mods,
            event: .release, associatedText: nil, modes: modes
        ))
    }

    func emit(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        onInput?(Data(bytes))
    }

    /// Map an NSEvent to a SpecialKey using the AppKit function-key unicode values.
    /// `internal` (not `private`) so the NSEvent→SpecialKey seam can be unit-tested.
    static func specialKey(for event: NSEvent) -> SpecialKey? {
        guard let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first else { return nil }
        switch Int(scalar.value) {
        case NSUpArrowFunctionKey: return .up
        case NSDownArrowFunctionKey: return .down
        case NSLeftArrowFunctionKey: return .left
        case NSRightArrowFunctionKey: return .right
        case NSHomeFunctionKey: return .home
        case NSEndFunctionKey: return .end
        case NSPageUpFunctionKey: return .pageUp
        case NSPageDownFunctionKey: return .pageDown
        case NSInsertFunctionKey: return .insert
        case NSDeleteFunctionKey: return .deleteForward
        case NSF1FunctionKey: return .f1
        case NSF2FunctionKey: return .f2
        case NSF3FunctionKey: return .f3
        case NSF4FunctionKey: return .f4
        case NSF5FunctionKey: return .f5
        case NSF6FunctionKey: return .f6
        case NSF7FunctionKey: return .f7
        case NSF8FunctionKey: return .f8
        case NSF9FunctionKey: return .f9
        case NSF10FunctionKey: return .f10
        case NSF11FunctionKey: return .f11
        case NSF12FunctionKey: return .f12
        case NSF13FunctionKey: return .f13
        case NSF14FunctionKey: return .f14
        case NSF15FunctionKey: return .f15
        case NSF16FunctionKey: return .f16
        case NSF17FunctionKey: return .f17
        case NSF18FunctionKey: return .f18
        case NSF19FunctionKey: return .f19
        case NSF20FunctionKey: return .f20
        case NSMenuFunctionKey: return .menu
        case NSPauseFunctionKey: return .pause
        case NSPrintScreenFunctionKey: return .printScreen
        case NSScrollLockFunctionKey: return .scrollLock
        case 0x0D, 0x03: return .enter        // return, enter
        case 0x7F: return .backspace          // delete (backspace) key
        case 0x1B: return .escape
        case 0x09, 0x19: return .tab  // 0x19 = NSBackTabCharacter (Shift-Tab); encoder emits ESC[Z
        default: return nil
        }
    }

}

// MARK: - NSTextInputClient (dead keys + IME)

extension HarnessTerminalSurfaceView: @preconcurrency NSTextInputClient {
    private func plainString(_ obj: Any) -> String {
        if let s = obj as? String { return s }
        if let a = obj as? NSAttributedString { return a.string }
        return ""
    }

    /// Committed text (plain typing, dead-key result, or finished IME composition).
    public func insertText(_ string: Any, replacementRange: NSRange) {
        markedText = ""
        let text = plainString(string)
        guard !text.isEmpty else { scheduleRender(); return }
        emit(inputEncoder.encode(text: text))
        scheduleRender()
    }

    /// In-progress composition shown as preedit over the grid.
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        markedText = plainString(string)
        scheduleRender()
    }

    public func unmarkText() {
        markedText = ""
        scheduleRender()
    }

    public func hasMarkedText() -> Bool { !markedText.isEmpty }

    public func markedRange() -> NSRange {
        markedText.isEmpty ? NSRange(location: NSNotFound, length: 0)
            : NSRange(location: 0, length: markedText.utf16.count)
    }

    public func selectedRange() -> NSRange { NSRange(location: 0, length: 0) }

    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    public func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }

    /// Where the IME candidate window should anchor: the cursor cell, in screen space.
    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let renderer, let window else { return .zero }
        let scale = window.backingScaleFactor
        let cellW = CGFloat(renderer.cellPixelWidth) / scale
        let cellH = CGFloat(renderer.cellPixelHeight) / scale
        let snapshot = emulatorSync { $0.readGrid() }
        let x = gridOriginPointsX + CGFloat(snapshot.cursor.col) * cellW
        // Convert grid-from-top to AppKit bottom-left origin.
        let yTop = gridOriginPointsY + CGFloat(snapshot.cursor.row) * cellH
        let viewRect = NSRect(x: x, y: bounds.height - yTop - cellH, width: cellW, height: cellH)
        let windowRect = convert(viewRect, to: nil)
        return window.convertToScreen(windowRect)
    }

    public func characterIndex(for point: NSPoint) -> Int { 0 }

    /// Keys the input system classifies as commands (e.g. Return) are already handled in
    /// `keyDown` before reaching the IME, so swallow these silently (no system beep).
    public override func doCommand(by selector: Selector) {}
}
