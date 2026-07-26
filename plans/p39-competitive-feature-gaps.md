# P39 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed / tmux)

> Refresh of `agent-memory/knowledge/meta/competitive-position.md` (stale, dated
> 2026-07-02, still calls the app "Harness"). Adds two competitors not previously
> tracked (Superset, Zed) and re-verifies claims against current code (v4.3.1, build 199).
> Web research done 2026-07-11 — see citations per gap.
>
> **tmux sweep (2026-07-11, Opus planning pass):** tmux parity is already tracked in
> depth at `docs/TMUX_PARITY.md` (scripting, copy-mode, status-line, hooks, format
> strings, session/window/pane lifecycle — all matched or exceeded via daemon
> persistence). No new gap found. The one tmux-ecosystem item (tpm-style plugin
> manager: resurrect/continuum/thumbs) was already tracked in `competitive-position.md`
> under "Extensions/plugins ecosystem" — not new, not added as a G-number here.
> Broader sweep (Warp, iTerm2, Ghostty, Kitty, Rio, Alacritty) surfaced nothing new
> either — Warp Drive (team sharing) and block-based terminal were already tracked.

## Method

For each gap: confirmed via `grep`/`graphify query` against current source, not assumed
from the old doc. Gaps the codebase already covers are marked **matched, not a gap** and
excluded from phases below.

## Already matched (verified in code, not gaps)

| Claimed competitor feature | Kouen equivalent | Evidence |
|---|---|---|
| cmux notification rings (OSC 9/99/777 + CLI hook) | `OSCNotificationParser`, `NotificationBus`, `AgentStatusDot` | `Packages/KouenIPC/Sources/KouenIPC/AgentNotification.swift` |
| Supacode persistent sessions survive app restart (bundled zmx) | Daemon process + scrollback replay from disk (stronger: survives full app quit, not just editor restart) | `RealPty.respawn()`, `Tests/KouenDaemonTests/ScrollbackPersistenceTests.swift` |
| Supacode agent busy/awaiting-input/idle badge | `AgentStatusDot` / `AgentInboxPanelView` | `Apps/Kouen/Sources/KouenApp/UI/Notifications/AgentInboxPanelView.swift` |
| Zed Agent Panel context injection (files/diagnostics/blocks) | `harness-mcp` tools (`kouenErrors`, `kouenGetBlock`, `kouenGrep`, `kouenFind`) — agent pulls context itself via MCP instead of UI @-mention | existing MCP tool list |
| Superset in-app browser + MCP | Browser pane + `harness-mcp` 27 tools | P28 |

## Real gaps (verified absent)

| # | Gap | Who has it | Evidence it's missing | Severity |
|---|-----|-----------|------------------------|----------|
| G1 | **Listening-port detection in sidebar** — cmux shows each pane's dev-server port live in the vertical tab sidebar. Kouen only has passive click-to-open localhost link detection in terminal output (`URLDetection.isLocalDevHost`), nothing proactive/sidebar-level. | cmux | `URLDetection.swift` only does text-pattern matching on rendered output, no port-scan/`lsof`-style sidebar badge | Medium (nice-to-have UX) |
| G2 | **SSH agent forwarding on remote mux domains** — WezTerm's `mux_enable_ssh_agent` propagates `SSH_AUTH_SOCK` to the remote host automatically for `wezterm ssh`. Kouen's `SSHTunnelManager`/Remote host manager (P23) has no agent-forwarding option. | WezTerm | `grep -rn "SSH_AUTH_SOCK\|ForwardAgent"` → zero hits outside this plan doc | Medium (remote-workflow friction, users currently need manual `ssh -A` / agent config outside Kouen) |
| G3 | **Configurable PR merge strategy (squash/rebase/merge) per worktree** — Supacode surfaces PR checks/merge-readiness in the sidebar *and* lets you pick merge strategy. Kouen has PR/CI status inline (P24/P33) but no merge-strategy picker — merging still routes through `Scripts/commit-push-merge.sh` or manual `gh`. | Supacode | `grep -rn "MergeMethod\|squash\|mergeStrategy"` → no real hits (only a docstring using the word "squashed") | Low-Medium |
| G4 | **In-app git hunk staging** (stage/unstage individual hunks without leaving the app) — Superset's diff viewer lets you stage specific hunks inline. Kouen's git panel shows diffs (commit-diff popover, P33) but staging is CLI-only. | Superset | no `hunkStage`/`stagePatch` implementation found, only a `KouenTerminalSurfaceView` false-positive match | Low-Medium |
| G5 | **Explicit multi-agent orchestration dashboard (10+ agents at a glance)** — Superset's headline pitch is running/reviewing 10+ parallel agents with a dedicated review workflow. Kouen supports parallel agents via worktree-per-session (P32 task-based worktrees) + sidebar, but there's no aggregate "N agents running, M need attention" board beyond the notification inbox. | Superset | `AgentInboxPanelView` is a flat notification list, not a fleet-status board | Low (philosophy difference — Kouen's MCP-first design lets an *external* orchestrator agent do this via `kouenList`/`kouenBoard`; may already be "solved" architecturally rather than in-UI) |

## Not gaps — deliberate positioning differences (no action)

- **Zed's built-in chat/Agent Panel UI** — Kouen removed inline AI chat deliberately
  (`c4e1e15`, 2026-06-29). Re-adding contradicts the CLI-agents-in-terminal-panes + MCP
  philosophy already documented in `competitive-position.md`. Not re-litigating here.
- **Superset/cmux Electron vs native** — Kouen's native Swift engine is already a stated
  USP; no action needed.
- **Cross-platform GUI (Win/Linux)** — pre-existing known gap (`competitive-position.md`),
  out of scope for this plan; macOS-only is a strategic choice, not an oversight.

## Phases

### Phase A — Remote workflow parity (G2) — DONE 2026-07-11
- `-A` was already a validated passthrough flag in `SSHTunnelManager.validatedUserSSHArgs`
  (no core change needed) — the gap was purely UI discoverability. Added an "Agent
  forwarding" toggle to `SettingsRemoteView`'s host form (same pattern as Port/Identity/
  Jump: synced from `sshArgs.contains("-A")` on select, appended on save).
