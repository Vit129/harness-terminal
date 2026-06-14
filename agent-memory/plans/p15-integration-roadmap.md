# P15 — Integration Roadmap (P4 + P10 + P11 + P12 + P13/P14)

Status: **planned / not started**
Priority: **P2** — sequencing/coordination plan, not a feature in itself
Owner surface: cross-cutting (HarnessCore, HarnessApp UI, harness-mcp, harness-cli)
Created: 2026-06-14, after P11 PBI-SCRIPT-001/002/003 and P13 PBI-SPLIT-001..005 landed

---

## Goal

P4, P10, P11, P12, and P13/P14 were planned somewhat independently (each from its own
"gap review" pass). Individually they are coherent; together several of them assume
the same underlying primitives (a pane/session command facade, the `PaneNode` split
tree, and an app-side event bus). This document is the integration map: which plans
share a primitive, what order avoids rework, and which open gaps from each plan are
now blocking another plan.

This is a **planning/sequencing** document. It does not introduce new features —
it cross-references existing plan docs ([[p4]], [[p10]], [[p11]], [[p12]], [[p13]])
and records the decisions needed to land them without duplicate or conflicting work.

## Non-Goals

- Do not re-litigate decisions already marked DONE in P11 PBI-SCRIPT-001/002/003 or
  P13 PBI-SPLIT-001..005.
- Do not redesign `PaneNode`, `CommandIPCTranslator`, or the daemon IPC surface here —
  those stay owned by their respective plans.
- Do not start P14 (embedded browser) work from this doc; it only notes where P14
  will plug in once P13 is merged.

---

## Current State Snapshot (2026-06-14)

| Plan | Status | Key deliverable |
|------|--------|-----------------|
| P4 — LSP + File View | Two divergent docs exist (see "Known Gap" below). `worktree-p4-track23`'s rewritten doc claims Track 1/2/3 DONE (syntax highlighting, Quick Look-style viewer, LSP). `origin/main`'s older doc still frames Track 2/3 as not started. | Sidebar file viewer + `HarnessLSP` client, `ContentAreaViewController.showFileEditorSplit()` sibling panel (not a `PaneNode` leaf). |
| P10 — Performance & Feature Roadmap | Items 1-3 done (lazy reflow, local completion, keyboard layout presets). Item 4 (ACP sidebar) deferred. Also shipped: Session State Dot, IDE Mode Persistence, Task Board Sidebar Tab (Makefile/package.json runner), Focus Mode (⌘P). | `WorkspaceSymbolIndex`, `CompletionPopupView`, per-session state dot, Makefile/package.json task runner sidebar tab. |
| P11 — Scripting & Config API | PBI-SCRIPT-001/002/003 DONE (JavaScriptCore runtime, reload lifecycle, read-only snapshot API + `commands.parse`). PBI-SCRIPT-004/005 not started. Explicit gap: `harness.events` namespace and `harness.commands.run`/mutators not implemented. | `ScriptRuntime`, `ScriptHookCoordinator`, `ScriptAPI` (`harness.sessions`, `harness.panes`, `harness.commands.parse`). |
| P12 — Agent Orchestration via MCP | PBI-ORCH-001/002/003/004 DONE. PBI-ORCH-005 (UI visibility indicator) scoped only, no implementation. | `harnessList`, `readPaneOutput`, `waitForPaneOutput`, gated mutating tools (`sendPaneText`, `sendPaneKeys`, `spawnSession`, `splitPane`, `closePane`), `ToolPolicy`. |
| P13 — Split Pane Parity | **Done** (uncommitted, awaiting review on `worktree-p13-split-pane`). PBI-SPLIT-001..005 implemented; top/bottom splits restored alongside side-by-side. | Vertical-split gate removed in `SessionCoordinator.splitActivePane`, "Split Down" UI affordances, CLI/docs parity, geometry + targeting tests. |
| P13 (alt doc) — Embedded Browser ("P14" in narrative) | Idea / not started. Explicitly depends on split panes landing first. | `WKWebView`-backed third `PaneNode` leaf kind. |

---

## Shared Primitives Map

Three primitives are referenced by name across multiple plans. Landing each one
once, in the right order, avoids three teams (or three agent sessions) building
slightly different versions.

### 1. The narrow pane/session command facade

- **P12** PBI-ORCH-002 built `sendPaneText`, `sendPaneKeys`, `spawnSession`,
  `splitPane`, `closePane` as MCP tools over existing `DaemonClientActor` IPC
  requests (`.send`, `.sendKeys`, `.newSession`, `.newSplit`, `.killPane`).
- **P11** PBI-SCRIPT-005 ("Mutating command/session/pane API") is explicitly gated:
  *"Do not start PBI-SCRIPT-005 until P12's MCP pane-control API is either
  implemented or deliberately deferred, because both features want the same narrow
  pane/session command facade."*
- **Status:** P12's facade is DONE (PBI-ORCH-002/004). **P11 PBI-SCRIPT-005 is now
  unblocked** — `ScriptAPI.swift` mutators (`pane.sendText`, `pane.split`,
  `pane.close`, `session.spawn`) should call the *same* `CommandParser` +
  `CommandIPCTranslator` + `DaemonClientActor` path that `HarnessDaemonTools.swift`
  uses for MCP, not a third implementation. Concretely: factor the
  direction-parsing / IPC-dispatch helpers in `HarnessDaemonTools.swift` so both
  `harness-mcp` and `ScriptAPI` (app-side, `@MainActor`) can call into them, or at
  minimum keep both call sites going through `CommandIPCTranslator` with identical
  direction-mapping so `harness.panes.split({direction: "right"})` and MCP's
  `splitPane({direction: "right"})` agree.

