# Memory — Harness Terminal

## Active Context
- **Project:** harness-terminal (Swift/AppKit macOS terminal emulator)
- **Fork:** Vit129/harness-terminal (fork of robzilla1738/harness-terminal)
- **Working branch:** `main`
- **Preview:** `make preview` (uses `.harness-preview/` dir)

## Current Sprint — Sidebar & Split Polish (post-v1.5.0)
✅ Sidebar position toggle (left/right) — real-time, no restart required  
✅ Right-click sidebar toggle button → "Move Sidebar to Left/Right" menu  
✅ Right-click session row → includes "Move Sidebar to Left/Right"  
✅ Removed all "Split Down" from menus, command palette, context menus  
✅ P6 UI Polish complete (SF Symbols, animations, vibrancy, pill buttons)  
✅ Git toast messages (fetch/pull/push/stage progress feedback)  
✅ viewDidMoveToSuperview() fix for Metal CADisplayLink on reparent  
✅ File preview (P4 Track 1 MVP) merged  

## Known Issues
- **Split right 4+ panes slightly uneven** — NSSplitView default resize algorithm compresses middle panes on window resize. Tolerable for now.

## Completed Sprints
- **v1.3.0** — IDE-like Sidebar (PBI-001): Files tab, Git tab, session tabs, recent projects
- **v1.4.0** — Git panel: Commit ▼ menu, Sync button with per-remote options
- **v1.5.0** — CMUX split panes, N-ary flatten, host reuse, split down removed

## Architecture Notes
- Sidebar: `HarnessSidebarPanelViewController` — tabs (Sessions/Files/Git) via NSSegmentedControl
- Sidebar position: `MainSplitViewController.updateSidebarPlacement()` — reorders NSSplitView subviews
- File tree: `WorkspaceFileTreeView` — NSOutlineView with `FileTreeWatcher`
- Git panel: `GitPanelView` — custom NSView with scroll views for changes/history
- Split panes: `PaneContainerView` builds from `PaneNode` binary tree; `HarnessSplitView` (NSSplitView subclass) per branch node
- Split buttons: `PaneSplitButtonsView` — overlay at top-right with zPosition 1000
- Sessions: `SessionCoordinator.shared` manages daemon IPC, snapshot notifications via `NotificationBus.shared.snapshotChanged`
- Preview uses `.harness-preview/` — socket path max 103 bytes (use `/tmp/hp` symlink for worktree)
- SoftIconButton: supports `rightMouseDown` → pops up assigned `.menu`
