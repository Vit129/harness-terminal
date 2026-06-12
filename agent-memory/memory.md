# Memory — Harness Terminal

## Active Context
- **Project:** harness-terminal (Swift/AppKit macOS terminal emulator)
- **Fork:** Vit129/harness-terminal (fork of robzilla1738/harness-terminal)
- **Working branch:** `main`
- **Preview:** `make preview` (uses `.harness-preview/` dir)
- **Latest release:** v2.5.0 (commits 55c7bff + 6cd143d — terminal power-user sprint: vi mode, tmux parity, LSP, keyboard file tree)

## Current Sprint — Post-v2.1.0 Polish & Shelving

### Task_Ledger

| # | Task | Status |
|---|------|--------|
| 1 | ACP Client shelved (adapters not ready) | ✅ Done |
| 2 | Session ID shown in sidebar cards | ✅ Done |
| 3 | Tab reorder fix (sortOrder persistence) | ✅ Done |
| 4 | Session grouping by CWD (adjacent insert) | ✅ Done |
| 5 | Agent sidebar tab hidden | ✅ Done |
| 6 | SurfaceShellTracker (daemon process tree scan) | ✅ Done |
| 7 | GitPanelView: Worktrees tab | ✅ Done |
| 8 | P2-async IPC (DaemonClientActor, SessionCoordinator) | ✅ Done |
| 9 | CWD tracking via daemon proc_pidinfo polling | ✅ Done |
| 10 | Git History diff coloring + file navigation | ✅ Done |
| 11 | macOS 26 Swift 6 crash fixes (MainActor isolation) | ✅ Done |
| 12 | File tree performance (remove polling, reconcile in-place) | ✅ Done |
| 13 | Preview/production session isolation | ✅ Done |
| 14 | File preview: no-reparent constraint split (40/60) | ✅ Done |
| 15 | File preview: brighter syntax colors + chrome bg | ✅ Done |
| 16 | Sidebar session card: icon scans all tabs + title always tracks live folder (matches tab bar) | ✅ Done |
| 17 | P6 — File editor opacity parity with terminal (compensated refreshEditorPanelFill) | ✅ Done |
| 18 | File tree FSEvents recursive watcher (CASE-016) | ✅ Done |
| 19 | Folder expand state persist in @Observable model (CASE-017) | ✅ Done |
| 20 | File preview drag-to-select text (CASE-018) | ✅ Done |
| 21 | Terminal selection highlight visible (CASE-019) | ✅ Done |
| 22 | Branch chip real-time via git rev-parse in loadRoot() (CASE-020) | ✅ Done |
| 23 | Git Changes FSEvents recursive watcher on rootPath (CASE-021) | ✅ Done |
| 24 | File preview live reload via single-file DispatchSource watcher (CASE-022) | ✅ Done |
| 25 | Sidebar collapse-then-expand fix: sync sidebarVisible on forced launch collapse (CASE-024) | ✅ Done |
| 26 | Terminal rendering corruption fix: don't clear synchronizedOutput on shell-prompt reset (CASE-023) | ✅ Done |
| 27 | v2.2.4 release prep: CHANGELOG Fixed entries, version bump (build 125), release notes regen, graphify refresh, tag | ✅ Done |
| 28 | P9 complexity reduction: extract LiveResizeGeometry, PasteController, SelectionResolver from SurfaceView; document GridCompositor duplication; plan macOS 27 adoption (P8) | ✅ Done |
| 29 | Terminal blink fix when file preview split opens/closes (CASE-025) | ✅ Done |
| 30 | P10 features: Local Completion, IDE Mode (⌘+⇧+D), Session State Dot, diff coloring, git panel improvements, IDE mode persistence | ✅ Done |
| 31 | CASE-026 black terminal on new session — display link race fix | ✅ Done |
| 32 | Lazy scrollback reflow (skip O(history) during live resize), Task Board sidebar, Focus Mode (⌘P) | ✅ Done |
| 30 | P10 implementation: Sidebar session state dots, Toggle IDE Mode shortcut (⌘⇧D), and Workspace Symbol Index autocomplete completions popup | ✅ Done |
| 33 | Implement Ctrl+R-style fuzzy command-history search overlay | ✅ Done |
| 34 | Fix Focus Mode (⌘P) out-of-sync sidebar state when manual visibility toggles occur | ✅ Done |
| 35 | Terminal power-user sprint: vi mode (ViNormalMode.swift), tmux parity (clear-history, word-separators, wrap-search, resize-window, list-* -F/--json, window-size, destroy-unattached, show-prompt-history, find-window -C from hooks), LSP activation, ⌘1-9 session switch, zoxide in Switch Project | ✅ Done |
| 36 | Keyboard file tree navigation (j/k/h/l/Enter, FileTreeKeyboardNav.swift) | ✅ Done |
| 37 | Vi ex command mode (:w/:q/:wq/:set/:e/:bn/:bp/:ls), jump list (Ctrl+o/i), backtick marks, named registers, macros, inline * search, relative numbers | ✅ Done |
| 38 | tmux deferred list closed: window-size option (smallest/largest/latest), list-* --json, find-window -C from hooks, destroy-unattached | ✅ Done |


