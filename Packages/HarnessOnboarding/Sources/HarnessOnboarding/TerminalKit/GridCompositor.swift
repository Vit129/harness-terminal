import Foundation

// NOTE: The authoritative compositor lives at:
//   Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/GridCompositor.swift
// This INTENTIONAL simplified copy avoids pulling HarnessTerminalEngine, HarnessCopyMode,
// and HarnessCore into the onboarding package — the first-run wizard only needs display
// rendering (no PTY, no damage tracking, no real grid access). See the note in the
// authoritative file for the full rationale.
//
// Ported (near-verbatim) from Packages/HarnessTerminalKit/.../GridCompositor.swift.
// Three edits versus the monorepo original:
//   1. drop the HarnessCopyMode/HarnessCore/HarnessTerminalEngine imports (types are inlined here),
//   2. rename the internal `RenderCell` to `ComposedCell`,
//   3. add `compose(panes:statusLines:)` returning the composed cell grid the SwiftUI
//      Canvas renders (the original only emits ANSI).
// Copy-mode selection/search overlays are removed (the onboarding never sets them); the
// layout, border junctions, pane-border labels, and status-line composition are unchanged.

/// One pane to composite: where it sits (`rect`) and its current screen contents (`grid`).
public struct CompositorPane: Sendable {
    public var rect: PaneRect
    public var grid: TerminalGridSnapshot
    public var isActive: Bool
    /// `window-style`/`pane-style` base colors substituted into default-colored cells (dim inactive panes).
    public var baseForeground: TerminalGridColor
    public var baseBackground: TerminalGridColor
    /// `pane-border-format` label drawn on this pane's border row, centered over the box-drawing.
    public var borderLabel: String?

    public init(
        rect: PaneRect,
        grid: TerminalGridSnapshot,
        isActive: Bool,
        baseForeground: TerminalGridColor = .none,
        baseBackground: TerminalGridColor = .none,
        borderLabel: String? = nil
    ) {
        self.rect = rect
        self.grid = grid
        self.isActive = isActive
        self.baseForeground = baseForeground
        self.baseBackground = baseBackground
        self.borderLabel = borderLabel
    }
}

/// The composited frame the Canvas renderer consumes: a `cols × rows` row-major cell buffer
/// plus the active pane's cursor position (in frame cell coordinates), or nil when hidden.
public struct ComposedFrame: Sendable {
    public let cols: Int
    public let rows: Int
    public let cells: [ComposedCell]
    public let cursor: (x: Int, y: Int)?
}

/// Composites multiple pane grids into a single `cols × rows` cell buffer (panes +
/// box-drawing borders + status rows) — the core of the `harness attach` renderer. Pure
/// and deterministic.
public final class GridCompositor {
    public private(set) var cols: Int
    public private(set) var rows: Int

    private var front: [ComposedCell]?

    public init(cols: Int, rows: Int) {
        self.cols = max(1, cols)
        self.rows = max(1, rows)
    }

    public func resize(cols: Int, rows: Int) {
        self.cols = max(1, cols)
        self.rows = max(1, rows)
        front = nil
    }

    public func invalidate() { front = nil }

    /// Build the composited cell buffer + cursor without emitting ANSI. This is what the
    /// SwiftUI Canvas renderer draws.
    public func compose(panes: [CompositorPane], statusLines: [[StyledSegment]]? = nil) -> ComposedFrame {
        let (buffer, cursor) = build(panes: panes, statusLines: statusLines)
        return ComposedFrame(cols: cols, rows: rows, cells: buffer, cursor: cursor)
    }

    /// Render `panes` plus an optional `status` line into ANSI (kept for parity with the
    /// monorepo renderer; the onboarding uses `compose` instead).
    public func render(panes: [CompositorPane], status: String? = nil, statusSegments: [StyledSegment]? = nil) -> String {
        let lines: [[StyledSegment]]?
        if let statusSegments {
            lines = [statusSegments]
        } else if let status {
            lines = [[StyledSegment(text: status)]]
        } else {
            lines = nil
        }
        return render(panes: panes, statusLines: lines)
    }

