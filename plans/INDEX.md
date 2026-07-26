# Plans Index — kouen-terminal

## Active Plans

| File | Title | Status |
|------|-------|--------|
| [p41-automations/dev-task-progress.md](p41-automations/dev-task-progress.md) | P41 — Automations (scheduled agent launches, `kouen-mcp`) | All tasks built, build/test/robot green, live-check pending |
| [p37-mobile-connect-v1.md](p37-mobile-connect-v1.md) | P37 — Mobile Connect v1 (QR+Tailscale hardening, in-app QR, real client) | Active — F2/F3/F4 done (F4 reconnect resilience live-verified 2026-07-13), F5 deferred pending web feature completion, F6 parked, F1 blocked on user's own APNs cert setup |
| [p8-macos27-adoption.md](p8-macos27-adoption.md) | P8 — macOS 27 Golden Gate Adoption | Active |

## Completed

→ [completed-archive.md](completed-archive.md)

### Quick ref — recent completions

| Plan | Version | Notes |
|------|---------|-------|
| P25 — iOS/iPadOS Support | Parked | Native app blocked on no paid Apple Developer Program account (confirmed still true 2026-07-23 — a free Xcode signing cert isn't one); Web/PWA MVP continues as P37 — see completed-archive.md |
| P43 — Add Repo/Folder to Workspace | Reverted | Browse-only built + live-verified, "open session here" follow-up broke on first test, torn down 2026-07-17 — see completed-archive.md |
| P42 — Workspace Sidebar Panels | Superseded | Built+shipped then reverted (too cramped in narrow sidebar), real ask continued as P43 (2026-07-17) — see completed-archive.md |
| P40 — MCP Surface Expansion + Shader Presets | Unreleased | Task Dashboard/Worktree/Host MCP tools live-checked 2026-07-13; shader UI reverted separately — see completed-archive.md |
| P39 — Competitive Feature Gaps + MAW validate gate | v4.7.2/v4.7.3 | 5 gaps (2026-07-11) + MAW-inspired merge validate gate/handoff-doc surfacing, all 6 legs live-verified; git-panel timeout root-cause fix shipped alongside (2026-07-23) — see completed-archive.md |
| P38 — Competitive Feature Gaps (A-E) | Unreleased | Diff dashboard, subagent visibility, thread overlay, Kitty conformance, scripting-hook audit — all 5 phases closed 2026-07-16 — see completed-archive.md |
| P37 Phase D/G — File Browser + Autocomplete | Unreleased | File preview/attach/browser mirror (15/15) + @ autocomplete (28/28), Opus-reviewed — see completed-archive.md |
| P36 — App Icon Auto/Light/Dark | Unreleased | Runtime Dock-icon swap via appearance KVO (macOS has no static per-appearance mechanism for `idiom:mac` icons); fixed white-edge SVG bug + 17% size-mismatch bug (2026-07-06) — see completed-archive.md |
| P35 — Fix Google/OAuth login inside embedded browser | Unreleased | Root cause: popup webview double-load severed `window.opener`; added `webViewDidClose` (2026-07-06) — see completed-archive.md |
| P34 — Block-Based Terminal | Unreleased | F1 command-boundary capture (zsh/fish `133;C`), F2 Copy Output/Command Only, F3 `kouenGetLastBlock`/`kouenGetBlock` MCP tools; bookmark deferred (2026-07-02) — see completed-archive.md |
| P33 — Visibility Gaps | Unreleased | PR checks-status dot, sidebar notification text, commit-diff popover rewire, sidebar first-reveal blank-panel fix, 4-finding Opus review pass (2026-07-02) — see completed-archive.md |
| P32 — Task-Based Agent Worktrees | Unreleased | Explicit "New Agent Task" palette action, `taskName` metadata, `archiveScript` teardown wired, task switcher via existing ⌘1-9 (2026-07-01–02) — see completed-archive.md |
| P23 — SSH Remote Host Manager | v3.9.x | Settings → Remote tab, toolbar badge, `kouen-cli remote add/list/remove`, socket auto-detect via new `kouen-cli socket-path` command (2026-07-01) — see completed-archive.md |
| SwiftUI Migration | v3.9.0–v3.11.x | Sidebar, Settings, Command palette, Notifications, Agent notch, Terminal tab bar all migrated; Browser tab bar deliberately skipped (2026-07-01, low value/high risk) — see completed-archive.md |
| P30 — Otty Feature Parity | v3.11.x | Recipes, Floating Panes, Tab Thumbnails, Frecency, Session Resurrection audit — all done; WASM plugins deferred. Kitty Graphics/Sixel/iTerm2 image protocols were NOT deferred — shipped 2026-05-30 (`0fc22101`/`1a07a4aa`), this line was stale until corrected 2026-07-14 during P38 Phase D (see completed-archive.md) |
| P28 — Browser DevTools API | v3.7.0–v3.9.0 | kouen-mcp 14 browser tools, replaces chrome-devtools-mcp |
| Sidebar SwiftUI Migration (Option B) | v3.9.0 | NSTableView → SwiftUI List; RL-051 eliminated permanently |
| KouenCore Package Split | v3.9.0 | Core → Core + Commands + IPC + Settings (4 packages) |
| P27 — Pane Drag-and-Drop | v3.5.0 | Drag grip → drop zone overlay → swapPanes / joinPane |
| P26 — Agent Connection | v3.9.0 | kouen-mcp 14 browser tools + terminal tools; MCP config wired globally for Claude/Codex/Kiro/Gemini |
| P12 — MCP Server | v3.9.0 | 27+ tools total; kouen-mcp replaces chrome-devtools-mcp for all agents |
| P4 — LSP + Code Viewing | v3.2.0 | `kouenErrors` MCP tool surfaces LSP diagnostics to agents |
| SwiftUI Settings | v3.9.4 | All settings pages migrated AppKit → SwiftUI |
| Command History Search | v3.9.x | ⌘R overlay, fuzzy match, shell history integration |
| IDE File Tree (Phase 1) | v3.9.x | Sidebar file tree, project root follows git root, session switching |
| Git Panel Memory Leak | v3.9.4 | State caching prevents NSTextField allocation spikes |
| P5 — ACP Client | Shelved | Erased entirely by `c4e1e15` ("remove: ACP + ⌘I"); P29 reactivation plan abandoned, not pursuing |
