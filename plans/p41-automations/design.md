# P41 — Automations

Scheduled agent launches, addressable via `kouen-mcp`. Dropped from P40's original
scope ("จำเป็นหรอ ไม่ต้องทำก็ได้มั้ง" — user judged not-yet-needed), reinstated
2026-07-11 with a new requirement: connect to `agent-memory/plans`.

## Strategic Design

**Bounded context**: same as Tasks/Worktree/Hosts (P40) — an MCP-addressable resource
exposed by `kouen-mcp`, backed by daemon-owned persistent state. Automations is the
one item in this family with a *scheduler* (a background timer that acts on its own,
not just CRUD on data a human/agent reads later).

**The connection to `agent-memory/plans` question**: resolved as "no connection at
the data-model level." An Automation is `repoPath + agent + prompt + intervalMinutes`
— nothing plan-specific. The link to `agent-memory/plans` is entirely a *prompt text
convention*: an Automation whose `prompt` is `"ทำต่อ agent-memory/plans/p40.../dev-task-progress.md"`
fires the launched agent's own CLAUDE.md continuation rule (read the plan → resume at
first unchecked task). Kouen never opens or parses a plan file. Rejected alternative:
teach Kouen to enumerate `agent-memory/plans/*/dev-task-progress.md` and offer a
picker — rejected as scope creep. `agent-memory/plans` is a Claude-Code-workflow
convention, not a Kouen product concept; baking plan-awareness into the shipped
terminal would couple a general-purpose terminal to one user's workflow file layout.

**The execution-model fork** (surfaced via advisor before implementation): three
options considered —
1. Headless one-shot (`claude -p "<prompt>"`, permission-bypass) — genuinely
   unattended, but needs an auto-approve flag, real safety surface for a scheduled,
   elevated-permission process. Rejected for v1.
2. Interactive spawn + auto-typed prompt (chosen) — same mechanism `kouenSpawnAgent`
   already uses (spawn session, type `claude\n`), just also types the prompt after a
   short delay. Still permission-gated inside the agent's own REPL — safer default,
   and still useful: instead of a human manually opening a pane and typing "ทำต่อ p40",
   the pane opens with the agent already working. Matches how a human would drive
   Kouen today.
3. Spawn + tell the agent to invoke `/loop` — most autonomous, but depends on `/loop`
   skill machinery being reliably available in a cold-started session. Not built;
   nothing prevents an Automation's own `prompt` text from asking the launched agent
   to self-schedule via `/loop` if the user wants that — Kouen doesn't need to know.

## Tactical Design

**Entity — `KouenAutomation`** (`Packages/KouenCore/Sources/KouenCore/Automations/AutomationStore.swift`):
`id`, `repoPath`, `workspaceID?` (nil = first workspace, mirrors `kouenSpawnAgent`'s
own default-workspace resolution), `agent`, `prompt`, `intervalMinutes` (`0` = manual /
run-now only, never auto-fires), `enabled`, `lastRunAt?`, `lastRunStatus?`,
`nextRunAt?`, `createdAt`, `updatedAt`.

No separate run-log store (Superset has `automations_logs`) — `lastRunAt` +
`lastRunStatus` on the record itself is enough visibility for v1; a full log store is
speculative scope until someone asks for run history.

**Store**: `AutomationStore`, exact `TaskStore` mirror (NSLock, atomic JSON write via
`KouenPaths.automationsURL`, load-on-init).

**Scheduler**: `AutomationScheduler` (`Packages/KouenDaemon/Sources/KouenDaemon/AutomationScheduler.swift`),
exact `AgentScanner` mirror — `DispatchSourceTimer` on its own queue, weak `registry`
ref, calls one plain method (`registry.tickAutomations()`) per tick (60s). All state
stays in `SurfaceRegistry.automationStore` — the scheduler owns only the timer, no
second store instance (would otherwise diverge from CRUD writes via MCP).

**Fire mechanism** (`SurfaceRegistry.fireAutomationLocked`): reuses the exact internal
steps `.newSession`/`.send` perform inside `handle()` — `editor.addSession` →
`ensureSessionSurfaces` → `commit()` → hooks → resolve leaf surface → `session.write(launchCommand)`.
Session creation is synchronous (no polling needed, unlike `kouenSpawnAgent`'s MCP
version — that polls only because of async client↔daemon IPC round trips; this runs
in-process). After the launch command, the prompt is typed with a fixed 3s delay on
`hookQueue` (ponytail: heuristic for CLI cold-start, not a readiness check — same
off-lock-reentry pattern hooks already use to call back into `handle()` safely).

**Locking**: `fireAutomationLocked` assumes the caller already holds `SurfaceRegistry.lock`
(non-reentrant `NSLock`). Two callers: `handle()`'s own `.automationRunNow` case
(already locked), and `tickAutomations()` (acquires lock itself for the scheduler,
which doesn't hold it). The delayed prompt-send closure calls `handle()` again, but
only after the original lock scope has already returned — no reentrancy.

## Logical Design

**IPC** (`KouenIPC`): `AutomationSummary` wire struct; `IPCRequest` cases
`automationList/Get/Create/Update/Delete/SetEnabled/RunNow`; `IPCResponse` cases
`automationInfo(AutomationSummary?)`/`automations([AutomationSummary])`. No protocol
version bump (purely additive).

**MCP tools** (`kouen-mcp`): `kouenAutomationList/Get` (read-only, ungated) and
`kouenAutomationCreate/Update/Delete/Pause/Resume/RunNow` (gated in `ToolPolicy.dangerousTools`,
same tier as `kouenWorktreeCreate`/`sendPaneText` — RunNow spawns a session and types
into it, same blast radius as `spawnSession` + `sendPaneText` combined).

**No new UI** — MCP tools only for v1, consistent with keeping scope to what was
asked (the Shader Preset UI was reverted this session as unrequested scope; no reason
to add a new dashboard panel here without being asked).
