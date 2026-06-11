import AppKit
import HarnessCopyMode
import HarnessCore
import HarnessTerminalEngine
import HarnessTerminalRenderer
import HarnessTheme
import Metal
import QuartzCore

extension HarnessTerminalSurfaceView {
    // MARK: - Find (Cmd+F)

    public func beginFind() { findActive = true }

    /// Close the find bar: drop matches + highlights (the bar stays a host concern).
    public func endFind() {
        guard findActive else { return }
        findActive = false
        findMatches = []
        findCurrentIndex = 0
        onFindResultsChanged?(0, 0)
        scheduleRender()
    }

    /// Run/refresh the search for `query` (incremental as the user types). Empty clears matches.
    public func updateFind(query: String) {
        findActive = true
        if query.isEmpty {
            findMatches = []
            findCurrentIndex = 0
        } else {
            findMatches = emulatorSync { emulator in
                TerminalBufferSearch.matches(query: query, lineCount: emulator.bufferLineCount) { emulator.bufferLine($0) }
            }
            findCurrentIndex = 0
            if !findMatches.isEmpty { scrollToCurrentMatch() }
        }
        onFindResultsChanged?(findMatches.isEmpty ? 0 : findCurrentIndex + 1, findMatches.count)
        scheduleRender()
    }

    public func findNext() { advanceFind(by: 1) }
    public func findPrevious() { advanceFind(by: -1) }

    private func advanceFind(by delta: Int) {
        guard !findMatches.isEmpty else { return }
        let n = findMatches.count
        findCurrentIndex = ((findCurrentIndex + delta) % n + n) % n
        scrollToCurrentMatch()
        onFindResultsChanged?(findCurrentIndex + 1, n)
        scheduleRender()
    }

    /// Scroll so the current match sits a little below the top of the viewport (context above it).
    private func scrollToCurrentMatch() {
        guard findMatches.indices.contains(findCurrentIndex) else { return }
        let line = findMatches[findCurrentIndex].bufferLine
        scrollToBufferLine(max(0, line - max(0, rows / 3)))
    }

    /// Viewport-relative highlight spans for the matches currently on screen. `nonisolated` +
    /// pure so the off-main render path can call it on its worker queue.
    nonisolated static func viewportFindHighlights(
        _ matches: [TerminalBufferMatch], scrollOffset: Int, historyCount: Int, rows: Int
    ) -> [TerminalSelection] {
        guard !matches.isEmpty, rows > 0 else { return [] }
        let topVisible = historyCount - scrollOffset // buffer index of the top viewport row
        var hits: [TerminalSelection] = []
        for m in matches where !m.columns.isEmpty {
            let row = m.bufferLine - topVisible
            if row >= 0, row < rows {
                hits.append(TerminalSelection((row, m.columns.lowerBound), (row, m.columns.upperBound - 1)))
            }
        }
        return hits
    }

