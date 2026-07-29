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