- Files: `Apps/Kouen/Sources/KouenApp/Settings/SwiftUI/SettingsRemoteView.swift`.
- Verified: `swift build --product Kouen` clean, `swift test --filter "RemoteHost|SSHTunnel"`
  26/26 green. Not yet verified: real remote host with `git`/`gh` end-to-end (build-green
  only — see MEMORY.md 2026-07-07 lesson, live check still owed before calling this fully done).

**Code-reviewed 2026-07-13** (no remote host configured on this Mac to test live against —
`kouenHostList` returns `[]`): traced the full wiring end to end. `editAgentForwarding` syncs
from `host?.sshArgs.contains("-A")` on load and appends `"-A"` back into `sshArgs` on save
(`SettingsRemoteView.swift:363,409`); `SSHTunnelManager.swift:219` passes `host.sshArgs` through
`validatedUserSSHArgs` into the real `ssh` invocation. Genuinely wired, not just a UI toggle.
Real end-to-end verification (an actual remote host + `git`/`gh`) is still owed — flagging
honestly rather than claiming full coverage from code review alone.

### Phase B — Sidebar dev-server visibility (G1) — DONE 2026-07-11
- Confirmed passive `URLDetection` doesn't cover this: `visibleLinks()` only scans the
  currently-rendered viewport on demand, nothing retained per-surface — a background pane's
  dev server would never surface. Built the proactive daemon-side scan instead.
- `Tab.listeningPorts: [Int]` field already existed in the model (unused scaffolding, no
  writer/reader anywhere) — reused as-is.
- New `ListeningPortScanner` (KouenCore/Agents): one batched `lsof -F pn` per scan tick
  across every surface's process-tree union (reuses `AgentDetector`'s `descendantPIDs`,
  exposed `internal` for this), not one fork per pane.
- `AgentScanner` gained a 5th timer (5s cadence — port state changes slower than agent
  activity, but a dev server should show up within ~1 tick of starting) calling
  `SurfaceRegistry.refreshListeningPorts()`, which mirrors `refreshSurfaceMetadata`'s
  off-lock-probe / re-validate-child-PID-then-commit shape.
- Sidebar: `SidebarSessionItemRow` shows the lowest listening port across all of a
  session's tabs as a badge (reusing `SidebarBadgeLabel`), click posts the same
  `KouenOpenInBrowserPaneURL` notification the passive link-click path already uses.
- Files: `Packages/KouenCore/Sources/KouenCore/Agents/{AgentDetector,ListeningPortScanner}.swift`,
  `Packages/KouenCore/Sources/KouenCore/Session/SessionEditor.swift`,
  `Packages/KouenDaemon/Sources/KouenDaemon/{SurfaceRegistry,AgentScanner}.swift`,
  `Apps/Kouen/Sources/KouenApp/UI/Sidebar/SidebarSessionListView.swift`.
- Verified: `swift build` (app + daemon + CLI) clean, `swift test` 50/50 (3 pre-existing
  live-daemon skips), `Tests/robot/run.sh` 10/10. New `ListeningPortScannerTests.swift`
  covers the `lsof -F pn` parser (IPv4/IPv6, empty input, malformed-line safety). Not yet
  verified: real dev server + real sidebar render (build/unit-green only — live check
  still owed, same caveat as Phase A).

**Partially live-tested 2026-07-13**: started a real `python3 -m http.server 8765` in a
real pane and confirmed via `readPaneOutput` it was genuinely listening — the actual test
condition the scanner needs is real, not simulated. Code-reviewed the rest (native sidebar
render, no MCP field exposes `listeningPorts`): `portScanTimer` confirmed active (5s tick,
`AgentScanner.swift`), off-lock `lsof` scan re-validates instance identity + child-PID
before committing (matches `refreshSurfaceMetadata`'s pattern, already checked by the
2026-07-11 Opus review above), sidebar renders the lowest port across all tabs correctly
(`SidebarSessionListView.swift:282`). Whether the badge actually rendered on screen for
that test server was not independently confirmed by me (no way to screenshot the native
window) — genuinely still owed.

