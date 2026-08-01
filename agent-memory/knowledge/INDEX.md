# Knowledge Index — Harness Terminal

## Files

| File | Domain | Tags | Score A/P | Summary |
|------|--------|------|-----------|---------|
| ui/appkit-metal.md | AppKit/Metal | CADisplayLink, zPosition, overlay, lifecycle, opacity, layer, preview, transparency, tint, legibility, liquid-glass | 4/0 | Metal surface lifecycle, overlay compositing, compensated NSView preview opacity parity, and window background tint for translucent legibility (CASE-027) |
| architecture/ipc-architecture.md | IPC/Daemon | socket, codec, binary-frame, security | 1/0 | Unix socket IPC design: framing, hot-path binary frames, security model |
| architecture/feature-provenance.md | Meta/History | cmux, Zed, WezTerm, Zellij, iTerm2, Devin, Windsurf, MCP, ACP, LSP, file-tree, file-editor, command-palette, tmux, zoxide, browser, notifications, SwiftUI, performance, P4, P5, P27, P30, P32, P33 | 0/0 | Where each major feature came from: origin story (cmux→Zed→harness fork); IDE track (file tree/editor/LSP, P4); ACP built-then-erased (P5); command palette power-user accretion (tmux/vim/zoxide); pane system (P13/P27/P30 otty parity); embedded browser + git panel quick-look; MCP same cycle as browser; notifications from cmux; status dashboard from Devin/Windsurf; SwiftUI migration performance crisis; P32/P33 status and non-goals |
| ui/split-panes.md | AppKit/UI | NSSplitView, ratio, recursion, reorder, two-axis, split-down, adjustRatio | 4/0 | Split pane management: ratio persistence, infinite-recursion guards, subview reorder, two-axis (Split Right/Split Down) parity (P13) |
| patterns/acp-client.md | ACP/Agent | JSON-RPC, stdio, shelved, adapter | 0/0 | ACP protocol integration — shelved due to adapter ecosystem immaturity |
| architecture/mcp-server.md | MCP/Agent | JSON-RPC, stdio, tools, policy, badge, browser, daemon | 0/0 | harness-mcp: 27-tool MCP server (agent→Harness direction); tool policy gating; tab badge; browser pane control; MCPConfigWriter for Claude Code/Kiro/Agy |
| ai/terminal-chat.md | AI/Chat | ⌘I, inline, overlay, AgentProcessManager, AIQueryInputView, AIResponseBlockView, ACP, MCP, cli, stdin, REMOVED | 0/0 | ❌ REMOVED (`c4e1e15`, 2026-06-29) — historical record of the erased ⌘I inline AI chat overlay; do not treat as current |
| ui/git-panel.md | AppKit/Git | DispatchSource, worktrees, real-time | 1/0 | Git panel with real-time refresh, history click→editor, worktree support |
| meta/project-history.md | Meta | sprints, releases, architecture | 0/0 | Sprint timeline and architecture decisions from v1.3→v3.0.0 |
| meta/competitive-position.md | Meta | Supacode, Warp, iTerm2, Ghostty, cmux, gaps, USPs | 0/0 | Competitive analysis: Harness wins/gaps vs market, unique selling points, positioning |
| architecture/session-tab-hierarchy.md | AppKit/UI | session, tab, pane, top-bar, keybinding, ⌘1-9, ⌘[, ⌘] | 1/0 | Workspace/Session/Tab/Pane hierarchy; top bar = 1 pill per Session, not per-Tab; ⌘1-9 and ⌘[/⌘] both target Session level, Tab-level shortcuts removed |
| ui/agent-session-board.md | AppKit/UI | BoardModel, Kanban, classify, BoardViewController, harness board, ScriptAPI, harnessBoard, MCP | 1/0 | Kanban-style Board view over live sessions/tabs/panes (cards), classified into columns by status, accessible via AppKit GUI sidebar, terminal CLI, scripting API, and read-only MCP tool |
| architecture/service-decomposition.md | Architecture | SessionCoordinator, facade, services, @MainActor, unowned, lazy | 2/0 | P17 god-object decomposition: SessionCoordinator 2050→397 LOC via 6 focused services (DaemonSync, SessionLifecycle, SplitPane, Notification, Theme, ActivePane) + HostDelegate extension + Types file |
| patterns/ui-automation.md | QA/Testing | Robot Framework, osascript, System Events, accessibility, CLI verification | 1/0 | P18 UI automation: Robot Framework + custom Python library using macOS System Events (AppleScript) for UI interaction + harness CLI for state verification. No Appium dependency. |
| ui/browser-pane.md | AppKit/WebKit | WKWebView, BrowserLeaf, applyLocalSnapshot, hit-testing, URLDetection, localhost | 2/0 | P14 embedded Browser Pane: architecture, applyLocalSnapshot re-injection bug (close button no-op), collapsed errorBanner hit-testing bug, ⌘B shortcut, click-to-open localhost/LAN dev-server links |
| architecture/browser-devtools-api.md | MCP/Browser | WKWebView, snapshot, screenshot, network, cookies, storage, elements, round-trip, timeout | 0/0 | P28 AI browser control: 3-phase (elements+screenshot, network capture, storage); round-trip fix (timeout 2s→35s); config-driven home page |
| ui/tab-bar.md | AppKit/UI | TabPillView, statusDot, branchLabel, gitBranch, drag, reorder, pill, shouldShowBranch, effectiveAgentKind, agentIcon | 1/0 | Tab bar pill layout; `Tab.effectiveAgentKind` centralized agent detection (daemon + OSC title inference); agent icon in sidebar cards; drag-reorder cancel-on-structural-reload |
| sidebar-swiftui-migration.md | AppKit/SwiftUI | NSTableView, Observable, NSHostingView, context-menu, RL-051, row-identity, diffing | 3/0 | Sidebar NSTableView→SwiftUI List migration: @Observable model, NSHostingView bridge, row identity via prefixed IDs, native .contextMenu, type collision fix (SwiftUI.Tab vs HarnessCore.Tab). Eliminates RL-051 row-index crashes. |
| architecture/background-polling.md | Performance | SurfaceShellTracker, DaemonSyncService, metadataRefresh, snapshotChanged, fanout, PerfCounters, metadataOnly, double-subscription | 1/0 | P22 background polling architecture: SurfaceShellTracker proc-tree walk, 5-s metadata refresh loop, snapshotChanged fanout consumers and gate logic, PerfCounters instrumentation, known non-P22 syncFromDaemon callers |
| bugs/zombie-crash-macos26.md | Swift/AppKit | zombie, macOS26, Swift6.3, executor, nonisolated, layout, retire, assumeIsolated, @objc, thunk, CASE-034-040 | 5/0 | macOS 26.5 + Swift 6.3.2 zombie view crashes: @objc thunk executor check dereferences freed self. Fixes: retire() 100ms, remove nonisolated, avoid Optional.map closures, detach NSHostingView |
| bugs/focus-persistence.md | AppKit/Focus | activeSurfaceID, ensureActivePane, reflectRemoteActivePane, selectTab, selectWorkspace, MainExecutor, RL-043 | 0/0 | Per-session-tab pane focus not restored on switch: stale GUI activeSurfaceID wins over daemon activePaneID. Partial fix: nil activeSurfaceID before syncFromDaemon in all select* paths. Not fully verified. |
| bugs/browser-tab-close-unresponsive.md | AppKit/UI | NSClickGestureRecognizer, BrowserTabButton, closeBtn, hit-test, P24 | 0/0 | Browser tab close button unresponsive — gesture recognizer intercepts click before NSButton action fires. Fix: check click location in gesture handler, return early if in close button rect. |
| bugs/nstextfield-leak-board.md | AppKit/Perf | NSTextField, leak, BoardViewController, agentStateChanged, snapshotChanged, removeFromSuperview, P20 | 1/0 | 21GB memory leak from unconditional board UI rebuild on every notification — NSTextField internal observers prevent deallocation. Fix: diff columns before rebuild. |
| cases/memory-leak-audit.md | Performance | memory, leak, vmmap, footprint, onRetire, SessionCoordinator, insert-only-dict, BrowserPaneView, network-cap | 2/0 | 34 GB long-session leak audit (2026-06-26): triage via vmmap (MALLOC_SMALL not GPU), dominant cause = existingHosts (0430ed8), secondary = insert-only AI controller dicts + uncapped browser network array. onRetire pattern + Robot guard added. |
| bugs/notch-cpu-animation.md | Performance/AppKit | AnimatableFrameAttribute, NSHostingView, CASpring, setFrame, snapshotChanged, NotchPanel, AgentScanner, proc_listpids, SnapshotCoalescer, gpu-animation | 1/0 | 100% CPU from SwiftUI spring animation never converging: snapshotChanged → setFrame → NSHostingView.layout() → AnimatableFrameAttribute at 60fps. Fix: data/geometry separation + CA mask GPU animation. |
| patterns/gpu-animation-ca.md | Performance/AppKit | CAShapeLayer, CABasicAnimation, path-morph, SnapshotCoalescer, NotchMaskAnimator, Zed, Otty, cmux, hasShadow, CombineLatest | 1/0 | GPU animation pattern for overlay panels: CAShapeLayer mask + CABasicAnimation path morph replaces SwiftUI AnimatableFrameAttribute. Layout once, GPU paints. System shadow from hasShadow=true + mask alpha. |
| patterns/build-self-kill-protection.md | Build/Scripts | TERM_PROGRAM, kill_stale_prod, run.sh, self-kill, Harness-hosted | 1/0 | Build scripts killing Harness while running inside Harness. Fix: detect TERM_PROGRAM=Harness, skip kill of /Applications instance and runtime state clear. |
| patterns/fsevents-pattern.md | Swift/FSEvents | FSEventStreamCreate, recursive, DispatchSource, WatcherContext, Unmanaged, CASE-016, CASE-021 | 1/0 | Reusable FSEvents recursive watcher pattern for Swift actors — replaces non-recursive DispatchSource for nested directory watching. |
| architecture/command-prompt.md | Commands/Parser | CommandParser, CommandPrompt, knownVerbs, aliases, sendKeys, zoxide, passthrough | 1/0 | Command prompt 2-layer architecture: CommandParser (text→Command) + MainExecutor (Command→effect). Every documented verb needs both layers or throws unknownCommand. |
| rl-lessons.md | AppKit/Swift6 | RL, zombie, NSSplitView, NSPanel, NSAlert, WKWebView, Task.detached, Observable, nonisolated, assumeIsolated | 0/0 | All RL-xxx lesson entries — grep target for bug pattern lookup |
| bugs/notification-sound-and-click-routing.md | AppKit/UN | UNUserNotificationCenter, NotificationPresenter, willPresent, didReceive, sound, userInfo, surfaceID, notch, CASE-063 | 0/0 | Compound report split into 2: (a) foreground `willPresent` ignored the sound toggle — now gates `.sound` on `content.sound != nil`; (b) banner click never navigated like the notch/inbox does — no `didReceive` and no identity on the request at all. Added `surfaceID` through `content.userInfo`, `NotificationCoordinator.openSurface(_:)`, and the `didReceive` delegate method. |
| architecture/decisions.md | Architecture | ACP, harness-mcp, keybindings, sidebar, worktree, browser, tab, config, IPC | 0/0 | Stable architecture decisions moved from MEMORY.md |
| project_no-gimmick-feature-policy.md | Meta/Product | gimmick, competitive-position, GUI, cloud sync, plugins, GPU shader | 0/0 | User rejected remaining competitive gaps (cross-platform GUI, team sharing/cloud sync, plugin ecosystem, GPU shader customization) as gimmicks — Kouen only builds features that see real usage |
| feedback_interview-gate-call-first.md | Process/Workflow | interview-gate.py, PreToolUse, Skill(interview) | 0/0 | Always call Skill(interview) as the very first tool call of any task that may need Edit/Write — avoids the interview-gate.py deny-then-retry cycle |