    public override func scrollWheel(with event: NSEvent) {
        if event.scrollingDeltaY != 0 { clearLinkHover() }
        // In copy mode, the wheel moves the copy-mode cursor through scrollback.
        if copyMode != nil, let renderer, event.scrollingDeltaY != 0 {
            let scale = window?.backingScaleFactor ?? 2.0
            let cellH = max(1, CGFloat(renderer.cellPixelHeight) / scale)
            let lines = consumeWheelLines(event, cellHeight: cellH)
            guard lines != 0 else { return }
            let action: CopyModeAction = lines > 0 ? .cursorUp : .cursorDown
            for _ in 0 ..< abs(lines) { handleCopyModeAction(action) }
            return
        }
        if isMouseReporting(event) {
            guard let renderer else { return }
            let scale = window?.backingScaleFactor ?? 2.0
            // One wheel report per *line* of travel (cell-height accumulated, remainder carried),
            // not per NSEvent — a trackpad fires a ~120Hz stream of tiny deltas plus momentum
            // events, and reporting each one flooded TUIs (Claude Code) with wheel events, making
            // scroll feel hair-trigger. Matches Ghostty's pending-scroll accumulation.
            let cellH = max(1, CGFloat(renderer.cellPixelHeight) / scale)
            let lines = consumeWheelLines(event, cellHeight: cellH)
            if lines != 0 {
                let button: MouseButton = lines > 0 ? .wheelUp : .wheelDown
                for _ in 0 ..< min(abs(lines), 32) { reportMouse(event, button: button, kind: .press) }
            }
            // Horizontal wheel: buttons 66/67, one report per cell-width column (Ghostty parity).
            let cellW = max(1, CGFloat(renderer.cellPixelWidth) / scale)
            let cols = consumeWheelColumns(event, cellWidth: cellW)
            if cols != 0 {
                let button: MouseButton = cols > 0 ? .wheelLeft : .wheelRight
                for _ in 0 ..< min(abs(cols), 32) { reportMouse(event, button: button, kind: .press) }
            }
            return
        }
        // Local scrollback: positive deltaY (content moves down) scrolls back into history.
        guard event.scrollingDeltaY != 0, let renderer else { return }
        let scale = window?.backingScaleFactor ?? 2.0
        let cellH = max(1, CGFloat(renderer.cellPixelHeight) / scale)
        // The alternate screen has no scrollback — synthesize arrow keys instead (DECSET
        // 1007 "alternate scroll", on by default) so the wheel scrolls less/man/vim when
        // the program didn't enable mouse reporting (that case already returned above).
        // Arrow synthesis is inherently line-based, so it keeps the whole-line accumulator;
        // local scrollback below scrolls by the continuous (pixel-smooth) delta instead.
        let onAltScreen = inputAltScreenActive()
        let modes = inputModes()
        if onAltScreen, modes.alternateScroll {
            let lines = consumeWheelLines(event, cellHeight: cellH)
            guard lines != 0 else { return }
            let key: SpecialKey = lines > 0 ? .up : .down
            let perLine = inputEncoder.encode(key, modifiers: [], modes: modes)
            guard !perLine.isEmpty else { return }
            // Cap one event's burst (don't flood the PTY on a violent fling) but carry
            // the excess back into the remainder so momentum isn't silently truncated.
            let send = min(abs(lines), 32)
            let excess = abs(lines) - send
            if excess > 0 { wheelLineRemainder += CGFloat(lines > 0 ? excess : -excess) }
            var bytes: [UInt8] = []
            bytes.reserveCapacity(perLine.count * send)
            for _ in 0 ..< send { bytes.append(contentsOf: perLine) }
            emit(bytes)
            return
        }
        scrollByContinuous(lines: continuousWheelLines(event, cellHeight: cellH))
    }

    /// Continuous (sub-line) wheel delta in lines for local-scrollback smooth scrolling. Precise
    /// (trackpad) deltas are pixel-based; the fraction itself is the carry, so no remainder
    /// accumulator is needed. Non-precise mouse wheels keep the classic whole-notch step
    /// (clamped to a full tick like `consumeWheelLines`) — a clicky wheel jumping 3 lines per
    /// notch is the expected feel; only the trackpad scrolls by pixels.
    private func continuousWheelLines(_ event: NSEvent, cellHeight: CGFloat) -> CGFloat {
        let delta = event.scrollingDeltaY
        if event.hasPreciseScrollingDeltas { return delta / cellHeight }
        let ticks = delta > 0 ? max(delta, 1) : min(delta, -1)
        return ticks * Self.mouseWheelLinesPerTick
    }

    /// Convert a wheel/trackpad event into a signed whole-line scroll count, carrying the
    /// sub-line remainder across events. Precise (trackpad) deltas are pixel-based, so dividing
    /// by the cell height maps a line's worth of finger travel to one line *and* lets small
    /// movements accumulate — the old `max(1, …rounded())` forced a full line per event, which
    /// made trackpad scrolling feel hair-trigger. Non-precise mouse wheels report in line units,
    /// scaled to the classic 3-line notch.
    private func consumeWheelLines(_ event: NSEvent, cellHeight: CGFloat) -> Int {
        let delta = event.scrollingDeltaY
        if event.hasPreciseScrollingDeltas {
            wheelLineRemainder += delta / cellHeight
        } else {
            // macOS simulates acceleration on non-precise wheels by ramping the delta from 0.1
            // upward — a slow single notch would otherwise accumulate 0.3 lines and do nothing
            // until the fourth click. Clamp a notch to at least one full tick (Ghostty parity).
            let ticks = delta > 0 ? max(delta, 1) : min(delta, -1)
            wheelLineRemainder += ticks * Self.mouseWheelLinesPerTick
        }
        let whole = wheelLineRemainder < 0 ? wheelLineRemainder.rounded(.up) : wheelLineRemainder.rounded(.down)
        wheelLineRemainder -= whole
        return Int(whole)
    }