### Phase C — Git workflow depth (G3, G4) — SPLIT 2026-07-11 (Opus planning pass)
Re-scoped after discovering `GitHubCLIClient.swift` has zero merge capability today
(read-only: PR status, checks, ahead/behind, open-URL — no merge method at all) and
`GitPanelView.swift` renders diffs read-only (no staging). Both are bigger than
originally estimated, and at very different risk levels — split by risk, not by file:

- **C1 = G4 (hunk staging) — DONE 2026-07-11.** Discovered whole-*file* stage/unstage
  already existed (`toggleStage`, `git add`/`git restore --staged` per file) — the
  planned MVP fallback was already shipped. Built whole-hunk granularity on top: a new
  "hunks" button per changed-file row opens a popover listing that file's unstaged
  hunks (`git diff -- file`, "Stage" button) and staged hunks (`git diff --cached --
  file`, "Unstage" button), each applying `git apply --cached [-R]` against a
  temp-file patch built from the shared file header + that one hunk. No interactive
  partial-line splitting (cut, per plan).
  - New: `GitPanelView.parseDiffHunks`/`patchText` (pure, tested), `applyHunkPatch`,
    `showHunkStaging`/`presentHunkStagingPopover`/`makeHunkCard`, `HunkActionButton`.
  - File: `Apps/Kouen/Sources/KouenApp/UI/Git/GitPanelView.swift`.
  - Verified: `swift build` (app+daemon+CLI) clean, targeted test filters green
    (`GitPanelViewHunkStagingTests` 3/3 new + `GitPanelViewDiffPopoverTests`/
    `GitPanelViewToastErrorSummaryTests` unaffected), `Tests/robot/run.sh` 10/10.
    Full unfiltered `swift test` has two pre-existing unrelated failures (not caused
    by this change — neither touches git/diff code): a `UNUserNotificationCenter`
    bundle-proxy crash in `GitPanelViewDiffErrorTests` under full-suite run only
    (documented pre-existing macOS 26 notification-DB issue, see
    `agent-memory/knowledge/bugs/notification-sound-and-click-routing.md`; passes
    standalone), and an unrelated `ExperienceModeTests` assertion failure. Not yet
    verified: staging a real hunk against a real repo end-to-end (build/unit-green
    only — live check still owed, same caveat as Phases A/B).

  **Code-reviewed 2026-07-13** (native GUI-only, no MCP surface to drive it myself):
  `parseDiffHunks` splits header/hunks correctly including the trailing-newline edge
  case, `patchText` reconstructs a valid standalone single-hunk patch, `applyHunkPatch`
  writes to a temp file (avoids `Process` arg-escaping issues) and cleans up via
  `defer`, `showHunkStaging`'s async diff fetch guards `sender.window != nil` after
  the `await` (RL-063 pattern applied correctly). Logic is sound; real hunk-staging-
  against-a-real-repo still not exercised live.
