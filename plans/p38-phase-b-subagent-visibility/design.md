# P38 Phase B — Subagent/Teammate Visibility

Source: `agent-memory/plans/p38-competitive-feature-gaps.md` Phase B, re-scoped after a
Fable design consult (2026-07-14) discovered the original "auto-split pane" premise is
not achievable for the dominant case. User confirmed the revised scope via AskUserQuestion.

> Note: this file, and every Phase B code change, was lost once mid-session to a concurrent
> release-session git operation on the shared working tree (uncommitted work, no recovery path)
> and rewritten from scratch on 2026-07-14. Content below is the reconstructed original design.

## Scope decision (locked, confirmed by user)

- **No literal pane auto-split.** A nested/child agent process does not have an independently
  addressable byte stream: `RealPty` (`Packages/KouenDaemon/Sources/KouenDaemon/RealPty.swift`)
  is one PTY per surface, not per-process, and macOS blocks retroactively rerouting another
  process's fds (SIP/hardened runtime). Worse, Claude Code's Task-tool subagents are typically
  **in-process** (no child PID at all) — no bytes exist to attach to in the first place. cmux
  achieves per-teammate panes only because it spawns each teammate itself with its own PTY; Kouen
  is a passive observer here and cannot reproduce that after the fact for detected subagents.
- **v1 deliverable: badge/indicator UI**, not a pane. A "+N" adjunct on the pane's existing agent
  chip, with a tooltip/popover listing each detected subagent's kind/pid/elapsed time. Clears when
  the process exits.
- **Both detection paths ship in v1** (user chose "รวม hook ด้วยใน v1" over proc-scan-only):
  1. Process-tree scan (catches real child processes — aider/goose/etc. shelling out, or any CLI's
     SDK-subprocess mode).
  2. Claude Code `PreToolUse`(matcher `Task`)/`SubagentStop` hook push (catches the in-process
     case proc-scan structurally cannot see).
- **Adaptive scan cadence accepted**: 30s baseline (current), 5s while ≥1 surface has a detected
  primary agent.
- **`kouenSpawnAgent` (existing MCP tool)** is the answer for *deliberate* multi-agent workflows
  that want a teammate in a real pane — that's a docs/prompting note, not new code, and is not
  part of this phase's build.
- **Not attempted**: activity attribution for subagents (shared PTY makes it impossible to tell
  which bytes came from which process) — presence/kind/age only.

## Corrections to the original plan text (verified against live source, not assumed)

- `AgentDetector.descendantPIDs(of:allPIDs:parentMap:)`
  (`Packages/KouenCore/Sources/KouenCore/Agents/AgentDetector.swift:216`) already walks the full
  descendant tree (per-candidate parent-chain walk, depth-capped at 32) — nested grandchild agent
  processes ARE structurally visible today. B1's premise ("is this a wiring problem, not detection")
  is correct for the process-tree path.
- BUT `detect(pid:table:allPIDs:parentMap:)` (same file, line 186) collapses every matching
  descendant down to a single `best: AgentSnapshot?` — last-match-in-iteration-order wins (no
  depth ordering despite the doc comment on line 175 claiming "returns the deepest match"; that
  comment does not match the implementation and gets fixed as part of this phase). Two
  simultaneous agent-kind matches in one tree today silently collapse to one.
- The plan text's "~1.5s cadence" claim was wrong: that cadence is surface *metadata* refresh
  (cwd/foreground command). The actual agent proc-scan (`AgentScanner.swift:38-42`) fires every
  **30s** (5s initial delay) as a fallback path — OSC 26 hooks are the primary, push-based path.
  Subagent child processes are often short-lived, so this phase's adaptive-cadence change (30s→5s
  while an agent is active) is load-bearing, not optional polish.

## A — detection core (`AgentDetector`, pure logic)

- `AgentSnapshot` (`Packages/KouenIPC/Sources/KouenIPC/AgentSnapshot.swift:137`): add
  `public var parentPID: Int32?` (optional, defaults nil — `decodeIfPresent` keeps old JSON/mixed
  daemon-client versions decoding fine, no version gate needed since this rides the length-prefixed
  JSON control channel, not the `0xF5`/`0xF6` binary hot path).
