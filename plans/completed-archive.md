# Completed Plans Archive

All plans below are **done** and merged into main.

---

## P1 — Sidebar Performance (v1.3.0)
- Cached `sidebarRows` (O(1) per NSTableView delegate call)
- `surfaceIndex` dict for O(1) surface lookup
- Theme guard (skip `applyThemeToAllHosts` when unchanged)
- Metadata probe dedup (one git probe per directory per cycle)
- Sync divider positioning (layoutSubtreeIfNeeded before setPosition)

## P3 — N-ary Split Panes (v1.5.0)
- Same-direction flatten into single NSSplitView + N subviews
- Equal distribution in `layout()` at `totalSize/N` intervals
- `isApplyingPositions` recursion guard
- Host reuse (detach before rebuild, re-insert without losing Metal)
- `viewDidMoveToSuperview()` fix for CADisplayLink restart
- Split down removed entirely

## P6 — UI Polish (v1.5.0)
- SF Symbols everywhere (disclosure chevrons, group buttons, worktree remove)
- `KouenDesign.configurePillButton()` shared helper
- `FontSize`, `IconSize`, `symbolConfig()` design tokens
- Animated disclosure chevron rotation
- Git stage checkbox pulse animation
- Sidebar vibrancy `.sidebar` material

## Sidebar & Split Issues (v1.6.0)
- Sidebar left/right toggle — real-time (no restart)
- NSSplitView reorder via remove+reinsert (CASE-007)
- Right-click context menu for position toggle
- Traffic light inset handled for both positions

## Session Grouping (v1.3.0)
- `SidebarSessionRow` enum (groupHeader + session)
- Project group by git root
- Collapse/expand with animated chevron
- Drag/drop with session ID (not row index)
- Group header `+` and `...` buttons (SF Symbols)

## Panel Session Performance (v1.3.0)
- All P1–P6 perf fixes merged
- F1: File tree auto-update per session (git status dots, FSEvents watcher)

## P6 — File Editor Opacity Parity (v2.2.3 / Unreleased, 2026-06-09)
- `refreshEditorPanelFill()` in `ContentAreaViewController` — applies `terminalBackground × opacity` to the `fileEditorPanel` CALayer
- Wired into `applyChrome()` (responds to theme/opacity changes) and `showFileEditorSplit()` (panel creation)
- Subviews (FileEditorView, FileEditorTabBarView, SyntaxTextView, gutter) required no changes — all already transparent
- Key insight: Metal renderer handles terminal alpha itself; AppKit-only panels must apply it explicitly to their layer
- `KouenSettings.clampedOpacity` returns `Float` — must cast to `CGFloat` for `withAlphaComponent`

## P2 — Async IPC Refactor
- IPC and metadata refresh moved off the main actor via `DaemonClientActor` and async background task contexts
- `SessionCoordinator` snapshot sync no longer blocks UI interactions on daemon round-trips

## P9 — Complexity Reduction
- Extracted `LiveResizeGeometry`, `PasteController`, and `SelectionResolver` from terminal surface code
- Split CLI handlers into `KouenCLI+*.swift` extension files while preserving command dispatch behavior
- Extracted `WindowInputRouter` with focused CLI tests
- Extracted daemon `HookExecutor` and `FormatContextBuilder`
- Documented intentional `GridCompositor` duplication between app and onboarding packages

## P10 — Terminal Performance and Convenience
- Lazy scrollback reflow shipped for live resize performance
- Local workspace symbol completion and completion popup shipped
- IDE mode, focus mode, session state dots, diff highlighting, git preview/history improvements, and task board sidebar shipped
- ACP sidebar work remains intentionally shelved; implementation is preserved but not exposed

## P5 — ACP Client (Shelved)
- ACP core implementation exists in `KouenCore/ACP`: `ACPClient`, `ACPSession`, `ACPProcess`, `ACPTransport`, `ACPMessage`, and `AgentConfig`
- `AgentChatPanelView` and settings-side ACP agent configuration remain in the app code
- Runtime entry point is intentionally disabled in the sidebar (`[ACP SHELVED] connectAgentIfNeeded()`)
- Shelved rationale: adapter binaries not widely available, PATH resolution in .app bundles unreliable, no tool sandboxing
- Full context: `agent-memory/knowledge/patterns/acp-client.md`
- Direction: ACP = Kouen→agent (embedded chat). MCP (P12) = agent→Kouen (tool server). Both share `ACPMessage` framing from `KouenCore`.
- Re-enable criteria: `brew install` for adapters, agent tool sandboxing at protocol level

## P37 Phase D — File Browser (v4.x, Unreleased at close)
- File preview, file attach, browser mirror — Completed 15/15
- Phase E built on top same pass; post-ship bug-fix pass done via real-phone testing

