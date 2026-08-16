# Gate State

Open HITL gates for in-progress debug-mantra sessions. `session-start.sh` surfaces any
`Status: OPEN` entry here automatically — resume the named skill at the stated gate
instead of restarting cold. Flip to `Status: RESOLVED` (or delete the entry) once the
user answers.

---

## Gate: cmd-backslash-sidebar-toggle

- Status: RESOLVED — user confirmed fix in preview build (2026-07-27), sidebar toggles back normally
- Skill: debug-mantra-workflow
- Gate: hypothesis falsify (user testing themselves before fix)
- Bug: Cmd+\ toggles left sidebar; toggling back is unreliable ("ไม่กลับมา ต้องกดหลายทีหรือไม่กลับเลย")
- Repro confirmed: sidebar, any time, plain Cmd+\ press
- Leading hypothesis (STRONG, code evidence): `toggleSidebar()` in
  `Apps/Kouen/Sources/KouenApp/UI/Chrome/MainMenuBuilder.swift:564-570` resolves target
  window via `NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: ...)`.
  `??` short-circuits on any non-nil keyWindow. `NotchPanel`
  (`UI/Notch/NotchPanel.swift:41`) and `ComposerPanel`
  (`UI/Shared/ComposerPanel.swift:40`) are both `canBecomeKey: true` floating NSPanels —
  when either is key, `win` = that panel, `contentViewController as? MainSplitViewController`
  is nil, toggleSidebar() no-ops silently. Same file's `jumpNotification()` (line 493-502)
  already uses the correct pattern (iterate `NSApp.windows`, ignore key/main) — evidence
  this exact bug class was fixed there but missed here. `toggleSidebarPosition()`
  (line 572-577) has the identical unsafe pattern and likely shares the bug.
- Weaker hypotheses ruled unlikely on code review: animation-token race (already guarded),
  double-fire registration (no duplicate binding found).
- Falsify test given to user: open Agent Notch (Cmd+I) or Composer (Cmd+Shift+E) to make
  it key window, then press Cmd+\ — predict no visible change. Click main window, press
  Cmd+\ again — predict works.
- Next step: user runs falsify test themselves, reports back result.

---

## Gate: cmd-backslash-sidebar-zero-width

- Status: RESOLVED — user confirmed sidebar works normally again after `make install-graceful`
  rebuild (2026-07-29)
- Skill: debug-mantra-workflow
- Gate: fix validated
- Bug: Cmd+\ (Toggle Sidebar) produces zero visible change on the shipped v4.9.1 release
  build — reported worse than the prior keyWindow bug ("กด cmd \ แล้ว panel ไม่มา bug กว่าเดิมอีก").
  User confirmed: single window, keyboard shortcut AND menu-bar click both no-op
  identically, fails on the very first press (not just after N presses), persists across
  the whole session.
- Root cause CONFIRMED (not hypothesis) via direct read of
  `~/Library/Application Support/Kouen/settings.json`: `sidebarWidth: 0`. In
  `MainSplitViewController.swift:341-344` (`applySidebarVisibility`):
  `let target = visible ? persistedWidth : 0` — with `persistedWidth == 0`, `target == 0`
  regardless of direction, and `start` (current panel width) is also ~0. The zero-delta
  guard at line 373 (`guard abs(target - start) > 0.5 else { ...early exit... }`) fires
  every time — no animation, no width change, ever. `make preview` builds use a separate
  bundle id / separate `settings.json` (per project CLAUDE.md), so a preview build looks
  completely healthy while release stays broken — explains why the 2026-07-27 fix
  validation (see gate above) never caught this.
- How `sidebarWidth` reached 0: `handlePotentialUserSidebarResize()`
  (`MainSplitViewController.swift:566-578`) persists `panel.frame.width` on any real
  mouse-drag with zero clamping against the app's own declared 200pt floor
  (`SplitChromeDelegate.constrainMinCoordinate`/`constrainMaxCoordinate`,
  lines 602-623). That floor is only enforced while `allowFullCollapse == false`;
  `allowFullCollapse` is set `true` at the top of every `applySidebarVisibility` call
  and only reset to `false` when the CADisplayLink animation reaches `raw >= 1`
  (`animateSidebar`, line 424) — if an animation is ever interrupted/never completes
  normally, the floor stays disabled and a subsequent real user drag can reach 0 and get
  saved verbatim. Exact interruption trigger not yet reproduced live; the disk evidence
  (persisted 0) is sufficient to confirm effect and target the fix, per-advisor guidance
  not to chase this further before landing the primary fix.
