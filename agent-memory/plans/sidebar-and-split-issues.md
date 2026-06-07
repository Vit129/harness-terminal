# Issues Analysis: Right Sidebar & Multi-Pane Split Squeezing

Status: **sidebar resolved**, split squeezing tolerable

---

## 1. Sidebar Right Alignment — RESOLVED

✅ Real-time toggle works (View > Move Sidebar to Right/Left)  
✅ Settings persist across restart  
✅ Right-click sidebar toggle button or session row → position menu  
✅ Traffic light inset handled for both left and right positions  

**Fix:** `updateSidebarPlacement()` removes only sidebar container, reinserts at correct position, restores frames, calls `adjustSubviews()`. (CASE-007)

---

## 2. Multi-Pane Split Squeezing (Split Right > 3) — LOW PRIORITY

### Behavior
Splitting panes horizontally 4-5 times causes middle panes to compress on window resize.

### Root Cause
- `HarnessSplitView.layout()` distributes equally only once (`appliedRatio` lock)
- After lock, NSSplitView's default resize algorithm resizes unequally

### Planned Fix (deferred)
Implement `splitView(_:resizeSubviewsWithOldSize:)` to redistribute equally when `ratio == nil`.
