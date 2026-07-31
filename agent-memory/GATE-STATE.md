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
- Falsify test proposed: `make install` (rebuilds with `3afb2297`'s os.Logger calls),
  relaunch, press Cmd+\ immediately on launch (matching the reported habit), then
  `log show --predicate 'subsystem == "com.vit129.kouen" AND category == "sidebar"' --last 5m`.
  H1 predicts: `toggleSidebar()`'s log line fires with `didApplyInitialSidebarState` having
  just flipped true inside the same call (visible in log ordering — `applySidebarVisibility`
  logged twice back-to-back: once from `applyInitialSidebarState()`, once from the toggle's
  own `setSidebarVisible`), and `totalWidth` in the `applySidebarVisibility`/`setSidebarWidth`
  lines reads small (~480 region) rather than the real window width.
- Next step: waiting on user to confirm rebuild + retest to capture real log evidence.
