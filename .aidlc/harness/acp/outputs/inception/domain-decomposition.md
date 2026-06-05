# Domain Decomposition: Agent Client Protocol (ACP) — Harness ACP Client

## Bounded Contexts

### 1. ACPRuntime
**Responsibility:** Low-level ACP protocol machinery — subprocess management, stdio pipe I/O, JSON-RPC 2.0 message framing, encode/decode, handshake.
**Owns:** `ACPProcess`, `ACPTransport`, `JSONRPCMessage`, `ACPHandshake`
**Does NOT own:** Business session logic, UI rendering, context assembly.

### 2. AgentRegistry
**Responsibility:** Configuration and discovery of available ACP agents. Persist agent configs (name, binary path, args). Validate binary existence.
**Owns:** `AgentConfig`, `AgentRegistryStore`
**Does NOT own:** Process lifecycle (delegates to ACPRuntime).

### 3. SessionContext
**Responsibility:** Assembles the workspace context payload for `session/new`. Reads from `SurfaceShellTracker` (CWD, git branch), file system (open file paths), terminal buffer (last N lines).
**Owns:** `WorkspaceContextBuilder`, `TerminalOutputSnapshot`, `GitContextSnapshot`
**Does NOT own:** Sending the payload (delegates to ACPRuntime).

### 4. ResponseRenderer
**Responsibility:** Receives streamed token notifications from ACPRuntime and renders them progressively in the native AppKit panel. Handles markdown, code blocks, copy/apply actions.
**Owns:** `ACPResponsePanelViewController`, `StreamingResponseBuffer`, `CodeBlockView`
**Does NOT own:** JSON-RPC parsing, prompt routing.

---

## Data Ownership

| Data | Owner | Consumer |
|------|-------|---------|
| Agent binary config | AgentRegistry | ACPRuntime |
| JSON-RPC messages | ACPRuntime | SessionContext, ResponseRenderer |
| Workspace context | SessionContext | ACPRuntime (sends via session/new) |
| Streamed tokens | ACPRuntime | ResponseRenderer |
| Terminal output | SurfaceShellTracker (existing) | SessionContext |
| Git branch/status | SurfaceShellTracker (existing) | SessionContext |

---

## Context Map

```
[AgentRegistry] ──config──► [ACPRuntime] ◄──context──[SessionContext]
                                 │                         ▲
                                 │                    [SurfaceShellTracker]
                                 │
                              tokens
                                 │
                                 ▼
                          [ResponseRenderer]
                                 │
                            [Harness UI]
```
