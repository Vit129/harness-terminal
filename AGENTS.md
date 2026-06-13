# AGENTS.md

This file provides guidance to AI coding agents (Codex, Gemini, etc.) working in this repository.

## Build & test

```bash
swift build                                          # debug build (all targets)
swift build --product Harness                        # macOS GUI app only
swift build --product HarnessDaemon                 # daemon only
swift build --product harness-cli                   # CLI only
swift test                                           # full test suite
swift test --filter <TargetName>                     # single test target
swift test --filter <TestClassName>                  # single test class
swift test --filter <testMethodName>                 # single test
HARNESS_BENCHMARKS=1 swift test -c release --filter HarnessBenchmarks   # benchmarks
```

```bash
make preview      # isolated preview build under .harness-preview/
make debug        # alias for make preview
make prod         # release-style repo-root Harness.app (no /Applications copy)
make run          # re-open existing repo-root Harness.app without rebuilding
make install      # manual-only copy to /Applications
make preview-stop # kill preview processes
make clean        # remove build artifacts, Harness.app, dist/
```

**Always run `swift build` after edits and fix all errors before finishing.**

## Project context lookup

- `graphify-out/graph.json` — machine-readable project knowledge graph. Use Graphify queries before broad source browsing.
- `graphify-out/GRAPH_REPORT.md` — human-readable navigation guide for broad architecture review or when a query is not enough.
- `graphify-out/.graphify_labels.json` — readable community labels for the graph.
- `agent-memory/memory.md` — hot state: active decisions, recent lessons, and current task context.
- `agent-memory/playbook.md` — reusable fix patterns and prevention notes.
- `agent-memory/user-profile.md` — stable user preferences for style, testing, and workflow.
- `agent-memory/knowledge/` — durable domain notes for architecture areas such as IPC, AppKit/Metal, ACP, split panes, and git panel behavior.

## Graphify + agent-memory

For codebase questions, first run `graphify query "<question>"` when `graphify-out/graph.json` exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused context. These commands return scoped graph context and should usually come before broad grep or reading many files.

After the Graphify query, read `agent-memory/memory.md` for hot project state. If the task matches a known failure pattern, read `agent-memory/playbook.md`. If Graphify points to `agent-memory/knowledge/*.md`, read the matching knowledge file before editing related code, rules, or architecture-relevant docs.

Dirty `graphify-out/` files are expected after hooks or incremental updates; dirty graph files are not a reason to skip Graphify. Only skip Graphify if the task is specifically about stale or incorrect graph output, or the user explicitly says not to use it.

Read `graphify-out/GRAPH_REPORT.md` only for broad architecture review or when `query`/`path`/`explain` do not surface enough context. After modifying code, architecture-relevant docs, rules, or `agent-memory/knowledge/`, run `graphify update . --force` to keep the graph current.

## Architecture

### Package map

