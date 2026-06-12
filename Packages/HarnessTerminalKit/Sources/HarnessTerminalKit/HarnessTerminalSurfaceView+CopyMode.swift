import AppKit
import HarnessCopyMode
import HarnessCore
import HarnessTerminalEngine
import HarnessTerminalRenderer
import HarnessTheme
import Metal
import QuartzCore

extension HarnessTerminalSurfaceView {
    // MARK: - Copy mode

    /// Enter copy mode, seeding the cursor at the live terminal cursor. The view's own
    /// emulator holds the scrollback, so no daemon text capture is needed.
    public func enterCopyMode() {
        guard copyMode == nil else { return }
        copyModeTables = KeybindingsStore.load()
        copyModeSearchEntry = nil
        copyMode = emulatorSync { emulator in
            let live = emulator.readGrid()
            let cursorLine = emulator.historyCount + live.cursor.row
            return CopyModeReducer.initialState(grid: emulator, cursorLine: cursorLine, cursorColumn: live.cursor.col, wrapSearch: wrapSearch, wordSeparators: wordSeparators)
        }
        scrollOffset = 0
        scrollFraction = 0 // copy mode is line-based; don't carry a smooth-scroll fraction in
        wheelLineRemainder = 0 // don't carry a sub-line wheel remainder across the mode boundary
        wheelColumnRemainder = 0
        notifyScrollChanged(historyCount: emulatorSync { $0.historyCount })
        scheduleRender()
    }

    /// Exit copy mode and return to the live bottom.
    public func exitCopyMode() {
        guard copyMode != nil else { return }
        copyMode = nil
        copyModeSearchEntry = nil
        scrollOffset = 0
        scrollFraction = 0
        wheelLineRemainder = 0
        wheelColumnRemainder = 0
        notifyScrollChanged(historyCount: emulatorSync { $0.historyCount })
        scheduleRender()
    }

    /// Run a copy-mode action from outside the view (the `:` prompt, `send-keys -X`,
    /// `copy-mode -X`). No-op when not in copy mode.
    public func performCopyModeAction(_ action: CopyModeAction) {
        guard copyMode != nil else { return }
        handleCopyModeAction(action)
    }

    func handleCopyModeKey(_ event: NSEvent) {
        // Interactive search-query entry captures raw keys until Enter / Escape.
        if copyModeSearchEntry != nil {
            handleSearchEntryKey(event)
            return
        }
        guard let spec = Self.copyModeKeySpec(from: event),
              let table = copyModeTables?.table(KeyTableID.copyMode(modeKeys: copyModeKeys)),
              case let .copyModeCommand(action) = table.lookup(spec)?.command
        else { return } // unbound keys are swallowed (copy mode is modal)
        handleCopyModeAction(action)
    }

    func handleCopyModeAction(_ action: CopyModeAction) {
        guard let state = copyMode else { return }
        let (next, effect) = emulatorSync { CopyModeReducer.reduce(state, action, grid: $0) }
        copyMode = next
        switch effect {
        case .none:
            scheduleRender()
        case let .copy(text):
            writeCopyModeSelection(text)
            scheduleRender()
        case let .copyAndCancel(text):
            writeCopyModeSelection(text)
            exitCopyMode()
        case let .pipe(text, command):
            copyModePipe(text: text, command: command)
            exitCopyMode()
        case .paste:
            exitCopyMode()
            paste(nil) // paste the most-recent buffer (mirrored to the system pasteboard on yank)
        case .cancel:
            exitCopyMode()
        case .beginSearchEntry:
            copyModeSearchEntry = ""
            scheduleRender()
        }
    }

