import AppKit
import HarnessCopyMode
import HarnessCore
import HarnessTerminalEngine
import HarnessTerminalRenderer
import HarnessTheme
import Metal
import QuartzCore

extension HarnessTerminalSurfaceView {
    // MARK: - Cursor blink

    // Blink is overlay-cheap: the cursor quad lives in the renderer's per-frame extras and a
    // block cursor's glyph inversion re-encodes exactly its own row (`previousCursor` key diff),
    // so each toggle costs ≤1 encoded row + one present — never a grid rebuild. Pinned by
    // `testCursorBlinkReencodesAtMostTheCursorRow`.
    func restartBlinkTimer() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        cursorBlinkVisible = true
        guard cursorBlinkEnabled else { return }
        let timer = Timer(timeInterval: 0.53, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                guard self.effectivelyFocused else { return }
                self.cursorBlinkVisible.toggle()
                self.scheduleRender()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
    }

    /// Reset the cursor to solid after activity (typing/output), matching common terminals.
    func wakeCursor() {
        guard cursorBlinkEnabled else { return }
        if !cursorBlinkVisible {
            cursorBlinkVisible = true
            scheduleRender()
        }
    }

    // MARK: - Scrollback

    /// Scroll the viewport by whole `lines` (positive = back into history) — keyboard paging and
    /// programmatic scrolls. Routed through the continuous path so a fractional rest position is
    /// preserved (a page-up while half a line into a scroll stays half a line offset).
    func scrollBy(lines: Int) {
        scrollByContinuous(lines: CGFloat(lines))
    }

    /// Smooth scroll: advance the continuous position `P = scrollOffset - scrollFraction` by
    /// `delta` lines (positive = back into history), clamped to `[0, historyCount]`. The integer
    /// offset is `ceil(P)` — the frame one line further back — and the fraction is the upward
    /// translate that slides it to the exact position. An offset change rebuilds via the existing
    /// shift path; a fraction-only change re-presents the cached frame with a new uniform (the
    /// near-free tick that makes trackpad scrolling pixel-smooth). Clamping to 0 lands exactly on
    /// the live view (fraction 0 — byte-identical frame).
    func scrollByContinuous(lines delta: CGFloat) {
        guard delta != 0 else { return }
        // Mirror read on the off-main pipeline (see `historyCountMirror`): a precise trackpad
        // fires this at event rate, and a `queue.sync` here would stall every wheel event behind
        // an in-flight parse. Direct read when the emulator is main-confined (legacy pipeline).
        let historyCount = offMainParserFramePipelineEnabled
            ? historyCountMirror
            : emulatorState.emulator.historyCount
        var position = CGFloat(scrollOffset) - scrollFraction + delta
        position = max(0, min(CGFloat(historyCount), position))
        // Snap float dust onto whole lines: P fractionally ABOVE an integer would ceil to the
        // next offset with fraction ≈ 1 — render-identical, but every line-based consumer
        // (hit-test, prompt jump, scrollbar) would report one line further back for that tick.
        let nearest = position.rounded()
        if abs(position - nearest) < 0.0005 { position = nearest }
        // Inline images don't ride the smooth-scroll translate (image quads draw window-relative,
        // outside the scrollPx uniform); quantize to whole lines while any are visible so they
        // never sit misaligned mid-cell. The legacy on-main pipeline quantizes too: it presents
        // without the fraction uniform (and never builds the peek row), so a fractional position
        // there would render one whole line off instead of in between.
        if !offMainParserFramePipelineEnabled
            || lastPresentedResult.map({ !$0.frame.images.isEmpty }) == true {
            position = position.rounded()
        }
        let newOffset = Int(position.rounded(.up))
        let newFraction = CGFloat(newOffset) - position
        guard newOffset != scrollOffset || newFraction != scrollFraction else { return }
        let offsetChanged = newOffset != scrollOffset
        scrollOffset = newOffset
        scrollFraction = newFraction
        clearSelection()
        notifyScrollChanged(historyCount: historyCount)
        if offsetChanged {
            scheduleRender()
        } else if !repaintLastFrame() {
            // Fraction-only tick: the frame is unchanged, only the translate moved. The repaint
            // applies the new uniform over the cached instances; fall back to a build only when
            // there is no presentable cached frame (e.g. generation just changed).
            scheduleRender()
        }
    }

    /// Jump back to the live bottom (e.g. on typing).
    func snapToBottom() {
        guard scrollOffset != 0 || scrollFraction != 0 else { return }
        scrollOffset = 0
        scrollFraction = 0
        notifyScrollChanged(historyCount: emulatorSync { $0.historyCount })
        scheduleRender()
    }

    /// Tell the host the scroll position changed so it can flash the transient scrollbar.
    func notifyScrollChanged(historyCount: Int) {
        onScrollChanged?(historyCount - scrollOffset, historyCount + rows, rows)
    }

    // MARK: - Jump to prompt (OSC 133)

    /// Scroll so the nearest shell-prompt row *above* the current top-of-viewport line sits at the
    /// top. No-op without shell-integration marks or when already above the first prompt.
    public func jumpToPreviousPrompt() {
        let (prompts, historyCount) = emulatorSync { ($0.promptRows, $0.historyCount) }
        guard !prompts.isEmpty else { return }
        let topVisible = historyCount - scrollOffset   // buffer index of the top row
        guard let target = prompts.last(where: { $0 < topVisible }) else { return }
        scrollToBufferLine(target)
    }

    /// Scroll so the nearest shell-prompt row *below* the current top-of-viewport line sits at the
    /// top. No-op without marks or when already at/after the last prompt.
    public func jumpToNextPrompt() {
        let (prompts, historyCount) = emulatorSync { ($0.promptRows, $0.historyCount) }
        guard !prompts.isEmpty else { return }
        let topVisible = historyCount - scrollOffset
        guard let target = prompts.first(where: { $0 > topVisible }) else { return }
        scrollToBufferLine(target)
    }

    /// Set the scrollback offset so virtual buffer line `index` is the top viewport row.
    func scrollToBufferLine(_ index: Int) {
        let historyCount = emulatorSync { $0.historyCount }
        let target = max(0, min(historyCount, historyCount - index))
        guard target != scrollOffset || scrollFraction != 0 else { return }
        scrollOffset = target
        scrollFraction = 0 // prompt jumps anchor on a whole line
        clearSelection()
        notifyScrollChanged(historyCount: historyCount)
        scheduleRender()
    }
}