## Source Map

| Knowledge | Implementation Files |
|-----------|---------------------|
| ui/appkit-metal.md | `HarnessTerminalKit/HarnessTerminalSurfaceView.swift`, `HarnessApp/UI/PaneSplitButtonsView.swift`, `HarnessApp/UI/ContentAreaViewController.swift` |
| architecture/ipc-architecture.md | `HarnessCore/IPC/IPCCodec.swift`, `HarnessCore/IPC/DaemonClient.swift`, `HarnessDaemon/DaemonServer.swift` |
| ui/split-panes.md | `HarnessApp/UI/HarnessSplitView.swift`, `HarnessApp/UI/ContentAreaViewController.swift` (PaneContainerView), `HarnessApp/Services/SessionCoordinator.swift`, `HarnessCore/Session/SessionEditor.swift` |
| patterns/acp-client.md | `HarnessCore/ACP/ACPClient.swift`, `HarnessCore/ACP/ACPSession.swift`, `HarnessApp/UI/AgentChatPanelView.swift` |
| architecture/mcp-server.md | `Tools/harness-mcp/Sources/HarnessMCP/MCPServer.swift`, `Tools/harness-mcp/Sources/HarnessMCP/ToolRegistry.swift`, `Tools/harness-mcp/Sources/HarnessMCP/ToolPolicy.swift`, `HarnessCore/Agents/MCPConfigWriter.swift`, `HarnessCore/ACP/ACPMessage.swift` |
| ai/terminal-chat.md | `HarnessCore/AI/AIAgentConfig.swift`, `HarnessCore/AI/AgentProcessManager.swift`, `HarnessApp/UI/AIChat/AIQueryInputView.swift`, `HarnessApp/UI/AIChat/AIResponseBlockView.swift`, `HarnessApp/UI/AIChat/AITerminalChatController.swift`, `HarnessApp/Services/SessionCoordinator.swift` |
| ui/git-panel.md | `HarnessApp/UI/GitPanelView.swift` |
| architecture/session-tab-hierarchy.md | `HarnessApp/UI/ContentAreaViewController.swift`, `HarnessApp/UI/MainMenuBuilder.swift`, `HarnessApp/Services/SessionCoordinator.swift`, `HarnessCore/Session/SessionEditor.swift` |
| ui/agent-session-board.md | `HarnessCore/Board/BoardModel.swift`, `HarnessCLI/HarnessCLI+Board.swift`, `HarnessApp/UI/BoardViewController.swift`, `HarnessApp/Scripting/ScriptAPI.swift`, `HarnessMCP/HarnessDaemonTools.swift`, `HarnessMCP/ToolRegistry.swift` |
| ui/browser-pane.md | `HarnessApp/UI/Chrome/BrowserPaneView.swift`, `HarnessApp/Services/SplitPaneCoordinator.swift`, `HarnessApp/Services/DaemonSyncService.swift`, `HarnessApp/UI/Chrome/MainMenuBuilder.swift`, `HarnessApp/UI/Chrome/ContentAreaViewController.swift`, `HarnessApp/UI/Chrome/MainSplitViewController.swift`, `HarnessTerminalEngine/URLDetection.swift`, `HarnessTerminalKit/HarnessTerminalSurfaceView+SelectionAndLinks.swift` |
| ui/tab-bar.md | `HarnessApp/UI/Terminal/TerminalTabBarView.swift`, `HarnessCore/Metadata/MetadataProvider.swift`, `HarnessApp/Services/DaemonSyncService.swift`, `HarnessApp/UI/Chrome/ContentAreaViewController.swift` |
| architecture/background-polling.md | `HarnessApp/Services/SurfaceShellTracker.swift`, `HarnessApp/Services/DaemonSyncService.swift`, `HarnessApp/Services/PerfCounters.swift`, `HarnessApp/UI/Chrome/MainSplitViewController.swift`, `HarnessApp/UI/Sidebar/BoardViewController.swift`, `HarnessApp/UI/Notch/NotchPanelController.swift`, `HarnessApp/UI/Sidebar/HarnessSidebarPanelViewController.swift` |
| bugs/focus-persistence.md | `HarnessApp/Services/ActivePaneService.swift`, `HarnessApp/Services/SessionLifecycleService.swift`, `HarnessApp/Services/MainExecutor.swift`, `HarnessApp/Services/DaemonSyncService.swift`, `HarnessApp/UI/Chrome/ContentAreaViewController.swift` |
| bugs/browser-tab-close-unresponsive.md | `HarnessApp/UI/Chrome/BrowserPaneView.swift` |
| bugs/nstextfield-leak-board.md | `HarnessApp/UI/Sidebar/BoardViewController.swift`, `HarnessCore/Notifications/NotificationBus.swift`, `HarnessApp/Services/NotificationCoordinator.swift` |
| patterns/build-self-kill-protection.md | `Scripts/run.sh`, `Scripts/clear-runtime-state.sh` |
| patterns/fsevents-pattern.md | `HarnessApp/Services/FileExplorer/FileTreeWatcher.swift`, `HarnessApp/UI/Git/GitPanelView.swift` |
| architecture/command-prompt.md | `HarnessCore/Commands/CommandParser.swift`, `HarnessApp/Services/MainExecutor.swift`, `HarnessCore/Workbench/WorkbenchCommand.swift`, `HarnessApp/UI/CommandPalette/CommandPromptController.swift` |
| bugs/notch-cpu-animation.md | `HarnessApp/UI/Notch/NotchPanelController.swift`, `HarnessApp/UI/Notch/AgentNotchViewModel.swift`, `HarnessApp/UI/Notch/NotchMaskAnimator.swift`, `HarnessApp/UI/Notch/NotchShape.swift`, `HarnessApp/Services/SnapshotCoalescer.swift`, `HarnessDaemon/AgentScanner.swift` |
| patterns/gpu-animation-ca.md | `HarnessApp/UI/Notch/NotchMaskAnimator.swift`, `HarnessApp/UI/Notch/NotchPanelController.swift`, `HarnessApp/UI/Notch/NotchPanel.swift`, `HarnessApp/Services/SnapshotCoalescer.swift` |
| bugs/zombie-crash-macos26.md | `HarnessApp/Services/TerminalPaneRegistry.swift`, `HarnessApp/UI/Chrome/ContentAreaViewController.swift`, `HarnessApp/UI/FileTree/WorkspaceFileTreeView.swift`, `HarnessApp/Services/ActivePaneService.swift`, `HarnessTerminalKit/HarnessTerminalSurfaceView+Scrollback.swift`, `HarnessTerminalKit/TerminalScrollbarView.swift`, `HarnessTerminalKit/ResizeHUDView.swift` |
| bugs/notification-sound-and-click-routing.md | `HarnessApp/Services/SessionCoordinatorTypes.swift`, `HarnessApp/Services/NotificationCoordinator.swift`, `HarnessApp/Services/SessionCoordinator+HostDelegate.swift` |

