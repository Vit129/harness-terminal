# AI-DLC Audit Trail - Iteration 1: Agent Client Protocol (ACP) — Harness ACP Client

## Current State
- **Current Phase**: 2.5 Dev Task Design
- **Status**: In Progress
- **Last Activity**: 2026-06-05T00:00:00+07:00
- **Next Action**: Create `05-implementation.md` task breakdown

## Iteration Overview
- **Start Date**: 2026-06-05
- **Architecture Choice**: Harness as ACP Client (Editor side) — JSON-RPC 2.0 over stdio subprocess launch + StreamableHTTP for remote agents. Swift Actor-based message pump. Native UI panel for agent response streaming.
- **Progress**: 6/10 phases completed

## Phase History
- **Phase 0: Setup and Inception** - Completed on 2026-06-05. Initialized `.aidlc/` folder, decisions record, audit log, inception plan.
- **Phase 1: Requirements Gathering** - Completed on 2026-06-05. Generated BDD user stories for ACP session bootstrap, agent subprocess management, context passing, and streaming response rendering.
- **Phase 1.2: Domain Decomposition** - Completed on 2026-06-05. Defined bounded contexts: ACPRuntime, AgentRegistry, SessionContext, ResponseRenderer.
- **Phase 1.4: Domain Design** - Completed on 2026-06-05. Designed domain entities (ACPSession, ACPAgent, ACPMessage), JSON-RPC value objects, and event flows.
- **Phase 1.6: Logical Design** - Completed on 2026-06-05. Mapped project directory layout, Swift class targets, and dependency graph.
- **Phase 1.8: Brainstorming (3 Amigos)** - Completed on 2026-06-05. Synthesized PO/Dev/QA perspectives on agent lifecycle, error recovery, and context size limits.

## Key Decisions
- **Decision 1 (Transport):** stdio JSON-RPC for local agents (Claude Code, Codex, Gemini CLI); Streamable HTTP for future remote agents.
- **Decision 2 (Context passing):** Pass workspace root, open files list, active pane CWD, and git branch via `session/new`. No full file contents by default (too large).
- **Decision 3 (Response UI):** Stream agent tokens into a dedicated ACPResponsePanelViewController — not inside a terminal pane.

## Notes
- ACP is a prerequisite for ide-file-tree full agent integration.
- MVP: local subprocess agents only (stdio). Remote HTTP is post-MVP.
- Reference spec: https://agentclientprotocol.com

## Knowledge Buffer
- ACP protocol version: 1 (stable)
- Transport: JSON-RPC 2.0 over stdio (local), Streamable HTTP (future)
- Key messages: `session/new`, `prompt/send`, streaming notifications, bidirectional requests
- Editor capabilities declared at handshake: workspace, openFiles, terminalOutput

## Reflexion Log
*Self-healing logs will be recorded here*
