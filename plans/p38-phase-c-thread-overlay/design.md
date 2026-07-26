# P38 Phase C — Agent Thread UX on Existing Block Capture

Source: `agent-memory/plans/p38-competitive-feature-gaps.md` Phase C. Design produced via a
Fable consult (2026-07-14), file/line claims independently re-verified against live source
before implementation (lesson from Phase B's `AgentChipView` dead-code miss — see RL-067).

## Pivot (2026-07-15, mid live-test) — supersedes the original design below

The original design (standalone `TerminalThreadOverlay`, ⇧⌘L, AppKit `NSTableView` — see
"Original design" section below, kept for history) was fully built, gated green, then **deleted**
during live testing:

- Real user testing found the overlay's close button visually colliding with `PaneSplitButtonsView`
  (top-anchor offset was 0, not the 44pt `TerminalFindBar` uses).
- Double-click and the filter/magnifying-glass affordance did not work — root cause never found
  (structural wiring looked correct on static read; live debugging was cut short by the pivot
  below before a repro could be nailed down).
- Mid-fix, the user asked the more fundamental question: why two separate pickers (Recipes ⌘⇧R,
  Thread View ⇧⌘L) for two things that are both "pick a command to act on"? Decision, confirmed
  via `AskUserQuestion`: merge into **one flat list** (not two sections) mixing saved recipes and
  captured command history, and **migrate to the Recipes floating-panel SwiftUI pattern**
  (`RecipePickerController`, `NSPanel` + `NSHostingController`) rather than the AppKit in-pane
  overlay. The AppKit overlay class and its test file were deleted outright, not kept as a
  fallback.

**Current architecture:** `Apps/Kouen/Sources/KouenApp/UI/Shared/RecipePickerController.swift`.
`PickerItem` enum (`.recipe(Recipe)` / `.historyBlock(TerminalBlock)`) — one flat, filterable,
most-recent-history-first list. `RecipePickerModel` (`@Observable`) holds `allItems`/`filteredItems`/
`selectedIndex`; `activateSelected()` branches on the enum case: a recipe either sends its command
immediately or opens the composer (existing behavior, unchanged), a history block calls
`host.jumpToBlock(promptLine:)` (new). Single entry point: **⌘⇧R only** — the user explicitly asked
to drop the second shortcut once the merge worked ("ลองกด ⌘⇧R แล้ว งั้นเหลือ shortcut ตัวเดียว").
Menu item renamed "Recipes…" → "Recipes & History…" in `MainMenuBuilder.swift` to match.

**What stayed from the original design, unchanged:** the P34 engine/surface plumbing —
`TerminalEmulator.blocks`, `KouenTerminalSurfaceView.blocks`/`jumpToBlock(promptLine:)` — all of
Stage 1-2 below is still exactly as built and still in use by the new picker. Everything from
"Design: overlay, not a new render subtree" onward describes the **deleted** approach; do not
extend `TerminalThreadOverlay` or `⇧⌘L` — they no longer exist in the codebase.

**Not yet re-verified live:** selecting a history item (click, double-click, or Enter) correctly
calling `jumpToBlock` and landing the terminal viewport on that command's output — this is the same
interaction that was broken in the deleted overlay and has not been re-tested in the new picker.

## Original design (2026-07-14, deleted 2026-07-15 — kept for history only)

## What P34 actually built (verified)

- `TerminalBlock` (`Packages/KouenTerminalEngine/Sources/KouenTerminalEngine/Emulator/TerminalBlock.swift:8`):
  `id`, `command`, `promptLine`, `outputStartLine`, `outputEndLine?`, `exitCode?`, timestamps.
- `TerminalBlockStore` (same file, line 28): `private(set) var blocks: [TerminalBlock]`, internal
  (module-scope) — this IS the full list, just never exposed publicly.
- `TerminalEmulator` (`.../Emulator/TerminalEmulator.swift:220-226`): `block(atPromptLine:)`,
  `lastBlock` (last finished), `block(id:)` — no full-list accessor. **This is the one missing
  primitive.**
- Client UI today: block actions live only in the right-click context menu
  (`KouenTerminalSurfaceView+Find.swift`), gated on `block(atPromptLine:)`.
- Daemon/MCP path (`RealPty.block(id:)`, `BlockSummary`) is entirely separate — replays scrollback
  through a headless `KouenGridTerminal`. Not touched by this phase.

## Known caveat (pre-existing, inherited not fixed)

Block line indices are never rebased after scrollback history eviction (`TerminalScreen.dropHistoryHead`
shifts image placements but not block ranges) — jump-to-block on an evicted block can land on the
wrong row. Pre-existing since P34 (already silently degrades the context menu). Mitigate by
clamping (`max(0, promptLine)`), do not attempt to fix by rebasing the store — that touches P34
semantics and needs its own dedicated test pass, out of scope here.

## Design: overlay, not a new render subtree

Follow `TerminalFindBar`'s exact pattern (`TerminalHostView.swift:609-640`, `toggleFind`/`showFind`/
`hideFind`) — a `TerminalThreadOverlay` NSView (NSVisualEffectView backdrop + NSTableView of block
rows: command, exit-code badge, relative time, "running" state for unfinished blocks), added/removed
as a subview of `TerminalHostView`, mutually exclusive with the find bar. Rejected: re-rendering
blocks as a real native text-view subtree (Warp-style) — duplicates the renderer's output, solves
live-update/resize/selection all over again, multi-week scope beyond what this phase needs.

