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
│  🤖  Agent Detection + Notifications            │
│  🔔  ACP Chat — shelved (code preserved)        │
└─────────────────────────────────────────────────┘
```

Open the DMG, drag `Harness.app` to Applications, and launch it normally. The release is signed, notarized, and built for Apple silicon Macs running macOS 15 or later.

Verify the SHA-256 checksum against the value published on the [GitHub release page](https://github.com/robzilla1738/harness-terminal/releases/latest).

Prefer to build it yourself? Jump to [Build from source](#build-from-source).

## Why Harness

- **It's a real terminal first.** GPU rendering, accurate sRGB color by default, opt-in converted Display-P3 vivid color, ligatures, inline images (Sixel / Kitty / iTerm2), and 490 built-in themes with a muted Harness default. Block and box-drawing glyphs are drawn procedurally, so borders tile without seams at any font.
- **Your work outlives the window.** Sessions, tabs, and splits are owned by a daemon. Quit and reopen and everything is exactly where you left it, scrollback included — history is persisted to disk and restored even if the daemon restarts. Attach the same session from a second window or another machine.
- **It's scriptable, locally or remotely.** `harness-cli` drives the whole thing — open tabs, send keys, capture a pane, resize, swap, zoom — so your tooling can build the layout it needs. Point any command at a headless or remote daemon with `--host <name>`; the daemon and CLI run on Linux too, so a remote box can host your sessions.
- **It watches your agents.** Harness detects Claude Code, Codex, Cursor, and others by their process tree, shows which session is running what, and pings you when an agent stops or asks for approval. `Cmd+Shift+U` jumps you to the one that's waiting and skips the ones still thinking.

## How it feels

Harness ranges from a plain, get-out-of-your-way terminal to a full session manager. Pick the level in **Settings → Terminal → Experience**:

- **Plain Terminal** — fast and quiet. No command prefix, no status bar. Sessions close when you quit, like any terminal.
- **Persistent Terminal** — the same clean look, but sessions survive quitting and you can attach to them from the CLI.
- **Full Terminal** — everything: command prefix, status line, copy mode, paste buffers, panes, and the full `harness-cli` command set.
- **Agent Workspace** — persistent project workspaces with agent detection and notifications turned up front.

New installs start in Plain. Moving over from another setup? See [docs/MIGRATION.md](docs/MIGRATION.md) — Harness can import an existing terminal config (colors, font, padding) on first run.

## Features

- GPU-accelerated rendering by Harness's own terminal engine — accurate sRGB output by default, opt-in converted Display-P3 vivid color, a themed translucent canvas, and program output left untouched unless you opt into theme recoloring; damage-driven redraws keep selection drags, find highlights, IME composition, and streaming output cheap, full-rate on ProMotion displays, and covered or minimized windows stop rendering entirely
- Mainstream-GPU-terminal polish: live re-wrap while resizing (with a grid-size overlay), word / line / block selection, middle-click paste, alternate-screen wheel scrolling, focus reporting, hollow unfocused cursor, minimum contrast, auto light/dark themes, bold-is-bright control, and paste protection
- Sidebar sessions, per-session tabs, and horizontal / vertical splits — group sessions with shared window lists
- Session layout persists across quits (daemon-owned, attach from the CLI or over SSH); if the daemon restarts under a pane, a quiet "Reconnecting…" chip rides the ~1-minute automatic backoff before the click-to-re-grab overlay takes over
- Persistent scrollback: a pane's history is written to disk per surface and restored when the daemon restarts
- Remote & headless daemon: run `HarnessDaemon` on a headless or remote box (Linux included) and drive it with `harness-cli --host <name>` over an SSH tunnel — register hosts with `harness-cli remote add`
- `harness-cli` for automation and agent hooks
- Color/theme diagnostics from the CLI: `harness-cli color-check` and `harness-cli theme-preview --theme <name>` print deterministic SGR pages for eyeballing fidelity in Harness itself
- Command set: `send-keys`, `capture-pane`, `kill-pane`, `resize-pane`, `zoom-pane`, `swap-pane`, `rename-tab`, `attach`, `find-window`, `kill-server`, `start-server`, `respawn-window`, `refresh-client`, and more
- Command prefix keymap (default `Ctrl-A`) with a live cheatsheet (prefix `?`)
- Agent detection for Claude Code, Codex, Cursor, Grok, Pi, Hermes, OpenClaw, OpenCode, Aider, Gemini, and Goose — each with a brand color and a sidebar chip
- Agent alerts as desktop banners and a sidebar bell; `Cmd+Shift+U` jumps to whoever is waiting
- One-line hook install: `harness-cli install-hooks <agent>`
## Features

- GPU-accelerated rendering by Harness's own terminal engine — accurate sRGB output by default, opt-in converted Display-P3 vivid color, a themed translucent canvas, and program output left untouched unless you opt into theme recoloring; damage-driven redraws keep selection drags, find highlights, IME composition, and streaming output cheap, full-rate on ProMotion displays, and covered or minimized windows stop rendering entirely
- Mainstream-GPU-terminal polish: live re-wrap while resizing (with a grid-size overlay), word / line / block selection, middle-click paste, alternate-screen wheel scrolling, focus reporting, hollow unfocused cursor, minimum contrast, auto light/dark themes, bold-is-bright control, and paste protection
- Sidebar sessions, per-session tabs, and horizontal / vertical splits — group sessions with shared window lists
- Session layout persists across quits (daemon-owned, attach from the CLI or over SSH); if the daemon restarts under a pane, a quiet "Reconnecting…" chip rides the ~1-minute automatic backoff before the click-to-re-grab overlay takes over
- Persistent scrollback: a pane's history is written to disk per surface and restored when the daemon restarts
- Remote & headless daemon: run `HarnessDaemon` on a headless or remote box (Linux included) and drive it with `harness-cli --host <name>` over an SSH tunnel — register hosts with `harness-cli remote add`
- `harness-cli` for automation and agent hooks
- Color/theme diagnostics from the CLI: `harness-cli color-check` and `harness-cli theme-preview --theme <name>` print deterministic SGR pages for eyeballing fidelity in Harness itself
- Command set: `send-keys`, `capture-pane`, `kill-pane`, `resize-pane`, `zoom-pane`, `swap-pane`, `rename-tab`, `attach`, `find-window`, `kill-server`, `start-server`, `respawn-window`, `refresh-client`, and more
- Command prefix keymap (default `Ctrl-A`) with a live cheatsheet (prefix `?`)
- Agent detection for Claude Code, Codex, Cursor, Grok, Pi, Hermes, OpenClaw, OpenCode, Aider, Gemini, and Goose — each with a brand color and a sidebar chip
- Agent alerts as desktop banners and a sidebar bell; `Cmd+Shift+U` jumps to whoever is waiting
- One-line hook install: `harness-cli install-hooks <agent>`
- Command palette (`Cmd+K`) with fuzzy file quick-open, Switch Project (tmux-sessionizer-style), and workspace symbol search
- Search command history with `Ctrl+R` — fuzzy search overlay with recency sorting, seeds the command prompt on selection
- Layout presets (`Cmd+Opt+1`–`5`): Even Horizontal, Even Vertical, Main Horizontal, Main Vertical, Tiled — instant one-key splits
- Git worktrees auto-open/close session tabs on add/remove
- A native macOS Settings window (`Cmd+,`)
- 490 built-in color themes with a muted Harness default, plus `.harnesstheme` export / import for sharing — double-click (or Open With) a theme file to install it, optionally applying its colors immediately
- Shell integration (OSC 133): prompt marks for jump-to-prompt and a command success / failure gutter — bash / zsh / fish snippets in [docs/shell-integration/](docs/shell-integration/README.md)
- Inline images that stay put across reflow and scroll into history
- Drag file-backed folders or images into a pane to insert shell-quoted paths
- Set Harness as the default terminal for SSH/Telnet/man-page links and `.command` / `.tool` files from Settings > Terminal
- Automatic, signed background updates (Sparkle + EdDSA)

## harness-cli

Harness launches its daemon automatically; the CLI talks to it.

```bash
harness-cli list-surfaces
harness-cli new-session --workspace Default --cwd ~/Code/myproject
harness-cli new-tab --workspace Default --cwd ~/Code/myproject
harness-cli send-keys --surface "$HARNESS_SURFACE" --keys "ls -la Enter"
harness-cli notify --surface "$HARNESS_SURFACE" --title Agent --body "Needs approval"
harness-cli color-check
harness-cli theme-preview --theme "Harness Default"
>>>>>>> upstream/main
```

| Layer | What it does |
|-------|-------------|
| **GPU Terminal** | Metal renderer, 490 themes, inline images (Sixel/Kitty/iTerm2), ligatures, procedural box-drawing |
| **Daemon** | Sessions survive quit/relaunch, scrollback persists to disk, attach from CLI or remote SSH |
| **CMUX** | Binary-tree split panes, drag-to-split, auto-balanced ratios, pane-local surface tabs |
| **File Tree** | FSEvents live-watch, git status colors, click-to-open in editor, context menu |
| **File Editor** | 20+ language syntax highlighting, vi-mode, find/replace, git diff gutter |
| **Git Panel** | Stage/unstage, commit (amend/signoff), fetch/pull/push, branch switch, history + diff, worktrees |
| **Agent Chat** | ACP Client over stdio — shelved (code preserved, adapters not yet available) |
| **Agent Detection** | Process-tree scan for 12+ agents, brand colors, desktop notifications, Cmd+Shift+U jump |

---

## ⚡ Quick Start

```bash
make preview          # build + launch isolated preview app
make run              # build + package + sign + open Harness.app
swift build           # compile all targets
swift test            # run test suite
```

The first-run setup in `Harness.app` performs the same local installation for new
users: it copies `harness-cli` and `HarnessDaemon`, registers the LaunchAgent,
adds PATH blocks for zsh/bash/fish with backups, installs fish completions, asks
for notification permission, and offers detected agent hooks. On a fresh install, Harness displays
a one-shot welcome tour; after an update, it shows release highlights (suppressible via the `update-banner` option).

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
| **Sessions** | Project groups, session cards (with session ID), drag-reorder, recent projects, CWD grouping |
| **Files** | File tree with FSEvents auto-refresh, git status colors, right-click menu |
| **Git** | Changes (stage/commit), History (click→file editor), Worktrees |

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

### ACP Client (shelved — code preserved for future)
- Spawn agent as subprocess via Agent Client Protocol (JSON-RPC 2.0 over stdio)
- Send prompts, receive streaming text + tool calls
- Approve/reject file edits and command execution
- Currently disabled: adapters not widely available, PATH issues in .app bundles
- Re-enable in Settings when ACP ecosystem matures

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
| Search command history | `Ctrl+R` |
| Jump to waiting agent | `Cmd+Shift+U` |
| Settings | `Cmd+,` |
| Switch tab 1–9 | `Cmd+1` … `Cmd+9` |
| Layout: Even Horizontal | `Cmd+Opt+1` |
| Layout: Even Vertical | `Cmd+Opt+2` |
| Layout: Main Horizontal | `Cmd+Opt+3` |
| Layout: Main Vertical | `Cmd+Opt+4` |
| Layout: Tiled | `Cmd+Opt+5` |

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

## Requirements

- Apple silicon Mac running macOS 15.0 or later for the downloadable DMG
- Xcode 16+ / Swift 6.0 (to build from source)
- For a headless/remote daemon: any machine with Swift 6.0 (macOS or Linux) — build the daemon + CLI with `swift build -c release` (the GUI app, renderer, and Sparkle are macOS-only and are dropped from the Linux build)

## Documentation

- [Experience modes](docs/MODES.md) — Plain / Persistent / Full / Agent
- [IDE sidebar](docs/IDE-SIDEBAR.md) — Files, Git, and active agent activity panel
- [Agent handbook](docs/AGENT-HANDBOOK.md) — instructions and guidelines for AI coding agents
- [Sessions & panes guide](docs/MULTIPLEXER_GUIDE.md) — prefix, panes, sessions, copy mode, attach from anywhere
- [tmux parity ledger](docs/TMUX_PARITY.md) — capability status, adaptations for the daemon-owned model, explicitly rejected tmux features with rationale
- [tmux-style capabilities PDF](docs/HARNESS_TMUX_CAPABILITIES.pdf) — printable setup, shortcuts, commands, attach, copy mode, and troubleshooting
- [Release runbook](docs/RELEASE.md) — signed/notarized DMG, GitHub Actions release workflow, and Sparkle appcast publishing
- [Migration](docs/MIGRATION.md) — bringing your config and habits across
- [Keybindings](docs/KEYBINDINGS.md) · [Commands](docs/COMMANDS.md) · [Shell integration](docs/shell-integration/README.md) · [Agent hooks](docs/agent-hooks/README.md)
- [Changelog](CHANGELOG.md) — release history
- [Third-party notices](docs/THIRD-PARTY-NOTICES.md)

## License

MIT
