import AppKit
import HarnessCopyMode
import HarnessCore
import HarnessTerminalEngine
import HarnessTerminalRenderer
import HarnessTheme
import Metal
import QuartzCore

// AppKit re-exports QuickDraw's legacy C `struct RGBColor`, which shadows
// `HarnessTheme.RGBColor` in this file. Pin the name to ours.
typealias RGBColor = HarnessTheme.RGBColor

private struct SurfaceFrameBuildConfiguration: Sendable {
    var resolver: CellColorResolver
    var cursorColor: RGBColor
    var cursorTextColor: RGBColor?
    var canvasOpacity: Float
    var colorRendering: TerminalColorRenderingMode
    var colorGamut: TerminalColorGamut
    var cursorStyle: CursorStyle
    var selectionBackground: RGBColor?
    var selectionForeground: RGBColor?
    var promptGutterEnabled: Bool

    func makeBuilder() -> FrameBuilder {
        FrameBuilder(
            resolver: resolver,
            cursorColor: cursorColor,
            cursorTextColor: cursorTextColor,
            canvasOpacity: canvasOpacity,
            colorRendering: colorRendering,
            colorGamut: colorGamut,
            cursorStyle: cursorStyle,
            selectionBackground: selectionBackground,
            selectionForeground: selectionForeground,
            promptGutterEnabled: promptGutterEnabled
        )
    }
}

struct SurfaceFrameBuildResult: Sendable {
    var generation: UInt64
    var frame: TerminalFrame
    var damage: TerminalDamage?
    /// Non-zero for a pure scrollback scroll: the frame is the previous one shifted by this many
    /// viewport rows (`FrameBuilder.buildShifted`), and the renderer should rotate its row cache
    /// by the same amount instead of re-encoding the kept rows. `damage` then lists exactly the
    /// newly-exposed rows.
    var scrollShift: Int = 0
    /// True when the frame carries the display-only smooth-scroll peek row: one extra row below
    /// the viewport (built whenever the view is scrolled into history) that the fraction translate
    /// reveals. The renderer clips it behind the grid box at fraction 0.
    var hasPeekRow: Bool = false
    var frameBuildNanos: UInt64
    var clearColor: RenderColor
}

private final class SurfaceColorProviderState: @unchecked Sendable {
    private let lock = NSLock()
    private var foreground = RGBColor(red: 255, green: 255, blue: 255)
    private var background = RGBColor(red: 0, green: 0, blue: 0)
    private var cursor = RGBColor(red: 255, green: 255, blue: 255)
    private var palette: [RGBColor] = []

    func update(foreground: RGBColor, background: RGBColor, cursor: RGBColor, palette: [RGBColor]) {
        lock.lock()
        self.foreground = foreground
        self.background = background
        self.cursor = cursor
        self.palette = palette
        lock.unlock()
    }

    func resolve(_ role: TerminalColorRole) -> (r: UInt8, g: UInt8, b: UInt8)? {
        lock.lock()
        defer { lock.unlock() }
        let c: RGBColor
        switch role {
        case .foreground: c = foreground
        case .background: c = background
        case .cursor: c = cursor
        case let .palette(i):
            guard i >= 0, i < palette.count else { return nil }
            c = palette[i]
        }
        return (c.red, c.green, c.blue)
    }
}

final class SurfaceEmulatorState: @unchecked Sendable {
    private let specific = DispatchSpecificKey<Void>()

    let emulator: TerminalEmulator
    let queue: DispatchQueue
    var lastPlainFrame: TerminalFrame?
    /// The `renderGeneration` the cached `lastPlainFrame` was built against. The worker refuses to
    /// reuse a frame from a different generation, so a resize/theme/detach that bumps the generation
    /// (and resets the emulator/grid) can never diff new damage against a frame built for the old
    /// grid — which would show torn/stale rows. Belt-and-suspenders alongside `resetPlainFrame()`.
    var lastPlainFrameGeneration: UInt64 = 0
    /// Scroll-delta reuse source: the last overlay-free, image-free viewport frame (live at
    /// offset 0 or a scrolled history view), the scroll offset it was built at, and its
    /// generation. A pure scroll between two such frames rebuilds via
    /// `FrameBuilder.buildShifted` — re-resolving only the newly-exposed rows — instead of a
    /// full rebuild. Touched only on the serial queue (same discipline as `lastPlainFrame`).
    var lastViewportFrame: TerminalFrame?
    var lastViewportOffset = 0
    var lastViewportGeneration: UInt64 = 0
    /// Per-row fingerprints of the last build's cell-overlay pass (selection / find / IME
    /// preedit shading) — see `overlayRowKeys`. The next build re-encodes exactly the rows
    /// whose fingerprint changed, so a selection drag costs the rows it crossed, not the grid.
    /// Touched only on the serial queue (same discipline as `lastPlainFrame`).
    var lastOverlayKeys: [Int: UInt64] = [:]

    /// Latest-wins coalescing for async frame builds. Every `renderNowOffMain()` claims a token; a
    /// build whose token is no longer the latest (a newer build is already queued behind it on this
    /// serial queue) skips itself. The superseding build still sees all accumulated damage (the
    /// skipped build never called `consumeDamage`), so no rows are lost — a burst of marks coalesces
    /// to one build instead of N stale ones. Guarded by `tokenLock` because it's claimed on main and
    /// checked on the worker.
    private let tokenLock = NSLock()
    private var latestFrameToken: UInt64 = 0

    func claimFrameToken() -> UInt64 {
        tokenLock.lock(); defer { tokenLock.unlock() }
        latestFrameToken &+= 1
        return latestFrameToken
    }

    func isLatestFrameToken(_ token: UInt64) -> Bool {
        tokenLock.lock(); defer { tokenLock.unlock() }
        return token == latestFrameToken
    }

    /// Separate token namespace for the live-resize preview builds. The preview must NOT share
    /// `latestFrameToken` with the output pipeline: during an ANIMATED resize (sidebar slide,
    /// tiling — no live-resize bracket, so output presents are not deferred) the two pipelines
    /// run concurrently, and a shared counter would let an output build silently cancel an
    /// in-flight re-wrap preview (and vice versa, dropping an echo frame). Each pipeline
    /// coalesces latest-wins against itself only.
    private var latestPreviewToken: UInt64 = 0

    func claimPreviewToken() -> UInt64 {
        tokenLock.lock(); defer { tokenLock.unlock() }
        latestPreviewToken &+= 1
        return latestPreviewToken
    }

    func isLatestPreviewToken(_ token: UInt64) -> Bool {
        tokenLock.lock(); defer { tokenLock.unlock() }
        return token == latestPreviewToken
    }

    /// The latest grid size a resize commit requested, applied-and-cleared by the NEXT output/commit
    /// build to run on the queue (`applyPendingResize` at the top of `renderNowOffMain`'s build).
    /// Decoupling "which size to materialize" from "which build wins the latest-wins token" is what
    /// lets mid-drag output presents coexist with live-resize commits: an output build that
    /// supersedes an in-flight commit build (newer token → the commit skips before its resize)
    /// still carries the resize forward, so the emulator can never strand at the old size after
    /// the PTY vote went out. Touched ONLY on `queue` (the setters below dispatch there; the
    /// queue's FIFO orders a `setPendingResize` ahead of any build dispatched after it).
    private var pendingResize: (cols: Int, rows: Int)?

    /// Enqueue a resize target from main. The preview pipeline must never call the apply side —
    /// previews are non-mutating reads at an explicit target size.
    func setPendingResize(_ size: (cols: Int, rows: Int)) {
        queue.async { [self] in pendingResize = size }
    }

    /// Drop an unapplied target (detach/re-host: a stale size must not apply to a re-hosted view).
    func clearPendingResize() {
        queue.async { [self] in pendingResize = nil }
    }

    /// On-queue: materialize any pending resize and clear it. Idempotent across builds; returns
    /// whether the grid dimensions actually changed so the caller can drop its reuse caches.
    func applyPendingResize() -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let size = pendingResize else { return false }
        pendingResize = nil
        emulator.resize(cols: size.cols, rows: size.rows)
        return true
    }

    /// Test seam: the staged-but-unapplied resize target (read on the queue).
    func pendingResizeForTesting() -> (cols: Int, rows: Int)? {
        sync { _ in pendingResize }
    }

    init(columns: Int, rows: Int) {
        self.emulator = TerminalEmulator(cols: columns, rows: rows)
        self.queue = DispatchQueue(label: "com.robert.harness.terminal-surface.emulator", qos: .userInteractive)
        queue.setSpecific(key: specific, value: ())
    }

    func sync<T>(_ body: (TerminalEmulator) -> T) -> T {
        if DispatchQueue.getSpecific(key: specific) != nil {
            return body(emulator)
        }
        return queue.sync {
            body(emulator)
        }
    }

    func async(_ body: @escaping @Sendable (TerminalEmulator) -> Void) {
        queue.async { [self] in
            body(emulator)
        }
    }

    func resetPlainFrame() {
        sync { _ in
            lastPlainFrame = nil
            lastViewportFrame = nil
            lastOverlayKeys = [:]
        }
    }
}

