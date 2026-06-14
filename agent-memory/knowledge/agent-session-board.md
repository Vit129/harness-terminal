# Agent/Session Board (P16)

## Data Model (PBI-BOARD-001)

The P16 Agent/Session Board provides a Kanban-style board view over live sessions, tabs, and panes. The core model is defined in `HarnessCore`:

- `BoardCard` — A read-only projection over a tab (`Tab` within the `SessionSnapshot`). It represents a card on the board containing `workspaceID`, `sessionID`, `tabID`, `paneID`, `title`, `cwd`, `gitBranch`, `currentCommand`, process `exitStatus`, and agent info (`agentKind`, `agentActivity`).
- `BoardColumnKind` — Enumeration of the five canonical columns in display order: `needsAttention` (Needs Attention), `running` (Running), `idle` (Idle), `done` (Done), and `error` (Error).
- `BoardColumn` — A column holding a list of `BoardCard` items.

### Centralized Classification
`BoardModel.classify(snapshot:)` in `Packages/HarnessCore/Sources/HarnessCore/Board/BoardModel.swift` acts as the single source of truth. It maps a `SessionSnapshot` into columns using status-dot logic ported from `Apps/Harness/Sources/HarnessApp/UI/SidebarSessionRows.swift` to ensure classification consistency:

1. **Needs Attention** — `tab.agent?.activity == .awaiting` (precedence over exit-status-based states, indicating an agent is waiting for user input).
2. **Error** — `tab.exitStatus != 0` (red dot).
3. **Done** — `tab.exitStatus == 0` (green dot).
4. **Running** — `tab.currentCommand` is non-empty and not a known interactive shell (e.g. `zsh`, `bash`, `sh`, `fish`, `login` — blue dot).
5. **Idle** — everything else (gray dot).

## Consumers

The board model is consumed by four interfaces:

### 1. Board Sidebar Tab (GUI)
- **File:** `Apps/Harness/Sources/HarnessApp/UI/BoardViewController.swift`
- **Implementation:** Adds a "Board" tab (index 3) to the sidebar. It renders a horizontally scrolling `NSStackView` of columns, each containing a vertical stack of `BoardCardView` cards.
- **Interactions:** Clicking a card focuses the target pane by invoking existing coordinator focus/navigation helpers.
- **Refresh:** Redraws when `NotificationBus.shared.snapshotChanged` fires on a full session reload.

### 2. Harness CLI Command
- **File:** `Tools/harness/Sources/HarnessCLI/HarnessCLI+Board.swift`
- **Commands:**
  - `harness board`: Performs a one-shot fetch of the snapshot, runs `BoardModel.classify(...)`, and renders the columns as a text table.
  - `harness board --watch`: Subscribes to snapshot changes via the client (`client.subscribeSnapshot`) and re-renders in place (similar to `tmux`/`htop`).

### 3. Scripting API
- **File:** `Apps/Harness/Sources/HarnessApp/Scripting/ScriptAPI.swift`
- **Implementation:** `harness.board.list()` exports the classified board state as a serialized JSON dictionary matching the MCP tool schema.

### 4. Read-Only MCP Tool
- **Files:** `Tools/harness-mcp/Sources/HarnessMCP/HarnessDaemonTools.swift` and `Tools/harness-mcp/Sources/HarnessMCP/ToolRegistry.swift`
- **Implementation:** Registers the `harnessBoard` tool to retrieve the classified columns as JSON. Classified as read-only, it is allowed by default under standard security policies.

## Deferred PBIs

- **Live Event-Bridge Updates (PBI-BOARD-004):** Deferred pending the completion of the `harness.events` / `NotificationBus` bridge. Currently, GUI and CLI watch paths listen to full snapshot changes to achieve real-time refreshes.
- **Card Ack/Dismiss (PBI-BOARD-006):** In-memory acknowledgement/dismissal of Needs Attention cards is deferred, as it requires the live event bridge and per-pane notification signals to function properly.
