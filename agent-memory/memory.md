# Memory — Harness Terminal

## Active Context
- **Project:** harness-terminal (Swift/AppKit macOS terminal emulator)
- **Fork:** Vit129/harness-terminal (fork of robzilla1738/harness-terminal)
- **Working branch:** `worktree-feature+acp-aidlc` in `.claude/worktrees/feature+acp-aidlc/`
- **Preview:** `cd /tmp/hp && make preview` (symlink to avoid socket path length limit)

## Current Sprint — Split Panel (v1.5.0)
✅ CMUX-style split buttons (split right + close) at top-right corner of each pane  
✅ ⌘D — split right (creates new pane with shell)  
✅ ⌥⌘←→↑↓ — directional pane navigation  
✅ ⌥⇧⌘W — close pane  
✅ Drag divider to resize panes  
✅ Removed old S1/S2/S3 pane-local surface tabs (broken drag UX)  
✅ N-ary flatten: same-direction splits use single NSSplitView with equal distribution  
✅ Infinite recursion fix: isApplyingPositions guard in HarnessSplitView.layout()  
✅ Host reuse: detach terminal hosts before rebuild, re-insert without losing Metal state  

## Known Issues
- **Split down removed** — The Split Down (vertical split/rows) functionality was completely removed from the menu bar, command palette, and UI buttons per user request. Split Right remains fully functional.

## Completed Sprints
- **v1.3.0** — IDE-like Sidebar (PBI-001): Files tab, Git tab, session tabs, recent projects
- **v1.4.0** — Git panel: Commit ▼ menu (Tracked/Amend/Signoff), Sync button (Fetch From/Pull Rebase/Push To per-remote)

## In Progress — P4 File View MVP (`worktree-p4-file-view`, 2026-06-07)
✅ `FileViewerViewController` — read-only plain-text preview (NSTextView, 1MB guard, binary/non-UTF8 placeholder)
✅ Single-click file in tree → preview replaces tree in sidebar; back arrow restores tree (double-click still opens in terminal editor)
✅ Wired through `FileTreeSwiftUIView`/`WorkspaceFileTreeView`/`HarnessSidebarPanelViewController` via existing visibility-toggle pattern
🔜 **Next:** redesign UX to browser-style tabs (open files in tabs instead of replacing the tree) — see `agent-memory/plans/p4-lsp-file-view.md`
📋 Deferred: TreeSitter syntax highlighting, line numbers, Quick Look (images/PDF), LSP integration

## Architecture Notes
- Sidebar: `HarnessSidebarPanelViewController` — tabs (Sessions/Files/Git) via NSSegmentedControl
- File tree: `WorkspaceFileTreeView` — NSOutlineView with `FileTreeWatcher`
- Git panel: `GitPanelView` — custom NSView with scroll views for changes/history
- Split panes: `PaneContainerView` builds from `PaneNode` binary tree; `HarnessSplitView` (NSSplitView subclass) per branch node
- Split buttons: `PaneSplitButtonsView` — overlay at top-right with zPosition 1000
- Sessions: `SessionCoordinator.shared` manages daemon IPC, snapshot notifications via `NotificationBus.shared.snapshotChanged`
- Preview uses `.harness-preview/` — socket path max 103 bytes (use `/tmp/hp` symlink for worktree)
