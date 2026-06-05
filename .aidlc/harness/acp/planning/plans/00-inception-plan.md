# Inception Plan: Agent Client Protocol (ACP) — Harness ACP Client

## Status: Completed

## Objective
Establish the full design foundation for implementing ACP (Agent Client Protocol) in Harness as an ACP Client/Editor, enabling Claude Code, Codex, and Gemini CLI to connect to Harness as first-class AI coding agents.

## Phases Completed

| Phase | Output | Status |
|---|---|---|
| Phase 0 | audit.md, PROGRESS.md, decisions/00-inception-decisions.md | ✅ |
| Phase 1 | outputs/inception/user-stories.md | ✅ |
| Phase 1.2 | outputs/inception/domain-decomposition.md | ✅ |
| Phase 1.4 | outputs/inception/domain-design.md | ✅ |
| Phase 1.6 | outputs/inception/logical-design.md | ✅ |
| Phase 1.8 | outputs/inception/brainstorming-summary.md | ✅ |

## Key Outputs
- 3 MVP PBIs defined with BDD acceptance criteria
- 4 bounded contexts mapped (ACPRuntime, AgentRegistry, SessionContext, ResponseRenderer)
- 7 new Swift source files identified across `HarnessCore/ACP/` and `HarnessApp/`
- 3 test files identified
- Architecture: Actor-based async pipeline, JSON-RPC 2.0 over stdio

## Next Phase
→ Phase 2.5: Dev Task Design (`planning/plans/05-implementation.md`)
