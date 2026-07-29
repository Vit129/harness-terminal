# Post-mortem: Cmd+\ sidebar toggle produces zero visible change (2026-07-29)

## Summary

Cmd+\ (Toggle Sidebar), and clicking the same "Toggle Sidebar" menu item directly, both
produced no visible change on the shipped v4.9.1 release build — dead from the very first
press, keyboard and menu identical, single window, persisting the whole session. Distinct
from — and reported as worse than — the previously fixed keyWindow-resolution bug
(`cmd-backslash-sidebar-keywindow.md`, RL-076), which this user had already confirmed fixed
in a preview build on 2026-07-27.

Root cause: `~/Library/Application Support/Kouen/settings.json` had `sidebarWidth: 0`
persisted. `MainSplitViewController.swift`, no PR/ticket (personal project, direct commit).

## Symptom

User report: "กด cmd \ แล้ว panel ไม่มา bug กว่าเดิมอีก" (press Cmd+\, panel doesn't come,
bug is even worse than before). Follow-up Q&A ruled out, in order: build mismatch (user was
on the actual installed v4.9.1, not a stale preview build), whole-window-missing vs
sidebar-only (confirmed nothing on screen changes at all, not a "whole window" issue —
user's answer was just describing "nothing visibly different anywhere"), multi-window
wrong-target resolution (only 1 window open, ruled out), shortcut/dispatch failure (menu-bar
click produces the identical no-op as the keyboard shortcut, ruling out anything
keybinding-specific).

## Root cause

`applySidebarVisibility` (`MainSplitViewController.swift:341` before the fix):

```swift
let persistedWidth = SessionCoordinator.shared.settings.sidebarWidth.map(CGFloat.init) ?? KouenDesign.sidebarWidth
let target = visible ? persistedWidth : 0
```

With `persistedWidth == 0`, `target` is `0` for BOTH `visible == true` and `visible ==
false`. `start` (the panel's current width) is also ~0 in this state. The zero-delta early
exit a few lines down:

```swift
guard abs(target - start) > 0.5 else {
    setSidebarWidth(target)
    if !visible { panel.isHidden = true }
    ...
    return
}
```

fires on every call — no animation ever starts, `panel.isHidden` only gets set on the
hide path (never un-hidden on the show path since that branch is skipped), and the visual
result is indistinguishable from a completely dead shortcut. This reproduces identically
whether triggered by keyboard or by a direct menu-item click, since both funnel through the
exact same `MenuTarget.toggleSidebar()` → `MainSplitViewController.toggleSidebar()` →
`setSidebarVisible(!visible, animated: true)` → `applySidebarVisibility` call chain — there
is no separate code path for the two triggers, which is why the falsify test (try the menu
item directly) came back identical rather than ruling anything out.

## Why `sidebarWidth` was 0

`handlePotentialUserSidebarResize()` (`MainSplitViewController.swift:566` before the fix)
persists `Float(panel.frame.width)` on any resize where `NSEvent.pressedMouseButtons & 1 !=
0` (a real drag), with no floor check. The app's own declared floor — a user drag can't
normally shrink the sidebar below 200pt — lives entirely in
`SplitChromeDelegate.constrainMinCoordinate`/`constrainMaxCoordinate`, gated on
`allowFullCollapse == false`. `allowFullCollapse` is set `true` at the top of every
`applySidebarVisibility` call (so a *programmatic* collapse/expand can reach 0) and is only
reset back to `false` once the CADisplayLink-driven animation reaches `raw >= 1`
(`animateSidebar`, ~line 424). If an animation is ever interrupted before reaching
completion, that reset never runs, and the 200pt floor stays disabled for any subsequent
real user drag — which can then reach (and persist) 0. The exact interruption trigger
wasn't reproduced live in this session; the persisted-0 value on disk was sufficient
evidence to confirm the effect and target the fix without further live reproduction.

## Why the 2026-07-27 fix validation never caught this

Per this project's own `CLAUDE.md`, `make preview` builds use their own bundle id and their
own state store — a separate `settings.json` from the release app. The user's 2026-07-27
confirmation ran against a preview build with a clean/healthy `sidebarWidth`, so it correctly
validated the keyWindow-resolution fix (RL-076) while this unrelated value-corruption bug
sat undetected in the release app's actual settings file the whole time.

## Fix

Clamp the persisted width to the same 200pt floor on both sides, via a new shared constant:

```swift
// SplitChromeDelegate
static let sidebarMinWidth: CGFloat = 200
```

Read side (`applySidebarVisibility`) — self-heals an already-corrupted 0 on the very next
toggle, no settings.json migration needed:

```swift
let persistedWidth = max(
    SplitChromeDelegate.sidebarMinWidth,
    SessionCoordinator.shared.settings.sidebarWidth.map(CGFloat.init) ?? KouenDesign.sidebarWidth
)
```

Write side (`handlePotentialUserSidebarResize`) — stops recurrence regardless of how
`allowFullCollapse` got stuck:

```swift
let width = max(Float(SplitChromeDelegate.sidebarMinWidth), Float(panel.frame.width))
```

The two pre-existing hardcoded `200` literals in `constrainMinCoordinate`/
`constrainMaxCoordinate` now reference the same constant instead of duplicating the magic
number a third and fourth time.

## How it was found

Diagnosed via `debug-mantra-workflow` + direct Q&A (repro confirmed one fact at a time:
build, symptom scope, window count, keyboard-vs-menu) rather than a debugger, since this is
a live macOS GUI app with no attached debugger session. Static code re-reading after each
ruled-out hypothesis nearly led into speculative animation-race territory before an advisor
consult redirected to the one piece of ground truth that actually discriminates: reading the
release app's real `settings.json` directly. `sidebarWidth: 0` there confirmed the
zero-delta mechanism in one step, no further live reproduction needed.

## Validation

Regression test added:
`Tests/KouenAppTests/SidebarPlacementSyncTests.swift::testCorruptedZeroSidebarWidthStillExpandsToAVisibleWidth`
— seeds `sidebarWidth = 0`, calls `setSidebarVisible(true, animated: false)`, asserts the
content pane narrows to reflect a real (200pt-floor) sidebar width rather than staying at
the full window width. `swift build --product Kouen` clean; full `KouenAppTests` suite
(242 tests) green.

User-facing validation still pending: the fix is source-only until the user rebuilds
(`make preview` or the full release flow) and reinstalls — the currently-running v4.9.1
binary predates this change and needs a rebuild to pick it up.

## Action items

- Rebuild + reinstall, confirm Cmd+\ actually shows/hides the sidebar again in the real app.
- Not fixed here, logged as a separate low-priority latent issue: `_sidebarLinkFired` still
  passes the *live* `sidebarAnimToken` into `animateSidebar` instead of a captured snapshot
  — `sidebar-cmdbackslash-toggle.md`'s "Suspect A" was never actually applied, only its
  "Suspect B" (invalidate-ordering) sibling was. Currently mitigated in practice by
  `invalidate()` running before every replacement link is scheduled, but worth a real fix if
  another sidebar-animation bug surfaces.

## Related

- `cmd-backslash-sidebar-keywindow.md` (RL-076) — same shortcut, different (already-fixed)
  root cause; this bug's own fix validation gap is exactly why that fix's confirmation
  didn't also catch this one.
- `sidebar-cmdbackslash-toggle.md` — original 2026-06-30/07-13 case file for the same
  general feature area (zero-delta trap was already a named suspect there, for a different
  triggering mechanism).
- RL-077 (`knowledge/rl-lessons.md`).