/// The native, self-contained terminal surface: a `CAMetalLayer`-backed `NSView` that
/// drives a `TerminalEmulator` and draws it with `TerminalMetalRenderer`. This is the
/// replacement for the previous renderer's view — bytes in via `receive(_:)`, input out
/// via `onInput`, grid-size changes via `onResize`.
///
/// Scope: GPU rendering with accurate sRGB output by default, opt-in converted Display-P3
/// vivid color, keyboard input, live resize, PTY responses (DSR/DA), mouse reporting,
/// selection, scrollback, copy mode, file-drop path insertion, IME, inline images, and
/// shell-integration marks.
@MainActor
public final class HarnessTerminalSurfaceView: NSView {
    private static let legacyFilenamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    private static let droppedPathPasteboardTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        legacyFilenamesPasteboardType,
        .tiff,
        .png,
    ]

    static func droppedFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) ?? []
        urls.append(contentsOf: objects.compactMap { object in
            if let url = object as? URL, url.isFileURL { return url }
            if let url = object as? NSURL, (url as URL).isFileURL { return url as URL }
            return nil
        })

        if let filenames = pasteboard.propertyList(forType: legacyFilenamesPasteboardType) as? [String] {
            urls.append(contentsOf: filenames.map { URL(fileURLWithPath: $0) })
        }

        var seen = Set<String>()
        return urls.compactMap { url in
            let standardized = url.standardizedFileURL
            guard seen.insert(standardized.path).inserted else { return nil }
            return standardized
        }
    }

    static func shellQuotedPath(_ path: String) -> String {
        ShellQuoting.quote(path)
    }

    static func droppedPathText(for urls: [URL]) -> String {
        urls.map { shellQuotedPath($0.path) }.joined(separator: " ")
    }

    /// Bytes the terminal produces for the PTY (typed input, key sequences, DSR/DA).
    public var onInput: ((Data) -> Void)?
    /// New grid size after a resize (columns, rows) — the host forwards this to the daemon.
    public var onResize: ((Int, Int) -> Void)?
    /// Fires while the grid size changes during a resize so the host can show a dimensions HUD.
    /// `committed` is false for the live (mid-drag) tick and true once the size settles. Never
    /// fires for the terminal's initial sizing live tick (opening a window isn't a resize).
    public var onGridSizeWillChange: ((_ cols: Int, _ rows: Int, _ committed: Bool) -> Void)?
    /// Fires when the scrollback position changes (wheel, page keys, jump-to-prompt) so the host
    /// can show a transient scrollbar. `topLine` is the buffer index of the top visible row,
    /// `totalLines` the whole buffer (history + viewport), `visibleRows` the viewport height.
    public var onScrollChanged: ((_ topLine: Int, _ totalLines: Int, _ visibleRows: Int) -> Void)?
    /// Window/tab title (OSC 0 / OSC 2) — the host forwards this to its delegate.
    public var onTitle: ((String) -> Void)?
    /// ConEmu progress report (OSC 9;4) — the host forwards this to its delegate, which
    /// drives the tab's working indicator (Claude Code 2.0+ keep-alives it per turn).
    public var onProgress: ((TerminalProgressReport) -> Void)?
    /// Reported working directory (OSC 7) — the host forwards this to its delegate.
    public var onPwd: ((String) -> Void)?
    /// Last reported working directory, kept for ⌘-click file path resolution.
    private(set) var currentCwd: String?
    /// Terminal bell (BEL) — the host forwards this to its delegate.
    public var onBell: (() -> Void)?
    /// A shell command finished (OSC 133), with its run duration + exit code — the host forwards
    /// this for the long-running-command-finished notification.
    public var onCommandFinished: ((_ duration: TimeInterval, _ exitCode: Int?) -> Void)?
    /// Desktop notification requested by a program (OSC 9 → nil title; OSC 777 → title+body)
    /// — the host forwards this to its delegate.
    public var onDesktopNotification: ((_ title: String?, _ body: String) -> Void)?
    /// This surface became effectively focused (first responder × key window). The host
    /// bridges it to the focus delegate so focusing a pane by click or app re-activation —
    /// not only a programmatic tab switch — clears its pending notification.
    public var onBecameFocused: (() -> Void)?
    /// Copied selection text — the host mirrors it into the daemon paste buffer (the
    /// system pasteboard is written here directly).
    public var onCopy: ((String) -> Void)?
    /// Optional per-frame renderer stats sink for diagnostics/benchmarks.
    public var onRenderStats: ((TerminalRenderStats) -> Void)?
    /// Whether a program may set the system clipboard via OSC 52 (tmux
    /// `set-clipboard`). The host sets this from the option; default on.
    public var allowProgramClipboardAccess = true

    let emulatorState: SurfaceEmulatorState
    private let colorProviderState = SurfaceColorProviderState()
    let inputEncoder = InputEncoder()
    let metalLayer = CAMetalLayer()
    var renderer: TerminalMetalRenderer?

    var frameBuilder: FrameBuilder
    private var frameBuildConfiguration: SurfaceFrameBuildConfiguration
    private var colorRendering: TerminalColorRenderingMode
    private var colorGamut: TerminalColorGamut
    var offMainParserFramePipelineEnabled = true // production default; always set from init
    private var renderGeneration: UInt64 = 0
    /// The last frame presented on the main thread, kept so a live resize can re-present it at the
    /// new drawable size WITHOUT touching the emulator serial queue (which, during heavy output, is
    /// busy parsing). During a drag the grid content is unchanged — reflow + SIGWINCH is debounced
    /// to drag-end (`scheduleResizeCommit`) — so stretching the last frame is exactly correct and
    /// never blocks main behind the parser. Main-thread only (written in `presentBuiltFrame`).
    var lastPresentedResult: SurfaceFrameBuildResult?
    /// True when the renderer's row-instance cache verifiably holds exactly
    /// `lastPresentedResult.frame`'s rows — i.e. the last renderer encode was of that frame through
    /// the cache-updating path (non-nil damage, no images). Then `repaintLastFrame` can present with
    /// EMPTY damage and reuse every row (`encodedRows == 0`, zero-copy instance bind): under the
    /// drag-frozen origin all cache keys are stable, so the per-tick cost collapses to the viewport
    /// uniform + draw. Anything that lets the cache and the frame disagree — a preview replacing the
    /// frame without a present, a dropped present wiping the cache, an overlay/image frame bypassing
    /// it, a renderer rebuild — clears the flag, and the next repaint pays one cache-populating full
    /// rebuild before ticks turn free again. Main-thread only, like `lastPresentedResult`.
    private var lastPresentedResultIsRendererCoherent = false
    /// The (cols, rows) the live-resize preview was last built for, so a continuous drag rebuilds the
    /// re-wrap preview only when the cell count actually changes (sub-cell drag frames re-present the
    /// cached preview at the new drawable size). Reset on commit so the next drag starts fresh.
    private var previewCols = 0
    private var previewRows = 0
    /// Real-time live resize (Ghostty parity). When true, a window-edge drag commits the
    /// authoritative grid reflow + PTY `SIGWINCH` at every cell boundary so interactive programs
    /// (vim/htop/tmux) redraw continuously, instead of deferring the reflow to drag-end. The
    /// non-mutating re-wrap preview still rides under it for instant feedback. Set from
    /// `configureAppearance(liveResizeReflow:)`; the escape-hatch setting defaults it on. When
    /// false the surface keeps the legacy defer-to-release behavior.
    private var liveResizeReflowEnabled = true
    /// The (cols, rows) last handed to the PTY via `onResize`, so a mid-drag commit only fires a
    /// `SIGWINCH` when the cell count actually changed from the last one sent (a within-column drag
    /// frame sends nothing). Reset at drag end so the next drag starts fresh.
    private var lastSentPTYSize: (cols: Int, rows: Int)?
    private var fontFamily: String
    private var fontSize: CGFloat
    /// The canvas (default) background — used as the Metal clear color and (at
    /// `canvasOpacity`) for default-bg cells. Resolved by the host through the same
    /// `ThemeManager.resolvedCanvas` the chrome uses, so terminal and chrome never seam.
    var canvasBackground: RGBColor
    /// 0...1. < 1 makes the canvas translucent (the window blur shows through); program
    /// output backgrounds and glyphs stay opaque.
    var canvasOpacity: Float
    /// Window padding in points (`window-padding-x/y`); converted to device
    /// pixels and used both as the grid inset and the renderer's draw origin.
    private var paddingPointsX: CGFloat = 0
    private var paddingPointsY: CGFloat = 0
    /// Center the grid by splitting the sub-cell remainder onto both sides (`window-padding-balance`).
    private var paddingBalanced = true
    /// Device-pixel grid origin (padding × scale, plus the centering half-offset when balanced).
    /// Reused by `renderNow` as the draw origin and by mouse→cell mapping via `gridOriginPoints*`.
    var originOffsetX = 0
    var originOffsetY = 0
    /// The grid's left/top origin in points (device-px `originOffset` ÷ backing scale). Equals the
    /// window padding when unbalanced; when balanced it includes the centering half-offset, so
    /// mouse hit-testing, link-hover, and IME anchoring stay aligned with the centered grid.
    var gridOriginPointsX: CGFloat { CGFloat(originOffsetX) / (window?.backingScaleFactor ?? 2.0) }
    var gridOriginPointsY: CGFloat { CGFloat(originOffsetY) / (window?.backingScaleFactor ?? 2.0) }
    /// Cursor shape + blink (`cursor-style` / `cursor-style-blink`).
    private var cursorStyle: CursorStyle = .block
    var cursorBlinkEnabled = true
    /// Blink phase: false hides the cursor on the off-beat. Reset to true on activity.
    var cursorBlinkVisible = true
    var blinkTimer: Timer?
    /// First-responder state — the cursor only blinks while focused.
    var focused = false
    /// Whether the host window is key. Combined with `focused` for the user-visible focus
    /// state (hollow cursor, blink) and DECSET 1004 focus reporting — a first responder in a
    /// deactivated window is not focused.
    private var windowIsKey = false
    private var windowKeyObservers: [NSObjectProtocol] = []
    /// Last focus value reported via DECSET 1004, so window-key and first-responder
    /// transitions never double-report the same state.
    var lastReportedFocus: Bool?
    var effectivelyFocused: Bool { focused && windowIsKey }
    /// Mouse selection endpoints (anchor = where the drag started, head = current). A
    /// `SelectionRegion` is derived from these (expanded by granularity) for highlight + extraction.
    var selectionAnchor: (row: Int, column: Int)?
    var selectionHead: (row: Int, column: Int)?
    /// Selection unit set by click count: 1 = character, 2 = word, 3 = line. A drag extends by
    /// the unit; word/line ranges reuse copy-mode's word definition.
    enum SelectionGranularity { case character, word, line }
    var selectionGranularity: SelectionGranularity = .character
    /// Option-drag makes a rectangular (block) selection instead of a linear one.
    var selectionRectangular = false
    var selectionBackground: RGBColor?
    private var selectionForeground: RGBColor?
    /// Copy the selection to the pasteboard automatically when a drag ends.
    var copyOnSelect = false
    /// Confirm before pasting risky (multi-line / control-char) text when bracketed paste is off.
    var pasteProtection = true
    /// Scrollback offset in lines (0 = live bottom; >0 = scrolled up into history).
    var scrollOffset = 0
    /// Smooth-scroll sub-line position. The continuous scrollback position is
    /// `P = scrollOffset - scrollFraction` (lines): the frame is built at the integer
    /// `scrollOffset = ceil(P)` — one line further back — and translated UP by
    /// `scrollFraction` of a cell at present time (a vertex-stage uniform; render-only, never
    /// baked into instances). The peek row fills the gap the translate opens at the bottom.
    /// Always 0 at the live bottom and whenever resting exactly on a line; every line-based
    /// consumer (hit-testing, copy mode, find, pinning, mouse reporting) keeps reading the
    /// integer `scrollOffset`.
    var scrollFraction: CGFloat = 0
    /// Sub-line wheel remainder carried between scroll events so small trackpad movements
    /// accumulate into whole lines instead of each snapping a full line (see `consumeWheelLines`).
    var wheelLineRemainder: CGFloat = 0
    /// Horizontal counterpart for mouse-reported wheel-left/right (see `consumeWheelColumns`).
    var wheelColumnRemainder: CGFloat = 0
    /// Lines per notch for a discrete (non-precise) mouse wheel — the classic 3-line step.
    static let mouseWheelLinesPerTick: CGFloat = 3
    /// Test-only: counts main-thread consume hops (one per `receiveOffMain` main bounce). The
    /// latency-under-load benchmark reads this to measure how aggressively the consume path
    /// coalesces a flood of small chunks. Never read in production; a single `Int` add on main.
    var testingMainHopCount = 0
    /// Canvas foreground — used to draw IME preedit (marked) text over the grid.
    var canvasForeground: RGBColor = RGBColor(red: 255, green: 255, blue: 255)
    /// Resolved cursor + 16-color palette, surfaced to programs via OSC 10/11/12/4 *queries*
    /// (`emulator.colorProvider`) for light/dark theme detection.
    private var canvasCursor: RGBColor = RGBColor(red: 255, green: 255, blue: 255)
    private var ansiPalette16: [RGBColor] = []
    /// In-progress IME composition (preedit). Empty when not composing.
    var markedText = ""
    /// Glyph coverage gamma: 1 = native blending; < 1 = gamma-correct (thicker) text.
    var glyphGamma: Float = 1
    /// Programming-font ligatures via CoreText run shaping.
    var ligaturesEnabled = true
    /// Draw the OSC 133 prompt gutter stripe. Off by default (a user opt-in).
    private var promptGutterEnabled = false

    var columns: Int = 80
    var rows: Int = 24
    /// The last frame built on the plain live path (no scrollback/selection/copy-mode/IME), kept
    /// so the next plain render can reuse unchanged rows via the engine's dirty-row damage. Set to
    /// nil whenever a non-plain frame is drawn or the appearance changes, forcing a full rebuild.
    private var lastPlainFrame: TerminalFrame?
    /// Coalesces renders to display cadence: `scheduleRender` marks dirty and wakes the link, which
    /// presents at most one frame per tick (resize/first paint/2026-timeout force immediately). Wired
    /// to `renderNow` in `init`.
    private lazy var scheduler = RenderScheduler(
        render: { [weak self] in self?.renderNow() },
        renderSynchronously: { [weak self] in self?.renderNowSynchronous() }
    )
    /// Main-thread display-cadence source (macOS 14+ `NSView.displayLink(target:selector:)`). Created
    /// when the view enters a window, paused while idle, invalidated on detach. nil when not in a
    /// window. Named `renderLink` so it doesn't shadow the `NSView.displayLink(...)` factory.
    private var renderLink: CADisplayLink?
    /// True once the grid has been sized from a real layout — the first sizing commits
    /// immediately (so the terminal opens at the right size); later changes coalesce.
    private var hasSizedGrid = false
    /// Pending coalesced grid+PTY resize. A sidebar slide / window drag calls `layout()`
    /// every frame; committing the grid reflow + PTY `SIGWINCH` each time storms the shell
    /// (fish/zsh redraw their prompt faster than they coalesce → overlapping garbage). The
    /// drawable still updates every frame for a smooth visual; the grid + PTY commit once the
    /// size settles.
    private var resizeCommitWork: DispatchWorkItem?
    /// Grid origin captured at `viewWillStartLiveResize`, held for the whole drag. Balanced
    /// padding re-centers the grid on *every* layout, so a pixel-by-pixel drag shifts the text
    /// ±1px per frame — a visible shimmer. Freezing the origin anchors the content for the
    /// duration (Ghostty's behavior: leftover sub-cell space accumulates at the right/bottom)
    /// and `viewDidEndLiveResize` re-centers exactly once for the settled size.
    private var liveResizeFrozenOrigin: (x: Int, y: Int)?
    /// Safety valve for DEC 2026 synchronized output: a program that enters a synchronized
    /// frame but never ends it must not freeze the display, so we force-present after this.
    private var syncTimeout: DispatchWorkItem?
    private let syncTimeoutInterval: TimeInterval = 0.15

    // MARK: Copy mode (in-pane overlay)
    /// Active copy-mode model (nil = not in copy mode). Driven by the shared
    /// `CopyModeReducer` over this view's own emulator (which holds the full scrollback), so
    /// the GUI overlay and the ssh compositor share one implementation.
    var copyMode: CopyModeState?
    /// Merged copy-mode key tables (defaults + user `keybindings.json`), loaded on entry.
    var copyModeTables: KeyTableSet?
    /// In-progress search query (nil = not entering a search). Shown in the status row.
    var copyModeSearchEntry: String?
    /// `mode-keys` option value (`vi` / `emacs`); the host sets it from the daemon option.
    public var copyModeKeys: String = "vi"
    public var isInCopyMode: Bool { copyMode != nil }

    // MARK: Find (in-scrollback search bar)
    /// True while the Cmd+F find bar is open; gates highlight rendering + scroll-to-match.
    var findActive = false
    /// All matches for the current query, in buffer-line order (history + viewport space).
    var findMatches: [TerminalBufferMatch] = []
    /// Index of the "current" match within `findMatches` (the one we scrolled to).
    var findCurrentIndex = 0
    /// Reports `(current, total)` to the host so the find bar can show "n of m" (0,0 = none).
    public var onFindResultsChanged: ((_ current: Int, _ total: Int) -> Void)?

    // MARK: Link hover (⌘-hover affordance for ⌘-click open)
    /// The link span under the pointer while ⌘ is held: a grid row + half-open column range.
    /// Drives the underline layer and the pointing-hand cursor. nil when not hovering a link.
    var hoveredLink: (row: Int, columns: Range<Int>)?
    /// Underline drawn beneath the hovered link. A sublayer of the Metal layer so it composites
    /// above the terminal content without intercepting clicks (a subview would eat the ⌘-click).
    let linkUnderlineLayer = CALayer()
    var trackingArea: NSTrackingArea?
    /// Physical modifier keycodes currently held — used to tell press from release in
    /// `flagsChanged` (which fires for both, with no inherent direction).
    var pressedModifierKeyCodes: Set<UInt16> = []

    public init(
        themeName: String = ThemeManager.defaultThemeName,
        fontFamily: String = "Menlo",
        fontSize: CGFloat = 14,
        vivid: Bool = false,
        colorRendering: TerminalColorRenderingMode? = nil,
        colorGamut: TerminalColorGamut = .auto,
        offMainParserFramePipeline: Bool = true,
        liveResizeReflow: Bool = true
    ) {
        let theme = HarnessThemeCatalog.theme(named: themeName)
            ?? HarnessThemeCatalog.theme(named: ThemeManager.defaultThemeName)!
        let resolvedColorRendering = colorRendering ?? (vivid ? .vivid : .accurate)
        let resolvedGamut = TerminalColorGamut.resolved(
            renderingMode: resolvedColorRendering,
            requested: colorGamut
        )
        let resolver = CellColorResolver(theme: theme)
        // Baseline appearance; the host immediately overrides via configureAppearance.
        self.frameBuilder = FrameBuilder(
            resolver: resolver,
            cursorColor: theme.cursor ?? theme.foreground,
            cursorTextColor: theme.cursorText,
            colorRendering: resolvedColorRendering,
            colorGamut: resolvedGamut
        )
        self.frameBuildConfiguration = SurfaceFrameBuildConfiguration(
            resolver: resolver,
            cursorColor: theme.cursor ?? theme.foreground,
            cursorTextColor: theme.cursorText,
            canvasOpacity: 1,
            colorRendering: resolvedColorRendering,
            colorGamut: resolvedGamut,
            cursorStyle: .block,
            selectionBackground: nil,
            selectionForeground: nil,
            promptGutterEnabled: true
        )
        self.canvasBackground = theme.background
        self.canvasOpacity = 1
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.colorRendering = resolvedColorRendering
        self.colorGamut = resolvedGamut
        self.offMainParserFramePipelineEnabled = offMainParserFramePipeline
        self.liveResizeReflowEnabled = liveResizeReflow
        self.emulatorState = SurfaceEmulatorState(columns: columns, rows: rows)
        super.init(frame: .zero)
        registerForDraggedTypes(Self.droppedPathPasteboardTypes)
        colorProviderState.update(
            foreground: theme.foreground,
            background: theme.background,
            cursor: theme.cursor ?? theme.foreground,
            palette: theme.palette
        )
        configureLayer()
        configureEmulatorCallbacks()
        // Defer the renderer build: at init the view has no window, so
        // `window?.backingScaleFactor` would fall back to 2.0 and compile the Metal
        // pipeline at the wrong scale — work immediately thrown away when the host
        // calls `configureAppearance` and again at `viewDidMoveToWindow` (real scale).
        // Every render/layout path guards `renderer == nil`, and the first real render
        // only happens once the view is in a window, so building there is correct and
        // avoids a discarded shader/pipeline compile per surface.
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }

    // MARK: - Public API

    /// Feed PTY output bytes into the emulator and schedule a redraw.
    public func receive(_ data: Data) {
        if offMainParserFramePipelineEnabled {
            receiveOffMain(data)
            return
        }
        let beforeHistory = emulatorState.emulator.historyCount
        emulatorState.emulator.feed(data)
        // If the user is scrolled up, stay anchored on the same content as new lines push
        // into history; at the bottom (offset 0) we naturally follow new output.
        if scrollOffset > 0 {
            let added = emulatorState.emulator.historyCount - beforeHistory
            if added > 0 { scrollOffset = min(emulatorState.emulator.historyCount, scrollOffset + added) }
        }
        wakeCursor()
        // DEC 2026 synchronized output: hold the last presented frame while the program is
        // mid-update (no tearing), and present atomically the moment it ends the batch — which
        // is exactly when this chunk leaves `synchronizedOutput` false. A timeout guards a
        // program that never closes the update.
        if emulatorState.emulator.modes.synchronizedOutput {
            scheduler.setSynchronized(true) // hold the display tick mid-batch (no tearing)
            armSyncTimeout()
        } else {
            syncTimeout?.cancel(); syncTimeout = nil
            // Releasing 2026 marks dirty; the batched frame presents atomically at the next tick.
            scheduler.setSynchronized(false)
            wakeDisplayLink()
            // Low-latency echo: present this chunk now instead of waiting up to a full display
            // interval. Coalesced to one paint per interval during a burst by the scheduler.
            scheduler.presentNow()
        }
    }

    private func receiveOffMain(_ data: Data) {
        emulatorState.async { [weak self] emulator in
            let beforeHistory = emulator.historyCount
            FrameSignposter.shared.interval("parse") { emulator.feed(data) }
            let afterHistory = emulator.historyCount
            let modesAfterFeed = emulator.modes
            let altScreenAfterFeed = emulator.isAlternateScreenActive
            let synchronized = modesAfterFeed.synchronizedOutput
            FrameSignposter.shared.event("mainHop")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.testingMainHopCount &+= 1
                // Refresh the input-side mirror (see `inputModes()`); chunks hop in FIFO order, so
                // the mirror always converges on the emulator's latest state.
                self.inputModesMirror = modesAfterFeed
                self.altScreenMirror = altScreenAfterFeed
                self.historyCountMirror = afterHistory
                if self.scrollOffset > 0 {
                    let added = afterHistory - beforeHistory
                    if added > 0 { self.scrollOffset = min(afterHistory, self.scrollOffset + added) }
                }
                self.wakeCursor()
                if synchronized {
                    self.scheduler.setSynchronized(true)
                    self.armSyncTimeout()
                } else {
                    self.syncTimeout?.cancel(); self.syncTimeout = nil
                    self.scheduler.setSynchronized(false)
                    self.wakeDisplayLink()
                    // Low-latency echo (off-main): kick the frame build now rather than at the next
                    // tick. renderNowOffMain builds on the emulator queue and presents on main; the
                    // renderGeneration guard drops any stale build so there's no double present.
                    self.scheduler.presentNow()
                }
            }
        }
    }

    private func armSyncTimeout() {
        guard syncTimeout == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.syncTimeout = nil
            // Safety valve: a program that set 2026 but never cleared it must not freeze the
            // display, so force-present past the hold.
            self?.scheduler.forceRender()
        }
        syncTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + syncTimeoutInterval, execute: work)
    }

    public func receive(_ text: String) { receive(Data(text.utf8)) }

    func testingReadGridSnapshot() -> TerminalGridSnapshot {
        emulatorSync { $0.readGrid() }
    }

    func testingWaitForEmulatorIdle() {
        // Drain the parse queue AND refresh the main-thread mirrors the parse hop would have
        // refreshed — tests call this in place of spinning the runloop, so the mirrors must not
        // lag the drained state (smooth scrolling clamps against `historyCountMirror`).
        let history = emulatorState.sync { $0.historyCount }
        historyCountMirror = history
    }

    func testingInputModes() -> TerminalModes { inputModes() }

    /// Test seam: drive the window-key half of `effectivelyFocused` (the real value comes from
    /// `NSWindow` key-state notifications, which are awkward to trigger headlessly). Mirrors the
    /// `didBecomeKey`/`didResignKey` observers — set the flag, then re-evaluate focus state.
    func testingSetWindowIsKey(_ isKey: Bool) {
        windowIsKey = isKey
        focusStateChanged()
    }

    func testingResizeGrid(cols: Int, rows: Int) {
        commitGridSize(cols: cols, rows: rows)
        // The commit stages the reflow for the next output/commit build to materialize; headless
        // there is no renderer, so no build ever runs — apply the staged target directly (the
        // exact step the first build performs) so tests observe the resize synchronously.
        emulatorState.sync { _ in _ = emulatorState.applyPendingResize() }
    }

    var testingRenderSynchronized: Bool { scheduler.synchronized }
    var testingRenderPending: Bool { scheduler.needsRender }

    // Live-resize seams (glitchless-resize behavior is asserted headlessly: no window, no Metal).
    var testingPresentsWithTransaction: Bool { metalLayer.presentsWithTransaction }
    var testingLiveResizeFrozenOrigin: (x: Int, y: Int)? { liveResizeFrozenOrigin }
    var testingGridSize: (cols: Int, rows: Int) { (columns, rows) }
    var testingHasPendingResizeCommit: Bool { resizeCommitWork != nil }
    func testingScheduleResizeCommit(cols: Int, rows: Int) { scheduleResizeCommit(cols: cols, rows: rows) }
    func testingRequestLiveResizeCommit(cols: Int, rows: Int) { requestLiveResizeCommit(cols: cols, rows: rows) }
    func testingSetLiveResizeReflow(_ enabled: Bool) { liveResizeReflowEnabled = enabled }
    var testingLiveResizeReflowEnabled: Bool { liveResizeReflowEnabled }
    var testingLastSentPTYSize: (cols: Int, rows: Int)? { lastSentPTYSize }
    func testingMarkGridSized() { hasSizedGrid = true }
    // pendingResize seams: the staged-but-unapplied reflow target, a direct driver for the
    // scheduler's async off-main entry (what a PTY output burst triggers mid-drag), and a queue
    // gate for staging deterministic build interleavings (e.g. an output build superseding a
    // commit build's frame token while both sit queued).
    var testingPendingResize: (cols: Int, rows: Int)? { emulatorState.pendingResizeForTesting() }
    func testingRenderNowOffMainAsync() { renderNowOffMain() }
    func testingBlockEmulatorQueue(until gate: DispatchSemaphore) {
        emulatorState.async { _ in gate.wait() }
    }
    // Window-hosted seams (the routing test drives real presents through a real Metal renderer).
    var testingOriginOffset: (x: Int, y: Int) { (originOffsetX, originOffsetY) }
    var testingHasRenderer: Bool { renderer != nil }
    var testingLastPresentScheduleNanos: UInt64 { renderer?.stats.presentScheduleNanos ?? 0 }
    // Full renderer stats for the frame-pacing harness (encodedRows/reusedRows/uploadBytes/...).
    var testingLastRenderStats: TerminalRenderStats? { renderer?.stats }
    var testingRepaintCacheCoherent: Bool { lastPresentedResultIsRendererCoherent }
    func testingRepaintLastFrame() -> Bool { repaintLastFrame() }
    // Async resize-preview seams: the current drag target the next landing preview must match,
    // and the renderer's device-pixel cell metrics (for stepping exactly one cell in benchmarks).
    var testingPreviewTarget: (cols: Int, rows: Int) { (previewCols, previewRows) }
    var testingCellPixelSize: (width: Int, height: Int) {
        (renderer?.cellPixelWidth ?? 0, renderer?.cellPixelHeight ?? 0)
    }
    /// Drive `presentResizePreview` directly with explicit (possibly stale) args — the main-hop
    /// guards only fire under racy interleavings production tests can't stage deterministically.
    /// Builds the preview synchronously, then lands it with the given token/target. Returns
    /// whether it was accepted (false = the guards dropped it).
    func testingPresentResizePreview(cols: Int, rows: Int, token: UInt64) -> Bool {
        let config = frameBuildConfiguration
        let bg = canvasBackground
        let opacity = canvasOpacity
        let generation = renderGeneration
        let result: SurfaceFrameBuildResult? = emulatorState.sync { emulator in
            guard let preview = emulator.previewViewportReflow(cols: cols, rows: rows) else { return nil }
            let builder = config.makeBuilder()
            let frame = builder.build(preview, region: nil, imageProvider: { emulator.image(for: $0) })
            return SurfaceFrameBuildResult(
                generation: generation, frame: frame, damage: nil,
                frameBuildNanos: 0, clearColor: builder.renderColor(bg, alpha: opacity)
            )
        }
        guard let result else { return false }
        return presentResizePreview(result, cols: cols, rows: rows, token: token)
    }
    func testingClaimPreviewToken() -> UInt64 { emulatorState.claimPreviewToken() }
    var testingRenderGeneration: UInt64 { renderGeneration }
    /// Neutralize the armed 60ms resize-commit debounce (matches `viewDidEndLiveResize`'s cancel
    /// semantics) so timing-sensitive assertions don't race it.
    func testingCancelPendingResizeCommit() {
        resizeCommitWork?.cancel()
        resizeCommitWork = nil
    }
    // Scroll-reuse seams: drive a synchronous build+present and a scrollback scroll headlessly.
    func testingForceRender() { scheduler.forceRender() }
    /// Programmatic selection for the cell-overlay tests (a mouse drag's end state).
    func testingSetSelection(
        anchor: (row: Int, column: Int)?, head: (row: Int, column: Int)?, rectangular: Bool = false
    ) {
        selectionAnchor = anchor
        selectionHead = head
        selectionRectangular = rectangular
        selectionGranularity = .character
        scheduleRender()
    }
    func testingSetSelectionColors(
        background: HarnessTheme.RGBColor?, foreground: HarnessTheme.RGBColor?
    ) {
        selectionBackground = background
        frameBuildConfiguration.selectionBackground = background
        frameBuildConfiguration.selectionForeground = foreground
    }
    func testingMakeFrameBuilder() -> FrameBuilder { frameBuildConfiguration.makeBuilder() }
    var testingLastPresentedFrame: TerminalFrame? { lastPresentedResult?.frame }
    var testingLastPresentedDamage: TerminalDamage? { lastPresentedResult?.damage }
    func testingSetWindowOccluded(_ occluded: Bool) { setWindowOccluded(occluded) }
    var testingIsOccluded: Bool { scheduler.isOccluded }
    // Smooth-scroll seams: continuous (sub-line) scrolling and the resulting offset/fraction split.
    func testingScrollByContinuous(lines: CGFloat) { scrollByContinuous(lines: lines) }
    var testingScrollPosition: (offset: Int, fraction: CGFloat) { (scrollOffset, scrollFraction) }
    // Drive one display-cadence tick (the scheduler's ASYNC render entry — the path the live-drag
    // hold defers); tests use it where the real CADisplayLink would fire.
    @discardableResult
    func testingSchedulerTick() -> Bool { scheduler.tick() }
    func testingScrollBy(lines: Int) { scrollBy(lines: lines) }

    /// The full appearance the host computes from settings + theme:
    /// - `canvasBackground/Foreground/cursor` come from `ThemeManager.resolvedCanvas`, so
    ///   the terminal canvas matches the chrome (no seam) regardless of theme-output mode.
    /// - `outputPalette` is the 16 ANSI colors for *program output*: the theme palette when
    ///   "apply theme to output" is on, otherwise the untouched default palette.
    /// - `canvasOpacity` < 1 makes the canvas translucent for the window blur.
    /// Rebuilds the renderer/atlas (font/colorspace) and the color resolver.
    public func configureAppearance(
        fontFamily: String,
        fontSize: CGFloat,
        vivid: Bool,
        colorRendering: TerminalColorRenderingMode? = nil,
        colorGamut: TerminalColorGamut = .auto,
        canvasBackgroundHex: String,
        canvasForegroundHex: String,
        cursorHex: String,
        outputPaletteHex: [String?],
        canvasOpacity: Float,
        cursorStyle: String,
        cursorBlink: Bool,
        paddingX: CGFloat,
        paddingY: CGFloat,
        paddingBalance: Bool = true,
        selectionBackgroundHex: String?,
        selectionForegroundHex: String?,
        cursorTextHex: String? = nil,
        copyOnSelect: Bool,
        pasteProtection: Bool = true,
        scrollbackLines: Int,
        linearBlending: Bool,
        textRendering: TerminalTextRenderingMode? = nil,
        ligatures: Bool,
        minimumContrast: Double = 1,
        boldIsBright: Bool = true,
        promptGutter: Bool = false,
        offMainParserFramePipeline: Bool = true,
        liveResizeReflow: Bool = true
    ) {
        liveResizeReflowEnabled = liveResizeReflow
        emulatorSync { $0.maxScrollbackLines = scrollbackLines }
        if offMainParserFramePipelineEnabled && !offMainParserFramePipeline {
            // Drain any queued parser/frame work before direct main-thread emulator access resumes.
            emulatorState.sync { _ in }
        }
        if offMainParserFramePipelineEnabled != offMainParserFramePipeline {
            offMainParserFramePipelineEnabled = offMainParserFramePipeline
            invalidateRenderGeneration()
        }
        let resolvedColorRendering = colorRendering ?? (vivid ? .vivid : .accurate)
        let resolvedGamut = TerminalColorGamut.resolved(
            renderingMode: resolvedColorRendering,
            requested: colorGamut
        )
        let resolvedTextRendering = textRendering ?? (linearBlending ? .crisp : .native)
        glyphGamma = resolvedTextRendering.glyphGamma
        ligaturesEnabled = ligatures
        promptGutterEnabled = promptGutter
        let bg = RGBColor(hex: canvasBackgroundHex) ?? RGBColor(red: 0, green: 0, blue: 0)
        let fg = RGBColor(hex: canvasForegroundHex) ?? RGBColor(red: 255, green: 255, blue: 255)
        let cursor = RGBColor(hex: cursorHex) ?? fg
        // Selection background: explicit setting/theme value, else a neutral slate.
        let selBg = selectionBackgroundHex.flatMap { RGBColor(hex: $0) }
            ?? RGBColor(red: 68, green: 78, blue: 102)
        let selFg = selectionForegroundHex.flatMap { RGBColor(hex: $0) }
        // Cursor-text (the glyph under a block cursor); nil falls back to the canvas bg.
        let cursorText = cursorTextHex.flatMap { RGBColor(hex: $0) }
        // 16 ANSI colors for program output; nil slots fall back to the default palette.
        let palette: [RGBColor] = (0 ..< 16).map { i in
            let hex = (i < outputPaletteHex.count ? outputPaletteHex[i] : nil)
                ?? ThemeManager.defaultBaselinePaletteHex[i]
            return RGBColor(hex: hex) ?? RGBColor(red: 0, green: 0, blue: 0)
        }
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.colorRendering = resolvedColorRendering
        self.colorGamut = resolvedGamut
        self.canvasBackground = bg
        self.canvasForeground = fg
        self.canvasCursor = cursor
        self.ansiPalette16 = palette
        self.canvasOpacity = max(0, min(1, canvasOpacity))
        self.cursorStyle = CursorStyle(rawValue: cursorStyle) ?? .block
        self.cursorBlinkEnabled = cursorBlink
        self.paddingPointsX = max(0, paddingX)
        self.paddingPointsY = max(0, paddingY)
        self.paddingBalanced = paddingBalance
        self.selectionBackground = selBg
        self.selectionForeground = selFg
        self.copyOnSelect = copyOnSelect
        self.pasteProtection = pasteProtection
        colorProviderState.update(foreground: fg, background: bg, cursor: cursor, palette: palette)
        let resolver = CellColorResolver(
            palette: ANSIPalette(base16: palette),
            defaultForeground: fg,
            defaultBackground: bg,
            boldBrightens: boldIsBright,
            minimumContrast: minimumContrast
        )
        self.frameBuildConfiguration = SurfaceFrameBuildConfiguration(
            resolver: resolver,
            cursorColor: cursor,
            cursorTextColor: cursorText,
            canvasOpacity: self.canvasOpacity,
            colorRendering: resolvedColorRendering,
            colorGamut: resolvedGamut,
            cursorStyle: self.cursorStyle,
            selectionBackground: selBg,
            selectionForeground: selFg,
            promptGutterEnabled: promptGutterEnabled
        )
        self.frameBuilder = FrameBuilder(
            resolver: resolver,
            cursorColor: cursor,
            cursorTextColor: cursorText,
            canvasOpacity: self.canvasOpacity,
            colorRendering: resolvedColorRendering,
            colorGamut: resolvedGamut,
            cursorStyle: self.cursorStyle,
            selectionBackground: selBg,
            selectionForeground: selFg,
            promptGutterEnabled: promptGutterEnabled
        )
        // Resolved colors/opacity changed — cached rows hold the old palette; force a full rebuild.
        lastPlainFrame = nil
        emulatorState.resetPlainFrame()
        invalidateRenderGeneration()
        restartBlinkTimer()
        // Opaque only when fully opaque; otherwise the layer must be non-opaque so the
        // window-wide blur shows through the translucent canvas.
        metalLayer.isOpaque = self.canvasOpacity >= 1
        metalLayer.colorspace = CGColorSpace(name: layerColorSpaceName)
        buildRenderer()
        updateGridSize()
        scheduleRender()
    }

    // MARK: - Setup

    func emulatorSync<T>(_ body: (TerminalEmulator) -> T) -> T {
        if offMainParserFramePipelineEnabled {
            return emulatorState.sync(body)
        }
        return body(emulatorState.emulator)
    }

    /// Main-thread mirror of the emulator state the *input* paths need (key/mouse/paste encoding),
    /// refreshed by every parsed chunk's main hop in `receiveOffMain`. Reading the mirror keeps a
    /// keystroke from doing a `queue.sync` against the parser — a held arrow key must never stall
    /// the main thread behind a busy parse. At most one in-flight chunk stale, the same window the
    /// old synchronous read had (those bytes were simply still unparsed then). Defaults match a
    /// fresh `TerminalEmulator`, so reads before the first output are correct.
    private var inputModesMirror = TerminalModes()
    private var altScreenMirror = false
    /// History line count, same mirror discipline: smooth scrolling clamps against it on EVERY
    /// precise wheel event (sub-line deltas included), so the clamp must not `queue.sync` behind
    /// a busy parse — that per-event stall is the scroll-jank class. At most one chunk stale;
    /// history only moves via parsed output, and the output-pinning hop re-aligns the offset with
    /// the real count anyway, so a momentarily-short clamp self-corrects on the next event.
    var historyCountMirror = 0

    /// The terminal modes input encoding should honor right now (mirror on the off-main pipeline;
    /// direct read when the emulator lives on main).
    func inputModes() -> TerminalModes {
        offMainParserFramePipelineEnabled ? inputModesMirror : emulatorState.emulator.modes
    }

    /// Whether the alternate screen is active, for input-side decisions (alternate scroll).
    func inputAltScreenActive() -> Bool {
        offMainParserFramePipelineEnabled ? altScreenMirror : emulatorState.emulator.isAlternateScreenActive
    }

    private func invalidateRenderGeneration() {
        renderGeneration &+= 1
        emulatorState.resetPlainFrame()
        lastPresentedResultIsRendererCoherent = false
    }

    private func configureLayer() {
        // Layer-hosting: assign the custom layer before enabling wantsLayer.
        layer = metalLayer
        wantsLayer = true
        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.pixelFormat = TerminalMetalRenderer.pixelFormat
        metalLayer.framebufferOnly = true
        metalLayer.isOpaque = true
        // Double-buffer (default is 3): triple-buffering adds up to one extra frame of swap latency,
        // which matters for keystroke echo. 2 still lets the next frame render while the current one
        // scans out. Kept in lockstep with the renderer's `maxFramesInFlight` (also 2) so the in-flight
        // semaphore and the drawable pool advertise the same depth — a deeper semaphore would just
        // block on `nextDrawable()` anyway. Keep `allowsNextDrawableTimeout` on (the default): both
        // render paths run `nextDrawable()` on the main thread/queue, so disabling the timeout would
        // let a fully occluded window or a stalled GPU block the main thread indefinitely (frozen
        // input + UI). With the timeout, a stall returns nil after ~1s; both paths re-arm the scheduler
        // on nil so the next display tick simply retries — nothing is lost, and main never wedges.
        metalLayer.maximumDrawableCount = 2
        metalLayer.allowsNextDrawableTimeout = true
        // Pin the grid to the top-left so any sub-cell remainder from flooring rows/cols
        // parks at the bottom-right instead of being centered into a hairline seam at the
        // top edge during live resize.
        metalLayer.contentsGravity = .topLeft
        // Tag the layer to match the frame builder's RGB output. Accurate mode stays sRGB;
        // vivid mode converts authored sRGB into Display-P3 before tagging the layer P3.
        metalLayer.colorspace = CGColorSpace(name: layerColorSpaceName)
        // Link-hover underline: a thin sublayer composited above the terminal content.
        linkUnderlineLayer.isHidden = true
        linkUnderlineLayer.backgroundColor = NSColor.linkColor.cgColor
        metalLayer.addSublayer(linkUnderlineLayer)
    }

    private var layerColorSpaceName: CFString {
        switch colorGamut {
        case .displayP3: return CGColorSpace.displayP3
        case .sRGB, .auto: return CGColorSpace.sRGB
        }
    }

    private func configureEmulatorCallbacks() {
        let emulator = emulatorState.emulator
        emulator.onResponse = { [weak self] data in
            // Terminal query replies (DSR/DA/XTVERSION/OSC color queries) must go back to the PTY
            // immediately, while the querying program is still in raw/no-echo mode. Hopping through
            // main can delay the reply until the program exits and the shell re-enables ECHO, which
            // makes the reply appear as literal text in the prompt.
            self?.onInput?(data)
        }
        emulator.onTitleChange = { [weak self] title in
            if Thread.isMainThread {
                self?.onTitle?(title)
            } else {
                DispatchQueue.main.async { [weak self] in self?.onTitle?(title) }
            }
        }
        emulator.onProgress = { [weak self] report in
            if Thread.isMainThread {
                self?.onProgress?(report)
            } else {
                DispatchQueue.main.async { [weak self] in self?.onProgress?(report) }
            }
        }
        emulator.onWorkingDirectoryChange = { [weak self] path in
            if Thread.isMainThread {
                self?.currentCwd = path
                self?.onPwd?(path)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.currentCwd = path
                    self?.onPwd?(path)
                }
            }
        }
        emulator.onBell = { [weak self] in
            if Thread.isMainThread {
                self?.onBell?()
            } else {
                DispatchQueue.main.async { [weak self] in self?.onBell?() }
            }
        }
        emulator.onCommandFinished = { [weak self] duration, exitCode in
            if Thread.isMainThread {
                self?.onCommandFinished?(duration, exitCode)
            } else {
                DispatchQueue.main.async { [weak self] in self?.onCommandFinished?(duration, exitCode) }
            }
        }
        emulator.onNotification = { [weak self] title, body in
            if Thread.isMainThread {
                self?.onDesktopNotification?(title, body)
            } else {
                DispatchQueue.main.async { [weak self] in self?.onDesktopNotification?(title, body) }
            }
        }
        emulator.onPointerShapeChange = { [weak self] shape in
            if Thread.isMainThread {
                self?.applyPointerShape(shape)
            } else {
                DispatchQueue.main.async { [weak self] in self?.applyPointerShape(shape) }
            }
        }
        emulator.onSetClipboard = { [weak self] text in
            guard !text.isEmpty else { return }
            if Thread.isMainThread {
                guard let self, self.allowProgramClipboardAccess else { return }
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                self.onCopy?(text)   // mirror into the daemon paste buffer, like a yank
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.allowProgramClipboardAccess else { return }
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    self.onCopy?(text)   // mirror into the daemon paste buffer, like a yank
                }
            }
        }
        // Answer OSC 10/11/12/4 color queries from the resolved theme (light/dark detection).
        let colorProviderState = colorProviderState
        emulator.colorProvider = { role in
            colorProviderState.resolve(role)
        }
    }

    /// Set the terminal identity the engine answers in XTVERSION (`CSI > q`) and secondary DA
    /// (`CSI > c`). Resolved by the host from the `terminal-identity` option (HarnessCore
    /// `TerminalIdentity`). Mutated on the emulator's serial queue since the replies are produced
    /// while feeding output off-main.
    public func setTerminalIdentity(name: String, version: String, daVersion: Int) {
        emulatorState.sync { emulator in
            emulator.terminalName = name
            emulator.terminalVersion = version
            emulator.secondaryDAVersion = daVersion
        }
    }

    /// Program-requested mouse pointer (OSC 22); nil = system default. Applied via cursor rects.
    private var programPointerCursor: NSCursor?

    private func applyPointerShape(_ shape: String?) {
        programPointerCursor = shape.flatMap(Self.cursor(forShape:))
        window?.invalidateCursorRects(for: self)
    }

    override public func resetCursorRects() {
        if let programPointerCursor {
            addCursorRect(bounds, cursor: programPointerCursor)
        } else {
            super.resetCursorRects()
        }
        // Added last so it wins over the base/program cursor for the link's region: ⌘-hovering
        // a link shows the pointing hand, signalling it's ⌘-clickable.
        if let rect = hoveredLinkRect() {
            addCursorRect(rect, cursor: .pointingHand)
        }
    }

    /// Map a CSI/OSC-22 pointer-shape name to an `NSCursor`. Unknown shapes fall back to the
    /// system default (nil) rather than guessing.
    private static func cursor(forShape name: String) -> NSCursor? {
        switch name.lowercased() {
        case "text", "ibeam", "xterm": return .iBeam
        case "pointer", "hand", "pointinghand": return .pointingHand
        case "default", "arrow", "left_ptr": return .arrow
        case "crosshair": return .crosshair
        case "grab", "openhand": return .openHand
        case "grabbing", "closedhand": return .closedHand
        default: return nil
        }
    }

    private func buildRenderer() {
        guard let device = metalLayer.device ?? MTLCreateSystemDefaultDevice() else { return }
        metalLayer.device = device
        let scale = window?.backingScaleFactor ?? 2.0
        renderer = TerminalMetalRenderer(device: device, fontFamily: fontFamily, fontSize: fontSize, scale: scale)
        // Tell the engine the real cell pixel size so inline-image cell footprints + cursor
        // advancement match what the renderer draws.
        if let renderer {
            emulatorSync { $0.setCellPixelSize(width: renderer.cellPixelWidth, height: renderer.cellPixelHeight) }
        }
        invalidateRenderGeneration()
    }

    // MARK: - Layout & rendering

    // No deinit teardown for the display link: a CADisplayLink strongly retains its target, so the
    // link keeps this view alive until `stopDisplayLink()` calls `invalidate()` (which also nils
    // `renderLink`). deinit therefore only runs once the link is already gone — accessing the
    // main-actor-isolated `renderLink` from a nonisolated deinit would also be a Swift 6 error.
    // `viewDidMoveToWindow(nil)` is the teardown hook (AppKit always calls it before dealloc).

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowKeyObservers.forEach(NotificationCenter.default.removeObserver(_:))
        windowKeyObservers.removeAll()
        if let window {
            StartupMetrics.shared.mark(.firstSurfaceAttached) // idempotent: first surface in a window
            buildRenderer() // pick up the real backing scale
            startDisplayLink()
            updateGridSize()
            restartBlinkTimer()
            scheduleRender()
            // Track the window's key state: focus (hollow cursor, blink, DECSET 1004
            // reports) means "first responder in the key window", not just first responder.
            windowIsKey = window.isKeyWindow
            let nc = NotificationCenter.default
            windowKeyObservers.append(nc.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.windowIsKey = true
                    self.focusStateChanged()
                }
            })
            windowKeyObservers.append(nc.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.windowIsKey = false
                    self.focusStateChanged()
                }
            })
            // Track occlusion (covered / minimized / other Space): an invisible pane must not
            // acquire drawables or present — Apple guidance, and it keeps a backgrounded build
            // or `tail -f` from waking the GPU at full cadence. Notification-driven only, NOT
            // seeded from the current state: a window that has never been ordered on screen
            // reads as non-visible (every headless test window, and briefly during launch), and
            // gating those would be wrong — the first real occlusion change corrects any
            // attach-while-covered case.
            windowKeyObservers.append(nc.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let window = self.window else { return }
                    self.setWindowOccluded(!window.occlusionState.contains(.visible))
                }
            })
            window.makeFirstResponder(self)
            focusStateChanged()
        } else {
            // Removed from the window (pane closed / re-mounted): stop the blink timer so
            // it doesn't keep the run loop (and a dangling render) alive. The timer holds
            // `[weak self]`, so this is the teardown hook (no retain cycle either way).
            blinkTimer?.invalidate()
            blinkTimer = nil
            stopDisplayLink()
            invalidateRenderGeneration()
            // A view can leave the window MID-DRAG (tab close / pane remount during a live
            // resize) and AppKit does not guarantee `viewDidEndLiveResize` then. This instance
            // is cached and re-hosted (`TerminalPaneRegistry`), so unwind the live-resize state
            // here too — a latched `presentsWithTransaction` would route every later present
            // through the synchronous (main-blocking) path outside any resize, and a stale
            // frozen origin would mis-anchor the next layout. The pending commit is cancelled,
            // not flushed: re-attach runs `layout()`, which re-schedules a commit if the size
            // really differs.
            metalLayer.presentsWithTransaction = false
            metalLayer.maximumDrawableCount = 2 // unwind the drag-scoped third drawable too
            liveResizeFrozenOrigin = nil
            resizeCommitWork?.cancel()
            resizeCommitWork = nil
            // Drop any in-flight preview build too (the generation bump above already declines
            // its hop, but a re-attach at the SAME size would not re-bump): clear the target and
            // advance the preview token so a late landing can never stash a stale-width frame
            // into the re-hosted view.
            _ = emulatorState.claimPreviewToken()
            previewCols = 0; previewRows = 0
            // And any staged-but-unapplied resize target: re-attach runs `layout()`, which
            // commits the real size if it differs — a stale mid-drag target applying to the
            // re-hosted view would resize the grid behind that layout's back.
            emulatorState.clearPendingResize()
        }
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if window != nil {
            stopDisplayLink()
            startDisplayLink()
            scheduleRender()
        }
    }

    /// Drive renders at the display's refresh rate while in a window. The link starts paused;
    /// `scheduleRender` wakes it, and `displayTick` re-pauses it once the screen is up to date, so an
    /// idle terminal costs nothing. macOS 14+ `NSView.displayLink` is the main-thread display source.
    private func startDisplayLink() {
        guard renderLink == nil else { return }
        let link = displayLink(target: self, selector: #selector(displayTick))
        link.isPaused = true
        link.add(to: .current, forMode: .common)
        renderLink = link
        applyPreferredFrameRateRange()
        scheduler.start()
    }

    /// On a variable-refresh (ProMotion) display, ask for the panel's full rate while the link is
    /// awake — the WWDC-recommended range form (min 60 lets the system adapt down for power). A
    /// no-op on fixed 60Hz panels and when the system already drives the link at native rate; the
    /// link only runs while there's pending paint, so this never holds the panel at 120Hz at idle.
    /// Re-applied on backing-property changes (the cross-monitor drag path).
    private func applyPreferredFrameRateRange() {
        guard let link = renderLink,
              let maxFPS = window?.screen?.maximumFramesPerSecond, maxFPS > 60 else { return }
        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60, maximum: Float(maxFPS), preferred: Float(maxFPS))
    }

    private func stopDisplayLink() {
        renderLink?.invalidate()
        renderLink = nil
        scheduler.stop()
    }

    /// Window visibility changed (occlusion observer / attach seed). While occluded the scheduler
    /// holds every present — dirty marks and parsing continue, so the pane stays current and
    /// costs no GPU work. On becoming visible, re-arm: any output that arrived while covered
    /// accumulated engine damage, so the next tick builds and presents one up-to-date frame.
    private func setWindowOccluded(_ occluded: Bool) {
        guard occluded != scheduler.isOccluded else { return }
        scheduler.setOccluded(occluded)
        if !occluded { scheduleRender() }
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        buildRenderer()
        applyPreferredFrameRateRange() // the view may have moved to a different-refresh display
        // Backing scale changed (e.g. the drag crossed monitors): a frozen drag origin is in
        // old-scale device pixels — drop it, recompute at the new scale, and re-freeze so the
        // rest of the drag stays anchored.
        let wasFrozen = liveResizeFrozenOrigin != nil
        liveResizeFrozenOrigin = nil
        updateGridSize()
        if wasFrozen, hasSizedGrid { liveResizeFrozenOrigin = (originOffsetX, originOffsetY) }
        scheduleRender()
    }

    /// Glitchless live resize (Hume's technique; Ghostty parity). While the user drags the window
    /// edge, the layer presents *with* the Core Animation transaction: every present becomes
    /// commit → `waitUntilScheduled()` → `drawable.present()` (see the renderer's
    /// `synchronizedWithTransaction`), so the terminal frame and the window's new frame land in
    /// the SAME transaction — content stays latched to the edge instead of lagging it by 1–2
    /// vsyncs (the judder the async present produces). The mode lives exactly as long as the
    /// drag: outside it, the async present path keeps its latency profile.
    /// `allowsNextDrawableTimeout` deliberately stays on (see `configureLayer`): a nil drawable
    /// mid-drag skips one transaction's present and self-heals on the next layout — preferable
    /// to an unbounded main-thread wait if the GPU wedges.
    public override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        metalLayer.presentsWithTransaction = true
        // Transaction-mode presents hand their drawable to the window server until the CA commit
        // completes, so with the steady-state pool of 2 (kept for keystroke echo latency) the
        // next drag tick parks in `nextDrawable()` for most of a frame (measured p50 ~12ms on
        // 120Hz hardware). A third drawable for the duration of the drag keeps one free while two
        // ride their transactions; the in-flight semaphore stays at 2 — GPU completion is not the
        // bottleneck here (semaphoreWait measured 0), the held presents are.
        metalLayer.maximumDrawableCount = 3
        // Anchor the grid for the whole drag; re-centered once in `viewDidEndLiveResize`.
        // Before the first real layout there's no meaningful origin to freeze — leave nil so
        // `updateGridSize` computes normally.
        liveResizeFrozenOrigin = hasSizedGrid ? (originOffsetX, originOffsetY) : nil
    }

    public override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        metalLayer.presentsWithTransaction = false
        metalLayer.maximumDrawableCount = 2 // restore the low-latency echo pool (see configureLayer)
        // Invalidate any in-flight preview build UNCONDITIONALLY. A live commit's generation bump
        // usually covers this, but a drag that returns to its ORIGINAL size commits nothing (no
        // bump, previewCols still holds the last intermediate target) — a slow build for that
        // intermediate width landing after release would pass every guard and stash a wrong-width
        // frame. Advancing the preview token + clearing the target makes both the on-queue skip and
        // the hop guards drop it.
        _ = emulatorState.claimPreviewToken()
        previewCols = 0; previewRows = 0
        // Unfreeze and recompute geometry/origin for the SETTLED size. With live reflow on this is
        // almost always a pure re-center — the last cell-boundary commit already reflowed + sent
        // the final size; with live reflow off it schedules the drag's one-and-only debounced
        // commit. Either mode, a release landing exactly on a not-yet-processed boundary schedules
        // a fresh commit here, flushed immediately just below.
        liveResizeFrozenOrigin = nil
        updateGridSize()
        // Flush any pending grid+PTY commit NOW: the size is settled the moment the drag ends and
        // transaction mode is off, so it lands immediately instead of waiting out the coalescing
        // delay (which exists only for *animated* resizes — sidebar slides, tiling). `perform` runs
        // it synchronously; `cancel` stops the queued asyncAfter copy from re-running it (and
        // `commitGridSize` is idempotent via its cols/rows guard anyway). Ordered AFTER
        // `updateGridSize` so a commit it just scheduled for a boundary-landing release is caught.
        if let work = resizeCommitWork {
            resizeCommitWork = nil
            work.perform()
            work.cancel()
        }
        if !repaintLastFrame() { scheduleRender() }
    }

    public override func layout() {
        super.layout()
        // Resize the drawable and repaint in the SAME turn, with implicit animations off, so a
        // resize never shows a stale frame stretched to the new bounds (the flicker).
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let needsFirstPaint = !hasSizedGrid
        updateGridSize()
        if needsFirstPaint {
            // First real layout: `updateGridSize` already committed the grid; build + present the
            // true frame synchronously so the terminal opens correct with no flash.
            scheduler.forceRender()
        } else if !repaintLastFrame() {
            // Resize/animation storm: re-present the cached frame at the new size — no emulator-queue
            // access, so a window drag never blocks on the output parser (the jank source). Fresh
            // output still lands between layout frames via the async display-link path. Fall back to
            // a full synchronous build only when there's no valid cached frame (e.g. generation just
            // changed via a font/theme/reflow invalidation).
            scheduler.forceRender()
        }
        CATransaction.commit()
    }

    /// Recompute columns/rows from the view size and resize the emulator + drawable.
    private func updateGridSize() {
        guard let renderer else { return }
        let scale = window?.backingScaleFactor ?? 2.0
        metalLayer.contentsScale = scale
        // Round (not floor) so the drawable exactly covers the layer's pixel area. With
        // `contentsGravity = .topLeft`, a floored (sub-pixel-short) drawable leaves a
        // transparent sliver at the right/bottom edge — a thin seam showing the blur through.
        let pixelWidth = max(1, Int((bounds.width * scale).rounded()))
        let pixelHeight = max(1, Int((bounds.height * scale).rounded()))
        metalLayer.drawableSize = CGSize(width: pixelWidth, height: pixelHeight)

        // Inset the grid by the window padding (in device pixels); the same offset is the
        // renderer's draw origin so the padding region shows the canvas color.
        let geometry = Self.computeGridGeometry(
            pixelWidth: pixelWidth, pixelHeight: pixelHeight,
            basePadX: Int((paddingPointsX * scale).rounded()),
            basePadY: Int((paddingPointsY * scale).rounded()),
            cellWidth: renderer.cellPixelWidth, cellHeight: renderer.cellPixelHeight,
            balanced: paddingBalanced,
            // The frozen origin is the live-resize signal (set in viewWillStartLiveResize,
            // cleared in viewDidEndLiveResize / detach) — NOT NSView.inLiveResize, which only
            // AppKit's drag loop sets, so the lifecycle stays directly drivable in tests.
            frozenOrigin: liveResizeFrozenOrigin
        )
        originOffsetX = geometry.originX
        originOffsetY = geometry.originY
        let newCols = geometry.cols
        let newRows = geometry.rows
        guard newCols != columns || newRows != rows else { return }
        if !hasSizedGrid {
            // First real layout: size immediately so the terminal opens correct (no flash).
            hasSizedGrid = true
            commitGridSize(cols: newCols, rows: newRows)
        } else {
            // Live HUD tick: the integer cols/rows only change at cell boundaries (the drawable
            // resizes smoothly every frame), so this fires exactly when the displayed size ticks.
            onGridSizeWillChange?(newCols, newRows, false)
            if liveResizeReflowEnabled, metalLayer.presentsWithTransaction {
                // Real-time live resize (Ghostty parity): commit the authoritative reflow + PTY
                // SIGWINCH at THIS cell boundary so the running program redraws during the drag,
                // not on release. The reflow runs off-main and coalesces latest-wins, so a fast
                // drag stays cheap. The preview below still rides under it for instant feedback.
                requestLiveResizeCommit(cols: newCols, rows: newRows)
            } else {
                // Legacy / animated path (escape-hatch off, or sidebar slide / tiling which never
                // enter live resize): the drawable already resized above (smooth); defer the
                // authoritative history-wide reflow + PTY SIGWINCH until the size settles so the
                // animation can't storm the shell. Each layout reschedules, so the commit fires
                // once after the last frame.
                scheduleResizeCommit(cols: newCols, rows: newRows)
            }
            // Live re-wrap: show the *content re-wrapped* to the new width during the drag instead of
            // the old grid revealed/clipped — `previewViewportReflow` is O(visible) and non-mutating,
            // so it's affordable every cell-boundary tick. Rebuild only when the cell count changes.
            // The build is async on the emulator queue (this tick's layout re-presents the cached
            // frame at the new drawable size; the re-wrap lands on the next main hop), so a
            // boundary tick costs main no more than a sub-cell tick.
            if newCols != previewCols || newRows != previewRows {
                previewCols = newCols
                previewRows = newRows
                updateResizePreview(cols: newCols, rows: newRows)
            }
        }
    }

    /// Pure grid geometry: cols/rows from the usable (padding-inset) area plus the draw origin.
    /// Normal path: the origin is the padding inset, balanced-centered when enabled — the sub-cell
    /// remainder splits onto both sides instead of `.topLeft` gravity parking it all bottom-right;
    /// the odd pixel (integer / 2) stays bottom-right and is invisible. Recomputed even when the
    /// cell count is unchanged so a sub-cell resize re-centers on the next paint.
    /// Live drag (`frozenOrigin` non-nil): hold the drag-start origin — re-centering every
    /// sub-cell layout shifts the text ±1px per pixel of drag (visible shimmer). Clamped so a
    /// shrink can't push the grid past the drawable's right/bottom edge: the origin slides only
    /// enough to keep the last column/row visible — once per cell boundary, not every pixel.
    /// `viewDidEndLiveResize` re-centers once for the settled size. Static + pure so the headless
    /// tests cover centering/freeze/clamp without a Metal renderer.
    nonisolated static func computeGridGeometry(
        pixelWidth: Int, pixelHeight: Int,
        basePadX: Int, basePadY: Int,
        cellWidth: Int, cellHeight: Int,
        balanced: Bool,
        frozenOrigin: (x: Int, y: Int)?
    ) -> (cols: Int, rows: Int, originX: Int, originY: Int) {
        let usableWidth = max(1, pixelWidth - 2 * basePadX)
        let usableHeight = max(1, pixelHeight - 2 * basePadY)
        let cols = max(1, usableWidth / cellWidth)
        let rows = max(1, usableHeight / cellHeight)
        if let frozen = frozenOrigin {
            return (
                cols, rows,
                min(frozen.x, max(0, pixelWidth - cols * cellWidth)),
                min(frozen.y, max(0, pixelHeight - rows * cellHeight))
            )
        }
        var originX = basePadX
        var originY = basePadY
        if balanced {
            originX += (usableWidth - cols * cellWidth) / 2
            originY += (usableHeight - rows * cellHeight) / 2
        }
        return (cols, rows, originX, originY)
    }

    private func scheduleResizeCommit(cols: Int, rows: Int) {
        resizeCommitWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.commitGridSize(cols: cols, rows: rows) }
        resizeCommitWork = work
        // ~60ms outlasts a frame cadence so it lands once the animation/drag stops, while
        // staying snappy enough that a deliberate resize feels immediate.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
    }

    /// Commit the settled size to the emulator grid (reflow) and the PTY (one SIGWINCH), then
    /// repaint. The authoritative width reflow is O(history) — tens to hundreds of ms at deep
    /// scrollback — so it runs **off the main thread**: the emulator is confined to its serial queue
    /// (so the resize serializes correctly with any in-flight output feed), and the rebuilt frame is
    /// presented on completion. Main never blocks, so a drag-release never drops a frame; the live
    /// preview (or `repaintLastFrame`) already covers the interim until the authoritative frame lands.
    private func commitGridSize(cols: Int, rows newRows: Int) {
        resizeCommitWork = nil
        // Never commit MID-DRAG (a stationary >60ms hold lets the debounce elapse): the commit
        // bumps the generation — dropping the in-flight preview — but its authoritative re-present
        // (`renderNowOffMain`) defers while the layer presents with the transaction, and with the
        // mouse still no further layout runs: the screen would freeze on a stale-generation frame
        // until the next pointer move. Re-arm instead; `viewDidEndLiveResize` clears the mode
        // FIRST and then flushes, so the commit lands exactly once at release.
        if metalLayer.presentsWithTransaction {
            scheduleResizeCommit(cols: cols, rows: newRows)
            return
        }
        guard cols != columns || newRows != rows else { return }
        // A text selection can't survive a reflow — its anchors reference the OLD grid extents, so
        // after a shrink the highlight renders at stale/out-of-grid coordinates and a copy yields
        // blank/garbage rows. Clear it like the real-time path (`requestLiveResizeCommit`) does;
        // this debounced/animated/legacy commit (and `testingResizeGrid`) skipped it. `clearSelection`
        // no-ops when nothing is selected and avoids the `currentSelectionRegion` getter.
        clearSelection()
        columns = cols
        rows = newRows
        invalidateRenderGeneration()              // bump generation; drop stale preview / plain-frame cache
        lastSentPTYSize = (cols, newRows)          // keep the live-resize vote coalescer in sync
        onResize?(cols, newRows)                  // one PTY SIGWINCH (fire-and-forget)
        onGridSizeWillChange?(cols, newRows, true) // settled size for the HUD
        previewCols = 0; previewRows = 0           // force the next drag to rebuild a fresh preview
        if offMainParserFramePipelineEnabled {
            // Off-main pipeline: stage the settled size and let the next build materialize it on
            // the emulator's serial queue (serialized with the output feed) — `setPendingResize`
            // enqueues ahead of the build below, and last-writer-wins overwrites any stale live
            // target still unapplied from the drag. Main never blocks on the O(history) width
            // reflow; the live preview / repaintLastFrame covers the interim. A superseding newer
            // resize drops this build's present via the generation guard, and its own build
            // applies the newest staged size.
            emulatorState.setPendingResize((cols, newRows))
            renderNowOffMain()
        } else {
            // Main-confined pipeline: the emulator lives on the main thread (no serial queue to
            // offload to), so resize + present synchronously — the pre-existing discipline. Going
            // off-main here would be an unsynchronized mutation of the main-confined emulator.
            emulatorSync { $0.resize(cols: cols, rows: newRows) }
            scheduler.forceRender()
        }
    }

    /// Real-time authoritative commit fired at EVERY cell boundary during a live drag (Ghostty
    /// parity) — the counterpart to `commitGridSize`'s debounced drag-end path. It mutates the real
    /// grid (`emulator.resize`) and sends the PTY `SIGWINCH` (`onResize`) live, so interactive
    /// programs — vim/htop/btop/tmux/less, and any alternate-screen TUI the non-mutating preview
    /// cannot serve — reflow and redraw continuously instead of snapping at release.
    ///
    /// Two costs are tamed so a fast drag stays smooth:
    /// - The O(history) width reflow runs OFF-MAIN on the emulator serial queue and is coalesced
    ///   latest-wins via `renderNowOffMain`'s frame token: a drag crossing N columns runs ~1–3
    ///   reflows, not N (superseded targets skip their resize+build entirely).
    /// - The cross-process PTY vote (`onResize` → daemon ioctl → child `SIGWINCH`) fires only when
    ///   the cell count changed from `lastSentPTYSize`, so a within-column drag frame sends nothing.
    ///
    /// The rebuilt frame presents inside an explicit `CATransaction` (`flushTransaction`) so a
    /// completion landing while the mouse is held *still* (no layout pass to ride) still flushes —
    /// see `presentWithinExplicitTransaction`. Called only while `presentsWithTransaction` (a real
    /// drag) and `liveResizeReflowEnabled`; `updateGridSize` gates both. Requires the off-main
    /// pipeline — on the main-confined escape hatch it falls back to the debounced commit below.
    private func requestLiveResizeCommit(cols: Int, rows newRows: Int) {
        // Only on the off-main pipeline: this commit reflows the emulator ON the serial queue, but
        // with the flag off the emulator is main-confined (`receive` feeds it synchronously on
        // main) and the queue hop would mutate it concurrently with a main-thread parse — the same
        // guard `updateResizePreview` and `commitGridSize` already apply. Fall back to the
        // debounced drag-end commit, whose `commitGridSize` resizes via `emulatorSync` on main.
        guard offMainParserFramePipelineEnabled else {
            scheduleResizeCommit(cols: cols, rows: newRows)
            return
        }
        guard cols != columns || newRows != rows else { return }
        columns = cols
        rows = newRows
        // A text selection can't survive a width reflow (the wrapped rows move under its anchors),
        // so clear it like Terminal.app/iTerm rather than render a stale region. Copy mode and find
        // recompute their viewport-relative state per build, so they self-heal across the reflow.
        // `clearSelection` no-ops when nothing is selected (and avoids the `currentSelectionRegion`
        // getter, which can `emulatorSync` for a word selection — a main-thread stall mid-drag).
        clearSelection()
        // DELIBERATELY no `renderGeneration` bump here. A bump would make `layout()`'s
        // `repaintLastFrame` decline (generation mismatch) and fall to the SYNCHRONOUS `forceRender`,
        // whose `state.sync` would block main behind the in-flight O(history) reflow on the emulator
        // queue — the exact stall the off-main pipeline exists to avoid. Instead the builder-reuse
        // cache is cleared ON the queue right after the resize applies (see `applyPendingResize` at
        // the top of `renderNowOffMain`'s build), and the renderer's row cache auto-invalidates on the
        // dimension change. So between this commit and the authoritative frame landing, layout keeps
        // stretching the cached frame (the same near-free sub-cell repaint), and FIFO queue + main
        // ordering guarantees the latest target's reflow is the one that presents last.
        // PTY SIGWINCH, coalesced caller-side to distinct cell counts (the daemon does not dedupe).
        if lastSentPTYSize?.cols != cols || lastSentPTYSize?.rows != newRows {
            lastSentPTYSize = (cols, newRows)
            onResize?(cols, newRows)
        }
        // Clear the preview target so the next `updateResizePreview` (same boundary tick) rebuilds a
        // fresh re-wrap for this width and a stale in-flight preview can't match `previewCols`.
        previewCols = 0; previewRows = 0
        // Stage the reflow target on the queue (whichever build runs next materializes it — see
        // `pendingResize`) and present the result within an explicit CA transaction.
        emulatorState.setPendingResize((cols, newRows))
        renderNowOffMain(flushTransaction: true)
    }

    /// Run `body` (which presents a transaction-synchronized frame) inside an explicit Core
    /// Animation transaction. With `presentsWithTransaction = true` a `drawable.present()` reaches
    /// the glass only when the enclosing transaction commits; during a live drag the only
    /// transactions are AppKit's per-frame `layout()` passes, so an off-main reflow completing while
    /// the pointer is held still would otherwise never flush (a frozen screen until the next pointer
    /// move). Wrapping the present in our own begin/commit flushes it immediately — the same
    /// mechanism `layout()` relies on (`CATransaction` at the resize site), driven from a completion
    /// handler. A no-op shape outside transaction mode (an explicit transaction around a normal
    /// async present is harmless), so the end-of-drag settle can share the path.
    private func presentWithinExplicitTransaction(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    /// Mark the surface dirty and ensure the display link is running to present it. Every code path
    /// that changes what's on screen (PTY output, blink, focus, selection, copy mode, IME, …) funnels
    /// here, so a burst coalesces to one present at the next display tick instead of one async render
    /// per call. Before the view is in a window (no link yet) this is just the dirty mark; the first
    /// `viewDidMoveToWindow`/`commitGridSize` paints via the synchronous force path.
    func scheduleRender() {
        scheduler.markDirty()
        wakeDisplayLink()
    }

    /// Resume the display link so a pending paint reaches the screen. No-op until the link exists
    /// (created on window attach).
    private func wakeDisplayLink() {
        renderLink?.isPaused = false
    }

    /// Display-cadence tick: present at most one coalesced frame, then pause the link when there's
    /// nothing left to draw so a quiet terminal doesn't wake the CPU every refresh.
    @objc private func displayTick() {
        scheduler.tick()
        if !scheduler.hasPendingWork {
            renderLink?.isPaused = true
            scheduler.linkDidPause() // reopen the immediate-present path for the next arrival
        }
    }

    private func renderNow(forced: Bool = false) {
        // Off-main pipeline first: its entry owns the drag semantics (output presents flow live
        // under real-time reflow, within explicit CA transactions; the reflow-off escape hatch
        // defers there). Ordering matters — the main-confined hold below must not swallow the
        // scheduler's off-main ticks, or mid-drag output would gate on BOTH pipelines.
        if offMainParserFramePipelineEnabled {
            renderNowOffMain()
            return
        }
        // Main-confined escape hatch: single present source during a live drag. This legacy
        // pipeline has no live commits (requestLiveResizeCommit falls back to the debounce) and
        // a build here runs ON main — an ad-hoc output/tick present would pay the synchronized
        // commit→waitUntilScheduled stall AND replace `lastPresentedResult` with a fresh frame
        // the renderer cache hasn't seen, forcing the next layout repaint back onto the
        // full-rebuild path (defeating the empty-damage reuse that makes drag ticks near-free).
        // Defer instead: re-mark dirty so the work is never lost (`presentNow`/`tick` cleared the
        // flag before calling here); `layout()`'s repaint carries the visual per drag step, and
        // the first tick after `viewDidEndLiveResize` flushes the freshest frame. `forced` keeps
        // the synchronous path (first paint / no-cached-frame fallback inside layout) open.
        if !forced, metalLayer.presentsWithTransaction {
            scheduler.markDirty()
            return
        }
        guard let renderer else { return }
        guard let drawable = metalLayer.nextDrawable() else { scheduler.markDirty(); return }
        let emulator = emulatorState.emulator
        // Copy mode owns the whole surface while active (its own scroll offset + overlay).
        if renderCopyMode(renderer: renderer, drawable: drawable) { lastPlainFrame = nil; return }
        let grid = scrollOffset > 0 ? emulator.readGrid(scrollbackOffset: scrollOffset) : emulator.readGrid()
        // Consume dirty-row damage every frame to keep the engine's "since last render" window
        // aligned, then feed it to the builder only on the plain live path. Scrollback, an active
        // selection, and IME preedit all rebuild every row (they aren't tracked by damage), so
        // they take the full path and reset the reuse cache.
        let damage = emulator.consumeDamage()
        let findHits = findActive
            ? Self.viewportFindHighlights(findMatches, scrollOffset: scrollOffset, historyCount: emulator.historyCount, rows: rows)
            : []
        let selectionRegion = currentSelectionRegion
        let plain = scrollOffset == 0 && selectionRegion == nil && markedText.isEmpty && findHits.isEmpty
        let frameBuildStart = DispatchTime.now().uptimeNanoseconds
        var frame: TerminalFrame
        if plain {
            frame = frameBuilder.build(grid, region: nil,
                                       imageProvider: { emulator.image(for: $0) },
                                       reusing: lastPlainFrame, damage: damage)
        } else {
            frame = frameBuilder.build(grid, region: selectionRegion,
                                       searchHighlights: findHits,
                                       imageProvider: { emulator.image(for: $0) })
        }
        let frameBuildNanos = DispatchTime.now().uptimeNanoseconds &- frameBuildStart
        // IME preedit: draw the in-progress composition over the grid at the cursor.
        if !markedText.isEmpty, scrollOffset == 0 {
            overlayPreedit(into: &frame)
        }
        // DECSCUSR: a program-requested cursor shape (vim/nvim/fish per-mode) overrides the
        // user's `cursorStyle` setting; `.default` keeps the setting.
        switch grid.cursor.shape {
        case .block: frame.cursor.style = .block
        case .bar: frame.cursor.style = .bar
        case .underline: frame.cursor.style = .underline
        case .default: break
        }
        // Cursor blink: hide on the off-beat (only while focused + blink enabled). The program's
        // DECSCUSR blink preference overrides the setting; a program-hidden cursor stays hidden.
        let blinkEnabled = grid.cursor.blinking ?? cursorBlinkEnabled
        if frame.cursor.visible, focused, blinkEnabled, !cursorBlinkVisible {
            frame.cursor.visible = false
        }
        // Unfocused → hollow cursor (outline block / dimmed bar-underline), never blinking.
        frame.cursor.hollow = !effectivelyFocused
        // Clear to the canvas color at canvas opacity so any cell-rounding remainder reads
        // as the canvas (no seam, and translucent when opacity < 1). The grid draws at the
        // padding origin so the inset region shows the canvas.
        let didPresent = renderer.present(
            frame,
            to: drawable,
            clearColor: frameBuilder.renderColor(canvasBackground, alpha: canvasOpacity),
            origin: (originOffsetX, originOffsetY),
            gamma: glyphGamma,
            ligatures: ligaturesEnabled,
            damage: plain ? damage : nil,
            frameBuildNanos: frameBuildNanos,
            synchronizedWithTransaction: metalLayer.presentsWithTransaction
        )
        if didPresent { onRenderStats?(renderer.stats) }
        else { scheduleRender() } // transient encode/present failure — retry next tick
        StartupMetrics.shared.mark(.firstDrawablePresented) // idempotent: only the first present counts
        // Retain only a plain frame for row reuse; a selection/scrollback/preedit frame would
        // poison the cache with overlay-baked cells, so drop it. (`plain` already excludes IME.)
        lastPlainFrame = plain ? frame : nil
    }

    /// Force path (resize / first-paint / 2026-timeout): present in the SAME runloop turn so the
    /// frame is on screen before the caller's `CATransaction` commits. The on-main pipeline already
    /// renders synchronously; the off-main pipeline must build-and-present inline rather than via its
    /// normal async hop (which would flash a stale grid stretched to the new bounds).
    private func renderNowSynchronous() {
        if offMainParserFramePipelineEnabled {
            renderNowOffMain(synchronous: true)
        } else {
            renderNow(forced: true)
        }
    }

    private func renderNowOffMain(
        synchronous: Bool = false,
        flushTransaction: Bool = false
    ) {
        // Live-drag hold for the scheduler's async entry — ESCAPE HATCH ONLY. With real-time
        // reflow off, the drag's contract is defer-to-release: the grid stays at its pre-drag
        // size while the re-wrap PREVIEW (a different cell count) owns the glass, so an output
        // build presenting the old-size grid mid-drag would visibly fight the preview's frame.
        // With real-time reflow ON (the default), boundary commits keep the real grid current,
        // so output builds present the same size the drag shows — they flow live (each present
        // flushes its own explicit CATransaction below), which is what keeps streaming output,
        // SIGWINCH redraws, and keystroke echo moving DURING the drag instead of one boundary
        // behind. The synchronous (layout/forceRender) entry always presents — it is a drag
        // present source; a live-resize commit (`flushTransaction`) likewise.
        if !synchronous, !flushTransaction, metalLayer.presentsWithTransaction, !liveResizeReflowEnabled {
            scheduler.markDirty()
            return
        }
        guard renderer != nil else { return }
        let generation = renderGeneration
        let state = emulatorState
        let config = frameBuildConfiguration
        let requestedScrollOffset = scrollOffset
        // Capture the RAW selection here (cheap, no emulator access) and resolve it on the emulator
        // queue inside the build — see `resolveSelectionRegion`. Resolving on main would `emulatorSync`
        // for a word selection and stall main behind the in-flight feed every build.
        let rawSelection = currentRawSelection
        let preedit = markedText
        let blinkSetting = cursorBlinkEnabled
        let blinkVisible = cursorBlinkVisible
        let isFocused = effectivelyFocused
        let copyModeState = copyMode
        let searchEntry = copyModeSearchEntry
        let viewRows = rows
        let viewColumns = columns
        let fg = canvasForeground
        let bg = canvasBackground
        let opacity = canvasOpacity
        let findIsActive = findActive
        let findMatchesSnapshot = findMatches

        // The frame build, identical for the async (coalesced) and synchronous (forced) paths. Pure
        // over the captured value snapshot + the emulator; the only mutation is `state`'s plain-frame
        // cache, which is always touched on the serial queue (sync runs there; async dispatches there).
        let build: @Sendable (TerminalEmulator) -> SurfaceFrameBuildResult = { emulator in
            // Materialize any staged resize on the queue right before the build so it serializes
            // with the in-flight output feed. EVERY output/commit build applies the shared target
            // (`pendingResize`): a superseded commit build (its token is no longer latest) returns
            // before this runs, and whichever build superseded it applies the staged size instead —
            // a fast drag reflows only to the latest target (intermediate column counts are never
            // materialized) and the emulator can never strand at a pre-vote size. Clearing the
            // builder-reuse caches here (on the queue, not via a main-thread generation bump) keeps
            // this build from diffing the new grid against an old-width cached frame; the renderer's
            // row cache auto-invalidates on the dimension change.
            if state.applyPendingResize() {
                state.lastPlainFrame = nil
                state.lastViewportFrame = nil
                state.lastOverlayKeys = [:]
            }
            let builder = config.makeBuilder()
            let frameBuildStart = DispatchTime.now().uptimeNanoseconds
            var frame: TerminalFrame
            var renderDamage: TerminalDamage?
            var scrollShift = 0
            var peekRow = false
            if let cm = copyModeState {
                let offset = cm.scrollbackOffset(historyCount: emulator.historyCount)
                let grid = emulator.readGrid(scrollbackOffset: offset)
                let region: SelectionRegion? = cm.viewportSelection(rows: viewRows, columns: viewColumns).map { vs in
                    switch vs.kind {
                    case .linear:
                        return .linear(TerminalSelection((vs.startRow, vs.startColumn), (vs.endRow, vs.endColumn)))
                    case .block:
                        return .block(BlockSelection((vs.startRow, vs.startColumn), (vs.endRow, vs.endColumn)))
                    }
                }
                let hits = cm.viewportSearchHits(rows: viewRows).map { m in
                    TerminalSelection((m.line, m.startColumn), (m.line, max(m.startColumn, m.endColumn - 1)))
                }
                frame = builder.build(grid, region: region, searchHighlights: hits,
                                      copyModeCursor: cm.viewportCursor(rows: viewRows),
                                      imageProvider: { emulator.image(for: $0) })
                let statusText = searchEntry.map { (cm.search.reverse ? "?" : "/") + $0 } ?? cm.statusLine()
                Self.applyCopyModeStatus(into: &frame, text: statusText, builder: builder,
                                         selectionBackground: config.selectionBackground,
                                         canvasForeground: fg, canvasBackground: bg)
                state.lastPlainFrame = nil
                state.lastViewportFrame = nil // copy-mode frames bake overlays — not a shift source
            } else {
                // Scrolled views build with the smooth-scroll peek row appended (rows+1 tall) so
                // the fraction translate always has real content to reveal; the live view (offset
                // 0) stays byte-identical. Augmenting whenever scrolled — not just when a fraction
                // is active — keeps the frame shape uniform across the whole scrolled regime, so
                // `buildShifted` keeps rotating instead of bailing on a rows mismatch.
                peekRow = requestedScrollOffset > 0
                // `gridRead` brackets boundary 1 (the engine→renderer grid snapshot) on the
                // signpost track, so a per-boundary trace can attribute build time to the
                // snapshot copy vs the RenderCell resolve that follows.
                let (grid, damage) = FrameSignposter.shared.interval("gridRead") {
                    () -> (TerminalGridSnapshot, TerminalDamage) in
                    let grid = peekRow
                        ? Self.appendingPeekRow(
                            to: emulator.readGrid(scrollbackOffset: requestedScrollOffset),
                            emulator: emulator, offset: requestedScrollOffset
                        )
                        : emulator.readGrid()
                    return (grid, emulator.consumeDamage())
                }
                let findHits = findIsActive
                    ? Self.viewportFindHighlights(findMatchesSnapshot, scrollOffset: requestedScrollOffset, historyCount: emulator.historyCount, rows: viewRows)
                    : []
                // Resolve the selection HERE, on the emulator queue: a `.word` selection reads
                // `wordColumnRange` directly (free) instead of stalling main via `emulatorSync`, and
                // it resolves against the same emulator state this frame renders.
                let selectionRegion = Self.resolveSelectionRegion(rawSelection, emulator: emulator,
                                                                  scrollOffset: requestedScrollOffset,
                                                                  columns: viewColumns)
                let overlayFree = selectionRegion == nil && preedit.isEmpty && findHits.isEmpty
                // The LIVE view (offset 0) always builds CLEAN: selection/find/preedit are
                // re-shaded onto a copy after the reuse caches are updated (the cell-overlay
                // pass below), so they ride damage-driven incremental builds instead of forcing
                // a full rebuild every frame for their whole duration. Scrolled views keep the
                // baked full-rebuild path (overlay coordinates while scrolled are rarer and not
                // worth the extra path).
                let plain = requestedScrollOffset == 0
                // Scroll-delta fast path: a pure scrollback scroll (the offset changed, nothing
                // else did — no output since the last overlay-free frame, no overlays now) is the
                // previous frame shifted by the offset delta. `buildShifted` re-resolves only the
                // newly-exposed rows; `scrollShift` + the exposed-row damage let the renderer
                // rotate its row cache the same way. This covers k→k′ scrolls AND the 0→k / k→0
                // transitions (landing at 0 yields a byte-identical plain frame, so the plain
                // cache below stays coherent). `damage.rows.isEmpty` is the no-output guard —
                // cursor moves list their rows there, so they conservatively take the full path.
                let scrollDelta = requestedScrollOffset - state.lastViewportOffset
                if overlayFree, scrollDelta != 0,
                   damage.rows.isEmpty, !damage.full,
                   state.lastViewportGeneration == generation,
                   let previous = state.lastViewportFrame,
                   let shifted = builder.buildShifted(grid, reusing: previous, shift: scrollDelta) {
                    frame = shifted
                    scrollShift = scrollDelta
                    // Exposed band in FRAME rows (grid.rows == viewRows + 1 when the peek row is
                    // appended): a shift toward live exposes the bottom band including the peek.
                    let exposed = scrollDelta > 0
                        ? IndexSet(integersIn: 0 ..< min(scrollDelta, grid.rows))
                        : IndexSet(integersIn: max(0, grid.rows + scrollDelta) ..< grid.rows)
                    renderDamage = TerminalDamage(rows: exposed)
                } else if plain {
                    // Only reuse a cached frame built for THIS generation — a stale-generation frame
                    // describes the old grid and would tear when diffed against fresh damage.
                    let reuse = state.lastPlainFrameGeneration == generation ? state.lastPlainFrame : nil
                    let fresh = damage.rows.subtracting(damage.scrolledRows)
                    // Output-scroll fast path: the engine reported a whole-viewport scroll
                    // (`damage.scroll`), so the moved band shift-copies from the previous frame
                    // and only the fresh rows (writes, blank band, cursor rows) re-resolve.
                    // `scrollShift` lets the renderer rotate its row-instance cache the same way
                    // it does for scrollback scrolls; the fresh band is its re-encode set. Any
                    // bail (no reusable frame, images, geometry) falls back to the plain build,
                    // whose `damage.rows` still covers the whole moved band.
                    if damage.scroll != 0, !damage.full, !damage.scrolledRows.isEmpty,
                       let prev = reuse,
                       let shifted = builder.buildShifted(grid, reusing: prev,
                                                          shift: damage.scroll, freshRows: fresh) {
                        frame = shifted
                        scrollShift = damage.scroll
                        renderDamage = TerminalDamage(rows: fresh)
                    } else {
                        frame = builder.build(grid, region: nil,
                                              imageProvider: { emulator.image(for: $0) },
                                              reusing: reuse, damage: damage)
                        renderDamage = damage
                    }
                } else {
                    frame = builder.build(grid, region: selectionRegion,
                                          searchHighlights: findHits,
                                          imageProvider: { emulator.image(for: $0) })
                    // Overlay-free full rebuilds (scrolled views) present with FULL damage, not
                    // nil: the instances are identical, but the encode routes through the
                    // cache-populating path, so the row cache is warm for the next scroll
                    // rotation or fraction-only repaint (nil would reset it and force the next
                    // tick to re-encode everything). Overlay frames keep nil — their baked
                    // highlight cells must not poison the cache.
                    if overlayFree {
                        renderDamage = TerminalDamage(full: true)
                    }
                }
                switch grid.cursor.shape {
                case .block: frame.cursor.style = .block
                case .bar: frame.cursor.style = .bar
                case .underline: frame.cursor.style = .underline
                case .default: break
                }
                let blinkEnabled = grid.cursor.blinking ?? blinkSetting
                if frame.cursor.visible, isFocused, blinkEnabled, !blinkVisible {
                    frame.cursor.visible = false
                }
                frame.cursor.hollow = !isFocused // unfocused → hollow outline / dimmed cursor
                // Caches hold the CLEAN frame: on the live path the overlay pass below shades a
                // copy, so reuse stays warm through a selection drag / find session / composition.
                state.lastPlainFrame = plain ? frame : nil
                state.lastPlainFrameGeneration = generation
                // Refresh the scroll-reuse source: any clean, image-free viewport frame qualifies
                // (the live view always builds clean now; a scrolled view only when overlay-free —
                // scrolled overlay frames bake highlight colors into cells, so they poison it).
                if plain || overlayFree, frame.images.isEmpty {
                    state.lastViewportFrame = frame
                    state.lastViewportOffset = requestedScrollOffset
                    state.lastViewportGeneration = generation
                } else {
                    state.lastViewportFrame = nil
                }
                // Cell-overlay pass (live view only): re-shade the selection / find rows of a
                // copy and lay the IME preedit over it, leaving the cached clean frame above
                // untouched. The render damage gains exactly the rows whose overlay fingerprint
                // changed since the last build, so a selection drag re-encodes the rows it
                // crossed — a static highlight (or an idle find bar) adds nothing per frame.
                if plain {
                    let keys = Self.overlayRowKeys(
                        selection: selectionRegion, findHits: findHits, preedit: preedit,
                        preeditCursor: (frame.cursor.row, frame.cursor.column),
                        rows: grid.rows, cols: grid.cols
                    )
                    if !keys.isEmpty {
                        builder.applyHighlights(into: &frame, from: grid, region: selectionRegion,
                                                searchHighlights: findHits, rows: IndexSet(keys.keys))
                        if !preedit.isEmpty {
                            Self.applyPreedit(into: &frame, text: preedit, builder: builder,
                                              canvasForeground: fg, canvasBackground: bg)
                        }
                    }
                    if var damage = renderDamage, !damage.full {
                        for (row, key) in keys where state.lastOverlayKeys[row] != key {
                            damage.rows.insert(row)
                        }
                        for row in state.lastOverlayKeys.keys where keys[row] == nil {
                            damage.rows.insert(row)
                        }
                        if !keys.isEmpty || !state.lastOverlayKeys.isEmpty { damage.cursorOnly = false }
                        renderDamage = damage
                    }
                    state.lastOverlayKeys = keys
                }
            }
            return SurfaceFrameBuildResult(
                generation: generation,
                frame: frame,
                damage: renderDamage,
                scrollShift: scrollShift,
                hasPeekRow: peekRow,
                frameBuildNanos: DispatchTime.now().uptimeNanoseconds &- frameBuildStart,
                clearColor: builder.renderColor(bg, alpha: opacity)
            )
        }

        if synchronous {
            // Block until the worker builds this frame, then present inline (we're on main inside the
            // caller's CATransaction). `state.sync` queues behind any in-flight build, preserving order.
            let result = state.sync { emulator in
                FrameSignposter.shared.interval("frameBuild") { build(emulator) }
            }
            presentBuiltFrame(result)
        } else {
            let token = state.claimFrameToken()
            let flush = flushTransaction
            state.async { emulator in
                // Latest-wins coalescing: if a newer build is already queued behind this one, skip —
                // it will consume the damage this one would have (no rows lost), so a burst of marks
                // collapses to a single build instead of N stale frames. For a live-resize commit
                // the skip also drops this target's `emulator.resize`, bounding O(history) reflows.
                guard state.isLatestFrameToken(token) else { return }
                let result = FrameSignposter.shared.interval("frameBuild") { build(emulator) }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    // Any present landing while the layer is in transaction mode flushes its own
                    // explicit CATransaction: a live-resize commit by contract, and an un-gated
                    // mid-drag output build because the mouse may be held still (no layout pass
                    // to carry a transaction-mode present to the glass). Checked at LANDING time —
                    // a build that outlives the drag presents normally (the wrap is a harmless
                    // no-op shape either way, see `presentWithinExplicitTransaction`).
                    if flush || self.metalLayer.presentsWithTransaction {
                        self.presentWithinExplicitTransaction { self.presentBuiltFrame(result) }
                    } else {
                        self.presentBuiltFrame(result)
                    }
                }
            }
        }
    }

    /// Present an already-built off-main frame (main thread). A stale generation / no window / no
    /// renderer is an intentional drop; a nil drawable or a failed present is transient, so re-arm the
    /// scheduler (and wake the link) to retry on the next tick rather than leaving a frame unshown.
    private func presentBuiltFrame(_ result: SurfaceFrameBuildResult) {
        guard renderGeneration == result.generation, window != nil, let renderer else { return }
        let outcome = presentFrame(result, damage: result.damage, scrollShift: result.scrollShift)
        if outcome == .presented {
            // Remember the presented frame so a live resize can re-stretch it without rebuilding
            // (and without touching the emulator queue). See `repaintLastFrame`.
            lastPresentedResult = result
            // The renderer reports whether the encode left its row cache holding exactly this
            // frame's rows — false for the cache-bypassing paths (nil damage) AND for a
            // mid-encode atlas reset that wiped the cache (which a damage-only heuristic here
            // could not distinguish from a normal full encode).
            lastPresentedResultIsRendererCoherent = renderer.stats.rowCacheCoherent
            onRenderStats?(renderer.stats)
        } else {
            // A genuine drop: nothing reached the glass this turn (repaintLastFrame failures
            // don't count — their callers fall back to another present in the same turn).
            // The worker has already diffed this frame's damage away (lastPlainFrame /
            // lastViewportFrame advanced at build time), so the NEXT build can legitimately say
            // "nothing changed" — but the renderer's row cache never received this frame's rows
            // (nil drawable drops before encode) or holds rows the screen never showed (encode
            // failed after mutating them). Either way the cache and the next frame's damage
            // disagree about what's on the glass, so drop the cache: the retry re-encodes fully.
            renderer.invalidateRowReuseCache()
            lastPresentedResultIsRendererCoherent = false
            FrameSignposter.shared.recordFrameDrop(
                outcome == .nilDrawable ? .nilDrawable : .encodeFailure)
            scheduleRender() // transient encode/present failure — retry next tick
        }
        StartupMetrics.shared.mark(.firstDrawablePresented)
    }

    /// Acquire a drawable and present `result`'s frame at the current origin — the one place the
    /// main thread meets the GPU (drawable wait + in-flight semaphore + encode). While the layer is
    /// in `presentsWithTransaction` mode (live resize) the present is routed through the renderer's
    /// transaction-synchronized path, keyed off the layer property itself so present modes can
    /// never mix while the mode is on — DELIBERATE for output/tick presents mid-drag too: an async
    /// `commandBuffer.present` against a transaction-mode layer presents at an indeterminate later
    /// commit (the glitch class this change eliminates), and the uniform sync cost is the bounded
    /// schedule wait (sub-ms, measured as `presentScheduleNanos`), paid only while dragging.
    /// The `present` signpost interval brackets nextDrawable() + the renderer's
    /// inFlightSemaphore.wait(): the drawable / GPU back-pressure (vsync) stall on the main thread
    /// — the term the latency work targets (0b showed parse+build is ~16µs, so any felt lag lives
    /// here, not upstream). When signposts are enabled we also record a rolling p50/p95 breakdown
    /// (total / drawable wait / semaphore wait / schedule). A `false` return is a skipped present
    /// (nil drawable or encode failure) — callers decide whether to retry or fall back; only
    /// `presentBuiltFrame` counts a genuine drop (`recordFrameDrop`), keyed by which failure it was.
    private enum PresentAttempt { case presented, nilDrawable, encodeFailure }

    private func presentFrame(
        _ result: SurfaceFrameBuildResult, damage: TerminalDamage?, scrollShift: Int = 0
    ) -> PresentAttempt {
        guard let renderer else { return .encodeFailure }
        // Smooth scroll is applied at present time from the CURRENT fraction (render-only state):
        // a fraction-only tick re-presents the same frame with just a new uniform. Rounded to
        // whole device pixels so glyphs stay crisp mid-scroll (no sub-pixel resampling).
        // The translate is gated on the FRAME, not just the fraction: (1) a frame without the
        // peek row (built at offset 0 — e.g. the cached live frame re-presented while the first
        // scrolled build is still in flight) must present untranslated, or the translate would
        // open a background gap at the bottom with no row to fill it — the worst case is one
        // un-smooth frame, never a hole; (2) image-bearing frames present untranslated too
        // (`image_vertex` has no scrollPx), so an image scrolling INTO a fractional viewport
        // can never sit misaligned against its text — `scrollByContinuous` quantizes the next
        // position the same way. The clip rides the peek row itself: hidden at fraction 0, and
        // rows slide out of the fixed grid box mid-fraction.
        let canTranslate = result.hasPeekRow && result.frame.images.isEmpty
        let fractionPx = canTranslate && scrollFraction > 0
            ? Float((scrollFraction * CGFloat(renderer.cellPixelHeight)).rounded())
            : 0
        let clipRows = result.hasPeekRow ? result.frame.rows - 1 : nil
        let sp = FrameSignposter.shared
        let presentStart = sp.enabled ? DispatchTime.now().uptimeNanoseconds : 0
        var drawableWaitNanos: UInt64 = 0
        let outcome = sp.interval("present") { () -> PresentAttempt in
            let drawableStart = sp.enabled ? DispatchTime.now().uptimeNanoseconds : 0
            guard let drawable = sp.interval("drawableWait", { metalLayer.nextDrawable() })
            else { return .nilDrawable }
            if sp.enabled { drawableWaitNanos = DispatchTime.now().uptimeNanoseconds &- drawableStart }
            let presented = renderer.present(
                result.frame,
                to: drawable,
                clearColor: result.clearColor,
                origin: (originOffsetX, originOffsetY),
                gamma: glyphGamma,
                ligatures: ligaturesEnabled,
                damage: damage,
                scrollShift: scrollShift,
                scrollFractionPx: fractionPx,
                smoothScrollClipRows: clipRows,
                frameBuildNanos: result.frameBuildNanos,
                synchronizedWithTransaction: metalLayer.presentsWithTransaction
            )
            return presented ? .presented : .encodeFailure
        }
        if sp.enabled, outcome == .presented {
            sp.recordPresent(
                nanos: DispatchTime.now().uptimeNanoseconds &- presentStart,
                drawableWait: drawableWaitNanos,
                semaphoreWait: renderer.stats.semaphoreWaitNanos,
                schedule: renderer.stats.presentScheduleNanos,
                instanceBuild: renderer.stats.buildInstancesNanos,
                upload: renderer.stats.uploadNanos
            )
        }
        return outcome
    }

    /// Append the buffer line just below the scrolled viewport as a display-only (rows+1)th row —
    /// the smooth-scroll peek row the fraction translate reveals. The snapshot stays a uniform
    /// window over `[history ++ viewport]`, so `buildShifted` rotates it like any other row.
    /// `offset ≥ 1` guarantees the line below the viewport exists (it is at worst the live bottom
    /// row); a defensive blank-pad covers width races during reflow. Runs on the emulator queue
    /// (called from the build closure).
    private nonisolated static func appendingPeekRow(
        to snapshot: TerminalGridSnapshot, emulator: TerminalEmulator, offset: Int
    ) -> TerminalGridSnapshot {
        let peekIndex = emulator.historyCount - offset + snapshot.rows
        var line = peekIndex >= 0 && peekIndex < emulator.bufferLineCount
            ? emulator.bufferLine(peekIndex) : []
        if line.count < snapshot.cols {
            line.append(contentsOf: Array(repeating: .blank, count: snapshot.cols - line.count))
        } else if line.count > snapshot.cols {
            line.removeLast(line.count - snapshot.cols)
        }
        return TerminalGridSnapshot(
            cols: snapshot.cols, rows: snapshot.rows + 1, cells: snapshot.cells + line,
            cursor: snapshot.cursor, images: snapshot.images, marks: snapshot.marks
        )
    }

    /// Re-present the last built frame at the *current* drawable size with no emulator-queue access
    /// — the smooth-resize fast path. Used by `layout()` during a live drag/animation: the grid
    /// hasn't reflowed yet (deferred to drag-end), so the cached frame is still the correct content;
    /// we just need to redraw it into the freshly-resized drawable. Returns false when there's no
    /// valid cached frame for this generation, so the caller falls back to a full synchronous build.
    ///
    /// Damage selection is the per-tick cost lever. Under the drag-frozen origin every row-cache
    /// key (cols/rows/origin/atlas) is stable, so when the cache verifiably holds this exact
    /// frame's rows (`lastPresentedResultIsRendererCoherent`) an EMPTY damage reuses every row —
    /// `encodedRows == 0`, zero-copy instance bind, only the viewport uniform changes. When it
    /// doesn't (preview reflow replaced the frame, a drop wiped the cache), a `full` damage pays
    /// one rebuild *through the cache-populating path* so the very next tick is free again —
    /// unlike `damage: nil`, which rebuilds AND leaves the cache empty, making every sub-cell drag
    /// tick a full re-encode (the pre-#57 resize-lag source). Image frames take the same two
    /// paths — image quads draw outside the cell instance buffers, so they never gate reuse.
    @discardableResult
    func repaintLastFrame() -> Bool {
        guard let result = lastPresentedResult,
              result.generation == renderGeneration,
              window != nil, let renderer else { return false }
        let damage: TerminalDamage?
        if lastPresentedResultIsRendererCoherent {
            damage = TerminalDamage(rows: [], full: false)
        } else {
            damage = TerminalDamage(full: true)
        }
        let didPresent = presentFrame(result, damage: damage) == .presented
        if didPresent {
            lastPresentedResultIsRendererCoherent = renderer.stats.rowCacheCoherent
            onRenderStats?(renderer.stats)
        }
        return didPresent
    }

    /// Build a live re-wrap preview of the viewport at the current drag target `nc × nr` and present
    /// it, so the drag shows the content *re-wrapped to the new width* rather than the old grid
    /// revealed/clipped. Pure: reads the emulator via `previewViewportReflow` (O(visible),
    /// non-mutating) and never reflows history or sends `SIGWINCH` (both deferred to
    /// `commitGridSize`), so the shell's width belief never desyncs from the display. Skipped when an
    /// overlay the preview can't represent is active (scrollback, selection, IME pre-edit, find, copy
    /// mode) or on the alternate screen — `repaintLastFrame` then keeps re-presenting the cached frame.
    ///
    /// The build runs **async on the emulator queue** (latest-wins token, the `renderNowOffMain`
    /// coalescing pattern): a boundary-crossing tick never parks main on the queue — not behind an
    /// in-flight parse under heavy output (the old `pendingFeed.isBusy` skip dodged that but still
    /// paid the full build wall when idle), and not even for the build itself. While the build is in
    /// flight, `layout()` keeps re-presenting the last cached frame at the new drawable size, so the
    /// drag never drops a frame; the re-wrapped content lands on the next main hop via
    /// `presentResizePreview`. A fast drag's boundary builds coalesce to the freshest `nc × nr`.
    ///
    /// DELIBERATE TRADE: the boundary tick shows ≤1 frame of the previous column count's wrap at
    /// the new drawable size before the re-wrap lands (the old synchronous code showed the re-wrap
    /// same-tick but stalled main for the reflow+build — a blown frame budget on big grids, and it
    /// SKIPPED the re-wrap entirely under parser load). Frame pacing wins over single-frame wrap
    /// fidelity; under load the async path is strictly better (stale wrap either way, no stall).
    private func updateResizePreview(cols nc: Int, rows nr: Int) {
        // Only on the off-main pipeline (the emulator lives on its serial queue; when the flag is
        // off it is main-confined and the async hop below would touch it off its confinement domain).
        guard offMainParserFramePipelineEnabled else { return }
        guard scrollOffset == 0, copyMode == nil, currentSelectionRegion == nil,
              markedText.isEmpty, !findActive else { return }
        let config = frameBuildConfiguration
        let bg = canvasBackground
        let opacity = canvasOpacity
        let isFocused = effectivelyFocused
        let generation = renderGeneration
        let state = emulatorState
        // Preview-namespace token (NOT claimFrameToken): the output pipeline must not cancel an
        // in-flight re-wrap — during an animated resize both pipelines run concurrently.
        let token = state.claimPreviewToken()
        state.async { emulator in
            // Latest-wins within the preview pipeline: a further boundary tick is already queued
            // behind this one — skip; it renders a strictly newer drag target.
            guard state.isLatestPreviewToken(token) else { return }
            guard let preview = emulator.previewViewportReflow(cols: nc, rows: nr) else { return }
            let buildStart = DispatchTime.now().uptimeNanoseconds
            let builder = config.makeBuilder()
            var frame = FrameSignposter.shared.interval("frameBuild") {
                builder.build(preview, region: nil, imageProvider: { emulator.image(for: $0) })
            }
            frame.cursor.hollow = !isFocused
            // NOTE: must not touch `state.lastPlainFrame`/`lastViewportFrame` — the preview has
            // different dims than the live grid and would poison the damage-reuse caches.
            let result = SurfaceFrameBuildResult(
                generation: generation, frame: frame, damage: nil,
                frameBuildNanos: DispatchTime.now().uptimeNanoseconds &- buildStart,
                clearColor: builder.renderColor(bg, alpha: opacity)
            )
            DispatchQueue.main.async { [weak self] in
                self?.presentResizePreview(result, cols: nc, rows: nr, token: token)
            }
        }
    }

    /// Main-hop landing for an async preview build. Drops a stale preview outright rather than
    /// stashing it: an async build can land after the drag moved to a different cell target, or
    /// after the settled commit bumped the generation — stashing a frame for the wrong grid would
    /// re-present mis-wrapped content on every subsequent sub-cell repaint. A current preview is
    /// stashed exactly like the old synchronous path (coherence broken: the renderer cache still
    /// holds the previous frame's rows) and repainted immediately — the repaint pays the one
    /// cache-populating full rebuild per geometry change, and the tick after it is free again.
    /// Returns whether the preview was accepted (stashed + repaint attempted) — false = dropped
    /// as stale. The Bool is for tests pinning the guards; production callers ignore it.
    @discardableResult
    private func presentResizePreview(
        _ result: SurfaceFrameBuildResult, cols: Int, rows: Int, token: UInt64
    ) -> Bool {
        guard renderGeneration == result.generation,         // not superseded by commitGridSize
              emulatorState.isLatestPreviewToken(token),      // not superseded by a newer preview
              cols == previewCols, rows == previewRows,       // still the current drag target
              window != nil else { return false }
        lastPresentedResult = result
        // The preview replaced the frame WITHOUT a present: the renderer cache still holds the
        // previous frame's rows, so the repaint below takes the cache-populating full path.
        lastPresentedResultIsRendererCoherent = false
        // Present now (sanctioned drag path: the same `repaintLastFrame` that `layout()` drives);
        // when no drawable is free this turn, the next layout pass repaints it instead.
        if !repaintLastFrame() { needsLayout = true }
        return true
    }
}
