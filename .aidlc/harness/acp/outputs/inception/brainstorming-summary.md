# Brainstorming Summary (3 Amigos): Agent Client Protocol (ACP) — Harness ACP Client

## Participants
- **PO perspective**: What does the developer experience need to feel like?
- **Dev perspective**: What are the hard technical constraints?
- **QA perspective**: What breaks and how do we catch it?

---

## PO Perspective

**Key concern**: The agent must feel like it's *inside* Harness, not bolted on. If activating Claude Code feels like opening a separate app, we've failed.

**Wants:**
- One-click agent activation from sidebar.
- Agent "knows" the project on first prompt — no onboarding friction.
- Response panel doesn't cover the terminal. It should be a side panel or bottom panel, not a modal.
- Clear visual indicator: agent is thinking / streaming / done / crashed.

**Risk flagged**: If the agent subprocess is slow to launch (> 3s), the developer will think Harness is frozen. Need a loading spinner.

---

## Dev Perspective

**Key concern**: Swift 6 strict concurrency + `Foundation.Process` async I/O is tricky. `Process.launch()` is synchronous; wrapping it cleanly in an Actor without blocking the main thread requires care.

**Hard constraints:**
- `Pipe.fileHandleForReading.availableData` is blocking — must use `AsyncBytes` or background thread for reading.
- JSON-RPC framing over stdio has no built-in message boundary. Need to implement newline-delimited JSON (Content-Length header like LSP, or pure NDJSON depending on ACP spec).
- `Process.terminationHandler` fires on a background queue — must hop to actor isolation before mutating state.

**Risk flagged**: ACP spec says Content-Length framing (same as LSP). Need to confirm before building transport. Check: https://agentclientprotocol.com/protocol/transports

---

## QA Perspective

**Key concern**: Agent subprocess is an external process — the biggest source of flakiness. Standard unit tests won't cover it.

**Test strategy:**
- `ACPTransportTests`: pure encode/decode, no process needed.
- `ACPSessionTests`: mock `ACPProcess` protocol — test state machine transitions without real subprocess.
- Integration test: spawn a simple echo agent binary that responds with valid ACP JSON → test full handshake + session/new + prompt/response roundtrip.

**Edge cases to cover:**
- Agent binary not found → expect graceful error, not crash.
- Agent sends malformed JSON → expect parse error logged, session stays alive.
- Agent crashes mid-stream → expect partial response shown + reconnect UI.
- Context payload exceeds 64KB → expect truncation applied correctly.

**Risk flagged**: The "Apply to split" button in the response panel calls `SessionCoordinator` — this is an integration point that could be broken by ide-file-tree changes. Cross-feature regression test needed.

---

## Synthesis

| Issue | Resolution |
|---|---|
| Agent launch latency | Show spinner + 3s timeout with clear error |
| ACP framing | Confirm Content-Length header transport from spec before building |
| Strict concurrency | Use `actor ACPProcess` with `AsyncStream` for stdout reading |
| Test coverage | Mock `ACPProcess` protocol for unit tests; echo-agent binary for integration |
| Response panel placement | Side panel (not modal), collapsible, inherits Harness theme |
| Cross-feature regression | `ACPResponsePanel` ↔ `SessionCoordinator` integration test added to QA plan |