    public func render(panes: [CompositorPane], statusLines: [[StyledSegment]]?) -> String {
        let (buffer, cursor) = build(panes: panes, statusLines: statusLines)
        let ansi = emit(buffer: buffer, cursor: cursor)
        front = buffer
        return ansi
    }

    // MARK: - Compose

    private func build(panes: [CompositorPane], statusLines: [[StyledSegment]]?) -> ([ComposedCell], (x: Int, y: Int)?) {
        let statusCount = max(0, min(rows, statusLines?.count ?? 0))
        var buffer = [ComposedCell](repeating: .blank, count: cols * rows)

        let paneArea = rows - statusCount
        paintBorders(into: &buffer, panes: panes, paneAreaRows: paneArea)

        var cursor: (x: Int, y: Int)? = nil
        for pane in panes {
            paint(pane: pane, into: &buffer, into: &cursor)
        }

        for pane in panes {
            guard let label = pane.borderLabel, !label.isEmpty, let row = pane.rect.labelRow else { continue }
            paintBorderLabel(label, row: row, paneX: pane.rect.x, paneCols: pane.rect.cols, active: pane.isActive, into: &buffer)
        }

        if let statusLines {
            for (i, line) in statusLines.prefix(statusCount).enumerated() {
                paintStatusSegments(line, row: rows - 1 - i, into: &buffer)
            }
        }
        return (buffer, cursor)
    }

    // MARK: - Painting

    private func paint(
        pane: CompositorPane,
        into buffer: inout [ComposedCell],
        into cursor: inout (x: Int, y: Int)?
    ) {
        let rect = pane.rect
        let grid = pane.grid
        let maxRows = min(rect.rows, grid.rows)
        let maxCols = min(rect.cols, grid.cols)
        for gy in 0 ..< maxRows {
            let by = rect.y + gy
            guard by >= 0, by < rows else { continue }
            for gx in 0 ..< maxCols {
                let bx = rect.x + gx
                guard bx >= 0, bx < cols else { continue }
                guard let cell = grid.cell(row: gy, col: gx) else { continue }
                if cell.width == .spacerTail { continue }
                var rc = ComposedCell(cell)
                if pane.baseForeground != .none, rc.fg == .none { rc.fg = pane.baseForeground }
                if pane.baseBackground != .none, rc.bg == .none { rc.bg = pane.baseBackground }
                buffer[by * cols + bx] = rc
            }
        }

        if pane.isActive, grid.cursor.visible {
            let cx = rect.x + grid.cursor.col
            let cy = rect.y + grid.cursor.row
            if cx >= 0, cx < cols, cy >= 0, cy < rows { cursor = (cx, cy) }
        }
    }

    private func paintStatusSegments(_ segments: [StyledSegment], row: Int, into buffer: inout [ComposedCell]) {
        var x = 0
        for seg in segments {
            let plain = seg.fg == nil && seg.bg == nil && !seg.bold && !seg.italic && !seg.underline && !seg.reverse && !seg.dim
            for scalar in seg.text.unicodeScalars {
                guard x < cols else { break }
                buffer[row * cols + x] = ComposedCell(
                    codepoint: scalar.value,
                    fg: Self.gridColor(seg.fg),
                    bg: Self.gridColor(seg.bg),
                    bold: seg.bold,
                    dim: seg.dim,
                    italic: seg.italic,
                    underline: seg.underline ? .single : .none,
                    inverse: plain ? true : seg.reverse
                )
                x += 1
            }
            if x >= cols { break }
        }
        while x < cols {
            buffer[row * cols + x] = ComposedCell(codepoint: 0x20, inverse: true)
            x += 1
        }
    }

    private func paintBorderLabel(_ text: String, row: Int, paneX: Int, paneCols: Int, active: Bool, into buffer: inout [ComposedCell]) {
        guard row >= 0, row < rows, paneCols > 0 else { return }
        let scalars = Array(text.unicodeScalars)
        let width = min(scalars.count, paneCols)
        guard width > 0 else { return }
        let startX = paneX + max(0, (paneCols - width) / 2)
        let fg: TerminalGridColor = active ? .palette(15) : .palette(8)
        for i in 0 ..< width {
            let x = startX + i
            guard x >= 0, x < cols, x < paneX + paneCols else { continue }
            buffer[row * cols + x] = ComposedCell(codepoint: scalars[i].value, fg: fg, bold: active)
        }
    }

