# P40 — MCP Surface Expansion (Tasks/Worktrees/Hosts) + Shader Presets

Requirements captured via `/interview` (2026-07-11), following the competitive research
in `agent-memory/knowledge/meta/competitive-position.md`. Domain terms recorded in
`LANGUAGE.md` (project root, first version of this file). Scope confirmed by user:
Automations explicitly dropped (thin use case, revisit later if real demand appears).

## Strategic Design

Single bounded context — Kouen is a monolith (one Swift app + daemon + CLI + MCP
server sharing `KouenCore`), not a multi-service system. No new bounded context needed;
this is 4 additions within existing module boundaries:

| Feature | Owning module(s) |
|---|---|
| Tasks + Dashboard | New `Packages/KouenCore/Sources/KouenCore/Tasks/` (store) + `Packages/KouenDaemon/` (IPC handler) + `Tools/kouen-mcp/` (MCP tools) + `Apps/Kouen/` (dashboard UI) |
| Worktree (MCP resource) | `Tools/kouen-mcp/` only — wraps existing `Packages/KouenCore/Sources/KouenCore/Worktree/WorktreeManager.swift`, no new storage |
| Hosts (MCP resource) | `Tools/kouen-mcp/` only — wraps existing `Packages/KouenCore/Sources/KouenCore/Remote/RemoteHostStore.swift`, read-only |
| Shader Presets | `Packages/KouenTerminalRenderer/` (new preset pipeline) + `Apps/Kouen/` (Settings toggle) |

**Architecture pattern**: monolith, module-boundary extension. No new services, no new
IPC transport — everything rides the existing daemon control-channel (JSON, 4-byte
length-prefixed) and existing `ToolRegistry.swift` MCP dispatch. Tradeoff: simplicity
and consistency with 27 existing tools vs. no isolation between Task-store bugs and the
rest of the daemon process — acceptable, matches how `PasteBufferStore`/`SessionStore`
already work in-process today.

## Tactical Design