    /// Horizontal counterpart of `consumeWheelLines` for mouse-reported wheel-left/right: precise
    /// deltas accumulate by cell width (remainder carried); non-precise ticks map 1:1 to columns.
    private func consumeWheelColumns(_ event: NSEvent, cellWidth: CGFloat) -> Int {
        let delta = event.scrollingDeltaX
        guard delta != 0 else { return 0 }
        if event.hasPreciseScrollingDeltas {
            wheelColumnRemainder += delta / cellWidth
            let whole = wheelColumnRemainder < 0 ? wheelColumnRemainder.rounded(.up) : wheelColumnRemainder.rounded(.down)
            wheelColumnRemainder -= whole
            return Int(whole)
        }
        return Int(delta.rounded())
    }

    /// Standard responder copy (Edit ▸ Copy / ⌘C via the menu).
    @objc public func copy(_ sender: Any?) {
        copySelection()
    }

    /// Standard responder cut (Edit ▸ Cut / ⌘X). A terminal's scrollback is read-only, so cut
    /// behaves as copy — without this, the Edit-menu Cut item (which targets `cut:`) no-ops.
    @objc public func cut(_ sender: Any?) {
        copySelection()
    }

    /// Standard responder paste (Edit ▸ Paste / ⌘V). Sends the clipboard text to the PTY,
    /// wrapped in bracketed-paste markers when the program enabled DECSET 2004 (so shells and
    /// editors treat it as a literal paste, not typed input). Newlines normalize to CR (the
    /// Enter byte) so multi-line pastes run line by line.
    ///
    /// When the clipboard holds no text but an image (a screenshot) or a copied file, the image is
    /// written to a temp PNG and its shell-quoted path is pasted instead — so programs that accept
    /// image-file paths (Claude Code, etc.) attach it. Mirrors the file-drop path.
    @objc public func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        // Text fast path.
        if let raw = pasteboard.string(forType: .string), !raw.isEmpty {
            pasteText(raw)
            return
        }
        // Image on the clipboard → write a temp PNG, paste its quoted path.
        if let path = Self.writePastedImage(from: pasteboard) {
            pasteText(Self.shellQuotedPath(path))
            return
        }
        // A file copied in Finder (⌘C → ⌘V) → paste the quoted path(s), like a drag-drop.
        let text = Self.droppedPathText(for: Self.droppedFileURLs(from: pasteboard))
        if !text.isEmpty { pasteText(text) }
    }

    /// If the pasteboard holds a valid image, write it to the pasted-images directory as a PNG and
    /// return the file path. Delegates to `PasteController`.
    static func writePastedImage(from pasteboard: NSPasteboard) -> String? {
        PasteController.writePastedImage(from: pasteboard)
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        pathDropOperation(for: sender)
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        pathDropOperation(for: sender)
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        // File URLs (files, folders) → paste shell-quoted paths.
        let urls = Self.droppedFileURLs(from: pasteboard)
        if !urls.isEmpty {
            window?.makeFirstResponder(self)
            pasteText(Self.droppedPathText(for: urls))
            return true
        }
        // Image drag (browser screenshot, Photos, etc.) → write temp PNG, paste path.
        if let path = Self.writePastedImage(from: pasteboard) {
            window?.makeFirstResponder(self)
            pasteText(Self.shellQuotedPath(path))
            return true
        }
        return false
    }

    private func pathDropOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        // Accept any drag the source allows (we always copy).
        guard !sender.draggingSourceOperationMask.isEmpty else { return [] }
        let pasteboard = sender.draggingPasteboard
        if !Self.droppedFileURLs(from: pasteboard).isEmpty { return .copy }
        if PasteController.pngImageData(from: pasteboard) != nil { return .copy }
        return []
    }

    func pasteText(_ raw: String) {
        let normalized = PasteController.normalizedForPaste(raw)
        let bracketed = inputModes().bracketedPaste
        if pasteProtection, !bracketed, PasteController.isUnsafePaste(normalized), let window {
            confirmPaste(normalized, in: window)
            return
        }
        deliverPaste(normalized)
    }

    private func deliverPaste(_ normalized: String) {
        snapToBottom()
        clearSelection()
        emit(inputEncoder.encodePaste(normalized, modes: inputModes()))
    }

    /// Unsafe = contains a line break (would run as a command without bracketed paste) or another
    private func confirmPaste(_ normalized: String, in window: NSWindow) {
        let lineCount = normalized.split(separator: "\r", omittingEmptySubsequences: false).count
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = lineCount > 1 ? "Paste \(lineCount) lines into the terminal?" : "Paste into the terminal?"
        alert.informativeText = "The clipboard contains line breaks or control characters that can run commands immediately. Review before pasting."
        alert.addButton(withTitle: "Paste")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.deliverPaste(normalized)
        }
    }

    /// Select the entire visible viewport (Edit ▸ Select All / ⌘A).
    @objc public override func selectAll(_ sender: Any?) {
        guard rows > 0, columns > 0 else { return }
        selectionGranularity = .character
        selectionRectangular = false
        selectionAnchor = (row: 0, column: 0)
        selectionHead = (row: rows - 1, column: columns - 1)
        scheduleRender()
    }

    /// Right-click context menu (Copy / Paste / Select All). Suppressed while the program is
    /// capturing the mouse (unless Shift forces local handling), matching the selection rules.
    public override func menu(for event: NSEvent) -> NSMenu? {
        guard !isMouseReporting(event) else { return nil }
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(paste(_:)), keyEquivalent: "")
        pasteItem.target = self
        menu.addItem(pasteItem)
        menu.addItem(.separator())
        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "")
        selectAllItem.target = self
        menu.addItem(selectAllItem)
        return menu
    }

    func copySelection() {
        guard let text = selectionTextIfAny() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        onCopy?(text)
    }

    /// The current selection's text, or nil when there is no selection (or it's empty).
    func selectionTextIfAny() -> String? {
        guard let region = currentSelectionRegion else { return nil }
        let text = emulatorSync { emu -> String in
            let snapshot = scrollOffset > 0 ? emu.readGrid(scrollbackOffset: scrollOffset) : emu.readGrid()
            switch region {
            case let .linear(sel): return selectedText(sel, snapshot)
            case let .block(blk): return blockSelectedText(blk, snapshot)
            }
        }
        return text.isEmpty ? nil : text
    }

    /// Extract the selected text from the grid: per row, the in-range columns, skipping the
    /// trailing spacer of wide chars, with trailing whitespace trimmed and rows joined by \n.
    private func selectedText(_ sel: TerminalSelection, _ snapshot: TerminalGridSnapshot) -> String {
        var lines: [String] = []
        for row in sel.startRow ... sel.endRow {
            let startCol = (row == sel.startRow) ? sel.startColumn : 0
            let endCol = (row == sel.endRow) ? sel.endColumn : snapshot.cols - 1
            lines.append(rowText(row: row, startCol: startCol, endCol: endCol, snapshot: snapshot))
        }
        return lines.joined(separator: "\n")
    }

    /// Extract a rectangular (block) selection: the same column span on every row, rows joined by \n.
    private func blockSelectedText(_ blk: BlockSelection, _ snapshot: TerminalGridSnapshot) -> String {
        (blk.startRow ... blk.endRow)
            .map { rowText(row: $0, startCol: blk.startColumn, endCol: blk.endColumn, snapshot: snapshot) }
            .joined(separator: "\n")
    }

    /// One row's text over `[startCol, endCol]`: drop wide-char spacer tails, blanks → space,
    /// trailing whitespace trimmed.
    private func rowText(row: Int, startCol: Int, endCol: Int, snapshot: TerminalGridSnapshot) -> String {
        var line = ""
        var col = startCol
        while col <= endCol {
            let cell = snapshot.cell(row: row, col: col)
            if cell?.width == .spacerTail { col += 1; continue }
            if let cell, cell.codepoint != 0 {
                line += cell.cluster // base + combining marks
            } else {
                line += " "
            }
            col += 1
        }
        while line.hasSuffix(" ") { line.removeLast() }
        return line
    }
}
