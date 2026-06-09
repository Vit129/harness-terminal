# AppKit + Metal Patterns

## Metal Surface Lifecycle (CASE-003)

Terminal uses Metal/CADisplayLink for rendering. When a pane tree is rebuilt (removeFromSuperview + re-add in same window), the Metal surface goes black.

**Fix:** Override `viewDidMoveToSuperview()` in `HarnessTerminalSurfaceView`: if `window != nil`, stop+start display link + scheduleRender.

**Why:** Metal's CADisplayLink doesn't survive a superview detach/reattach cycle. The display link loses its target and stops firing. Explicitly restarting it on reattach restores rendering.

## Overlay Above Metal (CASE-004)

Metal CALayer composites above all sibling layers regardless of `zPosition`. Standard `addSubview(positioned:above:)` doesn't work.

**Workaround:** Use `HitTestPassthroughView` with `layer?.zPosition = 1000`. Works for small overlays (split buttons, pills) but a full-frame overlay blocks Metal render.

**Pattern:** Keep overlays as small hit-test-passthrough views with high zPosition. Never cover the full Metal surface.

## NSView Layer Opacity — Chrome Parity Pattern (CASE-011)

AppKit NSViews that sit alongside Metal surfaces (file editor, sidebar chrome) must
explicitly apply opacity to their CALayer background to match the terminal's translucency.
Simply leaving `backgroundColor = .clear` makes them rely on raw window vibrancy, which
ignores the user's opacity slider.

**Pattern:**
```swift
let opacity = CGFloat(HarnessSettings.clampedOpacity(settings.backgroundOpacity))
panel.layer?.backgroundColor = HarnessChrome.current.terminalBackground
    .withAlphaComponent(opacity).cgColor
```

**Key points:**
- Call this in `applyChrome()` (responds to theme/opacity changes) AND at panel-creation time.
- `HarnessSettings.clampedOpacity` returns `Float` — cast to `CGFloat` for `withAlphaComponent`.
- Subviews (`scrollView`, `textView`, gutter) that already draw transparent don't need changes;
  the panel layer background shows through them automatically.
- The terminal host uses a different approach (clear when translucent, solid when opaque)
  because the Metal renderer handles its own alpha; AppKit-only panels must do it themselves.

**Files:** `ContentAreaViewController.swift` → `refreshEditorPanelFill()` / `applyChrome()`

## NSFont Italic (CASE-010)

NSFont has no `.italicSystemFont` (unlike UIFont).

**Fix:** `NSFontManager.shared.convert(.systemFont(ofSize:), toHaveTrait: .italicFontMask)`
