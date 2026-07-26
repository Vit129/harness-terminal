# Graph Summary — kouen-terminal
_Auto-generated from GRAPH_REPORT.md · do not edit manually_
_Regen: `graphify update .`_

## Summary
- 15548 nodes · 34859 edges · 3362 communities (961 shown, 2401 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 3858 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output


## Graph Freshness
- Built from commit: `cc60fc34`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).


## God Nodes (most connected - your core abstractions)
1. `SurfaceRegistry` - 183 edges
2. `SessionEditor` - 180 edges
3. `IPCRequest` - 177 edges
4. `DaemonClient` - 166 edges
5. `AnyCodable` - 148 edges
6. `SessionCoordinator` - 127 edges
7. `KouenTerminalSurfaceView` - 125 edges
8. `JSONRPCError` - 113 edges
9. `KouenPaths` - 111 edges
10. `Command` - 107 edges


## Cross-Cutting Nodes (span the most distinct areas of the codebase)
A high-degree node isn't always architecturally central - a widely-used
utility/config file can rack up more edges than a real coupler while only
ever touching one area. This ranks by how many DIFFERENT communities a
node's neighbors span, not by raw edge count.
1. `IPCRequest` - bridges 159 areas (177 edges)
2. `Command` - bridges 100 areas (107 edges)
3. `IPCResponse` - bridges 66 areas (85 edges)
4. `SessionCoordinator` - bridges 57 areas (127 edges)
5. `MenuTarget` - bridges 55 areas (62 edges)
6. `SurfaceRegistry` - bridges 54 areas (183 edges)
7. `KouenPaths` - bridges 51 areas (111 edges)
8. `EngineConformanceTests` - bridges 50 areas (76 edges)
9. `SpecialKey` - bridges 50 areas (56 edges)

## Surprising Connections (you probably didn't know these)
- `SUI` --calls--> `Color`  [INFERRED]
  Packages/KouenOnboarding/Sources/KouenOnboarding/Design/ImmersivePalette.swift → Apps/Kouen/Sources/KouenApp/Settings/SwiftUI/SettingsColorsView.swift
- `RemoteHostsService` --calls--> `RemoteHostStore`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/RemoteHostsService.swift → Packages/KouenCore/Sources/KouenCore/Remote/RemoteHostStore.swift
- `ThemeImportController` --calls--> `ThemeFileService`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/ThemeImportController.swift → Packages/KouenTheme/Sources/KouenTheme/ThemeFileService.swift
- `WorktreeAutoIsolateService` --calls--> `WorktreeManager`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/WorktreeAutoIsolateService.swift → Packages/KouenCore/Sources/KouenCore/Worktree/WorktreeManager.swift
- `GitHubCLIClient` --calls--> `Process`  [INFERRED]
  Packages/KouenCore/Sources/KouenCore/GitHub/GitHubCLIClient.swift → Apps/Kouen/Sources/KouenApp/UI/CommandPalette/CommandPaletteController.swift


_Full map → GRAPH_REPORT.md · query: `graphify query "..."`_
