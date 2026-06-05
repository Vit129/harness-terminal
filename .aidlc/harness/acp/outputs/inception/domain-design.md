# Domain Design: Agent Client Protocol (ACP) — Harness ACP Client

## Entities

### ACPSession
```swift
struct ACPSession: Identifiable {
    let id: String              // UUID
    let agentConfig: AgentConfig
    var state: ACPSessionState  // .connecting | .active | .crashed | .terminated
    let workspaceRoot: URL
    var contextSnapshot: WorkspaceContext
}

enum ACPSessionState { case connecting, active, crashed, terminated }
```

### AgentConfig
```swift
struct AgentConfig: Identifiable, Codable {
    let id: UUID
    let name: String            // e.g. "Claude Code"
    let binaryPath: String      // e.g. "/usr/local/bin/claude"
    let args: [String]          // e.g. ["--acp"]
    var isEnabled: Bool
}
```

### ACPMessage (Value Object)
```swift
// JSON-RPC 2.0 envelope
enum ACPMessage {
    case request(id: JSONRPCId, method: String, params: AnyCodable?)
    case response(id: JSONRPCId, result: AnyCodable?, error: JSONRPCError?)
    case notification(method: String, params: AnyCodable?)
}
```

### WorkspaceContext (Value Object)
```swift
struct WorkspaceContext {
    let workspaceRoot: String
    let openFilePaths: [String]       // max 500
    let terminalOutputSnapshot: String // last 200 lines
    let gitBranch: String
    let gitStatusSummary: String
}
```

---

## Domain Events

| Event | Trigger | Consumers |
|-------|---------|---------|
| `ACPAgentLaunched` | Process started + handshake OK | ResponseRenderer (show active state) |
| `ACPAgentCrashed` | Process exited unexpectedly | UI (show reconnect) |
| `ACPTokenReceived` | Streaming notification from agent | ResponseRenderer |
| `ACPSessionEnded` | Clean shutdown | UI (clear panel) |
| `ACPContextRefreshed` | CWD/git changed in active pane | SessionContext rebuilds snapshot |

---

## Business Rules (Pseudo-code)

### Agent Launch
```
1. Validate agentConfig.binaryPath exists + is executable
2. Spawn process with stdio pipes
3. Send JSON-RPC `initialize` request with editor capabilities
4. Await `initialized` response (timeout: 3s)
5. If timeout → terminate process, emit ACPAgentCrashed
6. Else → emit ACPAgentLaunched
```

### Session Bootstrap
```
1. Build WorkspaceContext from SurfaceShellTracker + file list
2. Enforce limits: openFilePaths.count <= 500, terminalOutput <= 200 lines
3. Encode total payload: if > 64KB → truncate terminalOutput first, then openFilePaths
4. Send `session/new` with context
```

### Streaming Response
```
1. On `prompt/send` → assign request ID
2. Listen for streaming notifications matching request ID
3. Append tokens to StreamingResponseBuffer
4. Trigger ResponseRenderer.appendToken() on main actor
5. On final notification → mark response complete
```
