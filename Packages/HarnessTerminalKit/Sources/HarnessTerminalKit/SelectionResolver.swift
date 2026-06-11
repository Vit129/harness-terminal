import HarnessCopyMode
import HarnessTerminalEngine
import HarnessTerminalRenderer

/// Pure selection resolution logic extracted from `HarnessTerminalSurfaceView+SelectionAndLinks`.
/// Resolves raw mouse selection inputs into render regions without touching view state.
enum SelectionResolver {
    /// Raw selection inputs captured on the main thread. Sendable so the off-main build closure
    /// can capture it safely.
    struct RawSelection: Sendable {
        let anchorRow: Int, anchorColumn: Int
        let headRow: Int, headColumn: Int
        let granularity: HarnessTerminalSurfaceView.SelectionGranularity
        let rectangular: Bool
    }

    /// Resolve a raw selection into a render region. Call ON the emulator queue (inside the build)
    /// so `.word` expansion reads `wordColumnRange` directly without a main-stalling `emulatorSync`.
    static func resolve(
        _ sel: RawSelection?,
        emulator: TerminalEmulator,
        scrollOffset: Int,
        columns: Int
    ) -> SelectionRegion? {
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
}
