# M4 — Fork Conversation — Task Progress

Design: [design.md](design.md). Wayfinder ticket: [../m2-m9-competitive-features/wayfinder-map.md](../m2-m9-competitive-features/wayfinder-map.md) (M4).

## KouenApp — MainMenuBuilder.swift

- [x] "Fork Conversation" menu item (View menu, after Split Down)
- [x] `MenuTarget.forkCommand(for: AgentKind) -> String?` — `claude --continue --fork-session` / `codex fork --last` / nil for everything else
- [x] `MenuTarget.forkConversation()` action — reads active tab's `effectiveAgentKind`, calls `SessionCoordinator.splitActivePaneAndRun`
- [x] `validateMenuItem` case — disables the menu item when the active tab's agent has no verified fork command

## Tests

- [x] `Tests/KouenAppTests/MenuTargetForkConversationTests.swift` (3 tests) — claude-code command, codex command, every other `AgentKind` returns nil
- [ ] Live check: real Claude Code/Codex pane, Fork Conversation, confirm the new pane's CLI actually resumes with prior context — owed (needs live CLI + API calls, can't unit-test)

## Docs

- [x] `GLOSSARY.md` — "Fork Conversation" term added
- [x] `agent-memory/plans/INDEX.md` — M4 row added
- [x] `agent-memory/plans/m2-m9-competitive-features/wayfinder-map.md` — M4 marked closed

## Verification

- [x] `swift build --product Kouen` — clean
- [x] `swift build --build-tests` — clean
- [x] `KouenAppTests.xctest` full suite — 247 tests, 0 failures (0 new vs M3's 244 baseline + 3 new)