CASE-004 note (`agent-memory/knowledge/cases/metal-displaylink.md`): an overlay NSView above a
Metal terminal surface needs `zPosition=1000` or it's invisible — `TerminalFindBar` already handles
this correctly since it's the exact same situation; the new overlay follows the same construction
path so it inherits the fix for free.

## cmd-F contract (C2) — contextual, not a rewrite of `updateFind`

- Thread view closed: ⌘F behaves exactly as today, `KouenTerminalSurfaceView+Find.swift`'s
  `updateFind(query:)` untouched.
- Thread view open: ⌘F focuses the overlay's own filter field (filters block list by `command`,
  case-insensitive) — searches ALL captured blocks including ones evicted from live scrollback,
  which raw buffer search cannot reach.
- Per-row "Find in output" escape hatch: closes overlay, opens classic find bar pre-seeded via
  existing `showFind` + `updateFind(query:)`.

Rejected: rewriting `updateFind` itself to try block-command matches first — touches the one
function the phase's own gate says must not regress, and would hide in-output matches whenever a
command's text happens to contain the query.

## Staged implementation

1. **Engine accessor** (additive only): `TerminalEmulator.swift` — add
   `public var blocks: [TerminalBlock] { blockStore.blocks }` next to the existing L220-226
   accessors. Test: one case in `Tests/KouenTerminalEngineTests/TerminalBlockStoreTests.swift`.
2. **Surface plumbing**: `KouenTerminalSurfaceView` — `public var blocks: [TerminalBlock]` via
   `emulatorSync`, `public func jumpToBlock(promptLine:)` delegating to the existing
   `scrollToBufferLine` (already clamps).
3. **Thread overlay UI**: new `TerminalThreadOverlay.swift` (filter field + block table,
   `onSelectBlock`/`onClose`), `TerminalHostView` gains `toggleThreadView()`/`showThreadView()`/
   `hideThreadView()` mirroring the find-bar methods, mutual exclusion with find bar.
4. **App wiring**: `SessionCoordinator.toggleThreadView()` mirroring `toggleFindBar()` (L478),
   menu item + shortcut in `MainMenuBuilder.swift` (verify no shortcut collision before picking).
5. **Contextual ⌘F**: route through the thread-overlay-visible check before falling to the normal
   find bar; `updateFind` itself stays untouched.
6. **Tests + gate**: new `ThreadOverlayTests.swift` (row building, filter, jump-target clamping);
   full `swift build`/`swift test`/`Tests/robot/run.sh`, explicit re-check of P34's own test list
   (`TerminalBlockStoreTests`, `BlockContextMenuTests`, `KouenMCPTests` block tools) — none of
   these files are touched by this phase, so this re-check is a regression confirmation, not a
   rewrite.

## Regression risk: near-zero by construction

The daemon/MCP block path (`RealPty`, `KouenGridTerminal`, `SurfaceRegistry`, `KouenIPC.BlockSummary`)
is never touched. `TerminalBlock.swift` gains nothing (the store's `blocks` already existed).
`updateFind` is never edited. Only additive changes to `TerminalEmulator.swift` (one computed
property) and new methods on `TerminalHostView.swift`.

## Open decisions (not decided here, confirm before Stage 4 if it matters)

1. "Agent thread" honest framing: blocks are shell-command boundaries — useful for MCP-driven
   panes and plain shells, near-empty for an interactively-run agent TUI (~1 perpetual block).
   Shipping as a general "command thread" for all panes (not agent-specific branding).
2. Toggle shortcut: verify no collision in `MainMenuBuilder.swift` before picking one.
3. Overlay geometry: full-pane cover (chosen — matches find bar's own footprint pattern) vs a
   trailing strip. Full-cover chosen for v1 simplicity; can revisit if it feels heavy in the live check.
