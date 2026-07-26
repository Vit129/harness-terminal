# Dev Task Progress — P40 MCP Surface Expansion + Shader Presets

Last updated: 2026-07-13
Status: Completed, live-checked

## Context
- System: kouen-terminal
- Feature: p40-mcp-surface-and-shader-presets
- Workflow: Dev
- Complexity: Standard (4 independent sub-features, each Lightweight-to-Standard on its own)
- Test Root: `Tests/` (KouenCoreTests, KouenDaemonTests, KouenMCPTests, KouenAppTests, KouenTerminalRendererTests)

## Artifacts
- Design: `agent-memory/plans/p40-mcp-surface-and-shader-presets/design.md`
- LANGUAGE.md: project root (Task, Worktree (MCP resource), Host (MCP resource), Shader Preset)
- Research trail: `agent-memory/knowledge/meta/competitive-position.md`

## Lessons applied (from `agent-memory/knowledge/rl-lessons.md`, surfaced during this session's P38 review)
- **RL-052** — `Task {}` on a `@MainActor` view blocking main thread on `DaemonClient.request()`
  (synchronous despite async callers). Applies directly to the Task Dashboard UI (F4-2)
  and the Settings shader-preset toggle (F4-1 read, F4-3 no daemon call needed) — any
  new UI code calling into `TaskStore`/`WorktreeManager`/`RemoteHostStore` via the daemon
  IPC round trip MUST wrap the call in `Task.detached(priority: .utility)`, not bare `Task {}`.
- **RL-063** — view captured across an `await` without a liveness guard. Applies to
  Task Dashboard row actions (toggle/delete) — guard `sender.window != nil` (or
  equivalent) after every await, same pattern as `GitPanelView`'s hunk-staging popover.

## Summary
- Total tasks: 19 (Automations dropped by user before implementation — see interview record)
- Completed: 19
- Remaining: 0

## Second-pass review (2026-07-11, per this project's own feedback memory)
Checked all 20 new/changed files against `agent-memory/knowledge/rl-lessons.md`'s full
lesson list (~30 entries) before calling this done:
- **RL-052** (bare `Task{}` on MainActor blocking on synchronous `DaemonClient.request()`)
  — correctly applied in `TaskDaemonBridge.swift` (`Task.detached(priority: .utility)`).
- **RL-063** (async Task capturing an NSView across an await without a liveness guard) —
  side-stepped structurally: `TaskDashboardBody` uses SwiftUI's `.task {}` modifier, which
  ties the async fetch's lifetime to the view itself, not a manually-captured reference.
- **RL-050** (NSEvent local monitor retain cycle) — `taskDashboardMonitor`'s closure uses
  `[weak self]`, exact mirror of the existing `agentsInboxMonitor` pattern.
- **RL-040/046** (zombie-crash nonisolated+assumeIsolated workaround) — not applicable;
  `TaskDashboardView` overrides zero high-frequency AppKit callbacks (no `layout()`,
  `resetCursorRects()`, etc.), same shape as the already-passing `AgentInboxPanelView`.
- **RL-043** (NSClickGestureRecognizer intercepting child NSButton clicks) — not
  applicable; `TaskRowView`'s checkbox is a pure SwiftUI `Button`, not an AppKit gesture
  recognizer conflict.
No violations found, no fixes needed this pass.

## Verification (2026-07-11)
- `swift build` — all 4 products (Kouen, kouen-mcp, KouenDaemon, kouen-cli) clean.
- `swift test` (full suite) — 1802 tests, 5 failures, all 5 pre-existing and unrelated
  (`ExperienceModeTests`/`Phase6KeysTests`/`ReleaseNotesGuardTests` — none touch any file
  this plan changed). Zero regressions from P40 across 3 checkpoints (post-F1, post-F2/F3,
  final).
- `Tests/robot/run.sh` — 22/22 passed.
- **Not yet done**: live manual smoke test (real MCP client calling `kouenTask*`/
  `kouenWorktree*`/`kouenHostList`, real Task Dashboard interaction, real shader preset
  visual check in `make preview`) — build/unit-green only, same "live check still owed"
  caveat this project's own P38/P39 plans flag for every phase.

---

