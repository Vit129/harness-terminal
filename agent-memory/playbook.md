# Playbook — Problem Resolution Cases

<!-- Flat table. Search by domain or trigger keywords at session start. -->
<!-- Trigger/Fix: 120 chars max. If more detail needed → store in knowledge/ and reference path. -->
<!-- Sequential IDs: CASE-001, CASE-002, etc. -->
<!-- Applied/Prevented: increment when case is used or prevents a repeat. -->
<!-- Archive rule: when Applied+Prevented >= 5 AND no use in 30 days → move to knowledge/archive-playbook.md -->

| ID | Trigger | Fix | Domain | Outcome | Applied | Prevented |
|----|---------|-----|--------|---------|---------|-----------|
| CASE-001 | NSButton checkbox inside NSStackView inside NSScrollView not receiving clicks in Git sidebar panel | Remove FlippedView scroll-wrapper; use custom FlippedStackView directly as documentView to fix Auto Layout constraints. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-002 | NSSplitView subviews collapsing to 0 size (hidden left/bottom splits) and custom ratios lost on rebuild | Set subviews `autoresizingMask = [.width, .height]`; store ratio in HarnessSplitView and setPosition on first layout pass with non-zero frame, setting appliedRatio flag *before* calling setPosition to prevent recursive stack overflow. | AppKit/UI | RESOLVED | 1 | 0 |
| CASE-003 | Terminal (Metal/CADisplayLink) goes black after pane tree rebuild (removeFromSuperview + re-add in same window) | viewDidMoveToWindow not fired on same-window reparent → display link stays dead. needsDisplay alone insufficient. Needs incremental update (don't remove existing hosts) or child NSWindow overlay. | AppKit/Metal | OPEN | 2 | 0 |
| CASE-004 | Overlay NSView above Metal terminal surface not visible (zPosition, addSubview positioned:above) | Metal CALayer composites above all sibling layers regardless of zPosition. Use HitTestPassthroughView with layer?.zPosition=1000 — works for small overlays but full-frame overlay blocks Metal render. | AppKit/Metal | WORKAROUND | 1 | 0 |
| CASE-005 | NSButton with .recessed bezelStyle shows white background in dark theme | Use .inline bezelStyle + isBordered=false + manual layer?.backgroundColor for dark pill appearance. | AppKit/UI | RESOLVED | 1 | 0 |