| Package | Path | Role |
|---------|------|------|
| `HarnessCore` | `Packages/HarnessCore/` | Shared foundation: IPC schema/codec/client, commands, settings, keybindings, ACP framing, agent detection, file explorer, persistence. **`-warnings-as-errors` is on.** |
| `HarnessTerminalEngine` | `Packages/HarnessTerminalEngine/` | Pure-Swift VT parser → screen/grid model. No AppKit/Metal. **`-warnings-as-errors` is on.** |
| `HarnessCopyMode` | `Packages/HarnessCopyMode/` | UI-agnostic copy-mode reducer over engine grids. |
| `HarnessTheme` | `Packages/HarnessTheme/` | Theme catalog + `.harnesstheme` format. Catalog embedded as base64 in `BundledThemesData.swift`. |
| `CHarnessSys` | `Packages/CHarnessSys/` | C shim for variadic `ioctl` and PTY helpers (Swift can't call variadic C on Linux). |
| `HarnessDaemonCore` | `Packages/HarnessDaemon/Sources/HarnessDaemon/` | Daemon library: `DaemonServer` (Unix socket), `SurfaceRegistry` (PTY sessions), scrollback, hooks. |
| `HarnessDaemon` | `Packages/HarnessDaemon/Sources/HarnessDaemonMain/` | Thin executable wrapping `HarnessDaemonCore`. |
| `HarnessCLI` | `Tools/harness/Sources/HarnessCLI/` | CLI frontend — `attach`, `send-keys`, `capture-pane`, `install-hooks`, `remote add`, etc. |
| `HarnessTerminalRenderer` | `Packages/HarnessTerminalRenderer/` | CoreText/Metal renderer — glyph atlas, frame building, sRGB/P3 color. **macOS only.** |
| `HarnessTerminalKit` | `Packages/HarnessTerminalKit/` | AppKit terminal surface (`TerminalHostView`, `HarnessTerminalSurfaceView`, input/resize). **macOS only.** |
| `HarnessOnboarding` | `Packages/HarnessOnboarding/` | Isolated SwiftUI first-run wizard. **macOS only.** |
| `HarnessApp` | `Apps/Harness/Sources/HarnessApp/` | GUI app (AppKit/SwiftUI): windows, sidebar, git panel, file tree, command palette, settings. **macOS only.** |

### Communication: GUI ↔ Daemon ↔ CLI

All three communicate over Unix-domain sockets using `HarnessCore` IPC:

- **Control frames**: 4-byte big-endian length-prefixed JSON (`IPCCodec`)
- **PTY output** (hot path): binary frame, magic `0xF5` + sequence number + raw bytes
- **PTY input** (hot path): binary frame, magic `0xF6` + surface id + raw bytes
- Key types: `Endpoint`, `DaemonClient`, `DaemonServer`, `IPCMessage`, `IPCCodec`, `CommandIPCTranslator`

**ACP** (`HarnessCore/ACP/`) is separate — `Content-Length: N\r\n\r\n{body}` framing (LSP-style) used to pipe agent hook notifications into the daemon via stdin.

> **⚠️ ACP Client is shelved/experimental.** The Agent sidebar tab and Chat toggle in Settings are commented out. Reason: most CLI agents (Claude Code, Codex, Gemini) require separate ACP adapter binaries that aren't widely installed, PATH resolution inside macOS .app bundles is unreliable, and there's no way to control which tools an agent invokes. The underlying code (`ACPClient`, `ACPSession`, `AgentChatPanelView`, `AgentConfig`) remains intact for future re-enablement when the ACP ecosystem matures.

**Remote daemon**: `SSHTunnelManager` opens `ssh -N -L <local>:<remote>` and returns `Endpoint.unix`; the CLI and GUI use the same IPC over the tunnel.

## Coding constraints

### Swift 6 strict concurrency (mandatory)
- Tools version 6.0 = strict concurrency everywhere. Every `Sendable` conformance and actor isolation must be explicit.
- `HarnessCore` and `HarnessTerminalEngine` also have `-warnings-as-errors` — data-race / `Sendable` / deprecation warnings are **build failures** in those targets.
- Long-lived classes that are `@unchecked Sendable` have documented queue/lock confinement (`DaemonClient`, `DaemonServer`, `SurfaceRegistry`, `RealPty`, `DaemonLauncher`, `SurfaceIO`, `InputGate`, `SSHTunnelManager`). Preserve their ownership invariants.
- AppKit/SwiftUI types are `@MainActor`. Terminal output replay uses `DispatchQueue.main.async` + `MainActor.assumeIsolated` to preserve FIFO byte order — do not replace with unstructured `Task { @MainActor in }`.

### Platform conditionals
- `#if os(macOS)` in `Package.swift` drops `HarnessTerminalRenderer`, `HarnessTerminalKit`, `HarnessOnboarding`, `HarnessApp`, and Sparkle on Linux.
- Daemon, CLI, engine, core, copy-mode, theme, and `CHarnessSys` build headless on Linux.
- Use `#if canImport(Darwin)` / `#elseif canImport(Glibc)` for POSIX imports in cross-platform targets.
- `WindowAttachClient.swift` is excluded on non-macOS; `attach-window` is guarded by `#if canImport(HarnessTerminalKit)`.

### IPC safety
- `IPCCodec.maxPayloadLength` = 16 MiB. Binary magic bytes `0xF5`/`0xF6` must not collide with the high byte of a JSON frame length — adding a new binary frame type needs a capability gate.
- The daemon control socket is owner-only (`chmod 0600`); `DaemonServer` rejects peers whose kernel uid differs from `geteuid()`.
- Subscription sockets are long-lived. Send resize and detach over `DaemonSubscription` (not one-shot `DaemonClient.request`) so votes survive the connection lifetime.
- `wait-for`, subscriptions, resize, detach, and client lifecycle are intercepted at the fd layer in `DaemonServer` — do not move them into `SurfaceRegistry`.

### Generated files (do not hand-edit)
- `BundledThemesData.swift` — regenerate with `EXPORT_THEMES=1 swift test --filter ThemeCatalogEmbedTests` after editing `themes.json`.
- `CharacterWidthTable.swift` — regenerate with `swift Scripts/generate-width-table.swift > Packages/HarnessTerminalEngine/.../Width/CharacterWidthTable.swift` after changing width ranges.

### Release packaging order
`make release` → `make sign` → `make dmg` → `make finalize`. Running `make dmg` before `make sign` ships an unsigned DMG.
