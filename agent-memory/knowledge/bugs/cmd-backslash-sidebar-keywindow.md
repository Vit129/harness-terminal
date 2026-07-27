# Post-mortem: Cmd+\ sidebar toggle unreliable (2026-07-27)

## Summary

`Cmd+\` (Toggle Sidebar) resolved its target window via a `keyWindow ?? mainWindow ??
.first(where:...)` chain that silently no-op'd whenever a floating panel (Agent Notch or
Composer) held key-window focus. First press worked (main window was still key at that
point); every press after the user's focus moved to a floating panel did nothing. Fixed by
having `MenuTarget.toggleSidebar()` / `toggleSidebarPosition()` iterate `NSApp.windows`
unconditionally instead of consulting `keyWindow`/`mainWindow` at all.
`Apps/Kouen/Sources/KouenApp/UI/Chrome/MainMenuBuilder.swift`, no PR/ticket (personal
project, direct commit).

## Symptom

User report: "กด cmd+\ แล้ว panel หายไป" (press Cmd+\, panel disappears), then on
follow-up: "กด Cmd+Backslash แล้วก็ไม่กลับมา" (press it again, it doesn't come back) —
"ไม่กลับมา ต้องกดหลายทีหรือไม่กลับเลย" (doesn't come back, needs many presses or never
comes back at all). Sidebar hides on the first press, then stops responding to the
shortcut.

## Root cause

`toggleSidebar()` and `toggleSidebarPosition()` in `MainMenuBuilder.swift` (lines
564-577 before the fix) resolved their target window as:

```swift
let win = NSApp.keyWindow ?? NSApp.mainWindow
    ?? NSApp.windows.first(where: { $0.contentViewController is MainSplitViewController })
