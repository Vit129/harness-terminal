---
name: agents-tab-removed
description: "Removed the Git panel's 'Agents' segment (P38 Phase A cross-repo worktree review dashboard) — fully redundant with the existing Board view + Worktrees tab, no unique value, user decision 2026-08-06"
metadata:
  type: project
  modified: 2026-08-06
---

On 2026-08-06, after a redundancy analysis (Board view already shows agent kind+activity
per tab across ALL sessions including non-git ones; Worktrees tab already shows the same
`WorktreeCardView` rows, just scoped to the current repo), user chose to remove the
Git panel's "Agents" segment entirely rather than redesign it.

**Why:** the tab's own code comment admitted it "repurposes what was a dormant,
half-wired 'Repos' surface" — built because unused code existed, not because a user
asked for cross-repo worktree aggregation specifically. Genuinely overlapped with two
other existing surfaces on the same axis (which agent, what activity) without being a
superset of either. Matches [[no-gimmick-feature-policy]] — usage-driven removal, not
competitor-checkbox thinking (no competitor in `competitive-position.md`'s research
does this exact cross-repo-worktree-plus-agent-status combination either, so removal
wasn't "catching up" to anything).

**What was removed:** `tabSelector`'s 4th segment + `agentsContainer`/`agentsScroll`/
`agentsStack`, `refreshAgentReview` (the populate function), `repoCandidates` (its
exclusive tab→repo dedup helper), `worktreeReviewStats`/`parseShortstatFileCount` (its
exclusive git-stats fetcher), `makeRepoGroupHeader`, the `RepoEntry` struct, the
"Review Agent Work" command-palette action + its `.kouenOpenGitPanel`
`selectAgentsTab` notification plumbing, and `WorktreeEntry.filesChanged`/`lastCommit`
(always-nil dead fields once their only populator was gone) + the now-unreachable
display branch in `makeWorktreeRow`. `parseWorktreePorcelain` (shared with the
Worktrees tab) and `WorktreeCardView`/`fetchWorktreeEntries`/`cdToWorktree`/
`removeWorktreeAction` were kept untouched.

**How to apply:** if a future "cross-repo agent visibility" ask comes up again, check
Board's actual capability first (it may already need only a minor extension, e.g. a
repo-grouping toggle) before building a parallel surface — this is the second time a
near-duplicate got built (first as the dormant Repos tab, then repurposed into Agents);
don't let a third instance happen without checking Board first.
