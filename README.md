# Harness

> Forked from [robzilla1738/harness-terminal](https://github.com/robzilla1738/harness-terminal)

The native macOS terminal that keeps your sessions running and tells you the moment a coding agent needs you.

Every pane renders on Harness's own GPU engine. Your splits and sessions live in a background daemon, so they survive quitting the app — and their scrollback survives a daemon restart. You can drive or attach to them from the command line, including a headless or remote daemon over SSH. And Harness watches the agents you run inside it (Claude Code, Codex, Cursor, and more), so an approval prompt never sits unseen behind another tab.

One self-contained app. The terminal engine, daemon, and CLI are all first-party Swift; the only external dependency is Sparkle (the macOS auto-update framework, GUI-only).

---

## 🧬 Architecture — CMUX + Zed in a Terminal

```
┌─────────────────────────────────────────────────┐
│              Harness Terminal                     │
├─────────────────────────────────────────────────┤
│  🖥️  GPU Terminal Engine (Metal, sRGB/P3)       │
│  🔄  Daemon (persistent sessions, remote SSH)    │
│  📐  CMUX (client-side split panes, N-ary)      │
│  📁  File Tree + Editor (Zed-style)             │
│  🌿  Git Panel — real-time (Zed-style)          │
│  🤖  Agent Chat — ACP protocol (Zed-style)      │
│  🔔  Agent Detection + Notifications            │
└─────────────────────────────────────────────────┘
```

| Layer | What it does |
|-------|-------------|
| **GPU Terminal** | Metal renderer, 490 themes, inline images (Sixel/Kitty/iTerm2), ligatures, procedural box-drawing |
| **Daemon** | Sessions survive quit/relaunch, scrollback persists to disk, attach from CLI or remote SSH |
| **CMUX** | Binary-tree split panes, drag-to-split, auto-balanced ratios, pane-local surface tabs |
| **File Tree** | FSEvents live-watch, git status colors, click-to-open in editor, context menu |
| **File Editor** | 20+ language syntax highlighting, vi-mode, find/replace, git diff gutter |
| **Git Panel** | Stage/unstage, commit (amend/signoff), fetch/pull/push, branch switch, history + diff, worktrees |
| **Agent Chat** | ACP Client over stdio — spawn Claude/Codex/Gemini/Kiro, stream responses, tool call approvals |
| **Agent Detection** | Process-tree scan for 12+ agents, brand colors, desktop notifications, Cmd+Shift+U jump |

---

## ⚡ Quick Start

```bash
make preview          # build + launch isolated preview app
make run              # build + package + sign + open Harness.app
swift build           # compile all targets
swift test            # run test suite
```

---

## 🖥️ Terminal

- GPU-accelerated Metal renderer — sRGB default, opt-in Display P3 vivid color
- 490 built-in themes + `.harnesstheme` import/export
- Inline images: Sixel, Kitty, iTerm2
- Ligatures, procedural box-drawing, minimum contrast
- Live re-wrap on resize with grid-size overlay
- Word/line/block selection, middle-click paste, alternate-screen scrolling
- Shell integration (OSC 133): prompt marks, jump-to-prompt, success/fail gutter
- Auto light/dark theme switching

---

## 🔄 Daemon & Sessions

- Sessions, tabs, splits owned by background daemon — survive quit and relaunch
- Scrollback persisted to disk — survives daemon restart
- Remote daemon: `harness-cli --host devbox` over SSH tunnel
- `harness-cli` for automation: `send-keys`, `capture-pane`, `new-session`, `notify`
- Experience modes: Plain → Persistent → Full → Agent Workspace

---

## 📐 CMUX (Split Panes)

- Binary-tree pane model (`PaneNode`) with N-ary flatten
- Split right (Cmd+D): auto-balanced 50/50 → 33/33/33 → 25/25/25/25
- Drag surface tabs to split with live drop overlays
- Pane-local surface tabs — multiple terminals per pane
- Move surfaces between panes
- Layout persists across restarts

---

## 📁 IDE Sidebar

Toggle with `Cmd+\`. Four tabs:

| Tab | What it does |
|-----|-------------|
| **Sessions** | Project groups, session cards, drag-reorder, recent projects |
| **Files** | File tree with FSEvents auto-refresh, git status colors, right-click menu |
| **Git** | Changes (stage/commit), History (click→file editor), Worktrees |
| **Agent** | ACP chat panel — type prompts, stream responses, approve tool calls |

---

## 🌿 Git (Real-time)

- **Auto-refresh** — FSEvents watcher on `.git` dir, 500ms debounce
- **Changes** — stage/unstage per-file, Stage All, commit message + Commit ▼ (amend, signoff)
- **Sync** — Fetch/Pull/Push with per-remote options, auto-detects ahead/behind
- **History** — commit list, click → changed files list + diff, click file → opens in editor (Zed-like)
- **Worktrees** — list/add/remove `git worktree` entries
- **Branch** — switcher from bottom bar

---

## 🤖 Agent System

### Detection (passive — zero config)
Harness scans process trees and detects: Claude Code, Codex, Cursor, Grok, Pi, Hermes, OpenClaw, OpenCode, Aider, Gemini, Goose, Antigravity, Kiro — each with brand color + sidebar chip.

### Notifications
- Desktop banners when agent stops or needs input
- Sidebar bell + `Cmd+Shift+U` jump to waiting agent
- One-line hook install: `harness-cli install-hooks claude-code`

### ACP Client (active — chat with agents)
- Spawn agent as subprocess via Agent Client Protocol (JSON-RPC 2.0 over stdio)
- Send prompts, receive streaming text + tool calls
- Approve/reject file edits and command execution
- Configure in Settings → Agents → "Add Agent…"

---

## ⌨️ Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New tab | `Cmd+T` |
| New session | `Cmd+Shift+N` |
| Close tab | `Cmd+W` |
| Split right | `Cmd+D` |
| Toggle sidebar | `Cmd+\` |
| Command palette | `Cmd+K` |
| Jump to waiting agent | `Cmd+Shift+U` |
| Settings | `Cmd+,` |
| Switch tab 1–9 | `Cmd+1` … `Cmd+9` |

Command prefix (default `Ctrl-A`) adds the full pane/session keymap — press prefix then `?` for cheatsheet.

---

## 💻 Tech Stack

| Layer | Technology |
|-------|-----------|
| **Language** | Swift 6 (strict concurrency) |
| **GUI** | AppKit + Metal |
| **Terminal Engine** | First-party VT parser + screen model |
| **Renderer** | CoreText + Metal glyph atlas |
| **IPC** | Unix-domain sockets, length-prefixed JSON + binary PTY frames |
| **Agent Protocol** | ACP v1 (JSON-RPC 2.0, Content-Length framing over stdio) |
| **Auto-update** | Sparkle (macOS only) |
| **Platforms** | macOS 15+ (GUI), Linux (daemon + CLI headless) |

---

## 📦 Package Map

| Package | Role |
|---------|------|
| `HarnessCore` | IPC, commands, settings, ACP, models, persistence |
| `HarnessTerminalEngine` | Pure-Swift VT parser → screen/grid model |
| `HarnessTerminalRenderer` | CoreText/Metal renderer (macOS) |
| `HarnessTerminalKit` | AppKit terminal surface (macOS) |
| `HarnessDaemonCore` | Daemon: Unix socket server, PTY sessions, hooks |
| `HarnessDaemon` | Daemon executable |
| `HarnessCLI` | CLI: `harness-cli` commands |
| `HarnessApp` | GUI app: windows, sidebar, git panel, agent chat |
| `CHarnessSys` | C shim for PTY/ioctl |

---

## 🧠 Agent Memory System

| Layer | Location | Purpose |
|-------|----------|---------|
| **Auto Memory** | `~/.claude/projects/.../memory/` | Session knowledge (Claude writes automatically) |
| **agent-memory/** | `agent-memory/` | Structured state: memory, playbook, skill-log, user-profile |
| **CLAUDE.md / AGENTS.md** | repo root | Build commands, architecture, constraints for all agents |

---

## 📊 Graphify

```bash
graphify update .     # rebuild knowledge graph (no API cost)
graphify serve        # local graph viewer
```

7303 nodes · 13291 edges · 439 communities → `graphify-out/GRAPH_REPORT.md`

---

## 🤖 Multi-Agent Development

| File | Agent | Purpose |
|------|-------|---------|
| `CLAUDE.md` | Claude Code | Build/architecture/constraints |
| `AGENTS.md` | Codex / Gemini / Kiro | Same (agent-agnostic format) |
| `agent-memory/memory.md` | All | Active sprint context |
| `agent-memory/playbook.md` | All | Resolved cases (CASE-001–011) |

---

## 📖 Documentation

- [Experience modes](docs/MODES.md) · [IDE sidebar](docs/IDE-SIDEBAR.md) · [Agent handbook](docs/AGENT-HANDBOOK.md)
- [Sessions & panes](docs/MULTIPLEXER_GUIDE.md) · [Keybindings](docs/KEYBINDINGS.md) · [Commands](docs/COMMANDS.md)
- [Shell integration](docs/shell-integration/README.md) · [Agent hooks](docs/agent-hooks/README.md)
- [Migration](docs/MIGRATION.md) · [Release runbook](docs/RELEASE.md) · [Changelog](CHANGELOG.md)

---

## 📄 License

MIT
