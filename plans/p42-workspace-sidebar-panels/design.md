# P42 — Workspace Sidebar Panels

Source: Kouen Task Dashboard task `B9325A6E` ("KouenTerminal should be support workspace too"), interviewed 2026-07-17. Prior-art research (VSCode/Superset/Supercode/cmux/tmux/Zed) and mockups: https://claude.ai/code/artifact/35dc2ebd-3077-4d24-8cde-6331d9b6b4c8

**Decision (user, 2026-07-17):** Option A, styled **terminal-native (cmux/tmux-style stacked panes)** — explicitly not a VSCode-style IDE explorer. Multi-root folder support (multiple project roots in one Files tree) is a separate, bigger axis — parked, not in scope here.

**⚠️ CLOSED/SUPERSEDED same day, after real usage in `make preview`:** Option A (always-visible stacked panes) shipped (Tasks 1-2, `KouenSidebarSplitView` + wired into `KouenSidebarPanelViewController`), built, and ran clean — but the user found it genuinely hard to use once actually tried on a real narrow sidebar (3 stacked resizable panes leaves each too cramped). **Fully reverted** — `git checkout` on `KouenSidebarPanelViewController.swift`, deleted `KouenSidebarSplitView.swift` + its tests. Confirmed clean rebuild on the reverted tree.

Real-usage feedback also clarified what "support workspace" actually meant: keep today's exclusive tab-switching (Sessions/Files/Git buttons, one visible at a time) — that part was never the problem. What was missing is an **"Add to Workspace" action** — pick another repo/folder and merge its Files+Git into the current workspace, switchable, cmux/tmux-style (not a VSCode multi-root explorer tree). This is functionally the multi-root-folders axis this doc explicitly parked above — turns out that's what was actually wanted, just delivered via tab-switching instead of a grouped tree. New design continues in `agent-memory/plans/p43-add-repo-to-workspace/design.md`.

**Kept, still valid learnings for the new plan:**
- `KouenSplitView` (`ContentAreaViewController.swift:810`) guard-shape reference (CASE-002/006) — not needed for a tab-switching UI, but keep in mind if any future resizable-pane work touches this codebase again.
- `reload()`/`refreshMetadata()` already update `fileTreeView`/`gitPanelView` roots unconditionally per snapshot change — relevant if multi-root adds more than one root to track.
- `Workspace` struct (`Packages/KouenIPC/Sources/KouenIPC/Workspace.swift`) is daemon-synced/`Codable` — adding "extra repo roots" to a workspace is a real domain-model change this time (unlike this doc's UI-only framing), since it needs to persist and sync, not just live in the app process.

## Strategic Design

**Bounded context:** single existing module, no new service. UI-layer feature inside the `KouenApp` target's Sidebar module (`Apps/Kouen/Sources/KouenApp/UI/Sidebar/`), backed by the existing `Workspace` domain type in `KouenIPC`/`KouenCore`. No new bounded context — monolith stays monolith, module boundary unchanged (Sidebar UI ↔ SessionCoordinator facade ↔ SessionLifecycleService ↔ daemon).

**Current state, confirmed by reading the code:**
- `Workspace` (`Packages/KouenIPC/Sources/KouenIPC/Workspace.swift`) = a window-level container: `id: WorkspaceID`, `name`, `sessions: [SessionGroup]`, `activeSessionID`. Multiple Workspaces exist per window, switched via pill/dropdown (`WorkspacePillModel`, `WorkspaceSwitcherRow`, `showWorkspaceMenu()` — `KouenSidebarPanelViewController+RecentProjects.swift`) → `SessionCoordinator.shared.selectWorkspace(id:)` → `SessionLifecycleService.selectWorkspace(id)`.
- Sidebar tab bar (`SidebarTabBarView`, `SidebarWorkspaceViews.swift:246`) is a **hardcoded 3-way `Picker`** — `Text("Sessions").tag(0)`, `Text("Files").tag(1)`, `Text("Git").tag(2)` — bound to `SidebarSectionModel.selectedTab: Int`.
- `selectSidebarTab(index:)` (`KouenSidebarPanelViewController.swift:652`) shows/hides `sessionHostingView` / `fileTreeView` / `gitPanelView` by index — **strictly exclusive today**.
- **Height-anchor audit (done to de-risk the resizable-pane approach):** grepped `GitPanelView.swift`/`WorkspaceFileTreeView.swift` for `heightAnchor`/`bounds.height` — every hit is internal content sizing (buttons, badges, rows, a capped diff-hunk scroll view). Neither view pins its own *overall* height to a constant; both already fill whatever container they're given via top/bottom anchors to `sectionLabelHostingView`/`footerHostingView`. This means neither view needs internal surgery to live inside a variable-height split pane.

**Chosen approach — `NSSplitView`, not a hand-rolled stack:** AppKit's own split-pane primitive (vertical orientation, 3 arranged subviews: Sessions / Files / Git) gives drag-to-resize natively — same "just split panes" primitive cmux and tmux are built on, less code than a custom resizable-stack container with hand-built drag handles. (ponytail: native platform feature covers this — rung 4, don't hand-roll a splitter.) **Position persistence is NOT native** — see Tactical Design; `NSSplitView.autosaveName` was tried and abandoned after empirical testing.

