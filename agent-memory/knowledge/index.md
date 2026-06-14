# Knowledge Index — Harness Terminal

## Files

| File | Domain | Tags | Score A/P | Summary |
|------|--------|------|-----------|---------|
| appkit-metal.md | AppKit/Metal | CADisplayLink, zPosition, overlay, lifecycle, opacity, layer, preview, transparency, tint, legibility, liquid-glass | 4/0 | Metal surface lifecycle, overlay compositing, compensated NSView preview opacity parity, and window background tint for translucent legibility (CASE-027) |
| ipc-architecture.md | IPC/Daemon | socket, codec, binary-frame, security | 1/0 | Unix socket IPC design: framing, hot-path binary frames, security model |
| split-panes.md | AppKit/UI | NSSplitView, ratio, recursion, reorder, two-axis, split-down, adjustRatio | 4/0 | Split pane management: ratio persistence, infinite-recursion guards, subview reorder, two-axis (Split Right/Split Down) parity (P13) |
| acp-client.md | ACP/Agent | JSON-RPC, stdio, shelved, adapter | 0/0 | ACP protocol integration — shelved due to adapter ecosystem immaturity |
| git-panel.md | AppKit/Git | DispatchSource, worktrees, real-time | 1/0 | Git panel with real-time refresh, history click→editor, worktree support |
| project-history.md | Meta | sprints, releases, architecture | 0/0 | Sprint timeline and architecture decisions from v1.3→v2.1 |
| session-tab-hierarchy.md | AppKit/UI | session, tab, pane, top-bar, keybinding, ⌘1-9, ⌘[, ⌘] | 1/0 | Workspace/Session/Tab/Pane hierarchy; top bar = 1 pill per Session, not per-Tab; ⌘1-9 and ⌘[/⌘] both target Session level, Tab-level shortcuts removed |

## Source Map

| Knowledge | Implementation Files |
|-----------|---------------------|
| appkit-metal.md | `HarnessTerminalKit/HarnessTerminalSurfaceView.swift`, `HarnessApp/UI/PaneSplitButtonsView.swift`, `HarnessApp/UI/ContentAreaViewController.swift` |
| ipc-architecture.md | `HarnessCore/IPC/IPCCodec.swift`, `HarnessCore/IPC/DaemonClient.swift`, `HarnessDaemon/DaemonServer.swift` |
| split-panes.md | `HarnessApp/UI/HarnessSplitView.swift`, `HarnessApp/UI/ContentAreaViewController.swift` (PaneContainerView), `HarnessApp/Services/SessionCoordinator.swift`, `HarnessCore/Session/SessionEditor.swift` |
| acp-client.md | `HarnessCore/ACP/ACPClient.swift`, `HarnessCore/ACP/ACPSession.swift`, `HarnessApp/UI/AgentChatPanelView.swift` |
| git-panel.md | `HarnessApp/UI/GitPanelView.swift` |
| session-tab-hierarchy.md | `HarnessApp/UI/ContentAreaViewController.swift`, `HarnessApp/UI/MainMenuBuilder.swift`, `HarnessApp/Services/SessionCoordinator.swift`, `HarnessCore/Session/SessionEditor.swift` |

## Edges

| From | To | Shared Keywords |
|------|----|-----------------|
| appkit-metal.md | split-panes.md | NSView lifecycle, removeFromSuperview, rebuild |
| ipc-architecture.md | acp-client.md | framing, protocol, stdio |
| git-panel.md | split-panes.md | DispatchSource, real-time refresh |
| session-tab-hierarchy.md | appkit-metal.md | ContentAreaViewController, top bar |

## Search Instructions

When loading context for a task, search this index by:
1. **Domain** column for the subsystem being modified
2. **Tags** for specific technologies/patterns
3. **Edges** for related cross-domain knowledge
