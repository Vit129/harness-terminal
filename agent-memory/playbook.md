# Playbook — Problem Resolution Cases

<!-- Flat table. Search by domain or trigger keywords at session start. -->
<!-- Sequential IDs: CASE-001, CASE-002, etc. -->
<!-- Max 120 chars per field. Archive rule: zero Applied+Prevented after 30 days → move to completed-archive.md -->
<!-- Promote rule: recurring pattern (Applied 2+) → agent-memory/knowledge/*.md -->

| ID | Trigger | Fix | Domain | Outcome | Applied | Prevented |
|----|---------|-----|--------|---------|---------|-----------|
| CASE-001 | NSButton checkbox inside NSStackView inside NSScrollView not receiving clicks in Git sidebar panel | Remove FlippedView scroll-wrapper; use custom FlippedStackView directly as documentView to fix Auto Layout constraints. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-002 | NSSplitView subviews collapsing to 0 size (hidden left/bottom splits) and custom ratios lost on rebuild | Set subviews `autoresizingMask = [.width, .height]`; store ratio in HarnessSplitView and setPosition on first layout pass with non-zero frame, setting appliedRatio flag *before* calling setPosition to prevent recursive stack overflow. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-003 | Terminal (Metal/CADisplayLink) goes black after pane tree rebuild (removeFromSuperview + re-add in same window) | Override `viewDidMoveToSuperview()` in HarnessTerminalSurfaceView: if window != nil, stop+start display link + scheduleRender. | AppKit/Metal | RESOLVED | 4 | 0 |
| CASE-004 | Overlay NSView above Metal terminal surface not visible (zPosition, addSubview positioned:above) | Metal CALayer composites above all sibling layers regardless of zPosition. Use HitTestPassthroughView with layer?.zPosition=1000 — works for small overlays but full-frame overlay blocks Metal render. | AppKit/Metal | WORKAROUND | 1 | 0 |
| CASE-005 | NSButton with .recessed bezelStyle shows white background in dark theme | Use .inline bezelStyle + isBordered=false + manual layer?.backgroundColor for dark pill appearance. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-006 | NSSplitView.setPosition in layout() causes infinite recursion when N>2 subviews | Add `isApplyingPositions` bool guard — set true before loop, check at entry. `appliedRatio` alone insufficient because setPosition triggers layout for each divider. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-007 | NSSplitView subview reorder via removeFromSuperview+addSubview causes window collapse/black | Remove only the view being moved, reinsert with `addSubview(_:positioned:relativeTo:)`, restore frames after reinsert, call `adjustSubviews()`. Never remove both subviews simultaneously. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-008 | NSApp.keyWindow nil when menu action triggered via AppleScript (process not frontmost) | Use `NSApp.keyWindow ?? NSApp.mainWindow` fallback in menu target handlers. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-009 | Git panel not updating in real-time (only refreshes on sidebar tab switch) | Add DispatchSource.makeFileSystemObjectSource watching `.git` dir with 500ms debounce → auto-refresh on commit/stage/checkout. | AppKit/Git | RESOLVED | 1 | 0 |
| CASE-010 | NSFont has no `.italicSystemFont` (unlike UIFont) | Use `NSFontManager.shared.convert(.systemFont(ofSize:), toHaveTrait: .italicFontMask)` instead. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-011 | AnyCodable has no subscript operator — can't chain `dict["key"]?["nested"]` | Pattern-match each level: `if case let .object(inner) = dict["key"], case let .string(v) = inner["nested"]`. | Swift/Types | RESOLVED | 1 | 0 |
| CASE-012 | File preview causes 1-2s black screen on open/close (Metal surface dies) | Don't reparent terminal views into NSSplitView. Use constraint-based sibling panel: add editor as sibling, shift terminalHost.leadingAnchor. | AppKit/Metal | RESOLVED | 1 | 0 |
| CASE-013 | Swift 6 crash: MainActor.assumeIsolated inside DispatchQueue.main.async | Replace `DispatchQueue.main.async { MainActor.assumeIsolated {} }` with `Task { @MainActor in }`. For DispatchSource, use `.main` queue directly. | Swift/Concurrency | RESOLVED | 3 | 0 |
| CASE-014 | NSSplitView.setPosition fails when bounds.width==0 (view not yet laid out) | Use DispatchQueue.main.async with retry after 50ms if bounds still zero. Or use constraint multiplier instead of setPosition. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-015 | File tree 3s polling causes unnecessary CPU + flicker | Remove polling task; FSEvents watcher with 500ms debounce is sufficient. Reconcile nodes in-place to preserve expand/collapse state. | AppKit/Perf | RESOLVED | 1 | 0 |
