# P38 Phase A — Dev Task Progress

## Context
- System: kouen-terminal
- Feature: p38-phase-a-diff-dashboard
- Workflow: Dev
- Complexity: Standard
- Test Root: Tests/KouenAppTests (unit) + Tests/robot (regression)

## Artifacts
- Design: agent-memory/plans/p38-phase-a-diff-dashboard/design.md
- Source plan: agent-memory/plans/p38-competitive-feature-gaps.md (Phase A section)
- Published: N/A

## Lessons Learnt reviewed
- `agent-memory/knowledge/cases/cwd-worktree-bleed.md` — directory-identity values must probe
  the shell, not transient descendants; not directly load-bearing here (this feature reads
  `Tab.cwd`/`worktreePath` as already-resolved state, doesn't re-probe cwd), but reinforces:
  don't add a second, competing source of truth for "which repo is this worktree in" — always
  derive from existing `Tab`/`WorktreeEntry` fields, never re-shell-out to infer it ad hoc.
- No prior case found for `GitPanelView` merge/conflict flows or aggregate multi-repo views —
  this is new territory in this file, extra care on the concurrency/staleness contract in
  design.md's Logical Design section.

## Task Granularity note
Tasks 1-4 are pure-refactor/plumbing slices (behavior-preserving, each independently testable
and shippable). Tasks 5-8 are the vertical feature slices (UI + aggregate refresh + merge
action). Task 9-10 close the verification gate. Sequencing mostly linear per design.md's Step
1→2→3→4, but Tasks 1-4 have no cross-dependencies on each other and may be done in any order
or in parallel.

## Tasks

### Category 1 — Pure refactor + extraction (no behavior change)
- [x] **Task 1** — Moved `WorktreeEntry` to file scope in `GitPanelView.swift` (widened from
  `private` to internal so `@testable import` can reach it), added `filesChanged: Int?` /
  `lastCommit: String?` fields (default nil via custom init). `swift build` green.
- [x] **Task 2** — Extracted `parseWorktreePorcelain(_:mergedBranchOutput:)` as `nonisolated
  static` from the inline parsing in `refreshWorktrees(generation:)`; `refreshWorktrees` now
  calls it. Added `Tests/KouenAppTests/GitPanelViewWorktreeParsingTests.swift` covering
  main/linked/detached/locked/merged porcelain blocks + empty output — 6/6 pass.
- [x] **Task 3** — Added `repoCandidates(tabs:)` as `nonisolated static`, keyed on
  `tab.parentRepoPath ?? tab.cwd`, deduped. **Deviation from plan**: did not refactor the
  existing `refreshRepos()`/`reposStack` onto it — that code is deleted wholesale in Task 5
  (locked decision: fold Repos into Agents segment), so rewiring it first would be thrown-away
  work. `repoCandidates` is new, tested code ready for Task 6 to consume directly. Dedup test
  (two tabs sharing `parentRepoPath` collapse to one) included in the same test file — 6/6 pass.
- [x] **Task 4** — Added `worktreeReviewStats(worktreePath:)` next to `runGitDiff`, reusing
  `runGitDiff` itself (via `async let`) instead of a new Process-spawn — avoids duplicating the
  subprocess plumbing. `parseShortstatFileCount(_:)` extracted + tested (multi-file, singular
  "1 file", empty, unrelated/error output) — 10/10 parsing tests pass.
- ✅ Ran: `swift build && swift test --filter GitPanelViewWorktreeParsingTests` — 10/10 pass.
  Noted: full unfiltered `swift test` has a **pre-existing, unrelated** crash/flake in
  `NotificationCoordinator`/`DaemonSyncService` (confirmed via `git stash` + full-suite run on
  clean `main` — reproduces without any of this feature's changes). Not caused by this work;
  targeted-filter runs are the reliable signal until that flake is separately investigated.

### Category 2 — Agents segment UI + aggregate refresh (A1 + A2)
- [x] **Task 5** — Renamed `reposContainer`/`reposScroll`/`reposStack` to `agentsContainer`/
  `agentsScroll`/`agentsStack` (repurposed, not duplicated) — added "Agents" as `tabSelector`'s
  4th segment; `tabChanged()` shows/hides `agentsContainer` for segment 3 and kicks a
  `Task { await refresh() }` on select (mirrors `toggleWorktreesSection`). Deleted the old
  `refreshRepos()` (was only ever reachable from one incidental call site inside `applyState`'s
  `!stateChanged` branch — confirmed dead/unreachable from the UI) and `lastRepoEntries`.
  `buildRepoRow` (path/branch/session row) was replaced, in Task 6, by `makeRepoGroupHeader`
  (name + worktree count, styled like the existing `makeWorktreesSectionHeader`) — branch/
  session columns dropped since a repo group spans multiple worktrees on different branches.
  `swift build` green.
- [x] **Task 6** — Implemented `refreshAgentReview(generation:)`: `repoCandidates` →
  `git rev-parse --show-toplevel` resolve+dedupe → per-repo `fetchWorktreeEntries` (new shared
  helper, also refactored `refreshWorktrees` onto it) → `withTaskGroup` over
  `worktreeReviewStats` → generation re-check after every await batch → render
  `makeRepoGroupHeader` + `makeWorktreeRow` per non-main worktree, enriched with
  `filesChanged`/`lastCommit` (meta line in `makeWorktreeRow` now appends "N files · time" when
  present). Added `lastAggregateSignature` + `invalidateWorktreeCaches()` (resets both cache
  keys, wired into `removeWorktreeAction`). Wired into `refresh()` right after
  `refreshWorktrees`. All 32 `GitPanelView*` tests pass (10 new + 22 pre-existing, 0 broken).
  — blocked by Tasks 2, 3, 4, 5
- [x] **Task 7** — Registered `action.reviewAgentWork` ("Review Agent Work") in
  `CommandPaletteController.buildActions()`. **Deviation from plan**: the controller has no
  direct reference to the sidebar/split view (only `SessionCoordinator`), so instead of a new
  coupling, the handler posts the *existing* `.kouenOpenGitPanel` notification (already how the
  daemon opens the Git panel) with a new `"selectAgentsTab": true` userInfo flag.
  `GitPanelView.showAgentReview()` added (sets `tabSelector.selectedSegment = 3` +
  `tabChanged()`); `KouenSidebarPanelViewController.handleOpenGitPanel` checks the new flag and
  calls it. `swift build` green, 41/41 relevant tests pass.
- ✅ Ran: `swift build && swift test --filter "GitPanelView|PaletteModel"` — 41/41 pass. Live
  `make preview` check deferred to Task 10's full walkthrough (per plan).

### Category 3 — Merge/handoff action (A3)
- [x] **Task 8** — Added 3rd `SoftIconButton` (`arrow.triangle.merge`) to `makeWorktreeRow`,
  hidden when `isMain || isMerged`. `mergeWorktreeAction(_:)` resolves branch/main-worktree
  fresh from the source path (see below) → `performMerge`: confirm alert (target path named,
  uncommitted-source warning) → target dirty-preflight abort → `runGitWithStatus(["merge",
  branch])`, plain merge (no `--no-ff`, per locked decision) → success
  (`invalidateWorktreeCaches()`, toast, `refresh()`) → failure distinguishes `MERGE_HEAD`
  conflict (inline red conflict card via `makeConflictCard`, `activeMergeConflicts[sourcePath]`,
  Abort Merge/Resolve-in-Changes buttons, zero auto-resolve) from hard failure (toast with
  `toastErrorSummary`). Added `reconcileMergeConflicts` (called every `refresh()`) so a
  conflict card clears itself once `MERGE_HEAD` no longer verifies (resolved/aborted outside
  this UI) instead of staying stale forever.
  **Deviation + bug fix found along the way**: `activeMergeConflicts` is keyed by the *source*
  worktree path (not repo path as design.md sketched) so the conflict card renders in that
  specific row's place — simpler than threading repo identity through render call sites, and
  matches "renders in the row's place" literally. While wiring this, found that
  `removeWorktreeAction` anchored on `currentPath`, which is **wrong** for any row on the new
  cross-repo Agents tab that belongs to a different repo than the currently-focused one (Task 6
  reused `makeWorktreeRow` for cross-repo rows without this call site accounting for it) — fixed
  by adding `resolveMainWorktreePath(from:)` (lists worktrees from the row's own path, so it's
  correct regardless of which repo `currentPath` is) and using it in both `removeWorktreeAction`
  and the new merge flow. `swift build` green, 32/32 `GitPanelView*` tests pass.
- ✅ Ran: `swift build && swift test --filter GitPanelView` — 32/32 pass. Live merge/conflict
  walkthrough deferred to Task 10 (needs a real repo with a manufacturable conflict).

### Category 4 — Regression + final gate
- [x] **Task 9** — Added `Tests/robot/worktree_review_dashboard.robot`, 3 structural guards:
  (A) merge call site is the exact plain two-arg form + no quoted `"--no-ff"` anywhere; (B) no
  `--theirs`/`--ours`/`checkout --force` auto-resolve call anywhere in the file; (C)
  `reconcileMergeConflicts` exists, re-verifies `MERGE_HEAD`, is actually called from `refresh()`,
  and `activeMergeConflicts` is read by `makeWorktreeRow` (not write-only). Auto-discovered by
  `run.sh` (globs the whole directory, no explicit wiring needed). **Two bugs caught and fixed
  in the guards themselves during first run**: Guard A's naive `--no-ff` substring check matched
  my own doc-comment prose ("no `--no-ff`, per locked decision") — narrowed to the quoted
  `"--no-ff"` literal form so it only catches real code. Guard C had a Robot Framework syntax
  error (a `msg=` value wrapped across two `...` continuation lines is parsed as a second
  positional argument, not continued text) — fixed by keeping each `msg=` on one line, matching
  every other guard in this suite. Full `run.sh`: 26/26 tests pass (was 23/23 pre-existing).
- [x] **Task 10** — Final verification gate.
  - `swift build --product Kouen`: green.
  - `swift test --filter "GitPanelView|PaletteModel"`: 41/41 pass. Unfiltered `swift test`
    still hits the pre-existing, unrelated `DesktopNotifier`/`UNUserNotificationCenter` crash
    (confirmed root cause this session: `bundleProxyForCurrentProcess is nil` — `swift test`'s
    CLI process has no real app bundle, which `UserNotifications` requires; reproduces
    identically on clean `main` via `git stash`, nothing to do with this feature).
  - `Tests/robot/run.sh`: 26/26 pass (10/10 → 26/26 net-new-suite-inclusive; 23 pre-existing +
    3 new Phase A guards).
  - Live `make preview` smoke test (launch + stay-alive, twice — once before and once after
    the code-review fixes below): both times the app builds, launches, and stays stable with
    no crash. **Genuine limitation, stated plainly**: this session has no tool that can drive
    native AppKit UI (click a segment, click a button) — only a browser-automation surface
    exists (`kouen-mcp`'s browser tools, for *browser panes inside* Kouen, not Kouen's own
    native chrome) and no accessibility/computer-use tool was available. So the actual
    click-through (Agents segment → repo grouping → diff popover → merge → conflict card →
    abort) is **not personally verified** and is owed to the user, exactly the same gap
    recorded for P39/P40's native-GUI-only features in `agent-memory/plans/INDEX.md`.
  - **Code review** (`review-personas`, fanned out as code-reviewer + security-auditor via a
    fresh subagent with no context bias from the implementation): verdict was REQUEST CHANGES.
    No security findings (array-args `Process`, no shell injection, no secrets). Findings, all
    fixed before closing this task:
    1. **Important** — `abortMergeAction` had no confirmation and repeated a lesson already on
       record in this repo (`RL-060`: `git merge --abort` discards *all* working-tree edits to
       every file touched by the operation, not just the merge's own changes — including
       manual conflict-resolution edits made after the merge started). Fixed: added a
       destructive-action confirmation alert naming exactly what's lost.
    2. **Important** — genuine stale-render race in `refreshAgentReview`: `lastAggregateSignature`
       was committed *before* the `withTaskGroup` await + final generation guard, so a
       superseded refresh could poison the cache and leave the Agents tab stuck stale until
       git state changed again. Fixed: moved the commit to after the final guard, matching
       `refreshWorktrees`'s existing (correct) ordering.
    3. **Important** — `resolveMainWorktreePath` returning nil failed silently in both
       `removeWorktreeAction` and `mergeWorktreeAction` (no alert/toast, unlike every other
       failure path in this file). Fixed: both now surface an explicit error.
    4. **Minor** — `abortMergeAction` ignored its own subprocess result, showing "Merge
       aborted" even on failure. Fixed: now checks `result.success` before clearing state.
    5. **Minor** — merge button was visible on detached-HEAD worktrees (branch = "detached" is
       not mergeable). Fixed: hidden alongside `isMain`/`isMerged`.
    Post-fix: `swift build` green, 41/41 filtered tests pass, 26/26 robot tests pass.
  — blocked by Task 9

## Summary
- Total tasks: 10
- Completed: 10
- Remaining: 0

## Status: Completed — build/test/robot green, code-reviewed and fixed; live interactive
click-through (Agents segment, merge, conflict card) still owed to the user (see Task 10 note)
## Last updated: 2026-07-13
