import AppKit
import HarnessCopyMode
import HarnessCore
import HarnessTerminalEngine
import HarnessTerminalRenderer
import HarnessTheme
import Metal
import QuartzCore

extension HarnessTerminalSurfaceView {
    // MARK: - Selection & copy

    /// Raw selection inputs, captured on the main thread WITHOUT resolving the per-granularity
    /// column expansion. The off-main render path resolves the region on the emulator queue (see
    /// `resolveSelectionRegion`) so a `.word` selection never drives `currentSelectionRegion`'s
    /// `emulatorSync` — which, off the queue, `queue.sync`s the MAIN thread behind an in-flight
    /// output feed on every build while the word selection is held (the stall the off-main pipeline
    /// exists to avoid). `Sendable` so the `@Sendable` build closure can capture it.
    struct RawSelection: Sendable {
        let anchorRow: Int, anchorColumn: Int
        let headRow: Int, headColumn: Int
        let granularity: SelectionGranularity
        let rectangular: Bool
    }

    var currentRawSelection: RawSelection? {
        guard let a = selectionAnchor, let h = selectionHead else { return nil }
        return RawSelection(anchorRow: a.row, anchorColumn: a.column,
                            headRow: h.row, headColumn: h.column,
                            granularity: selectionGranularity, rectangular: selectionRectangular)
    }

    /// Resolve a raw selection into a render region. PURE — call it ON the emulator queue (inside
    /// the build) so the `.word` expansion reads `wordColumnRange` directly instead of through a
    /// main-stalling `emulatorSync`. Mirrors `currentSelectionRegion`'s expansion exactly.
    nonisolated static func resolveSelectionRegion(_ sel: RawSelection?, emulator: TerminalEmulator,
                                                           scrollOffset: Int, columns: Int) -> SelectionRegion? {
        guard let sel else { return nil }
        if sel.rectangular {
            return .block(BlockSelection((sel.anchorRow, sel.anchorColumn), (sel.headRow, sel.headColumn)))
        }
        if sel.granularity == .character {
            return .linear(TerminalSelection((sel.anchorRow, sel.anchorColumn), (sel.headRow, sel.headColumn)))
        }
        func unitRange(row: Int, column: Int) -> ClosedRange<Int> {
            switch sel.granularity {
            case .character: return column ... column
            case .line: return 0 ... max(0, columns - 1)
            case .word:
                let virtualLine = emulator.historyCount - scrollOffset + row
                return emulator.wordColumnRange(line: virtualLine, column: column)
            }
        }
        let lo: (row: Int, column: Int), hi: (row: Int, column: Int)
        if (sel.anchorRow, sel.anchorColumn) <= (sel.headRow, sel.headColumn) {
            lo = (sel.anchorRow, sel.anchorColumn); hi = (sel.headRow, sel.headColumn)
        } else {
            lo = (sel.headRow, sel.headColumn); hi = (sel.anchorRow, sel.anchorColumn)
        }
        let loRange = unitRange(row: lo.row, column: lo.column)
        let hiRange = unitRange(row: hi.row, column: hi.column)
        if lo.row == hi.row {
            return .linear(TerminalSelection((lo.row, min(loRange.lowerBound, hiRange.lowerBound)),
                                             (lo.row, max(loRange.upperBound, hiRange.upperBound))))
        }
        return .linear(TerminalSelection((lo.row, loRange.lowerBound), (hi.row, hiRange.upperBound)))
    }

    /// The active selection region (nil when nothing is selected): rectangular for an Option-drag,
    /// else linear with the endpoints expanded by the current granularity (word / line).
    var currentSelectionRegion: SelectionRegion? {
        guard let a = selectionAnchor, let h = selectionHead else { return nil }
        if selectionRectangular { return .block(BlockSelection((a.row, a.column), (h.row, h.column))) }
        guard selectionGranularity != .character else {
            return .linear(TerminalSelection((a.row, a.column), (h.row, h.column)))
        }
        // Order the endpoints, then expand the lower one to the start of its unit and the higher
        // one to the end of its unit (unioning when both are on the same row).
        let (lo, hi) = (a.row, a.column) <= (h.row, h.column) ? (a, h) : (h, a)
        let loRange = unitColumnRange(viewportRow: lo.row, column: lo.column)
        let hiRange = unitColumnRange(viewportRow: hi.row, column: hi.column)
        if lo.row == hi.row {
            return .linear(TerminalSelection((lo.row, min(loRange.lowerBound, hiRange.lowerBound)),
                                             (lo.row, max(loRange.upperBound, hiRange.upperBound))))
        }
        return .linear(TerminalSelection((lo.row, loRange.lowerBound), (hi.row, hiRange.upperBound)))
    }