## P37 Phase G — Autocomplete (v4.x, Unreleased at close)
- `@` file-path, shell completion strip, AI suggestion via `claude` CLI
- Completed 28/28, Opus review passed

## P38 — Competitive Feature Gaps (CLOSED 2026-07-16)
Cross-agent diff dashboard / subagent pane visibility / thread-view / image protocol / scripting hook parity. All 5 phases built 2026-07-14, build/test/robot green throughout. Live interactive click-through skipped for B/C/D/E (user decision), A was live-verified.
- **Phase A** — Cross-agent worktree diff/review dashboard (Agents segment in `GitPanelView` + merge/handoff action). Completed 10/10, code-reviewed + fixed, live-verified by user 2026-07-14 (merge/conflict flow tested in real `make preview`).
- **Phase B** — Subagent visibility (badge indicator + proc-scan + Claude Code hook push, not a literal auto-split pane — see original `design.md` for why). Closed 23/23 — rewritten from scratch after original pass was lost to a concurrent git operation; build/test 87/87, robot 26/26; live check skipped unverified per user decision.
- **Phase C** — Thread overlay (captured-command list on top of P34 block capture, ⇧⌘L). Closed 20/20 — build/test 17/17, robot 26/26, zero regression on P34's own suite; live check skipped (cross-pane jump-to-block untested) per user decision.
- **Phase D** — Kitty graphics conformance slice (`a=q` query, `a=t`/`a=p` place-by-id, `a=d` delete). Closed 8/8 — finding: image protocols were NOT deferred, had already shipped 2026-05-30 (INDEX/plan-doc corrected then); conformance slice build/test 22/22, robot 26/26; live check against a real client skipped per user decision.
- **Phase E** — Scripting hook parity audit (`paneCreated`/`paneRemoved` doc-vs-reality gap). Closed 6/6 — audit found capability parity already existed, no hook-parity build needed; build/test/robot green; low-priority live check skipped per user decision.

## P39 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed / tmux / MAW) — shipped v4.7.2/v4.7.3
Phases A-D (remote workflow parity, sidebar dev-server visibility, git workflow depth, fleet visibility) done 2026-07-11, all 5 gaps code-reviewed. Re-opened 2026-07-23 to adapt the one thing worth taking from GitHub MAW repos (`bobisme/maw`, `Soul-Brews-Studio/maw-js`, `laris-co/multi-agent-workflow-kit`, `haoyu-haoyu/Multi-AI-Workflow`, researched via agy) — deterministic build/test validation before a worktree merge. All four MAW repos otherwise already match Kouen's existing tmux/git-worktree agent-isolation pattern.

