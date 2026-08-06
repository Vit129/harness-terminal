# M3 — Browser Design Mode — Task Progress

Design: [design.md](design.md). Wayfinder ticket: [../m2-m9-competitive-features/wayfinder-map.md](../m2-m9-competitive-features/wayfinder-map.md) (M3).

## KouenApp — BrowserPaneView.swift

- [x] `designModeButton` (`SoftIconButton`, `"cursorarrow.rays"` symbol) — toolbar wiring (setup, `toolbarStack`, width constraint), mirrors `viewSourceButton`/`darkModeButton` exactly
- [x] `designModeEnableJS` — hover-highlight overlay (fixed-position div, `pointer-events:none`) + click-to-select, `data-kouen-design-ref` marker attribute, `window.__kouenDesignModeCleanup` teardown function
- [x] `kouenDesignModeSelect` `WKScriptMessageHandler` registration (`setupConsoleLogRedirection`, alongside the two existing handlers) + case in `userContentController(_:didReceive:)`
- [x] `DesignModeElementInfo: Codable` decode (tag/id/className/styles)
- [x] `designModeClicked()` toggle action, `teardownDesignModeIfActive()` (also wired into `closePaneClicked()`)
- [x] `showDesignModePopover(for:)`, `applyLiveStyle(prop:value:)` (re-finds element via `data-kouen-design-ref`, live `element.style[prop] = value`), `copyDesignModeCSS()` + `cssPropertyName()` (camelCase → kebab-case)
- [x] `DesignModePopoverViewController` (new private `NSViewController`, bottom of file) — title + one labeled `NSTextField` per style property + "Copy CSS" button

## Tests

- [x] `Tests/KouenAppTests/BrowserPaneViewTests.swift` (+2 tests): `testDesignModeButtonHasExpectedIdentifierAndTooltip`, `testCssPropertyNameConvertsCamelCaseToKebabCase` (`cssPropertyName` made internal, not private, so `@testable import` can reach it)
- Full JS-injection/popover-interaction path has no unit test — same ceiling as every other browser-pane feature in this project (`architecture/browser-devtools-api.md`'s own Testing section requires a running app). Deferred to the live check below.

## Docs

- [x] `GLOSSARY.md` — "Design Mode" term added during interview pass, table blank-line bug (pre-existing from this session's own M2 edit) fixed while there
- [x] `agent-memory/plans/INDEX.md` — M3 row added
- [x] `agent-memory/plans/m2-m9-competitive-features/wayfinder-map.md` — M3 marked closed

## Environment fix discovered this session (not part of M3's diff — `.build/` is gitignored)

`KouenAppTests.xctest` failed to `dlopen` (`Library not loaded: @rpath/Sparkle.framework`) —
blocked plain `swift test` and anything shelling out to it (including `Tests/robot/run.sh`'s
`Pairing Unit Tests Pass` guard) for the whole session, starting from M2's verification pass.
Root cause: `.build/out/Products/Debug/PackageFrameworks/` (one of the `@rpath` search
locations baked into the test binary) didn't exist / was empty, even though
`.build/out/Products/Debug/Sparkle.framework` itself was present one level up. Fix:
`ln -sf .build/out/Products/Debug/Sparkle.framework .build/out/Products/Debug/PackageFrameworks/Sparkle.framework`.
Local/session-only (inside gitignored `.build/`) — a clean `.build` wipe will need this
redone. Worth investigating why SwiftPM isn't populating `PackageFrameworks/` itself if this
recurs after a real clean build; out of scope for M3 to chase further tonight.

## Verification

- [x] `swift build --product Kouen` — clean, no new warnings
- [x] `swift build --build-tests` — clean
- [x] `KouenAppTests.xctest` full suite (direct `xcrun xctest`, Sparkle workaround above) — 244 tests, 0 failures
- [x] `Tests/robot/run.sh` — 27/27 passed (previously 26/27 before the Sparkle fix — the `Pairing Unit Tests Pass` guard is now green too, unrelated to M3's own changes but unblocked by the same-session environment fix)
- [ ] Live check: open a real browser pane, click Design Mode, hover/click a real page element, edit a style field, confirm live visual change + verify "Copy CSS" clipboard content — owed, same as every other browser-pane feature's live-check in this project
