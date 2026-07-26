# Dev Task Progress — Workspace Sidebar Panels (P42)

Last updated: 2026-07-17 13:05
Status: CLOSED/SUPERSEDED — see design.md for why (reverted after real usage, continues as P43)

## Context
- System: kouen-terminal
- Feature: p42-workspace-sidebar-panels
- Workflow: Dev
- Complexity: Standard
- Test Root: Tests/KouenAppTests/

## Artifacts
- Design: agent-memory/plans/p42-workspace-sidebar-panels/design.md
- Mockups + prior-art research: https://claude.ai/code/artifact/35dc2ebd-3077-4d24-8cde-6331d9b6b4c8
- Published: N/A

## Summary
- Total tasks: 7
- Completed: 2
- Remaining: 5

## Note on task re-sequencing (2026-07-17)

Original plan had a new `KouenSplitContainerView` with hand-built persistence via `NSSplitView.autosaveName`. Empirical testing (3 throwaway `swiftc` probes, see design.md Tactical Design) showed `autosaveName` doesn't reliably restore under this codebase's Auto-Layout-based construction, and that avoiding a guarded `layout()` override just relocates the CASE-006 recursion, not removes it. Corrected plan below: mirror the codebase's own already-proven `KouenSplitView` guard shape, and split into 2 slices — ship the 3-pane stack first (even-spaced, no persistence), verify for real, then add per-workspace divider memory.

**Second re-sequencing (same day):** Task 2 and Task 4 (headers/tab-bar removal) turned out to be more coupled in the real code than planned — `selectSidebarTab`'s header-swap and tab-bar Picker share the same function. Per a second advisor consult: kept them separate anyway via a deliberately "ugly but verified" intermediate — Task 2 below strips only the cross-pane `isHidden`-by-index branching (all 3 panes always visible) and leaves the tab bar Picker + single shared header **inert/stale** in place. Task 4 does the real cleanup (3 per-pane headers, tab-bar removal) only after Task 3's `make preview` gate confirms the core split renders correctly with real content — isolating the one thing never actually verified (`NSHostingView`/`GitPanelView` inside a variable-height arranged subview) from a second round of model/header churn. Also found while implementing: `reload()`/`refreshMetadata()` already update `fileTreeView`/`gitPanelView` roots unconditionally on every snapshot change, regardless of active tab — the "root-path plumbing rewiring" the design doc scoped turned out to be unnecessary, already tab-independent.

## Client Application — Slice 1 (stacked panes, no persistence)