## Data Storage — Tasks (F1)
- [x] F1-A: `KouenTask` model + `TaskStore` (`Packages/KouenCore/Sources/KouenCore/Tasks/TaskStore.swift`) — Codable struct, file-lock JSON persistence, mirrors `PasteBufferStore` pattern exactly (atomic write, in-memory cache, `@unchecked Sendable`). CRUD: `list(sessionID:)`, `get(id:)`, `create`, `update`, `delete`. **Deviation from design.md**: `sessionID` is the real `SessionID` (`= UUID`, from `KouenIPC`) not a raw `String` — `KouenCore` already depends on `KouenIPC` (confirmed via `Package.swift` + existing `SessionEditor.swift` import), so the design doc's "avoid type coupling" concern didn't apply; typed is strictly better here. Also added `KouenPaths.tasksURL` (`Paths/KouenPaths.swift`, mirrors `buffersURL`).
- [x] F1-B: `TaskStoreTests` (`Tests/KouenCoreTests/TaskStoreTests.swift`) — create/list/get/update/delete round trip, `list(sessionID: nil)` returns all sessions, closed-session Tasks remain listable (store never deletes on its own — Dashboard UI does the "closed sessions" grouping), persists across reopen, update-on-missing-id returns nil.
- [x] ✅ Run test scripts (verify GREEN): `swift build --product Kouen` clean, `swift test --filter TaskStoreTests` 5/5 passed

## Server Logic — Tasks IPC + MCP (F1)
- [x] F1-C: New `IPCRequest`/`IPCResponse` cases in `Packages/KouenIPC/Sources/KouenIPC/IPCMessage.swift` — `taskList(sessionID: UUID?)`, `taskGet(id: UUID)`, `taskCreate(sessionID: UUID, title: String)`, `taskUpdate(id: UUID, title: String?, done: Bool?)`, `taskDelete(id: UUID)`; response `.taskInfo(TaskSummary?)` / `.tasks([TaskSummary])`. New `TaskSummary` wire struct (`KouenIPC/TaskSummary.swift`) — mirrors `BlockSummary`'s separation from its KouenCore-side type (KouenIPC can't import KouenCore). No `ipcProtocolVersion` bump — purely additive cases degrade gracefully on an old daemon (same precedent as `getBlock`/`replayScrollbackSequenced`).
- [x] F1-D: `SurfaceRegistry.handle()` daemon-side dispatch for the 5 new cases (`Packages/KouenDaemon/Sources/KouenDaemon/SurfaceRegistry.swift`), delegating to a daemon-owned `taskStore` instance + a `Self.taskSummary(_:)` conversion helper.
- [x] F1-E: `kouenTaskList`/`kouenTaskGet`/`kouenTaskCreate`/`kouenTaskUpdate`/`kouenTaskDelete` MCP tools (`ToolRegistry.swift` + `KouenDaemonTools.swift`), registered in `.listTools()`/`.callTool()`. **Scope tweak from design.md**: added `kouenTaskGet` as a 5th tool (design only listed List/Create/Update/Delete) — the IPC `.taskGet` case would otherwise be dead code with no MCP caller, and a single-task-by-id fetch is a real use case for an agent that already has an id. Not gated behind `KOUEN_MCP_ALLOW_CONTROL` — Task tools are Kouen-app-local bookkeeping, not command execution, same tier as `kouenBoard`.
- [x] F1-F: `KouenDaemonToolsTests.testTaskToolsAreRegistered`/`testKouenTaskGetRejectsInvalidUUID` (mirrors `.testKouenBoardIsReadOnlyAndRegistered()` pattern) + new `Tests/KouenDaemonTests/TaskIPCDaemonTests.swift` (3 tests, `WorktreeIsolationDaemonTests`-style direct `SurfaceRegistry.handle()` round trip, real `KOUEN_HOME` sandbox).
- [x] ✅ Run test scripts (verify GREEN): `swift build --product Kouen` clean, `swift test --filter "TaskIPCDaemonTests|KouenDaemonToolsTests"` 15/15 passed