- Related unfixed latent bug (NOT the cause here, logged for later): `_sidebarLinkFired`
  (line ~432) still passes the *live* `sidebarAnimToken` into `animateSidebar` instead of
  a captured snapshot — `sidebar-cmdbackslash-toggle.md`'s "Suspect A" fix was never
  actually applied, only the invalidate-ordering fix (Suspect B) was. Low priority,
  mitigated in practice by `invalidate()` running before every new link is scheduled.
- Proposed fix (pending user approval):
  1. Clamp `persistedWidth` to the same 200pt floor when reading it in
     `applySidebarVisibility` (`max(200, ...)`) — self-heals any already-corrupted
     `sidebarWidth: 0` on next toggle, no manual settings.json edit needed.
  2. Clamp the write side in `handlePotentialUserSidebarResize()` to never persist below
     that floor — prevents recurrence regardless of how `allowFullCollapse` got stuck.
  3. Regression test in `Tests/KouenAppTests/SidebarPlacementSyncTests.swift` asserting a
     persisted `sidebarWidth: 0` still produces a real (non-zero-delta) toggle.
- Next step: present fix + rationale to user, get approval before editing.

---

## Gate: cmd-backslash-sidebar-launch-race-6th

- Status: OPEN
- Skill: debug-mantra-workflow
- Gate: hypothesis pick (mantra step 3, before instrumented rebuild)
- Bug: 6th recurrence of Cmd+\ sidebar toggle bug, one day after the
  `cmd-backslash-sidebar-zero-width` fix (ffe984d5) was confirmed working. Same
  installed build still running (`/Applications/Kouen.app`, built 2026-07-29 14:14,
  contains the clamp fix but NOT the later os.Logger instrumentation commit
  `3afb2297` at 17:11 same day — confirmed via `log show`, zero entries for
  subsystem `com.vit129.kouen` category `sidebar`).
- Repro confirmed by user: fresh launch, first Cmd+\ press, deterministic. Symptom:
  sidebar area blank/black (terminal content pane stays intact) — matches the
  visual signature of Bug #2/#3 in `agent-memory/knowledge/bugs/sidebar-cmdbackslash-toggle.md`
  (squeeze/placement desync), NOT the zero-width case just fixed.
- Current settings.json: `sidebarWidth:319`, `sidebarVisible:false`, `sidebarOnRight:true`
  — not the zero-width state, rules out a recurrence of the just-fixed bug.