**Why this is "moderate, not tiny" (the honest sizing the user asked about):** the change is structural — `SidebarTabBarView`'s exclusive Picker and `selectSidebarTab`'s show/hide branching are replaced by an always-visible `NSSplitView`. That's a real rewrite of the sidebar's top-level layout, just bounded to `KouenSidebarPanelViewController.swift` + `SidebarWorkspaceViews.swift` — none of the 3 panels' own internals (confirmed above) need to change.

## Tactical Design

**No new persisted domain entity** — same reasoning as before: split-position state is a UI concern, not daemon-synced session state. Do NOT add fields to `KouenIPC.Workspace`.

**⚠️ This section went through 2 empirical corrections during design. Final conclusion below; the dead ends are kept as a record of what was tried and why it failed — don't re-attempt them.**

**Dead end 1 — `NSSplitView.autosaveName`:** looked "free" (AppKit-managed `NSUserDefaults` persistence, no custom code). A throwaway `swiftc` probe with a manually-set fixed frame showed restore working. But the real sidebar builds views via pure Auto Layout (`translatesAutoresizingMaskIntoConstraints = false` + constraints), not manual frames. A second, more realistic probe — `NSSplitView` pinned via `NSLayoutConstraint`s inside a container, matching how `KouenSidebarPanelViewController` actually builds its views — reproduced a collapse: restored heights came back `[582, 0, 0]` instead of the saved `~[150, 250, 200]`, regardless of whether `autosaveName` was set before or after the first layout pass. **Conclusion: `autosaveName`'s native restore does not reliably engage under this codebase's Auto-Layout-based construction style — do not rely on it.** (This is also consistent with — though not conclusively explained by — the fact that the codebase's own existing `KouenSplitView` never uses `autosaveName` either, instead persisting an explicit `ratio` through `SessionCoordinator.setSplitRatio`.)

**Dead end 2 — "call `setPosition` from an external workspace-switch handler, avoid `layout()` entirely":** the reasoning was that CASE-006/CASE-002 are specifically about calling `setPosition` *from inside* `layout()`, so calling it externally should sidestep them. Wrong: under Auto Layout, a single external `setPosition` call gets redistributed by the next layout pass (the same probe that broke dead end 1 also showed a manual `setPosition(150, ofDividerAt: 0)` resolve to height `101`, not `150` — Auto Layout renegotiates it). Wiring the reapply into `viewDidLayout()` to fight that redistribution reproduces the **same recursion shape as CASE-006** (`viewDidLayout → setPosition → needsLayout → viewDidLayout`), just relocated from `NSSplitView.layout()` to the view controller. The guard is not optional overhead to design around — it is the mechanism that makes positions survive Auto Layout redistribution at all.

**Final approach — mirror `KouenSplitView`'s guarded `layout()`, don't avoid it:**
1. New, small `NSSplitView` subclass (name TBD at implementation, e.g. `KouenSidebarSplitView`) — mirrors `KouenSplitView`'s `isApplyingPositions` (CASE-006) + `appliedRatio` (CASE-002) guard shape, **without** the pane-specific parts (`tabID`/`firstPaneID`/`secondPaneID`, `SessionCoordinator.setSplitRatio`, corner-handle intersection dragging — none of that applies to a 3-pane sidebar stack). Stores `ratios: [Double]?` (plural — a 3-way split has 2 independent dividers, unlike `KouenSplitView`'s single `ratio: Double?` for a 2-way split).
2. **`ratios == nil` branch is already N-general** — confirmed by reading `KouenSplitView.layout()`: `for i in 0..<(count - 1) { setPosition(evenSize * CGFloat(i + 1), ofDividerAt: i) }` works for any subview count, not just 2. This alone delivers the core ask (3 stacked, resizable, always-visible panes) with zero custom persistence.
3. **Per-workspace divider memory is a separate, later slice** — store `[WorkspaceID: [Double]]` (2 ratios per workspace) in the app process (same "UI-only, not daemon-synced" reasoning as before), applied through the *same* guarded `layout()` path (setting the `ratios` property + `needsLayout = true`, not calling `setPosition` from an external handler) so Auto Layout redistribution is fought the same proven way as slice 1's even-spacing.

