# Harness Terminal — IDE Sidebar Feature Branch

## Overview

This branch adds IDE-like sidebar functionality to Harness Terminal, transforming it from a pure terminal multiplexer into a terminal-first IDE. Inspired by Zed and SourceTree.

## Features

### Files Tab
- **Project-aware file tree** — root follows the active session's cwd
- **Right-click context menu** — Copy Path / Copy Relative Path
- **Drag & drop** — drag files from tree into terminal to paste the path
- **NSOutlineView** with lazy directory expansion

### Git Tab (Zed-style)
- **Changes / History** tab switcher with change count badge
- **Stage/unstage** checkboxes per file
- **Stage All** button
- **Commit message** text area with **Commit ▼** menu — Commit Tracked, Amend, Signoff
- **History view** — SourceTree-style commit cards (subject + author · time · hash)
- **Branch switcher** — click branch name to see dropdown of all branches
- **Sync button** (Fetch ▼ / Push ▼) — contextual menu: Fetch, Fetch From (per-remote), Pull, Pull (Rebase), Push, Push To (per-remote), Force Push; auto-switches to "Push" when ahead of upstream

### CMUX Pane Splitting
- **Drag surface tabs** between panes to split left/right
- **Drop overlay** — accent-colored half-pane highlight shows where the split will land
- **Ratio preservation** — custom split ratios persist across tab switches and rebuilds (CASE-002 fix)
- **Sidebar position** — toggle sidebar left/right via View menu, right-click toggle button, or session context menu (real-time, no restart)

### Session Management
- **1 session = 1 project** — tab bar shows sessions, not tabs within a session
- **+ button in tab bar** — creates new session
- **+ button in sidebar** — opens Finder to pick project folder
- **Recent projects** (🕐 button) — dropdown of last 10 projects, switches to existing session if already open
- **✕ close** on each tab (hover) — closes the session

### Sidebar Layout Customization
- **Right Sidebar Support** — The sidebar can be aligned to either the left or right side of the window.
- **Toggles** — Toggled via "View" menu item ("Move Sidebar to Right" / "Move Sidebar to Left") or Settings -> Window ("Sidebar on right" checkbox).
- **Dynamic Icons & Insets** — Icons (`sidebar.left`/`sidebar.right`) and margins/insets update dynamically so window traffic lights never overlap content.

## Known Issues

| ID | Issue | Status |
|----|-------|--------|
| CASE-001 | Checkbox in Git Changes list not receiving clicks (NSScrollView event blocking) | Resolved (Direct FlippedStackView documentView) |

## Branch

```
worktree-feature+acp-aidlc
```

## Build & Preview

```bash
cd /tmp/hp  # symlink to worktree (socket path length limit)
make preview
make preview-stop
```

## Architecture

```
HarnessSidebarPanelViewController — Sessions / Files / Git tabs
├── WorkspaceFileTreeView         — NSOutlineView + FileTreeWatcher
├── GitPanelView                  — Changes/History, branch, sync actions
└── Footer: ⚙ | agents | 🕐 | + | ⌘

ContentAreaViewController
└── TerminalTabBarView            — shows sessions as tab pills (1:1 with projects)
```
