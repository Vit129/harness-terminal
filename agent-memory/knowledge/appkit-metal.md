# AppKit + Metal Patterns

## Metal Surface Lifecycle (CASE-003)

Terminal uses Metal/CADisplayLink for rendering. When a pane tree is rebuilt (removeFromSuperview + re-add in same window), the Metal surface goes black.

**Fix:** Override `viewDidMoveToSuperview()` in `HarnessTerminalSurfaceView`: if `window != nil`, stop+start display link + scheduleRender.

**Why:** Metal's CADisplayLink doesn't survive a superview detach/reattach cycle. The display link loses its target and stops firing. Explicitly restarting it on reattach restores rendering.

## Overlay Above Metal (CASE-004)

Metal CALayer composites above all sibling layers regardless of `zPosition`. Standard `addSubview(positioned:above:)` doesn't work.

**Workaround:** Use `HitTestPassthroughView` with `layer?.zPosition = 1000`. Works for small overlays (split buttons, pills) but a full-frame overlay blocks Metal render.

**Pattern:** Keep overlays as small hit-test-passthrough views with high zPosition. Never cover the full Metal surface.

## NSView Layer Opacity — Preview Parity Pattern (CASE-011)

AppKit NSViews that sit alongside Metal surfaces (file editor, sidebar chrome) must
explicitly apply opacity to their CALayer background to match the terminal's translucency.
Simply leaving `backgroundColor = .clear` makes them rely on raw window vibrancy, which
ignores the user's opacity slider.

File editor/preview panels are a special case: raw opacity parity can still look too
transparent beside terminal content. The terminal renderer applies opacity to the default
canvas, but terminal programs may paint opaque cell backgrounds. Preview text usually sits
over a transparent AppKit canvas, so the panel needs a denser compensated alpha.

**Pattern:**
```swift
let opacity = CGFloat(HarnessSettings.clampedOpacity(settings.backgroundOpacity))
let editorOpacity = min(1, opacity + (1 - opacity) * 0.55)
panel.layer?.backgroundColor = HarnessChrome.current.terminalBackground
    .withAlphaComponent(editorOpacity).cgColor
```

**Key points:**
- Call this in `applyChrome()` (responds to theme/opacity changes) AND at panel-creation time.
- `HarnessSettings.clampedOpacity` returns `Float` — cast to `CGFloat` for `withAlphaComponent`.
- Use compensated alpha for the editor/preview panel; use raw opacity only for chrome surfaces
  that do not need to visually match terminal-rendered content.
- Subviews (`scrollView`, `textView`, gutter) that already draw transparent don't need changes;
  the panel layer background shows through them automatically.
- The terminal host uses a different approach (clear when translucent, solid when opaque)
  because the Metal renderer handles its own alpha; AppKit-only panels must do it themselves.
- `PaneContainerView.refreshChrome(snapshot:)` should call `applyChrome()` directly; an empty
  host lookup loop creates warning noise and does not refresh panel colors.

**Files:** `ContentAreaViewController.swift` → `refreshEditorPanelFill()` / `applyChrome()`

## Window Background Tint for Legibility (CASE-027)

**Problem:** When `backgroundOpacity < 1`, `window.backgroundColor = .clear` + CGS blur gives
a fully transparent backdrop. If the content behind the window is bright (Finder, browser,
document), terminal text becomes unreadable — pure transparency has no tint to provide
contrast.

**Apple's approach (iOS/macOS 26–27):** The "Liquid Glass" material uses a semi-opaque tinted
backing (`UIVisualEffectView.backgroundColor = theme_color.withAlpha(...)`) instead of pure
clear. iOS 27 added a user-facing transparency slider (ultra clear → fully tinted) after
community feedback that pure transparency hurt legibility. The lesson: "pure transparent +
always readable" is impossible without a tint layer.

**Fix applied:** In `MainWindowController.applyChrome()`, instead of `.clear`, set:
```swift
window.backgroundColor = HarnessChrome.current.terminalBackground
    .withAlphaComponent(CGFloat(opacity))
```
The theme colour acts as a tint at whatever strength the opacity slider is set. At 100 % it
is fully opaque (unchanged); at lower values the blur shows through but the tint ensures
contrast. CGS blur still applies on top.

**Files:** `MainWindowController.swift` → `applyChrome()`

## NSFont Italic (CASE-010)

NSFont has no `.italicSystemFont` (unlike UIFont).

**Fix:** `NSFontManager.shared.convert(.systemFont(ofSize:), toHaveTrait: .italicFontMask)`
