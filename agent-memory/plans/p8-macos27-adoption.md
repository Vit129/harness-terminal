# P8: macOS 27 Golden Gate Adoption

## Context
WWDC26 announced macOS 27 Golden Gate (ships ~Sep 2026). Harness Terminal
currently targets macOS 26 Tahoe. This plan covers compatibility testing,
new API adoption, and visual alignment with the refined Liquid Glass system.

Key sessions:
- "Modernize your AppKit app" (WWDC26/289)
- "What's new in SwiftUI" (WWDC26/269)
- "Use SwiftUI with AppKit and UIKit" (WWDC26/272)
- Metal guide (no breaking changes for our renderer)

## Priority: High (P0 = ship-blocking, P1 = quality, P2 = nice-to-have)

---

## Phase 1 — Compatibility (P0)

Ensure Harness builds and runs correctly on macOS 27 beta without regressions.

- [ ] Build with Xcode 27 beta, fix any deprecation warnings-as-errors
- [ ] Verify Liquid Glass doesn't break custom sidebar chrome (`HarnessDesign`,
      `ChromeBackdrop`, `WindowBlur.apply()`)
- [ ] Verify window corner radius change doesn't clip terminal content or overlays
- [ ] Test NSStatusItem (`MenuBarController`) with new expanded interface session API
- [ ] Confirm Metal renderer still works (no display pipeline changes expected)
- [ ] Run full test suite on macOS 27

## Phase 2 — Quick Wins (P1)

Low-effort adoptions that improve quality immediately.

- [ ] Set `window.autorecalculatesKeyViewLoop = true` on `MainWindowController`
- [ ] Set `preventsApplicationTerminationWhenModal = false` on non-critical sheets
      (about panel, settings, command palette)
- [ ] Adopt `NSViewCornerConfiguration` + `.containerConcentric` on:
  - `ToastLabel`
  - `DisplayPanesOverlay` chips
  - `ResizeHUDView`
  - `NotificationDropdownPanelView`
- [ ] Adopt sidebar semi-bold selection text style (if system doesn't auto-apply
      due to custom sidebar)

## Phase 3 — NSTextSelectionManager (P1)

Replace manual mouse-forwarding in file preview with system text selection.

- [ ] Evaluate `NSTextSelectionManager` for `SyntaxTextView` (file editor)
- [ ] Evaluate for `FileViewerViewController` QuickLook text selection
- [ ] If viable, remove manual `mouseDown/mouseDragged/mouseUp` forwarding
      (currently needed per RL-010/CASE-018)
- [ ] Test bidirectional selection, drag-and-drop text

## Phase 4 — Gesture Recognizer Migration (P2)

Long-term tech debt: replace mouseDown overrides with gesture recognizers.
Not urgent but aligns with Apple's direction.

Priority targets (most complex mouseDown logic):
- [ ] `TerminalTabBarView` — drag reorder + context menu
- [ ] `SessionCardRowView` — click + hover + context menu
- [ ] `HarnessControls` (slider, toggle, select) — tracking loops
- [ ] `ContentAreaViewController` split divider drag

Lower priority (simpler or less frequent):
- [ ] `SoftIconButton`, `HarnessPillButton`, `NotificationBellButton`
- [ ] `WorkspacePillButton`, `WorkspaceSwitcherRow`

## Phase 5 — State Restoration (P2)

Adopt `NSWindowRestoration` for seamless relaunch after system updates.

- [ ] Evaluate overlap with existing `SessionStore` persistence
- [ ] Implement `encodeRestorableState` on `MainWindowController` (sidebar
      width, selected tab, sidebar visibility, active workspace)
- [ ] Implement `restoreWindow(withIdentifier:)` in restoration class
- [ ] Call `invalidateRestorableState()` on relevant state changes
- [ ] Keep `SessionStore` for daemon-side session state (pane tree, surfaces)
      — restoration handles window chrome only

## Phase 6 — SwiftUI Performance (Free wins)

These require no code changes, just running on macOS 26+/27:

- List 100k+ items 6x faster → benefits `FileTreeSwiftUIView`
- Nested layouts 2x faster resize → benefits sidebar SwiftUI views
- `@State` lazy init (macro) → reduces reconciliation overhead

Verify:
- [ ] File tree with large repos (10k+ files) — measure scroll perf on 27 vs 26

---

## Non-goals
- Liquid Glass full redesign (keep custom chrome for brand identity)
- 3D charts / spatial layout (not relevant for terminal)
- Document API (not a document-based app)
- MetalFX upscaling (2D glyph renderer, not 3D)

## Risks
- Custom `NSVisualEffectView` / `WindowBlur` may conflict with system Liquid
  Glass in unexpected ways — need early beta testing
- `NSTextSelectionManager` may not support our use case (syntax-highlighted
  attributed text with line numbers) — evaluate before committing
- Gesture recognizer migration is large scope, defer if time-constrained

## Timeline
- **Beta 1–3 (Jun–Aug 2026):** Phase 1 + 2
- **RC (Sep 2026):** Phase 3 evaluated, Phase 6 verified
- **Post-release:** Phase 4 + 5 as time allows