**MAW-pattern validate gate (shipped v4.7.2).** Explicit user constraint honored throughout: validate+merge must never run automatically — `mergeWorktreeAction`/`performMerge`'s NSAlert confirm remains the only path to an actual `git merge`; this only adds an automated validate step that runs *before* the confirm dialog, so the user decides with pass/fail already in hand.
- `SignalFileRouter.validationSteps(at:)` — reuses existing stack-detection to return ordered build/test commands (swift: `swift build`+`swift test`; python: `pytest -q`; node family: package-manager `test` script via lockfile detection, only if `package.json` defines one). Empty = skip, never a failure.
- `GitPanelView.validateWorktree(at:)` + `runShellCommand` (merged stdout+stderr pipe, 5-min kill ceiling) run those steps; `performMerge`'s NSAlert shows the pass/fail summary, `.warning` style on failure. Merge/Cancel and the underlying `git merge` call unchanged.
- Structured handoff-doc surfacing: `GitPanelView` reads the existing `handoff` skill's `agent-memory/HANDOFF.md` (reuse over inventing a new schema) and shows its `Note:` in the merge dialog (human-review leg). `kouenSpawnAgent` (`Tools/kouen-mcp`) separately surfaces the full untruncated note + `Suggested skills:` as `priorHandoff`/`priorHandoffSuggestedSkills` spawn-result fields, non-auto-typed — same pattern as the pre-existing `detectedStack`/`detectedHint` (agent-to-agent leg). One shared reader (`SignalFileRouter.HandoffInfo`) in KouenCore, two callers with different truncation needs.
- Two rounds of advisor-style self-review before shipping caught and fixed: PATH resolution (`runShellCommand` fallback missed Homebrew tools when launched from Dock — fixed via shared `Process.resolveExecutablePath(_:)`, later widened with a 4th candidate `~/.volta/bin/<name>` after live-testing found this machine's node toolchain is 100% Volta, zero Homebrew node; nvm/asdf/fnm remain a known, documented gap), a Merge-button re-entrancy guard, a truncation-wrong-for-agent-context bug (fixed via the `HandoffInfo` split above), and a `Process.zoxideQueryAll` DRY duplication.
- **All 6 MAW legs live-verified for real, not just build/test-green**: isolation (pre-existing), validate-gate incl. the real-machine PATH fix, handoff-doc format reuse, human-review-at-merge (real screenshot: validate pass message + handoff note + uncommitted-changes warning all rendered correctly, user clicked Merge for real, toast+sidebar update confirmed), agent-to-agent handoff (`kouenSpawnAgent` called against a real isolated `make preview` daemon, real unedited JSON response with the real `HANDOFF.md` text). Known, not live-tested: the swift/python validate branches specifically; system `python3` has no `pytest` installed on this dev machine (would misreport a python-stack validate as "test failed" for an environment gap, not fixed — would require a process-spawn availability pre-check that conflicts with `validationSteps`'s pure/no-spawn design, documented as a known limitation instead).
- Verification throughout: `swift build` clean for both `Kouen` and `kouen-mcp` products, `swift test` filtered suite reached 79/79, `Tests/robot/run.sh` 27/27 (including the pre-existing "never `--no-ff`"/"no auto-resolve" merge guards, unaffected) at every step.

**Root-cause git-panel timeout bug (shipped v4.7.3, found immediately after v4.7.2 install).** User reported fetch/pull/commit/push all erroring in the Git panel. Debug-mantra repro: a throwaway direct-daemon-call test reproduced `DaemonClientError.timeout` on a real `git fetch --dry-run`; a real `git fetch --dry-run` in Bash measured 3.48s. Root cause: `DaemonClient.request()`'s default `timeout: TimeInterval = 2` was never overridden by `GitPanelView.runGitWithStatus` — any git op needing real network/SSH I/O would client-side-timeout even though the daemon's own git process (60s kill-ceiling) was still succeeding in the background. Pre-existing latent bug, unrelated to the MAW work above, coincidentally surfaced now by real network timing exceeding 2s (same bug class as RL-048's earlier WKWebView 2s→35s fix, never applied to git ops at the time). Fixed: `runGitWithStatus` now passes `timeout: 30`. Secondary display bug fixed alongside: `DaemonClientError` conforms to `CustomStringConvertible` not `LocalizedError`, so `error.localizedDescription` produced Foundation's generic NSError-bridged string (the confusing text in the user's screenshot) instead of the real message — fixed by preferring `(error as? DaemonClientError)?.description`. Verified: repro test re-run against real production daemon with the fix succeeded (3.49s); full filtered suite 79/79, robot 27/27.

**Research discipline note:** two later agy research rounds (token/cost tracking + dashboard survey; tmux/cmux-native-agent + Supacode/Superset re-check) each returned "gaps" that, verified against real graphify+source reads, were already fully implemented in Kouen (OSC 133, Kitty/iTerm2 image protocol, sync-panes broadcast, per-pane border status, browser pane scriptable+MCP, composer, remote SSH persistence, tool-approval GUI). Token/cost tracking judged unnecessary — already fully covered by the separate `~/Git/Personal/codexbar` project. Conclusion after both rounds: no further competitive gaps remain worth building; Kouen is at/ahead of parity with tmux/cmux/WezTerm/Supacode/Superset/MAW.

## P40 — MCP Surface Expansion (Tasks/Worktrees/Hosts) + Shader Presets
- Completed + live-checked 2026-07-13: Task Dashboard + new `cwd` field verified via real `make preview`, Worktree/Host verified via real MCP calls
- Shader UI reverted earlier (separate user call) — nothing to check there

## P42 — Workspace Sidebar Panels (CLOSED/SUPERSEDED 2026-07-17)
- Stacked always-visible Sessions/Files/Git panes in sidebar
- Built + shipped (Tasks 1-2), reverted after real `make preview` use — too cramped in a narrow sidebar
- Real ask was "Add to Workspace" (merge another repo's Files/Git in, tab-switch style) — continued as P43

## P43 — Add Repo/Folder to Workspace (REVERTED 2026-07-17)
- `Workspace.extraRepoRoots`, daemon-synced, picker on Files/Git tabs
- Built + live-verified (browse-only); a same-day "open session here" follow-up didn't work on first test
- User chose to tear the whole feature down rather than keep debugging

## P25 — iOS/iPadOS Support (Parked 2026-07-23)
- Native iPad app (Phase 0-6: shared renderer extraction, mobile IPC transport, UIKit terminal MVP, app shell, multiplexer parity, polish) — hard-blocked since 2026-07-04 on no paid Apple Developer Program account (required for TestFlight/App Store/APNs push)
- Pivoted to Web/PWA MVP instead — continued as `p37-mobile-connect-v1.md` (W1 daemon bridge + multi-device pairing shipped + live-verified 2026-07-07; W2-W9 resize-sync/session-switcher frontend/file preview+attach/browser-open/command-palette/git-panel/LSP/notification-inbox folded into that doc's ongoing scope)
- Closed 2026-07-23: checked whether a fresh Xcode "Apple Development" signing certificate changed the blocker — confirmed it's only the free Personal Team cert (auto-issued, no payment), not a paid Developer Program enrollment; TestFlight/App Store/APNs remain blocked. Cross-checked against this repo's own release scripts (`Scripts/finalize-release.sh`'s own comment: "this fork's releases are plain `git tag` + `gh release create`, no notarization" — ad-hoc signing only, no Developer ID in use here) and `codexbar`'s (its Developer ID cert belongs to that project's upstream author, not this user) — neither project is evidence of a paid account existing. Revisit only if a paid Apple Developer Program account is actually obtained.
- Design mockup `agent-memory/plans/p25-mobile-session-switcher-design.html` stays in `plans/` (not archived) — still the live design reference for P37 Phase C, already shipped from it

## P7 — Sidebar UI Polish
- Large-screen sidebar group header button visibility/alignment completed
- Session card spacing and file editor tab bar overlap polish completed

## P4 — Terminal-First Code Viewing + LSP
- Track 1 (Syntax Highlighting): `SyntaxTextView` regex-based, 30+ languages, wired into `FileViewerViewController`
- Track 2 (Vi Navigation): `gf` path-under-cursor, `gd`/`K`/`]d`/`[d` LSP-backed, `:view`/`:edit`/`:split`/`:vsplit`/`:find`, `kouen view` CLI
- Track 3 (LSP Command API): `kouen lsp start/status/hover/definition/diagnostics`
- Follow-ups (`:recent`, `:grep`, `:make`) moved to P24
- MCP surface: `kouenErrors` tool in `kouen-mcp` exposes LSP diagnostics to AI agents (see P12/architecture/mcp-server.md)

## P21 — Hermes-Inspired Agent Platform (Shelved → P24 partial)
- Status: Shelved — ACP adapters not publicly available
- Actionable UX layer (agent auto-start, status badges, selection via config) absorbed into P24
- Remaining layers (ACP sideband, multi-provider, brain, orchestration, execution backends) stay shelved for future re-enable
- AgentCatalog + `:agent` ex command + AgentBridge partially implemented and preserved

## P22 — Long-Session Responsiveness Hardening
- Adaptive polling (skip-on-idle when no PTY output for 10s)
- Off-main output processing for metadata refresh
- Scrollback compaction (trim to N lines when idle)
- Renderer micro-batch (coalesce rapid redraws)
- `salvageRowKeys` optimization for grid diff
- Snapshot fanout: `metadataOnly` flag prevents unnecessary UI rebuilds

## P11 — Scripting & Config API (WezTerm parity)
- `kouen.config.get/set` (11 allowlisted keys)
- `kouen.keys.bind/unbind/reload`
- `kouen.commands.run` (Promise-based)
- Pane mutators: `sendText/split/close`, session `spawn`
- `kouen.events.on/off` bridge (snapshotChanged/configReloaded)
- All in `ScriptAPI.swift`

## P12 — Agent Orchestration via MCP
- PBI-ORCH-001–005 complete
- `kouen-mcp` binary: JSON-RPC 2.0 over stdin/stdout, protocol v2024-11-05
- 27 tools across 6 categories: session/pane control, file I/O, git, workbench, browser pane, agents
- Tool policy gating: `~/.config/kouen/mcp-policy.json` or `KOUEN_MCP_ALLOW_CONTROL=1`
- MCP badge on tab bar via `lastMCPControlAt` timestamp on `Tab` snapshot
- Browser pane fully controllable: open/navigate/snapshot/interact/close
- Workbench tools: `kouenFind`, `kouenGrep`, `kouenRecent`, `kouenErrors` (LSP diagnostics)
- Direction: agent→Kouen (opposite of shelved ACP which is Kouen→agent)
- Full architecture: `agent-memory/knowledge/architecture/mcp-server.md`

## P13 — Split Pane Parity
- PBI-SPLIT-001–005 implemented
- Same-direction flatten, equal distribution, resize handles
- Pane zoom/unzoom, rotate, swap
- tmux-compatible split commands (`:sp`, `:vsp`)
- Merged via PR #10

## P15 — Integration Roadmap
- Sequencing plan for P4+P11+P12+P13+P14+P16
- All steps complete — coordination artifact, not a feature itself

## P16 — Agent/Session Board
- PBI-BOARD-001–005 complete (006 closed — auto-clear sufficient)
- Sidebar board tab: session cards with agent status, timing, output summary
- CLI: `kouen-cli board`
- MCP read-only exposure

## P17 — Structural Refactor
- PBI-001/002/003/005 complete
- SessionCoordinator decomposed into services
- UI/ subfolder reorganization
- PBI-004 deferred (build time 9s, not worth risk)

## P18 — UI Automation (Robot Framework)
- 25 automated tests via Robot Framework + osascript (System Events)
- CLI verification paths
- No Appium/XCUITest dependency
- Accessibility identifiers added to key UI elements

## P19 — Terminal Workbench Migration Layer
- PBI-WB-001–007 fully implemented
- `:find`, `:grep`, `:make`, `:errors`, `:recent` workbench commands
- IDE migrant bridge (VS Code-like workflows in terminal)

## P20 — Kouen-Term Agent (Shelved)
- Shelved — terminal-first flow sufficient (kiro-cli/claude/codex typed directly)
- Revisit when pain point emerges
- Design docs preserved for future re-enable

## P14 — Embedded Browser Pane
- PBI-BROWSER-001–005 implemented
- WKWebView pane for localhost preview
- kouen-mcp browser tools (navigate, screenshot, evaluate)
- Post-release fixes in v2.7.1

## P24 — Supacode-Inspired Competitive Features (Consolidated)
- Status: Complete (archived from active plan list on 2026-06-20)
- Competitive analysis consolidated Supacode, P21 actionable agent layer, and P4 follow-ups into Kouen-specific parity work.
- Key completed scope: project config/lifecycle scripts direction, agent status/auto-start UX, worktree-per-session model, GitHub PR/CI integration plan, sidebar density, and CLI scripting model.
- P21 ACP sideband/provider/brain/execution layers remain shelved separately; P4 follow-ups were absorbed into P24.

## P28 — Browser DevTools API (v3.7.0 → v3.9.0)
- kouen-mcp 14 browser tools: Open, Navigate, Wait, Snapshot, Interact, Close, Screenshot, Network, Cookies, Storage, Evaluate, GoBack, GoForward, Reload
- IPC wiring: BrowserRequestPayload → DaemonServer → GUI BrowserPaneView → MCP response
- ToolPolicy gate for control tools (evaluateJS, interact, close, navigate)
- MCP config wired globally (Claude, Codex, Kiro, Gemini)
- Replaces chrome-devtools-mcp (~70-75% token savings)

## Sidebar SwiftUI Migration — Option B (v3.9.0)
- NSTableView → SwiftUI List via @Observable SidebarListModel + NSHostingView
- Eliminates RL-051 crash class (row-index out-of-range) permanently
- KouenSidebarPanelVC reduced from 72KB → ~30KB
- Context menus via .contextMenu {} SwiftUI modifier
- snapshotChanged → model.update() (SwiftUI handles diffing)

## KouenCore Package Split (v3.9.0)
- KouenCore (30+ subdirs) → KouenCore + KouenCommands + KouenIPC + KouenSettings
- 20+ files moved to KouenCommands (parser, keybindings, format, pane layout)
- IPC types moved to KouenIPC (IPCMessage, IPCCodec, models)
- Settings moved to KouenSettings (AIAgentConfig, KouenSettings, ProjectConfig)
- Faster incremental builds, cleaner dependency graph

## SwiftUI Migration (v3.9.0 – v3.11.x)
- Sidebar session list + chrome (pill, tab bar, section label, footer) → SwiftUI List + @Observable, `KouenControls.swift` deleted, eliminated RL-051 (row-index out-of-range) crash class
- Settings (S1–S9) → SwiftUI, `SettingsViewController` eliminated
- Command palette → `NSHostingController(rootView: PaletteView)` (wave 2, `760705a`)
- Notifications inbox → `AgentInboxPanelView` SwiftUI (wave 2)
- Agent notch → `AgentNotchRootView: View` SwiftUI content, `NSPanel` shell (wave 2)
- Terminal tab bar → hybrid: `TerminalTabBarView: NSView` shell + SwiftUI pills (`TerminalTabBarBody`, `TabPillView`), drag-drop stays AppKit (wave 2)
- Net −424 lines across the wave-2 four components; no manual `NSTableViewDataSource`/cell-reuse left in these paths
- **Browser tab bar deliberately skipped (2026-07-01)** — still `NSStackView`/`NSButton` in `BrowserPaneView.swift`; works fine, no bug class to eliminate, not worth WKWebView-bridging regression risk

## P30 — Otty Feature Parity (v3.11.x)
- Command Recipes (⌘⇧R) — `RecipesStore` + `RecipePickerController`, fuzzy picker
- Floating Terminal (⌘⌥F) — `FloatingPaneController`, NSPanel, persisted frame
- Tab Overview (⌘⇧\\) — `TabOverviewController`, thumbnail grid, click to switch
- Frecency dir picker (⌘⇧J) — zoxide-powered, ↩ cd / ⌘↩ new tab
- Session Resurrection audit (Zellij-inspired) — verified quit/relaunch, daemon crash/restart, reboot, multi-window restore
- Block output tint + AI explain (Phase 12b/12c) — border, collapse/expand, re-run button
- Vi mode at terminal input layer
- Deferred (intentional, not blocked): Kitty Graphics Protocol, WASM plugin runtime — no demand yet

## P23 — SSH Remote Host Manager (v3.9.x – 2026-07-01)
- Settings → Remote tab: host list (add/remove/duplicate), detail form (Name/SSH target/Port/Identity/Jump/Socket path), Save/Revert, Connect/Disconnect
- Toolbar badge showing active remote host name; click disconnects (or opens Settings → Remote when local)
- Socket auto-detect (PBI-SSH-008, 2026-07-01): new `kouen-cli socket-path` command prints `KouenPaths.socketURL.path`; `SSHTunnelManager.detectSocketPath` runs it over `ssh` reusing the tunnel's arg-validation seams (`validatedSSHTarget`/`validatedUserSSHArgs`); consumed by both `SettingsRemoteView`'s "Detect" button and `kouen-cli remote add --detect` (alternative to passing `--socket` by hand)
- TCP transport remains suspended — no TLS layer, SSH tunnel covers all current remote use cases

## P32 — Task-Based Agent Worktrees (2026-07-01 – 2026-07-02)
- Explicit "New Agent Task" command-palette action — `SessionLifecycleService.addAgentTask(to:taskName:)` calls `WorktreeManager.create` then the existing `addSession(to:cwd:name:)`, reusing P24's `setupScript` auto-run for free; failure path (no git repo) shows `NSAlert` instead of silently no-oping
- `Tab.taskName: String?` added (optional-backfill decode pattern); `displaySubtitle`/sidebar title precedence now `taskName > gitBranch > cwd`
- Bonus fix: `worktreePath`/`parentRepoPath`/`taskName` were never actually threaded from the GUI's `addAgentTask` → `.newSession` IPC call (only the CLI did) — wired through for real
- `archiveScript` (schema-only, zero call sites before this) wired into `SurfaceRegistry.handle(.closeSession)`, runs via `/bin/sh -c` with a 30s hard-kill timer before `WorktreeManager.remove`
- Task switcher: no new UI needed — existing ⌘1-9 (`MenuTarget.selectWorkspaceNumber`) already reaches task-worktree sessions as regular workspace entries
- `.kouen-worktrees/` added to `.gitignore` (was getting staged as regular files)
- Tests: `WorktreeIsolationTests` (core), `WorktreeIsolationDaemonTests` (archiveScript teardown) — both 10/10; `Tests/robot/run.sh` 10/10
- **Shipped (2026-07-02) — `setPaneLabel` MCP tool for pane purpose/label tagging.** Backlog item from 2026-07-02 (below, corrected on build): the original note assumed reusing `IPCRequest.updateTabTitle` needed "no new schema/field." That assumption was wrong on inspection — `updateTabTitle` actually mutates `Tab.title` (tab-scoped, via `SessionEditor.updateTabTitle`'s `tabIndex(surfaceID:)` lookup), not `PaneSurface.title`, and is gated on the per-tab `automatic-rename` flag so it silently no-ops or gets clobbered by the next OSC title update — unusable as a durable per-pane label, and the wrong granularity besides (can't protect one pane's label without breaking OSC titles for its sibling in the same tab). Also found `PaneSurface.title` itself was never mutated anywhere in the codebase (vestigial). Built instead: a dedicated `PaneSurface.label: String?` field (`PaneNode.swift:101`), never touched by OSC/shell output; `PaneNode.setSurfaceLabel(_:label:)` tree-mutator; `SessionEditor.setPaneLabel`; new `IPCRequest.setPaneLabel(surfaceID:label:)` + `SurfaceRegistry` handler; exposed as `"label"` in `kouenList`'s `paneJSON`; policy-gated `setPaneLabel` MCP tool (`ToolPolicy.dangerousTools`, mirrors `sendPaneText`). Tests: `PaneLabelDaemonTests` (4/4 — set/read-back, nil clears, doesn't touch `title`, unknown surface errors). `swift build`/`swift test` (2 pre-existing unrelated failures only)/`Tests/robot/run.sh` 10/10 clean.
- **Follow-up shipped (2026-07-02) — `spawnSession`/`splitPane` set a pane label atomically.** User asked to make labeling "auto" for an agent's own workflow; landed on: whichever agent creates a pane labels it in the same call, rather than the daemon guessing purpose from output (no terminal tool — tmux included — does true semantic auto-labeling; tmux's `automatic-rename` only shows the literal foreground process name via `pane_current_command`). Without this, `spawnSession`/`splitPane` only return `sessionId`/`paneId`, so an agent wanting to label its own new pane needed a 3rd round-trip (`kouenList`) just to resolve a `surfaceId` first. Added optional `label` param to both; `KouenDaemonTools.labelPrimarySurface`/`labelPaneSurface` resolve the surface via one internal snapshot lookup and call `setPaneLabel` in the same tool call — best-effort (doesn't fail pane creation if the label can't be applied). No live-daemon test kouen exists for `KouenDaemonTools` in this codebase (confirmed via grep), so verified end-to-end manually against a real headless daemon over the actual MCP stdio protocol (`spawnSession` with `label:"build"` → `kouenList` shows it on the new pane) rather than build new test infra for one small feature; the underlying `setPaneLabel` mechanism already has persisted coverage via `PaneLabelDaemonTests`.

## P33 — Visibility Gaps: PR status, cross-pane notifications, diff popover (2026-07-02)
- PR checks-status dot: found `PRStatusPoller` was dead/duplicate code — the *live* PR path was already `SidebarListModel.fetchGitMetadata`. Swapped its hand-rolled `gh pr view` call for `GitHubCLIClient().prForCurrentBranch` (which parses `statusCheckRollup`), added `RepoGitMetadata.prChecksStatus`, rendered as a green/red/yellow dot next to the existing `#123` badge. Deleted `PRStatusPoller.swift` + its dead `AppDelegate` call site.
- Sidebar notification text: found `OSCNotificationParser` (OSC 9/99/777) has zero call sites — the *live* path is IPC `.notify` → `SurfaceRegistry.markWaiting` → `Tab.status/.notificationText`, which already drove a per-pane glowing ring, dock badge, native notification, and Notch panel. Only the sidebar itself was missing the message text — added `SidebarSessionItemRow.waitingNotificationText`, shown in `.systemBlue` when `tab.status == .waiting`.
- Diff popover: `GitPanelView.presentCommitDetail` was a fully-built, zero-call-site popover (file-nav bar + colored diff, same dead-code-next-to-live-path shape). Rewired the commit-card click to it (`previewCommitDetail`); old full-tab-open flow kept via context menu ("Open Full Diff in Tab").
- Same-session bug found + fixed: sidebar rendered blank/blurred on first `⌘\` reveal after every launch, predating this work — root cause was `sidebarContainer.translatesAutoresizingMaskIntoConstraints = false` with no constraint of its own, colliding with an existing CASE-042 fix (`layoutSubtreeIfNeeded()`) that collapsed it to 0-width. Fix: removed the `= false`. See RL-062/CASE-061.
- Post-commit review (Opus, 12-agent workflow) found + fixed 4 defects: a popover-anchored-to-detached-view crash race in `previewCommitDetail` (guard `card.window != nil` after await, RL-063), `waitingNotificationText` only checking `activeTab` instead of scanning all tabs (contradicted its own "regardless of focus" goal), a `gh` path-resolution mismatch between the sidebar's availability guard and `GitHubCLIClient`'s actual fetch (added the same `which gh` fallback to both), and a duplicated `git show` invocation (extracted to `fetchCommitDiff`).
- `swift build`/`swift test` (only the 2 pre-existing unrelated failures)/`Tests/robot/run.sh` all clean throughout.

## P34 — Block-Based Terminal / Command Grouping (2026-07-02)
- F1: zsh/fish shell-integration now emit `133;C;<base64 command>` via their native preexec hooks (the shell's own knowledge of the typed command, not a screen-scrape guess) — no shell previously emitted this boundary at all. bash deferred (DEBUG-trap footgun, no reentrancy guard yet). New per-pane `TerminalBlockStore`/`TerminalBlock` (`KouenTerminalEngine/Emulator/TerminalBlock.swift`), decoupled from scrollback so a block survives `dropHistoryHead` eviction. Fixed the pre-existing `ponytail:`-flagged Re-run regex-prompt-strip to use the real command text. Bonus: emitting `C` also fixes the latent bug where `onCommandFinished`'s duration/"long command finished in background" notification never fired against a real shell.
- F2: `BlockActionBar` gained Copy Output Only / Copy Command Only (shown only when the pane's shell actually captured a block — bash panes keep the original 2-button bar). `TerminalBlock` promoted back to public; `block(atPromptLine:)`/`lastBlock`/`block(id:)`/ranged `captureLines(fromLine:toLine:)` added across `TerminalEmulator`→`KouenGridTerminal`→`KouenTerminalSurfaceView`. Bookmark explicitly deferred by user, not built.
- F3: `kouenGetLastBlock`/`kouenGetBlock` MCP tools. Found the daemon never parses OSC 133 live (only client-side `TerminalEmulator` instances do) — reused `RealPty.captureGrid`'s existing "replay retained scrollback through a fresh headless instance on demand" pattern instead of building a new always-on daemon parser; not retroactive backfill since the replayed bytes contain the same live `C`/`D` sequences originally parsed. New `IPCRequest.getBlock`/`IPCResponse.blockInfo(BlockSummary?)` (`KouenIPC`), `RealPty.block(id:)`, `SurfaceRegistry.handle(.getBlock)`.
- Interviewed before implementing (plan doc's own premise was partly wrong — no shell emitted `133;B`/`133;C` at all, and `SemanticMark` never persisted command text); consulted `advisor` before touching 3 shell scripts and again before the F3 daemon-architecture question. A transient signal-11 crash in an unrelated Metal/GPU test during one full-suite run was confirmed pre-existing/order-dependent via `git stash` A/B against the clean baseline commit, not caused by this work.
- Tests: `TerminalBlockStoreTests`, `KouenGridTerminalTests` block-forwarding cases, extended `ShellIntegrationTests`. `swift build`/`swift test` (2 pre-existing unrelated failures only)/`Tests/robot/run.sh` 10/10 clean throughout.
- **Shipped (2026-07-02) — replaced ⌘-click with a right-click context menu for block actions.** Resolves the 2026-07-02 backlog decision below (direction (a) chosen over (b) via user pick). `BlockTintOverlay`'s `BlockActionBar` (~95 lines) removed entirely; ⌘-click in `KouenTerminalSurfaceView+SelectionAndLinks.swift` now only opens links (matching other terminal apps' convention). Block actions (Copy Output Only / Copy Command Only / Re-run) moved into `menu(for:)` (`+Find.swift`), gated on whether the clicked line falls in a captured OSC-133 block; degrades to Re-run-only for shells that only emit `A`/`D` (bash). `cell(at:)` widened from `private` to internal (cross-file access within the same type's extensions needs internal, not private). Orphaned `selectionString`/`copyBlock()` wrappers deleted (zero remaining call sites after the move). Tests: `BlockContextMenuTests` (2/2 — full menu when a block is captured, Re-run-only otherwise).

## P35 — Fix Google/OAuth login inside embedded browser (2026-07-06)
- Original hypothesis (Google's anti-phishing embedded-webview block) was wrong — live repro reached the consent screen fine, which that block would have prevented.
- Real root cause: `BrowserPaneView.createTab` called `.load()` on the popup webview after WebKit had already created it via `createWebViewWith`, severing `window.opener` (WKWebView auto-loads `navigationAction.request` into the returned view — loading it again yourself breaks the opener link). Also missing: `webViewDidClose` (JS `window.close()` was a no-op).
- Fix: `createTab(url:configuration:skipLoad:)` skips the redundant load on the popup path; `createWebViewWith` returns the created view (was `nil`); added `webViewDidClose`.
- Verified end-to-end: Google login → Allow → popup auto-closes → claude.ai loads authenticated. Full case + diagnostic technique: `knowledge/ui/browser-pane.md` → "CASE: OAuth login (Google) never completes — P35".
- Other providers (GitHub, Microsoft, etc.) not separately tested, but same code path — expected to work for any provider using the standard `window.open()` popup pattern.

## P36 — App icon Auto/Light/Dark support (2026-07-06)
- Original ask was about the app icon (logo), not in-app UI theme. New mark green `#567a52` (was `#93a889`, 2.16:1 contrast — now 4.11:1). Fixed a real white-edge bug: non-square SVG viewBox letterboxed on raster, made square to fill edge-to-edge.
- Dark OS-native swap: `.icns`/`CFBundleIconFile` static path and asset-catalog `AppIcon.appiconset` per-appearance renditions both ruled out (macOS `"idiom":"mac"` icons never supported appearance variants via classic appiconset+actool — iOS-only mechanism; real macOS adaptive icons need Tahoe's Icon Composer `.icon` format, GUI-only, out of reach).
- Real fix: runtime Dock-icon swap — `AppDelegate.updateDockIconForCurrentAppearance()` sets `NSApp.applicationIconImage` from the existing appearance-KVO observer, using new bundled `AppIcon-1024-dark.png` (copied in by `Scripts/package-app.sh`).
- Follow-up bug: dark tile rendered ~17% bigger — root cause was macOS's icon compositor auto-shrinking only statically-declared `.icns` icons, not runtime-injected `NSImage`s. Fixed by manually pre-shrinking the dark PNG to ~85.6% scale on a padded canvas (baking in what the compositor gives static icons for free), confirmed pixel-equal to the light icon in a side-by-side Dock screenshot.
- Verified end-to-end: `make prod` → signed `Kouen.app`, Dock icon confirmed dark in Dark mode by Vit. Caveat: only the running app's Dock tile swaps — Finder/Launchpad/Get Info keep the static light icon (read before the process exists).