## Client Application — Task Dashboard (F1)
- [x] F1-G: `TaskDashboardView.swift` (`Apps/Kouen/Sources/KouenApp/UI/Tasks/`) — NSView+SwiftUI host mirroring `AgentInboxPanelView`'s construction, grouped Active/Closed sections (cross-referenced against `SessionCoordinator.shared.snapshot`'s live session IDs), checkbox toggle, inline add. New `TaskDaemonBridge.swift` (`Apps/Kouen/Sources/KouenApp/Services/`) wraps every daemon call in `Task.detached(priority: .utility)` per RL-052 (mirrors `GitPanelView.runGitWithStatus`). RL-063 side-stepped structurally — SwiftUI's `.task {}` modifier ties the async fetch's lifetime to the view, no manual liveness guard needed the way an AppKit completion-handler callback would.
- [x] F1-H: Dashboard entry point — added a "checklist" footer icon next to the existing Agents/sparkles button (`SidebarFooterView`), wired to `showTaskDashboard()`/`dismissTaskDashboard()` in `KouenSidebarPanelViewController.swift`, exact structural mirror of `showAgentsInbox()`. Row tap jumps to the owning session via `SessionCoordinator.selectSession`.
- [x] ✅ Run test scripts (verify GREEN): `swift build --product Kouen` clean

**Follow-up 2026-07-13 — `cwd` field added to `KouenTask`/`TaskSummary`.** Live-checking this
phase surfaced a real gap: a Task has no project/repo field at all, and the Task Dashboard is one
global cross-project store (`~/Library/Application Support/Kouen/tasks.json`) — so once a Task's
owning session closes, there was no way, even in principle, to know which project it came from
(needed for the new "Kouen Task Sync" workflow in `~/.claude/rules/routing.md`, which graduates a
Task into a real `agent-memory/plans/` entry). Fixed by capturing the creating session's
active-tab cwd once, at `taskCreate` time (`SurfaceRegistry.swift`'s `.taskCreate` case resolves it
from `editor.snapshot` before calling `TaskStore.create`) — the only point it's ever knowable.
`cwd: String?` added to `KouenTask` (`TaskStore.swift`), `TaskSummary` (`KouenIPC`), and the
`kouen-mcp` `taskJSON` response; optional throughout so pre-existing `tasks.json` entries (and any
task created for an unrecognized/forged sessionID) decode/resolve to `nil`, not a crash. No wire
version-gate needed — this is the control-channel JSON path (Task IPC), not the PTY hot path's
binary-magic framing CLAUDE.md's version-gate rule targets.
- [x] ✅ Run test scripts (verify GREEN): `swift build` clean; 5 new tests
  (`TaskStoreTests`: capture+persist, default-nil, backward-compat decode of a pre-existing
  tasks.json with no `cwd` key at all; `TaskIPCDaemonTests`: real session → correct cwd captured,
  unknown/forged sessionID → nil, not a crash) — full suite 33/33 (was 28/28), `Tests/robot/run.sh`
  23/23. Full unfiltered `swift test`: only the 3 pre-existing unrelated failures already tracked
  (`ExperienceModeTests`/`Phase6KeysTests`/`ReleaseNotesGuardTests` — CHANGELOG/release-notes
  drift) plus one confirmed-flaky `WorktreeIsolationTests` crash (passed clean in isolation,
  untouched by this diff).
- [ ] **Not yet live-checked**: real Task Dashboard interaction in `make preview` (add/toggle/jump
  -to-session, and now also confirming the cwd actually shows up correctly end-to-end from a real
  session) — still owed, same as the rest of P40's Integration section below.