    /// Columns spanned by the current granularity at a viewport cell: the whole row for `.line`,
    /// the whitespace-delimited word for `.word` (shared with copy mode), else the single column.
    private func unitColumnRange(viewportRow row: Int, column: Int) -> ClosedRange<Int> {
        switch selectionGranularity {
        case .character: return column ... column
        // Line selection covers the DISPLAY row, consistent with copy mode's line ops.
        // Most terminals (Ghostty/iTerm2/kitty) triple-click the LOGICAL line across
        // soft wraps — that needs wrap-flag plumbing through the selection region;
        // tracked in the release-audit backlog.
        case .line: return 0 ... max(0, columns - 1)
        case .word:
            return emulatorSync { emu in
                let virtualLine = emu.historyCount - scrollOffset + row
                return emu.wordColumnRange(line: virtualLine, column: column)
            }
        }
    }

    func clearSelection() {
        selectionGranularity = .character
        selectionRectangular = false
        guard selectionAnchor != nil || selectionHead != nil else { return }
        selectionAnchor = nil
        selectionHead = nil
        scheduleRender()
    }

    /// Map a window-space point to a grid cell, accounting for padding + backing scale.
    /// AppKit view coordinates are bottom-left origin, so the row is measured from the top.
    private func cell(at locationInWindow: NSPoint) -> (row: Int, column: Int)? {
        guard let renderer, columns > 0, rows > 0 else { return nil }
        let scale = window?.backingScaleFactor ?? 2.0
        let cellW = CGFloat(renderer.cellPixelWidth) / scale
        let cellH = CGFloat(renderer.cellPixelHeight) / scale
        guard cellW > 0, cellH > 0 else { return nil }
        let p = convert(locationInWindow, from: nil)
        let x = p.x - gridOriginPointsX
        // The smooth-scroll translate slides content UP by `scrollFraction` of a cell, so what's
        // visually under the pointer is the content that fraction further down — add it back so
        // clicks/selections land on the row the user sees, not the untranslated grid slot.
        let yFromTop = bounds.height - p.y - gridOriginPointsY + scrollFraction * cellH
        let col = Int((x / cellW).rounded(.down))
        let row = Int((yFromTop / cellH).rounded(.down))
        return (max(0, min(rows - 1, row)), max(0, min(columns - 1, col)))
    }

    /// Mouse goes to the program when it enabled tracking — unless Shift is held, which
    /// always forces local selection (the standard terminal override).
    func isMouseReporting(_ event: NSEvent) -> Bool {
        inputModes().mouseTrackingEnabled && !event.modifierFlags.contains(.shift)
    }