    public static func gridColor(_ color: FormatColor?) -> TerminalGridColor {
        switch color {
        case nil, .some(.none): return .none
        case let .some(.palette(i)): return .palette(i)
        case let .some(.rgb(r, g, b)): return .rgb(r: r, g: g, b: b)
        }
    }

    private func paintBorders(
        into buffer: inout [ComposedCell],
        panes: [CompositorPane],
        paneAreaRows: Int
    ) {
        guard paneAreaRows > 0 else { return }
        var covered = [Bool](repeating: false, count: cols * paneAreaRows)
        for pane in panes {
            let r = pane.rect
            for y in max(0, r.y) ..< min(paneAreaRows, r.y + r.rows) {
                for x in max(0, r.x) ..< min(cols, r.x + r.cols) {
                    covered[y * cols + x] = true
                }
            }
        }

        func isBorder(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, x < cols, y >= 0, y < paneAreaRows else { return false }
            return !covered[y * cols + x]
        }

        for y in 0 ..< paneAreaRows {
            for x in 0 ..< cols where isBorder(x, y) {
                let up = isBorder(x, y - 1)
                let down = isBorder(x, y + 1)
                let left = isBorder(x - 1, y)
                let right = isBorder(x + 1, y)
                buffer[y * cols + x] = ComposedCell(
                    codepoint: boxGlyph(up: up, down: down, left: left, right: right),
                    fg: .palette(8)
                )
            }
        }
    }

    private func boxGlyph(up: Bool, down: Bool, left: Bool, right: Bool) -> UInt32 {
        switch (up, down, left, right) {
        case (true, true, true, true): return 0x253C   // ┼
        case (true, true, true, false): return 0x2524  // ┤
        case (true, true, false, true): return 0x251C  // ├
        case (true, true, false, false): return 0x2502 // │
        case (false, true, true, true): return 0x252C  // ┬
        case (true, false, true, true): return 0x2534  // ┴
        case (true, false, true, false): return 0x2518 // ┘
        case (true, false, false, true): return 0x2514 // └
        case (false, true, true, false): return 0x2510 // ┐
        case (false, true, false, true): return 0x250C // ┌
        case (false, false, true, true): return 0x2500 // ─
        case (true, false, false, false), (false, true, false, false): return 0x2502 // │
        case (false, false, true, false), (false, false, false, true): return 0x2500 // ─
        default: return 0x2502
        }
    }

    // MARK: - ANSI emission (parity with monorepo; unused by the Canvas renderer)

    private func emit(buffer: [ComposedCell], cursor: (x: Int, y: Int)?) -> String {
        var out = ""
        out += "\u{1b}[?25l"
        let full = front == nil || front?.count != buffer.count
        if full { out += "\u{1b}[2J" }

        var lastSGR = ""
        var penX = -1
        var penY = -1
        for y in 0 ..< rows {
            for x in 0 ..< cols {
                let idx = y * cols + x
                let cell = buffer[idx]
                if !full, let front, front[idx] == cell { continue }
                if penY != y || penX != x { out += "\u{1b}[\(y + 1);\(x + 1)H" }
                let sgr = cell.sgr
                if sgr != lastSGR { out += sgr; lastSGR = sgr }
                out.unicodeScalars.append(cell.scalar)
                penX = x + 1
                penY = y
            }
        }
        out += "\u{1b}[0m"
        if let cursor {
            out += "\u{1b}[\(cursor.y + 1);\(cursor.x + 1)H"
            out += "\u{1b}[?25h"
        }
        return out
    }
}

// MARK: - ComposedCell