    private func handleSearchEntryKey(_ event: NSEvent) {
        let chars = event.charactersIgnoringModifiers ?? ""
        let scalar = chars.unicodeScalars.first?.value ?? 0
        switch scalar {
        case 0x1B: // Escape — abandon the search
            copyModeSearchEntry = nil
            scheduleRender()
        case 0x0D, 0x03: // Enter — commit
            let query = copyModeSearchEntry ?? ""
            copyModeSearchEntry = nil
            if let state = copyMode, !query.isEmpty {
                copyMode = emulatorSync {
                    CopyModeReducer.applySearch(state, query: query, reverse: state.search.reverse, grid: $0)
                }
            }
            scheduleRender()
        case 0x7F, 0x08: // Backspace
            if var q = copyModeSearchEntry, !q.isEmpty { q.removeLast(); copyModeSearchEntry = q }
            scheduleRender()
        default:
            if scalar >= 0x20, !chars.isEmpty { copyModeSearchEntry = (copyModeSearchEntry ?? "") + chars }
            scheduleRender()
        }
    }

    private func writeCopyModeSelection(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        onCopy?(text) // mirror into the daemon paste buffer
    }

    /// `copy-pipe`: feed the selected text to a shell command's stdin (detached), like tmux.
    private func copyModePipe(text: String, command: String) {
        guard !text.isEmpty, !command.isEmpty else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardInput = pipe
        // Don't let the child inherit the GUI app's stdout/stderr (it would leak app fds and
        // could block on a full inherited pipe); discard its output like tmux's copy-pipe.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        // Reap the child so it can't linger as a zombie across many copy-pipe invocations.
        process.terminationHandler = { _ in }
        guard (try? process.run()) != nil else { return }
        // Write off the main thread so a large selection into a slow/non-draining command can't
        // block the UI; a closed pipe (child already exited) throws and is ignored.
        let data = Data(text.utf8)
        let writer = pipe.fileHandleForWriting
        DispatchQueue.global(qos: .utility).async {
            try? writer.write(contentsOf: data)
            try? writer.close()
        }
    }

    /// Convert an `NSEvent` to a `KeySpec` for copy-mode table lookup (mirrors the prefix
    /// keymap's mapping; kept local so the live-input path is untouched).
    private static func copyModeKeySpec(from event: NSEvent) -> KeySpec? {
        guard let chars = event.charactersIgnoringModifiers else { return nil }
        let key: String
        if chars.count == 1, let scalar = chars.unicodeScalars.first {
            switch scalar.value {
            case 0x1B: key = "Escape"
            case 0x09, 0x19: key = "Tab"  // 0x19 = NSBackTabCharacter (Shift-Tab)
            case 0x0D, 0x03: key = "Enter"
            case 0x7F: key = "Backspace"
            case 0x20: key = "Space"
            case 0xF700: key = "Up"
            case 0xF701: key = "Down"
            case 0xF702: key = "Left"
            case 0xF703: key = "Right"
            case 0xF729: key = "Home"
            case 0xF72B: key = "End"
            case 0xF72C: key = "PageUp"
            case 0xF72D: key = "PageDown"
            default: key = chars
            }
        } else {
            key = chars
        }
        var modifiers: KeySpec.Modifiers = []
        let mask = event.modifierFlags
        if mask.contains(.control) { modifiers.insert(.control) }
        if mask.contains(.option) { modifiers.insert(.option) }
        if mask.contains(.command) { modifiers.insert(.command) }
        if mask.contains(.shift), key.count > 1 { modifiers.insert(.shift) }
        return KeySpec(key: key, modifiers: modifiers)
    }

