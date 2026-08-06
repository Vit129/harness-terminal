# M9 — Slash Command Picker — Task Progress

Wayfinder ticket: [../m2-m9-competitive-features/wayfinder-map.md](../m2-m9-competitive-features/wayfinder-map.md) (M9), last of M2-M9.

**Scope correction found during investigation:** the plan doc's own note that "@ file-path
autocomplete" already shipped (P37 Phase G, 28/28) turned out to be for **P37 Mobile
Connect** — the phone companion app, not the macOS `ComposerPanel`. Verified by grep
(zero @-mention/autocomplete code in `ComposerPanel.swift`) before trusting the plan-doc
line at face value — a real instance of Step 3's "cross-reference every claim" catching
a stale assumption. Multi-line WAS already true for the macOS composer (confirmed,
`NSTextView`-based). Given that correction and remaining session time, scoped M9 v1 down
to slash-command discoverability only — `@file` mention is a real, separate, unbuilt gap
(documented, not silently dropped).

Reused `CompletionPopupView` (already exists, built for the file editor's own completion
in `SyntaxTextView.swift`) rather than building a new popup widget — same
`onConfirm`/`onDismiss`/`update(candidates:)`/`moveSelection(down:)`/`confirmSelection()`
API, positioned the same way (`firstRect(forCharacterRange:)`).

## KouenApp — ComposerPanel.swift

- [x] `ComposerPanel.slashCommands` — fixed list (`/clear`, `/compact`, `/model`, `/agents`, `/continue`, `/resume`, `/help`, `/cost`)
- [x] `ComposerPanel.slashMatch(text:cursorLocation:)` — pure, line-start-only matching (mirrors how the CLIs themselves only treat a leading `/` as a command)
- [x] `textDidChange(_:)` (NSTextViewDelegate) — shows/updates/dismisses the popup as the user types
- [x] `textView(_:doCommandBy:)` extended — Up/Down/Tab/Return/Esc drive the popup when it's showing, fall through to the panel's own Esc-to-close otherwise
- [x] `insertSlashCompletion` — replaces the typed prefix with the full command + trailing space

## Tests

- [x] `Tests/KouenAppTests/ComposerPanelSlashCommandTests.swift` (7 tests) — start-of-text match, match after a newline, no-match mid-sentence, no-match without leading slash, no-match on unknown prefix, bare `/` lists everything, cursor-position-scoped matching (not full-line)

## Docs

- [x] `GLOSSARY.md` — "Slash Command Picker" term, explicit `@file`-mention and Mobile-Connect-autocomplete distinctions
- [x] `agent-memory/plans/INDEX.md` — M9 row added
- [x] `agent-memory/plans/m2-m9-competitive-features/wayfinder-map.md` — M9 marked closed (last of the 8)

## Verification

- [x] `swift build --product Kouen` — clean
- [x] `swift build --build-tests` — clean
- [x] `KouenAppTests.xctest` full suite — 261/261, 0 failures (254 baseline + 7 new)
- [x] `Tests/robot/run.sh` — 27/27 passed, end-of-session batch run (2026-08-05, covers M2-M9 combined)
- [ ] Live check: open Composer (⌘⇧E), type `/mo`, confirm the picker filters to `/model` and Tab/Return inserts it — owed
