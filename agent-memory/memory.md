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

## Known Issues
- **Split down (⌘⇧D) terminal disappears** — Metal CADisplayLink not re-activated after view rebuild (viewDidMoveToWindow not fired on same-window reparent)
- **Split 3+ panes stack right** — binary tree PaneNode nests 50/50 NSSplitViews; need N-ary flat model + single NSSplitView with adjustSubviews()
- **Fix plan:** Refactor PaneNode from binary tree → N-ary list, use one NSSplitView per direction with N subviews, incremental view update (don't removeFromSuperview existing hosts)

## Completed Sprints
- **v1.3.0** — IDE-like Sidebar (PBI-001): Files tab, Git tab, session tabs, recent projects
- **v1.4.0** — Git panel: Commit ▼ menu (Tracked/Amend/Signoff), Sync button (Fetch From/Pull Rebase/Push To per-remote)

## Architecture Notes
- Sidebar: `HarnessSidebarPanelViewController` — tabs (Sessions/Files/Git) via NSSegmentedControl
- File tree: `WorkspaceFileTreeView` — NSOutlineView with `FileTreeWatcher`
- Git panel: `GitPanelView` — custom NSView with scroll views for changes/history
- Split panes: `PaneContainerView` builds from `PaneNode` binary tree; `HarnessSplitView` (NSSplitView subclass) per branch node
- Split buttons: `PaneSplitButtonsView` — overlay at top-right with zPosition 1000
- Sessions: `SessionCoordinator.shared` manages daemon IPC, snapshot notifications via `NotificationBus.shared.snapshotChanged`
- Preview uses `.harness-preview/` — socket path max 103 bytes (use `/tmp/hp` symlink for worktree)
