# Kouen

> This is a personal fork of [robzilla1738/harness-terminal](https://github.com/robzilla1738/harness-terminal), maintained independently by [Vit129](https://github.com/Vit129). Not affiliated with the original project or its author. It's a hard fork, not a PR queue back upstream — see [What's different from upstream](#whats-different-from-upstream).

Kouen is a native macOS terminal built for AI agent workflows. A first-party Swift terminal engine, a background session daemon, a scriptable CLI, embedded browser with MCP control, and multi-agent awareness — all in one app.

Run Claude Code, Codex, Gemini CLI, or any agent side-by-side. Sessions persist across app restarts, agents notify you when done, the embedded browser responds to MCP tool calls, and panes render on Metal.

---

## What's different from upstream

This fork started from upstream (currently v1.12.1) and has since diverged substantially — 47 releases of its own versus upstream's 23, and five new first-party Swift packages backing the features below. Checked directly against upstream's current source, not assumed:

- **AI browser control via MCP** — `kouen-mcp` exposes tools like `kouenBrowserOpen` and `kouenBrowserSnapshot` (full list under [AI Browser Control](#ai-browser-control-kouen-mcp)) so agents can drive the embedded browser pane directly. Upstream has no browser pane and no MCP server.
- **A built-in code editor with LSP** across 21 languages, with vi ex commands `gd` / `K` / `:errors` working against the live session (see [Editor & LSP](#editor--lsp)). Upstream's sidebar is session/tab lists only — no file editor, no LSP.
- **Inline AI command suggestions** (`⌥Space`, see [Keyboard Shortcuts](#keyboard-shortcuts)) — sends the pane's recent output to Claude and suggests the next command inline. No equivalent upstream.
- **A denser navigation layer** — Recipes (`⌘⇧R`), Composer (`⌘⇧E`), the zoxide frecency picker (`⌘⇧J`), tab overview (`⌘⇧\`), and hint mode (`⌘⇧U`) — none of these shortcuts exist upstream.
- **JavaScriptCore-based scripting** (see [Stack](#stack)) — upstream has no scripting layer at all.

None of this is a knock on the original — it's a different, more actively-maintained branch, kept for personal use rather than as a distributed product.

---

## Install

This fork does not currently publish a downloadable `.dmg` asset. Install it by building from source.

### Requirements

- Apple silicon Mac
- macOS 15 or later
- Xcode 16+ / Swift 6.0

### Install Into Applications

Use this for a normal local install:

```bash
git clone https://github.com/Vit129/kouen-terminal.git
cd kouen-terminal
make install
```

`make install` builds Kouen, packages `Kouen.app`, copies it to `/Applications/Kouen.app`, refreshes the local daemon/CLI helper binaries, and opens the app.

After the app opens, install the CLI on your `PATH` if prompted, or run:

```bash
/Applications/Kouen.app/Contents/MacOS/kouen-cli install
```

Then verify:

```bash
kouen-cli doctor
kouen-cli ping
```

Since Kouen is only ever built locally from this clone, launching the app also checks this repo's `version.json` on `main` once per launch and, on a clean working tree, asks whether to `git pull` when a newer version is available — never automatically. Decline and it won't ask again for that version; a dirty tree gets a notice instead of a prompt.

### Development Builds

For an isolated dev/test app that does not touch production Kouen state:

```bash
make preview
```

See [USAGE.md](USAGE.md) for the full install, run, CLI, and remote/headless guide.

## Why Kouen

- Native terminal rendering with Swift, CoreText, Metal, ligatures, and a large built-in theme catalog.
- Daemon-owned sessions, tabs, panes, scrollback, and layouts so work survives app restarts and can be attached from another client.
- `kouen-cli` automation for creating sessions, sending keys, capturing panes, installing hooks, and driving remote/headless daemons.
- Agent detection and notifications for Claude Code, Codex, Cursor, Grok, Pi, Hermes, OpenClaw, OpenCode, Aider, Gemini, Goose, and generic agents.
- Embedded browser pane with `kouen-mcp` — AI agents can open URLs, read DOM snapshots, click elements, fill forms, capture screenshots, and inspect network/storage without a separate Playwright process.
- Headless Claude Code runs — `kouen cc run` (CLI) or `kouenCCRun`/`kouenCCStatus` (`kouen-mcp`) drive `claude` as a real subprocess for one-shot prompts/automations, no pane or human supervision needed.
- Multi-agent workflows — run Claude Code, Codex, and Gemini CLI in parallel panes with per-agent statusline showing model, context usage, and rate limits.
- Optional tmux-style controls: prefix key, status line, copy mode, paste buffers, hooks, command prompt, and many tmux-compatible commands.
- IDE-like navigation — double-click folders to cd, ⌘P fuzzy jump to any directory via zoxide frecency, ⌘⇧J frecency dir picker (↩ cd · ⌘↩ open new tab), ⌘⇧R saved command recipes, ⌘-click file paths, `:cd` from the command prompt, and **Open With Kouen** from Finder on any source file.
- Sidebar tools for sessions, file navigation, real-time Git workflows (one-step Commit & Push, per-hunk stage/unstage, PR merge with squash/rebase/merge picker), command palette, and editor/LSP flows across 21 languages — see [Editor & LSP](#editor--lsp).
- Sidebar dev-server detection — live listening-port badge per session, click to open in the browser pane.
- SSH agent forwarding for remote hosts, toggleable per host in Settings.
- Fleet visibility — footer badge + Agent Inbox header show running/needs-attention counts across all active agent sessions.
- Stable under long sessions — per-pane controller trees and browser network buffers are bounded and released on pane close; memory stays flat across hours of use.

## Keyboard Shortcuts

The most-used ones. Full reference (Vi modal editing, prompt tools, navigation, session/layout files, agent protocol) is in [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md).

| Shortcut | Action |
|----------|--------|
| ⌘⌃V | Toggle Vi modal editing (normal / insert mode) |
| ⌘⇧J | Frecency directory picker (zoxide-powered) |
| ⌘⇧R | Recipes — saved command picker |
| ⌘⇧E | Composer panel — multi-line command editor |
| ⌘⌥F | Floating terminal pane (NSPanel, persisted frame) |
| ⌘⇧\ | Tab overview — thumbnail grid, click to switch |
| ⌘F / ⌘⇧F | Scrollback search / find in files |
| ⌥Space | Inline AI command suggestion overlay — sends recent pane output to Claude, suggests a next command |
| ⌘⇧U | Hint mode — keyboard-driven link/path opening |

## How It Feels

Kouen has four experience modes:

| Mode | Best for | Persistence |
| --- | --- | --- |
| Plain Terminal | A normal, quiet terminal | Sessions close on clean quit |
| Persistent Terminal | Plain terminal plus daemon-backed sessions | Sessions survive clean quit |
| Full Terminal | tmux-style panes, prefix, status line, copy mode | Sessions survive clean quit |
| Agent Workspace | Project workspaces with agent detection foregrounded | Sessions survive clean quit |

Switch modes in **Settings -> Terminal -> Experience**. Details live in [docs/MODES.md](docs/MODES.md).

## CLI

After installation, `kouen-cli` is available from the app bundle or app-support bin directory:

```bash
/Applications/Kouen.app/Contents/MacOS/kouen-cli install
export PATH="$HOME/Library/Application Support/Kouen/bin:$PATH"
```

Common commands:

```bash
kouen-cli doctor
kouen-cli list-sessions
kouen-cli list-surfaces
kouen-cli new-session --workspace Default --cwd ~/Code
kouen-cli attach --surface <uuid>
kouen-cli attach-window --session <name>
kouen-cli send-keys --surface <uuid> --keys "ls -la Enter"
kouen-cli capture-pane --surface <uuid> --scrollback
kouen-cli install-hooks codex
kouen-cli cc run "summarize the last commit" --cwd ~/Code/myrepo
```

More examples are in [USAGE.md](USAGE.md), [docs/COMMANDS.md](docs/COMMANDS.md), and [docs/MULTIPLEXER_GUIDE.md](docs/MULTIPLEXER_GUIDE.md).

## AI Browser Control (kouen-mcp)

AI agents (Claude Code, Codex, Kiro) can see and interact with the embedded browser pane via `kouen-mcp`. No separate browser or Playwright process needed.

**What an agent can do:**

| Capability | Tool | Returns |
| --- | --- | --- |
| Open / navigate URL | `kouenBrowserOpen`, `kouenBrowserNavigate` | pane ID |
| Read DOM + elements | `kouenBrowserSnapshot` | accessibility tree with stable refs (e1, e2…) |
| Click / fill / scroll | `kouenBrowserInteract` | ok / error |
| Screenshot | `kouenBrowserScreenshot` | base64 PNG |
| Read console logs | included in snapshot | array of log strings |
| Network requests | `kouenBrowserNetwork` | url, method, status, req/res body |
| Cookies | `kouenBrowserCookies` | name, value, domain, expires, secure |
| localStorage / sessionStorage | `kouenBrowserStorage` | key/value pairs |

**Snapshot element format** — stable refs let agents interact without writing selectors:

```json
{ "id": "e7", "tag": "button", "role": "button", "text": "Save", "bounds": {"x":120,"y":340,"width":80,"height":32}, "visible": true }
```

**Default home page** is configurable in `settings.json`:

```json
{ "browserHomePage": "https://www.google.com" }
```

**Token efficiency:** snapshot returns structured data (~200–500 tokens), not screenshots or raw HTML — significantly cheaper than vision-based browser automation.

## Claude Code Harness

Run `claude` as a real subprocess — `-p --output-format stream-json` — instead of a pty pane. No adapter binary, no screen-scraping; tool access is controlled via `--allowedTools`/`--disallowedTools`. For one-shot prompts and automations where nothing needs to watch it run; use `kouenSpawnAgent`/an interactive pane instead when a human is steering.

**From the terminal, no AI agent needed:**

```bash
kouen-cli cc run "summarize the last commit" --cwd ~/Code/myrepo
kouen-cli cc run "add input validation" --profile edit --model sonnet --effort high
kouen-cli cc status <runId>
kouen-cli cc list
kouen-cli cc cancel <runId>
```

**From an AI agent, via `kouen-mcp`:**

| Capability | Tool | Returns |
| --- | --- | --- |
| Start a run | `kouenCCRun` | run id + immediate status |
| Get / list / cancel | `kouenCCStatus` | run status, result, cost |

**Permission profiles** — `readonly` (Read/Glob/Grep only) or `edit` (default: Edit/Write + a git-readonly Bash allowlist; `rm`/`sudo`/`git push` always denied). Never `bypassPermissions`.

## Editor & LSP

Opening a file in the sidebar file editor auto-detects a language server from the file extension or a project marker (e.g. `package.json`, `Package.swift`) in an ancestor directory, and starts it if the binary is on `PATH`. Vi ex commands work against the live session: `gd` (go to definition, falls back to `gf` path resolution), `K` (hover), `:errors` (diagnostics). See [docs/COMMANDS.md](docs/COMMANDS.md#errors-and-lsp).

Nothing ships bundled — install the server binary you need yourself. Auto-start is off by default; turn it on and override any default binary path via `settings.json`:

```json
{ "lspAutoStart": true, "lspServers": { "python": "/opt/homebrew/bin/pyright-langserver" } }
```

| Group | Extensions | Server |
| --- | --- | --- |
| iOS native | `.swift` `.m` `.mm` | `sourcekit-lsp` |
| Android native | `.kt` `.kts` | `kotlin-language-server` |
| Android native | `.java` | `jdtls` |
| Flutter | `.dart` | `dart language-server` |
| Web / React / Next.js / Apps Script | `.ts` `.tsx` `.js` `.jsx` `.gs` | `typescript-language-server` |
| PHP | `.php` | `intelephense` |
| Ruby | `.rb` | `ruby-lsp` |
| Go | `.go` | `gopls` |
| Rust | `.rs` | `rust-analyzer` |
| Python | `.py` | `pyright-langserver` |
| C / C++ | `.c` `.cpp` `.cc` `.cxx` `.h` `.hpp` `.hxx` | `clangd` |
| C# / .NET | `.cs` | `csharp-ls` |
| SQL | `.sql` | `sql-language-server` |
| JSON | `.json` `.jsonc` | `vscode-json-language-server` |
| YAML | `.yml` `.yaml` | `yaml-language-server` |
| CSS | `.css` `.scss` `.sass` | `vscode-css-language-server` |
| HTML | `.html` `.htm` | `vscode-html-language-server` |
| Robot Framework | `.robot` `.resource` | `robotcode` |
| Gherkin / Cucumber | `.feature` | `cucumber-language-server` |
| Shell | `.sh` `.bash` `.zsh` | `bash-language-server` |
| Markdown | `.md` | `marksman` |

## Remote And Headless

The daemon and CLI can run without the GUI, including on Linux. Register a remote daemon over SSH and use `--host` with normal CLI commands:

```bash
kouen-cli remote add --name devbox --ssh me@devbox --socket "/home/me/.config/kouen/kouen.sock"
kouen-cli ping --host devbox
kouen-cli new-session --host devbox --cwd ~/Code
kouen-cli capture-pane --host devbox --surface <id>
```

## Stack

| Area | Technology |
| --- | --- |
| Language | Swift 6, strict concurrency |
| GUI | AppKit + SwiftUI |
| Terminal rendering | CoreText + Metal |
| IPC | Unix sockets, length-prefixed JSON, binary PTY frames |
| Scripting | JavaScriptCore |
| Agent tooling | CLI hooks + `kouen-mcp` |
| Platforms | macOS 15+ GUI, macOS/Linux daemon and CLI |

## Documentation

- [USAGE.md](USAGE.md) - install, run, CLI, remote/headless, IDE-like workflow, experience modes, migration, and troubleshooting
- [docs/MODES.md](docs/MODES.md) - Plain, Persistent, Full, and Agent Workspace modes (detail)
- [docs/MIGRATION.md](docs/MIGRATION.md) - migrating from tmux or another terminal setup
- [docs/COMMANDS.md](docs/COMMANDS.md) - full command reference including workbench commands (`:find`, `:grep`, `:make`, `:errors`, `:recent`)
- [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md) - shortcuts, key bindings, and vi ex command quick reference (IDE-like navigation)
- [sheet-cheat.html](sheet-cheat.html) - interactive cheat sheet (shell tools, unix, vim, Kouen) — regenerate with `make cheatsheet`
- [docs/shell-integration/README.md](docs/shell-integration/README.md) - shell integration
- [docs/agent-hooks/README.md](docs/agent-hooks/README.md) - agent notification hooks
- [docs/MULTIPLEXER_GUIDE.md](docs/MULTIPLEXER_GUIDE.md) - sessions, panes, prefix key, attach, copy mode
- [docs/RELEASE.md](docs/RELEASE.md) - release workflow
- [CHANGELOG.md](CHANGELOG.md) - release history

## Build From Source

```bash
swift build
swift test
make preview
```

For release packaging, use the documented order:

```bash
make release
make sign
make dmg
make finalize
```

## License

MIT
