# P6: File Editor Opacity Parity with Terminal

## Problem
File editor panel opacity does not match terminal opacity when user adjusts
the Background Opacity slider in Settings > Appearance.

- Terminal uses Metal renderer with its own `backgroundOpacity` setting applied
  at the GPU layer (shader uniform or clear color alpha).
- Editor panel currently uses `NSColor.clear` background → relies on window
  vibrancy/transparency directly, which doesn't respect the same opacity %.

## Root Cause (hypothesis)
The Metal terminal renderer applies `HarnessChrome.backgroundOpacity` to the
terminal background color in its render pass. The editor panel has no equivalent
— it's either fully opaque or fully transparent (vibrancy pass-through).

## Fix Approach
1. Find where `backgroundOpacity` is applied in the Metal renderer (likely in
   `HarnessTerminalRenderer` or the surface view's clear color).
2. Apply the same alpha to the editor panel's layer background:
   ```swift
   panel.layer?.backgroundColor = c.terminalBackground
       .withAlphaComponent(HarnessChrome.backgroundOpacity).cgColor
   ```
3. Do the same for `FileEditorView`, `FileEditorTabBarView`, and gutter.
4. Listen for opacity setting changes and update the layers dynamically.

## Actual Fix (2026-06-09)

Only `fileEditorPanel` (NSView) needed a background — all subviews (`FileEditorView`,
`FileEditorTabBarView`, `SyntaxTextView`, gutter) were already transparent and composite
correctly over the panel layer. Metal renderer not involved: editor uses AppKit layers.

Added `refreshEditorPanelFill()` in `ContentAreaViewController`:
```swift
private func refreshEditorPanelFill() {
    guard let panel = fileEditorPanel else { return }
    let opacity = CGFloat(HarnessSettings.clampedOpacity(SessionCoordinator.shared.settings.backgroundOpacity))
    panel.layer?.backgroundColor = HarnessChrome.current.terminalBackground
        .withAlphaComponent(opacity).cgColor
}
```
Wired into `applyChrome()` (theme/opacity changes) and `showFileEditorSplit()` (panel creation).

Pattern mirrors chrome sidebar: `terminalBackground × opacity` over the window-wide blur.

## Status
- [x] Investigate Metal renderer opacity application
- [x] Apply matching opacity to editor panel layers
- [x] Verify both sides match at various opacity %

**Done — 2026-06-09. Ready to archive.**
