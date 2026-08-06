# M5 — Saved Layouts — Task Progress

Wayfinder ticket: [../m2-m9-competitive-features/wayfinder-map.md](../m2-m9-competitive-features/wayfinder-map.md) (M5).

**Naming collision caught before it landed:** almost named the new type `LayoutTemplate` —
that name is already taken by a pre-existing, unrelated concept (tmux-style built-in
algorithmic layouts: `even-horizontal`/`main-vertical`/`tiled`,
`KouenCore/Layouts/LayoutTemplate.swift`). Renamed to `SavedLayout`/`PaneLayoutShape`
before writing any code that would have collided. See GLOSSARY.md's alias note.

**Design (skipped a separate design.md — scope was small enough to reason through
directly, same call as M4):** capture a tab's `PaneNode` tree as a shape-only
`PaneLayoutShape` (split direction/ratio/leaf positions, no `PaneID`/`SurfaceID`
identity, browser leaves collapse to plain leaves — v1 cut, documented). Apply = client-side
only: `newTab` then recursively walk the shape issuing `newSplit` requests (same primitives
`SplitPaneCoordinator` already uses elsewhere) — no daemon-side recursive tree-building,
avoids any risk of reentrant-lock issues in `SurfaceRegistry.handle()`. Ratio is not
restored in v1 (every split lands at daemon default 0.5) — documented cut.

## KouenIPC

- [x] `PaneLayoutShape` (indirect enum: `.leaf` / `.branch`) + `SavedLayout` struct (`SavedLayout.swift`)
- [x] `PaneNode.paneLayoutShape` — reduces a real pane tree to shape only
- [x] `IPCRequest` cases: `savedLayoutList/Save/Delete` (no `Apply` — client-side only, see above)
- [x] `IPCResponse` cases: `savedLayoutInfo`/`savedLayouts`

## KouenCore

- [x] `SavedLayoutStore` (`Layouts/SavedLayout.swift`) — mirrors `AutomationStore` persistence shape
- [x] `KouenPaths.savedLayoutsURL`

## KouenDaemon

- [x] `SurfaceRegistry.savedLayoutStore` property + 3 IPC case handlers (list/save/delete)

## KouenApp

- [x] `SplitPaneCoordinator`: `listSavedLayouts()`, `saveCurrentLayout(name:)`, `deleteSavedLayout(id:)`, `applySavedLayout(_:)` (async, recursive `newTab`→`newSplit` walk), private `applyLayoutShape` helper
- [x] `SessionCoordinator` facade wrappers (mirrors existing split-pane facade pattern)
- [x] `MainMenuBuilder.swift`: "Save Current Layout as Template…" (NSAlert + text field, mirrors `addRemoteHost`'s accessory-view pattern) and "Apply Saved Layout…" (NSAlert + NSPopUpButton) in the View menu
- No delete UI in v1 (menu-level) — `deleteSavedLayout` exists on the coordinator but isn't wired to a menu item yet. Minor, flagged for follow-up.

## Tests

- [x] `Tests/KouenCoreTests/SavedLayoutStoreTests.swift` (2 tests) — CRUD round trip, persists across reopen
- [x] `Tests/KouenCoreTests/SavedLayoutStoreTests.swift` `PaneNodeLayoutShapeTests` (3 tests) — leaf/browser-leaf reduce to shape leaf, branch preserves direction/ratio while stripping identity
- [x] `Tests/KouenDaemonTests/SavedLayoutIPCDaemonTests.swift` (4 tests) — save/list/delete round trip via `handle()`, missing-tab and missing-id error paths, save captures a real split's shape correctly

## Docs

- [x] `GLOSSARY.md` — "Saved Layout" term + `LayoutTemplate` collision-avoidance note
- [x] `agent-memory/plans/INDEX.md` — M5 row added
- [x] `agent-memory/plans/m2-m9-competitive-features/wayfinder-map.md` — M5 marked closed

## Verification

- [x] `swift build --product Kouen` — clean at every layer (KouenDaemon, then full app)
- [x] `swift build --build-tests` — clean
- [x] KouenCoreTests 679/5 failures (exactly the known pre-existing baseline, 0 new)
- [x] KouenDaemonTests 222/0 failures
- [x] KouenAppTests 247/0 failures
- [x] `Tests/robot/run.sh` — 27/27 passed, end-of-session batch run (2026-08-05, covers M2-M9 combined)
- [ ] Live check: save a real 3-pane layout, apply it to a new tab, confirm the shape matches (direction/leaf count) — owed