## Edges

| From | To | Shared Keywords |
|------|----|-----------------|
| ui/appkit-metal.md | ui/split-panes.md | NSView lifecycle, removeFromSuperview, rebuild |
| architecture/ipc-architecture.md | patterns/acp-client.md | framing, protocol, stdio |
| architecture/mcp-server.md | patterns/acp-client.md | ACPMessage, JSON-RPC, stdio, framing — shared model, opposite directions |
| ai/terminal-chat.md | architecture/mcp-server.md | both agent integration paths; MCP = agent→Harness, Terminal Chat = user→agent |
| ai/terminal-chat.md | patterns/acp-client.md | ACP was the original Harness→agent path; terminal chat replaced it with CLI print-mode |
| ai/terminal-chat.md | ui/appkit-metal.md | overlay NSView pattern above Metal surface — same as CompletionPopupView |
| architecture/mcp-server.md | ui/agent-session-board.md | harnessBoard tool exposes BoardModel read-only via MCP |
| architecture/mcp-server.md | ui/browser-pane.md | harnessBrowser* tools control BrowserPaneView via MCP |
| architecture/browser-devtools-api.md | architecture/mcp-server.md | P28 extends MCP browser tools; HarnessBrowserTools.swift is the MCP layer |
| architecture/browser-devtools-api.md | ui/browser-pane.md | BrowserPaneView implements all snapshot/screenshot/network/storage methods |
| architecture/browser-devtools-api.md | architecture/ipc-architecture.md | round-trip: daemon forwardBrowserRequest → GUI subscription → browserResponse |
| ui/tab-bar.md | architecture/mcp-server.md | lastMCPControlAt drives MCP badge on TabPillView |
| ui/git-panel.md | ui/split-panes.md | DispatchSource, real-time refresh |
| architecture/session-tab-hierarchy.md | ui/appkit-metal.md | ContentAreaViewController, top bar |
| ui/agent-session-board.md | architecture/session-tab-hierarchy.md | SessionSnapshot, Tab, PaneLeaf, status classification |
| ui/browser-pane.md | ui/split-panes.md | PaneNode, PaneContainerView, SplitPaneCoordinator |
| bugs/notification-sound-and-click-routing.md | bugs/zombie-crash-macos26.md | NotificationCenterProbe.isKnownBad forks AppleScript vs UNUserNotificationCenter delivery path |
| bugs/notification-sound-and-click-routing.md | bugs/nstextfield-leak-board.md | both touch NotificationCoordinator.swift |
| ui/browser-pane.md | architecture/ipc-architecture.md | DaemonSyncService, snapshot, applySnapshot |
| ui/tab-bar.md | architecture/session-tab-hierarchy.md | reloadTabBar, TabPillView, SessionGroup, pill-per-session |
| ui/tab-bar.md | ui/agent-session-board.md | statusDot, BoardColumnKind, tab status classification |
| bugs/zombie-crash-macos26.md | ui/appkit-metal.md | NSView lifecycle, zombie, removeFromSuperview |
| bugs/zombie-crash-macos26.md | architecture/background-polling.md | snapshotChanged fanout, timing, view rebuild |
| bugs/zombie-crash-macos26.md | ui/tab-bar.md | TerminalTabBarView.layout(), zombie crash |
| bugs/browser-tab-close-unresponsive.md | ui/browser-pane.md | BrowserPaneView, BrowserTabButton, close button |
| bugs/nstextfield-leak-board.md | ui/agent-session-board.md | BoardViewController, reload, agentStateChanged |
| bugs/nstextfield-leak-board.md | architecture/background-polling.md | snapshotChanged, notification frequency |
| bugs/notch-cpu-animation.md | architecture/background-polling.md | snapshotChanged fanout, AgentScanner, proc_listpids — same notification path |
| bugs/notch-cpu-animation.md | patterns/gpu-animation-ca.md | fix uses CA mask pattern |
| bugs/notch-cpu-animation.md | bugs/nstextfield-leak-board.md | both: snapshot-driven rebuild causing CPU/memory blowup |
| patterns/gpu-animation-ca.md | ui/appkit-metal.md | CALayer, NSHostingView, render server — shared layer model |
| patterns/fsevents-pattern.md | ui/git-panel.md | FSEvents, recursive watch, real-time |

## Search Instructions

When loading context for a task, search this index by:
1. **Domain** column for the subsystem being modified
2. **Tags** for specific technologies/patterns
3. **Edges** for related cross-domain knowledge
