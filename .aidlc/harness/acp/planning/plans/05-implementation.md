# Implementation Plan: Agent Client Protocol (ACP) — Harness ACP Client

## Status: Planning

## Objective
Implement the ACP Client layer in Harness so that ACP-compatible agents (Claude Code, Codex, Gemini CLI) can be launched as managed subprocesses, bootstrapped with workspace context, and have their streamed responses rendered natively in a dedicated panel.

## Decision Reference
**Based on decisions from**: [../decisions/00-inception-decisions.md](../decisions/00-inception-decisions.md)

## User Story Mapping (MANDATORY)
**Source**: Reference `outputs/inception/user-stories.md`

### MVP User Stories (Must Implement)
- [ ] **PBI-ACP-001**: ACP Agent Subprocess Lifecycle Management — launch, handshake, crash detection, graceful shutdown.
- [ ] **PBI-ACP-002**: ACP Session Bootstrap with Workspace Context — `session/new` with CWD, open files, terminal output, git branch.
- [ ] **PBI-ACP-003**: Prompt Sending & Streaming Response Rendering — `prompt/send`, token streaming, native response panel.

### Future User Stories (Post-MVP)
- [ ] **PBI-ACP-001-Ext**: Streamable HTTP transport for remote agents.
- [ ] **PBI-ACP-002-Ext**: Multi-agent support (multiple subprocesses per workspace).
- [ ] **PBI-ACP-003-Ext**: Diff-apply code blocks directly to files (patch mode).

---

## Feature Implementation Plan

### Phase 1: ACP Core Transport & Process — Status: Not Started
**User Stories**: PBI-ACP-001
**Target**: Low-level ACP machinery — subprocess, stdio pipes, JSON-RPC framing.

- [ ] Task 1.1: Create `Packages/HarnessCore/Sources/HarnessCore/ACP/ACPMessage.swift`
  - Define `ACPMessage` enum (request, response, notification), `JSONRPCId`, `JSONRPCError`, `AnyCodable` wrapper.
  - *Source*: Read `outputs/inception/domain-design.md` ACPMessage section.

- [ ] Task 1.2: Create `Packages/HarnessCore/Sources/HarnessCore/ACP/ACPTransport.swift`
  - Implement Content-Length header framing (LSP-style) for JSON-RPC over stdio.
  - Encode `ACPMessage` → bytes (write to stdin pipe). Decode bytes → `ACPMessage` (read from stdout pipe via `AsyncBytes`).
  - *Source*: Read `outputs/inception/brainstorming-summary.md` Dev section on framing. Confirm from https://agentclientprotocol.com/protocol/transports

- [ ] Task 1.3: Create `Packages/HarnessCore/Sources/HarnessCore/ACP/ACPProcess.swift`
  - `actor ACPProcess`: wraps `Foundation.Process` + `Pipe`.
  - `launch(config:)` — spawn subprocess, set up stdin/stdout pipes.
  - `send(_:)` — write encoded message to stdin.
  - `incomingMessages: AsyncStream<ACPMessage>` — reads stdout via `AsyncBytes`.
  - `terminationHandler` — emit crash event if unexpected exit.
  - *Source*: Read `outputs/inception/logical-design.md` Section 5.1.

- [ ] Task 1.4: Create `Packages/HarnessCore/Sources/HarnessCore/ACP/AgentConfig.swift`
  - `struct AgentConfig: Identifiable, Codable` — name, binaryPath, args, isEnabled.
  - Simple `AgentRegistryStore` backed by `UserDefaults` or a JSON file in app support.
  - *Source*: Read `outputs/inception/domain-design.md` AgentConfig section.

**Tests**: Write `ACPTransportTests.swift` — pure encode/decode round-trip, no subprocess.

**Acceptance**: JSON-RPC messages encode/decode correctly. `ACPProcess` can launch a simple echo binary and receive messages back.

---

### Phase 2: ACP Session & Context Bootstrap — Status: Not Started
**User Stories**: PBI-ACP-001 (handshake), PBI-ACP-002 (session/new)
**Target**: Capability handshake + workspace context assembly + session state machine.

- [ ] Task 2.1: Create `Packages/HarnessCore/Sources/HarnessCore/ACP/ACPSession.swift`
  - `actor ACPSession`: state machine (connecting → active → crashed → terminated).
  - Sends `initialize` request → awaits `initialized` response (3s timeout).
  - On timeout → terminates process, transitions to `.crashed`.
  - *Source*: Read `outputs/inception/domain-design.md` Business Rules section.