**Sequencing (de-risking, not just task order):** ship the 3-pane stack with `ratios == nil` (even spacing, no persistence) first, verify with real content (`NSHostingView`-wrapped session list, `WorkspaceFileTreeView`, `GitPanelView`) via `make preview` — confirm panes render and resize correctly before adding per-workspace persistence on top. This is the concrete lesson from the 2 dead ends above: verify the risky 20% (Auto-Layout-interacting layout code) empirically before layering more logic on an unproven base.

**Root-path plumbing (unchanged in shape, changed in trigger):** `fileTreeView.updateRoot(path:sessionID:)` and `gitPanelView.updateRoot(path:)` — today called conditionally inside the `case 1`/`case 2` branches of `selectSidebarTab(index:)`. Since all 3 panels are now always visible, both calls fire unconditionally whenever the active session/tab's `cwd` changes (on session switch, not on a tab-index switch that no longer exists) — same functions, different call site.

## Logical Design

**Changed files:**
1. `Apps/Kouen/Sources/KouenApp/UI/Sidebar/KouenSidebarSplitView.swift` (**new**)
   - `NSSplitView` subclass mirroring `KouenSplitView`'s guarded `layout()` (`isApplyingPositions` CASE-006 guard, `appliedRatio` CASE-002 guard/ordering), **without** the pane-specific `tabID`/`firstPaneID`/`secondPaneID`/corner-handle machinery. Property `ratios: [Double]?` (plural, N-1 dividers) instead of `KouenSplitView`'s single `ratio: Double?`. `ratios == nil` → evenly space (N-general loop, already proven in `KouenSplitView`); `ratios` set → apply each stored position in the same guarded pass.

2. `Apps/Kouen/Sources/KouenApp/UI/Sidebar/SidebarWorkspaceViews.swift`
   - Remove or repurpose `SidebarTabBarView`'s exclusive `Picker` (no more "select one of three" — panels are always visible). If a toolbar affordance is still wanted (e.g. jump/scroll-to a panel, or collapse one), that's a separate small SwiftUI change, not required for the core stacked-panes behavior.

