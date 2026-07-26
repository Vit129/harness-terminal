# Playbook — harness-terminal

All resolved cases live in `knowledge/cases/` — grep there first.

## Grep Command

```bash
grep -rn "<keyword>" agent-memory/knowledge/cases/ agent-memory/knowledge/rl-lessons.md
```

## Case Index

| File | Domain |
|------|--------|
| `knowledge/cases/appkit-ui.md` | AppKit, NSSplitView, NSPanel, NSAlert, NSButton, sidebar |
| `knowledge/cases/metal-displaylink.md` | Metal, CADisplayLink, black screen, flicker |
| `knowledge/cases/swift6-concurrency.md` | Swift 6, zombie, @Observable, nonisolated, assumeIsolated |
| `knowledge/cases/remote-ssh.md` | SSH tunnel, remote host, P23 |
| `knowledge/cases/misc.md` | Git/FS, terminal/renderer, keybindings, command prompt, Claude Code config (CASE-057: settings.json whole-file reject + PTY diagnostic) |
| `knowledge/cases/cwd-worktree-bleed.md` | cwd/worktree, deepest-descendant, tab pill/file tree/git panel wrong dir during builds |
| `knowledge/bugs/tab-switch-black-screen.md` | Tab switch black screen — 4 FM deep dive, final fix pattern |
| `knowledge/bugs/browser-pane-local-daemon-merge.md` | Browser pane vs daemon pane-tree sync — 2nd recurrence (2026-06-15, 2026-07-23), same broken merge condition each time |
| `knowledge/bugs/p8-liquid-glass-chrome-regressions.md` | P8 macOS27 Liquid Glass: transparency hardcoded off, chrome double-tint, un-unified tab-bar chrome, ANSI-art contrast-floor corruption (CASE-066) |
| `knowledge/rl-lessons.md` | All RL-xxx prevention lessons |

## Open Cases

| ID | Trigger | Status |
|----|---------|--------|
| CASE-038 | NSClickGestureRecognizer intercepts NSButton clicks | OPEN — see `knowledge/cases/appkit-ui.md` for workaround |
