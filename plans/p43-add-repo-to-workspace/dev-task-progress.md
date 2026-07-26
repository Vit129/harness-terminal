# Dev Task Progress — Add Repo/Folder to Workspace (P43)

Last updated: 2026-07-17 21:15
Status: **REVERTED 2026-07-17** — all 6 tasks were built, tested, code-reviewed, and the core
Add/browse flow (extraRepoRoots + Files/Git tab picker) was confirmed live-working by the user.
A same-day follow-up ("Open Session in <root>" from the footer "+" menu, reusing the existing
`addSession(to:cwd:name:)` path) shipped but didn't visibly work on first live test — user
decided the whole feature wasn't worth continuing to debug/iterate on and asked to tear it down
entirely rather than fix the follow-up. Reverted via `git restore --source=HEAD` (everything here
was still uncommitted, so this was a clean revert, not a new commit) across: `Workspace.swift`
(`extraRepoRoots` field), `IPCMessage.swift`, `SurfaceRegistry.swift`, `SessionEditor.swift`,
`SessionCoordinator.swift`, `KouenSidebarPanelViewController.swift`, `SidebarWorkspaceViews.swift`,
plus their tests. Left below for the record — see `p42-workspace-sidebar-panels/design.md` for the
sibling revert (same feature area, different reason: UX complexity vs. this one, low perceived
value once the "run commands there" gap surfaced).

Original status before revert: Code complete, all automated verification GREEN.

## Context
- System: kouen-terminal
- Feature: p43-add-repo-to-workspace
- Workflow: Dev
- Complexity: Standard
- Test Root: Tests/KouenDaemonTests/, Tests/KouenIPCTests (or wherever Workspace decode tests live), Tests/KouenAppTests/

## Artifacts
- Design: agent-memory/plans/p43-add-repo-to-workspace/design.md
- Prior/related: agent-memory/plans/p42-workspace-sidebar-panels/design.md (reverted attempt, real-usage lesson)
- Lesson applied: agent-memory/knowledge/cases/cwd-worktree-bleed.md (confidence 1.0 — displayed-root-gets-silently-overwritten is a previously-real bug class in this exact codebase)
- Published: N/A

## Summary
- Total tasks: 6
- Completed: 6
- Remaining: 0 (manual `make preview` click-through owed separately — not a checkbox task, needs the user)

Sequencing follows Infrastructure → Server Logic → Client Application → Integration (this design spans daemon + IPC + app layers, unlike P42 which was client-only).

## Bug found via real `make preview` testing (2026-07-17, post-Task-6)

User reported the sidebar "left side" looked broken on first manual check. Two separate things surfaced:
1. **Garbled/repeated terminal prompt banners** — traced to accumulated stale scrollback/session state from this session's own repeated preview kill/relaunch cycles (P42 build → revert → P43 build, several restarts). Confirmed by `make preview-clean` + fresh relaunch — garbling did not reproduce. Not a real bug, not related to this diff.
2. **Real bug (fixed):** an "Active Session" control was visibly overlaying the Sessions tab. Root cause: `fileRootPicker`/`gitRootPicker` are pinned to the same shared, always-rendered content region every sidebar tab uses (the pre-existing exclusive-tab pattern: one rect, `isHidden` toggles which tab's content occupies it) — but `selectSidebarTab(index:)` was never given an `isHidden` line for either new picker, unlike every other pane view (`sessionHostingView`, `fileTreeView`, `gitPanelView`, `boardVC.view` all have one). They stayed visible on every tab, not just Files/Git. Fixed: added `fileRootPicker.isHidden = index != 1` / `gitRootPicker.isHidden = index != 2` to `selectSidebarTab`. Regression test: `testRootPickersAreHiddenOnSessionsTabAndShownOnTheirOwnTab` (5/5 in the file pass).

This is exactly the kind of gap the manual click-through step exists to catch — no automated test constructed the full tab-switching interaction, only the override-guard and title-collision logic in isolation.

## Bigger finding: the planned "Add to Workspace" entry point was unreachable (2026-07-17)

User tried step-by-step and the "Add Folder to Workspace…" menu item (via workspace pill → "…") wasn't there at all. Traced it: `showActiveWorkspaceActions()` (where that menu item lives) is only ever called from `workspacePill`'s `onMoreClick` — and `workspacePill` (the `NSHostingView` itself) is **never added to the view hierarchy anywhere** (`grep` for `.addSubview(workspacePill)` across the app: zero hits). It's dormant by design — a pre-existing code comment in `setupWorkspaceBar()` says so explicitly ("Workspaces are deliberately not surfaced here... switcher machinery stays dormant so it can be re-enabled later"). The menu item I added was real, working code, attached to a menu that no gesture in the live app can ever open.

User asked for both a fix and a drag-and-drop alternative, and to keep Workspace (window, holds N sessions) vs Session (one repo/folder, already the existing data model — not something P43 introduced) unambiguous. Rebuilt the entry point around the one thing that IS definitely reachable — the root pickers themselves:
- Added **"Add Folder to Workspace…"** as a real, actionable item at the bottom of both `fileRootPicker`/`gitRootPicker`'s own dropdown (via a `RootPickerAddFolderMarker` `representedObject` sentinel, distinct from a real path or "Active Session"'s `nil`) — opens the same `NSOpenPanel` flow, immediately selects the newly-added root.
- Added **drag-and-drop**: new `WorkspaceRootDropPicker` (`NSPopUpButton` subclass) accepting a dropped folder directly onto either picker. Deliberately scoped to the picker only, not `fileTreeView`/`gitPanelView` — those views already have drag-and-drop with a *different* meaning (copy a dropped file into the currently-browsed folder), and dropping a folder there would ambiguously trigger a deep copy instead of "add as workspace root." Reuses the existing `KouenTerminalSurfaceView.droppedFileURLs` pasteboard helper for consistency with that other drop handler.
- Refactored the resulting duplication (menu-pick / open-panel / drag-drop all needed the same "add then select" sequence) into shared `selectFileRoot(_:)`/`selectGitRoot(_:)` + `addRepoToWorkspaceAndSelectPath(_:)` helpers.
- Left `showActiveWorkspaceActions`'s menu item in place (harmless, matches the codebase's own "dormant, re-enable later" pattern already established for `workspacePill`) rather than deleting it — it'll work automatically if that pill is ever wired up.

