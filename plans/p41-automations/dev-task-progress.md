# P41 — Automations — Task Progress

Design: [design.md](design.md). Built 2026-07-11 in one pass following the P40 MCP
tool pattern (Tasks/Worktree/Hosts).

## KouenIPC

- [x] `AutomationSummary` wire struct (`Packages/KouenIPC/Sources/KouenIPC/AutomationSummary.swift`)
- [x] `IPCRequest` cases: `automationList/Get/Create/Update/Delete/SetEnabled/RunNow`
- [x] `IPCResponse` cases: `automationInfo`/`automations`

## KouenCore

- [x] `KouenAutomation` + `AutomationStore` (`Packages/KouenCore/Sources/KouenCore/Automations/AutomationStore.swift`) — mirrors `TaskStore`
- [x] `KouenPaths.automationsURL`

## KouenDaemon

- [x] `SurfaceRegistry.automationStore` property
- [x] IPC case handlers for all 7 requests
- [x] `fireAutomationLocked` — spawn session, type launch command, delayed prompt send (3s heuristic, ponytail-tagged)
- [x] `tickAutomations()` — scheduler entry point (assumes not locked, acquires lock itself)
- [x] `AutomationScheduler` (`Packages/KouenDaemon/Sources/KouenDaemon/AutomationScheduler.swift`) — `AgentScanner`-pattern timer, 60s tick
- [x] Wired in `KouenDaemonMain/main.swift` (`start`) and `DaemonServer.stop()` (`AutomationScheduler.shared.stop()`)

## kouen-mcp

- [x] `ToolPolicy.dangerousTools`: Create/Update/Delete/Pause/Resume/RunNow gated; List/Get ungated
- [x] `ToolRegistry` tool defs (8 tools) + dispatch + wrapper funcs + `intArg` helper
- [x] `KouenDaemonTools` automation funcs + `automationJSON` serializer

## Tests

- [x] `Tests/KouenCoreTests/AutomationStoreTests.swift` (8 tests — CRUD, due-filtering by interval/enabled, reschedule-on-run)
- [x] `Tests/KouenDaemonTests/AutomationIPCDaemonTests.swift` (4 tests — CRUD round trip via `handle()`, runNow spawns a surface)
- [x] `Tests/KouenMCPTests/KouenDaemonToolsTests.swift` (+4 tests — registration/gating, invalid UUID, gate-closed errors)

## Docs

- [x] `LANGUAGE.md` — Automation term + relationship note
- [x] `agent-memory/plans/INDEX.md` — P41 row added

## Verification

- [x] `swift build` — clean
- [x] `swift test` — 1818 tests, same 5 pre-existing unrelated failures as before this change (ExperienceModeTests/Phase6KeysTests/ReleaseNotesGuardTests), 0 new failures
- [x] `Tests/robot/run.sh` — 22/22 passed
- [ ] Live check: real MCP client calling `kouenAutomationCreate` + `kouenAutomationRunNow`, confirm a pane actually opens and types the prompt (owed, same as P40's live-check item)