- [x] **Task 1 — `KouenSidebarSplitView` with CASE-006/CASE-002 guards + regression tests** ✅ 2026-07-17
  New `NSSplitView` subclass (`Apps/Kouen/Sources/KouenApp/UI/Sidebar/KouenSidebarSplitView.swift`) mirroring `KouenSplitView`'s (`ContentAreaViewController.swift:810`) `isApplyingPositions` (CASE-006) + `appliedRatio` (CASE-002) guards, without the pane-specific `tabID`/`firstPaneID`/`secondPaneID`/corner-handle code. `ratios: [Double]?` (plural — 2 dividers for 3 panes). `ratios == nil` reuses `KouenSplitView`'s already-N-general even-spacing loop.
  - [x] ✅ Run test scripts (verify GREEN) — `Tests/KouenAppTests/KouenSidebarSplitViewTests.swift`, both built under a **real Auto-Layout-constrained container** (`NSLayoutConstraint`-pinned, not a manually-set frame — a frame-based test would give a false pass, per the design doc's dead-end 1):
    1. 3 subviews, `ratios == nil`, evenly spaced (loosened tolerance to account for real divider-thickness overhead, not a hardcoded exact px). **PASS**
    2. `ratios` set to 2 custom values, survives a second `layoutSubtreeIfNeeded()` pass without collapsing/redistributing. **PASS**

- [x] **Task 2 — Wire `KouenSidebarSplitView` into `KouenSidebarPanelViewController`, `ratios = nil`** ✅ 2026-07-17
  New `sessionsSlot`/`filesSlot` container views hold the existing session-list/board and file-tree/viewer pairs (same within-slot `isHidden` toggle as before); `gitPanelView` is a standalone arranged subview. `setupSidebarSplit()` builds the `KouenSidebarSplitView`, anchored where the old individual setups anchored. `selectSidebarTab(index:)` stripped down to only the cross-pane `isHidden`-by-index lines removed — within-slot toggles (session↔board, tree↔viewer) kept; tab bar Picker + shared header **left inert/stale on purpose** (Task 4 cleans up, after the preview gate). `reload()`/`refreshMetadata()` already handle root-path updates tab-independently — no changes needed there.
  - [x] ✅ Run test scripts (verify GREEN) — `swift build --product Kouen` clean; targeted run of 67 sidebar-adjacent tests (`BoardViewControllerTests`, `FileTreeWatcherTests`, `SidebarPlacementSyncTests`, `TaskDashboardGroupingTests`, `FilePreviewCoordinatorTabScopeTests`, `GitPanelView*Tests`, `KouenSidebarSplitViewTests`, `KouenSplitViewTests`) — 0 failures. (Full-suite `swift test --filter KouenAppTests` crashes on a pre-existing, unrelated `ScriptingTests` notification-center issue — confirmed via `git stash` that the identical crash happens on the clean, unmodified codebase too; not a regression.)

- [ ] **Task 3 — `make preview` verification gate (real content, not probes)** — *blocked by Task 2 (done), blocks Tasks 4-7* — IN PROGRESS
  Build via `make preview`, confirm in the real running app: all 3 panels (Sessions/Files/Git, real `NSHostingView`-wrapped session list + real `WorkspaceFileTreeView` + real `GitPanelView`) render simultaneously, dividers drag-resize correctly, no collapse/redistribution glitches. **This is the de-risking gate the design doc calls for** — slice 2 (persistence) and Task 4 (header/tab-bar cleanup) do not start until this passes for real, not just in a standalone probe.

- [ ] **Task 4 — Per-pane headers, remove exclusive tab bar** — *blocked by Task 3*
  Remove `SidebarTabBarView`'s exclusive `Picker` from `SidebarWorkspaceViews.swift`. Give each pane (Sessions/Files/Git) its own compact label — `sidebarSectionModel.text`/`isRepoHeader` swap-per-active-tab logic has no single active tab to key off anymore.
  - [ ] ✅ Run test scripts (verify GREEN)

## Client Application — Slice 2 (per-workspace divider memory)

- [ ] **Task 5 — Per-workspace `ratios` persistence** — *blocked by Task 3 (not Task 4 — independent of headers)*
  `sidebarRatios: [WorkspaceID: [Double]]` on `KouenSidebarPanelViewController`. Write on divider drag (`splitViewDidResizeSubviews`-equivalent hook on `KouenSidebarSplitView`). At the workspace-switch call site in `KouenSidebarPanelViewController+RecentProjects.swift` (pill tap → `SessionCoordinator.shared.selectWorkspace(id:)`), assign `splitView.ratios = sidebarRatios[newWorkspaceID]` (nil for a never-visited workspace — evenly spaces via the same guarded path, no special-casing needed). Per `focus-persistence.md` RL-043 lesson, this must be an explicit assignment at the switch call site, not assumed to fall out on its own.
  - [ ] ✅ Run test scripts (verify GREEN) — switching workspaces applies the right stored ratios (or evenly-spaces for first-visit), divider drag under workspace A doesn't affect workspace B's stored ratios.

- [ ] **Task 6 — Manual pass + robot regression suite** — *blocked by Tasks 4, 5*
  `Tests/robot/run.sh` (per project CLAUDE.md: run before every build) — confirms no regression in existing sidebar/tab-bar robot invariants. Manual check in `make preview`: 3 panels visible simultaneously, resize each, switch workspaces, confirm ratios restore per-workspace and file/git roots update on session switch.
  - [ ] ✅ Run test scripts (verify GREEN)

## Integration

- [ ] **Task 7 — Code review gate + final full suite**
  `review-personas` code-reviewer pass (fan out to bug-hunter given CASE-006's recursion history and the 3 dead-end corrections this design went through). Don't mark complete with Critical/Important findings unresolved.
  - [ ] ✅ Run all test scripts (verify GREEN)
  - [ ] Code review