### 2. The `PaneNode` split tree (P13 → P14, P4's file editor)

- **P13** (done) restored `.vertical`/`.horizontal` splits end-to-end through
  `PaneNode`, `SessionCoordinator.splitActivePane`, `HarnessSplitView`, and CLI.
- **P13-embedded-browser** ("P14") explicitly depends on P13 landing first and
  notes the file-editor split is "currently a sibling panel, *not* part of the
  `PaneNode` tree" and "may need to become a `PaneNode` case."
- **P4**'s `ContentAreaViewController.showFileEditorSplit()` is that same sibling
  panel. Any future work that promotes the file editor into `PaneNode` (for P14
  parity, or to fix the editor/sidebar coupling noted below) touches P4, P10's IDE
  Mode layout presets, and P14 simultaneously — scope that as its own PBI rather
  than folding it into any one of those plans silently.
- **Status:** P13 merge is the gate. Once `worktree-p13-split-pane` is reviewed and
  merged, P14 can be scoped concretely (current doc is "idea / not started").

### 3. The app-side event bus (`harness.events`, `NotificationBus`, MCP visibility)

- **P11**'s "Public JS API v1" defines `harness.events.on(name, handler)` with v1
  events including `snapshotChanged`, `sessionCreated`, `agentStateChanged`,
  `notificationPosted` — but this namespace is an explicit **gap**, not yet
  implemented (PBI-SCRIPT-003's notes call this out directly).
- **P12** PBI-ORCH-005 (scoped only) proposes a "MCP-controlled" indicator driven by
  "the normal `NotificationBus.snapshotChanged` path or a narrow new notification
  emitted when the daemon accepts MCP-originated control," explicitly *not*
  persisted in `HarnessSettings`.
- **P10** shipped a Session State Dot (blue=running/gray=idle/green=exit0/red=error)
  driven by snapshot diffing — the same signal `agentStateChanged` would carry.
- **Status:** these three features want one bridge: `NotificationBus` →
  `harness.events` (P11, not yet built) and `NotificationBus` → MCP-visibility
  indicator (P12, not yet built) and `NotificationBus` → Session State Dot (P10,
  already built — proves the signal exists). Build the `harness.events` bridge
  (P11's remaining gap) as the single fan-out point; P12 PBI-ORCH-005 and any
  future "board" feature (see [[p16-task-board]]) should subscribe to the same
  bridge rather than re-deriving state from raw snapshot diffs independently.

---

## Known Gap: Divergent P4 Docs

`agent-memory/plans/p4-lsp-file-view.md` differs between `origin/main` (older doc,
"Track 2 — Quick Look Preview" / "Track 3 — LSP Integration" framed as not started)
and `worktree-p4-track23` (rewritten doc, "Track 1/2/3 DONE"). These have **not been
reconciled**. Before any of the integration points above that touch P4 (the
file-editor `PaneNode` promotion in particular) are scheduled, merge
`worktree-p4-track23` to `main` first so there is one authoritative P4 doc and one
authoritative `ContentAreaViewController`/`HarnessLSP` implementation to integrate
against.

---

## Recommended Sequencing

1. **Merge P13** (`worktree-p13-split-pane`) — unblocks P14 scoping and is a
   prerequisite for any `PaneNode` changes touched by P4/P10/P14 integration.
2. **Merge P4 Track 2/3** (`worktree-p4-track23`) — reconciles the divergent P4
   docs; gives P14 and the file-editor/`PaneNode` question one ground truth.
3. **Build the `harness.events` bridge** (remaining P11 gap) — single
   `NotificationBus`-backed fan-out used by P11 scripts, P12 PBI-ORCH-005's MCP
   indicator, and the board feature ([[p16-task-board]]).
4. **P11 PBI-SCRIPT-004/005** — config/keybinding writes and mutating pane/session
   API, reusing P12's command facade per "Shared Primitives Map" item 1.
5. **P12 PBI-ORCH-005** — MCP-controlled indicator, now that the event bridge
   exists.
6. **P16 (board feature)** — consumes the event bridge + read-only snapshot APIs
   from P11/P12; can start in parallel with steps 4-5 since it only needs
   read-only data plus the bridge.
7. **P14 (embedded browser)** — only after step 1, and after the file-editor
   `PaneNode` question from step 2 is resolved (a `WKWebView` leaf and a promoted
   file-editor leaf are the same kind of change; do them together or in the same
   PBI sequence to avoid two separate `PaneNode` migrations).

## Acceptance Criteria

- A single, current P4 plan doc exists on `main` (no divergent copies).
- `harness.events` bridge exists, is used by at least P11's `configReloaded`/
  `snapshotChanged` events, and is documented as the integration point for P12
  PBI-ORCH-005 and P16.
- P11 PBI-SCRIPT-005 mutators and P12's MCP mutating tools share direction-parsing
  and IPC-dispatch code (no duplicated `CommandIPCTranslator` call sites with
  diverging direction maps).
- P14 scoping doc references the resolved file-editor/`PaneNode` decision instead
  of leaving it as an open question.
