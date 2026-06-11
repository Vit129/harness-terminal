# P10 Task: Lazy Scrollback Reflow

## Problem

`TerminalScreen.reflow(toCols:rows:)` in
`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Screen/TerminalScreen.swift`
walks **every row in the scrollback history** on every resize. The function comment
says "O(history) bulk" — this means a 50,000-line scrollback = 50,000 rows processed
synchronously on the engine queue before the resize is committed.

The user experiences this as:
- Lag/stutter when dragging the window edge with deep scrollback
- Brief PTY input freeze (the engine queue is blocked)
- Noticeable jank when toggling the sidebar or opening the file editor split

## Background

Key files:
- `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Screen/TerminalScreen.swift`
  — `reflow(toCols:rows:)` at line ~968, calls `rewrapRows(sourceCount: historyCount + rows, ...)` 
- `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Screen/HistoryRingBuffer.swift`
  — already a proper ring buffer (O(1) append/trim, random access). No changes needed here.
- `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Emulator/TerminalEmulator.swift`
  — calls `screen.resize(cols:rows:)` which calls `reflow`

The `HarnessTerminalSurfaceView` at `Packages/HarnessTerminalKit/...` drives live resize:
- `computeGridGeometry()` → `requestLiveResizeCommit()` → `commitGridSize()` → PTY resize

## Strategy: Lazy Reflow (Two-Phase)

Split reflow into two phases:

### Phase 1 — Immediate (synchronous, always runs)
Reflow only the **viewport** (current `rows` lines) + a small **lookahead** above it
(e.g. `rows * 2` lines) into the new column width. This is fast: O(viewport) ≈ O(40).
Set up a "pending reflow" marker with the new column width.

### Phase 2 — Deferred (async, runs after resize settles)
After the viewport reflow commits and the user sees a correct screen, schedule the
full history reflow on a background DispatchQueue (or Task with `.utility` priority).
When it finishes, patch the history in-place and post a damage notification so the
renderer picks up the corrected scrollback.

During the deferred phase:
- New output from PTY continues normally — live rows go into the viewport as usual
- If another resize fires before Phase 2 finishes, cancel the pending task and start fresh
- Scrollback access during the pending phase uses the **pre-reflow** history (slightly
  stale widths) — acceptable because the user isn't scrolled into that region while resizing

## Implementation

### 1. Add a `pendingReflowTask` field to `TerminalScreen`

```swift
// In TerminalScreen
private var pendingReflowTask: DispatchWorkItem?
private var committedCols: Int = 0  // columns used by the current history
```

### 2. Split `reflow(toCols:rows:)` into two helpers

```swift
// Fast path — reflow only viewport + lookahead
private func reflowViewport(toCols nc: Int, rows nr: Int) { ... }

// Full path — reflow entire history (existing logic)
private func reflowFull(toCols nc: Int, rows nr: Int) { ... }
```

### 3. In `resize(cols:rows:)`, use the fast path first

```swift
mutating func resize(cols nc: Int, rows nr: Int) {
    guard nc != cols || nr != rows else { return }
    
    if nc == committedCols {
        // Width unchanged — existing fast path (just adjusts row count, no reflow)
        resizeRowsOnly(to: nr)
    } else {
        // Width changed — reflow viewport immediately
        reflowViewport(toCols: nc, rows: nr)
        committedCols = nc
        
        // Schedule full history reflow deferred
        pendingReflowTask?.cancel()
        let task = DispatchWorkItem { [self] in
            var copy = self
            copy.reflowFull(toCols: nc, rows: nr)
            // merge history back
        }
        pendingReflowTask = task
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1, execute: task)
    }
}
```

> **Note:** `TerminalScreen` is a struct. The deferred task needs to capture state carefully.
> Consider using a class wrapper or `actor` for the history buffer if mutating from background.
> An alternative: keep `TerminalScreen` as-is and run the deferred reflow on the **same**
> engine queue (which is serial) — just `asyncAfter` on the engine's own queue so it runs
> after the current frame is presented. This is the safer approach.

## Simpler Alternative (Recommended for v1)

Instead of true background reflow, just **skip history reflow during live resize** and
run it once when resize settles:

```swift
// TerminalEmulator: add a "live resize in progress" flag
var isLiveResizing = false

// In HarnessTerminalSurfaceView.viewWillStartLiveResize():
emulator.isLiveResizing = true

// In HarnessTerminalSurfaceView.viewDidEndLiveResize():
emulator.isLiveResizing = false
emulator.flush()  // run the deferred full reflow once

// In TerminalScreen.reflow():
if screen.isLiveResizing && history.count > rows * 4 {
    // Only reflow viewport + 4 screen heights of history
    // Mark rest as "needs reflow" with stored old width
    return
}
// else: full reflow as normal
```

This is safer and still eliminates the O(history) lag from *every* drag step.

## Constraints

- `HarnessTerminalEngine` has `-warnings-as-errors`. No new warnings.
- `TerminalScreen` is a **struct** — be careful with mutation semantics.
- The engine emulator queue is the ownership queue for `TerminalScreen` — all mutations
  must happen on it. If using async, dispatch back to the same queue.
- All existing reflow golden tests in `Tests/HarnessTerminalEngineTests/ReflowGolden/`
  must still pass: `swift test --filter ReflowTests`
- `swift test` full suite must pass.
- Benchmark before/after with `HARNESS_BENCHMARKS=1 swift test -c release --filter HarnessBenchmarks`

## Success Criteria

- Dragging window edge with 10k+ line scrollback: no visible lag on viewport
- Full history reflow completes in background (or on resize-end)
- All reflow golden tests pass
- No input lag regression (existing benchmark baseline)