3. `Apps/Kouen/Sources/KouenApp/UI/Sidebar/KouenSidebarPanelViewController.swift`
   - Replace the individual `setupSessionList()` / `setupFileTree()` / `setupGitPlaceholder()` Auto Layout blocks (each currently anchors its view to fill the full content area) with one `KouenSidebarSplitView` (`isVertical = false`, stacked-top-to-bottom), `arrangedSubviews = [sessionHostingView, fileTreeContainer, gitPanelView]`.
   - Remove `selectSidebarTab(index:)`'s show/hide branching; keep its `case`-based root-path-update logic (file tree reveal, git root update), now triggered by session/tab change notifications instead of tab-index change.
   - `sidebarSectionModel.text`/`isRepoHeader` (currently swapped per active tab — "SESSIONS" vs "FILES" vs "GIT") needs a new home now that there's no single active tab — likely three independent small headers, one per pane, or drop the single big header entirely in favor of each pane's own compact label (matches the cmux/tmux reference screenshots already shown in the artifact, which label each pane individually).
   - **Slice 1 stops here** (`ratios` left `nil` — even spacing, no persistence). **Slice 2** (separate task, built after slice 1 is verified in `make preview`): add `sidebarRatios: [WorkspaceID: [Double]]`, write on divider drag (`splitViewDidResizeSubviews`-equivalent), read + assign `splitView.ratios` + `needsLayout = true` on workspace switch.

4. `Apps/Kouen/Sources/KouenApp/UI/Sidebar/KouenSidebarPanelViewController+RecentProjects.swift`
   - **Slice 2 only:** at the workspace-switch call site (pill tap → `SessionCoordinator.shared.selectWorkspace(id:)`), assign the new workspace's stored ratios (or `nil` for a first-ever visit — evenly spaces via the same guarded path, not a special case). Per `focus-persistence.md`'s RL-043 lesson (GUI-side state not reset on workspace switch is the same bug shape seen before), this must be an explicit assignment at the switch call site, not an assumption that something falls out naturally.

**No API/DB contract changes** — entirely `KouenApp`-process, in-memory. No `NSUserDefaults`/`autosaveName` involved (abandoned — see Tactical Design).

**Tests (ponytail: non-trivial logic gets checks):**
1. `KouenSidebarSplitViewTests` — 3 arranged subviews, `ratios == nil` evenly spaces all 3 (not just 2) under a real Auto-Layout-constrained container (not a manually-set frame — that's exactly what hid the bug during design). This is the slice-1 regression test.
2. `KouenSidebarSplitViewTests` — `ratios` set to 2 custom values survives a subsequent Auto Layout pass (`layoutSubtreeIfNeeded()` called again) without redistributing back to even spacing or collapsing — this is the CASE-002/006-shaped regression test, and it must run under real constraint-based layout to be meaningful (see dead end 1 in Tactical Design for why a frame-based test would give a false pass).
3. `KouenAppTests` — switching workspaces applies the new workspace's stored `ratios` (or evenly-spaces for a never-visited workspace) — the slice-2 behavior.

**Rollout risk:** low-medium. The risk that mattered (Auto-Layout/guard interaction) is now empirically resolved rather than assumed either "big" or "not applicable" — both earlier framings were wrong in different directions. Splitting into 2 slices means slice 1 (the actual "stacked panes" ask) ships and gets verified before slice 2 (persistence, the part that caused all 3 rounds of empirical correction) is attempted. No changes to `GitPanelView`/`WorkspaceFileTreeView` internals (audited clean earlier).

## Parked (not in scope)

- **Multi-root folders** (VSCode `.code-workspace`-style, several project folders in one Files tree) — bigger, separate axis (`FileTreeContext.rootPath: String → [String]`, grouped tree headers, multi-root `FileTreeWatcher`, `GitPanelView` parity). Explicitly rejected for now as too IDE-like relative to the terminal-native direction chosen.

## Next Step

`references/task-design.md` (Dev section) to break this into implementation tasks.