## Server Logic — Worktree (MCP resource) (F2)
- [x] F2-A: New IPC cases wrapping `WorktreeManager` 1:1 (`worktreeList(repoPath:)`, `worktreeCreate(repoPath:sessionID:branch:baseRef:)`, `worktreeRemove(repoPath:worktreePath:force:)`) — thin passthrough, no new domain logic. New `WorktreeInfoSummary` wire struct (KouenIPC), same `BlockSummary`/`TaskSummary` separation pattern.
- [x] F2-B: `kouenWorktreeList`/`kouenWorktreeCreate`/`kouenWorktreeRemove` MCP tools in `ToolRegistry.swift`. `force: true` requires explicit per-call opt-in (no default-true). **Correction found while implementing**: `ToolPolicy.dangerousTools` is a denylist (tools NOT listed default to allowed) — `kouenWorktreeCreate`/`kouenWorktreeRemove` added to that set so the `isToolAllowed` gate check in `KouenDaemonTools` actually takes effect; `kouenWorktreeList` deliberately left off (read-only, same tier as `kouenList`/`kouenBoard`).
- [x] F2-C: `WorktreeMCPIPCDaemonTests.swift` (2 tests, real temp git repo) + `KouenDaemonToolsTests` gating tests (2 tests). **Bug caught by test**: first draft compared exact worktree path string, which git canonicalizes (macOS `/var` → `/private/var` in `worktree list --porcelain` output) — fixed by comparing branch name instead, matching the existing `WorktreeIsolationTests.testCreateAndListWorktree` precedent (would have been a flaky/host-dependent test if shipped as first written).
- [x] ✅ Run test scripts (verify GREEN): `swift build --product Kouen`/`kouen-mcp` clean, `swift test --filter "WorktreeMCPIPCDaemonTests|KouenDaemonToolsTests"` 16/16 passed

## Server Logic — Hosts (MCP resource, read-only) (F3)
- [x] F3-A: Decided — expose all 4 `RemoteHost` fields as-is (`name`/`sshTarget`/`remoteSocketPath`/`sshArgs`). None carry credentials: `sshArgs` is already validated against `SSHTunnelManager.validatedUserSSHArgs`'s allowlist, where `-i` is an identity *file path*, never key material.
- [x] F3-B: `kouenHostList()` — direct `RemoteHostStore()` file read, no daemon IPC round trip. **Confirmed at implementation time** (design.md's open question): `kouen-cli` already reads `RemoteHostStore()` directly in 3 places (`KouenCLI.swift`, `KouenCLI+Server.swift`) — `RemoteHostStore` is a small, read-rarely JSON file, not daemon-owned in-memory state like `TaskStore`, so the same direct-access pattern applies to `kouen-mcp`.
- [x] F3-C: `testHostListIsRegisteredReadOnlyAndHasNoWriteCounterpart` (asserts no `kouenHostCreate`/`Update`/`Delete`/`Remove` tool exists — guards the deliberate read-only boundary) + `testHostListReturnsConfiguredHosts` (positive round trip).
- [x] ✅ Run test scripts (verify GREEN): `swift build --product Kouen`/`kouen-mcp` clean, `swift test --filter KouenDaemonToolsTests` 16/16 passed

## Client Application — Shader Presets (F4) — **UI REVERTED 2026-07-11, user call**
User judged the feature "ไม่จำเป็น เหมือนเป็นแค่ gimmick ไร้สาระ" (unnecessary, feels like
a useless gimmick) after seeing it live in Settings. Reverted the `Picker` from
`SettingsAppearanceView.swift` — `terminalShaderEffect` is back to being unreachable from
the UI (same as before this session, just with an honest doc comment now instead of a
misleading one). Kept: the doc-comment fix (harmless correctness) and the 4
`MetalRendererTests` cases (they cover pre-existing renderer behavior that predates this
session, not code invented for this feature — deleting real regression coverage because
the UI got cut would be throwing out something unrelated to the "gimmick" complaint).
Below is the original (now-reverted) task log, kept for the record:


**Major discovery while starting F4-A**: the entire rendering engine for this feature
**already existed, fully wired, just never exposed in Settings UI.** `TerminalMetalRenderer`
already has a public `shaderEffect: String` property (default `"none"`), an `overlayPipeline`
(`overlay_vertex`/`overlay_fragment` in `MetalShaders.swift`) supporting 4 modes
(`scanlines`/`grain`/`vignette`/`crt`) drawn as a fullscreen quad within the same render
pass encoder (not a separate intermediate-texture pass — simpler than design.md assumed).
`KouenSettings.terminalShaderEffect` already exists as a persisted field, and
`TerminalHostView.applySettings()` already reactively pushes it to live renderers. The
*only* missing piece was a Settings UI control — nothing had ever written to that field.
This eliminated F4-A/B/C as originally scoped (no new enum, no new shaders, no new
pipeline wiring needed — all done already by earlier unrelated work). Re-scoped to:

- [x] **Correction**: fixed a misleading doc comment on `KouenSettings.terminalShaderEffect`
  (`Packages/KouenSettings/Sources/KouenSettings/KouenSettings.swift`) — it claimed a
  `"bloom"` value that the shader's `overlayMode` switch never actually implements (silently
  no-ops to `default: overlayMode = 0`, i.e. behaves as "none"). Now documents the 4 values
  that actually exist: `scanlines`/`grain`/`vignette`/`crt`.
