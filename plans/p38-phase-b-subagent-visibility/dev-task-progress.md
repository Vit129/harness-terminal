# P38 Phase B — Subagent Visibility — Dev Task Progress

Design: `design.md` (same folder). Source: `agent-memory/plans/p38-competitive-feature-gaps.md` Phase B.

> Rewritten 2026-07-14 after the first implementation pass (tasks 1-5 had been completed once)
> was lost to a concurrent release-session git operation on the shared working tree before commit.

## Detection core (AgentDetector, pure logic)

- [x] 1. `AgentSnapshot`: add `public var parentPID: Int32?` (optional, decodeIfPresent-safe).
- [x] 2. `AgentTableEntry`: add `MatchSource` enum (`ownProcess`/`wrapperLaunch`) + `matchSource(resolvedExecutable:arguments:)`, keep `matchesProcess` as a thin wrapper.
- [x] 3. `AgentDetector`: depth-aware descendant walk (`descendantPIDsWithDepth`), keep existing `descendantPIDs` signature delegating to it (don't break `ListeningPortScanner`).
- [x] 4. `AgentDetector`: replace single-`best` `detect()` loop with `detectAll()` — split into `resolveDetection(from:parentMap:)` (internal, pure, testable) for the wrapper-collapse + shallowest-primary + subagent-tagging logic. Fix the stale "deepest match" doc comment.
- [x] 5. `AgentDetector.scan()`: compute `AgentDetection{primary,subagents}` per surface, add `lastSubagents` store (same lock idiom as existing state), carry `lastActivityAt` forward per subagent pid, clear on `unregisterRootPID`.
- [x] 6. Unit tests in `Tests/KouenCoreTests/AgentDetectorTests.swift` via `resolveDetection`: nested same-kind match, wrapper collapse (`bun run claude`), depth tie-break determinism, primary excluded from subagents list.
- [x] 7. Gate: `swift build` + `swift test --filter AgentDetectorTests` green (15/15).

## Claude Code hook push (in-process Task subagent detection)

- [x] 8. Traced `kouen-cli notify` (`Tools/kouen/Sources/KouenCLI/KouenCLI.swift:154`) → `.notify` IPCRequest case → `SurfaceRegistry.handle`. Added new `.setSubagentHint(surfaceID:kind:active:)` case alongside it.
- [x] 9. `AgentHookInstaller`: extended `claudePayload` with `PreToolUse`(matcher `Task`)/`SubagentStop` hooks calling `kouen-cli notify --surface ... --subagent start|stop`; added both events to `managedEvents`.
- [x] 10. New IPC path wired: CLI `--subagent start|stop` → `.setSubagentHint` → `AgentDetector.registerSubagentHint`/`clearSubagentHint` → applied immediately via new `AgentDetector.mergedSubagents(forSurfaceKey:)` + `editor.setSubagents` + `commit()` (near-instant, doesn't wait for next scan tick) — also merged into `scan()`'s own subagents computation so periodic scans stay consistent. `pid: 0` sentinel for hook-sourced entries.
- [x] 11. Tests in `Tests/KouenCoreTests/AgentHookInstallerTests.swift`: 2 new tests (Task-matcher scoping + idempotent reinstall; user's own unrelated PreToolUse hook survives prune).
- [x] 12. Gate: `swift build` (KouenCLI + KouenDaemon) + `swift test --filter AgentHookInstallerTests` green (32/32, 0 regressions).

## IPC / Tab plumbing

- [x] 13. `Tab`: add `subagents: [AgentSnapshot]?` — update custom `init(from:)` and the `isStableEqual` field list.
- [x] 14. `SessionEditor`: add separate `setSubagents(_:forSurfaceKey:)`, don't fold into `setAgent`.
- [x] 15. `SurfaceRegistry.applyAgentChanges`: consume `AgentDetection{primary,subagents}`, write both onto `Tab`; also clear subagents at the dead-pane `remain-on-exit` path.
- [x] 16. `SurfaceRegistry.hasAnyPrimaryAgent()` + `AgentScanner`: adaptive cadence — 30s baseline, ~5s while ≥1 surface has a detected primary agent, back off when none remain.
- [x] 17. Tests: `Tab` Codable round-trip (old-JSON-without-subagents still decodes), `SurfaceRegistryTests` case that `applyAgentChanges` with subagents lands in the snapshot + bumps revision. Also had to update 5 pre-existing `applyAgentChanges` call sites (signature changed from bare `AgentSnapshot?` to `AgentDetection`).
- [x] 18. Gate: `swift build` (KouenDaemon) + `swift test --filter "AgentDetectorTests|TabAlertTests|SurfaceRegistryTests"` green (55/55, 3 skipped live-daemon tests unrelated). `Tests/robot/run.sh` deferred to full B-E gate (task 22).

## Client UI indicator

- [x] 19. ~~`AgentChipView` (`KouenDesign.swift`): stacked "+N" badge variant~~ — **corrected mid-task**: `AgentChipView` is dead code (zero callers anywhere in the app). The real tab-chip/sidebar-chip rendering is inline SwiftUI (`TerminalTabBarView.swift`, `SidebarSessionListView.swift`), not this AppKit class. Reverted the AgentChipView edit; badge built directly in the two real SwiftUI sites instead (see 20).
- [x] 20. Badge built inline as a SwiftUI `ZStack(alignment: .bottomTrailing)` "+N" circle over the existing agent icon in both `TerminalTabBarView.swift` (tab bar chip, ~line 337) and `SidebarSessionListView.swift` (sidebar row icon, ~line 226).
- [x] 21. Tooltip via `.help(...)`: kind + pid-or-"hook" (pid==0 sentinel) + elapsed seconds since first seen, one `subagentTooltip(kind:subagents:)` helper per file (matches the existing per-file `agentColor(for:)` precedent — not shared, small enough not to warrant a shared module).
- [x] 22. Full gate: `swift build --product Kouen` green + `swift test --filter "AgentDetectorTests|AgentHookInstallerTests|TabAlertTests|SurfaceRegistryTests"` green (87/87, 3 skipped live-daemon) + `Tests/robot/run.sh` green (26/26, no regression on Phase A's guards).
- [x] 23. ~~Live check (required, not optional)~~ — **SKIPPED, closed without live verification per explicit user decision 2026-07-16.** Build/test/robot green (87/87 / 26/26) stands as the only verification; proc-scan/hook/wrapper-collapse behavior has NOT been confirmed against a real `make preview` workspace. Risk accepted by user, not verified by agent.

## Summary

Completed: 23, Remaining: 0 (live check closed unverified — see task 23 note)

## Status: Rewritten 2026-07-14 after original implementation (tasks 1-5) was lost to a concurrent git operation before commit. Closed 2026-07-16 on user instruction, live check skipped.
