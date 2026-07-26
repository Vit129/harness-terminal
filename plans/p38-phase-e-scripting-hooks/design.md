# P38 Phase E — Scripting Hook Parity (JS vs WezTerm's Lua)

Source: `agent-memory/plans/p38-competitive-feature-gaps.md` Phase E. Audit via Fable consult
(2026-07-14) found the plan's own suspicion correct: capability parity already exists (21 daemon
lifecycle hooks in `HookRegistry` + JS can run any command those hooks can via
`kouen.commands.run`), so **no hook-parity build was needed**. The one real defect found: the
`kouen.plugin.on` doc comment in `ScriptAPI.swift` promised `paneCreated`/`paneRemoved` events
that were never actually dispatched anywhere — a documented-but-dead API.

## Scope (locked)

Fixed the doc-vs-reality gap directly (Fable's "small build" option, not the minimal comment-only
fix) — closes the promise properly rather than just retracting it, and it's cheap (~40 lines).

Explicitly NOT built (per Fable's recommendation, no change from the audit's own conclusion):
- WezTerm-named JS hooks duplicating the daemon `HookRegistry` catalog — would be exactly the
  "abstractions beyond what the task requires" the project rules prohibit.
- `window-resized` — needs new AppKit observation plumbing, no identified consumer.
- `format-tab-title` as a JS callback — conflicts with the already-established format-string engine.
- A first-class `paneFocusChanged` event — still derivable from `snapshotChanged` +
  `activeTabId`/`activePaneId` on the snapshot, as the audit found; not promised anywhere, so no
  doc-vs-reality gap to close for it.

## Implementation

`Apps/Kouen/Sources/KouenApp/Scripting/ScriptRuntime.swift`:
- New `lastKnownPaneIDs: Set<PaneID>` — seeded from `SessionCoordinator.shared.snapshot` at
  `registerNotificationBridge()` time (init), NOT starting empty. Bug caught during implementation:
  seeding from empty would fire a spurious `paneCreated` for every pane already open the first
  time `snapshotChanged` fires after script load.
- `dispatchPaneDiff()` (called from `handleSnapshotChanged`): diffs the current pane-ID set
  (flattened from every workspace/session/tab's `rootPane.allPaneIDs()`) against the baseline,
  dispatches `paneCreated`/`paneRemoved` per pane id (as `paneID: <uuidString>`), updates the
  baseline. Skips the walk entirely when no handler is registered for either event.
- Made `internal` (not `private`) specifically so tests can call it directly instead of posting
  through the real `NotificationBus` — a real post fans out to `NotificationCoordinator`, which
  crashes outside a real app process (RL-065: `UNUserNotificationCenter` needs a bundle context
  bare `swift test` doesn't have). Confirmed this is the exact pre-existing landmine, not something
  this change introduced: the crash reproduced in an UNRELATED pre-existing test
  (`testScriptFileWatcherReloadAndReArm`) in the same filtered run.

No change needed to `ScriptAPI.swift`'s doc comment — it already correctly listed exactly
`pluginsLoaded`/`paneCreated`/`paneRemoved`/`snapshotChanged`/`configReloaded`/`agentStateChanged`;
the fix was making the promise true, not correcting the promise's text.

## Tests

`Tests/KouenAppTests/ScriptingTests.swift` — 2 new tests: bridge-level payload contract
(`testPaneCreatedAndRemovedDispatchWithPaneIDPayload`, mirrors the existing
`testEventsOnDispatchesHandlerWithPayload` pattern) and a regression guard for the seeding fix
(`testNoSpuriousPaneCreatedOnFirstDiffAfterInit`).

## Gate

`swift build --product Kouen` green, `swift test --filter "testPaneCreatedAndRemovedDispatchWithPaneIDPayload|testNoSpuriousPaneCreatedOnFirstDiffAfterInit"` green (2/2, isolated from the
pre-existing RL-065 flake), `Tests/robot/run.sh` green (26/26).
