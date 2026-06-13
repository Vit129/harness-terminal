# Harness

> Forked from [robzilla1738/harness-terminal](https://github.com/robzilla1738/harness-terminal)

A native macOS terminal that keeps your sessions running, brings your editor tools with you, and tells you the moment a coding agent needs you.

Everything is first-party Swift — GPU terminal engine, session daemon, CLI. One external dependency: Sparkle for auto-updates.

---

## Why Harness

**Terminal first.** Metal GPU renderer, 490 themes, inline images, ligatures. Sessions live in a background daemon — quit and reopen and everything is exactly where you left it. Attach from a second window or remote machine over SSH.

**vi power user.** Full vi normal mode in the file editor — motions, operators, text objects, marks, registers, macros, jump list, `:` ex commands (`:w` `:q` `:s/old/new/g` `:%s` `:set relativenumber` `:e file` `:bn`). Inline `*` search highlight, LSP hover + go-to-definition + diagnostics.

**tmux compatible.** Prefix keymap, copy mode, `word-separators`, `wrap-search`, `window-size`, `destroy-unattached`, format strings, hooks, `source-file ~/.tmux.conf`. Full command set including `list-sessions -F "#{session_name}"`.

**IDE convenient.** Sidebar (`Cmd+\`): file tree with keyboard nav (j/k/h/l/Enter), real-time Git panel (stage, commit, push, history, worktrees), LSP-powered file editor. `Cmd+K` command palette with file quick-open, Switch Project (+ zoxide), symbol search.

**Agent aware.** Detects Claude Code, Codex, Cursor, and 10+ more. Desktop alerts + `Cmd+Shift+U` jump to whoever's waiting.

---

## Quick start

```bash
make preview      # isolated preview (separate daemon socket)
make debug        # alias for make preview
swift build       # compile all targets
swift test        # run tests
```

[Download signed DMG →](https://github.com/Vit129/harness-terminal/releases/latest) · Requires Apple silicon, macOS 15+

---

## Stack

| | |
|--|--|
| Language | Swift 6, strict concurrency |
| GUI | AppKit + Metal |
| Terminal | First-party VT parser, CoreText/Metal renderer |
| IPC | Unix sockets, length-prefixed JSON + binary PTY frames |
| Platforms | macOS 15+ (GUI), Linux (daemon + CLI headless) |

---

## Build from source

```bash
git clone https://github.com/Vit129/harness-terminal
cd harness-terminal
make preview
```

Requires Xcode 16+ / Swift 6.0. Daemon and CLI also build on Linux: `swift build --product HarnessDaemon`.

---

## Docs

[tmux parity](docs/TMUX_PARITY.md) · [Commands](docs/COMMANDS.md) · [Keybindings](docs/KEYBINDINGS.md) · [Shell integration](docs/shell-integration/README.md) · [Agent hooks](docs/agent-hooks/README.md) · [Migration](docs/MIGRATION.md) · [Changelog](CHANGELOG.md)

---

MIT