### Recent_Lessons

- **RL-001:** ACP requires adapter binaries; can't ship reliably in .app bundle (PATH issues)
- **RL-002:** Shell tracker can't read env vars from /bin/zsh (macOS hardened runtime blocks KERN_PROCARGS2). CWD tracking relies on daemon-side proc_pidinfo polling only.
- **RL-003:** sortOrder must persist to UserDefaults on every drag, not just on quit
- **RL-004:** Never reparent Metal terminal surfaces for file preview split — causes 1-2s black screen (CASE-003). Use constraint-based sibling panel instead.
- **RL-005:** DispatchSource on .main queue directly (not .global with async hop) for Swift 6 MainActor isolation.
- **RL-006:** AppKit panels alongside Metal surfaces must apply opacity explicitly to their CALayer, but file editor/preview panels need a denser compensated alpha (`opacity + (1 - opacity) * 0.55`) rather than raw opacity. Metal handles terminal canvas alpha and terminal programs may paint opaque cell backgrounds, while preview text sits over mostly transparent AppKit canvas; raw parity can look too transparent. Hook into `applyChrome()` + panel-creation site. (CASE-011)
- **RL-007:** DispatchSource.makeFileSystemObjectSource on a directory is non-recursive — only detects root-level changes. Use FSEventStreamCreate with kFSEventStreamCreateFlagFileEvents for recursive watching. (CASE-016, CASE-021)
- **RL-008:** Swift actor + FSEvents C callback: use WatcherContext class (@unchecked Sendable) + Unmanaged.passRetained to pass onChange closure via FSEventStreamContext.info. Release in stopWatching via Unmanaged.fromOpaque().release(). (CASE-016)
- **RL-009:** SwiftUI @State in list rows resets on every view reconciliation. State that must survive tree refresh belongs in the @Observable model, not the View. (CASE-017)
- **RL-010:** NSView wrapping NSTextView must forward mouseDown/mouseDragged/mouseUp to the inner textView explicitly — super.mouseDown doesn't cascade to child views. (CASE-018)
- **RL-011:** For watching a single file (not a directory), plain `DispatchSource.makeFileSystemObjectSource(O_EVTONLY)` is sufficient — no need for FSEvents recursion (RL-007 only applies to directories). Re-arm by reopening the path on every reload to survive atomic-save-by-rename. For a reused `QLPreviewView`, call `refreshPreviewItem()` instead of re-setting an unchanged `previewItem` (QuickLook caches by URL). (CASE-022)
- **RL-012:** When a forced visual state on launch (e.g. collapse) diverges from the persisted toggle-state field, sync the persisted field too — otherwise the first user toggle computes against stale state and is a no-op. (CASE-024)
- **RL-013:** `TerminalModes.resetForShellPrompt()` (OSC 133;D) must only reset *input* modes (mouse tracking, bracketed paste, kitty keyboard, etc.), never `synchronizedOutput` — a sub-command's 133;D can fire mid-batch inside an outer TUI's `?2026h`/`?2026l` redraw, and clearing it there causes the renderer to present a half-applied frame (interleaved garbled rows). The 150ms sync-timeout in `HarnessTerminalSurfaceView` already handles a program that never sends `?2026l`. (CASE-023)
- **RL-014:** When extracting logic from large AppKit views: prefer standalone `enum` types with static methods for pure logic (geometry, validation, resolution). Keep the original method signature as a thin delegate — preserves the public API and test seams. Don't over-extract tightly-coupled state machines that would need large delegate protocols; those are better served by extension files.
- **RL-015:** Pure GUI-side states (like file editor tab lists and IDE mode visibility) should be persisted via `UserDefaults.standard` rather than modifying the shared daemon settings struct `HarnessSettings`, preventing binary compatibility issues.
- **RL-016:** On macOS/AppKit, to prevent click-gesture recognizers on parent stack views from intercepting clicks on child buttons, use `gestureRecognizer(_:shouldAttemptToRecognizeWith:)` of `NSGestureRecognizerDelegate` to selectively disable gesture recognition.
- **RL-017:** SwiftUI `List` in `NSHostingView` doesn't forward `keyDown` to the parent NSView. Add `acceptsFirstResponder = true` + `keyDown` override on the hosting NSView wrapper, then post notifications to SwiftUI rows via `NotificationCenter` for state changes (expand/collapse).
- **RL-018:** Modal vi engine inside `NSTextView`: set `isEditable = false` in normal mode and restore it only in insert mode. This prevents AppKit from consuming keystrokes meant for the vi engine. Use a `@MainActor final class` engine that holds `weak var textView: NSTextView?` and dispatches all mutations via `tv.isEditable = true; tv.replaceCharacters(...); tv.isEditable = false`.
- **RL-019:** `SyntaxLineNumberGutterView.draw()` receives a locally-unwrapped non-optional `textView` (from `guard let textView, ...`) — inside the draw closure `textView` is `NSTextView`, not `NSTextView?`. Conditional binding `if let tv2 = textView` inside that closure will fail to compile because it's already non-optional.
- **RL-020:** `window-size` vote aggregation: DaemonServer tracks per-client surface sizes; `applyEffectiveSize` picks the winning vote. Reading `registry.optionStore.get("window-size")` inside DaemonServer is correct since `optionStore` is `public let` on SurfaceRegistry.

