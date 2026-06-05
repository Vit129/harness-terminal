# Logical Design: Agent Client Protocol (ACP) — Harness ACP Client

## 1. User Story Mapping

| User Story ID | Description | Backend/Core Components | Frontend/UI Components | MVP |
|---|---|---|---|---|
| PBI-ACP-001 | Agent subprocess lifecycle | `ACPProcess`, `ACPTransport`, `AgentConfig` | `ACPAgentManager` | ✅ |
| PBI-ACP-002 | Session bootstrap with workspace context | `WorkspaceContextBuilder`, `ACPSession` | `ACPAgentManager` | ✅ |
| PBI-ACP-003 | Prompt send + streaming response render | `ACPClient`, `StreamingResponseBuffer` | `ACPResponsePanelViewController` | ✅ |

---

## 2. Non-Functional Requirements

| Category | Requirement | Technical Impact |
|---|---|---|
| Performance | Handshake < 3s | Timeout guard on `initialize` request in `ACPProcess` |
| Performance | First token < 500ms | Main actor dispatch in `StreamingResponseBuffer.appendToken()` |
| Reliability | Crash detection < 1s | `Process.terminationHandler` → emit `ACPAgentCrashed` immediately |
| Security | No escalation | `Process` inherits Harness user permissions only |

---

## 3. Project Structure

### 3.1 Directory Layout
```
harness/
├── Apps/Harness/Sources/HarnessApp/
│   ├── Services/
│   │   └── ACPAgentManager.swift         (New — launch/manage agents, owns ACPSession lifecycle)
│   └── UI/
│       └── ACPResponsePanelViewController.swift  (New — streaming response panel)
├── Packages/HarnessCore/Sources/HarnessCore/
│   └── ACP/
│       ├── ACPClient.swift               (New — high-level API: send prompt, manage session)
│       ├── ACPProcess.swift              (New — subprocess + stdio pipe management)
│       ├── ACPTransport.swift            (New — JSON-RPC 2.0 framing: encode/decode messages)
│       ├── ACPMessage.swift              (New — JSONRPCMessage enum + value types)
│       ├── ACPSession.swift              (New — session state machine)
│       ├── AgentConfig.swift             (New — Codable agent config + registry store)
│       └── WorkspaceContextBuilder.swift (New — assembles WorkspaceContext from SurfaceShellTracker)
└── Tests/
    └── HarnessCoreTests/
        ├── ACPTransportTests.swift        (JSON-RPC encode/decode tests)
        ├── ACPSessionTests.swift          (Session state machine tests)
        └── WorkspaceContextBuilderTests.swift
```

---

## 4. Technical Architecture

### 4.1 Architecture Pattern
- **Choice**: Actor-based async pipeline (Swift 6).
- **Reasoning**: ACP I/O is strictly async — subprocess stdin/stdout are async streams. Swift Actors isolate mutable state (session, buffer) from concurrent access.

### 4.2 Technology Stack
| Category | Choice | Source |
|---|---|---|
| Process management | `Foundation.Process` (NSTask) | macOS stdlib |
| I/O | `Pipe` + `AsyncBytes` | Swift Concurrency |
| JSON-RPC | Custom `ACPTransport` over Codable | No external dep |
| Concurrency | Swift 6 `actor` + `@MainActor` | Codebase guideline |

---

## 5. Core Component Design

### 5.1 ACPProcess (Actor)
```swift
actor ACPProcess {
    func launch(config: AgentConfig) async throws  // spawn + pipe setup
    func send(_ message: ACPMessage) async throws  // write to stdin
    var incomingMessages: AsyncStream<ACPMessage>  // read from stdout
    func terminate() async                          // graceful shutdown
}
```

### 5.2 ACPClient (Actor)
```swift
actor ACPClient {
    func initialize(context: WorkspaceContext) async throws  // handshake + session/new
    func sendPrompt(_ text: String) async throws -> AsyncStream<String>  // returns token stream
    func shutdown() async
}
```

### 5.3 WorkspaceContextBuilder
```swift
struct WorkspaceContextBuilder {
    // Reads from SurfaceShellTracker.shared
    func build(for paneID: PaneID) async -> WorkspaceContext
}
```

---

## 6. Frontend / UI Design

### 6.1 ACPResponsePanelViewController
- `NSTextView` in scrollable container.
- Appends tokens progressively via `@MainActor` callback.
- Code blocks rendered with monospace font + background fill matching Harness theme.
- "Copy" button per code block. "Apply to split" button triggers `SessionCoordinator` pane split.

---

## 7. Validation Checklist
- [x] Actor isolation defined for all async components.
- [x] JSON-RPC message types modeled.
- [x] Context payload limits specified (64KB, 500 files, 200 lines).
- [x] Crash detection path defined.
- [x] Test targets identified.
