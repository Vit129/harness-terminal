# Knowledge Index — Harness Terminal

## Files

| File | Domain | Tags | Score A/P | Summary |
|------|--------|------|-----------|---------|
| appkit-metal.md | AppKit/Metal | CADisplayLink, zPosition, overlay, lifecycle, opacity, layer, preview | 4/0 | Metal surface lifecycle, overlay compositing, and compensated NSView preview opacity parity pattern |
| ipc-architecture.md | IPC/Daemon | socket, codec, binary-frame, security | 1/0 | Unix socket IPC design: framing, hot-path binary frames, security model |
| split-panes.md | AppKit/UI | NSSplitView, ratio, recursion, reorder | 3/0 | Split pane management: ratio persistence, infinite-recursion guards, subview reorder |
| acp-client.md | ACP/Agent | JSON-RPC, stdio, shelved, adapter | 0/0 | ACP protocol integration — shelved due to adapter ecosystem immaturity |
| git-panel.md | AppKit/Git | DispatchSource, worktrees, real-time | 1/0 | Git panel with real-time refresh, history click→editor, worktree support |
| project-history.md | Meta | sprints, releases, architecture | 0/0 | Sprint timeline and architecture decisions from v1.3→v2.1 |

## Source Map

| Knowledge | Implementation Files |
|-----------|---------------------|
| appkit-metal.md | `HarnessTerminalKit/HarnessTerminalSurfaceView.swift`, `HarnessApp/UI/PaneSplitButtonsView.swift`, `HarnessApp/UI/ContentAreaViewController.swift` |
| ipc-architecture.md | `HarnessCore/IPC/IPCCodec.swift`, `HarnessCore/IPC/DaemonClient.swift`, `HarnessDaemon/DaemonServer.swift` |
| split-panes.md | `HarnessApp/UI/HarnessSplitView.swift`, `HarnessApp/UI/PaneContainerView.swift` |
| acp-client.md | `HarnessCore/ACP/ACPClient.swift`, `HarnessCore/ACP/ACPSession.swift`, `HarnessApp/UI/AgentChatPanelView.swift` |
| git-panel.md | `HarnessApp/UI/GitPanelView.swift` |

## Edges

| From | To | Shared Keywords |
|------|----|-----------------|
| appkit-metal.md | split-panes.md | NSView lifecycle, removeFromSuperview, rebuild |
| ipc-architecture.md | acp-client.md | framing, protocol, stdio |
| git-panel.md | split-panes.md | DispatchSource, real-time refresh |

## Search Instructions

When loading context for a task, search this index by:
1. **Domain** column for the subsystem being modified
2. **Tags** for specific technologies/patterns
3. **Edges** for related cross-domain knowledge