- `AgentTableEntry` (`AgentDetector.swift:296`): add
  `matchSource(resolvedExecutable:arguments:) -> MatchSource?` where
  `enum MatchSource { case ownProcess, wrapperLaunch }`, replacing the boolean
  `matchesProcess(...)` (kept as a thin `matchSource(...) != nil` wrapper for existing callers).
- Depth-aware walk: extend the existing hop-counting loop in `descendantPIDs(of:allPIDs:parentMap:)`
  (line 216-234, `depth` var already exists at line 223, currently discarded) into an internal
  `descendantPIDsWithDepth(...) -> [(pid: Int32, depth: Int)]`. Keep the public `descendantPIDs`
  signature delegating to it (shared with `ListeningPortScanner`, do not break that caller).
- Replace the single-`best` loop in `detect(pid:table:allPIDs:parentMap:)` (line 186-203) with
  `detectAll(pid:table:allPIDs:parentMap:) -> AgentDetection`, splitting the pure grouping logic
  (wrapper-collapse + primary selection + subagent tagging) into a testable
  `resolveDetection(from matches: [RawMatch], parentMap:) -> AgentDetection` that takes no real
  PIDs/system calls — avoids flaky real-subprocess-tree unit tests (see Testing section):
  - Collect all matches with depth + `MatchSource`.
  - **Wrapper collapse**: drop a `wrapperLaunch` match when a same-kind match exists among ITS
    descendants (the wrapper is the launcher, not a second agent) — prevents `bun run claude` /
    `npm exec claude` from reporting a phantom subagent of itself.
  - **Primary = shallowest surviving match** (tie-break: lower depth, then lower pid — deterministic,
    fixes the line-175 doc comment to match reality).
  - Remaining matches → `subagents: [AgentSnapshot]`, each `parentPID` = nearest matching ancestor
    pid (walk `parentMap` from the subagent's pid; falls back to the primary's pid if no
    intermediate match).
  - `activity` stays `.idle` for every subagent snapshot — no attribution attempt (see Scope).
- `scan()` (line 124-171): compute `AgentDetection { primary: AgentSnapshot?; subagents: [AgentSnapshot] }`
  per surface (new `public struct AgentDetection: Equatable, Sendable` nested on `AgentDetector`).
  Keep `lastSurfaceSnapshots` storing only `primary` (untouched contract for `snapshot(forSurfaceKey:)`,
  hints, and the `agentInfo` IPC response at `GitPanelView.swift:1544` — all single-snapshot
  consumers keep working unmodified). Add a parallel
  `nonisolated(unsafe) private static var lastSubagents: [String: [AgentSnapshot]]` guarded by a
  matching `NSLock` (same idiom as `snapshotsLock`/`rootsLock`/`hintsLock` in this file — Swift 6
  warnings-as-errors safe, no new concurrency pattern introduced). Carry forward `lastActivityAt`
  per subagent pid across scans (elapsed-time display needs a stable start time, not "reset every
  scan"). Clear `lastSubagents[key]` in `unregisterRootPID` alongside the other per-surface state.
- Hints (`registerHint`) and `setActivity` remain single-snapshot — they identify the pane's
  primary agent via OSC 26 / kouen-cli hook. Subagents come from two sources in v1: the proc scan
  above, and a new hint-style push described in B below.

## B — Claude Code Task-subagent hook push (in-process detection)

Proc-scan structurally cannot see Claude Code's Task-tool subagents (they run as API-level turns
inside the same PID, no child process exists). Only a hook can observe this.

- `AgentHookInstaller` (`Packages/KouenCore/Sources/KouenCore/Agents/AgentHookInstaller.swift`):
  extend `claudePayload` (line 518, currently manages `["Notification", "Stop"]` at line 182) to
  also register `PreToolUse` (matcher `"Task"`) and `SubagentStop` hooks, add both to
  `managedEvents` at line 182 so re-install/prune stays correct. Follow the existing
  `osc26AndNotifyFromHook`/`osc26AndNotify` pattern (line 502-514) — do NOT overload the existing
  `AgentActivity` status vocabulary (`idle`/`working`/`awaiting`/`errored`, defined at
  `AgentSnapshot.swift:82-86`); a subagent start/stop is not an activity-state transition for the
  pane's primary agent and must not be misparsed as one downstream (`AgentNotchPeekDecider`,
  `AgentApprovalBar`, etc. all switch on that same enum).
