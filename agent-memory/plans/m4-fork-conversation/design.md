# Design — M4: Fork Conversation

Wayfinder ticket: `agent-memory/plans/m2-m9-competitive-features/wayfinder-map.md` (M4).
GLOSSARY.md: "Fork Conversation" term added.

**Architecture reality check (same class of issue as M2):** cmux can literally fork a
conversation because cmux owns its own agent/LLM orchestration. Kouen wraps opaque CLI
subprocesses over a PTY — it has no visibility into an agent's conversation state at all.
Verified (2026-08-05, real `--help` output, not docs/marketing) that the two CLIs this
project's own AgentKind enum lists first each ship a **real, built-in fork mechanism**:
- `claude --continue --fork-session` — "Continue the most recent conversation in the
  current directory" + "create a new session ID instead of reusing the original"
- `codex fork --last` — "Fork a previous interactive session... fork the most recent"

Neither requires Kouen to discover or track a session ID itself — both CLIs resolve
"most recent, this directory" on their own. This made the feature small: reuse the
already-existing `SessionCoordinator.splitActivePaneAndRun(direction:command:)` primitive
(same one `kouenSpawnAgent`-adjacent split-and-type flows already use), map `AgentKind`
to a command string, done.

Gemini/Kiro/Cursor/others: no verified fork mechanism, so `forkCommand(for:)` returns
`nil` and the menu item is disabled for that pane's agent — not a silent fake fork
(duplicate cwd with a blank new session would *look* like it worked while losing all
context, which is worse than clearly not offering it).

## Strategic Design

No new bounded context. Extends existing **Session/Pane** capability
(`SplitPaneCoordinator`, `MainMenuBuilder`) with one new menu command.

## Tactical Design

No new persisted model. Pure logic: `MenuTarget.forkCommand(for: AgentKind) -> String?`
(`MainMenuBuilder.swift`), a static lookup table, easily unit-tested without any daemon/
WebKit dependency (unlike M2/M3's harder-to-test-in-isolation pieces).

## Logical Design

- `MainMenuBuilder.swift`: "Fork Conversation" item in the View menu, after Split Down.
  `MenuTarget.forkConversation()` reads `SessionCoordinator.shared.snapshot.activeWorkspace?
  .activeTab?.effectiveAgentKind` (existing centralized agent-detection property, already
  used the same way by `MenuBarController.swift`), looks up the fork command, calls
  `SessionCoordinator.shared.splitActivePaneAndRun(direction: .horizontal, command:)`.
- `validateMenuItem` gates enable state: disabled whenever `forkCommand(for:)` is `nil`
  for the active tab's agent (mirrors the existing `detachPane`/`reattachPane` gating
  pattern already in `MenuTarget`).
- No new IPC, no new storage, no new Settings.

## Next Step
Implemented directly (small enough to skip a separate task-design pass):
1. `MenuTarget.forkCommand(for:)` + `forkConversation()` action + menu item + validate case
2. Unit tests: `Tests/KouenAppTests/MenuTargetForkConversationTests.swift`
3. Live check owed: real Claude Code / Codex pane, click Fork Conversation, confirm the new
   pane's CLI actually resumes with prior context (not just that the command ran) — this is
   the one thing that can't be verified without a live CLI session and real API calls.