### Task (new aggregate root)
```
Task {
  id: UUID
  sessionID: SessionID        // owning session — required, not optional
  title: String
  done: Bool
  createdAt: Date
  updatedAt: Date
}
```
- **Aggregate boundary**: a session "owns" its Tasks. No cross-session Task references,
  no global Task list independent of a session (per user's explicit choice over
  Superset's global-object model).
- **Lifecycle resolution** (interview left this open): **Tasks survive session close,
  archived not deleted.** Rationale: a closed session/pane is routine (user closes a
  tab constantly); silently deleting checklist items on tab-close would be surprising
  and destructive per `coding.md`'s input-validation/data-loss principles. Store keeps
  a `sessionID` reference that may point to a now-closed session — the Dashboard shows
  archived Tasks under "closed sessions" grouping, same pattern GitPanelView already
  uses for stale-worktree display. No explicit user-facing delete-Task-on-session-close
  action exists; user can manually delete a Task if they want it gone.
- **Domain event**: none needed — Tasks are simple CRUD state, not a process with
  meaningful state-transition side effects (unlike, say, `AgentDetector`'s state
  machine). No event bus involvement.

### Worktree (MCP resource) — no new aggregate
Wraps existing `WorktreeManager.WorktreeInfo` (path, branch, head, bare) and
`WorktreeManager.create()/remove()/list` (list via `parseWorktreeList()`, confirmed at
`WorktreeManager.swift:163`). MCP tools operate directly against `WorktreeManager`
through the daemon — no new persistent state, no new aggregate.

### Host (MCP resource) — no new aggregate
Wraps existing `RemoteHost` (`RemoteHostStore.swift:9`, already `Codable`/`Sendable`/
`Equatable`/`Identifiable`). MCP tool is a thin read path over `RemoteHostStore.load()`.
No new aggregate; deliberately no MCP write path (create/edit stays Settings-UI-only —
recorded in LANGUAGE.md's Host relationship note).

### ShaderPreset (new value object, not an aggregate — no independent lifecycle)
```
ShaderPreset: String, CaseIterable {
  case none, crt, scanline, bloom
}
```
Stored as a single `OptionStore` key (existing pattern — see
`Packages/KouenCore/Sources/KouenCore/Options/OptionStore.swift`), not a new store.
Pure UI/rendering preference, not a domain entity with identity.

## Logical Design

### 1. Tasks — storage + MCP + IPC contracts

**Storage** (`Packages/KouenCore/Sources/KouenCore/Tasks/TaskStore.swift`, follows
`PasteBufferStore` pattern exactly — file-lock + atomic JSON write, in-memory cache,
`@unchecked Sendable`):
```swift
public struct KouenTask: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var sessionID: String   // SessionID is a String-backed type; store as raw string to avoid a KouenCore<->daemon type coupling
    public var title: String
    public var done: Bool
    public let createdAt: Date
    public var updatedAt: Date
}

public final class TaskStore: @unchecked Sendable {
    public func list(sessionID: String? = nil) -> [KouenTask]   // nil = all sessions, for the Dashboard
    public func get(id: UUID) -> KouenTask?
    public func create(sessionID: String, title: String) -> KouenTask
    public func update(id: UUID, title: String?, done: Bool?) -> KouenTask?
    public func delete(id: UUID) -> Bool
}
```
File: `~/Library/Application Support/Kouen/tasks.json` (matches `PasteBufferStore`'s
`Application Support` convention).

**IPC** (`Packages/KouenIPC/Sources/KouenIPC/IPCMessage.swift`): new request cases
`taskList(sessionID: String?)`, `taskGet(id: UUID)`, `taskCreate(sessionID: String,
title: String)`, `taskUpdate(id: UUID, title: String?, done: Bool?)`, `taskDelete(id:
UUID)`; response case `taskInfo(KouenTask?)` / `taskList([KouenTask])`. Handled in
`SurfaceRegistry.handle()` (`Packages/KouenDaemon/Sources/KouenDaemon/SurfaceRegistry.swift:279`),
delegating to a `TaskStore` instance owned by the daemon process — same ownership
pattern as existing stores.

**MCP tools** (`Tools/kouen-mcp/Sources/KouenMCP/ToolRegistry.swift`, camelCase
`kouen`-prefixed, matching `kouenBoard`/`kouenGrep` convention — not Superset's
snake_case):
- `kouenTaskList(sessionID?: string)` → list, omit `sessionID` for all-sessions
- `kouenTaskCreate(sessionID: string, title: string)` → create
- `kouenTaskUpdate(id: string, title?: string, done?: boolean)` → update
- `kouenTaskDelete(id: string)` → delete

**Dashboard UI** (`Apps/Kouen/Sources/KouenApp/UI/Tasks/TaskDashboardView.swift`, new):
grouped list, "Active sessions" / "Closed sessions" sections, checkbox toggles `done`,
inline title edit. Entry point: new sidebar footer icon (same row as the existing
Agents/sparkles button from P38 Phase D) or a `⌘⇧T` shortcut — **left as an open
question for task-design**, not resolved here (UI entry point is a small decision,
doesn't block the data-layer design).

### 2. Worktree (MCP resource) — MCP contracts only

New tools in `ToolRegistry.swift`, delegating to `WorktreeManager` via a new IPC round
trip (`worktreeList(repoPath: String)`, `worktreeCreate(repoPath, sessionID, branch?,
baseRef?)`, `worktreeRemove(repoPath, worktreePath, force?)` — mirrors
`WorktreeManager`'s existing Swift signatures 1:1, no new domain logic):
- `kouenWorktreeList(repoPath: string)` → `WorktreeInfo[]` (path, branch, head, bare)
- `kouenWorktreeCreate(repoPath: string, sessionID: string, branch?: string, baseRef?: string)` → path or error
- `kouenWorktreeRemove(repoPath: string, worktreePath: string, force?: boolean)` → bool

`force: true` requires explicit opt-in per call (no default-true) — matches the
existing `WorktreeManager.remove(force:)` signature and Kouen's general pattern of
never silently discarding uncommitted work (`core.md`'s git-safety principle applies
here even though this is app code, not agent-harness code).

### 3. Hosts (MCP resource) — one read-only tool

- `kouenHostList()` → `RemoteHost[]` minus any secret-bearing fields. **Check before
  implementing**: confirm `RemoteHost`'s fields (`name`, `sshTarget`,
  `remoteSocketPath`, `sshArgs`) contain no embedded credentials — `sshArgs` could
  theoretically carry a `-i /path/to/key` identity-file flag (a path, not a secret
  itself, but worth a explicit allowlist-of-fields-to-expose decision at
  implementation time rather than serializing the whole struct blindly).

No create/update/delete tool — reinforces the Settings-UI-only boundary from
LANGUAGE.md.

### 4. Shader Presets — rendering pipeline change

**Injection point** (resolved, was the open question from interview): `render(_:to:
target: MTLTexture, ...)` (`TerminalMetalRenderer.swift:421`) already renders into an
arbitrary `MTLTexture`, not just a drawable — this is the existing offscreen-capture
path. Reuse it:

1. When a preset is active, `present(_:to: drawable, ...)` first calls the existing
   `render()` into a **new intermediate offscreen `MTLTexture`** (allocated once per
   surface size, cached — same lifecycle as existing per-surface Metal resources, not
   per-frame) instead of encoding directly to the drawable.
2. A new, second, lightweight full-screen-quad pipeline (`makePresetPipeline()`,
   mirrors `makePipeline()`) samples that intermediate texture in its fragment shader,
   applies the preset effect (scanline: alternating-row darken; CRT: adds scanline +
   vignette; bloom: simple threshold+blur-sample), and writes to the drawable.
3. **Zero cost when `preset == .none`** (the default): `present()` takes its current
   direct-to-drawable path unchanged, no intermediate texture allocated, no extra draw
   call. This preserves the performance-critical instance-cache path
   (`RowInstanceCache`/`UploadedInstanceBuffers`) exactly as-is — the preset pass reads
   already-rendered pixels, it doesn't touch glyph/background instance encoding at all.

**New file**: `Packages/KouenTerminalRenderer/Sources/KouenTerminalRenderer/ShaderPresets.swift`
(preset enum + the 3 new fragment shader functions, added to `MetalShaders.swift`'s
existing `.metal` source string or a new adjacent shader file — check
`MetalShaders.swift`'s structure at implementation time to match its existing
single-file-vs-multi-file convention).

**Settings**: new `Toggle`-style picker in whichever `SettingsXxxView.swift` currently
holds theme/appearance settings (find via `graphify query "settings appearance theme
view"` at implementation time — not yet located this session), backed by
`OptionStore` (existing pattern, one new key `shaderPreset: String`).

**Explicitly out of scope** (per user's choice): no user-authored shader code, no
shader file import, no arbitrary MSL compilation at runtime — closes the security
surface that would otherwise come with letting user-supplied GPU code run.

## Open items for task-design to resolve (not blocking, just unresolved here)
- Task Dashboard UI entry point (sidebar icon vs. shortcut vs. both)
- Exact scanline/CRT/bloom shader math (visual tuning, not architecture)
- `RemoteHost` field allowlist for `kouenHostList` serialization