/// A flattened cell in the composited frame: a glyph plus the SGR state we keep.
public struct ComposedCell: Equatable, Sendable {
    public var codepoint: UInt32
    public var fg: TerminalGridColor
    public var bg: TerminalGridColor
    public var underlineColor: TerminalGridColor
    public var bold: Bool
    public var dim: Bool
    public var italic: Bool
    public var underline: TerminalGridUnderline
    public var blink: Bool
    public var inverse: Bool
    public var invisible: Bool
    public var strikethrough: Bool
    public var overline: Bool

    public init(
        codepoint: UInt32,
        fg: TerminalGridColor = .none,
        bg: TerminalGridColor = .none,
        underlineColor: TerminalGridColor = .none,
        bold: Bool = false,
        dim: Bool = false,
        italic: Bool = false,
        underline: TerminalGridUnderline = .none,
        blink: Bool = false,
        inverse: Bool = false,
        invisible: Bool = false,
        strikethrough: Bool = false,
        overline: Bool = false
    ) {
        self.codepoint = codepoint
        self.fg = fg
        self.bg = bg
        self.underlineColor = underlineColor
        self.bold = bold
        self.dim = dim
        self.italic = italic
        self.underline = underline
        self.blink = blink
        self.inverse = inverse
        self.invisible = invisible
        self.strikethrough = strikethrough
        self.overline = overline
    }

    public init(_ c: TerminalGridCell) {
        codepoint = c.codepoint
        fg = c.foreground
        bg = c.background
        underlineColor = c.underlineColor
        bold = c.bold
        dim = c.faint
        italic = c.italic
        underline = c.underline
        blink = c.blink
        inverse = c.inverse
        invisible = c.invisible
        strikethrough = c.strikethrough
        overline = c.overline
    }

    public static let blank = ComposedCell(codepoint: 0x20)

    private static let space = Unicode.Scalar(0x20)!

    /// The glyph to draw (empty cells render as a space).
    public var scalar: Unicode.Scalar {
        guard codepoint != 0, let s = Unicode.Scalar(codepoint) else { return Self.space }
        return s
    }

    /// Build a `TerminalGridCell` view of this composed cell so `CellColorResolver` can
    /// resolve its final fg/bg using the exact monorepo rules.
    public var asGridCell: TerminalGridCell {
        TerminalGridCell(
            codepoint: codepoint, foreground: fg, background: bg, underlineColor: underlineColor,
            bold: bold, faint: dim, italic: italic, underline: underline, blink: blink,
            inverse: inverse, invisible: invisible, strikethrough: strikethrough, overline: overline
        )
    }

    var sgr: String {
        var codes: [String] = ["0"]
        if bold { codes.append("1") }
        if dim { codes.append("2") }
        if italic { codes.append("3") }
        codes.append(contentsOf: Self.underlineCodes(underline))
        if blink { codes.append("5") }
        if inverse { codes.append("7") }
        if invisible { codes.append("8") }
        if strikethrough { codes.append("9") }
        if overline { codes.append("53") }
        codes.append(contentsOf: Self.colorCodes(fg, kind: .fg))
        codes.append(contentsOf: Self.colorCodes(bg, kind: .bg))
        if underline != .none { codes.append(contentsOf: Self.colorCodes(underlineColor, kind: .underline)) }
        return "\u{1b}[\(codes.joined(separator: ";"))m"
    }

    private static func underlineCodes(_ style: TerminalGridUnderline) -> [String] {
        switch style {
        case .none: return []
        case .single: return ["4"]
        case .double: return ["21"]
        case .curly: return ["4:3"]
        case .dotted: return ["4:4"]
        case .dashed: return ["4:5"]
        }
    }

    private enum ColorKind {
        case fg, bg, underline
        var base: Int { switch self { case .fg: 38; case .bg: 48; case .underline: 58 } }
    }

    private static func colorCodes(_ color: TerminalGridColor, kind: ColorKind) -> [String] {
        switch color {
        case .none: return []
        case let .palette(idx): return ["\(kind.base)", "5", "\(idx)"]
        case let .rgb(r, g, b): return ["\(kind.base)", "2", "\(r)", "\(g)", "\(b)"]
        }
    }
}
