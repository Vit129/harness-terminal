# P43 — Add Repo/Folder to Workspace

Source: follow-up to P42 (`agent-memory/plans/p42-workspace-sidebar-panels/design.md`), which shipped and reverted an always-visible stacked-panes sidebar (unusable in a narrow sidebar per real `make preview` testing). Real-usage feedback clarified the actual ask: keep today's exclusive tab-switching (Sessions/Files/Git), add an **"Add to Workspace"** action that merges another repo/folder's Files+Git into the current Workspace — cmux/tmux-flavored (simple picker/switcher), not a VSCode multi-root explorer tree.

## Strategic Design

**Bounded context:** still the `KouenApp` Sidebar module, same as P42 — no new service. Unlike P42, this change is **not UI-only**: it needs a new field on the `Workspace` domain type that persists across app restarts and syncs through the daemon, so it touches `KouenIPC` (shared model + IPC message contract) and `KouenDaemon` (`SurfaceRegistry`, the authoritative owner of `Workspace` state) in addition to `KouenApp`.

**Current state, confirmed by reading the code:**
- `Workspace` (`Packages/KouenIPC/Sources/KouenIPC/Workspace.swift`): `id`, `name`, `sessions: [SessionGroup]`, `activeSessionID`, `sortOrder` — `Codable`, with a custom `init(from:)` that already handles backward-compatible decode of newer fields via `decodeIfPresent(...) ?? default` (a precedent to follow for the new field).
- `SessionSnapshot` (`Packages/KouenIPC/Sources/KouenIPC/SessionSnapshot.swift`): `version`, `revision`, `workspaces: [Workspace]`, `activeWorkspaceID`, `themeName`, `keepSessionsOnQuit`, `savedAt` — this whole struct is what `SessionStore` (`Packages/KouenCore/Sources/KouenCore/Persistence/SessionStore.swift`) saves/loads as JSON on disk, and what the daemon (`SurfaceRegistry`, the in-memory authoritative owner) broadcasts to GUI clients over IPC. **Adding a field to `Workspace` rides along on this existing full-snapshot persistence/sync mechanism — no new persistence file or sync channel needed.**
- `SurfaceRegistry` (daemon) is authoritative for `Workspace` mutation. The GUI never mutates `Workspace` directly — it sends an `IPCRequest` (existing precedent: `.renameWorkspace(workspaceID:name:)`, `.closeWorkspace(id:)`, `.selectWorkspace(id:)` in `IPCMessage.swift`), the daemon mutates its in-memory `SurfaceRegistry` state and persists via `SessionStore`, then broadcasts the updated snapshot back. **New workspace mutations (add/remove a repo root) must follow this same request → daemon-mutate → broadcast shape**, not a GUI-local mutation.
- Files tab (`WorkspaceFileTreeView`/`FileTreeContext.rootPath: String`) and Git tab (`GitPanelView.updateRoot(path:)`) both show a single root, always following the active session/tab's `cwd` — updated unconditionally on every snapshot change via `reload()`/`refreshMetadata()` in `KouenSidebarPanelViewController.swift`. This is the behavior that stays the default; the new picker (below) is an additional, explicit override on top of it.
- Workspace actions today live behind the workspace pill's "more" button → `showActiveWorkspaceActions(from:)` (menu with rename/delete-style actions) — the natural existing home for a new "Add Folder to Workspace…" menu item.

## Tactical Design