- [ ] Task 2.2: Create `Packages/HarnessCore/Sources/HarnessCore/ACP/WorkspaceContextBuilder.swift`
  - Reads from `SurfaceShellTracker.shared`: active pane CWD, git branch, last 200 lines terminal output.
  - Reads open file paths from `SessionCoordinator` active workspace.
  - Enforces limits: 500 paths max, 200 terminal lines, total < 64KB (truncate terminalOutput first).
  - *Source*: Read `SurfaceShellTracker.swift` and `SessionCoordinator.swift` for available APIs.

- [ ] Task 2.3: Create `Packages/HarnessCore/Sources/HarnessCore/ACP/ACPClient.swift`
  - `actor ACPClient`: high-level API over `ACPSession` + `ACPProcess`.
  - `initialize(context:)` — handshake then `session/new`.
  - `sendPrompt(_:)` → returns `AsyncStream<String>` (token stream).
  - `shutdown()` — graceful.
  - *Source*: Read `outputs/inception/logical-design.md` Section 5.2.

**Tests**: Write `ACPSessionTests.swift` — mock `ACPProcess` protocol, test state transitions. Write `WorkspaceContextBuilderTests.swift` — test payload limit enforcement.

**Acceptance**: `session/new` payload is correctly assembled and sent. State machine transitions correctly on handshake success/timeout.

---

### Phase 3: ACPAgentManager + Response Panel UI — Status: Not Started
**User Stories**: PBI-ACP-001 (lifecycle UI), PBI-ACP-003 (response rendering)
**Target**: App-layer agent manager + native streaming response panel.

- [ ] Task 3.1: Create `Apps/Harness/Sources/HarnessApp/Services/ACPAgentManager.swift`
  - Owns the single active `ACPClient` per workspace.
  - Exposes `activateAgent(_ config: AgentConfig)` and `deactivateAgent()`.
  - Publishes `@Published var agentState: ACPSessionState` for UI binding.
  - Handles crash → sets state to `.crashed` → triggers UI reconnect prompt.
  - *Source*: Read `outputs/inception/logical-design.md` Section 6.

- [ ] Task 3.2: Create `Apps/Harness/Sources/HarnessApp/UI/ACPResponsePanelViewController.swift`
  - `NSTextView` in scrollable container. Appends tokens `@MainActor`.
  - Code block detection → monospace font + background fill + "Copy" button.
  - "Apply to split" button → calls `SessionCoordinator.shared` to open a pane split with the file.
  - Agent state indicator (spinner/active/crashed badge) in panel header.
  - *Source*: Read `outputs/inception/logical-design.md` Section 6.1. Read `HarnessSidebarPanelViewController.swift` for theme color conventions.

- [ ] Task 3.3: Wire `ACPAgentManager` into sidebar — add agent activate/deactivate controls in `HarnessSidebarPanelViewController`.
  - *Source*: Read `HarnessSidebarPanelViewController.swift`.

**Acceptance**: Developer can activate Claude Code from sidebar, send a prompt, and see streamed response with syntax-highlighted code blocks in the panel.

---

## Technical Setup

### Pre-Implementation Checks (MANDATORY before coding)
- [ ] Confirm ACP framing transport: Content-Length header or NDJSON? Check: https://agentclientprotocol.com/protocol/transports
- [ ] Confirm `session/new` payload schema: what fields does the spec require? Check: https://agentclientprotocol.com/protocol/schema
- [ ] Check `SurfaceShellTracker.swift` API surface for terminal output + git branch access.
- [ ] Check `SessionCoordinator.swift` for open files list API.
- [ ] Create feature branch: `git checkout -b feature/acp-client`

---

## Success Criteria (Implementation Validation)
- [ ] `ACPTransportTests` pass: encode/decode round-trip for all message types.
- [ ] `ACPSessionTests` pass: handshake success, handshake timeout, crash recovery.
- [ ] `WorkspaceContextBuilderTests` pass: payload limits enforced correctly.
- [ ] End-to-end: Claude Code activates in Harness, receives `session/new`, responds to a prompt with streamed tokens visible in the panel.
- [ ] All file system + subprocess I/O executes off Main Actor (verified by Swift 6 strict concurrency checks).