- **C2 = G3 (PR merge) — DONE 2026-07-11.** User sign-off received ("C until the end
  of all phase") before implementing — this is a new capability (the app gaining the
  ability to execute `gh pr merge` against the user's real GitHub repo), materially
  different risk than anything else in this plan.
  - `GitHubCLIClient.merge(repoPath:prNumber:method:)` — `MergeMethod` enum
    (`.squash`/`.rebase`/`.merge`), every caller must pass one explicitly, no default.
    `PRInfo` gained `baseRefName` + `mergeable` (`true` only for GitHub's exact
    `"MERGEABLE"` string — `"CONFLICTING"`/`"UNKNOWN"`/missing all parse to `false`,
    tested).
  - Sidebar row context menu: "Merge PR #N…", disabled unless
    `prChecksStatus == .pass && prMergeable == true`. Click opens an `NSAlert` with
    PR number/title/target branch + a method `NSPopUpButton` defaulted to a
    "Choose merge method…" placeholder — hitting Merge while the placeholder is
    still selected is treated as cancel, not "pick one for me". Result (success or
    `gh`'s stderr on failure) shown in a follow-up alert.
  - No app-side force-merge path — `gh pr merge`'s own branch-protection refusal is
    the only backstop, as designed.
  - Files: `Packages/KouenCore/Sources/KouenCore/GitHub/GitHubCLIClient.swift`,
    `Apps/Kouen/Sources/KouenApp/UI/Sidebar/{SidebarListModel,SidebarSessionListView}.swift`.
  - Verified: `swift build` (app+daemon+CLI) clean, new `GitHubCLIClientTests` 5/5
    (mergeable-parse cases — the load-bearing gate logic), `Tests/robot/run.sh`
    10/10. Not yet verified: an actual merge against a real PR (build/unit-green
    only — live check still owed, same caveat as every other phase; this one
    especially warrants a real end-to-end try before relying on it).

  **Code-reviewed 2026-07-13, deliberately not live-tested.** No default merge method
  (every caller must pass one explicitly, no silent auto-pick), `--delete-branch=false`,
  zero app-side force path, `mergeable` strictly parses the literal `"MERGEABLE"` string
  (anything else defaults safely to `false`). Sound and conservative. A real merge was
  **not** executed to "verify" this — it's a destructive, hard-to-reverse GitHub action
  with no open PR to test against safely; code review is the appropriate bar here, not
  execution.

**All five phases (A, B, C1, C2, D) done as of 2026-07-11.** Every phase still owes
its "live check against a real daemon/repo" gate (see Verification gates below) —
build/test-green was achieved throughout, but no phase has been exercised against
real hardware yet (real SSH host, real dev server, real hunk, real PR, real
multi-agent session).

**2026-07-13 verification pass.** All five gaps are native GUI-only (no MCP tool surfaces
any of them directly), so a genuine runtime live-check wasn't reachable through the tools
available this session — code-reviewed all five instead (see each phase's own
"Code-reviewed 2026-07-13" note above), plus started a real listening dev server for G1/B
to at least make the underlying test condition real rather than hypothetical. No new bugs
found; the 2026-07-11 Opus review had already caught and fixed what needed fixing. Real
on-screen confirmation (does the sidebar badge actually render, does a real merge/hunk/SSH
session actually work end-to-end) is still genuinely owed — this pass raises confidence,
it doesn't close the live-check gate.

## Post-implementation review (Opus, 2026-07-11)

User asked for a second-pass review checked specifically against this repo's own
`agent-memory/knowledge/` lesson history (rl-lessons.md, cases/appkit-ui.md,
cases/swift6-concurrency.md, cases/remote-ssh.md) before treating the work as done.

- **CASE-040/RL-043** (button click not firing / gesture-recognizer conflict) —
  checked against the new `hunksButton` (C1): **refuted**. `StageToggleButton`
  (same file, same `momentaryChange`+no-bezel pattern, no `mouseUp` override) has
  shipped in the core staging workflow through the entire post-macOS-26 period with
  zero not-firing reports — CASE-040's actual root cause was `SoftIconButton`'s
  child `NSImageView` stealing hitTest, which `hunksButton` doesn't have. Row's
  `NSClickGestureRecognizer` delegate already excludes all `NSButton` hits.
- **RL-052** (`Task {}` on a `@MainActor` NSView blocking main thread on
  `DaemonClient.request()`, which is synchronous despite its callers being
  `async`) — **confirmed, pre-existing pattern** (`runAndRefresh`/Sync button had
  the same issue already). **Fixed at the root**: `runGitWithStatus` itself now
  wraps its body in `Task.detached(priority: .utility)`, so every caller (Sync
  button, worktree remove, the new hunk-apply) gets it fixed in one place, not
  patched per-caller.
- **RL-063** (view captured across an `await` without a liveness guard) — checked
  `showHunkStaging`/`presentHunkStagingPopover`/`makeHunkCard`: compliant,
  `sender.window != nil` guarded after every await.
- **Daemon timer re-validation** (Phase B) — checked `refreshListeningPorts`
  against `refreshSurfaceMetadata`'s exact pattern: correct, re-validates both
  instance identity and child-PID-hasn't-respawned before committing.
- **PR merge blast radius** (C2) — checked: safe, no accidental-method path, no
  app-side force-merge, `Task.detached` already used correctly (this was the
  reference the `runGitWithStatus` fix above was brought in line with).
- **Real gap found and closed**: `GitPanelViewHunkStagingTests` only covered
  `parseDiffHunks` parsing, never exercised the reconstructed patch through a real
  `git apply --cached`. Added `testStagingOneHunkLeavesTheOtherUnstaged` — real
  temp repo, two-hunk file, stages one hunk via the actual patch-file path, asserts
  the index/worktree split, then reverses via `apply --cached -R` and confirms a
  clean index. This is the test that would have caught a subtly wrong patch header
  or hunk-boundary bug; the pure-parsing tests couldn't.
- **SSH toggle "gap" — investigated 2026-07-11, closed as no-op, not a real bug.**
  The reviewer's flagged scenario ("`-oForwardAgent=yes` shows the toggle off while
  forwarding is actually on") cannot occur: `SSHTunnelManager.validatedUserSSHArgs`
  (`Packages/KouenCore/Sources/KouenCore/Remote/SSHTunnelManager.swift:225`) only
  allows `-4/-6/-A/-a/-T/-q/-v/-vv/-vvv` (no-value) and `-p/-i/-J/-l` (value) — `-o`
  is not in either allowlist. Any host with `-oForwardAgent=yes` in `sshArgs` would
  already fail to connect (`SSHTunnelError.invalidConfiguration`) before agent
  forwarding could ever matter — so a host can never be "actually forwarding via
  `-o`" while the toggle reads off; toggle-off is the accurate read for that state.
  The only way such a flag reaches storage at all is a manual JSON edit or CLI
  bypassing Settings' own form (which only ever writes `-A`) — a save-time
  validation gap (`RemoteHostStore` doesn't validate `sshArgs`, only
  `SSHTunnelManager` does, at connect time), not a toggle-detection gap. User
  confirmed: close as no-op, no code change.

No ship-blockers found. `runGitWithStatus`'s `Task.detached` fix + the new
integration test are the only code changes from this review pass — re-verified:
`swift build` clean, `GitPanelViewHunkStagingTests` 4/4 (including the new
integration test), `Tests/robot/run.sh` 10/10.

### Phase D — Fleet visibility (G5) — DONE 2026-07-11
Built the lightweight aggregation Opus recommended, reusing existing state (no new
data plumbing, as scoped):
- Footer "Agents" (sparkles) button gets a small red count badge when any agent is
  `.waiting` — computed inline from `SessionCoordinator.shared.agentsList()`,
  piggybacking on `SidebarFooterModel`'s existing `chromeEpoch`-driven re-render.
- Agent Inbox popover header now reads "Agents · N running · M need you" instead of
  just "Agents".
- Files: `Apps/Kouen/Sources/KouenApp/UI/Sidebar/SidebarWorkspaceViews.swift`,
  `Apps/Kouen/Sources/KouenApp/UI/Notifications/AgentInboxPanelView.swift`.
- Verified: `swift build` (app+daemon+CLI) clean, `Tests/robot/run.sh` 10/10. No new
  unit test — trivial view composition + a one-line `.filter(\.waiting).count` over
  already-tested data, no new logic to regress. Not yet verified: real multi-agent
  session with the badge visibly updating (live check still owed, same caveat as
  every other phase in this doc).

**Code-reviewed 2026-07-13** (native sidebar UI, no MCP surface — `kouenBoard`/`kouenList`
are separate pre-existing tools, not this feature; do not conflate a `kouenBoard` check with
verifying this badge). `.filter(\.waiting).count` over `SessionCoordinator.shared.agentsList()`
reads correctly as a simple derived count, no new state to get out of sync. Real visual
confirmation (does the red count badge actually render/update on the real sidebar) still
not done.

### Phase D — Fleet visibility (G5) — RE-SCOPED 2026-07-11 (Opus planning pass)
Not closing as "solved via MCP" — `kouenBoard`/`kouenList` solve the *agent-
orchestrator* case, not the *human-at-a-glance* case a human watching 10 running
agents actually has (Superset's headline feature is explicitly human-facing). The
sidebar's per-row status dots + `AgentInboxPanelView`'s flat notification list
partially cover this but don't aggregate.
- Build a **lightweight** native aggregation, not a big Superset-style dashboard:
  running-agent count + a "needs-attention" list (agents awaiting input), reusing
  existing `AgentStatusDot`/`AgentInboxPanelView` state — no new data plumbing.
- Stays lowest priority of the four remaining gaps; small enough to fold into a
  slow afternoon, not urgent.

## Verification gates (every phase)
- `swift build` + `swift test` green, `Tests/robot/run.sh` 10/10
- Live check against a real daemon, not just build-green (see MEMORY.md 2026-07-07 lesson)

## Addendum — MAW-pattern validate gate (2026-07-23)

User asked to compare Kouen against GitHub `MAW`/`Multi-Agent-Workflow` repos
(`bobisme/maw`, `Soul-Brews-Studio/maw-js`, `laris-co/multi-agent-workflow-kit`,
`haoyu-haoyu/Multi-AI-Workflow` — researched via agy). All four use the same
tmux/git-worktree agent-isolation pattern Kouen already has (`kouen-cli wake`,
worktree-per-session). The one piece worth adapting: their deterministic
merge step runs build/test validation before merging an agent's branch back.

**Explicit constraint from user**: validate+test+merge must never run
automatically — the existing `mergeWorktreeAction`/`performMerge` NSAlert
confirm (git panel) is already the only thing that can trigger a merge, and
that stays true. This only adds an automated *validate* step that runs before
the confirm dialog is shown, so the user decides with pass/fail info already
in hand — it does not add any new auto-merge path.

- `SignalFileRouter.validationSteps(at:)` (`Packages/KouenCore/Sources/KouenCore/Routing/SignalFileRouter.swift`)
  — reuses the existing stack-detection (`detectProfile`) to return ordered
  build/test commands (swift: `swift build` + `swift test`; python: `pytest -q`;
  node/nextjs/react/vue/node-backend: package-manager `test` script, detected
  via lockfile, only if `package.json` actually defines one). Empty = skip,
  never treated as failure.
- `GitPanelView.validateWorktree(at:)` runs those steps via a new
  `runShellCommand` (merges stdout+stderr into one pipe, 5-minute kill
  ceiling — build/test output is much larger than the git diffs `runGit`/
  `runGitDiff` already handle, so a two-pipe drain would risk the classic
  `Process` deadlock).
- `mergeWorktreeAction` now runs validate before calling `performMerge`;
  `performMerge`'s NSAlert shows the pass/fail summary and switches to
  `.warning` style on failure — Merge/Cancel buttons and the underlying
  `git merge branch` call are unchanged.
- Files: `Packages/KouenCore/Sources/KouenCore/Routing/SignalFileRouter.swift`,
  `Apps/Kouen/Sources/KouenApp/UI/Git/GitPanelView.swift`.
- Verified: `swift build --product Kouen` clean, `swift test --filter
  "SignalFileRouterTests|GitPanelView"` 46/46, `Tests/robot/run.sh` 27/27
  (including the pre-existing "never `--no-ff`" / "no auto-resolve" merge
  guards — unaffected). New tests: `testSwiftValidationStepsAreBuildThenTest`,
  `testPythonValidationStepsRunPytest`, `testNodeWithoutTestScriptSkipsValidation`,
  `testNodeWithTestScriptPicksPackageManagerFromLockfile`,
  `testEmptyDirectorySkipsValidation`.

  **Advisor review caught 2 real gaps in the first pass, both fixed:**
  1. `runShellCommand` used `/usr/bin/env <tool>`, which inherits the GUI
     app's minimal launchd PATH (`/usr/bin:/bin:…`) — Homebrew-installed
     npm/pnpm/yarn/bun/pytest would report "command not found" and read as a
     false validate failure when Kouen.app is launched from Dock (not from a
     terminal that leaks shell PATH). Fixed by adding
     `resolveValidateExecutable(_:)`, mirroring the existing
     `Process.zoxideQueryAll()` fix for the identical gap
     (`CommandPaletteController.swift`) — checks
     `/opt/homebrew/bin`/`/usr/local/bin`/`/usr/bin` before falling back to
     bare-name-via-`env`.
  2. Button had no re-entrancy guard — a second click on "Merge" while a
     multi-minute validate was still running would spawn a second concurrent
     validate+dialog for the same worktree. Fixed: `sender.isEnabled = false`
     for the duration of the Task.

  **Known, not fully closed:** a real validate run against a real dirty
  worktree (with an actually-failing test) has not been exercised end to end
  — build/unit-green only, same live-check caveat as every other phase in
  this doc. Kouen's own worktrees specifically carry an extra known risk:
  this session hit `SidebarPlacementSyncTests`' documented sandboxed-AppKit
  crash while unit-testing (`agent-memory/knowledge/bugs/sidebar-cmdbackslash-toggle.md`)
  — believed to be a no-real-WindowServer artifact of this dev session's
  test-runner environment specifically, not something that should reproduce
  when `swift test` is spawned from the real logged-in-desktop `Kouen.app`,
  but that belief has not been checked against the real app.

  **Scope note:** the original ask was "handoff doc + deterministic merge";
  this addendum ships only the merge-validate half. The structured
  handoff-doc piece (goals/artifacts/open-decisions passed between agents)
  is still unbuilt — not silently dropped, flagging it back to the user
  explicitly.

  **2026-07-23 follow-up — handoff-note surfacing, human side only.**
  `GitPanelView.handoffNote(at:)` reads the existing `handoff` skill's
  `agent-memory/HANDOFF.md` (From/To/Suggested skills/Note) instead of
  inventing a second handoff-doc format, and shows its `Note:` field in the
  merge confirm dialog — reuse over new schema, per the skill-routing
  precedent already established in this workspace. Files:
  `Apps/Kouen/Sources/KouenApp/UI/Git/GitPanelView.swift`. New tests:
  `Tests/KouenAppTests/GitPanelViewHandoffNoteTests.swift` (4/4), full suite
  re-verified `swift build` clean, `swift test --filter
  "GitPanelView|SignalFileRouterTests"` 50/50, `Tests/robot/run.sh` 27/27.

  **This is the human-review half only — not the agent-to-agent half.**
  The gap named earlier in this doc was specifically "agent-to-agent
  handoff structured — `WaitForRegistry` is signal-only, doesn't pass
  context between agents." What shipped here reads a prior agent's
  HANDOFF.md and shows it to a *human* at merge time — useful, but it
  doesn't close that gap. Closing it would mean the *spawn* side
  (`kouen-cli wake`/`kouenSpawnAgent`) seeding a new agent's initial prompt
  from a prior HANDOFF.md, symmetric to how `SignalFileRouter.detectProfile`
  already seeds a stack hint on spawn — not built, flagged back to the user
  rather than assumed.

  **2026-07-23 follow-up #2 — agent-to-agent leg (`kouenSpawnAgent`).**
  User confirmed: build it. `kouenSpawnAgent` (`Tools/kouen-mcp/Sources/KouenMCP/KouenDaemonTools.swift`)
  now surfaces a prior worktree's handoff in its spawn-result data — same
  non-auto-typed pattern `detectedStack`/`detectedHint` already established
  there (the calling agent/orchestrator decides whether/how to fold it into
  the new agent's first prompt; nothing is typed into the pane
  automatically).

  Advisor review caught the reused `handoffNote` (400-char truncated,
  Note-field-only — right for a human glancing at an NSAlert) being wrong
  for this caller: a continuing agent needs the full note, and
  `Suggested skills:` is the one field the `handoff` skill wrote
  specifically for the next agent, not for a human dialog. Fixed by
  splitting into `SignalFileRouter.HandoffInfo` (full `note` +
  `suggestedSkills`, untruncated) — `GitPanelView`'s merge dialog now
  truncates at its own call site (display-only concern), `kouenSpawnAgent`
  returns both fields as-is (`priorHandoff`, `priorHandoffSuggestedSkills`).
  One shared reader in `KouenCore`, two callers with different needs.

  Files: `Packages/KouenCore/Sources/KouenCore/Routing/SignalFileRouter.swift`,
  `Tools/kouen-mcp/Sources/KouenMCP/KouenDaemonTools.swift`,
  `Apps/Kouen/Sources/KouenApp/UI/Git/GitPanelView.swift`. Verified:
  `swift build --product Kouen` and `--product kouen-mcp` clean, `swift test
  --filter "SignalFileRouterTests|GitPanelView|KouenMCPTests"` 79/79,
  `Tests/robot/run.sh` 27/27.

  **Wired, not verified end to end.** All tests assert the parser against
  synthetic temp files; nothing has exercised the real flow (agent A writes
  `HANDOFF.md` in worktree A → `kouenSpawnAgent` called with `cwd` pointing
  at worktree A → the returned `priorHandoff` actually reaches a new agent's
  prompt). Same live-check-owed caveat as every other phase in this doc —
  do not read the green build/test as "the handoff flow works," only as
  "the parsing and wiring don't crash." All of this addendum's changes are
  also still uncommitted/unshipped as of this writing.

  **2026-07-23 follow-up #3 — ponytail/rl-lessons self-audit cleanup.**
  Cross-checked the whole addendum against `agent-memory/knowledge/rl-lessons.md`
  (Process/Task-actor-isolation lessons especially — RL-052, RL-063) and the
  YAGNI/reuse ladder. No RL-052 violation (`runShellCommand` wraps `Process`
  in `DispatchQueue.global().async` exactly like the pre-existing
  `runGit`/`runGitDiff`, never blocks the Task's inherited actor). Two real
  findings, both fixed:
  - `GitPanelView`'s `resolveValidateExecutable` duplicated
    `Process.zoxideQueryAll`'s Homebrew-path-search logic instead of reusing
    it (both already lived in the `KouenApp` target). Extracted
    `Process.resolveExecutablePath(_:)` (`CommandPaletteController.swift`,
    visibility widened from `private extension` to `extension` since it now
    has two callers); `GitPanelView` calls the shared one, its own copy
    deleted.
  - `mergeWorktreeAction` captures `sender: NSButton` across a
    multi-minute-await Task, matching RL-063's shape (view captured across
    an await with no post-await liveness check) — harmless in practice
    (re-enabling a detached button's `isEnabled` is a no-op, not a crash),
    but added `sender.window != nil` before the deferred re-enable anyway,
    matching this file's own established defensive convention.
  - Verified: `swift build --product Kouen` and `--product kouen-mcp`
    clean, `swift test --filter "SignalFileRouterTests|GitPanelView|CommandPalette"`
    51/51, `Tests/robot/run.sh` 27/27.

  **2026-07-23 follow-up #4 — real live-test of the validate step (option
  "A" from the live-test menu: real subprocesses, no GUI needed).** Found
  2 genuine gaps empirically (not synthetic — actual state of this dev
  machine's toolchain):
  1. This machine's node toolchain is 100% Volta (`~/.volta/bin/npm`), zero
     Homebrew node install. `resolveExecutablePath`'s original 3 candidates
     (`/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`) all missed it —
     confirmed via `env -i PATH=/usr/bin:/bin env npm` → `env: npm: No such
     file or directory`, exit 127, the exact false-validate-failure bug
     already flagged, just via a different toolchain than assumed. Fixed:
     added `~/.volta/bin/<name>` as a 4th candidate
     (`CommandPaletteController.swift`). nvm/asdf/fnm remain a known,
     documented gap (not silently claimed covered) — evidence-based fix,
     not a guess at every possible version manager.
  2. System `python3` (`/usr/bin/python3`, Xcode's bundled stub) has no
     `pytest` module installed — a python-stack validate would report
     "tests failed" for an environment gap, not a real code problem. Not
     fixed (would need a process-spawning availability pre-check inside
     `SignalFileRouter.validationSteps`, which is documented as
     pure/no-process-spawn by design) — flagged as a known limitation
     instead of silently patched.
  3. Separately hardened: `validateWorktree`'s failure summary now
     distinguishes "the tool wasn't found at all" (`env: <name>: No such
     file or directory`, exit 127 signature) from "the tool ran and the
     build/test genuinely failed" — phrased differently so a missing
     toolchain doesn't read as a code-quality signal.

  Verified with a throwaway smoke test (`_LiveMAWValidateSmokeTest.swift`,
  written, run, then deleted — not meant to stay in the suite since it
  asserts against this specific machine's installed toolchain): real
  `Process.resolveExecutablePath("npm")` resolves to the actual Volta path
  on disk; a real passing `npm test` (through that resolved binary) exits
  0; a real failing one exits non-zero and is correctly detected, not
  silently swallowed; the `env: <name>: No such file or directory` /
  exit-127 signature is confirmed real. Re-verified after cleanup: `swift
  build --product Kouen` clean, `swift test --filter
  "SignalFileRouterTests|GitPanelView|CommandPalette|KouenMCPTests"` 79/79,
  `Tests/robot/run.sh` 27/27.

  **2026-07-23 follow-up #5 — leg C (`kouenSpawnAgent` priorHandoff) fully
  live-verified end to end, against a real daemon.** User asked to test the
  agent-to-agent leg; production Kouen.app had 6 live panes across 5
  unrelated projects (all agents idle) — confirmed via `kouenList` — so
  installing over production and restarting was ruled out. Used `make
  preview` instead: an isolated preview build with its own bundle id
  (`com.vit129.kouen.preview`), own daemon, own socket
  (`/tmp/kouen-preview-<hash>/kouen.sock`), confirmed running standalone
  without touching the production app or its 6 panes (`ps aux` showed both
  running independently throughout).

  With `KOUEN_HOME` pointed at the preview's isolated socket and
  `KOUEN_MCP_ALLOW_CONTROL=1`, called `KouenDaemonTools().kouenSpawnAgent(
  agent: "claude", cwd: <real temp dir with agent-memory/HANDOFF.md>)`
  directly (Swift method call against the real running preview daemon — no
  JSON-RPC hand-rolling needed, `KouenDaemonTools` is a plain struct).
  **Real result, unedited:**
  ```json
  {"sessionId":"...","launched":"claude","priorHandoff":"LIVE TEST — this is
  the real end-to-end handoff note agent B should receive.","agent":"claude",
  "priorHandoffSuggestedSkills":"dev-architect","surfaceId":"..."}
  ```
  This is the full real chain: a real session spawned in a real (isolated)
  daemon, a real `claude` CLI process launched in a real PTY, and
  `priorHandoff`/`priorHandoffSuggestedSkills` both present with the exact
  text from the real `HANDOFF.md` file on disk. Leg C's core claim —
  "kouenSpawnAgent surfaces a prior agent's handoff for the caller to fold
  into a new agent's context" — is no longer just wired, it's verified
  against a real spawn.

  Cleanup: `make preview-stop` killed the preview app+daemon (confirmed via
  `ps aux` — no orphaned `claude` process tied to the test's temp
  directory), preview state dir removed, throwaway test file
  (`_LiveSpawnAgentHandoffSmokeTest.swift`, written/run/deleted, not
  committed) removed. Production Kouen.app (73404) and its 6 panes
  confirmed untouched throughout. Re-verified after cleanup: `swift build
  --product Kouen` clean, `swift test --filter
  "SignalFileRouterTests|GitPanelView|CommandPalette|KouenMCPTests"` 79/79,
  `Tests/robot/run.sh` 27/27.

  **2026-07-23 follow-up #6 — leg B confirmed by the user, real screenshot.**
  Set up a throwaway scratch repo (`package.json` with a real passing
  `npm test`, a real `agent-memory/HANDOFF.md`, an uncommitted change) as a
  worktree, relaunched `make preview`, user opened it and clicked "Merge"
  on the real NSAlert. Screenshot confirms all three pieces render exactly
  as designed:
  - `✓ npm test passed.` (validate ran for real, correct phrasing for a
    genuine pass — not the "tool not found" branch)
  - `📋 Handoff note left by this worktree's agent: Demo handoff for leg
    B — implemented the login form; validation still needs a real backend
    check.` (exact text from the real `HANDOFF.md` on disk)
  - `⚠️ This worktree has uncommitted changes — they will NOT be included
    in the merge.`
  User clicked Merge for real (not just Cancel) — sidebar updated to
  "merged · main", which only happens after the success path's
  `Toast.show("✓ Merged …")` + `refresh()` both ran, so the follow-up toast
  is confirmed to have fired too without needing a second screenshot.
  Cleanup: demo repo/worktree deleted, `make preview-stop` run, production
  Kouen.app (pid unchanged throughout) confirmed still running untouched.

  **All 6 MAW legs are now genuinely live-verified, not just wired**:
  isolation (pre-existing), handoff-doc format reuse, human-review-at-merge
  (leg B, this entry), validate-gate with the real-machine PATH fix (leg A),
  agent-to-agent handoff (leg C). Still not live-tested: the swift/python
  validate branches specifically (lower risk — `/usr/bin/swift` is
  standard-PATH; python's pytest-missing gap is already documented above
  rather than silently passing). All changes remain uncommitted as of this
  writing.

## Sources (2026-07-11 research)
- cmux: https://github.com/manaflow-ai/cmux
- Supacode: https://supacode.sh/ , https://github.com/supabitapp/supacode
- Superset: https://superset.sh/ , https://github.com/superset-sh/superset
- WezTerm: https://wezterm.org/config/lua/config/mux_enable_ssh_agent.html
- Zed: https://zed.dev/docs/ai/agent-panel , https://andrew.ooo/answers/what-is-zed-terminal-threads-may-2026/