    private func mouseModifiers(_ event: NSEvent) -> KeyModifiers {
        var mods: KeyModifiers = []
        let flags = event.modifierFlags
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.control) { mods.insert(.control) }
        return mods
    }

    func reportMouse(_ event: NSEvent, button: MouseButton, kind: MouseEventKind) {
        guard let pos = cell(at: event.locationInWindow) else { return }
        let modes = inputModes()
        emit(inputEncoder.encodeMouse(
            button: button, kind: kind,
            column: pos.column, row: pos.row,
            modifiers: mouseModifiers(event), modes: modes
        ))
    }

    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if copyMode != nil { return } // copy mode is keyboard-driven; ignore clicks
        // ⌘-click opens an OSC 8 hyperlink or an auto-detected URL.
        // ⌘ overrides mouse reporting, the same way Shift overrides it for selection.
        if event.modifierFlags.contains(.command), let pos = cell(at: event.locationInWindow),
           let url = linkURL(atRow: pos.row, column: pos.column) {
            openLink(url)
            return
        }
        if isMouseReporting(event) {
            reportMouse(event, button: .left, kind: .press)
            return
        }
        guard let pos = cell(at: event.locationInWindow) else { return }
        // Click count picks the selection unit (1 = char, 2 = word, 3 = line); Option = rectangle.
        switch event.clickCount {
        case 2: selectionGranularity = .word
        case let n where n >= 3: selectionGranularity = .line
        default: selectionGranularity = .character
        }
        selectionRectangular = event.modifierFlags.contains(.option)
        selectionAnchor = pos
        selectionHead = pos
        scheduleRender()
    }

    /// The clickable URL at a grid cell (OSC 8 hyperlink first, else an auto-detected URL).
    private func linkURL(atRow row: Int, column col: Int) -> String? {
        linkRange(atRow: row, column: col)?.url
    }

    /// The clickable link at a grid cell *and* its column span — an OSC 8 hyperlink (the run of
    /// adjacent cells sharing its id) first, else an auto-detected URL in the row text. The row is
    /// built one character per cell so `column`/the returned range map directly to grid columns.
    private func linkRange(atRow row: Int, column col: Int) -> (url: String, columns: Range<Int>)? {
        emulatorSync { emulator in
            let grid = scrollOffset > 0 ? emulator.readGrid(scrollbackOffset: scrollOffset) : emulator.readGrid()
            guard row >= 0, row < grid.rows, col >= 0, col < grid.cols else { return nil }
            if let cell = grid.cell(row: row, col: col), cell.hyperlinkID != 0,
               let url = emulator.hyperlinkURL(id: cell.hyperlinkID) {
                var lo = col, hi = col
                while lo > 0, grid.cell(row: row, col: lo - 1)?.hyperlinkID == cell.hyperlinkID { lo -= 1 }
                while hi + 1 < grid.cols, grid.cell(row: row, col: hi + 1)?.hyperlinkID == cell.hyperlinkID { hi += 1 }
                return (url, lo ..< (hi + 1))
            }
            var line = ""
            line.reserveCapacity(grid.cols)
            for c in 0 ..< grid.cols {
                guard let cell = grid.cell(row: row, col: c), cell.width != .spacerTail else { line.append(" "); continue }
                line.unicodeScalars.append(cell.codepoint == 0 ? " " : (Unicode.Scalar(cell.codepoint) ?? " "))
            }
            return URLDetection.match(in: line, at: col) ?? URLDetection.detectFilePath(in: line, at: col)
        }
    }

    /// Open a clicked link, restricted to safe schemes so terminal output can't trigger a
    /// surprising handler (e.g. a custom app scheme) on ⌘-click. No `file:` — an OSC 8
    /// hyperlink comes from terminal output (possibly a remote host), and opening an
    /// arbitrary local path via NSWorkspace executes .app bundles and .command scripts.
    /// File paths (absolute or relative to cwd) open in Harness's file preview instead.
    private func openLink(_ string: String) {
        // Check if it's a local file path first
        let path = resolveFilePath(string)
        if let path, FileManager.default.fileExists(atPath: path) {
            let isDirectory = (try? FileManager.default.attributesOfItem(atPath: path)[.type] as? FileAttributeType) == .typeDirectory
            guard !isDirectory else { return }
            // Don't open executables (.app, .command, etc.) — security
            guard !path.hasSuffix(".app"), !path.hasSuffix(".command"), !path.hasSuffix(".tool") else { return }
            NotificationCenter.default.post(
                name: Notification.Name("HarnessOpenFilePreview"),
                object: nil,
                userInfo: ["path": path]
            )
            return
        }
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased(),
              ["http", "https", "mailto", "ftp", "ftps"].contains(scheme) else { return }
        NSWorkspace.shared.open(url)
    }

    private func resolveFilePath(_ string: String) -> String? {
        var cleanString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle file:// scheme
        if cleanString.lowercased().hasPrefix("file://") {
            let rawPath = String(cleanString.dropFirst(7))
            if let decoded = rawPath.removingPercentEncoding {
                cleanString = decoded
            } else {
                cleanString = rawPath
            }
        }
        
        // Strip leading/trailing single or double quotes
        if (cleanString.hasPrefix("'") && cleanString.hasSuffix("'")) ||
           (cleanString.hasPrefix("\"") && cleanString.hasSuffix("\"")) {
            cleanString = String(cleanString.dropFirst().dropLast())
        }

        // Strip line:col suffix (e.g. "file.swift:42:5" or "file.swift:42")
        let stripped = cleanString.replacingOccurrences(of: #":\d+(?::\d+)?$"#, with: "", options: .regularExpression)
        if stripped.hasPrefix("/") {
            return stripped
        }
        // Relative path — resolve against terminal's cwd
        guard let cwd = currentCwd, !cwd.isEmpty else { return nil }
        let resolved = (cwd as NSString).appendingPathComponent(stripped)
        return resolved
    }

    public override func mouseDragged(with event: NSEvent) {
        if copyMode != nil { return }
        if isMouseReporting(event) {
            // Only report motion when the app asked for drag / any-motion tracking.
            let modes = inputModes()
            if modes.mouseDrag || modes.mouseAny {
                reportMouse(event, button: .left, kind: .drag)
            }
            return
        }
        guard selectionAnchor != nil, let pos = cell(at: event.locationInWindow) else { return }
        selectionHead = pos
        scheduleRender()
    }

    public override func mouseUp(with event: NSEvent) {
        if copyMode != nil { return }
        if isMouseReporting(event) {
            reportMouse(event, button: .left, kind: .release)
            return
        }
        // A single-cell *character* click with no drag clears; a word/line click (or any drag)
        // makes a real selection that copy-on-select copies.
        if let a = selectionAnchor, let h = selectionHead, a == h, selectionGranularity == .character {
            clearSelection()
            return
        }
        if copyOnSelect { copySelection() }
    }

    public override func rightMouseDown(with event: NSEvent) {
        if isMouseReporting(event) { reportMouse(event, button: .right, kind: .press) }
        else { super.rightMouseDown(with: event) }
    }

    public override func rightMouseUp(with event: NSEvent) {
        if isMouseReporting(event) { reportMouse(event, button: .right, kind: .release) }
        else { super.rightMouseUp(with: event) }
    }

    public override func otherMouseDown(with event: NSEvent) {
        if isMouseReporting(event) {
            reportMouse(event, button: .middle, kind: .press)
        } else if event.buttonNumber == 2 {
            // Middle-click pastes the current selection (the X11/Ghostty primary-paste
            // convention), falling back to the clipboard. Routed through pasteText so
            // bracketed paste and paste protection apply exactly like ⌘V.
            if let text = selectionTextIfAny() ?? NSPasteboard.general.string(forType: .string),
               !text.isEmpty {
                pasteText(text)
            }
        } else {
            super.otherMouseDown(with: event)
        }
    }

    public override func otherMouseUp(with event: NSEvent) {
        if isMouseReporting(event) { reportMouse(event, button: .middle, kind: .release) }
        else { super.otherMouseUp(with: event) }
    }

    // MARK: - Link hover (⌘-hover affordance)

    private func cellSizePoints() -> (w: CGFloat, h: CGFloat)? {
        guard let renderer else { return nil }
        let scale = window?.backingScaleFactor ?? 2.0
        let w = CGFloat(renderer.cellPixelWidth) / scale
        let h = CGFloat(renderer.cellPixelHeight) / scale
        guard w > 0, h > 0 else { return nil }
        return (w, h)
    }

    /// The view-space rect (bottom-left origin, matching `cell(at:)`'s inverse) covering a grid
    /// `row` and half-open `columns` span.
    private func cellRect(row: Int, columns: Range<Int>) -> CGRect? {
        guard let (w, h) = cellSizePoints(), !columns.isEmpty else { return nil }
        let x = gridOriginPointsX + CGFloat(columns.lowerBound) * w
        let y = bounds.height - gridOriginPointsY - CGFloat(row + 1) * h
        return CGRect(x: x, y: y, width: CGFloat(columns.count) * w, height: h)
    }

    func hoveredLinkRect() -> CGRect? {
        guard let link = hoveredLink else { return nil }
        return cellRect(row: link.row, columns: link.columns)
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateLinkHover(at: event.locationInWindow, modifiers: event.modifierFlags)
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        clearLinkHover()
    }

    public override func flagsChanged(with event: NSEvent) {
        super.flagsChanged(with: event)
        // Pressing/releasing ⌘ over a stationary pointer toggles whether the link is "hot".
        if let window {
            updateLinkHover(at: window.mouseLocationOutsideOfEventStream, modifiers: event.modifierFlags)
        }
        reportModifierKeyIfNeeded(event)
    }

    /// Report a modifier key (Shift/Ctrl/Alt/Cmd/CapsLock) as its own key event when a program
    /// enabled the Kitty protocol's "report all keys as escape codes" flag (0b1000). Release events
    /// additionally require "report event types" (0b10). No-op otherwise — modifiers normally emit
    /// nothing on their own.
    private func reportModifierKeyIfNeeded(_ event: NSEvent) {
        let modes = inputModes()
        guard modes.kittyKeyboardFlags & 0b1000 != 0 else { pressedModifierKeyCodes.removeAll(); return }
        guard copyMode == nil, let key = Self.modifierSpecialKey(forKeyCode: event.keyCode) else { return }
        // flagsChanged toggles: if we already recorded this key down, this event is its release.
        let isPress: Bool
        if pressedModifierKeyCodes.contains(event.keyCode) {
            pressedModifierKeyCodes.remove(event.keyCode)
            isPress = false
        } else {
            pressedModifierKeyCodes.insert(event.keyCode)
            isPress = true
        }
        if !isPress, modes.kittyKeyboardFlags & 0b10 == 0 { return } // release needs event-types
        emit(inputEncoder.encode(key, modifiers: [], event: isPress ? .press : .release, modes: modes))
    }

    /// Map a macOS virtual keycode for a modifier key to its Kitty `SpecialKey`. Left/right are
    /// distinguished by keycode (the device-independent modifier flags can't tell them apart).
    private static func modifierSpecialKey(forKeyCode code: UInt16) -> SpecialKey? {
        switch code {
        case 56: return .leftShift       // kVK_Shift
        case 60: return .rightShift      // kVK_RightShift
        case 59: return .leftControl     // kVK_Control
        case 62: return .rightControl    // kVK_RightControl
        case 58: return .leftAlt         // kVK_Option
        case 61: return .rightAlt        // kVK_RightOption
        case 55: return .leftSuper       // kVK_Command
        case 54: return .rightSuper      // kVK_RightCommand
        case 57: return .capsLock        // kVK_CapsLock
        default: return nil
        }
    }

    /// A link is only highlighted while ⌘ is held (matching ⌘-click open) and the program
    /// isn't grabbing the mouse.
    private func updateLinkHover(at locationInWindow: NSPoint, modifiers: NSEvent.ModifierFlags) {
        // `cell(at:)` clamps to the grid, so first require the pointer to actually be inside us
        // (⌘ can be pressed while the pointer rests over another pane).
        guard copyMode == nil, modifiers.contains(.command),
              bounds.contains(convert(locationInWindow, from: nil)),
              let pos = cell(at: locationInWindow),
              let link = linkRange(atRow: pos.row, column: pos.column)
        else { clearLinkHover(); return }
        if let current = hoveredLink, current.row == pos.row, current.columns == link.columns { return }
        hoveredLink = (row: pos.row, columns: link.columns)
        refreshLinkUnderline()
        window?.invalidateCursorRects(for: self)
    }

    func clearLinkHover() {
        guard hoveredLink != nil else { return }
        hoveredLink = nil
        refreshLinkUnderline()
        window?.invalidateCursorRects(for: self)
    }

    private func refreshLinkUnderline() {
        // Disable implicit animations so the underline snaps to the pointer instead of sliding.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let rect = hoveredLinkRect() {
            let thickness = max(1, (cellSizePoints()?.h ?? 16) * 0.07)
            linkUnderlineLayer.frame = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: thickness)
            linkUnderlineLayer.isHidden = false
        } else {
            linkUnderlineLayer.isHidden = true
        }
        CATransaction.commit()
    }
}
