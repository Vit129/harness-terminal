# P8 macOS27 adoption — Liquid Glass chrome regressions (2026-07-25/26)

Four independent bugs found and fixed in one session while chasing "terminal isn't
transparent" / "tab bar color doesn't match" / "agy logo colors are corrupted" reports on
`feature/p8-macos27-adoption`. All four trace back to the same mid-refactor WIP (agy/
Antigravity CLI session) that was handed off uncommitted. Landed in `157e5aa6` +
follow-up commits.

## 1. Transparency pipeline hardcoded off

`MainWindowController.applyTransparency()` had its opacity/blur/tint/shadow logic ripped
out and replaced with hardcoded `isOpaque=true`, `hasShadow=true`,
`WindowBlur.apply(radius: 0, ...)`, `titlebarAppearsTransparent=false` — completely
ignoring `settings.backgroundOpacity`/`backgroundBlur`/`transparentTitlebar`. A new
`⌘⇧U` "Toggle Solid/Glass Opacity Mode" feature was added in the same WIP that depended
on this function actually reading the setting — so the toggle silently did nothing.

**Why it wasn't caught:** `KouenSettings.swift`'s default `backgroundOpacity` was also
changed `0.63→1.0` (`backgroundBlur 16→0`) in the same WIP. At opacity=1.0 the hardcoded
always-opaque path *looks* correct by coincidence, so testing against the new default
never exercised the broken translucent branch. A user with a pre-existing custom opacity
(persisted in their own `settings.json`) hit the dead code path immediately.

**Fix:** restored the original opacity-driven branch (isOpaque/tintAlpha/shadow/blur all
keyed off `settings.backgroundOpacity`). Reverted the default back to `0.63`/`16`/`true`
— the branch's whole purpose is adopting Liquid Glass; defaulting to solid contradicted it.

## 2. Chrome tint double-composited over the window's own tint

`ChromeBackdrop.update()` (`KouenDesign.swift`) painted its own
`tint.layer.backgroundColor = baseColor.withAlphaComponent(opacity)` unconditionally, on
top of the window's own already-tinted `backgroundColor` (bug 1's fix). Two
semi-transparent layers of the *same* color compositing over each other read as visibly
more opaque than one (two 24%-alpha layers ≈ 42% effective) — sidebar/tab-bar read as a
distinct, more-saturated block next to the barely-tinted terminal (which correctly went
`nil` for its own layer in an earlier, unrelated fix — see bug 3's `refreshTerminalHostFill`
pattern). Confirmed with pixel sampling (`PIL.Image.getpixel`) at the row boundary: hue
ratios matched (same base color) but brightness differed ~1.6-1.8x.

**Fix:** `tint.layer.backgroundColor = translucent ? nil : baseColor.cgColor` — mirrors
`ContentAreaViewController.refreshTerminalHostFill()`'s `opacity >= 1 ? solid : nil`
exactly. Single tint source (the window) when translucent; each surface only paints its
own solid fill when opaque.

## 3. One chrome strip not routed through the shared ChromeBackdrop system

`TerminalTabBarView` (the terminal session tab-pill row) had its own bespoke
opacity-aware `CALayer.backgroundColor` fill (`nil` when translucent, solid
`terminalBackground` when opaque) instead of calling `KouenDesign.applyTabBarChrome()`
like every other chrome strip (window title strip, browser toolbar, browser tab bar,
sidebar). Functionally "correct" in isolation (single-tint, no double-composite) but
visibly inconsistent with everything else because it skipped the real
`NSGlassEffectView`/vibrancy backdrop entirely — Liquid Glass has its own
refraction/brightening the flat CALayer fill doesn't replicate.

**Fix:** replaced the bespoke fill with `KouenDesign.applyTabBarChrome(to: self)` in both
`setup()` and `applyChrome()`; SwiftUI body's own `.background()` changed to
unconditional `Color.clear` (fill now comes from the NSView-level backdrop behind it).

**Lesson:** when N chrome surfaces are meant to look like "one continuous surface," grep
for *every* call site that paints that surface's background before declaring it fixed —
a bespoke reimplementation that's individually correct can still be the one outlier that
breaks visual consistency. `grep -rn "applyTabBarChrome\|applySidebarChrome"` to enumerate
all current call sites before adding a new chrome surface.

## 4. Accessibility contrast floor corrupting ANSI/pixel-art content

`CellColorResolver.resolve()`'s `minimumContrast` accessibility feature (this user's own
setting: `3.5`) forces a WCAG contrast floor between a cell's foreground and background —
correct for normal text, but half-block ANSI-art tools (e.g. the `agy`/Antigravity CLI
banner) deliberately set fg/bg to *near-identical* truecolor values on block-drawing
glyphs (`▀▄`) for smooth pixel shading, with no `faint` SGR attribute involved at all.
Forcing contrast between two adjacent art-pixel colors that were never meant to contrast
replaced the intended gradient with washed-out/white blocks.

An earlier pass at this (widening a `faint`-only ghost-text floor to `max(minimumContrast,
4.5)`) fixed a real but narrower over-triggering bug and was NOT sufficient — the agy logo
uses zero `faint` attributes, so it went through the plain non-faint
`effectiveMinContrast = minimumContrast` branch untouched by that fix. Confirmed via raw
ANSI capture (`kouen-cli capture-pane --surface <id> -e`, reading the isolated preview
instance's own daemon directly) — screenshots alone couldn't show the SGR codes needed to
tell "faint dim text" from "explicit near-identical truecolor pixel pair."

**Fix:** `CellColorResolver.isGraphicsGlyph(_ codepoint:)` — skip contrast enforcement
entirely (regardless of `minimumContrast` or `faint`) for codepoints in Block Elements
(U+2580–259F), Braille Patterns (U+2800–28FF), or Symbols for Legacy Computing
(U+1FB00–1FBFF). Ordinary text glyphs are unaffected. Regression test built from the
*actual* captured colors (`38;2;242;146;46;48;2;246;145;46`), asserting the exemption is
glyph-scoped (a plain letter with the same low-contrast pair still gets corrected).

## Cross-cutting

- **Verify against the actual running instance, not a screenshot alone.** Several rounds
  of this session were lost to (a) mistakenly claiming the user was on a stale binary when
  they weren't (the real tell: window title says "Kouen Preview"/bundle id
  `.preview` vs the production `.kouen` app — check that before diagnosing "stale"), and
  (b) guessing at chrome-color mismatches from a cropped screenshot before pixel-sampling
  or raw-capturing the actual bytes. `kouen-cli capture-pane -e` against an isolated
  preview's own `KOUEN_HOME` socket gets the real SGR codes; `PIL.Image.getpixel` gets
  real chrome colors. Both are cheap and end guessing loops fast.
- **A per-instance `settings.json` in an isolated preview state dir persists across
  relaunches** (`make preview` reuses the same `/tmp/kouen-preview-<hash>` unless
  `make preview-clean` runs) — a code-level default change never retroactively updates an
  already-persisted value. Diff the instance's actual `settings.json` before assuming a
  reverted default took effect. See RL-061 (same lesson, different session).
