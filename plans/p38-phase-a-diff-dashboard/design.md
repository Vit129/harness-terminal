# P38 Phase A — Cross-Agent Worktree Diff/Review Dashboard — Design

> Source: agent-memory/plans/p38-competitive-feature-gaps.md (Phase A). Fable-consulted
> implementation plan, verified against live source (GitPanelView.swift, Tab.swift,
> KouenDesign.swift, CommandPaletteController.swift) 2026-07-13. All file/line references
> below re-checked against current source, not the original plan doc's assumptions.

## Locked decisions (user-confirmed)
- Base branch hardcoded to `main` (matches existing `fetchWorktreeDiff`'s `main...HEAD` and
  `refreshWorktrees`' `git branch --merged main` — do not add a resolver this phase).
- A3 merge = plain `git merge` (no `--no-ff`) for v1. `--no-ff` noted as a fast-follow, not
  built now.
- New `Tests/robot/worktree_review_dashboard.robot` — verification gate becomes 11/11 (was
  10/10).
- Dormant `reposContainer`/`reposStack`/`buildRepoRow` (GitPanelView.swift:56-58, 1795) fold
  into the new Agents segment as repo-grouping headers; dead code removed, not left dormant.

## Strategic Design

No new bounded context. This is a UI feature added entirely inside the existing `GitPanelView`
module (`Apps/Kouen/Sources/KouenApp/UI/Git/`) — it reads existing domain state
(`SessionCoordinator.shared.snapshot`, `Tab`) and existing git plumbing (`runGit`,
`runGitWithStatus`), it does not introduce a new subsystem. Module boundary: everything stays
inside `GitPanelView.swift` except one new command-palette registration.

Reused substrate (confirmed live, not from the plan doc):
- `WorktreeEntry` (GitPanelView.swift:1299) — path/head/branch/isMain/isLocked/isMerged.
- `agentInfo(forWorktreePath:tabs:)` (line 1313, `nonisolated static`) — resolves
  `(AgentKind, AgentActivity)` per worktree path from `Tab.agent`.
- `makeWorktreeRow(_:)` (line 1518) — per-worktree card: branch, agent icon, merged badge,
  diff button, remove button.
- `refreshWorktrees(generation:)` (line 1703) — single-repo (`currentPath`) worktree list via
  `git worktree list --porcelain` + `git branch --merged main`.
- `refreshRepos()` (line 1759) — cross-tab repo enumeration into `RepoEntry`
  (path/branch/sessionName), already deduped by `cwd`.
- `fetchWorktreeDiff(worktreePath:)` (line 669) / `runGitDiff` — diff vs merge-base, already
  implemented.
- `runGit` / `runGitWithStatus` — existing async git-subprocess plumbing (daemon-routed,
  stderr-surfacing).
- `Tab.parentRepoPath` (Packages/KouenIPC/Sources/KouenIPC/Tab.swift:45) — exact field needed
  as merge-target repo root for A3, set by `WorktreeAutoIsolateService` + task creation.
- `tabSelector` (GitPanelView.swift:52) — `NSSegmentedControl(labels: ["Changes", "History",
  "Worktrees"], ...)` → becomes 4-segment control.
- `SoftIconButton` (KouenDesign.swift:410, `final class SoftIconButton: NSButton`) — real
  `isBordered = false`, `isTransparent = false`, `.momentaryChange` — dispatches via standard
  NSButton target/action, safe to add a 3rd instance per row. (The `isTransparent=true` comment
  cited in GitPanelView.swift:1534 is stale/inaccurate — verified against the live class.)

## Tactical Design

**Extended value type** — `WorktreeEntry` (moved from nested-private to private file scope,
still `Sendable` by virtue of all-`let` String/Bool/Int? fields):
```swift
private struct WorktreeEntry {
    let path: String
    let head: String
    let branch: String
    let isMain: Bool
    let isLocked: Bool
    let isMerged: Bool
    let filesChanged: Int? = nil   // new — nil on the existing single-repo Worktrees tab
    let lastCommit: String? = nil  // new — populated only on the new Agents tab
}
```

**New pure helpers** (nonisolated static, unit-testable without a live `SessionCoordinator`,
same pattern as `agentInfo`/`toastErrorSummary`):
```swift
nonisolated static func parseWorktreePorcelain(_ output: String, mergedBranchOutput: String) -> [WorktreeEntry]
nonisolated static func repoCandidates(tabs: [Tab]) -> [RepoEntry]   // keyed on parentRepoPath ?? cwd, deduped
nonisolated static func worktreeReviewStats(worktreePath: String) async -> (filesChanged: Int, lastCommit: String)
nonisolated static func parseShortstatFileCount(_ output: String) -> Int
```

**New mutable state on `GitPanelView`:**
```swift
private var lastAggregateSignature: String = ""              // separate cache key from lastWorktreeOutput
private var activeMergeConflicts: [String: [String]] = [:]    // repoPath -> conflicted file paths
```

**Domain event equivalent** (state transitions, not literal events — AppKit/imperative, no
event bus in this module): merge-attempted → merge-succeeded (badge flips to merged) |
merge-conflicted (conflict card renders, persisted across generation-superseded refreshes) |
merge-hard-failed (toast only, no state persisted).

## Logical Design

**New UI surface** — 4th `tabSelector` segment "Agents", replacing the currently-hidden Repos
container as the entry point (`reposContainer`/`reposStack` deleted, `buildRepoRow` logic
folded into the new repo-grouping header renderer inside the Agents refresh path).

**Refresh flow** (`refreshAgentReview(generation:)`, called from `refresh()` after
`refreshWorktrees`, gated to only run when the Agents segment is selected/visible):
1. `repoCandidates(tabs:)` over `SessionCoordinator.shared.snapshot` tabs → dedup via one
   `git rev-parse --show-toplevel` per candidate (same call `WorktreeManager.repoRoot` uses;
   not unified with it in v1 — KouenCore's `WorktreeManager.parseWorktreeList`/`WorktreeInfo`
   is a separate, synchronous, `-warnings-as-errors`-constrained parser; changing its public
   surface is out of scope for this phase, left as a one-line cross-reference comment).
2. Per resolved repo root: reuse `fetchWorktreeEntries(repoPath:)` (the same instance-level
   wrapper `refreshWorktrees` now calls after Step 1's refactor) to get `[WorktreeEntry]`.
3. `withTaskGroup` over all worktrees needing stats → `worktreeReviewStats(worktreePath:)`
   concurrently (nonisolated static, no `@MainActor` hazard) → collect into a
   `[String: (Int, String)]` keyed by path.
4. Re-check `generation == refreshGeneration` (staleness guard) before touching any `NSView`.
   Discard partial results on mismatch — never partially render.
5. Build `lastAggregateSignature` from repo roots + each repo's porcelain/merged-branch output;
   skip rebuild if unchanged (mirrors `lastWorktreeOutput`'s existing flicker-prevention
   pattern, but as its own key so the two tabs' skip-guards can't clobber each other).
6. Render: one repo-grouping header (from folded `buildRepoRow` logic) per repo, followed by
   `makeWorktreeRow(_:)` for each non-main worktree in that repo, now with `filesChanged`/
   `lastCommit` populated so the meta line reads `"<branch> · <agent> — <activity> · N files ·
   <relative time>"`.

**A3 merge/handoff contract** (`mergeWorktreeAction(entry:repoPath:mainWorktreePath:)`):
```
input:  WorktreeEntry (source branch), repoPath, mainWorktreePath (target — first/isMain entry)
1. NSAlert confirm: "Merge <branch> into <target-branch> (in <mainWorktreePath>)?"
   — if source worktree has uncommitted changes (git status --porcelain), append warning text.
2. Preflight: git status --porcelain in mainWorktreePath — dirty → abort, Toast, no merge attempted.
3. suppressingFSEvents = true; runGitWithStatus(["merge", branch], in: mainWorktreePath); reset flag.
4. success -> invalidateWorktreeCaches(); Toast "✓ Merged <branch>"; await refresh().
5. failure -> git rev-parse -q --verify MERGE_HEAD in mainWorktreePath:
     exists  -> conflict: git diff --name-only --diff-filter=U -> activeMergeConflicts[repoPath] = files
                render inline conflict card (red WorktreeCardView variant): "Abort Merge" (git merge --abort
                + clear activeMergeConflicts[repoPath] + refresh) | "Resolve in Changes" (updateRoot(path:
                mainWorktreePath) + select Changes segment). No auto-resolve of any kind, ever.
     absent  -> Toast "✗ Merge failed: <stderr summary>" via existing toastErrorSummary().
```
Entry point: 3rd `SoftIconButton` per row (`arrow.triangle.merge`, tooltip "Merge <branch> into
<target>"), hidden when `isMain || isMerged`.

**Command palette contract** — `CommandPaletteController.buildActions()` (line 210) gains one
`PaletteAction` ("Review Agent Work") whose handler reveals the sidebar git panel and selects
the Agents segment via a new `func showAgentReview()` on `GitPanelView`.

**Concurrency contract (Swift 6 strict):**
- All new pure parsers/stat-fetchers are `nonisolated static` — zero `@MainActor` hops needed
  inside `withTaskGroup` children.
- `WorktreeEntry`/`RepoEntry` are plain `let`-only value structs of `Sendable` primitives —
  implicitly `Sendable`, crossing the `nonisolated` → `@MainActor` boundary is sound.
- Single generation authority: the Agents refresh is driven by `refresh()`'s existing
  `refreshGeneration`, never a parallel entry point — segment selection calls
  `Task { await refresh() }`, same as `toggleWorktreesSection` does today.
- Known v1 gap (documented, not fixed this phase): FSEvents watcher only watches `currentPath`,
  so a commit landing in a repo that isn't the currently-focused tab's repo won't auto-refresh
  the Agents tab. Mitigated by refresh-on-segment-select + existing `refresh()` triggers only.

## Verification gate (this phase)
- `swift build` + `swift test` green (new: `GitPanelViewWorktreeParsingTests.swift` covering
  porcelain parsing incl. main/linked/detached/locked/merged entries, repo-candidate dedup incl.
  `parentRepoPath` collapsing, shortstat file-count parsing).
- `Tests/robot/run.sh` 10/10 → 11/11 (new `worktree_review_dashboard.robot`) — **feasibility
  checked**: this project's `.robot` suite is static source-guard regression tests
  (`Should Contain`/`Get File`/Python structural checkers against source text), not a
  GUI-clicking E2E harness — there is no AppKit UI driver in use (confirmed: P39/P40 GUI
  features got manual `make preview` live-checks in INDEX.md, not robot coverage, for the
  same reason). The new `.robot` file therefore asserts source-level invariants (merge path
  never passes `--no-ff`, conflict path never calls an auto-resolve/`checkout --theirs`
  equivalent, `activeMergeConflicts` state isn't silently dropped on refresh) rather than
  driving clicks. Actual click-through UI verification stays in the live `make preview` check
  below, as it does for every other GUI feature in this project.
- Live check (`make preview`): 2+ tabs on different branches in the same repo (auto-isolated
  worktrees) + 1 tab in a second repo → Agents segment lists both repos grouped, agent
  icon/files-changed/last-commit populated per row, diff button opens existing popover, merge
  on a clean branch flips to merged badge, a manufactured same-line conflict renders the inline
  conflict card with working Abort (no auto-resolve).
