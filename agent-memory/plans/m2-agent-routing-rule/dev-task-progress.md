# M2 — Agent Routing Rule — Task Progress

Design: [design.md](design.md). Wayfinder ticket: [../m2-m9-competitive-features/wayfinder-map.md](../m2-m9-competitive-features/wayfinder-map.md) (M2).

## KouenIPC

- [x] `AgentRoutingRuleSummary` wire struct (`Packages/KouenIPC/Sources/KouenIPC/AgentRoutingRuleSummary.swift`) — mirrors `AutomationSummary`
- [x] `IPCRequest` cases: `routingRuleList/Get/Create/Update/Delete/Reorder`
- [x] `IPCResponse` cases: `routingRuleInfo`/`routingRules`

## KouenCore

- [x] `AgentRoutingRule` model + `Kind` enum (`Packages/KouenCore/Sources/KouenCore/Routing/AgentRoutingRule.swift`)
- [x] `AgentRoutingRuleStore` (`Packages/KouenCore/Sources/KouenCore/Routing/AgentRoutingRuleStore.swift`) — mirrors `AutomationStore` persistence shape, per-kind `reorder`
- [x] `AgentRoutingResolver.resolve(cwd:rules:defaultAgent:)` — two-phase (path glob via `fnmatch` → detected stack → default), pure function (`Packages/KouenCore/Sources/KouenCore/Routing/AgentRoutingResolver.swift`)
- [x] `KouenPaths.agentRoutingRulesURL`
- [x] `KouenSettings.defaultAgentKind: AgentKind` field, default `.claudeCode` (fog-resolved decision — see design.md); added to init/decoder alongside `agentColorOverrides`

## KouenDaemon

- [x] `SurfaceRegistry.routingRuleStore` property
- [x] IPC case handlers for all 6 requests
- [x] `fireAutomationLocked` — resolve `agent == "auto"` via `AgentRoutingResolver` using the automation's `repoPath` as `cwd`, before calling `automationLaunchCommand`

## kouen-mcp

- [x] `ToolPolicy.dangerousTools`: Create/Update/Delete/Reorder gated; List/Get ungated
- [x] `ToolRegistry` tool defs (5 tools: `kouenRoutingRuleList/Create/Update/Delete/Reorder`) + dispatch + wrapper funcs
- [x] `KouenDaemonTools` routing-rule funcs + `routingRuleJSON` serializer
- [x] `kouenSpawnAgent` — intercept `agent.lowercased() == "auto"` before the existing switch, resolve via `AgentRoutingResolver` (fetches rules via `.routingRuleList` IPC, `defaultAgent` via local `KouenSettings.load()`), fall through with resolved agent string. Every other `agent:` value's behavior unchanged (verified: switch/error path/result-dict all still keyed off the same string, just renamed `agent`→`resolvedAgent`).

## KouenApp (Settings UI)

- [x] **Scope decision, not built**: checked precedent first — Automations (P41, the closest analog feature) ship with **zero GUI view**, MCP-CRUD only (`grep` for any Automation SwiftUI view returned nothing). M2 v1 follows the same precedent: MCP-only, no Settings UI editor. Avoids inventing an unreviewed list-editor pattern with no existing analog to mirror. Revisit if the user actually wants a GUI editor later — separate ticket, not blocking M2.

## Tests

- [x] `Tests/KouenCoreTests/AgentRoutingResolverTests.swift` — 8 tests: path-rule wins over stack-rule, disabled rule skipped, no match falls to `defaultAgent`, nil cwd falls to default, glob pattern matching, order-within-phase, real stack detection (Package.swift), unknown stack falls through
- [x] `Tests/KouenCoreTests/AgentRoutingRuleStoreTests.swift` — 6 tests: CRUD round trip, per-kind order independence, reorder scoped to its own kind, reorder omitted-rule handling, persists across reopen, update-on-missing-id
- [x] `Tests/KouenDaemonTests/AgentRoutingRuleIPCDaemonTests.swift` — 4 tests: CRUD round trip via `handle()`, unknown kind/agent rejected, missing-id errors, reorder round trip
- [x] `Tests/KouenMCPTests/KouenDaemonToolsTests.swift` (+5 tests) — registration/gating (List ungated, Create/Update/Delete/Reorder gated), invalid-UUID rejection, gate-closed error path
- [ ] Full `kouenSpawnAgent(agent:"auto", ...)` end-to-end MCP test — needs a live daemon connection (same as P41's own deferred live-check item), not built as a unit test. Deferred to the live check below.

## Docs

- [x] `GLOSSARY.md` — already updated during interview pass (Agent Routing Rule term + relationship)
- [x] `agent-memory/plans/INDEX.md` — M2 row added
- [ ] `agent-memory/plans/m2-m9-competitive-features/wayfinder-map.md` — mark M2 ticket closed, one-line gist in Decisions-so-far (next step)

## Verification

- [x] `swift build` (full) — clean, only pre-existing unrelated warnings (KouenBrowserTools.swift `let` pattern, DaemonServer.swift weak-capture, KouenWindow.swift actor-isolation — none touched by this change)
- [x] `swift test` (KouenCoreTests/KouenDaemonTests/KouenMCPTests, run directly via `xcrun xctest` — `swift test`'s own runner can't load `KouenAppTests.xctest` in this environment, see below) — KouenCoreTests 674 tests/5 failures (exactly the documented pre-existing baseline: ExperienceModeTests, Phase6KeysTests, ReleaseNotesGuardTests — zero new failures), KouenDaemonTests 218/0 failures, KouenMCPTests 32/0 failures
- [x] `Tests/robot/run.sh` — 26/27 passed. The 1 failure (`Pairing Unit Tests Pass`) is the same pre-existing environment issue below, not a regression — it internally shells out to `swift test --filter MobileBridgePairingTests`, which tries to load every `.xctest` bundle including `KouenAppTests` and hits the same dlopen failure.
- **Pre-existing environment issue found, not caused by this change**: `KouenAppTests.xctest` fails to `dlopen` — `Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle`. Confirmed unrelated: this change touches no Sparkle/KouenApp-update code at all. Blocks the plain `swift test` command (and anything that shells out to it) from completing; every other test bundle runs fine directly via `xcrun xctest <bundle>.xctest`. Worth a separate investigation (Sparkle.framework likely missing from `.build/out/Products/Debug/` after an SDK/toolchain change — Xcode-beta/macOS27 SDK per the build warnings — not part of M2's scope).
- [ ] Live check: real MCP client calling `kouenSpawnAgent(agent:"auto", cwd:...)` with a configured path rule, confirm the resolved (not literal "auto") agent actually spawns — owed, same as every other P-plan's live-check item in this project
