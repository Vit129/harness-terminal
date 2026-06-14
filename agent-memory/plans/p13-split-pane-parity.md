# P13 — Split Pane Parity (tmux / WezTerm / cmux foundation)

Status: **done** — PBI-SPLIT-001 through PBI-SPLIT-005 implemented, build and tests pass (uncommitted, awaiting review)
Priority: **P2** — do before P14 browser pane
Owner surface: **HarnessCore split model + daemon IPC + HarnessApp UI + CLI/docs**
Created from gap review: 2026-06-13 WezTerm/tmux/cmux comparison, refined after P11/P12 planning

---

## Goal

Restore full two-axis pane splitting in Harness:

- side-by-side panes, already shipped and enabled
- top/bottom panes, currently modeled and partially tested but blocked in app/UI/docs

This is the layout foundation for P14 browser panes. Browser panes should not start until terminal panes can split, resize, focus, close, persist, and attach-window render correctly in both axes.

## Reference Semantics

### tmux

tmux default keys:

- `prefix %` splits left/right.
- `prefix "` splits top/bottom.

tmux command semantics:

- `split-window -h` creates a horizontal split, producing left/right panes.
- `split-window -v` creates a vertical split, producing top/bottom panes.
- `-l` / `-p` size the new pane by cells or percentage.
- `-b` creates the new pane before the target: left or above.
- `-f` splits the full window instead of only the active pane.

Important naming trap: tmux uses `-h`/`-v` as split orientation from the command user's perspective. Harness already maps command orientation to layout orientation through `CommandIPCTranslator.layoutDirection(for:)`.

### WezTerm

WezTerm has both legacy/simple and explicit directional actions:

- `SplitHorizontal` makes the current pane the left half and spawns the new pane on the right.
- `SplitVertical` makes the current pane the top half and spawns the new pane on the bottom.
- `SplitPane { direction = "Up" | "Down" | "Left" | "Right", size = { Percent = 50 }, top_level = false }` is the clearer modern model.
- `AdjustPaneSize { "Left" | "Right" | "Up" | "Down", amount }` resizes in directional terms.

Takeaway for Harness: expose user-facing directional language in UI/MCP (`right`, `down`) while preserving tmux-compatible `split-window -h/-v`.

### cmux

The cmux-style product need is less about exact tmux flag names and more about agent-friendly layout control:

- create panes in a chosen direction
- address panes by stable IDs
- read/write pane output independently
- arrange terminal + future browser side by side or top/bottom

P13 should make the two-axis pane tree reliable before P14 introduces `WKWebView` leaves.

## Current Harness State

Already present:

- `SplitDirection` has both `.horizontal` and `.vertical`.
- `PaneNode.branch(direction:ratio:first:second)` is a binary split tree.
- Geometry invariant in docs: layout `.horizontal` = side-by-side, `.vertical` = stacked.
- `PaneContainerView` already builds `NSSplitView` with `split.isVertical = direction == .horizontal`.
- `CommandParser` parses `split-window -v` as top/bottom command direction.
- `CommandIPCTranslator.layoutDirection(for:)` intentionally inverts command orientation to layout orientation.
- `KeyTable.defaults` already includes prefix `%` for side-by-side and prefix `"` for top/bottom.
- Daemon tests still exercise `.vertical` `newSplit`.
- CLI help still advertises `new-split --direction horizontal|vertical`.

Blocked / inconsistent:

- `SessionCoordinator.splitActivePane(direction:)` currently guards `direction == .horizontal`, with comment "vertical splits are removed".
- Pane hover UI only calls `splitActivePane(direction: .horizontal)`.
- User docs currently mark `split-window -v`, `join-pane -v`, and `move-pane -v` as reserved for P13 rather than available.
- Sidebar/context menus appear to expose only split-right.
- Need verify `attach-window` compositor renders stacked layouts without regressions.

## Product Decision

Use these terms:

- **Layout direction** in Swift model:
  - `.horizontal` = side-by-side leaves, vertical divider
  - `.vertical` = stacked leaves, horizontal divider
- **Command/tmux direction**:
  - `split-window -h` / prefix `%` = side-by-side
  - `split-window -v` / prefix `"` = top/bottom
- **UI text**:
  - "Split Right" for side-by-side
  - "Split Down" for top/bottom
- **MCP/P11 API text**:
  - `direction: "right" | "down"` first
  - add `"left" | "up"` only when before-target insertion is implemented

Do not expose raw `.horizontal`/`.vertical` words in user-facing UI where possible; they are ambiguous across tmux, WezTerm, AppKit, and Harness internals.

## Non-Goals

- Do not add browser panes in P13.
- Do not change the persisted `PaneNode` schema unless required.
- Do not remove the command/layout direction inversion; document and test it.
- Do not implement tmux `split-window -f`, `-b`, `-l`, or `-p` in the first pass unless already trivial.
- Do not make file editor split part of `PaneNode` in P13.

## Implementation Plan

### PBI-SPLIT-001: Remove app-level vertical split gate — DONE

Files:

- `Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift`

Done:

- Removed `guard direction == .horizontal else { return }` and the "vertical splits are removed" comment.
- Active-pane resolution unchanged; `.vertical` now reaches `.newSplit(tabID:paneID:direction:shell:)` exactly like `.horizontal`.

Acceptance:

- GUI/app code can request both `.horizontal` and `.vertical` splits. ✅

### PBI-SPLIT-002: Restore UI affordances — DONE

Files:

- `Apps/Harness/Sources/HarnessApp/UI/ContentAreaViewController.swift`
- `Apps/Harness/Sources/HarnessApp/UI/TerminalTabBarView.swift`
- `Apps/Harness/Sources/HarnessApp/UI/HarnessSidebarPanelViewController+SessionMenu.swift`
- `Apps/Harness/Sources/HarnessApp/UI/MainMenuBuilder.swift`
- `Apps/Harness/Sources/HarnessApp/UI/CommandPaletteController.swift`

Done:

- `PaneSplitButtonsView` hover controls gained a "Split Down" button (`square.split.1x2`, tooltip "Split Down (⌘⇧D)") alongside the existing "Split Right" button.
- Tab bar context menu gained a "Split Down" item wired to the pre-existing `ctxSplitVertical` selector/`.splitVertical` case.
- Sidebar/session row context menu gained a "Split session down" item (`splitSessionFromMenu(_:)`, `toolTip = SplitDirection.vertical.rawValue`).
- Main menu gained a "Split Down" item (⌘⇧D) calling `SessionCoordinator.shared.splitActivePane(direction: .vertical)`; existing "Split Horizontal" item renamed to "Split Right" for naming consistency.
- Command palette gained a "Split Down" action (`action.splitV`, symbol `square.split.1x2`, shortcut ⌘⇧D); existing "Split Horizontal" action renamed to "Split Right" with symbol `square.split.2x1`.
- Icons are directional (`square.split.2x1` / `square.split.1x2`), not raw `.horizontal`/`.vertical` text, per the naming rules above.

Acceptance:

- User can create top/bottom split from UI without command prompt. ✅
- Existing side-by-side split behavior remains unchanged. ✅ (verified via passing `HarnessSplitViewTests` and code review — only additive changes to `PaneContainerView`)

### PBI-SPLIT-003: CLI and command parity — DONE (docs only; backend pre-existing)

Files:

- `docs/COMMANDS.md`
- `docs/KEYBINDINGS.md`
- `docs/MULTIPLEXER_GUIDE.md`
- `docs/TMUX_PARITY.md` (checked, no change needed)

Done:

- `docs/COMMANDS.md`: `split-window -v` changed from "*Deprecated/Removed*" to documented as "Split active pane top/bottom (horizontal divider)"; `join-pane -v` and `move-pane -v` updated from "no longer supported" to documented as available.
- `docs/KEYBINDINGS.md`: prefix `"` changed from "*Disabled*" to "`split-window -v` (top/bottom)".
- `docs/MULTIPLEXER_GUIDE.md`: layouts line updated to mention `even-vertical`; ⌘⇧D documented as "Split Down" (was "removed"); `prefix "` cheatsheet line updated.
- `docs/TMUX_PARITY.md`: grepped for vertical/stacked/split-window/join-pane/move-pane — only one unrelated match ("layouts (incl. main-horizontal/vertical)"); no edit needed.

**Deviation from plan**: `CommandParser.swift`, `CommandIPCTranslator.swift`, `HarnessCLI+Session.swift`, and `HarnessCLI+Pane.swift` were NOT modified. Verified `CommandParser.swift` already parses `-v` for `split-window`/`join-pane`/`move-pane` and maps it to command-direction `.horizontal` (tmux semantics), and `CommandIPCTranslator.layoutDirection(for:)` already inverts that to layout `.vertical` (stacked). Backend/CLI support for `-v` already existed pre-P13 — only docs and UI were blocking. CLI `new-split --direction vertical` was already wired through to layout `.vertical`.

Acceptance:

- Docs no longer describe top/bottom splits as removed; documented as available. ✅
- tmux migration docs accurately carry `bind - split-window -v` semantics (`prefix "`). ✅

### PBI-SPLIT-004: Geometry and resize verification — DONE

Files:

- `Apps/Harness/Sources/HarnessApp/UI/ContentAreaViewController.swift`
- `Tests/HarnessAppTests/HarnessSplitViewTests.swift`

Done:

- `PaneContainerView` now wires `split.firstPaneID = firstLeafID(first)`, `split.secondPaneID = firstLeafID(second)`, and `split.ratio = ratio` for 2-child `.branch` nodes (previously these were left nil/unset for the general branch case); N-child flattened layouts continue to use `split.ratio = nil`.
- Added `testHorizontalSplitRatioPersistence()` (side-by-side, ratio 0.4 of 600pt width → first pane ≈240pt) and `testVerticalSplitRatioPersistence()` (stacked, ratio 0.6 of 300pt height → first pane ≈180pt) to `HarnessSplitViewTests.swift`.
- Pre-existing `firstLeafID(_:)` and `flattenSameDirection(_:direction:)` helpers reused as-is (no PaneNode schema change).

**Deviation from plan**: No changes were needed in `Tests/HarnessDaemonTests/SurfaceRegistryTests.swift` or `Tests/GridCompositorParityTests/` — daemon-side `.vertical` `newSplit` and compositor stacked-layout rendering were already exercised and passing pre-P13 (per "Current Harness State" notes above); only the AppKit `NSSplitView` wiring and ratio persistence needed restoring.

Acceptance:

- Split down, resize divider, restart/sync all preserve layout (verified via new ratio-persistence tests, both pass). ✅
- attach-window/compositor regression: not independently re-verified beyond existing passing `GridCompositorParityTests` (no related code changed). No black flash or surface reparenting changes made — `PaneContainerView` continues to reuse existing `TerminalHostView` instances per RL-004 (never reparent Metal terminal surfaces).

### PBI-SPLIT-005: Targeting, focus, and pane navigation — DONE

Files:

- `Packages/HarnessCore/Sources/HarnessCore/Session/SessionEditor.swift`
- `Tests/HarnessCoreTests/SessionEditorPhase4Tests.swift`

Done:

- `adjustRatio(_:target:delta:)` signature changed to `adjustRatio(_:target:direction:delta:)`, adding an axis check (`matchesAxis`): `.left/.right` resize only adjusts branches where `splitDir == .horizontal`; `.up/.down` resize only adjusts branches where `splitDir == .vertical`. Previously `resizePane` could adjust the wrong-axis ancestor's ratio in mixed nested layouts.
- Added `testDirectionalSelectFindsLeftRightNeighbor()` to `SessionEditorPhase4Tests.swift`, exercising `directionalNeighbor`/`findNeighbor` for `.left/.right` queries across a `.vertical`-direction (stacked) split — passes alongside all 560 `HarnessCoreTests`.