### Decisions_In_Force

- **ACP shelved** — re-enable when adapters ship with agent CLIs natively
- **Agent tab hidden** — 4th sidebar segment commented out, code preserved
- **CWD tracking** — daemon polls proc_pidinfo every 500ms (lightweight); no shell integration needed
- **File preview** — constraint-based sibling panel (never reparent terminal views)
- **vi mode** — `ViNormalMode.swift` is a self-contained engine (`@MainActor final class ViEngine`); `SyntaxTextView` owns the instance and wires callbacks. Notifications used for cross-layer actions (:q → `viQuitCommand`, :e → `viOpenFileCommand`, :bn/:bp → `viNextBufferCommand`).
- **⌘1–9** — switches workspaces (sidebar sessions), not tabs within a workspace
- **Keyboard file tree** — `FileTreeKeyboardNav.swift` holds `FileTreeKeyboardState` (@Observable); AppKit (`WorkspaceFileTreeView.keyDown`) writes, SwiftUI (`NodeRow`) reads for highlight; `updateVisiblePaths()` keeps flat ordered list in sync

## Known Issues
- **Split right 4+ panes slightly uneven** — NSSplitView default resize compresses middle panes. Tolerable.
- **CWD detection latency** — up to 500ms after `cd` for sidebar to update (daemon poll interval). Acceptable.

## Completed Sprints
- **v1.3.0** — IDE-like Sidebar (PBI-001): Files tab, Git tab, session tabs, recent projects
- **v1.4.0** — Git panel: Commit ▼ menu, Sync button with per-remote options
- **v1.5.0** — CMUX split panes, N-ary flatten, host reuse, split down removed
- **v2.0.0** — File preview, sidebar polish, agent icon art
- **v2.1.0** — ACP Client, real-time Git, history→file editor

## Architecture Notes
- Sidebar: `HarnessSidebarPanelViewController` — tabs (Sessions/Files/Git) via NSSegmentedControl (Agent tab hidden)
- Sidebar position: `MainSplitViewController.updateSidebarPlacement()` — reorders NSSplitView subviews
- File tree: `WorkspaceFileTreeView` → `FileTreeSwiftUIView` (SwiftUI) with `FileTreeWatcher` (FSEvents); keyboard nav via `FileTreeKeyboardNavigator` + `FileTreeKeyboardState` (@Observable)
- Git panel: `GitPanelView` — changes/history/worktrees; FSEvents recursive watcher on rootPath (utility queue, 500ms debounce)
- Split panes: `PaneContainerView` builds from `PaneNode` binary tree; `HarnessSplitView` per branch node
- Sessions: `SessionCoordinator.shared` — async IPC, snapshot notifications via `NotificationBus.shared.snapshotChanged`
- File preview: `ContentAreaViewController.showFileEditorSplit()` — constraint-based sibling panel (40% editor / 60% terminal), never reparents terminal views; `refreshEditorPanelFill()` uses compensated opacity so editor preview visually matches terminal density
- File preview live reload: `FileChangeWatcher` (Services/FileExplorer) — single-file DispatchSource, 0.3s debounce, used by `FileEditorView` and `FileViewerViewController` to reload on external edits
- File editor vi mode: `ViEngine` in `ViNormalMode.swift` — `@MainActor final class`, wired via `SyntaxTextView.vi`; callbacks: `onSave`, `onQuit`, `onOpenFile`, `onSetOption`, `onNextBuffer`, `onSearchHighlight`; ex commands post notifications (`viQuitCommand`, `viOpenFileCommand`, `viNextBufferCommand`)
- LSP: `LSPFileSession` in `HarnessApp/UI/` wraps `HarnessLSP.LSPClient`; auto-detects Swift/TS/Python/Rust/Go by project markers; hover + go-to-def + diagnostics wired in `FileEditorView`
- CWD tracking: `AgentScanner.cwdTimer` (500ms) → `SurfaceRegistry.refreshCwdOnly()` (proc_pidinfo) → `snapshotChanged` → sidebar reload
- ACP Client: SHELVED — code intact (`ACPClient`, `ACPSession`, `AgentChatPanelView`, `AgentConfig`)
- Preview uses `.harness-preview/` — socket path max 103 bytes (use `/tmp/hp` symlink for worktree)
- SoftIconButton: supports `rightMouseDown` → pops up assigned `.menu`
- ⌘1–9: `MenuTarget.selectSessionNumber` → `SessionCoordinator.selectWorkspace(byIndex:)`
- tmux: `window-size` option read in `DaemonServer.applyEffectiveSize`; `list-*` commands in `MainExecutor` render `-F` format strings and `--json` arrays
