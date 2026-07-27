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
