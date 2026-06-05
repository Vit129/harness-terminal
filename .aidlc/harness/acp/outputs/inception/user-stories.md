# Product Backlog Items: Agent Client Protocol (ACP) — Harness ACP Client

## PBIs (Product Backlog Items)

### PBI-ACP-001: ACP Agent Subprocess Lifecycle Management
**Product Metrics:** Number of AI agents successfully connected and actively running per session.

**Goal:** Allow Harness to launch, communicate with, and terminate ACP-compatible AI coding agents (Claude Code, Codex, Gemini CLI) as managed subprocesses.

**Persona:** Developer who wants to use Claude Code or Codex inside Harness without switching to Zed or a separate terminal.

**Requirement:**
- Harness must support launching any ACP-compatible agent binary as a child process via stdio.
- Harness must perform an ACP capability handshake (`initialize` / `initialized`) on agent startup.
- Harness must manage agent process lifecycle: start, restart on crash, graceful shutdown.
- A list of configured agents must be stored in Harness settings (agent name, binary path, args).

**User Flow:**
1. Developer opens Harness settings and adds Claude Code as an ACP agent (path: `claude`, args: `--acp`).
2. Developer activates the agent from the sidebar.
3. Harness spawns the `claude --acp` subprocess and performs capability handshake.
4. Agent is now active and ready to receive prompts.

**Acceptance Criteria:**
* **Given** an agent is configured, **when** the developer activates it, **then** Harness spawns the subprocess and completes the ACP handshake within 3 seconds.
* **Given** an active agent crashes, **when** the process exits unexpectedly, **then** Harness detects the crash, logs it, and shows a reconnect option in the UI.
* **Given** the developer deactivates an agent, **when** shutdown is requested, **then** Harness sends an ACP shutdown notification and waits for the process to exit cleanly.

---

### PBI-ACP-002: ACP Session Bootstrap with Workspace Context
**Product Metrics:** Agent accuracy on first prompt (fewer "what's the project?" clarifications).

**Goal:** When a new ACP session starts, automatically pass the active workspace context to the agent so it immediately has codebase awareness.

**Persona:** Developer who wants the agent to already know the project structure, current file, and git branch without having to explain it.

**Requirement:**
- Harness must send `session/new` with editor capabilities declared: `workspace`, `openFiles`, `terminalOutput`.
- Context payload must include: workspace root path, list of currently open file paths, last 200 lines of active pane terminal output, current git branch and status summary.
- Context must be scoped to the active workspace (git repo root or CWD of active pane).

**User Flow:**
1. Developer has a project open in Harness with 3 active panes.
2. Developer activates Claude Code agent.
3. Harness bootstraps `session/new` with workspace root, open files list, active pane output, and git branch.
4. Agent immediately responds with context-aware suggestions.

**Acceptance Criteria:**
* **Given** an agent is launched, **when** `session/new` is sent, **then** the payload includes workspace root, open file paths, last 200 lines of terminal output, and git branch.
* **Given** the active pane CWD changes, **when** the developer sends a new prompt, **then** the updated CWD context is included in the prompt request.

---

### PBI-ACP-003: Prompt Sending & Streaming Response Rendering
**Product Metrics:** Time-to-first-token visible in UI (target < 500ms from send).

**Goal:** Allow the developer to send a prompt to the active agent and see the streamed response rendered natively in a dedicated Harness panel.

**Persona:** Developer asking the agent to write code, explain a function, or fix a bug.

**Requirement:**
- A prompt input field must appear in the ACP response panel.
- Sending a prompt must trigger `prompt/send` JSON-RPC request to the active agent.
- The panel must stream token-by-token updates as the agent responds.
- Code blocks in the response must be syntax-highlighted using the active Harness theme.
- The developer must be able to copy a code block or apply it directly to a terminal pane split.

**User Flow:**
1. Developer types a prompt in the ACP panel: "Refactor `FileNode.swift` to use a value type."
2. Harness sends `prompt/send` with the prompt text and active file context.
3. Agent streams the response — tokens appear progressively in the panel.
4. Developer clicks "Apply to split" on a code block → Harness opens a new pane with the file loaded in a TUI editor.

**Acceptance Criteria:**
* **Given** a prompt is sent, **when** the agent starts responding, **then** the first token appears in the panel within 500ms.
* **Given** the agent response contains a code block, **when** rendered, **then** it is syntax-highlighted and has a copy button.
* **Given** "Apply" is clicked on a code block, **when** executed, **then** Harness opens a split pane with the file and content staged for editing.

---

## Business Rules
1. **No Main Actor blocking:** All ACP subprocess I/O and JSON-RPC parsing must run on background Swift Actors. The UI must never stall waiting for agent responses.
2. **One active agent per workspace:** Only one ACP agent subprocess may be active per workspace session at a time (MVP). Multi-agent support is post-MVP.
3. **Context size limit:** Total `session/new` payload must not exceed 64KB. Terminal output is capped at 200 lines. File list is capped at 500 paths.
4. **Agent binary validation:** Before launching, Harness must verify the configured binary exists and is executable. Show a clear error if not found.

---

## Non-Functional Requirements

### Performance
- Agent subprocess launch + handshake: < 3 seconds.
- `session/new` bootstrap: < 500ms after handshake.
- First streaming token visible: < 500ms from `prompt/send`.

### Reliability
- Crash detection and reconnect UI within 1 second of process exit.
- JSON-RPC parse errors must be logged and surfaced as user-visible error messages, not silent failures.

### Security
- Agent binaries are launched with the same user permissions as Harness (no escalation).
- No secrets or credentials are included in the context payload.

---

## MVP Scope
**In MVP:**
- PBI-ACP-001: Agent subprocess lifecycle (stdio transport only).
- PBI-ACP-002: Session bootstrap with workspace context.
- PBI-ACP-003: Prompt sending + streaming response panel.

**Post-MVP:**
- Streamable HTTP transport for remote agents.
- Multi-agent support per workspace.
- Agent response diff-apply (patch files directly instead of terminal split).
- ACP Agent Registry browser inside Harness settings.
