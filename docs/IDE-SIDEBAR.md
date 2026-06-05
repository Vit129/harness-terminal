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
- **Stage/unstage** checkboxes per file (⚠️ known issue: CASE-001)
- **Stage All** button
- **Commit message** text area with Commit Tracked button
- **History view** — SourceTree-style commit cards (subject + author · time · hash)
- **Branch switcher** — click branch name to see dropdown of all branches
- **Sync dropdown** (Fetch ▾) — Fetch, Pull, Push, Force Push

### Session Management
- **1 session = 1 project** — tab bar shows sessions, not tabs within a session
- **+ button in tab bar** — creates new session
- **+ button in sidebar** — opens Finder to pick project folder
- **Recent projects** (🕐 button) — dropdown of last 10 projects, switches to existing session if already open
- **✕ close** on each tab (hover) — closes the session

## Known Issues

| ID | Issue | Status |
|----|-------|--------|
| CASE-001 | Checkbox in Git Changes list not receiving clicks (NSScrollView event blocking) | Unresolved — needs Xcode View Debugger |

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