**Domain model change — new field on `Workspace`:**
```swift
public var extraRepoRoots: [String] = []   // ordered list of explicitly-added folder paths
```
- Decoded the same backward-compatible way as `sortOrder`/`activeSessionID`: `decodeIfPresent([String].self, forKey: .extraRepoRoots) ?? []` — an old saved snapshot with no such field loads fine as "no extra roots," no migration needed.
- **Not a new entity/aggregate** — `extraRepoRoots` is a value (ordered list of paths) owned by the `Workspace` aggregate, same lifecycle as its other fields. No separate `RepoRoot` type needed at this stage (a plain path string is enough for "which folder" — display name for the picker can be derived from the path's last component, same pattern `KouenDesign.pathDisplayName`/`shortenPath` already use elsewhere).

**Domain events (IPC requests) — new, mirroring the existing `renameWorkspace`/`closeWorkspace` shape:**
```swift
case addWorkspaceRepoRoot(workspaceID: UUID, path: String)
case removeWorkspaceRepoRoot(workspaceID: UUID, path: String)
```
- Daemon (`SurfaceRegistry.handle(...)`) appends/removes the path in the target `Workspace.extraRepoRoots`, bumps `revision` (existing pattern per `SurfaceRegistryTests.testNewWorkspaceTabAndSelectMutateSnapshotAndBumpRevision`), persists via `SessionStore`, broadcasts snapshot.
- **Validation belongs at the daemon boundary** (trust boundary — a path typed/picked by the user is external input): reject/normalize a path that isn't a directory, expand `~`, and de-dupe against existing `extraRepoRoots` (adding the same folder twice is a no-op, not an error).

**Root selection state — where does "which root is currently shown" live?** This is UI-only (same reasoning as P42's original tab-memory idea) — not persisted, not synced. A simple `@Published`/`@Observable` "selected root" per Files-tab-instance and per Git-tab-instance, defaulting to "active session" (today's behavior), switchable to any of `extraRepoRoots` via the new picker. Lives in `KouenSidebarPanelViewController`, not in the `Workspace` model.

## Logical Design

**Changed files:**
1. `Packages/KouenIPC/Sources/KouenIPC/Workspace.swift`
   - Add `extraRepoRoots: [String] = []`, threaded through `init`, `CodingKeys`, custom `init(from:)` (backward-compat decode), and `encode(to:)`.
2. `Packages/KouenIPC/Sources/KouenIPC/IPCMessage.swift`
   - Add `.addWorkspaceRepoRoot(workspaceID: UUID, path: String)` / `.removeWorkspaceRepoRoot(workspaceID: UUID, path: String)` request cases, alongside the existing `.renameWorkspace`/`.closeWorkspace`.
3. `Packages/KouenDaemon/Sources/KouenDaemon/SurfaceRegistry.swift`
   - Handle the two new request cases: mutate the target `Workspace.extraRepoRoots` (validate path is a real directory, expand `~`, de-dupe), bump `revision`, trigger `SessionStore` persistence (existing save path), broadcast snapshot (existing broadcast path).
4. `Apps/Kouen/Sources/KouenApp/Services/SessionCoordinator.swift` (+ its `SessionLifecycleService` facade, matching `selectWorkspace`/`renameWorkspace`'s existing thin-wrapper pattern)
   - `addRepoToActiveWorkspace(path: String)` / `removeRepoFromActiveWorkspace(path: String)` — thin wrappers sending the new `IPCRequest`s.
5. `Apps/Kouen/Sources/KouenApp/UI/Sidebar/KouenSidebarPanelViewController+RecentProjects.swift` (or wherever `showActiveWorkspaceActions` builds its menu)
   - Add "Add Folder to Workspace…" menu item → `NSOpenPanel` (directories only, matching whatever picker style `Self.recordRecentProject`-adjacent flows already use for folder selection) → `SessionCoordinator.shared.addRepoToActiveWorkspace(path:)`.
6. `Apps/Kouen/Sources/KouenApp/UI/Sidebar/KouenSidebarPanelViewController.swift`
   - Files pane and Git pane each get a small root picker (a plain `NSPopUpButton` or segmented control above the existing content, cmux/tmux-flavored — a flat list, not a tree) populated from `["Active Session"] + workspace.extraRepoRoots.map(displayName)`. Selecting an entry calls `fileTreeView.updateRoot(path:sessionID:)`/`gitPanelView.updateRoot(path:)` directly with the chosen path (bypassing the active-session-cwd default until switched back).
   - `reload()`/`refreshMetadata()`'s unconditional root-follow needs a guard: only auto-follow the active session's cwd when the picker is on "Active Session" — if the user has explicitly picked an extra root, don't yank it back on the next snapshot tick.

**No new persistence file, no new sync channel** — rides on the existing `SessionSnapshot` → `SessionStore` (disk) and `SurfaceRegistry` → IPC broadcast (GUI sync) paths already in place for every other `Workspace` field.

**Test (ponytail: non-trivial logic gets checks):**
1. `SurfaceRegistryTests` — `addWorkspaceRepoRoot`/`removeWorkspaceRepoRoot` mutate the right workspace, bump revision, de-dupe on repeat-add, reject a non-directory path.
2. `KouenIPCTests` (or wherever `Workspace` decode tests live) — an old-format saved snapshot (no `extraRepoRoots` key) decodes with `extraRepoRoots == []`, not a decode failure.
3. `KouenAppTests` — the Files/Git root picker's "don't yank back to active session while an extra root is explicitly selected" guard, mirroring the exact bug shape `focus-persistence.md`'s RL-043 already documented once (GUI-side state not reset/respected across snapshot syncs).

**Rollout risk:** low-medium. Additive at every layer (new optional field, new request cases, new menu item, new picker) — nothing existing is removed or restructured, unlike P42. The one behavior change is the `reload()`/`refreshMetadata()` guard (must not silently override an explicit user pick), which is a small, testable, single-purpose change.

## Next Step

`references/task-design.md` (Dev section) — this design spans daemon + IPC + app layers, so task sequencing should follow Infrastructure(daemon/IPC) → Client Application(picker UI) → Integration, not client-only like P42.
