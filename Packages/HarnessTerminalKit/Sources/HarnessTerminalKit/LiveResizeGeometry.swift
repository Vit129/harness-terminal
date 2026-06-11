/// Pure grid geometry computation for live-resize. Extracted from
/// `HarnessTerminalSurfaceView.computeGridGeometry` to separate pure logic from view state.
///
/// Normal path: the origin is the padding inset, balanced-centered when enabled.
/// Live drag (`frozenOrigin` non-nil): hold the drag-start origin — re-centering every
/// sub-cell layout shifts the text ±1px per pixel of drag (visible shimmer). Clamped so a
/// shrink can't push the grid past the drawable's right/bottom edge.
enum LiveResizeGeometry {
    struct Result {
        var cols: Int
        var rows: Int
        var originX: Int
        var originY: Int
    }

    /// Compute columns/rows and draw origin from pixel dimensions, padding, cell metrics,
    /// and optional frozen origin (live-resize anchor).
    static func compute(
        pixelWidth: Int, pixelHeight: Int,
        basePadX: Int, basePadY: Int,
        cellWidth: Int, cellHeight: Int,
        balanced: Bool,
        frozenOrigin: (x: Int, y: Int)?
    ) -> Result {
        let usableWidth = max(1, pixelWidth - 2 * basePadX)
        let usableHeight = max(1, pixelHeight - 2 * basePadY)
        let cols = max(1, usableWidth / cellWidth)
        let rows = max(1, usableHeight / cellHeight)
        if let frozen = frozenOrigin {
            return Result(
                cols: cols, rows: rows,
                originX: min(frozen.x, max(0, pixelWidth - cols * cellWidth)),
                originY: min(frozen.y, max(0, pixelHeight - rows * cellHeight))
            )
        }
        var originX = basePadX
        var originY = basePadY
        if balanced {
            originX += (usableWidth - cols * cellWidth) / 2
            originY += (usableHeight - rows * cellHeight) / 2
        }
        return Result(cols: cols, rows: rows, originX: originX, originY: originY)
    }
}
