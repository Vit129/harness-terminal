# Design — M2: Agent Routing Rule

Wayfinder ticket: `agent-memory/plans/m2-m9-competitive-features/wayfinder-map.md` (M2).
GLOSSARY.md: "Agent Routing Rule" term added during interview pass.

PRODUCT.md check: fits existing Core Feature "Multi-agent awareness" — no conflict
with Out of Scope.

**Fog resolved during design (flag, don't guess-silently):** interview assumed a
"default agent" setting already existed as the no-match fallback ("(ถ้ามี)" —
hedged). Confirmed by grep: no such setting exists today —
`kouenSpawnAgent`'s unknown-agent path (`KouenDaemonTools.swift:353-356`) just
errors (`-32602 Unknown agent`). This design adds one new settings field
(`KouenSettings.defaultAgentKind: AgentKind`, default `.claudeCode`) to make the
fallback real — smallest possible new surface, not a judgment call worth a
separate gate (obvious safe default, matches this session's own live
`kouenList` evidence: all 4 of the user's current sessions run `claude-code`).

## Strategic Design

Single bounded context — no new context. This is a new capability inside the
existing **Agent Session Management** context that already owns `AgentKind`,
`AutomationStore`, `TaskStore`, `SignalFileRouter`. Kouen is a single native
macOS app + daemon (monolith); no architecture-pattern decision needed, this
follows the established module-per-capability convention (mirrors P41
Automations' own placement).

Module boundaries:
- `KouenCore/Routing/` — new `AgentRoutingRuleStore` + `AgentRoutingResolver`
  (pure domain logic, alongside existing `SignalFileRouter.swift`)
- `KouenDaemon` — owns `AgentRoutingRuleStore` instance, persists to disk
  (mirrors `AutomationStore`'s daemon-owned pattern)
- `kouen-mcp` (`KouenDaemonTools.swift`) — new MCP CRUD tools + the `"auto"`
  interception in `kouenSpawnAgent`
- `KouenApp/Settings` — new rule-list editor section

## Tactical Design

### Aggregate: `AgentRoutingRule`
```swift
struct AgentRoutingRule: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    var order: Int              // priority within its own kind group, ascending
    var kind: Kind
    var targetAgent: AgentKind
    var enabled: Bool

    enum Kind: Codable, Sendable, Equatable {
        case repoPathGlob(String)     // e.g. "~/Git/Company/**"
        case detectedStack(String)    // matches SignalFileRouter.DetectedProfile.stack
    }
}
```
No domain events — this is CRUD + a pure read-side resolver, same shape as
`AutomationStore` (which also has no event stream, just list/get/create/update/
delete/pause/resume/run-now as direct calls).

### Aggregate root: `AgentRoutingRuleStore`
Mirrors `AutomationStore`'s persistence shape 1:1 (`Packages/KouenCore/Sources/
KouenCore/Automations/AutomationStore.swift`): daemon-owned, `@unchecked
Sendable`, own lock, JSON-persisted under `KouenPaths` state dir
(`agent-routing-rules.json`, sibling to `automations.json`). CRUD methods:
`list() / get(id:) / create(kind:targetAgent:) / update(id:...) / delete(id:) /
reorder(kind:orderedIDs:)` — reorder is scoped per `Kind` (path rules and stack
rules each keep their own priority ordering; the two groups don't interleave).

### Domain service: `AgentRoutingResolver`
```swift
enum AgentRoutingResolver {
    /// Two-phase, first-match-wins within each phase. Never mid-session — only
    /// called at spawn time (kouenSpawnAgent, Automation fire).
    static func resolve(
        cwd: String?,
        rules: [AgentRoutingRule],
        defaultAgent: AgentKind
    ) -> AgentKind {
        let enabled = rules.filter(\.enabled)
        guard let cwd else { return defaultAgent }

        // Phase 1 — explicit repo-path glob rules, ascending order
        let pathRules = enabled
            .filter { if case .repoPathGlob = $0.kind { true } else { false } }
            .sorted { $0.order < $1.order }
        for rule in pathRules, case let .repoPathGlob(pattern) = rule.kind {
            if fnmatch(pattern, cwd, 0) == 0 { return rule.targetAgent }
        }

        // Phase 2 — detected-stack fallback rules, ascending order
        if let profile = SignalFileRouter.detectProfile(at: cwd) {
            let stackRules = enabled
                .filter { if case .detectedStack = $0.kind { true } else { false } }
                .sorted { $0.order < $1.order }
            for rule in stackRules, case let .detectedStack(stack) = rule.kind {
                if stack == profile.stack { return rule.targetAgent }
            }
        }

        // Phase 3 — no rule matched
        return defaultAgent
    }
}
```
`fnmatch` (glob, POSIX, already linked via Foundation/Darwin — no new
dependency) for path patterns; exact-string match for stack (finite enum-like
set already produced by `SignalFileRouter`).

## Logical Design

### Storage
`agent-routing-rules.json` (array of `AgentRoutingRule`), daemon state dir,
same load/save pattern as `automations.json`.

### Settings addition
`KouenSettings.defaultAgentKind: AgentKind` (new field, default `.claudeCode`,
persisted in the existing `settings.json`) — Phase 3 fallback target.

### MCP tools (`kouen-mcp`, naming mirrors Automation's tool family)
| Tool | Params | Returns |
|---|---|---|
| `kouenRoutingRuleList` | — | `[AgentRoutingRule]` |
| `kouenRoutingRuleCreate` | `kind` (`"path"`\|`"stack"`), `pattern`, `targetAgent`, `enabled?` | created rule |
| `kouenRoutingRuleUpdate` | `id`, any of the above | updated rule |
| `kouenRoutingRuleDelete` | `id` | ok |
| `kouenRoutingRuleReorder` | `kind`, `orderedIDs: [UUID]` | ok |

### `kouenSpawnAgent` change (`KouenDaemonTools.swift:319-356`)
Insert before the existing `switch agent.lowercased()`:
```swift
let resolvedAgent: String
if agent.lowercased() == "auto" {
    let rules = await routingStore.list()
    let resolved = AgentRoutingResolver.resolve(
        cwd: cwd, rules: rules, defaultAgent: settings.defaultAgentKind
    )
    resolvedAgent = resolved.rawValue
} else {
    resolvedAgent = agent
}
// existing switch continues, now switching on resolvedAgent
```
No change to any explicit `agent:` value's behavior — `"auto"` is new, additive.

### P41 Automation change
`kouenAutomationCreate`/`Update`'s existing `agent: String?` field accepts
`"auto"` the same way. At fire time (`AutomationScheduler`, not yet read in
this pass — task-design should locate the exact fire call site), the same
`AgentRoutingResolver.resolve(cwd: automation.repoPath, ...)` call replaces
`"auto"` with a concrete `AgentKind` before spawning, mirroring the
`kouenSpawnAgent` interception exactly.

### Settings UI
New "Agent Routing Rules" section in `SettingsAgentsView.swift`, below the
existing `agentsSection`. Two sub-lists (Path Rules, Stack Rules), each row:
kind-appropriate input (glob text field / stack picker) + `AgentKind` picker +
enabled toggle + drag-to-reorder (reuses whatever list-reorder pattern the
Automation list view already uses, if any — task-design to confirm) + delete.

## Next Step
`task-design` (Dev section) — break into implementation tasks:
1. `AgentRoutingRule` + `AgentRoutingResolver` (KouenCore/Routing/)
2. `AgentRoutingRuleStore` (daemon-owned, JSON persistence)
3. `defaultAgentKind` settings field
4. MCP tools (5) + `kouenSpawnAgent` `"auto"` interception
5. Automation fire-time `"auto"` interception (locate `AutomationScheduler` fire call site first)
6. Settings UI section
7. Regression test: resolver unit tests (path-wins-over-stack, no-match-falls-to-default, disabled-rule-skipped)