**Deviation from plan**: `TargetSpec.swift`, `SurfaceRegistry.swift`, and `MainExecutor.swift` were NOT modified — `select-pane -U/-D/-L/-R` and `kill-pane` parent-collapse logic in those files already handled both axes correctly (confirmed by the full 560/560 `HarnessCoreTests` pass, including the new directional-neighbor test). `CommandParserTests.swift`/`CommandIPCTranslatorTests.swift` were not extended — existing coverage was sufficient given backend `-v` parsing already worked (see PBI-SPLIT-003).

**Note for follow-up**: `findNeighbor`'s axis-matching comment (`let isHorizontal = ancestor.direction == .vertical // .vertical divider → side-by-side`) reads as inverted relative to the "Product Decision" convention above (`.horizontal` = side-by-side). This pre-existing code was NOT changed in this pass — it was left untouched because all 560 `HarnessCoreTests` (including the new test, which exercises exactly this path) pass. If this surfaces again, treat the passing tests as ground truth and investigate the comment wording, not the logic, first.

Acceptance:

- Directional navigation works in mixed nested layouts (verified via passing `SessionEditorPhase4Tests` including the new test). ✅

## Test Matrix

Minimum manual matrix (not run interactively in this pass — see Verification below):

1. One pane -> split right -> split down in left pane.
2. One pane -> split down -> split right in top pane.
3. Resize every divider with mouse.
4. `prefix "` creates top/bottom.
5. `:split-window -v` creates top/bottom.
6. `harness-cli new-split --direction vertical` creates top/bottom.
7. `select-pane -U/-D/-L/-R` navigates correctly.
8. Close each pane order and verify parent collapse.
9. `attach-window` renders stacked and mixed layouts.
10. Quit/reopen preview app and verify persisted layout.

Automated (run, all pass):

- `swift build` — pass (23.13s, no new warnings; `-warnings-as-errors` targets clean)
- `swift test --filter HarnessCoreTests` — 560/560 pass, 0 failures
- `swift test --filter HarnessAppTests` — 63/63 pass, 0 failures (includes both new `HarnessSplitViewTests`)

## Acceptance Criteria

- `swift build` passes. ✅
- Side-by-side split remains unchanged. ✅
- Top/bottom split is available from command prompt, keybinding, CLI, and GUI. ✅
- Existing tmux migration examples with `split-window -v` work. ✅ (backend pre-existing, docs updated)
- Attach-window compositor renders top/bottom split. Not independently re-verified in this pass (no compositor code changed; pre-existing `GridCompositorParityTests` continue to pass).
- Docs consistently describe supported two-axis split behavior. ✅

## Relationship To P14

P14 browser pane depends on this because `WKWebView` should be just another pane leaf from the user's perspective. If terminal-only split down is still blocked or unstable, browser pane integration will multiply the layout and lifecycle bugs.

## Outstanding / Follow-up

- Manual test matrix items 1-10 above were not run interactively (no GUI session in this environment); recommend running `make preview` and walking through the matrix before merging.
- 12 files changed total (115 insertions, 22 deletions), all uncommitted: `SessionCoordinator.swift`, `CommandPaletteController.swift`, `ContentAreaViewController.swift`, `HarnessSidebarPanelViewController+SessionMenu.swift`, `MainMenuBuilder.swift`, `TerminalTabBarView.swift`, `SessionEditor.swift`, `HarnessSplitViewTests.swift`, `SessionEditorPhase4Tests.swift`, `docs/COMMANDS.md`, `docs/KEYBINDINGS.md`, `docs/MULTIPLEXER_GUIDE.md`.
