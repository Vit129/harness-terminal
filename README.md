# Harness

[![CI](https://github.com/robzilla1738/harness-cli/actions/workflows/ci.yml/badge.svg)](https://github.com/robzilla1738/harness-cli/actions/workflows/ci.yml)

The native macOS terminal that keeps your sessions running and tells you the moment a coding agent needs you.

Every pane renders on Harness's own GPU engine. Your splits and sessions live in a background daemon, so they survive quitting the app and you can drive or attach to them from the command line — even over SSH. And Harness watches the agents you run inside it (Claude Code, Codex, Cursor, and more), so an approval prompt never sits unseen behind another tab.

One self-contained app. The terminal engine, daemon, and CLI are all first-party Swift; the only external dependency is Sparkle (the macOS auto-update framework, GUI-only).

## Download

**[Download Harness for macOS →](https://harnesscli.dev)**

Drag it to Applications and open it. Updates install themselves in the background, signed and verified. Requires macOS 15 or later.

Prefer to build it yourself? Jump to [Build from source](#build-from-source).

## Why Harness

- **It's a real terminal first.** GPU rendering, true 24-bit color, ligatures, inline images (Sixel / Kitty / iTerm2), and 485 built-in themes. Block and box-drawing glyphs are drawn procedurally, so borders tile without seams at any font.
- **Your work outlives the window.** Sessions, tabs, and splits are owned by a daemon. Quit and reopen and everything is exactly where you left it. Attach the same session from a second window or another machine.
- **It's scriptable.** `harness-cli` drives the whole thing — open tabs, send keys, capture a pane, resize, swap, zoom — so your tooling can build the layout it needs.
- **It watches your agents.** Harness detects Claude Code, Codex, Cursor, and others by their process tree, shows which session is running what, and pings you when an agent stops or asks for approval. `Cmd+Shift+U` jumps you to the one that's waiting and skips the ones still thinking.

## How it feels

Harness ranges from a plain, get-out-of-your-way terminal to a full session manager. Pick the level in **Settings → Terminal → Experience**:

- **Plain Terminal** — fast and quiet. No command prefix, no status bar. Sessions close when you quit, like any terminal.
- **Persistent Terminal** — the same clean look, but sessions survive quitting and you can attach to them from the CLI.
- **Full Terminal** — everything: command prefix, status line, copy mode, paste buffers, panes, and the full `harness-cli` command set.
- **Agent Workspace** — persistent project workspaces with agent detection and notifications turned up front.

New installs start in Plain. Moving over from another setup? See [docs/MIGRATION.md](docs/MIGRATION.md) — Harness can import an existing terminal config (colors, font, padding) on first run.

## Features

- GPU-accelerated rendering by Harness's own terminal engine — Display-P3 / sRGB color, a themed translucent canvas, and program output left untouched unless you opt into theme recoloring
- Sidebar sessions, per-session tabs, and horizontal / vertical splits
- Session layout persists across quits (daemon-owned, attach from the CLI or over SSH)
- `harness-cli` for automation and agent hooks
- Command set: `send-keys`, `capture-pane`, `kill-pane`, `resize-pane`, `zoom-pane`, `swap-pane`, `rename-tab`, `attach`, and more
- Command prefix keymap (default `Ctrl-A`) with a live cheatsheet (prefix `?`)
- Agent detection for Claude Code, Codex, Cursor, Pi, Hermes, OpenClaw, OpenCode, Aider, Gemini, and Goose — each with a brand color and a sidebar chip
- Agent alerts as desktop banners, a sidebar bell, and pane rings; `Cmd+Shift+U` jumps to whoever is waiting
- One-line hook install: `harness-cli install-hooks <agent>`
- Command palette (`Cmd+K`) and a fully themed Settings window (`Cmd+,`)
- 485 built-in color themes, plus `.harnesstheme` export / import for sharing
- Shell integration (OSC 133): prompt marks for jump-to-prompt and a command success / failure gutter — bash / zsh / fish snippets in [docs/shell-integration/](docs/shell-integration/README.md)
- Inline images that stay put across reflow and scroll into history
- Automatic, signed background updates (Sparkle + EdDSA)

## harness-cli

Harness launches its daemon automatically; the CLI talks to it.

```bash
harness-cli list-surfaces
harness-cli new-session --workspace Default --cwd ~/Code/myproject
harness-cli new-tab --workspace Default --cwd ~/Code/myproject
harness-cli send-keys --surface "$HARNESS_SURFACE" --keys "ls -la Enter"
harness-cli notify --surface "$HARNESS_SURFACE" --title Agent --body "Needs approval"
```

Install it onto your `PATH`:

```bash
# From the app bundle:
/Applications/Harness.app/Contents/MacOS/harness-cli install

# Or from a source build:
.build/release/harness-cli install

# Then add the printed path to your shell profile:
export PATH="$HOME/Library/Application Support/Harness/bin:$PATH"
```

## Agent hooks

`HARNESS_SURFACE` is set in every Harness pane, so an agent can ping the exact tab it's running in:

```bash
harness-cli install-hooks claude-code
harness-cli notify --surface "$HARNESS_SURFACE" --body "Approval required"
```

Per-agent setup lives in [docs/agent-hooks/README.md](docs/agent-hooks/README.md). Agents without a hook mechanism still notify you through Harness's built-in activity detection once they're running.

## Keyboard shortcuts

| Action | Shortcut |
|--------|----------|
| New tab | `Cmd+T` |
| New workspace | `Cmd+Shift+N` |
| Close tab | `Cmd+W` |
| Split horizontal / vertical | `Cmd+D` / `Cmd+Shift+D` |
| Switch to tab 1–9 | `Cmd+1` … `Cmd+9` |
| Previous / next tab | `Cmd+Shift+[` / `Cmd+Shift+]` |
| Jump to waiting agent | `Cmd+Shift+U` |
| Command palette | `Cmd+K` |
| Settings | `Cmd+,` |
| Toggle sidebar | `Cmd+\` |

The command prefix (default `Ctrl-A`) adds the full pane / session keymap on top — press prefix then `?` for the cheatsheet.

## Build from source

```bash
git clone https://github.com/robzilla1738/harness-cli.git harness
cd harness
make release
open Harness.app
```

### Develop in Xcode

`Harness.xcodeproj` is generated from `project.yml` with XcodeGen. The app target builds and bundles `HarnessDaemon` and `harness-cli` into `Harness.app/Contents/MacOS/`, so an Xcode run uses the same helper layout as the release app.

```bash
xcodegen generate
open Harness.xcodeproj
xcodebuild -project Harness.xcodeproj -scheme Harness -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build test
```

### Sign and notarize a release

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export APPLE_TEAM_ID="TEAMID"
export APPLE_APP_PASSWORD="app-specific-password"

make release                  # Harness.app with embedded harness-cli + HarnessDaemon
./Scripts/sign-and-notarize.sh
make dmg                       # Harness.dmg, drag-to-Applications install
```

## Requirements

- macOS 15.0 or later
- Xcode 16+ / Swift 6.0 (to build from source)

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — daemon, terminal engine, IPC, compositor
- [Experience modes](docs/MODES.md) — Plain / Persistent / Full / Agent
- [Sessions & panes guide](docs/MULTIPLEXER_GUIDE.md) — prefix, panes, sessions, copy mode, attach from anywhere
- [Migration](docs/MIGRATION.md) — bringing your config and habits across
- [Keybindings](docs/KEYBINDINGS.md) · [Commands](docs/COMMANDS.md) · [Shell integration](docs/shell-integration/README.md) · [Agent hooks](docs/agent-hooks/README.md)
- [Reliability & security](docs/RELIABILITY.md)

## License

MIT
