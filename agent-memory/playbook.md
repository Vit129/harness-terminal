# Playbook — Problem Resolution Cases

<!-- Flat table. Search by domain or trigger keywords at session start. -->
<!-- Sequential IDs: CASE-001, CASE-002, etc. -->

| ID | Trigger | Fix | Domain | Outcome | Applied | Prevented |
|----|---------|-----|--------|---------|---------|-----------|
| CASE-001 | NSButton checkbox inside NSStackView inside NSScrollView not receiving clicks in Git sidebar panel | Remove FlippedView scroll-wrapper; use custom FlippedStackView directly as documentView to fix Auto Layout constraints. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-002 | NSSplitView subviews collapsing to 0 size (hidden left/bottom splits) and custom ratios lost on rebuild | Set subviews `autoresizingMask = [.width, .height]`; store ratio in HarnessSplitView and setPosition on first layout pass with non-zero frame, setting appliedRatio flag *before* calling setPosition to prevent recursive stack overflow. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-003 | Terminal (Metal/CADisplayLink) goes black after pane tree rebuild (removeFromSuperview + re-add in same window) | Override `viewDidMoveToSuperview()` in HarnessTerminalSurfaceView: if window != nil, stop+start display link + scheduleRender. | AppKit/Metal | RESOLVED | 3 | 0 |
| CASE-004 | Overlay NSView above Metal terminal surface not visible (zPosition, addSubview positioned:above) | Metal CALayer composites above all sibling layers regardless of zPosition. Use HitTestPassthroughView with layer?.zPosition=1000 — works for small overlays but full-frame overlay blocks Metal render. | AppKit/Metal | WORKAROUND | 1 | 0 |
| CASE-005 | NSButton with .recessed bezelStyle shows white background in dark theme | Use .inline bezelStyle + isBordered=false + manual layer?.backgroundColor for dark pill appearance. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-006 | NSSplitView.setPosition in layout() causes infinite recursion when N>2 subviews | Add `isApplyingPositions` bool guard — set true before loop, check at entry. `appliedRatio` alone insufficient because setPosition triggers layout for each divider. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-007 | NSSplitView subview reorder via removeFromSuperview+addSubview causes window collapse/black | Remove only the view being moved, reinsert with `addSubview(_:positioned:relativeTo:)`, restore frames after reinsert, call `adjustSubviews()`. Never remove both subviews simultaneously. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-008 | NSApp.keyWindow nil when menu action triggered via AppleScript (process not frontmost) | Use `NSApp.keyWindow ?? NSApp.mainWindow` fallback in menu target handlers. | AppKit/UI | RESOLVED | 1 | 0 |
