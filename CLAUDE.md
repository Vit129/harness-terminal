# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/test/run commands

- `make build` -> `swift build`.
- `swift build` builds the SwiftPM package. On macOS this includes `Harness`, `HarnessDaemon`, `harness-cli`, renderer, terminal kit, onboarding, and Sparkle-backed app targets; on Linux the macOS-only targets are omitted by `#if os(macOS)` in `Package.swift`.
- `swift build --product Harness` builds the macOS GUI executable product.
- `swift build --product HarnessDaemon` builds the daemon executable product.
- `swift build --product harness-cli` builds the CLI executable product.
- `make preview` -> `./Scripts/preview.sh`: builds `Harness`, `HarnessDaemon`, and `harness-cli` products for an isolated preview app with its own bundle id, socket, and state directory.
- `make debug` -> `./Scripts/run.sh debug`: backward-compatible alias for `make preview`.
- `make prod` -> `./Scripts/run.sh prod`: builds `Harness`/`HarnessDaemon`/`harness-cli` in release config, packages/signs the repo-root `Harness.app`, and opens it without copying to `/Applications`.
- `make run` -> `./Scripts/run.sh run`: kills any stale running instance and re-opens the existing repo-root `Harness.app` without rebuilding (fails if it doesn't exist yet — run `make prod` first).
- `make install` -> `./Scripts/install-app.sh`: manual-only release build + package + sign, stops the old daemon, copies into `/Applications/Harness.app`, clears quarantine/LaunchServices cache, then opens it from `/Applications`. It is not part of the interactive/full-cycle release flow. `make install-no-build` skips the build step.
- `make preview-stop` stops preview `Harness` and `HarnessDaemon` processes under `.harness-preview`; `make preview-clean` removes `.harness-preview`.
- `swift run HarnessDaemon` runs the daemon foreground executable from the SwiftPM product.
- `swift run harness-cli -- <command>` runs the CLI product; `swift run harness-cli -- daemon` execs `HarnessDaemon`.
- `swift test` runs the package test suite declared in `Package.swift`.
- `swift test --filter <TestTargetOrCase>` runs a filtered test target/case.
- `make bench` -> `HARNESS_BENCHMARKS=1 swift test -c release --filter HarnessBenchmarks`.
- `make icon` -> `./Scripts/generate-app-icon.sh`.
- `make release` depends on `icon` and runs `./Scripts/build-release.sh`.
- `make dmg`, `make sign`, `make appcast`, `make finalize`, and `make hotfix-release` call the corresponding scripts; release order is `make release` -> `make sign` -> `make dmg` -> `make finalize`.
- Theme catalog regeneration: `EXPORT_THEMES=1 swift test --filter ThemeCatalogEmbedTests` rewrites `Packages/HarnessTheme/Sources/HarnessTheme/BundledThemesData.swift` from `Packages/HarnessTheme/Sources/HarnessTheme/Resources/themes.json`.
- Character width table regeneration is manual, not part of the build: `swift Scripts/generate-width-table.swift > Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Width/CharacterWidthTable.swift`.

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

## High-level architecture

- Package: `Harness` (`Package.swift`, Swift tools 6.0). External dependency exists only on macOS: Sparkle `2.9.x` for the GUI app.
- `HarnessCore` (`Packages/HarnessCore/Sources/HarnessCore`): shared models, session/editor logic, IPC envelope/schema/codec/client, command parsing/translation, settings, keybindings, paths, hooks, diagnostics, remote SSH tunnel configuration, ACP JSON-RPC framing, and persistence helpers. `HarnessCore` and `HarnessTerminalEngine` use `-warnings-as-errors`.
- `HarnessTerminalEngine` (`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine`): pure Swift terminal engine: VT parser, emulator, screen/grid model, input encoding, image protocols, search, damage tracking, and generated character-width lookup.
- `HarnessCopyMode` (`Packages/HarnessCopyMode/Sources/HarnessCopyMode`): UI-agnostic copy-mode state and reducer over terminal engine grids.
- `HarnessTheme` (`Packages/HarnessTheme/Sources/HarnessTheme`): theme definitions, `.harnesstheme` document support, diagnostics, and embedded base64 community catalog.
- `HarnessLSP` (`Packages/HarnessLSP/Sources/HarnessLSP`): LSP client plumbing — transport, client, models, and server registry — used by the GUI file viewer/editor.
- `HarnessSyntaxResources` (`Packages/HarnessSyntaxResources`): bundled tree-sitter grammar resources (`Resources/TreeSitterGrammars`) for syntax highlighting.
- `CHarnessSys` (`Packages/CHarnessSys`): C portability shim for low-level PTY/socket helpers such as non-variadic terminal/ioctl wrappers and peer credentials.
- `HarnessDaemonCore` (`Packages/HarnessDaemon/Sources/HarnessDaemon`): daemon library. `DaemonServer` owns the Unix socket accept/read/write loop, client subscriptions, snapshot subscriptions, and per-fd resize/detach state. `SurfaceRegistry` owns session layout, `RealPty` surfaces, hooks, options, paste buffers, and persistence. `DaemonCommandExecutor` maps hook-fired commands through `CommandIPCTranslator`.
- `HarnessDaemon` (`Packages/HarnessDaemon/Sources/HarnessDaemonMain`): thin daemon executable that starts `DaemonServer`, installs signal handlers, writes/removes PID files, starts `AgentScanner`, logs to `HarnessPaths.daemonLogURL`, and runs the dispatch loop.
- `HarnessCLI` (`Tools/harness/Sources/HarnessCLI`): command-line frontend. `HarnessCLI` parses commands, uses `DaemonClient` for RPC, uses `AttachClient`/`ControlModeClient`/`RecordClient`/`ReplayClient` for live terminal workflows, and on macOS conditionally uses `WindowAttachClient`/`HarnessTerminalKit` for `attach-window`.
- `HarnessMCP` (`Tools/harness-mcp/Sources/HarnessMCP`, product `harness-mcp`): MCP (Model Context Protocol) server speaking JSON-RPC 2.0 over stdin/stdout so AI agents can use Harness as a tool provider; depends only on `HarnessCore`.
- `HarnessTerminalRenderer` (`Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer`, macOS): CoreText/Metal renderer, glyph atlas/rasterizer, frame building, color resolution, and image texture cache.
- `HarnessTerminalKit` (`Packages/HarnessTerminalKit/Sources/HarnessTerminalKit`, macOS): AppKit terminal surface layer. `TerminalHostView` hosts `HarnessTerminalSurfaceView`, ensures daemon surfaces, replays scrollback, subscribes to output, and routes input/resize through `SurfaceIO` and `InputGate`.
- `HarnessOnboarding` (`Packages/HarnessOnboarding/Sources/HarnessOnboarding`, macOS): isolated SwiftUI/AppKit onboarding wizard and install helpers.
- `HarnessApp` (`Apps/Harness/Sources/HarnessApp`, macOS product `Harness`): GUI app. `AppDelegate`/controllers build windows, menus, settings, panes, and onboarding. `DaemonLauncher` ensures a daemon exists via launchd in release or direct fallback in debug. `SessionCoordinator`, `MainExecutor`, and pane registry types coordinate GUI state with daemon surfaces.
- Test targets in `Package.swift`: `HarnessCoreTests`, `HarnessTerminalEngineTests`, `HarnessCopyModeTests`, `HarnessThemeTests`, `HarnessCLITests`, `HarnessDaemonTests`; macOS-only `HarnessTerminalRendererTests`, `HarnessTerminalKitTests`, `HarnessOnboardingTests`, `GridCompositorParityTests` (drift canary: live vs onboarding `GridCompositor`), `HarnessAppTests`, and opt-in `HarnessBenchmarks`.
- GUI/CLI/daemon communication is not ACP. They communicate through `HarnessCore` IPC over Unix-domain sockets. Boundary types/files are `Endpoint` and `EndpointConnector` (`IPC/Endpoint*.swift`), `DaemonClient` and `DaemonSubscription` (`IPC/DaemonClient.swift`), `IPCRequest`/`IPCResponse`/`IPCEnvelope`/`IPCReply` (`IPC/IPCMessage.swift`), `IPCCodec` (`IPC/IPCCodec.swift`), and `DaemonServer` (`HarnessDaemon/DaemonServer.swift`).
- IPC framing: control messages are 4-byte big-endian length-prefixed JSON. PTY hot paths use binary frames in `IPCCodec`: daemon-to-client output magic `0xF5` with sequence, and client-to-daemon input magic `0xF6` with surface id and raw bytes.
- Remote daemon access still uses the same IPC protocol. `SSHTunnelManager` starts `ssh -N -L <local-socket>:<remote-socket>` and returns `Endpoint.unix`; native `Endpoint.tcp` is reserved and currently unsupported.
- ACP is separate agent-process plumbing in `HarnessCore/ACP`: `ACPMessage` models JSON-RPC 2.0, `ACPTransport` frames messages with `Content-Length`, and `ACPProcess` launches an external agent binary over stdin/stdout.
- **⚠️ ACP Client is shelved/experimental.** The Agent sidebar tab and Chat toggle in Settings are commented out. Reason: most CLI agents require separate ACP adapter binaries that aren't widely installed, PATH resolution inside macOS .app bundles is unreliable, and there's no way to control which tools an agent invokes. The underlying code (`ACPClient`, `ACPSession`, `AgentChatPanelView`, `AgentConfig`) remains intact for future re-enablement.
- Shared command mapping lives in `CommandIPCTranslator` (`HarnessCore/Commands/CommandIPCTranslator.swift`). It maps parsed `Command` values to `IPCRequest`s for headless frontends and daemon hooks; GUI `MainExecutor` consults it while keeping AppKit-specific prompts/toasts local.

## Non-obvious constraints

- Swift 6 strict concurrency is on because the package tools version is 6.0. `HarnessCore` and `HarnessTerminalEngine` additionally set `-warnings-as-errors`; concurrency/data-race/deprecation warnings in those foundational targets are build failures.
- Many long-lived classes are deliberately `@unchecked Sendable` with documented confinement: `DaemonClient`, `DaemonSubscription`, `DaemonServer`, `SurfaceRegistry`, `RealPty`, `DaemonLauncher`, `SurfaceIO`, `InputGate`, `SSHTunnelManager`, and stores. Preserve the stated lock/queue ownership when changing them.
- AppKit/SwiftUI UI types are `@MainActor`. For terminal output replay, `TerminalHostView` uses `DispatchQueue.main.async` plus `MainActor.assumeIsolated` to preserve FIFO byte order; replacing that with unstructured `Task { @MainActor in }` can reorder bursty terminal output.
- Package-level `#if os(macOS)` drops Sparkle, `HarnessTerminalRenderer`, `HarnessTerminalKit`, `HarnessOnboarding`, `HarnessApp`, and their tests on non-macOS. On Linux/headless, `HarnessDaemon`, `harness-cli`, core, engine, copy mode, theme, and `CHarnessSys` still build.
- CLI source has platform conditionals: `WindowAttachClient.swift` is excluded on non-macOS, and `attach-window` is guarded by `#if canImport(HarnessTerminalKit)`. Single-pane `attach` remains headless.
- Low-level POSIX imports are normally `#if canImport(Darwin)` / `#elseif canImport(Glibc)`. Socket helpers also route through `PlatformSys.swift` and `CHarnessSys`; avoid Darwin-only calls in daemon/CLI/core code unless guarded.
- The daemon control socket is owner-only: `DaemonServer` binds `HarnessPaths.socketURL`, chmods it `0600`, and rejects peers whose kernel peer uid differs from `geteuid()`.
- `IPCCodec.maxPayloadLength` is 16 MiB. Binary magic bytes rely on JSON frame length high bytes never colliding with `0xF5`/`0xF6`; adding a new binary frame type needs a version/capability gate because old readers treat unknown magics as oversized JSON and drop the connection.
- Subscription sockets are long-lived and full-duplex. Input and resize should ride `DaemonSubscription` where possible so resize votes live for the fd lifetime; one-shot `DaemonClient.request(.resizeSurface)` votes disappear when the socket closes.
- `wait-for`, subscriptions, resize, detach, and client lifecycle are intercepted in `DaemonServer` at the fd layer because they depend on connection identity; do not move those blindly into `SurfaceRegistry`.
- `themes.json` is the editable theme source but is excluded from the SwiftPM build. Runtime loads compiled base64 from `BundledThemesData.swift`; after editing themes, regenerate with `EXPORT_THEMES=1 swift test --filter ThemeCatalogEmbedTests`.
- `CharacterWidthTable.swift` is generated and committed. If canonical width ranges in `CharacterWidth.swift` change, regenerate with `Scripts/generate-width-table.swift`; `CharacterWidthTests` exhaustively checks all Unicode scalars.
- Release packaging order matters: `dmg`, `sign`, and `finalize` intentionally operate on an existing `Harness.app`; running `make dmg` after `make sign` without respecting the documented order can rebuild away a signature.