Regression tests added: `testRebuildRootPickerAppendsAddFolderItemLast` (structural — the NSOpenPanel modal flow itself isn't unit-testable). Full drag-and-drop path (real `NSDraggingInfo`) is also not practically unit-testable — verified manually only, same disclosed limitation as the open-panel flow.

## Third entry point: footer "+" button (2026-07-17)

User pointed at the always-visible footer "+" (`SidebarFooterView`, `FooterIconButton(symbol: "plus", tooltip: "New session")`) as a better anchor than a per-tab picker — it's definitely reachable (unlike the dormant `workspacePill`) and doesn't require first navigating to Files/Git. Confirmed its current action (`addSession()`) already opens an `NSOpenPanel` ("Choose a project folder") to create a new session — same shape as `promptAddFolderToWorkspace()`, just a different destination.

Converted it into a VSCode-style dropdown (`NewSessionMenuButton`, mirroring the existing `RecentProjectsMenuButton` pattern in the same file) with two items: "New Session…" (unchanged behavior) and "Add Folder to Workspace…" (new — reuses `promptAddFolderToWorkspace()`, selects the result on both Files and Git pickers so it's visible whichever tab the user switches to next). `SidebarFooterView` gained an `onAddRepoToWorkspace` closure parameter; single call site in `KouenSidebarPanelViewController.setupFooterView()` already updated, no other call sites exist.

There are now 3 ways to add a repo: footer "+" menu (primary, most discoverable), the picker's own trailing menu item, and drag-and-drop onto either picker — all funnel through the same `promptAddFolderToWorkspace()`/`addRepoToWorkspaceAndSelectPath()` helpers, no logic duplication.

**One more real bug found + fixed:** clicking "Add Folder to Workspace…" while on the Sessions tab produced zero visible feedback (Files/Git panes are hidden there, and that's the only place any effect showed) — read by the user as "nothing happened," even though the add itself worked. Added a `Toast.show(...)` confirmation in the shared `addRepoToWorkspaceAndSelectPath()` path so every entry point (footer menu, picker menu, drag-and-drop) confirms regardless of which tab is active.

**Confirmed working end-to-end by the user (2026-07-17, live `make preview` test):** clicked footer "+" → "Add Folder to Workspace…" → picked a folder → switched to Files tab → picker correctly showed the added folder's name instead of "Active Session." Core feature verified live, not just via automated tests.

## Polish: dynamic "Active Session" label (2026-07-17)

User asked whether the picker's first item shows the real active project/branch or just a static string — it was static (`"Active Session"`, hardcoded), unlike every other entry (which shows the real folder name). Made it dynamic: `activeSessionPickerLabel()` mirrors `WindowTitleStripView.setPath`'s existing `"name  (⎇ branch)"` format for consistency with the rest of the app, falling back to the literal "Active Session" only when there's no active tab/cwd at all. Regression test: `testRebuildRootPickerUsesCustomActiveLabelWhenProvided` (7/7 in the file pass).

## Fourth real bug, surfaced by the label becoming honest (2026-07-17)

The dynamic label immediately exposed a pre-existing bug: the Files tab was browsing `.git`'s own internals (hooks/objects/refs/config) instead of the project. Reproduced empirically (throwaway repo, not guessed): `git rev-parse --show-toplevel` run from inside `.git` fails with exit 128 ("fatal: this operation must be run in a work tree"). `WorktreeManager().repoRoot(for:) ?? cwd`'s fallback then used that failing `.git` path unchanged — silently. This pattern was duplicated across **5 call sites** in this file (not something P43 introduced — it's the app's general cwd→repo-root resolution, just newly visible now that the label stopped hiding it behind generic text).

Fixed at the root (ponytail: fix the shared function once, not each caller): added `KouenSidebarPanelViewController.resolveRepoRoot(for:)` — tries the normal `git rev-parse` path first, and if that fails, climbs out of the first `.git` path component instead of using it as-is. All 5 call sites (`syncFileTreeToActiveSession`, `revealFileInTreeQuietly`, the inert `selectSidebarTab` switch, `reload()`, `refreshMetadata()`) now go through it. Regression tests (`ResolveRepoRootTests`, real temp git repos via `git init`, not mocked): climbs out of `.git` correctly, leaves a normal repo root unchanged, leaves a non-git path unchanged. 10/10 across both test files in this feature.

**Missed spot, caught by the user re-checking:** the file tree content was fixed, but the picker's *label* (`activeSessionPickerLabel()`) still showed ".git" — it computed `KouenDesign.pathDisplayName(tab.cwd)` from the **raw** cwd directly, never routed through `resolveRepoRoot(for:)` like the other 5 call sites. Same bug class, one more site of it. Fixed by resolving the root first, then deriving the display name from that. Not independently unit-tested (composes two already-tested pieces — `resolveRepoRoot` covered directly, `pathDisplayName` pre-existing — and full isolation would need mocking the `SessionCoordinator.shared` singleton, disproportionate for a one-line glue fix); verified via live `make preview` re-check instead.

## Infrastructure / Data Storage

- [x] **Task 1 — `Workspace.extraRepoRoots` field + IPC request contract** ✅ 2026-07-17
  `Packages/KouenIPC/Sources/KouenIPC/Workspace.swift`: added `extraRepoRoots: [String] = []`, threaded through `init`, `CodingKeys`, custom `init(from:)` (backward-compat `decodeIfPresent(...) ?? []`), `encode(to:)`.
  `Packages/KouenIPC/Sources/KouenIPC/IPCMessage.swift`: added `.addWorkspaceRepoRoot(workspaceID: UUID, path: String)` / `.removeWorkspaceRepoRoot(workspaceID: UUID, path: String)` request cases. No `ipcProtocolVersion` bump — matches the codebase's own precedent that ordinary additive cases (most of them) don't bump it, only ones needing a forced daemon restart do.
  - [x] ✅ Run test scripts (verify GREEN) — `SessionEditorTests.swift`: `testOldSnapshotWithoutExtraRepoRootsKeyDecodesAsEmpty`, `testExtraRepoRootsRoundTripsThroughEncodeDecode`. 24/24 in the file pass, no regressions.

## Server Logic

- [x] **Task 2 — Daemon handling: `SurfaceRegistry` mutates `Workspace.extraRepoRoots`** ✅ 2026-07-17 — *blocked by Task 1*
  `Packages/KouenCore/Sources/KouenCore/Session/SessionEditor.swift`: pure mutators `addRepoRoot(_:path:)` (de-dupes, silent no-op on repeat) / `removeRepoRoot(_:path:)`, mirroring `renameWorkspace`'s shape exactly.
  `Packages/KouenDaemon/Sources/KouenDaemon/SurfaceRegistry.swift`: handles the two new request cases — filesystem validation (real directory via `FileManager`, `~` expansion) lives here at the trust boundary, not in the pure `SessionEditor` mutator. Calls `commit()` same as every other mutation (existing persist+broadcast path, no new plumbing).
  - [x] ✅ Run test scripts (verify GREEN) — `SessionEditorTests.swift`: `testAddRepoRootAppendsAndDedupes`, `testAddRepoRootUnknownWorkspaceFails`, `testRemoveRepoRootRemovesAndFailsWhenAbsent`. Full package `swift build` clean.

- [x] **Task 3 — App-side facade wrappers** ✅ 2026-07-17
  `Apps/Kouen/Sources/KouenApp/Services/SessionCoordinator.swift`: `addRepoToWorkspace(id:path:)` / `removeRepoFromWorkspace(id:path:)`, mirroring `renameWorkspace(id:name:)`'s exact shape (explicit workspace id, matching how `renameWorkspace` itself works — not an implicit "active workspace").
  - [x] ✅ Run test scripts (verify GREEN) — `swift build --product Kouen` clean.

## Client Application

- [x] **Task 4 — "Add Folder to Workspace…" menu + folder picker** ✅ 2026-07-17
  Added menu item to `showActiveWorkspaceActions` (`KouenSidebarPanelViewController.swift:843`) → `NSOpenPanel` (directories only) → `SessionCoordinator.shared.addRepoToWorkspace(id:path:)`.
  - [x] ✅ Run test scripts (verify GREEN) — `swift build --product Kouen` clean.

- [x] **Task 5 — Files/Git tab root picker + no-yank-back guard** ✅ 2026-07-17
  `KouenSidebarPanelViewController.swift`: `fileRootPicker`/`gitRootPicker` (`NSPopUpButton`, flat list — "Active Session" + one entry per `extraRepoRoots`) inserted above the Files/Git pane content (pushed content down via constraint retarget, no layout surgery needed). `refreshRootPickers()`/`rebuildRootPicker()` treat the override fields as the source of truth (rebuild the menu to match them, not the reverse) — found and fixed a real bug during testing: an earlier version derived the override from the picker's own post-rebuild selection, which silently desynced when the override's path wasn't in the rebuilt menu at all. `reload()`/`refreshMetadata()` now guard their unconditional root-follow behind `selectedFileRootOverride == nil` / `selectedGitRootOverride == nil`.
  - [x] ✅ Run test scripts (verify GREEN) — `RootPickerOverrideGuardTests.swift` (3 tests: override blocks cwd-follow on `reload()`/`refreshMetadata()`, dangling override cleared when its root is no longer in the workspace) + `SurfaceRegistryTests.swift` (3 tests: real-directory accept + revision bump, non-directory reject, remove). Broader regression pass: 68 sidebar/git/file-tree tests + 35 `SurfaceRegistryTests` (3 unrelated live-daemon-only skips) — 0 failures.

## Integration

- [x] **Task 6 — Robot suite + code review gate** ✅ 2026-07-17 (automated parts)
  `Tests/robot/run.sh`: 27/27 pass. Full `swift build`: clean. Broad regression sweep: `KouenDaemonTests` 217/217 (57 unrelated live-daemon-only skips), `KouenCoreTests` 641/646 (5 pre-existing failures — confirmed via `git stash -u` comparison to identically fail on the clean codebase: `ExperienceModeTests`, `Phase6KeysTests`, `ReleaseNotesGuardTests`, none touched by this diff), `KouenAppTests` sidebar/git/file-tree sweep 50/50.

  **`review-personas` code-reviewer pass — 3 findings, all fixed, not just reported:**
  1. **(Important, fixed)** `rebuildRootPicker` matched picker selection by display title (last path component), not full path — two `extraRepoRoots` sharing a folder name (e.g. two repos both named "backend") would silently select the wrong one. Fixed to match `NSMenuItem.representedObject` (the full path). Regression test: `testPickerSelectsByFullPathNotByCollidingTitle`.
  2. **(Important, fixed)** `refreshRootPickers()` cleared a dangling override (root removed, or workspace switched) but never re-synced `fileTreeView`/`gitPanelView` content — the exact stale-display bug class (`cwd-worktree-bleed.md`) this task's guard was built to prevent, just relocated to the auto-clear path instead of the normal-tick path. Extracted `syncFileTreeToActiveSession()`/`syncGitPanelToActiveSession()` (shared by the picker's own manual-clear handlers and the auto-clear path) so both paths re-sync content, not just the picker's visual selection.
  3. **(Important, fixed)** No UI existed to remove an added repo — `removeRepoFromWorkspace` was fully wired end-to-end but nothing called it. Added "Remove '<name>' from Workspace" items to the workspace actions menu (one per `extraRepoRoots` entry), mirroring the existing rename/delete pattern.

  - [x] ✅ Run all test scripts (verify GREEN) — `RootPickerOverrideGuardTests` now 4 tests (added the title-collision regression), all green alongside the full sweep above.
  - [x] Code review — all Important findings fixed, re-verified green, not just reported.

  **Not yet done — needs the user, not automatable:** manual click-through in `make preview` (add a second repo folder, switch Files/Git pickers, confirm no yank-back through real snapshot ticks and a real workspace switch, confirm the added repo survives an app restart). Screenshot-based self-verification was attempted and abandoned this session after accidentally capturing unrelated screen content (Microsoft Teams) — see conversation; will not retry without a safer capture method.
