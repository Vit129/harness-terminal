# Graph Summary — kouen-terminal
_Auto-generated from GRAPH_REPORT.md · do not edit manually_
_Regen: `graphify update .`_

## Summary
- 15355 nodes · 35361 edges · 3153 communities (970 shown, 2183 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 3954 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output


## Graph Freshness
- Built from commit: `d87f8ab9`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).


## God Nodes (most connected - your core abstractions)
1. `SurfaceRegistry` - 195 edges
2. `IPCRequest` - 186 edges
3. `SessionEditor` - 180 edges
4. `DaemonClient` - 167 edges
5. `AnyCodable` - 158 edges
6. `SessionCoordinator` - 131 edges
7. `KouenTerminalSurfaceView` - 125 edges
8. `JSONRPCError` - 122 edges
9. `KouenPaths` - 119 edges
10. `AgentKind` - 108 edges


## Cross-Cutting Nodes (span the most distinct areas of the codebase)
A high-degree node isn't always architecturally central - a widely-used
utility/config file can rack up more edges than a real coupler while only
ever touching one area. This ranks by how many DIFFERENT communities a
node's neighbors span, not by raw edge count.
1. `IPCRequest` - bridges 169 areas (186 edges)
2. `Command` - bridges 100 areas (107 edges)
3. `IPCResponse` - bridges 70 areas (91 edges)
4. `SurfaceRegistry` - bridges 60 areas (195 edges)
5. `SessionCoordinator` - bridges 60 areas (131 edges)
6. `MenuTarget` - bridges 57 areas (68 edges)
7. `KouenPaths` - bridges 56 areas (119 edges)
8. `AgentKind` - bridges 54 areas (108 edges)
9. `EngineConformanceTests` - bridges 50 areas (76 edges)

## Surprising Connections (you probably didn't know these)
- `SUI` --calls--> `Color`  [INFERRED]
  Packages/KouenOnboarding/Sources/KouenOnboarding/Design/ImmersivePalette.swift → Apps/Kouen/Sources/KouenApp/Settings/SwiftUI/SettingsColorsView.swift
- `DaemonSyncService` --calls--> `DaemonSessionService`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/DaemonSyncService.swift → Packages/KouenCore/Sources/KouenCore/IPC/DaemonSessionService.swift
- `RemoteHostsService` --calls--> `RemoteHostStore`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/RemoteHostsService.swift → Packages/KouenCore/Sources/KouenCore/Remote/RemoteHostStore.swift
- `ThemeImportController` --calls--> `ThemeFileService`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/ThemeImportController.swift → Packages/KouenTheme/Sources/KouenTheme/ThemeFileService.swift
- `WorktreeAutoIsolateService` --calls--> `WorktreeManager`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/WorktreeAutoIsolateService.swift → Packages/KouenCore/Sources/KouenCore/Worktree/WorktreeManager.swift


_Full map → GRAPH_REPORT.md · query: `graphify query "..."`_
