# P3 — N-ary Split Panes

Status: **complete** (split down removed; split right works)  
Priority: closed  

---

## Completed

✅ Same-direction flatten: binary tree chain flattened into single NSSplitView + N subviews  
✅ Equal distribution: `layout()` sets divider positions at `totalSize/N` intervals  
✅ Recursion fix: `isApplyingPositions` guard prevents layout→setPosition→layout loop  
✅ Host reuse: detach existing TerminalHostViews before rebuild, re-insert into new container  
✅ viewDidMoveToSuperview() fix: restart CADisplayLink on reparent — terminal no longer goes black  
✅ Split down removed entirely (menu, command palette, context menus, keybindings, docs)  

## Remaining (low priority, tolerable)

- **4+ horizontal splits slightly uneven on resize** — NSSplitView default resize algorithm compresses middle panes. Fix would require implementing `splitView(_:resizeSubviewsWithOldSize:)` for equal redistribution.
