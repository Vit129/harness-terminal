# Decision Record: Inception — Agent Client Protocol (ACP) in Harness

## Status: Decided

## Background
- **What is ACP?** The Agent Client Protocol is an open standard (JSON-RPC 2.0) developed by JetBrains + Zed that standardizes how code editors communicate with AI coding agents (Claude Code, Codex, Gemini CLI, etc.). Often described as "LSP for AI agents".
- **What already exists in Harness?** PTY daemon (harnessd), IPC command bus (`split-window`, `send-keys`), `SurfaceShellTracker` tracking CWD/git branch per pane, existing agent activity UI.
- **What is missing?** Harness has no protocol layer to launch and communicate with external AI coding agents as first-class citizens. Currently agents run loosely in terminal panes without structured context exchange.

---

## Outstanding Decisions

### Decision 1: ACP Transport Layer
**Context**: ACP supports two transports — stdio (local subprocess) and Streamable HTTP (remote). Which to implement first?

**Options**:
- **A) stdio only (local subprocess)**
  - *Rationale*: Claude Code, Codex, Gemini CLI all run locally and support stdio ACP. Simplest integration path.
  - *Consequences*: No remote agent support. Sufficient for MVP.
- **B) Streamable HTTP only (remote)**
  - *Rationale*: Agents hosted in cloud or on separate machine.
  - *Consequences*: More complex networking; remote agents not yet critical for Harness.
- **C) Both (stdio + HTTP)**
  - *Rationale*: Full ACP coverage.
  - *Consequences*: Higher implementation cost.

**Decision**: A (stdio local subprocess) — MVP
**Additional Rationale**: All target agents (Claude Code, Codex, Gemini CLI) run locally. stdio is the stable ACP v1 transport. HTTP is draft/proposal.
**Post-MVP**: Add Streamable HTTP transport.

---

### Decision 2: Editor Context Passed to Agent
**Context**: At `session/new`, the editor declares its capabilities and passes workspace context to the agent. What context should Harness send?

**Options**:
- **A) Minimal context** — workspace root path + active pane CWD + git branch
- **B) Rich context** — workspace root + open files list + terminal output buffer + git status
- **C) Full file contents** — send all open file contents inline

**Decision**: B (Rich context)
**Additional Rationale**: File tree and terminal output are already tracked by `SurfaceShellTracker`. Sending them adds minimal overhead but gives agent meaningful context. Full file contents (Option C) would exceed JSON-RPC message size limits.
**Scope**: workspace root, open file paths (not content), last 200 lines of active pane output, current git branch + status summary.

---

### Decision 3: Agent Response Rendering
**Context**: How should Harness display the agent's streamed token response to the user?

**Options**:
- **A) Inside a terminal pane** — pipe agent output into a PTY split as plain text
- **B) Native AppKit response panel** — dedicated `ACPResponsePanelViewController` with markdown rendering
- **C) Inline in sidebar** — render agent chat inline in the existing agent activity sidebar area

**Decision**: B (Native AppKit response panel)
**Additional Rationale**: Agent responses contain code blocks, markdown, and structured output. A dedicated panel renders them correctly. Terminal panes are for shell I/O, not markdown chat.
**Additional Consequences**: Requires implementing `ACPResponsePanelViewController` with basic markdown rendering (can reuse `MarkdownPreviewViewController` from ide-file-tree).

---

## Decision Summary

| Decision | Chosen Option | Rationale | Impact |
|----------|---------------|-----------|--------|
| Transport | A (stdio) | All local agents use stdio; stable ACP v1 | Medium |
| Context | B (rich) | CWD/git/terminal already tracked; no content overhead | Medium |
| Response UI | B (native panel) | Agent output is markdown/structured, needs proper rendering | High |

## Next Steps
1. Create `outputs/inception/user-stories.md`
2. Proceed with full inception phases.
