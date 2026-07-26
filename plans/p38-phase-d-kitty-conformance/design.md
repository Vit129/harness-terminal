# P38 Phase D — Kitty Graphics Conformance Slice

Source: `agent-memory/plans/p38-competitive-feature-gaps.md` Phase D. D1 investigation via Fable
consult (2026-07-14) found the phase's own premise stale: Kitty/Sixel/iTerm2 image protocols
shipped 2026-05-30 (`0fc22101`/`1a07a4aa`), not deferred. This document covers only the real gap
found: `handleKittyGraphics` dropped `a=q` (query), `a=t`+`a=p` (transmit-then-place-by-id), and
`a=d` (delete) — the rest of D1's findings live in `p38-competitive-feature-gaps.md`'s Phase D
section and `INDEX.md`'s corrected P30 entry.

## Scope (locked)

- PNG/RGB/RGBA formats, direct base64 payload only — matches existing v1 transmit+display support,
  no new format work.
- `a=d` deletes placements for a given image id only (`i=`) — NOT the full Kitty deletion-mode
  matrix (`d=a/c/f/p/q/r/x/y/z`). Documented as deferred, not silently dropped.
- Quiet-flag (`q=0/1/2`) response suppression implemented per spec, since wrong response behavior
  is worse than no response for some real clients (Fable's own flagged concern).
- Explicitly NOT verified against a real client (kitten icat / timg / ratatui-image) this session —
  no live terminal session available to drive one. Protocol behavior implemented from spec + the
  existing engine's own conventions, covered by headless unit tests only. **Live check still owed.**

## Implementation

- `TerminalScreen.placeImage` (`Screen/TerminalScreen.swift`): now returns the internal placement
  id (`@discardableResult`) instead of `Void` — needed so the emulator can record which internal
  placements belong to which Kitty client image id.
- `TerminalScreen.deleteImage(id:)` (new): removes one placement + its `imageStore` entry by
  internal id. Marks the whole screen dirty rather than computing the placement's current
  viewport-relative row (which can drift after scrolling since placement time) — deletion is rare
  enough that the extra redraw cost is a non-issue.
- `TerminalEmulator`: two new dictionaries —
  - `kittyTransmittedImages: [Int: DecodedImage]` — `a=t` images awaiting a later `a=p`, keyed by
    the client's `i=` id (distinct from `TerminalScreen`'s own `nextImageID`, which has no
    protocol meaning).
  - `kittyPlacementIDsByImageID: [Int: [Int]]` — client image id → internal placement ids, so
    `a=d` can find what to remove. Known simplification: assumes all placements for one image id
    live on the CURRENT screen at delete time — a placement made on the alternate screen, deleted
    after switching back to primary, won't be found. Real kitty ties image storage to the terminal
    rather than a screen buffer; not fixed here, deferred until a real client hits it.
  - Both cleared in `fullReset()` alongside the existing `kittyPending` reset.
  - `maxKittyTransmittedImages = 64` — same flood-guard pattern as the existing
    `maxKittyPendingImages` cap on in-flight chunk reassembly.
- `handleKittyGraphics` rewritten from a 2-case guard (`T`/`p` only) to a full switch: `T`
  (transmit+display, unchanged behavior + response), `t` (store only), `p` (place by id), `d`
  (delete by id), `q` (validate-only, no store/display).
- `respondKitty(_:message:isError:)` (new): builds the `<ESC>_G<control>;<message><ESC>\` response,
  honoring `q=1`(suppress OK)/`q=2`(suppress both).

## Tests

`Tests/KouenTerminalEngineTests/KittyGraphicsConformanceTests.swift` (9 tests): query OK/error
responses, quiet-flag suppression (both tiers), transmit-then-place-by-id (single + repeated),
place-by-unknown-id error, delete removes placement, delete-unknown-id no-ops, delete doesn't
cross-contaminate other image ids. Existing `ImageProtocolTests.swift` (13 tests, P30's own suite)
re-run as an explicit regression check — none of those tests or the files they exercise needed
changes.

## Gate

`swift build --product Kouen` green, `swift test --filter "KittyGraphicsConformanceTests|ImageProtocolTests"` green (22/22), `Tests/robot/run.sh` green (26/26). Live check against a real
probing client (kitten icat / timg) deferred to end-of-session batch alongside Phase B/C/E.