- [x] F4-E (Settings picker, the actual missing piece): added a "Shader effect" `Picker` to
  `Apps/Kouen/Sources/KouenApp/Settings/SwiftUI/SettingsAppearanceView.swift`, matching the
  existing `Binding(get:set:) { model.update(\.x, $0) }` pattern used by the adjacent
  "Resize overlay" picker. Exposes all 4 real modes — kept as raw `String` tags (not a new
  Swift enum) since `terminalShaderEffect` is already persisted as `String`; introducing an
  enum would have meant touching `Codable` encode/decode for zero behavioral gain.
- [x] F4-D: 4 new `MetalRendererTests` cases (`testUnrecognizedShaderEffectBehavesAsNone`,
  `testScanlinesDarkenAlternatingPixelRows`, `testCRTDarkensCorners`,
  `testGrainAndVignetteChangeOutputFromBaseline`) — this genuinely was missing (zero prior
  coverage of the overlay pass despite it being fully implemented). Render the same frame
  with/without each mode via the existing `renderFixture()` helper and assert pixel-level
  darkening/difference, plus the unrecognized-string-is-safe guarantee.
- [x] ✅ Run test scripts (verify GREEN): `swift build --product Kouen` clean,
  `swift test --filter MetalRendererTests` 64/64 passed (60 pre-existing + 4 new).
  **Not yet done**: visual smoke check in `make preview` (Metal rendering correctness can't
  be fully asserted by unit tests alone) — flag as owed, same caveat pattern P38/P39 used
  for every "build/unit-green only, live check still owed" phase.

## Integration
- [x] End-to-end wiring: full `swift build` (app+daemon+CLI+kouen-mcp) clean — 2026-07-13.
- [x] ✅ Run all test scripts (verify GREEN): full `swift test` 1856 tests, only the 3
  pre-existing unrelated failures (`ExperienceModeTests`/`Phase6KeysTests`/
  `ReleaseNotesGuardTests` — CHANGELOG/release-notes drift, untouched by P40), `Tests/robot/run.sh`
  23/23 — 2026-07-13. (One full-suite run hit a known flaky `bundleProxyForCurrentProcess`
  xctest crash unrelated to any specific test — passed clean on retry.)
- [x] Code review — checked this session's only new P40 code (the Task `cwd` follow-up
  above) against `agent-memory/knowledge/rl-lessons.md`'s full lesson list: RL-052
  (`Task{}` on `@MainActor` blocking) and RL-063 (view captured across `await`) don't
  apply — the diff is plain daemon/data-model Swift (`KouenTask`/`TaskSummary` fields,
  `SurfaceRegistry`'s synchronous `.taskCreate` handler, `kouen-mcp` JSON serialization),
  no MainActor UI or async-view-capture code touched. No other lesson in the file applies
  either (AppKit view lifecycle, Metal rendering, SSH — none relevant to this diff).
- [x] Update `agent-memory/plans/INDEX.md` with a P40 row — done 2026-07-13 (see INDEX.md).

**Live-checked 2026-07-13** (real `make preview` build, real GUI, not just build-green):
Task Dashboard — created a real task via the actual "New task..." UI, confirmed `cwd` was
captured correctly in the on-disk `tasks.json` (`/Users/supavit.cho/.../tasks.json`
directly, since `kouen-mcp` is bound to the production daemon, not this isolated preview
instance). Worktree/Host — `kouenWorktreeList`/`kouenHostList` both returned correct real
data (current repo's branch/head; empty host list, correctly matching zero configured
remote hosts). Shader Presets (F4): UI was reverted 2026-07-11 by explicit user call
("ไม่จำเป็น เหมือนเป็นแค่ gimmick ไร้สาระ") — nothing left to live-check there.
**Not yet live-checked**: `kouenWorktreeCreate`/`Remove` (the actual write paths) — gated
behind the MCP control-allowlist policy and would leave a real throwaway worktree to clean
up; deferred unless explicitly requested.