- Leading hypothesis (H1, STRONG — code evidence, not yet falsified with real log data):
  `toggleSidebar()` (`MainSplitViewController.swift:490-498`) has its own inline
  fallback: `if !didApplyInitialSidebarState { didApplyInitialSidebarState = true;
  applyInitialSidebarState() }`. This bypasses the guard added for Bug #3
  (`viewDidLayout()`'s `guard view.window?.isVisible == true` at line 190) — that guard
  only protects the `viewDidLayout()` call site, not this one. If the user presses
  Cmd+\ immediately after launch (their actual habit per this report), before AppKit's
  first `viewDidLayout()` pass with a visible window has run, `toggleSidebar()` calls
  `applyInitialSidebarState()` itself against the transient 480×400 `minSize` window —
  reproducing the exact race Bug #3 already diagnosed (divider math correct per-frame,
  final width still wrong because it races the window's async resize-to-real-size),
  just via a second, unguarded call site the original fix missed.
- Weaker hypotheses: H2 sidebarOnRight physical/flag desync (Bug #2 pattern) — unlikely,
  no Settings change this session, `sidebarOnRight` consistent in settings.json. H3 pure
  `setSidebarWidth` totalWidth=0 defer race — `setSidebarWidth` re-reads `split.bounds.width`
  live each call (not captured stale), so this alone should self-heal within a runloop
  turn; less likely to explain a fully blank/black sidebar than H1.
- Not yet falsified — no real Console log data exists for this incident since the running
  binary predates the instrumentation commit. Per mantra step 2 (escalate to in-code
  instrumentation only after debugger/source-trace), instrumentation already exists in
  source but isn't in the running build — next step is a real data point, not another
  code-only guess (5 prior root causes on this exact shortcut already).
- Falsify test proposed (ORIGINAL PLAN, CORRECTED 2026-08-16 — see below): `make install`
  (rebuilds with `3afb2297`'s os.Logger calls), relaunch, press Cmd+\ immediately on
  launch, then `log show --predicate 'subsystem == "com.vit129.kouen" AND category ==
  "sidebar"' --last 5m`. **This exact command is unrunnable by construction** — every
  `sidebarLog` call in `MainSplitViewController.swift` uses `.debug()` level, and macOS
  unified logging never persists Debug/Info level to the on-disk store `log show` reads
  from (only Default/Error/Fault are persisted). Confirmed empirically 2026-08-16: user's
  installed build (4.12.1/227, well past `3afb2297`) pressed Cmd+\ multiple times,
  `log show` over 30 minutes returned zero rows for the whole subsystem. Correct tool is
  `log stream --predicate '...' --level debug`, run live in the background *while* the
  user reproduces, e.g.:
  `/usr/bin/log stream --predicate 'subsystem == "com.vit129.kouen" AND category ==
  "sidebar"' --level debug --info > out.txt & PID=$!; <user reproduces>; kill $PID`
  (macOS has no `timeout` binary by default — use the background+kill pattern, not
  `timeout N log stream ...`). Update any future falsify plan on this shortcut to use
  `log stream`, not `log show`.

### Recurrence 2026-08-15/16 — 7th occurrence, real log data captured

User reported "cmd\ กลับมาเป็นอีกแล้ว" (2026-08-15) while a separate gate
(`browser-pane-intermittent-black-screen`, fix-approval pending) was mid-conversation
and unresolved — that gate stays parked, un-touched, waiting on the user's go/no-go on
the one-line `createTab()` fix already shown to them.

Using the corrected `log stream` method above, captured 3 toggle events live
(2026-08-16 08:31:55–08:32:01, user confirmed hitting the visual bug during this
window — "รอบนี้เห็นอาการจริงๆ"):
- Press 1 (08:31:55.692): `toggleSidebar() currentVisible=false` → `applySidebarVisibility
  visible=true target=200 totalWidth=1440` → smooth animation 0→200, final
  `setPosition=1240.0`. Numerically clean.
- Press 2 (08:31:56.427): `toggleSidebar() currentVisible=true` → hides, target=0,
  totalWidth=1440 → smooth animation 199→0, final `setPosition=1440.0`. Numerically clean.
- Press 3 (08:32:01.571): `toggleSidebar() currentVisible=false` → shows, target=200,
  **totalWidth=1920** (jumped from 1440) → smooth animation 0→200, final
  `setPosition=1720.0`. Numerically clean.
- All 3: `persistedWidth=200`, `sidebarOnRight=true`, `keyWindow=true` throughout — none
  of the 5 previously-fixed root causes (zero-width, keyWindow chain, launch race) are
  present in this data. Full raw capture was in session scratchpad
  (`sidebar-log-stream.txt`, ephemeral) — reproduced verbatim above since that path does
  not survive a session boundary.
- User confirmed between press 2 and 3 they moved the window to another display /
  connected an additional display — coincides exactly with the totalWidth jump.

Candidate H4 (screen/display change leaves the sidebar panel's layer stale, not
repainted — same *family* as the WKWebView compositor-commit bug just fixed in the
browser pane, but unconfirmed for this code path): **NOT YET CONFIRMED.** Two problems
per advisor review, both open:
1. Never established *which* of the 3 presses the user actually saw the black/missing
   sidebar on — "saw it somewhere in these 3" was confirmed, not "saw it on press 3
   specifically." If it was press 1 or 2 (both at totalWidth=1440, before any display
   change), H4 is dead on arrival.
2. Contradicts this file's own `cmd-backslash-sidebar-launch-race-6th` gate above, whose
   repro was "fresh launch, first Cmd+\ press, deterministic" — no display change
   involved at all. A hypothesis must hold for every prior breadcrumb (mantra step 4);
   H4 as currently stated does not. At best this is a second, distinct trigger on a
   shortcut with 5 already-fixed root causes — do not present it as "the" root cause
   without saying that explicitly.
- Grepped for `didChangeScreenParameters`/`didChangeBackingProperties` near
  `MainSplitViewController.swift` — none found (only an unrelated `NotchPanelController`
  listener). Noted as a WEAK signal only — AppKit often handles backing-scale/screen
  transitions via `viewDidChangeBackingProperties` with no explicit observer needed, so
  absence of a handler is not itself a defect. Also the glob used
  (`Apps/Kouen/Sources/KouenApp/**/*.swift`) may not have expanded recursively — "nowhere
  in the app" is under-verified, only `MainSplitViewController.swift` itself is solid.
- Next step (blocking any sidebar code change): ask the user directly which press showed
  the bug (1st / 2nd / the one right after the display change), and separately whether it
  was "moved to another screen" vs "connected a new display" (different code paths —
  the latter fires `NSApplication.didChangeScreenParametersNotification` app-wide and can
  resize windows with no direct user action). Then run a control: same `log stream` +
  kill-by-pid setup, 8-10 toggles with the window untouched and no display changes. If
  black still appears with zero screen changes, H4 is falsified and the trigger is
  something else in the paint/redraw family, unrelated to screen changes.

**Control result (voided, not negative):** user mashed ~8-10 presses at 150-450ms
against the animation's own ~240ms duration — confounded, tests "rapid re-toggle
mid-animation" not "steady toggle, no display change." Captured log's final state
(hidden, `width=0`) is fully explained by toggle parity, not a stuck/black bug — not
usable as control evidence either way. Do NOT reopen a "rapid-toggle interruption"
hypothesis from this artifact; it was introduced by the test procedure, not a user
report. One real finding survives from this capture though: `applySidebarVisibility`'s
`start = panel.frame.width` (`MainSplitViewController.swift:386`) read `0.000000`
within ~115ms of a show animation that had just logged completing to `width=200.000000`
— i.e. the panel's real frame reverted to 0 with no toggle in between. Not yet
explained; parked, not chased further (see clean single-press result below, which
answers the blocking question more cheaply).

**Clean single press (2026-08-16, decisive):** user pressed once, unhurried, gave a
direct visual report: sidebar panel appeared but fully black/empty. Window was still on
an external/secondary display from the earlier screen-change repro. **Moving the
window back to the built-in MacBook display fixed it immediately** — sidebar renders
normally there. This is stronger than "screen change" as the trigger — it's "currently
rendering on a non-primary/external display," persisting for as long as the window
stays there, not just a one-shot race right after the move. Consistent with a
backing-scale-factor or color-profile mismatch between displays where the sidebar
panel's layer never gets told to redraw/rescale for the display it's actually on
(`viewDidChangeBackingProperties`-class bug — AppKit normally handles this per-view
automatically, but a custom layer-backed subview can need to force its own redraw if
something upstream suppresses or races the automatic path).

**Status: H4 CONFIRMED as a real, reproducible trigger** — distinct from, and does NOT
explain, the still-separately-open `cmd-backslash-sidebar-launch-race-6th` gate above
(that repro is fresh-launch/first-press with no display involved at all). Two
independent trigger paths on the same shortcut/symptom; do not conflate them or claim
one fix closes both.

- Next step: consult on the correct, minimal mechanism to force the sidebar panel to
  redraw when the window is/becomes resident on a non-primary display, before writing
  any fix. `sidebarContainerView` (`MainSplitViewController.swift:517`) is a plain
  `NSView` (`split.subviews[sidebarContainerIndex]`), not a custom subclass — no
  existing override point for `viewDidChangeBackingProperties()`. Options to weigh:
  override on a subclass, observe `NSWindow.didChangeScreenNotification`, or hook into
  the same `NSApplication.didChangeScreenParametersNotification` already used (for an
  unrelated purpose) by `NotchPanelController.swift:77`. Get user approval on the
  chosen approach before editing (fix-approval gate — same discipline as the browser
  pane fix above, which is still separately parked awaiting the user's go/no-go).

**Correction (still 2026-08-16, same session):** the "display-related, backing-scale"
framing above is WRONG — dropped. Discriminator asked: when black, does the terminal
content area shrink to make room for the sidebar, or stay full-size? User answered
**full-size, unchanged** — meaning the divider never actually moved; the sidebar's real
allocated width is ~0, not "200pt but painted black." So this is the `start=0.000000`
finding from the earlier capture (a *live* `panel.frame.width` read, not stale/cached),
now explained without any display-scale theory: `setSidebarWidth()`
(`MainSplitViewController.swift:556-572`) calls `split.setPosition(position, ofDividerAt:
0)`, which is **advisory** — `NSSplitView` routes it through
`SplitChromeDelegate.splitView(_:constrainMinCoordinate/MaxCoordinate:ofSubviewAt:)`
(L635-656) before applying it, and our logging only records what was *asked*
(`setSidebarWidth width=... -> setPosition=...`), never what the split view actually
*accepted*. `constrainMinCoordinate` for `sidebarOnRight=true` (L636-640) computes
`splitView.bounds.width - 320` **live, read again independently inside the delegate
callback** — a second read of the same total-width value `setSidebarWidth` already read
earlier in the same call. If a screen/display change is mid-transition (window
resizing to fit the new display) when `setPosition` is invoked, these two reads of
`splitView.bounds.width` can disagree — `setSidebarWidth` computes `position=1720`
against the new width (1920), but the delegate's own live re-read could still see a
stale/transitional bounds value, clamping the divider back near the collapsed edge with
no error, no log line, nothing to show the request was rejected. This fits every
breadcrumb: log says width=200/position=1720 was asked for, screen shows the divider
never moved, no crash/banner, only during/after a display transition.
- **NOT YET CONFIRMED** — this is a strong mechanism from a direct code read
  (`SplitChromeDelegate`, L617-674), not yet proven with a live "asked vs accepted"
  data point. Per mantra step 2, the next escalation is one more targeted log line, not
  more pure inference or another AskUserQuestion round: add `panel.frame.width` /
  `content.view.frame.width` to the existing debug line in `setSidebarWidth`, right
  after `split.setPosition(...)`, rebuild (`make install`), and capture one more
  `log stream` round on the external display. If accepted width matches asked width,
  this mechanism is dead and the search continues elsewhere in the delegate/layout path;
  if it doesn't match, this is the confirmed root cause.
- 1920-vs-external-display confound (noted, not yet resolved): every black observation
  in this session was at `totalWidth=1920` (the external display's logical width) and
  every clean one at `1440` (assumed built-in). Display identity and window width moved
  together in every sample so far — not separated. Do not resolve this with another
  user experiment before the instrumented rebuild above; if the delegate-clamp theory is
  confirmed, width is the operative variable and display identity is incidental, so the
  confound dissolves without needing a separate test.
- Do NOT pursue a `viewDidChangeBackingProperties`/`didChangeScreenNotification`/
  `didChangeScreenParametersNotification` fix for this gate — that was this session's
  first-pass theory, dropped once the shrink/no-shrink answer came back. No evidence for
  a paint/backing-scale bug remains; `system_profiler` did confirm the two displays have
  different backing scale (2x built-in vs 1x external, so that notification would have
  fired) but the geometry answer means it isn't the relevant mechanism here.
- Next step: waiting on user decision to add the instrumentation line + rebuild + retest
  (real build/wait cost, unlike the live MCP/log-stream checks used everywhere else this
  session). The original, still-separately-unanswered item from earlier in this same
  session: the browser pane `createTab()` one-line `allowsMagnification = true` fix
  (`browser-pane-intermittent-black-screen` gate above) — user asked to see more code,
  it was shown, no go/no-go given yet. Re-ask both together.

**Both approved 2026-08-16 ("ทำเลย" x2) — instrumentation applied, fix still pending
on real data:**
- Added `sidebarLog.debug("setSidebarWidth accepted panelWidth=... contentWidth=...
  (asked width=...)")` right after `split.setPosition(...)` in `setSidebarWidth()`
  (`MainSplitViewController.swift:570-575`). `swift build --product Kouen` clean.
- Next step (unchanged): user runs `make install`, moves the window to the external
  display, reproduces the black sidebar, captures one more `log stream --level debug`
  round (same pattern as this session's earlier captures), and reports the
  `accepted panelWidth=` value on the failing toggle. If it's ~0 while `asked width=200`,
  the `SplitChromeDelegate` clamp theory is confirmed and the fix targets the
  constrain-method's `splitView.bounds.width` re-read; if it matches, this mechanism is
  dead and the search resumes elsewhere. No sidebar behavior fix has been written yet —
  only the diagnostic line.

---

## Gate: kouen-browser-mcp-intermittent-unresponsive

- Status: OPEN
- Skill: debug-mantra-workflow
- Gate: hypothesis pick (mantra step 1, no reliable repro yet)
- Bug: `mcp__kouen__kouenBrowser*` MCP tools (Claude calling them) sometimes
  unresponsive. User unsure if it's a hang or an error after wait ("ไม่แน่ใจอาจจะ
  2,3" — timeout error / other error, ruled out silent-hang-only). App
  foreground/background state at time of failure also unconfirmed ("1,2").
- Repro: NOT reliable. Live test this session (`kouenBrowserOpen` on
  `https://example.com`) succeeded fast — could not reproduce on demand.
- Confirmed precondition (user, live): routinely runs 4+ Kouen windows/sessions
  simultaneously (matches `kouenList` output this session — 4 sessions across
  1 workspace).
- Leading hypothesis (H1, code-grounded, precondition confirmed live, not yet
  falsified with a real failure capture): `DaemonSyncService` is per-window
  (`Apps/Kouen/Sources/KouenApp/Services/DaemonSyncService.swift:10,20` —
  `init(coordinator: SessionCoordinator)`), each window independently calls
  `client.subscribeSnapshot(label: "KouenGUI", ...)` (line 37-38) with the
  identical literal label. Daemon-side `guiBrowserFD`
  (`Packages/KouenDaemon/Sources/KouenDaemon/DaemonServer.swift:66-69`) resolves
  via `snapshotSubscribers.first(where: { clients[$0]?.label == "KouenGUI" })`
  — `Set<Int32>` has no defined iteration order, so with N windows open, an
  arbitrary one is picked per request. Normally harmless because
  `BrowserPaneRegistry.shared` (`DaemonSyncService.swift` handler) is a
  process-global singleton — whichever window's `onBrowserRequest` closure
  fires can still resolve the target `paneID`. Suspected failure mode: the
  picked window is mid-close/deinit exactly when routed to (race), or its
  `Task { @MainActor in ... }` closure fires but the window's own state is
  already torn down — daemon-side cleanup on a *clean* disconnect already
  fails pending requests immediately with "GUI disconnected"
  (`DaemonServer.swift:830-837`, confirmed correct), so a genuine 30s-then-error
  ("Request timed out", `DaemonServer.swift:865-871`) implies the picked fd's
  socket stayed open (no EOF detected) while nothing on that window's side
  actually processed the request.
- Weaker hypotheses: H2 App Nap-style scheduling delay when all windows are
  backgrounded (no code gate found confirming this — unverified). H3 daemon
  restarted and GUI hasn't resubscribed yet (`guiBrowserFD` nil →
  immediate "Kouen GUI is not running or connected" error, not a 30s wait —
  distinguishable from H1/H2 by whether the error is instant or ~30s later).
- User declined adding diagnostic logging at `guiBrowserFD` proactively
  ("รอซ้ำโดยไม่เพิ่ม log (แนะนำ)") — waiting for a real occurrence instead.
- Next step: next time it happens, capture (a) exact error text or confirm
  silent hang, (b) how many Kouen windows were open, (c) whether the failing
  window was mid-close, (d) elapsed wait time (~instant vs ~30s) — this alone
  disambiguates H1/H2 vs H3. Resume debug-mantra-workflow at this gate with
  that capture; do not re-derive the hypothesis list from scratch.

---

## Gate: browser-pane-intermittent-black-screen

- Status: OPEN
- Skill: debug-mantra-workflow
- Gate: fix approval (before editing code)
- Bug: Kouen's embedded browser pane (`BrowserPaneView`, WKWebView-based) sometimes
  renders a fully solid-black content area on navigation — chrome (address bar, tab
  bar) renders fine, only the WKWebView content is black. Reported on a Facebook
  group permalink URL (screenshot attached by user), but nature of the bug (see
  below) is page-agnostic — any page can hit it.
- Repro confirmed by user: intermittent ("บางทีก็เป็นสีดำ" — sometimes black, not
  always). Diagnostic question asked: does reload fix it? User answered "Reload
  แก้ได้เสมอ" (reload always fixes it) — this was the falsify test for the
  Facebook-blocking/crash hypothesis (H3/H4 below): a genuine server-side block or
  page-JS crash would very likely re-trigger on reload of the same URL; consistently
  fixing on reload does not fit that pattern, so H3/H4 are considered disproven.
- Root cause (STRONG, code evidence):
  `Apps/Kouen/Sources/KouenApp/UI/Chrome/BrowserPaneView.swift` `setupUI()`:
  - L188-190: `webView.setValue(false, forKey: "drawsBackground")` +
    `webView.setValue(NSColor.clear, forKey: "underPageBackgroundColor")` — makes the
    WKWebView's own CALayer fully transparent. Comment says intent is only "prevents
    initial white background paint/flash" (i.e. transient), but the setting is never
    reverted after the page loads.
  - L258-260: the pane's container view is painted a **solid** color,
    `KouenChrome.current.terminalBackground` (the active terminal theme's background
    — black/near-black for dark themes) — this is what shows through the transparent
    WKWebView when its own content hasn't been composited to screen yet.
  - `didFinish` (L1252-1271) never forces a repaint/compositor commit of the
    main-frame webview. There is already an analogous, working fix for a related
    WebKit compositor-commit bug in the same file:
    `kickCompositorRelayout(for:)` (L683-694) forces a magnification nudge to make
    WebKit commit a pending layer change — currently only wired to a nested-iframe
    scroll-tree-commit bug (JS message `kouenCompositorKick`, fired on
    pointermove/wheel inside a nested cross-origin iframe), per a documented P35
    investigation (`agent-memory/knowledge/ui/browser-pane.md`). It is NOT called
    from `didFinish` for the main frame's own initial paint.
  - Comment at L1267-1269 explicitly explains why a "blind post-load timer" kick was
    rejected for the iframe case (races the iframe's async mount) — that reasoning is
    iframe-specific and does not apply to the top-level frame, which by the time
    `didFinish` fires has genuinely finished its own navigation.
  - Transparency was introduced in commit `157e5aa64` ("fix(macos27): restore Liquid
    Glass transparency pipeline and finish browser-pane chrome", 2026-07-26,
    Vit129) — before that, no solid-canvas-behind-transparent-webview pairing
    existed.
- Mechanism: WKWebView is transparent by design; reload forces a fresh
  navigation+layout+full compositor setup that reliably paints. First paint on a
  freshly created/warmed webview occasionally loses the race — content finishes
  loading (`didFinish` fires, URL bar updates correctly) but the visible CALayer is
  never actually committed/flushed to screen, leaving the solid dark container color
  showing through indefinitely until something forces a repaint (manual reload).
- Weaker/ruled-out hypotheses: H3 Facebook detecting embedded WKWebView / blocking —
  disproven by reload always fixing it (see above). H4 Kouen's injected
  console/network-capture scripts crashing Facebook's JS before it paints — same
  disproof applies (a JS crash would very likely reproduce identically on reload).
- No prior-art in `agent-memory/knowledge/` specifically for this (checked
  `PLAYBOOK.md`, `knowledge/bugs/`, `rl-lessons.md` — only unrelated Metal/iframe
  entries found).
- Fix applied (user approved "ทำเลย"): `kickCompositorRelayout(for: webView)` now
  called at the end of `didFinish` (after `applyWebDarkMode()`, before
  `completeLoading()`) in `BrowserPaneView.swift`.
- Verification so far: `swift build --product Kouen` clean (no new warnings).
  Regression test added — `Tests/KouenAppTests/BrowserPaneViewTests.swift`
  `testDidFinishTriggersCompositorKickToForcePaint` (tracks `setMagnification` calls
  on a `MockWebView`, asserts `didFinish` triggers at least one) — passes, along
  with the full `BrowserPaneViewTests` suite (10/10). This proves the wiring is
  correct; it does NOT prove the real WKWebView compositor bug is fixed (can't be
  unit-tested — needs a real running build).
- Next step: user rebuilds (`make preview` or `make install`) and re-tests the
  original repro (reopen the same/any slow-loading page a few times) to confirm the
  black screen no longer occurs. Gate stays OPEN until user confirms in the real
  app — this is the "fix validated" gate, not "fix approval" (already passed).

---

### Recurrence 2026-08-14 — distinct trigger, same root mechanism

User confirmed running v4.12.1 build 227 (verified via `defaults read
/Applications/Kouen.app/Contents/Info.plist`, PID matches the live process) — NOT a
stale-build report. Still hits a black content area.

New repro details (differ from the original gate above — breaks its old
"reload always fixes it" finding):
- Reload/refresh no longer helps at all. Only closing the whole browser pane and
  reopening fixes it.
- Happens on the 2nd/3rd tab opened within an existing pane (Cmd+T, or a link/
  window.open that pops a new tab) — not on a brand-new pane's first tab.
- Random across many sites, not one specific site.
- No "Page crashed, reloading…" banner appears (rules out
  `webViewWebContentProcessDidTerminate` crash-loop as the trigger).

Root cause (STRONG, code evidence, falsification test passed):
`createTab()` (`Apps/Kouen/Sources/KouenApp/UI/Chrome/BrowserPaneView.swift:430-495`)
constructs the new tab's `WKWebView` but never sets `allowsMagnification = true` on
it — unlike the pane's first tab, which always gets it set (either via the warm pool
at L1339, or fresh creation at L94). `kickCompositorRelayout(for:)` (the v4.12.1 fix,
called from `didFinish` at L1277) guards on `webView.allowsMagnification` (L684) and
silently no-ops when false. So for every tab opened via `createTab()`, the v4.12.1
fix never actually runs — `didFinish` fires, the guard fails, nothing forces the
compositor commit. Reload just re-triggers the same no-op guard every time, which is
exactly why reload stopped helping for this case. Closing the pane works because a
fresh pane's first tab always goes through the correctly-flagged init path.

Ranked hypotheses: H1 (above) confirmed by disproof test — user confirmed the black
screen only occurs on 2nd/3rd tabs in an existing pane, never a fresh pane's first
tab, and no crash banner appeared. H2 (shared `compositorKickInFlight` flag racing
across tabs loading close together) — too weak, self-clears in 50ms, doesn't explain
"reload never helps." H3 (WKContent process crash loop) — disproven, no banner shown
and that path already auto-reloads.

Consistent with the original 2026-08-13 finding: that repro was always the pane's
own first tab (correctly flagged), which is why reload reliably fixed it there and
why the didFinish kick fixed it for good. This is an adjacent gap in the same fix,
not a contradiction.

- Fix applied 2026-08-16 (user approved "ทำเลย"): added
  `newWeb.allowsMagnification = true` in `createTab()`
  (`BrowserPaneView.swift`, right after `newWeb.appearance = ...`), mirroring the two
  other WKWebView-creation call sites (L94, L1339). Regression test added —
  `Tests/KouenAppTests/BrowserPaneViewTests.swift`
  `testCreateTabSetsAllowsMagnificationForCompositorKick` (asserts the webview returned
  by `createTab()` has `allowsMagnification == true`). `swift build --product Kouen`
  clean; full `BrowserPaneViewTests` suite passes (11/11, includes the new test).
- Next step: user rebuilds (`make preview` or `make install`) and re-tests opening a
  2nd/3rd tab in an existing pane a few times to confirm the black screen no longer
  occurs there. Gate stays OPEN until confirmed in the real app.
