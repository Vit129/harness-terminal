# Graph Summary — kouen-terminal
_Auto-generated from GRAPH_REPORT.md · do not edit manually_
_Regen: `graphify update .`_

## Summary
- 15443 nodes · 37312 edges · 2139 communities (564 shown, 1575 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 5160 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output


## Graph Freshness
- Built from commit: `d1860afd`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).


## God Nodes (most connected - your core abstractions)
1. `KouenTerminalSurfaceView` - 342 edges
2. `SessionCoordinator` - 230 edges
3. `TerminalEmulator` - 229 edges
4. `SurfaceRegistry` - 200 edges
5. `IPCRequest` - 193 edges
6. `SessionEditor` - 180 edges
7. `DaemonClient` - 176 edges
8. `AnyCodable` - 167 edges
9. `SessionSnapshot` - 167 edges
10. `KouenCLI` - 161 edges


## Cross-Cutting Nodes (span the most distinct areas of the codebase)
A high-degree node isn't always architecturally central - a widely-used
utility/config file can rack up more edges than a real coupler while only
ever touching one area. This ranks by how many DIFFERENT communities a
node's neighbors span, not by raw edge count.
1. `KouenPaths` - bridges 61 areas (135 edges)
2. `SessionCoordinator` - bridges 53 areas (230 edges)
3. `SurfaceRegistry` - bridges 46 areas (200 edges)
4. `SessionSnapshot` - bridges 45 areas (167 edges)
5. `Process` - bridges 42 areas (89 edges)
6. `AgentKind` - bridges 39 areas (112 edges)
7. `KouenTerminalSurfaceView` - bridges 38 areas (342 edges)
8. `Notification` - bridges 37 areas (62 edges)
9. `IPCResponse` - bridges 35 areas (94 edges)

## Surprising Connections (you probably didn't know these)
- `DaemonSyncService` --calls--> `DaemonSessionService`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/DaemonSyncService.swift → Packages/KouenCore/Sources/KouenCore/IPC/DaemonSessionService.swift
- `RemoteHostsService` --calls--> `RemoteHostStore`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/RemoteHostsService.swift → Packages/KouenCore/Sources/KouenCore/Remote/RemoteHostStore.swift
- `.selectWorkspace(byIndex:)` --references--> `SessionSnapshot`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/SessionCoordinator.swift → Packages/KouenIPC/Sources/KouenIPC/SessionSnapshot.swift
- `ThemeImportController` --calls--> `ThemeFileService`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Services/ThemeImportController.swift → Packages/KouenTheme/Sources/KouenTheme/ThemeFileService.swift
- `.selectedHost` --references--> `RemoteHost`  [INFERRED]
  Apps/Kouen/Sources/KouenApp/Settings/SwiftUI/SettingsRemoteView.swift → Packages/KouenCore/Sources/KouenCore/Remote/RemoteHostStore.swift


_Full map → GRAPH_REPORT.md · query: `graphify query "..."`_