- New signal, kept separate from OSC 26 status: extend `kouen-cli notify` with a
  `--subagent start|stop` flag. Confirmed at implementation time (traced
  `Tools/kouen/Sources/KouenCLI/` for the `notify` subcommand and
  `Packages/KouenCommands/Sources/KouenCommands/CommandIPCTranslator.swift`) rather than assumed.
  The command Claude Code's hook shells out to becomes
  `kouen-cli notify --surface "$KOUEN_SURFACE" --subagent start --from-hook` (`start` on
  `PreToolUse`/Task, `stop` on `SubagentStop`) — daemon-side this calls a new
  `AgentDetector.registerSubagentHint(forSurfaceKey:)` / `clearSubagentHint(forSurfaceKey:)` pair
  (same lock idiom as `registerHint`/`unregisterRootPID`), which `scan()` merges into that surface's
  `subagents` array (hint-sourced entries have no real pid — use `pid: 0` as the sentinel, matching
  the existing hint-snapshot convention at `AgentDetector.swift:91` (`AgentSnapshot(... pid: 0 ...)`
  in `setActivity`'s hint-seed path) — UI must treat `pid == 0` as "hook-sourced, no live pid to
  show" rather than a real process.
- Test coverage: extend `Tests/KouenCoreTests/AgentHookInstallerTests.swift` (existing per-agent
  install-shape tests, e.g. `testCursorInstallsStopHookArrayShape` at line 225) with a Claude-Code
  case asserting the new `PreToolUse`/`SubagentStop` entries are present, idempotent on reinstall,
  and pruned correctly.

## C — IPC / Tab plumbing

- `Tab` (`Packages/KouenIPC/Sources/KouenIPC/Tab.swift`): add `public var subagents: [AgentSnapshot]?`.
  Tab has a custom `init(from:)` and an explicit `isStableEqual` field list — both must be updated
  (`decodeIfPresent` for decode; add to the `isStableEqual` list so subagent changes actually
  trigger a UI refresh). `encode(to:)`/top-level `Equatable` are compiler-synthesized from stored
  properties (no custom implementation exists), so they pick up the new field automatically.
- `SessionEditor` (`Packages/KouenCore/Sources/KouenCore/Session/SessionEditor.swift`): add a
  **separate** `setSubagents(_:forSurfaceKey:)` next to `setAgent(_:forSurfaceKey:)` (line 1237) —
  kept separate so hint/OSC-26-driven activity updates (which know nothing about subagents) never
  clobber a tab's detected subagent list to nil.
- `SurfaceRegistry.applyAgentChanges` (`Packages/KouenDaemon/Sources/KouenDaemon/SurfaceRegistry.swift:1212`):
  update to consume `AgentDetector.AgentDetection` (primary + subagents) instead of a bare optional
  snapshot, call both `editor.setAgent` and `editor.setSubagents`. Existing `commit()`/revision-bump
  broadcast mechanism needs no new IPC message type — subagents ride the existing full-`Tab`-snapshot
  push. Also clear subagents (`editor.setSubagents([], forSurfaceKey:)`) at the dead-pane
  `remain-on-exit` path (~line 2026) alongside the existing `editor.setAgent(nil, ...)` call, so a
  retained dead pane doesn't keep showing a stale subagent badge.
- New `SurfaceRegistry.hasAnyPrimaryAgent() -> Bool` (any tab with `agent != nil`) — drives
  `AgentScanner`'s adaptive cadence decision without needing a new dedicated state channel.
- `AgentScanner` (`Packages/KouenDaemon/Sources/KouenDaemon/AgentScanner.swift:38-42`): adaptive
  cadence — keep the 30s baseline timer, reschedule (`agentScanTimer.schedule(deadline:repeating:)`,
  legal to call again on a live `DispatchSourceTimer`) to ~5s whenever `scanAgents()` finds ≥1
  surface with a non-nil primary agent via `hasAnyPrimaryAgent()`, back off to 30s once none remain.
  Track current cadence in a bool so it only reschedules on an actual transition, not every tick.

## D — Client UI indicator

- `AgentChipView` (`Apps/Kouen/Sources/KouenApp/UI/Shared/KouenDesign.swift`, ~line 953): add a
  stacked "+N" badge variant, shown when the owning tab's `subagents` is non-empty.
- Wire into the two existing chip consumers: `TerminalTabBarView` (agent color/chip usage
  ~line 550) and `SidebarSessionListView`'s `SidebarBadgeLabel` (~line 659).
- Tooltip first (kind display name + pid-or-"hook" (pid==0 sentinel) + elapsed time since first
  seen). Upgrade to a popover only if the tooltip proves insufficient in the live check — do not
  build a popover speculatively.
- Explicitly NOT touched: `AgentNotchRootView` (menu-bar notch) — out of scope for v1, no
  indication this phase needs it.

## Concurrency contract

- All new `AgentDetector` state (`lastSubagents`) follows the file's existing
  `nonisolated(unsafe) private static var ... ; private static let ...Lock = NSLock()` idiom —
  no actors, no new isolation domain, consistent with every other piece of state in this enum.
  Safe under `-warnings-as-errors` because the pattern is already proven in this file.
- `SurfaceRegistry`/`Tab` changes are additive Codable fields on the existing snapshot-broadcast
  path — no new message type, no binary-frame version gate (confirmed: this never touches the
  `0xF5`/`0xF6` PTY hot path, only the 4-byte length-prefixed JSON control channel).

## Testing strategy (why real-subprocess tests were dropped)

Testing `detectAll`'s grouping logic (nested same-kind match, wrapper collapse, iteration-order
independence) against REAL spawned process trees is fragile: reliably constructing a real "agent
process spawns a same-kind child agent process" tree requires nested shell/exec tricks that are
platform-timing-dependent and don't actually reflect how any real agent CLI forks. Instead,
`resolveDetection(from:parentMap:)` — the pure grouping/collapse/tagging logic — is split out from
the real `pidPath`/`processArguments` OS calls, taking synthetic `RawMatch` + `parentMap` input.
`RawMatch` and `resolveDetection` are `internal` (not `private`), same precedent as the pre-existing
internal `descendantPIDs(of:allPIDs:parentMap:)` — accessible to `@testable import KouenCore`.

## Staged implementation / verification gate

Per the plan's own Phase B gate ("design-review checkpoint before implementation... don't start
coding until the hard part has an actual design") — this document IS that checkpoint. The hard
part's conclusion is: no independent byte stream exists for a detected subagent; v1 substitutes a
truthful indicator instead of a fabricated pane.

1. **Detection core** (A) — pure logic + `Tests/KouenCoreTests/AgentDetectorTests.swift` cases via
   `resolveDetection`: nested same-kind match (parent+child claude → primary=parent, one subagent
   with correct `parentPID`), wrapper collapse (`bun run claude` → zero subagents), depth tie-break
   determinism, primary-pid exclusion from subagents.
   Gate: `swift build` (KouenCore is warnings-as-errors) + `swift test --filter AgentDetectorTests`.
2. **Hook push** (B) — extend `AgentHookInstallerTests.swift`. Gate: `swift test --filter AgentHookInstallerTests`.
3. **IPC/Tab plumbing** (C) — `Tab` Codable round-trip (old-JSON decode still works), `SurfaceRegistry`
   test that `applyAgentChanges` with subagents lands in the tab snapshot and bumps revision (pattern:
   existing tests in `Tests/KouenDaemonTests/SurfaceRegistryTests.swift`). Gate: `swift build` +
   `swift test --filter SurfaceRegistryTests` (avoid the unfiltered-suite crash, RL-065) +
   `Tests/robot/run.sh`.
4. **UI indicator** (D) — build/test/robot green, PLUS the required live check per this project's
   own convention: in a real `make preview` workspace, run `claude` in a pane, have it execute a
   real Bash-tool subprocess spawn (`claude -p "say hi"` or similar) to exercise the proc-scan path,
   AND drive an actual Task-tool call to exercise the hook path; confirm the badge appears within
   ~5s (adaptive cadence) for the proc-scan case and near-instantly for the hook case, and clears
   after exit. Also verify `bun run claude`-style launches show no phantom subagent (regression
   check for the wrapper-collapse rule).

## Open items deferred out of this phase (documented, not silently dropped)

- Non-Claude-Code agents' in-process subagent equivalents (if any exist) are not covered by the
  hook push in v1 — only Claude Code's `PreToolUse`(Task)/`SubagentStop` are wired. Extending to
  other agent kinds is future work if/when another CLI exposes an equivalent hook.
- `kouenSpawnAgent` promotion/documentation for deliberate multi-agent-as-panes workflows is a
  docs task, not tracked as a checklist item in this phase's `dev-task-progress.md`.