    /// Render copy mode: the grid at the model's scroll offset, with selection / search
    /// highlights and the copy-mode cursor, plus a status row. Returns false when not in
    /// copy mode so `renderNow` falls through to the normal path.
    func renderCopyMode(renderer: TerminalMetalRenderer, drawable: CAMetalDrawable) -> Bool {
        guard let cm = copyMode else { return false }
        let emulator = emulatorState.emulator
        let offset = cm.scrollbackOffset(historyCount: emulator.historyCount)
        let grid = emulator.readGrid(scrollbackOffset: offset)
        let region: SelectionRegion? = cm.viewportSelection(rows: rows, columns: columns).map { vs in
            switch vs.kind {
            case .linear:
                return .linear(TerminalSelection((vs.startRow, vs.startColumn), (vs.endRow, vs.endColumn)))
            case .block:
                return .block(BlockSelection((vs.startRow, vs.startColumn), (vs.endRow, vs.endColumn)))
            }
        }
        let hits = cm.viewportSearchHits(rows: rows).map { m in
            TerminalSelection((m.line, m.startColumn), (m.line, max(m.startColumn, m.endColumn - 1)))
        }
        let frameBuildStart = DispatchTime.now().uptimeNanoseconds
        var frame = frameBuilder.build(grid, region: region, searchHighlights: hits,
                                       copyModeCursor: cm.viewportCursor(rows: rows),
                                       imageProvider: { emulator.image(for: $0) })
        let frameBuildNanos = DispatchTime.now().uptimeNanoseconds &- frameBuildStart
        let statusText = copyModeSearchEntry.map { (cm.search.reverse ? "?" : "/") + $0 } ?? cm.statusLine()
        overlayCopyModeStatus(into: &frame, text: statusText)
        let didPresent = renderer.present(
            frame, to: drawable,
            clearColor: frameBuilder.renderColor(canvasBackground, alpha: canvasOpacity),
            origin: (originOffsetX, originOffsetY), gamma: glyphGamma, ligatures: ligaturesEnabled,
            frameBuildNanos: frameBuildNanos,
            synchronizedWithTransaction: metalLayer.presentsWithTransaction
        )
        if didPresent { onRenderStats?(renderer.stats) }
        return true
    }

    /// Draw the copy-mode status into the bottom frame row (mode, position, match count, or
    /// the live search query) on an inverted band.
    private func overlayCopyModeStatus(into frame: inout TerminalFrame, text: String) {
        Self.applyCopyModeStatus(
            into: &frame,
            text: text,
            builder: frameBuilder,
            selectionBackground: selectionBackground,
            canvasForeground: canvasForeground,
            canvasBackground: canvasBackground
        )
    }

    nonisolated static func applyCopyModeStatus(
        into frame: inout TerminalFrame,
        text: String,
        builder: FrameBuilder,
        selectionBackground: RGBColor?,
        canvasForeground: RGBColor,
        canvasBackground: RGBColor
    ) {
        let row = frame.rows - 1
        guard row >= 0, frame.columns > 0 else { return }
        let bandBg = builder.renderColor(selectionBackground ?? canvasForeground)
        let bandFg = builder.renderColor(canvasBackground)
        for col in 0 ..< frame.columns {
            let idx = row * frame.columns + col
            frame.cells[idx].codepoint = 0x20
            frame.cells[idx].foreground = bandFg
            frame.cells[idx].background = bandBg
            // The band is an opaque highlight, not the canvas color, so force its fill even
            // though the underlying cell may have been built as a skippable canvas cell.
            frame.cells[idx].drawBackground = true
            frame.cells[idx].underlineColor = bandFg
            frame.cells[idx].bold = false
            frame.cells[idx].italic = false
            frame.cells[idx].underline = .none
            frame.cells[idx].strikethrough = false
            frame.cells[idx].overline = false
            frame.cells[idx].width = .normal
            frame.cells[idx].combining0 = 0
            frame.cells[idx].combining1 = 0
        }
        // Write the status text one base scalar per column, folding combining marks onto their base
        // so a Thai search query renders correctly instead of exploding across the band.
        var col = 0
        var lastBaseIdx: Int? = nil
        for scalar in text.unicodeScalars {
            if CharacterWidth.width(of: scalar) == 0 {
                // Fold a true combining mark onto the base; drop non-extending format scalars.
                if scalar.properties.isGraphemeExtend, let bi = lastBaseIdx {
                    if frame.cells[bi].combining0 == 0 { frame.cells[bi].combining0 = scalar.value }
                    else if frame.cells[bi].combining1 == 0 { frame.cells[bi].combining1 = scalar.value }
                }
                continue
            }
            guard col < frame.columns else { break }
            let idx = row * frame.columns + col
            frame.cells[idx].codepoint = scalar.value
            lastBaseIdx = idx
            col += 1
        }
    }
}