if let split = win?.contentViewController as? MainSplitViewController {
    split.toggleSidebar()
}
```

`??` only falls through when the left side is `nil`. `NotchPanel`
(`UI/Notch/NotchPanel.swift:41`, `canBecomeKey: true`) and `ComposerPanel`
(`UI/Shared/ComposerPanel.swift:40`, `canBecomeKey: true`) are both `.nonactivatingPanel`
floating panels that can become the app's `keyWindow` without stealing app activation.
The moment either has focus, `NSApp.keyWindow` is that panel — non-nil, so the chain
stops there and never reaches `mainWindow` or the `.first(where:)` fallback. `win` is the
panel; `win?.contentViewController as? MainSplitViewController` is `nil`; the whole
function body is skipped. The shortcut fires (it's a registered `NSMenuItem`
keyEquivalent), it just does nothing.

This exact `keyWindow ?? mainWindow ?? .first(where:...)` chain was originally introduced
as the fix for RL-039 (`agent-memory/knowledge/rl-lessons.md`): menu `@objc` actions
failing before the user's first click, because `keyWindow` is `nil` right after launch.
That fix only handles `keyWindow == nil` — it has no answer for `keyWindow` being
non-nil but wrong, which is exactly what a `canBecomeKey` floating panel produces.

## Why it produced the symptom

The sidebar's own toggle logic (`MainSplitViewController.toggleSidebar()`,
`setSidebarVisible(_:animated:)`) is correct in both directions — verified by the
pre-existing `SidebarPlacementSyncTests.swift` suite, none of which touch this bug. The
break is one layer up, in `MenuTarget`'s window resolution, which never reaches
`MainSplitViewController` at all once a floating panel is key. The user doesn't see "my
shortcut didn't fire" — they see "sidebar came back once, then Cmd+\ stopped working,"
because the app spends most of its time with the Agent Notch or Composer having stolen
key-window status via ordinary interaction (opening the notch, typing in the composer).

## Fix

Both functions now iterate `NSApp.windows` unconditionally and act on the first window
whose `contentViewController` is `MainSplitViewController`, dropping `keyWindow`/
`mainWindow` from the resolution entirely:

```swift
@objc func toggleSidebar() {
    for window in NSApp.windows {
        if let split = window.contentViewController as? MainSplitViewController {
            split.toggleSidebar()
            return
        }
    }
}
```

(Same pattern for `toggleSidebarPosition()`.) This is not a new pattern in this file —
`jumpNotification()` (`MainMenuBuilder.swift:493-502`) already used exactly this loop, for
unrelated reasons, and never had this bug. The fix generalizes RL-039's original fix
rather than regressing it: type-match iteration doesn't care whether `keyWindow` is nil,
wrong, or absent, so the "menu action fails before first click" case RL-039 fixed still
works (the loop finds the window by type regardless of key/main status), and the new
"floating panel is key" case is now also covered.

No prior fix attempt existed for this specific case — RL-039's chain was the first and
only attempt, and it simply never covered floating panels.

## How it was found

Repro confirmed via direct Q&A with the user (which panel, does a second press restore
it) rather than a debugger, since this is a UI-interaction bug in a macOS app with no
attached debugger session. Fail path traced via static code search: grepped
`BannerShortcutRegistry.swift` to confirm `Cmd+\` is a real, intentional "Toggle Sidebar"
binding (`keyChar: "\\"`, `modifiers: .command`, line 170-172) rather than an accidental
side effect; then grepped every `NSApp.keyWindow`/`mainWindow` usage in
`MainMenuBuilder.swift` to find the window-resolution code actually wired to that menu
item.

Hypotheses considered: (1) key-window resolution stopping at a floating panel — strong,
directly explained by the `??` short-circuit and the two `canBecomeKey` panels; (2)
`CADisplayLink`/animation-token race in `applySidebarVisibility` leaving `isHidden` stuck
— rejected on code read, the existing `sidebarAnimToken` guard already handles stale
animation frames correctly, no gap found; (3) duplicate/double-firing shortcut
registration — rejected, grepped for a second registration of the same `NSMenuItem`
action or a competing local event monitor and found none.

Single experiment that confirmed it: `jumpNotification()` in the same file resolves its
window by looping `NSApp.windows` and ignoring key/main status entirely — it has no
history of this bug. `toggleSidebar()`/`toggleSidebarPosition()` are the only two window-
resolving `@objc` actions in the file still using the `keyWindow ?? mainWindow` chain,
directly correlating "uses the fragile chain" with "has the bug" and "uses the robust
loop" with "doesn't have the bug."

## Why it slipped through

Incomplete prior fix. RL-039's chain fixed the `keyWindow == nil` case it was written
for, but the fix wasn't generalized to the `keyWindow` non-nil-but-wrong case, and
`jumpNotification()`'s correct loop-based pattern existed in the same file without anyone
noticing the other two functions could reuse it. No CI/test gap is the primary cause here
— this is a UI-focus interaction bug in an AppKit menu action, a class of bug this
project's test suite (XCTest, off-window by design; Robot Framework, AX-identifier driven)
doesn't currently have machinery to exercise for arbitrary window-focus states.

## Validation

Manually validated by the user in a real `make preview` build (isolated preview bundle,
own socket/state) — confirmed the sidebar toggles back to visible via Cmd+\ after the fix,
where before the fix it would not reliably come back. `swift build --product Kouen`
compiles clean. Not validated: production (`make prod`) build specifically — not expected
to differ, since the fix is pure source logic with no build-configuration dependency, but
this was reasoned about, not separately re-tested. Not validated: an automated regression
test (see Action Items) — coverage for this specific fix currently rests entirely on the
one manual QA pass described above plus the RL lesson recorded below.

## Action items

- Regression test attempted, not landed: an XCTest simulating a floating `NSPanel`
  stealing `keyWindow` alongside a real `NSWindow`+`MainSplitViewController`
  (`Tests/KouenAppTests/SidebarPlacementSyncTests.swift`) crashed (SIGSEGV) during
  `NSWindow`/`MainSplitViewController` deinit in this session's execution environment (a
  background CLI job with no real WindowServer/GPU session for the Metal terminal
  renderer's teardown to talk to) — isolated via step-by-step debug prints showing the
  crash happens after all test logic completes successfully, purely during
  teardown/dealloc. Confirmed as an environment limitation, not a code bug, by
  progressively simplifying the test: bare `NSWindow` construction succeeds,
  `NSApp.windows` registration succeeds, but `orderFront`/`makeKeyAndOrderFront` and
  `MainSplitViewController`+`NSWindow` dealloc both crash regardless of test content. The
  addition was reverted rather than committed crashing or environment-fragile. Whoever
  picks this up next should attempt it from a real interactive macOS session (not a
  headless/background job) where `swift test` has genuine WindowServer/GPU access — no
  owner assigned yet.
- CI gap not closed: a Robot Framework GUI-level test (matching
  `Tests/KouenRobotTests/suites/keybinding_crash_regression.robot`'s style) would be the
  more appropriate test type for this defect class (real keyboard focus, real panels),
  but needs new AX accessibility identifiers on the sidebar/notch/composer views that
  don't exist today — out of scope for this fix. No owner assigned yet.
- Lesson captured: `agent-memory/knowledge/rl-lessons.md` RL-076, cross-referencing
  RL-039, so the next AppKit menu action added in this file starts from the
  `NSApp.windows`-loop pattern rather than rediscovering the `keyWindow ?? mainWindow`
  trap.
- Related, not filed: no other `@objc` menu action in `MainMenuBuilder.swift` was found
  reusing the broken `keyWindow ?? mainWindow` chain during this pass (grepped all
  `NSApp.keyWindow`/`mainWindow` usages in the file) — `toggleSidebar`/
  `toggleSidebarPosition` were the only two.
