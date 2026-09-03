# Graph Report - kouen-terminal  (2026-09-03)

## Corpus Check
- 785 files · ~826,717 words
- Verdict: corpus is large enough that graph structure adds value.

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
10. `TerminalEmulator` - bridges 34 areas (229 edges)

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

## Import Cycles
- None detected.

## Communities (2139 total, 1575 thin omitted)

### Community 0 - "CodingKey"
Cohesion: 0.12
Nodes (6): GitPanelView, .isHidden, Any, DispatchWorkItem, NSMenuItem, NSGestureRecognizer

### Community 1 - "callingPaneTarget"
Cohesion: 0.15
Nodes (11): TerminalDamage, RenderColor, MetalRendererTests, RenderedFixture, Bool, MTLTexture, StaticString, String (+3 more)

### Community 2 - ".handleNormal"
Cohesion: 0.20
Nodes (7): Recipe, RecipesStore, Bool, String, URL, UUID, RecipesStoreTests

### Community 4 - "EngineConformanceTests"
Cohesion: 0.10
Nodes (17): DaemonClient, ClaudeCodeHarnessIPCTests, String, URL, DaemonContentionTests, String, URL, DaemonRoundTripTests (+9 more)

### Community 5 - "IPCRequest"
Cohesion: 0.07
Nodes (22): DecodedReplyFrame, output, reply, DecodedRequestFrame, input, request, FrameError, tooLarge (+14 more)

### Community 6 - "AgentNotchRootView"
Cohesion: 0.12
Nodes (22): AnyTransition, Color, .hexString, AgentNotchRootView, .bottomRadius, .closedAccessibilityLabel, .closedTransition, .closedView (+14 more)

### Community 7 - "Command"
Cohesion: 0.09
Nodes (31): AppEnum, AppIntent, AppIntents, GetTerminalOutputIntent, KouenIntentError, .localizedStringResource, noActivePane, workspaceNotFound (+23 more)

### Community 8 - "LSPMessage"
Cohesion: 0.11
Nodes (12): .addSurface(tabID:paneID:), .tab(containingPaneID:), .tab(forSurfaceKey:), .tabIndex(surfaceKey:), .tabIndex(workspaceID:tabID:), Bool, Date, SessionID (+4 more)

### Community 9 - "TerminalEmulator"
Cohesion: 0.10
Nodes (13): PerformanceBenchmarks, SurfaceMainThreadStallSample, SurfaceOffMainStallSample, Bool, Data, Double, MTLDevice, MTLTexture (+5 more)

### Community 10 - "PerformanceBenchmarks"
Cohesion: 0.13
Nodes (15): IndexingIterator, LayoutTemplate, surfaceID, .addSurface(to:paneID:surfaceID:cwd:), .split(node:targetPaneID:direction:paneCount:before:), .split(node:targetPaneID:with:direction:beforeTarget:), .surfaceID(forPaneID:in:), Command (+7 more)

### Community 11 - "GitPanelView.swift"
Cohesion: 0.08
Nodes (11): SessionCoordinator, Bool, Double, PaneID, PaneNode, SplitDirection, String, SurfaceID (+3 more)

### Community 13 - "KittyKeyboardTests"
Cohesion: 0.29
Nodes (4): KeyRecorderViewTests, NSEvent, String, UInt16

### Community 14 - "VTParser"
Cohesion: 0.22
Nodes (5): Data, UInt8, VTParser, .feed(_:), VTParserHandler

### Community 15 - "HarnessTerminalSurfaceView"
Cohesion: 0.10
Nodes (15): StatusLineView, .init(coder:), CGFloat, FormatColor, Never, NSAttributedString, NSCoder, NSColor (+7 more)

### Community 16 - ".applyPreedit"
Cohesion: 0.05
Nodes (43): Decodable, AssistantLine, ClaudeCodeHarness, Content, Message, Profile, edit, readonly (+35 more)

### Community 17 - "MetalRendererTests"
Cohesion: 0.10
Nodes (18): TabContextCommand, close, closeOthers, rename, splitHorizontal, splitVertical, togglePersistent, ScrollbackFile (+10 more)

### Community 18 - "HarnessUILibrary"
Cohesion: 0.08
Nodes (30): DaemonSubscription, .start(onData:onEnd:buffered:), .start(onResponse:onEnd:), Bool, Data, Int32, String, TimeInterval (+22 more)

### Community 19 - "SpecialKey"
Cohesion: 0.08
Nodes (23): .lspPosition(characterOffset:), CodingKeys, error, id, jsonrpc, method, params, result (+15 more)

### Community 20 - "code:block1 (Agent shell process)"
Cohesion: 0.24
Nodes (5): KouenBrowserTools, Bool, Double, String, TimeInterval

### Community 21 - "HarnessTerminalSurfaceView"
Cohesion: 0.06
Nodes (17): KouenTerminalKit, Bool, NSEvent, Selector, UInt8, Bool, NSEvent, ViInputMode (+9 more)

### Community 22 - "CopyModeAction"
Cohesion: 0.10
Nodes (11): HistoryLine, ImagePlacement, RewrapResult, SavedCursor, Bool, String, TerminalCellWidth, TerminalGridCell (+3 more)

### Community 23 - "SplitPaneCoordinator"
Cohesion: 0.10
Nodes (23): OptionStore, OptionStore.Value, .boolValue, .intValue, .statusLineCount, .stringValue, Scope, global (+15 more)

### Community 24 - ".request"
Cohesion: 0.11
Nodes (10): DaemonSyncService, .logIfFailed(_:), .request(_:), .sync(metadataOnly:), Bool, Never, Task, Void (+2 more)

### Community 25 - "WorktreeManager"
Cohesion: 0.20
Nodes (5): DaemonCommandExecutor, Command, SurfaceRegistry, Bool, Set

### Community 26 - "Harness tmux-style capabilities"
Cohesion: 0.15
Nodes (10): ActivePaneService, .surfaceID(forPane:in:), .surfaceID(forPaneID:in:), Bool, PaneID, PaneNode, Set, SurfaceID (+2 more)

### Community 27 - "RGBColor"
Cohesion: 0.15
Nodes (6): RenderScheduler, .hasPendingWork, Bool, Void, RenderSchedulerTests, Bool

### Community 28 - ".parse"
Cohesion: 0.19
Nodes (6): ParsedShortcut, .displayString, PrefixKeymap, Any, NSEvent, TimeInterval

### Community 30 - "Notification"
Cohesion: 0.12
Nodes (9): Bool, String, UInt8, UnsafeBufferPointer, TerminalEmulator, .blocks, .captureLines(fromLine:toLine:), .onResponse (+1 more)

### Community 31 - "Sendable"
Cohesion: 0.13
Nodes (13): CommandPromptController, .historyEntries, .historyURL, KeyablePanel, .canBecomeKey, Bool, NSControl, NSPanel (+5 more)

### Community 32 - ".addTab"
Cohesion: 0.09
Nodes (9): CGFloat, NSEvent, CGFloat, CGRect, NSEvent, NSPoint, Range, String (+1 more)

### Community 33 - "Equatable"
Cohesion: 0.12
Nodes (14): DisplayMessage, MainExecutor, RunShell, .loginShell, Bool, Command, MainActor, PaneID (+6 more)

### Community 34 - "DaemonClient"
Cohesion: 0.15
Nodes (10): LSPServerConfiguration, LSPServerRegistry, LSPSettings, Bool, FileManager, String, URL, LSPServerRegistryTests (+2 more)

### Community 35 - "MenuTarget"
Cohesion: 0.17
Nodes (3): TerminalGridCell, TerminalGridSnapshot, ThaiCombiningMarkTests

### Community 36 - "code:bash (harness chat "Use the project map first, then inspect this r)"
Cohesion: 0.14
Nodes (28): Cleanup Test Repo, Close Isolated Session Keeps Dirty Worktree, Close Isolated Session Removes Clean Worktree, Close One Isolated Does Not Affect Another, Close Session With Split Panes Removes Worktree, Create Isolated Session, Create Isolated Session Via CLI, Get Active Pane (+20 more)

### Community 37 - "String"
Cohesion: 0.08
Nodes (24): DragDiagnostics, DispatchSourceTimer, String, PaneDragController, .isDragging, Any, Bool, NSEvent (+16 more)

### Community 39 - "TerminalColorGamut"
Cohesion: 0.15
Nodes (14): NWEndpoint, NWListener, ConnectionState, .authorized, .browserPaneID, .deviceID, .snapshotSubscription, .subscription (+6 more)

### Community 40 - "HarnessSettings"
Cohesion: 0.07
Nodes (18): DisplayWidth, String, Unicode, ReleaseNotes, Section, String, Run, Data (+10 more)

### Community 41 - "CodingKeys"
Cohesion: 0.07
Nodes (31): ClientRecord, CountBox, DaemonError, alreadyRunning, bindFailed, .description, listenFailed, socketFailed (+23 more)

### Community 42 - "HarnessSidebarPanelViewController.swift"
Cohesion: 0.14
Nodes (18): CommandParseError, .description, emptyInput, expectedCommand, invalidArgument, missingArgument, missingFlag, unknownCommand (+10 more)

### Community 43 - "RenderSchedulerTests"
Cohesion: 0.16
Nodes (8): .removeWorktreeAction(path:), GitResult, Bool, String, ValidateOutcome, WorktreeEntry, CoreServices, GitPanelViewWorktreeParsingTests

### Community 44 - "HarnessOverlayBackground"
Cohesion: 0.04
Nodes (45): Already portable or mostly portable, Build matrix, Competitive Landscape (research 2026-07-04), Current Architecture Fit, D1: Transport model (P0 gate), D2: Renderer reuse boundary (P0 gate), D3: Local terminal support (explicitly deferred), Design: mobile session switcher (2026-07-04/05, recovered 2026-07-06) (+37 more)

### Community 45 - "HarnessTerminalSurfaceView.swift"
Cohesion: 0.16
Nodes (10): Process, KouenPaths, SSHTunnelManager, .init(makeTunnelProcess:reachabilityProbe:), Bool, URL, Tunnel, SSHTunnelManagerTests (+2 more)

### Community 46 - ".buildCommand"
Cohesion: 0.07
Nodes (29): Endpoint, EndpointError, connectionFailed, .description, notYetSupported, pathTooLong, String, EndpointConnector (+21 more)

### Community 47 - ".normalizedKey"
Cohesion: 0.10
Nodes (19): Array, GroupHeaderRow, .body, PickerItemRow, .badgeText, .body, .iconName, .subtitle (+11 more)

### Community 48 - "HookEvent"
Cohesion: 0.25
Nodes (8): Executor, Hook, HookEvent, HookRegistry, Bool, Command, URL, UUID

### Community 49 - "DaemonServer"
Cohesion: 0.13
Nodes (4): CommandIPCTranslatorTests, Bool, PaneID, TabID

### Community 51 - ".keyEvent"
Cohesion: 0.14
Nodes (21): CompositorPane, GridCompositor, .render(panes:status:statusSegments:), .render(panes:statusLines:), RenderCell, .cluster, .init(_:), .init(codepoint:combining0:combining1:fg:bg:underlineColor:bold:dim:italic:underline:blink:inverse:invisible:strikethrough:overline:) (+13 more)

### Community 54 - "HarnessSplitView"
Cohesion: 0.05
Nodes (44): AgentBridge, AgentTarget, Bool, String, SurfaceID, .onCurrentCWD, .onCurrentFile, LinePos (+36 more)

### Community 55 - "TabCell"
Cohesion: 0.18
Nodes (6): AnyCodable, JSONRPCError, Bool, Int32, String, ToolRegistry

### Community 56 - "NSPanel"
Cohesion: 0.16
Nodes (10): QuickTerminalController, QuickTerminalPanelDelegate, Any, Bool, NSEvent, NSPanel, NSRect, NSScreen (+2 more)

### Community 57 - "BellScanState"
Cohesion: 0.14
Nodes (11): DaemonLifecycle, PriorInstanceDecision, proceed, refuse, stale, Bool, pid_t, String (+3 more)

### Community 58 - "PasteBufferStore"
Cohesion: 0.11
Nodes (32): MTLClearColor, MTLCommandBuffer, MTLRenderCommandEncoder, BgInstance, CursorCacheKey, .invertsGlyph, DecoInstance, EncodedFrameInstances (+24 more)

### Community 59 - "3.2 สิ่งที่ implement แล้ว"
Cohesion: 0.08
Nodes (13): SessionGroup, String, KouenSidebarPanelViewController, CGFloat, NSMenuItem, NSView, SessionGroup, String (+5 more)

### Community 60 - "ViEngine"
Cohesion: 0.15
Nodes (5): SessionPersistenceTests, Bool, String, TabID, URL

### Community 61 - "FrecencyDirectoryStore"
Cohesion: 0.14
Nodes (20): ComposedCell, .asGridCell, .init(_:), .init(codepoint:fg:bg:underlineColor:bold:dim:italic:underline:blink:inverse:invisible:strikethrough:overline:), .scalar, .sgr, CompositorPane, GridCompositor (+12 more)

### Community 62 - "ComposedCell"
Cohesion: 0.27
Nodes (4): SessionID, String, TabID, UInt16

### Community 63 - "HarnessCLI+Server.swift"
Cohesion: 0.14
Nodes (11): Buffer, .preview, Configuration, PasteBufferStore, Bool, Data, Date, String (+3 more)

### Community 64 - ".text"
Cohesion: 0.10
Nodes (3): Bool, String, UUID

### Community 65 - "PrefixKeymap"
Cohesion: 0.08
Nodes (23): 1. Create an Isolated Git Worktree, 1. Overview & Architecture Principle, 1. Transition Status, 2. Reuse Existing Worker Session & Worktree, 2. Roles & Vocabulary, 2. Spawn Worker with Atomic Prompt Delivery, 3. Dispatch Fix Prompt, 3. Step-by-Step Orchestration Lifecycle (+15 more)

### Community 66 - "ShellIntegration"
Cohesion: 0.12
Nodes (5): KouenThemeCatalog, .allThemes, String, KouenThemeCatalogTests, ThemeDiagnosticsTests

### Community 67 - "String"
Cohesion: 0.15
Nodes (15): AgentHookInstaller, .antigravityPayload, .claudePayload, .codexPayload, .cursorPayload, .grokPayload, .hermesHookBody, .openClawHookBody (+7 more)

### Community 68 - "Completed Plans Archive"
Cohesion: 0.26
Nodes (3): BellScanTests, Bool, UInt8

### Community 69 - ".compose"
Cohesion: 0.15
Nodes (3): .activePaneIsDetached, SurfaceID, TerminalPaneRegistryAccess

### Community 70 - "worktree_isolation_cli.robot"
Cohesion: 0.14
Nodes (18): RepoGitMetadata, SidebarListModel, SidebarSessionRow, divider, groupHeader, .id, session, worktree (+10 more)

### Community 71 - "ImportedTerminalConfig"
Cohesion: 0.06
Nodes (21): KouenUILibrary, KouenUILibrary — Robot Framework keyword library for Kouen terminal automation., Verify a board column exists using kouen CLI., Run a kouen CLI command and assert exit code 0., Run kouen view and assert output contains substring., Type a string of text into the focused element via osascript keystroke., Wait for UI to settle., Verify app is still running (no crash report in last 10s). (+13 more)

### Community 72 - "XCTestCase"
Cohesion: 0.12
Nodes (13): CornerInfo, KouenSplitView, .dividerColor, .dividerThickness, DispatchWorkItem, Double, NSColor, NSRect (+5 more)

### Community 73 - "README.md"
Cohesion: 0.50
Nodes (3): Hermes → Kouen, One-line install, Required: approve the hook

### Community 75 - "OptionStore"
Cohesion: 0.09
Nodes (20): CaseIterable, ExperienceMode, agent, .displayName, .foregroundsAgents, full, .notchEnabledByDefault, persistent (+12 more)

### Community 76 - ".parse"
Cohesion: 0.13
Nodes (16): Codable, Equatable, ExpressibleByStringLiteral, PaneListRow, SessionListRow, SnapshotQueryFormatter, Bool, SessionGroup (+8 more)

### Community 77 - "TerminalProtocolCompatibilityTests"
Cohesion: 0.23
Nodes (6): EnvironmentStore, Persisted, String, URL, EnvironmentStoreTests, URL

### Community 79 - "HarnessDesign"
Cohesion: 0.07
Nodes (33): AgentRow, AgentIconArt, AgentVectorIcon, Bool, CGSize, String, AgentIconRenderer, Scanner (+25 more)

### Community 80 - "Agent handbook — Harness (extended reference)"
Cohesion: 0.25
Nodes (8): Agent Memory, Build / Test / Run, Graphify, graphify, kouen-terminal — Claude Instructions, Non-obvious Constraints, Session Start, Skills

### Community 81 - "DaemonSubscription"
Cohesion: 0.13
Nodes (15): InstallResult, Profile, .id, Shell, bash, fish, .profilePath, zsh (+7 more)

### Community 82 - ".firstMatch"
Cohesion: 0.09
Nodes (10): .receive(_:), DispatchSemaphore, FluidityBenchmarks, NSWindow, String, UInt64, KouenTerminalSurfaceWorkerTests, Bool (+2 more)

### Community 83 - "LSPClient"
Cohesion: 0.18
Nodes (7): AsyncCLIResultBox, LSPDefinitionPayload, LSPDiagnosticsPayload, LSPStatusPayload, Error, Result, String

### Community 84 - "LSPDiagnostic"
Cohesion: 0.06
Nodes (32): SplitPaneCoordinator, .surfaceID(forPane:in:), .surfaceID(forPaneID:in:), Bool, PaneID, PaneNode, SessionID, SplitDirection (+24 more)

### Community 85 - "TerminalGridCell"
Cohesion: 0.09
Nodes (24): LSPFileSession, Never, String, Task, URL, Void, Error, object (+16 more)

### Community 86 - "HarnessPaths"
Cohesion: 0.08
Nodes (18): String, WorkbenchMRU, FileEditorView, .acceptsFirstResponder, .activeDiagnostics, .init(coder:), .init(frame:), .isShowingSyntaxView (+10 more)

### Community 87 - "SessionCoordinator"
Cohesion: 0.14
Nodes (14): FindWindowMatcher, SearchScope, all, none, only, Bool, SessionGroup, SessionID (+6 more)

### Community 88 - "Harness as a terminal multiplexer"
Cohesion: 0.14
Nodes (19): BannerShortcut, .init(from:), .init(key:description:showInBanner:), BannerShortcutRegistry, .bannerShortcuts, CodingKeys, description, key (+11 more)

### Community 89 - ".cursorPos"
Cohesion: 0.16
Nodes (4): hooks, AgentHookInstallerTests, String, URL

### Community 90 - "Zombie View Crashes on macOS 26.5 + Swift 6.3.2"
Cohesion: 0.09
Nodes (12): CKouenSys, pipe, termios, AttachClient, Configuration, LiveSession, Bool, Data (+4 more)

### Community 91 - "TerminalModes"
Cohesion: 0.08
Nodes (13): EditorDividerView, .init(coder:), PaneDragGripView, .init(coder:), PaneHoverButton, PaneSplitButtonsView, .init(coder:), .init(tabID:paneID:) (+5 more)

### Community 92 - "P2 — Async IPC Refactor: Design Document"
Cohesion: 0.13
Nodes (14): AgentTable, AgentTableEntry, MatchSource, ownProcess, wrapperLaunch, RawMatch, Bool, Set (+6 more)

### Community 93 - "code:bash (# Terminal 1: Create workspace with long-running job)"
Cohesion: 0.12
Nodes (6): Int, SemanticMark, ClosedRange, Range, .cursorVisible, .markRowsDirty(_:)

### Community 94 - "AttachInputBatcher"
Cohesion: 0.19
Nodes (9): C, AttachInputBatcher, .hasPending, Outcome, Bool, Data, UInt8, AttachInputBatcherTests (+1 more)

### Community 95 - "shim.c"
Cohesion: 0.13
Nodes (17): DirectoryItemRow, .body, DirectoryPanel, .canBecomeKey, DirectoryPickerController, DirectoryPickerModel, DirectoryPickerView, .body (+9 more)

### Community 96 - "Harness Usage"
Cohesion: 0.17
Nodes (9): PaneStyle, .isEmpty, PaneStyleSet, .init(window:windowActive:pane:paneActive:), .isEmpty, Bool, FormatColor, String (+1 more)

### Community 97 - "PaneContainerView"
Cohesion: 0.25
Nodes (7): skipUnlessLiveDaemonTests(), Bool, Set, String, TimeInterval, URL, VersionBannerTests

### Community 98 - "4. Technical Architecture"
Cohesion: 0.12
Nodes (12): BrowserIntegrationController, NSView, PaneID, HitTestPassthroughView, PaneContainerView, .init(node:cwd:themeName:existingHosts:existingBrowserPanes:), .init(paneID:), NSPoint (+4 more)

### Community 99 - ".dispatch"
Cohesion: 0.12
Nodes (23): TerminalColorGamut, auto, displayP3, sRGB, TerminalColorRenderingMode, accurate, vivid, .init(_:gamut:alpha:) (+15 more)

### Community 100 - "ScriptRuntime.swift"
Cohesion: 0.09
Nodes (18): requestFailed, FileHandle, LSPMessage, notification, request, response, Decoder, Encoder (+10 more)

### Community 101 - "Session Grouping and Split Session Plan"
Cohesion: 0.12
Nodes (22): .color, TaskSummary.Status, .columnKind, .sessionBoardStatus, BoardCard, BoardColumn, .name, BoardColumnKind (+14 more)

### Community 102 - "DaemonLauncher"
Cohesion: 0.09
Nodes (23): CopyModeMatch, CopyModeSearch, CopyModeSelectionMode, block, char, line, none, CopyModeSideEffect (+15 more)

### Community 104 - "Recipe"
Cohesion: 0.10
Nodes (25): Bool, UInt8, TerminalCellWidth, normal, spacerTail, wide, TerminalCursor, TerminalCursorShape (+17 more)

### Community 105 - "Changelog"
Cohesion: 0.19
Nodes (7): AgentListFormatter, Date, String, AgentListFormatterTests, Bool, Date, String

### Community 106 - "domain-design.md"
Cohesion: 0.10
Nodes (26): PaneRef, bottom, byID, byIndex, last, left, next, previous (+18 more)

### Community 107 - "AgentNotchViewModel"
Cohesion: 0.10
Nodes (17): BoxDrawing, Kind, arms, dashH, dashV, halfDown, halfLeft, halfRight (+9 more)

### Community 108 - ".resolve"
Cohesion: 0.07
Nodes (13): CLIInstallLocator, DetachKeys, absent, invalid, parsed, OptionalUUID, absent, dangling (+5 more)

### Community 109 - "DamageTrackingTests"
Cohesion: 0.13
Nodes (8): SGRMouse, SGRMouseEvent, Bool, PaneRect, UInt8, SGRMouseTests, String, UInt8

### Community 110 - "SoftIconButton"
Cohesion: 0.18
Nodes (6): CopyModeReducerTests, FakeGrid, .totalLines, Set, String, TerminalGridCell

### Community 111 - "code:text (:workbench start swift)"
Cohesion: 0.12
Nodes (11): CGImage, data, DecodedImage, .byteCount, ImageLimits, Bool, UInt8, ImageDecoder (+3 more)

### Community 112 - ".makeSnapshot"
Cohesion: 0.18
Nodes (7): KeyTokenParser, Bool, Data, String, .remaining, KeyTokenParserTests, Phase6KeysTests

### Community 113 - "HarnessGridTerminal"
Cohesion: 0.13
Nodes (21): .windowSection, KouenSettings, .init(fontSize:fontFamily:defaultShell:defaultCWD:transparentTitlebar:sidebarVisible:sidebarOnRight:sidebarCollapsedOnLaunch:sidebarWidth:restoreWindowSize:backgroundOpacity:backgroundBlur:windowPaddingX:windowPaddingY:customBackgroundHex:customForegroundHex:customCursorHex:importedConfigSignature:prefixKey:scrollbackLines:cursorStyle:cursorBlink:copyOnSelect:selectionBackgroundHex:selectionForegroundHex:boldColorHex:cursorTextHex:paletteHex:agentColorOverrides:defaultAgentKind:dividerHex:statusLineHex:windowBorderHex:windowBorderOpacity:systemNotificationsEnabled:notificationSoundEnabled:notchVisibilityMode:notchOpenOnHover:colorRendering:colorGamut:textRendering:vividColors:linearBlending:applyThemeToTerminalOutput:ligatures:offMainParserFramePipeline:liveResizeReflow:mobileBridgeEnabled:showPromptGutter:showStatusLine:experienceMode:kouenControlsEnabled:prefixKeyEnabled:statusLineEnabled:resizeOverlay:resizeOverlayPosition:windowPaddingBalance:minimumContrast:lightThemeName:darkThemeName:lightThemeOpacity:darkThemeOpacity:pasteProtection:commandFinishedThresholdSeconds:notificationEvents:boldIsBright:lspAutoStart:lspServers:fileClickAction:claudeAPIKey:inlineAICompletion:terminalShaderEffect:browserHomePage:), .init(from:), ResizeOverlayMode, afterFirst, always, never (+13 more)

### Community 114 - ".firstWaitingTab"
Cohesion: 0.14
Nodes (9): ImportedTerminalConfig, .hasTerminalColorOverrides, .signature, Bool, Double, Float, String, TerminalConfigImporter (+1 more)

### Community 115 - ".encode"
Cohesion: 0.21
Nodes (4): CommandTarget, String, UUID, TargetSpecTests

### Community 116 - "SessionGroup"
Cohesion: 0.20
Nodes (7): AgentRoutingRuleStore, Bool, String, URL, UUID, AgentRoutingRuleStoreTests, URL

### Community 117 - "PaneNode"
Cohesion: 0.10
Nodes (11): NotificationCoordinator, Bool, Date, Set, String, SurfaceID, Tab, TabID (+3 more)

### Community 118 - "WorkspaceFileTreeView"
Cohesion: 0.09
Nodes (15): SessionID, ActiveTabCloseDisposition, session, tab, window, workspace, CloseConfirmationCopy, SessionLifecycleService (+7 more)

### Community 119 - "Harness command reference"
Cohesion: 0.06
Nodes (29): Attaching from a plain terminal, Bindings, Board and attention, Buffers (paste store), Composition, Errors and LSP, File navigation, Hooks (+21 more)

### Community 122 - "ViEngine"
Cohesion: 0.19
Nodes (8): Range, String, TerminalGridCell, TerminalBufferMatch, TerminalBufferSearch, String, TerminalGridCell, TerminalBufferSearchTests

### Community 123 - "Pipe"
Cohesion: 0.18
Nodes (9): InstallChoice, cancel, install, installAndApply, Error, String, URL, ThemeImportController (+1 more)

### Community 124 - "String"
Cohesion: 0.30
Nodes (9): .encode(text:shifted:modifiers:event:associatedText:modes:), KeyEventType, press, release, `repeat`, KeyModifiers, Character, String (+1 more)

### Community 125 - "HistoryRingBuffer"
Cohesion: 0.11
Nodes (10): ContiguousArray, IteratorProtocol, HistoryRingBuffer, .isEmpty, Iterator, Bool, Element, S (+2 more)

### Community 126 - ".path"
Cohesion: 0.08
Nodes (29): AgentArt, AgentMark, .body, AgentMarkShape, AgentVectorIcon, Scanner, .atEnd, SVGPath (+21 more)

### Community 127 - "GlyphAtlas"
Cohesion: 0.10
Nodes (24): Hashable, AtlasEntry, ClusterGlyphKey, GlyphAtlas, .entry(for:), .entry(forCluster:bold:italic:), .entry(forShaped:font:), .stats (+16 more)

### Community 128 - "code:block1 (SessionCoordinator.snapshot ──┐)"
Cohesion: 0.13
Nodes (16): .agentInfo(forWorktreePath:), AgentNotchPeekEvent, Reason, errored, finished, needsInput, RowState, Bool (+8 more)

### Community 129 - "SwiftUI"
Cohesion: 0.25
Nodes (5): FilePreviewCoordinator, FileTabID, NSView, SplitDirection, String

### Community 131 - ".install"
Cohesion: 0.13
Nodes (14): PickerItem, .groupLabel, historyBlock, .id, recipe, .searchableText, RecipePickerModel, NSWindow (+6 more)

### Community 132 - "AgentHookInstaller"
Cohesion: 0.11
Nodes (13): CommandIPCTranslator, CommandTranslation, clientLocal, requests, unresolved, Command, PaneID, PaneLeaf (+5 more)

### Community 133 - ".load"
Cohesion: 0.26
Nodes (4): NodeRow, .body, Error, String

### Community 134 - "code:js (// ~/.config/harness/init.js)"
Cohesion: 0.17
Nodes (6): FloatingPaneController, Any, Bool, NSEvent, NSObjectProtocol, NSPanel

### Community 135 - "CommandTarget"
Cohesion: 0.13
Nodes (3): KittyKeyboardTests, String, UInt8

### Community 136 - ".startWatching"
Cohesion: 0.12
Nodes (29): BrowserSnapshotAck, BrowserCookie, BrowserElement, BrowserElementBounds, BrowserNetworkEntry, BrowserResponsePayload, cookies, error (+21 more)

### Community 137 - "ActivePaneService"
Cohesion: 0.12
Nodes (13): constantTimeEquals(), PairedDeviceRecord, PairedDeviceStore, SHA256Mini, Bool, Date, String, TimeInterval (+5 more)

### Community 138 - "User Story Mapping (MANDATORY)"
Cohesion: 0.23
Nodes (5): ListeningPortScanner, Int32, Set, String, ListeningPortScannerTests

### Community 139 - "แผนงานการสร้างระบบพรีวิวและแสดงผลไฟล์ (File Viewer & Preview Integration Plan)"
Cohesion: 0.12
Nodes (14): KeyRecorderView, .acceptsFirstResponder, .init(coder:), .init(initial:), .isRecording, .recording, Any, Bool (+6 more)

### Community 141 - ".testPaneLeafLegacyDecodeBackfillsSurfaceTabs"
Cohesion: 0.14
Nodes (15): Phase, daemonConnected, firstDrawablePresented, firstSnapshot, firstSurfaceAttached, firstWindow, launchStart, StartupMetrics (+7 more)

### Community 142 - "CopyModeGridSource"
Cohesion: 0.32
Nodes (4): PaneID, SessionGroup, Tab, first

### Community 143 - "How to use Harness from the terminal only (no GUI)"
Cohesion: 0.11
Nodes (19): String, SidebarBadgeLabel, .body, SidebarDividerRow, .body, SidebarGroupHeaderRow, .body, SidebarSessionItemRow (+11 more)

### Community 144 - "PaneStyleSet"
Cohesion: 0.19
Nodes (10): CheckResult, GitCloneUpdateChecker, .dismissFileURL, RemoteVersion, Bool, Data, Pipe, String (+2 more)

### Community 146 - "DecodedImage"
Cohesion: 0.34
Nodes (3): TaskStore, URL, TaskStoreTests

### Community 147 - "FileTreeWatcher"
Cohesion: 0.21
Nodes (8): BranchSwitchHelper, FileTreeNode, FileTreeSwiftUIView, .body, .scanOptions, Notification.Name, Bool, NSMenuItem

### Community 148 - "TriState"
Cohesion: 0.10
Nodes (14): NSEvent, BoardCardView, .init(card:), .init(coder:), .onDismiss, BoardViewController, FlippedView, .isFlipped (+6 more)

### Community 149 - "EnvironmentStore"
Cohesion: 0.17
Nodes (9): DaemonLauncher, Bool, Double, Int32, MainActor, String, TimeInterval, UInt16 (+1 more)

### Community 150 - "HarnessDaemonToolsTests"
Cohesion: 0.28
Nodes (3): KouenDaemonToolsTests, String, URL

### Community 151 - ".evaluate"
Cohesion: 0.15
Nodes (7): FileManager, String, URL, ThemeFileService, String, URL, ThemeFileServiceTests

### Community 153 - "What You Must Do When Invoked"
Cohesion: 0.12
Nodes (10): KouenCLITests, URL, KouenFilePreviewLoader, KouenViewError, binaryOrUnsupportedEncoding, missingPath, tooLarge, unreadable (+2 more)

### Community 154 - "LiveResizeTests"
Cohesion: 0.27
Nodes (8): Date, String, TerminalBlock, TerminalBlockStore, .block(atPromptLine:), .block(id:), .lastFinishedBlock, .block(id:)

### Community 155 - "Int"
Cohesion: 0.14
Nodes (11): FileFuzzyMatcher, FuzzyPathResolution, ambiguous, none, unique, FuzzyPathResolver, Bool, Character (+3 more)

### Community 156 - "ThaiCombiningMarkTests"
Cohesion: 0.20
Nodes (9): NotificationDropdownPanelView, .acceptsFirstResponder, .cornerConfiguration, .init(entries:onSelect:onClearAll:onDismiss:), Bool, CGFloat, NSScrollView, NSViewCornerConfiguration (+1 more)

### Community 158 - "Harness Terminal — IDE Sidebar Feature Branch"
Cohesion: 0.16
Nodes (11): FileNode, GitStatusType, added, deleted, modified, renamed, unmodified, untracked (+3 more)

### Community 159 - "MatchCategory"
Cohesion: 0.14
Nodes (14): .agentColorBinding, colors, ANSIPalette, CellColorResolver, MochaTheme, ResolvedCellColors, .init(hex:), .init(red:green:blue:alpha:) (+6 more)

### Community 160 - "AmbientBackground"
Cohesion: 0.13
Nodes (17): FileEditorTabBarBody, .body, FileEditorTabBarModel, FileEditorTabBarView, .init(coder:), .init(frame:), .onClose, .onSelect (+9 more)

### Community 161 - "What You Must Do When Invoked"
Cohesion: 0.13
Nodes (11): PairingBox, .current, .isLockedOut, PendingPairing, Date, TimeInterval, TokenCheck, accepted (+3 more)

### Community 162 - "TerminalFindBar"
Cohesion: 0.10
Nodes (17): NSSearchFieldDelegate, Bool, CGFloat, NSButton, NSCoder, NSControl, NSEvent, NSImage (+9 more)

### Community 163 - "Workspace"
Cohesion: 0.32
Nodes (3): BinaryInstallerVersionTests, String, URL

### Community 164 - "CommandPromptController"
Cohesion: 0.25
Nodes (10): CIRun, GitHubCLIClient, IssueInfo, MergeResult, PRInfo, PRState, closed, open (+2 more)

### Community 166 - "LiveSession"
Cohesion: 0.10
Nodes (22): cardHTML(), closeSheet(), goto(), #list-count, openSession(), renderSessions(), SESSIONS, terminal on mobile research (+14 more)

### Community 167 - "AgentTableEntry"
Cohesion: 0.05
Nodes (54): AgentChipView, .init(coder:), .intrinsicContentSize, ChromeBackdrop, .init(coder:), .init(role:), ChromeRole, sidebar (+46 more)

### Community 170 - "URLDetection"
Cohesion: 0.10
Nodes (13): Bool, Range, String, URLDetection, digest(), firstMatch(), flushBullet(), Section (+5 more)

### Community 171 - "ReflowCorpusTests"
Cohesion: 0.14
Nodes (15): AgentApprovalBar, .init(coder:), .init(host:prompt:kind:), ApprovalBarAction, hide, noop, show, NSColor (+7 more)

### Community 172 - ".decodeKeySpec"
Cohesion: 0.14
Nodes (13): GridCompositor, Configuration, Int32, SessionGroup, SessionID, Tab, TabID, WorkspaceID (+5 more)

### Community 174 - "BinaryRefresherTests"
Cohesion: 0.11
Nodes (5): ISO8601DateFormatter, KouenDaemonTools, .init(client:subscriptionClient:controlEnabled:), String, UUID

### Community 175 - "RGBColorTests"
Cohesion: 0.23
Nodes (8): SettingsRemoteView, .body, .hostFormPanel, .hostListPanel, .mobilePairingSection, .pairedDevicesList, NSImage, String

### Community 176 - "Added"
Cohesion: 0.13
Nodes (18): AgentRow, .agentColor, .executables, .hookButton, .hookButtonTitle, .mcpButton, HookState, failed (+10 more)

### Community 177 - ".rects"
Cohesion: 0.20
Nodes (9): Group, PrefixCheatsheetWindow, .groups, PrefixIndicatorWindow, CGFloat, NSTextField, NSView, NSWindow (+1 more)

### Community 178 - "InlineAICompletionView"
Cohesion: 0.22
Nodes (10): CopyModeGridSource, .promptRows, ClosedRange, CopyModeReducer, Bool, Character, NSRegularExpression, Range (+2 more)

### Community 179 - "[3.13.1] - 2026-07-02"
Cohesion: 0.14
Nodes (17): PaneBorderStatus, bottom, off, top, PaneLeaf, PaneNode, branch, leaf (+9 more)

### Community 180 - "VTConformanceCorpusTests"
Cohesion: 0.08
Nodes (14): NSRangePointer, Any, NSAttributedString, NSRange, NSRect, String, UInt64, .color(_:) (+6 more)

### Community 181 - "GridCompositorTests"
Cohesion: 0.18
Nodes (5): CompositorPane, GridCompositorTests, Bool, String, TerminalGridSnapshot

### Community 182 - "P25 — iOS/iPadOS Support"
Cohesion: 0.21
Nodes (4): Bool, String, SurfaceID, TimeInterval

### Community 184 - "targets"
Cohesion: 0.09
Nodes (21): name, options, bundleIdPrefix, createIntermediateGroups, deploymentTarget, packages, Kouen, Sparkle (+13 more)

### Community 185 - "SessionSnapshot"
Cohesion: 0.13
Nodes (3): KouenGridTerminalTests, String, TerminalGridSnapshot

### Community 186 - "Error"
Cohesion: 0.09
Nodes (9): KeybindingsService, Bool, Command, String, .init(from:), Decoder, DECSpecialGraphics, CommandParserTests (+1 more)

### Community 187 - "AppDelegate"
Cohesion: 0.18
Nodes (10): AppDelegate, .application(_:open:), .application(_:openFiles:), QueuedExternalOpen, Bool, NSKeyValueObservation, String, URL (+2 more)

### Community 188 - "BrowserPaneView"
Cohesion: 0.12
Nodes (19): Motion, .entrance, .spring, .standardEase, CAMediaTimingFunction, KouenOnboarding, Bool, ImmersiveOnboardingWindowController (+11 more)

### Community 189 - "P5 — ACP (Agent Client Protocol) — Harness as ACP Editor/Client"
Cohesion: 0.27
Nodes (4): PanePipe, .subscribe(surfaceID:handler:), FileHandle, UUID

### Community 190 - "user-stories.md"
Cohesion: 0.13
Nodes (15): CodingKeys, activeWorkspaceID, keepSessionsOnQuit, revision, savedAt, themeName, version, workspaces (+7 more)

### Community 191 - "ScriptRuntime"
Cohesion: 0.14
Nodes (7): ScriptRuntime, Any, String, URL, JSContext, JSValue, ScriptingTests

### Community 192 - "GlyphRasterizer"
Cohesion: 0.08
Nodes (27): CTFontSymbolicTraits, CellMetrics, GlyphRasterizer, .rasterize(cluster:bold:italic:), .rasterize(codepoint:bold:italic:), .rasterize(glyph:font:), .shapedRunStats, RasterizedGlyph (+19 more)

### Community 193 - "BinaryInstaller"
Cohesion: 0.15
Nodes (13): UInt16, TTYSize, RecordClient, RecordingWriter, RecordSession, Summary, Bool, Data (+5 more)

### Community 194 - "Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag"
Cohesion: 0.15
Nodes (16): FileTreeScanOptions, MatchCategory, exactFilename, filenameContains, filenameContainsTokens, filenameEndsWith, filenameStartsWith, fuzzy (+8 more)

### Community 195 - "ResizeHUDView"
Cohesion: 0.16
Nodes (6): FileTreeContext, NSHostingView, SessionID, String, .init(rootPath:), UnsafeMutableRawPointer

### Community 196 - "Feature Provenance — harness-terminal"
Cohesion: 0.07
Nodes (22): Selector, .init(frame:), Collection, .aggregateBoardStatus, .taskTooltipSummary, Kind, primary, secondary (+14 more)

### Community 197 - "AgentSessionSummary"
Cohesion: 0.14
Nodes (10): .removeWorktreeAction(_:), NSButton, NSColor, NSRect, NSScrollView, NSStackView, NSTextField, NSClickGestureRecognizer (+2 more)

### Community 198 - ".classify"
Cohesion: 0.23
Nodes (6): DoctorRunner, Bool, URL, DoctorRunnerTests, String, URL

### Community 200 - "BinaryInstallerVersionTests"
Cohesion: 0.26
Nodes (7): InstallResult, Shell, bash, fish, zsh, Bool, URL

### Community 201 - "MCP Server (harness-mcp)"
Cohesion: 0.08
Nodes (35): KouenGridTerminal, .currentSelectionRegion, ClosedRange, BlockSelection, CursorRender, CursorStyle, bar, block (+27 more)

### Community 202 - "PaletteModel"
Cohesion: 0.14
Nodes (10): FrecencyDirectoryStore, FrecencyEntry, Date, Double, Never, String, Task, URL (+2 more)

### Community 203 - "Harness keybindings"
Cohesion: 0.17
Nodes (4): InputEncoder, InputEncoderTests, String, UInt8

### Community 204 - "From tmux"
Cohesion: 0.25
Nodes (7): Bringing your `.tmux.conf` over, Deliberate divergences, From tmux, Import Terminal Colors And Fonts, Key-by-key translation, Make Kouen the default terminal, Migrating to Kouen

### Community 205 - "CopyModeState"
Cohesion: 0.14
Nodes (12): NSCoder, NSEvent, NSImage, NSPanel, NSRect, String, Void, TabCell (+4 more)

### Community 206 - "HarnessCLI"
Cohesion: 0.22
Nodes (5): CSIParams, .count, Pen, TerminalGridColor, TerminalGridUnderline

### Community 207 - "scheduleRender"
Cohesion: 0.07
Nodes (13): AgentDetection, AgentDetector, Date, Int32, TimeInterval, ProcessScan, Int32, Int32 (+5 more)

### Community 208 - ".testDataFrameEncodeVsJSONBase64Output"
Cohesion: 0.14
Nodes (14): CompletionPopupView, .init(coder:), .init(frame:), CompletionRowView, .init(coder:), .init(text:isSelected:), .isHovered, Bool (+6 more)

### Community 209 - "SettingsRemoteView"
Cohesion: 0.13
Nodes (15): BrowserRequestPayload, close, cookies, evaluate, goBack, goForward, interact, navigate (+7 more)

### Community 210 - "PaneDropZoneOverlay"
Cohesion: 0.20
Nodes (4): CompletionGenerator, String, .fishCompletionSource, CompletionGeneratorTests

### Community 211 - "PaneTarget"
Cohesion: 0.28
Nodes (7): Channel, Bool, Int32, String, WaitForRegistry, .activeChannelCount, WaitForRegistryTests

### Community 212 - ".translate"
Cohesion: 0.17
Nodes (6): CwdMetadataProvider, GitMetadataProvider, MetadataProvider, String, Tab, GitMetadataProviderTests

### Community 213 - "String"
Cohesion: 0.08
Nodes (24): 1 — Process lifecycle & supervision, 2 — IPC protocol evolution, 3 — Concurrency architecture, 4 — State persistence, 5 — Render/PTY data path & the "mktemp failed" spam, 6 — Build/release pipeline, A10 (Low) — stale `@unchecked Sendable` inventory, A1 (High) — S1 daemon-reuse is undone at GUI relaunch by the build-handshake staleness check (+16 more)

### Community 215 - ".lines"
Cohesion: 0.14
Nodes (9): PaneID, SurfaceID, Tab, TabID, UUID, BrowserPaneReuseScopeTests, PaneNode, Tab (+1 more)

### Community 216 - "CellColorResolverTests"
Cohesion: 0.12
Nodes (16): OptionSet, KeySpec, .description, .init(key:modifiers:), Modifiers, String, UInt8, WindowInputRouterTests (+8 more)

### Community 217 - "GridCompositor"
Cohesion: 0.14
Nodes (18): PaletteAction, PaletteItemRow, .body, PaletteModel, PalettePanel, .canBecomeKey, PaletteRow, header (+10 more)

### Community 218 - "ScrollbackFile"
Cohesion: 0.09
Nodes (15): DetachedPaneOverlay, .init(coder:), .init(frame:style:), Style, detached, reconnectingChip, NSCoder, NSEvent (+7 more)

### Community 219 - "Prompt"
Cohesion: 0.18
Nodes (5): KouenCLI, StatusLineWidthTests, StatusLineWidth, String, StyledSegment

### Community 220 - "Section"
Cohesion: 0.17
Nodes (11): NotchGeometry, .fallback, NSScreen, NotchLayoutMetrics, .peekHeight, .peekWidth, NotchRect, NotchScreenMetrics (+3 more)

### Community 221 - "TerminalServicesProvider"
Cohesion: 0.10
Nodes (23): keys, ITerm2InlineImage, .heightArg, .preserveAspectRatio, .widthArg, Bool, String, UInt8 (+15 more)

### Community 222 - "AgentNotchRowSummary"
Cohesion: 0.12
Nodes (17): Bool, String, WorkbenchCommand, ack, agent, attention, board, cd (+9 more)

### Community 223 - "ANSIPalette"
Cohesion: 0.25
Nodes (8): GlassEffectView, RuntimeGlassEffectView, Bool, CGFloat, Context, NSColor, NSView, .panelBackground

### Community 224 - "CellColorResolver"
Cohesion: 0.12
Nodes (12): ANSIPalette, RGBColor, CellColorResolver, .init(palette:defaultForeground:defaultBackground:boldBrightens:faintFraction:minimumContrast:), .init(theme:boldBrightens:minimumContrast:), ResolvedCellColors, Bool, Double (+4 more)

### Community 225 - "HarnessPathDisplay"
Cohesion: 0.23
Nodes (7): StdioTransportTests, Data, MCPStdioBuffer, MCPStdioFraming, contentLength, newline, Data

### Community 226 - "FileChangeWatcher"
Cohesion: 0.18
Nodes (16): Source, activePane, activeTab, focusedPane, focusedSurface, PaneID, PaneLeaf, PaneNode (+8 more)

### Community 227 - "SSHTunnelManagerTests"
Cohesion: 0.14
Nodes (16): NotchOverviewRow, .approvalControls, .background, .badge, .body, .openableRow, .progressUnderline, .relativeTime (+8 more)

### Community 228 - "sessionRow"
Cohesion: 0.14
Nodes (7): KeybindingsStore, .fileURL, URL, KeybindingsStoreTests, URL, Void, String

### Community 229 - ".decide"
Cohesion: 0.21
Nodes (6): MutationResult, RemoteHost, RemoteHostStore, Bool, String, T

### Community 230 - "HarnessGridTerminalTests"
Cohesion: 0.25
Nodes (5): ResolvedCanvas, String, ThemeManager, ThemePreset, ThemeManagerTests

### Community 231 - "ExternalOpenKind"
Cohesion: 0.16
Nodes (20): Appearance, .init(backgroundOpacity:backgroundBlur:fontFamily:fontSize:windowPaddingX:windowPaddingY:sourceColorSpace:appearance:supportsWideGamut:contrastGrade:applyToTerminalOutput:), .init(from:), AppearanceKind, dark, light, Colors, ContrastGrade (+12 more)

### Community 232 - "P10 Task: Lazy Scrollback Reflow"
Cohesion: 0.21
Nodes (8): Logger, OSSignposter, FrameDropCause, encodeFailure, nilDrawable, FrameSignposter, Bool, UInt64

### Community 234 - ".scan"
Cohesion: 0.23
Nodes (4): Set, SurfaceID, Void, TerminalPaneRegistry

### Community 235 - "WorkbenchCommand"
Cohesion: 0.09
Nodes (17): SettingsHostingController, .init(coder:), .init(page:), SettingsWindowController, NSCoder, NSWindow, Page, advanced (+9 more)

### Community 237 - "TerminalBlockStoreTests"
Cohesion: 0.12
Nodes (11): Bool, CGFloat, NSCoder, NSEvent, NSLayoutConstraint, NSPoint, NSRect, WindowTitleStripView (+3 more)

### Community 238 - ".make"
Cohesion: 0.06
Nodes (30): DefaultTerminalManager, DefaultTerminalOpener, DefaultTerminalRegistrationError, .errorDescription, failed, DefaultTerminalStatus, .isDefault, .summary (+22 more)

### Community 239 - "TerminalMetalRenderer"
Cohesion: 0.10
Nodes (16): .captureLines(fromLine:toLine:), .captureLines(joinWrapped:), .feed(_:), Bool, Data, String, UInt8, CharacterWidth (+8 more)

### Community 240 - "PaneBorderStatus"
Cohesion: 0.14
Nodes (18): ChooseScope, buffer, client, session, tree, window, Command, MenuItem (+10 more)

### Community 242 - "AgentBridge"
Cohesion: 0.15
Nodes (5): HookFiringTests, NSObjectProtocol, String, URL, XCTestExpectation

### Community 243 - ".make"
Cohesion: 0.15
Nodes (20): Encodable, AISuggestionAck, AttachedAck, BrowserFramePush, BrowserOkAck, Cred, DetachedAck, DeviceCredentials (+12 more)

### Community 244 - "FileNode"
Cohesion: 0.12
Nodes (9): DaemonClientActor, TimeInterval, DaemonSessionService, .endpoint, .request(_:timeout:), Bool, TimeInterval, DaemonSessionServiceTests (+1 more)

### Community 245 - "ThemeDocumentTests"
Cohesion: 0.20
Nodes (8): PendingVersionBanner, welcome, whatsNew, State, Bool, String, URL, VersionBannerStore

### Community 246 - "Experience modes"
Cohesion: 0.16
Nodes (15): KouenTask, .init(from:), .init(id:sessionID:title:done:status:createdAt:updatedAt:cwd:), KouenTaskStatus, ciFailing, done, mergeReady, open (+7 more)

### Community 247 - ".renderFixture"
Cohesion: 0.14
Nodes (14): InstallError, daemonNotFound, .description, launchctlFailed, writeFailed, InstallReport, LaunchAgentInstaller, .isInstalled (+6 more)

### Community 248 - "DaemonMetrics"
Cohesion: 0.06
Nodes (18): Bool, NSObjectProtocol, Set, String, Tab, TabID, WorktreeAutoIsolateService, Bool (+10 more)

### Community 249 - "ReflowPreviewTests"
Cohesion: 0.16
Nodes (9): ClientSummary, DaemonStats, Bool, Date, Double, Int32, String, UUID (+1 more)

### Community 250 - "HarnessTerminalSurfaceWorkerTests"
Cohesion: 0.18
Nodes (8): PluginLoader, String, ScriptAPI, ScriptError, .errorDescription, evaluationError, unsupportedPlatform, JavaScriptCore

### Community 251 - "SessionCoordinator"
Cohesion: 0.21
Nodes (3): NSEvent, NSPopover, .lspPosition(for:)

### Community 252 - "NSViewRepresentable"
Cohesion: 0.29
Nodes (7): FSEventStreamBox, escaping, FSEventStreamRef, MainActor, UnsafeMutableRawPointer, Void, WatcherContext

### Community 253 - "Split Right"
Cohesion: 0.21
Nodes (5): PtyError, launchFailed, ShellLaunchProfile, .argv, ShellLaunchProfileTests

### Community 254 - "BoardViewController"
Cohesion: 0.10
Nodes (7): ContentAreaViewController, Bool, SplitDirection, String, TabID, Set, Notification

### Community 255 - "release-hotfix.sh"
Cohesion: 0.16
Nodes (9): FileGraphInfo, GraphifyLSPBridge, Double, String, URL, GraphifyLSPBridgeTests, Any, String (+1 more)

### Community 256 - "GitMetadataProvider"
Cohesion: 0.14
Nodes (13): InlineAICompletionView, .init(coder:), .init(frame:), .suggestion, Bool, NSCoder, NSEvent, NSRect (+5 more)

### Community 257 - "Sidebar SwiftUI Migration — Knowledge"
Cohesion: 0.15
Nodes (22): CoreImage, Network, AttachedAck, attachToPairedSurface(), ConnectionState, .authorized, .subscription, .surfaceID (+14 more)

### Community 258 - "WindowTitleStripView"
Cohesion: 0.14
Nodes (18): CodingKeys, activeSessionID, activeTabID, id, name, sessions, sortOrder, tabs (+10 more)

### Community 259 - "ThemeFileServiceTests"
Cohesion: 0.33
Nodes (4): .setSidebarVisible(_:animated:), SidebarPlacementSyncTests, CGFloat, Void

### Community 260 - ".welcome"
Cohesion: 0.18
Nodes (8): .body, InstallError, unsupported, Bool, AgentKind, Bool, String, URL

### Community 261 - "Browser Pane (P14)"
Cohesion: 0.18
Nodes (8): HookNotificationParser, Parsed, Any, Data, String, HookNotificationParserTests, Data, String

### Community 262 - ".install"
Cohesion: 0.15
Nodes (9): AgentRoutingResolver, String, AgentRoutingRule, AgentRoutingRuleSummary, Bool, String, UUID, AgentRoutingResolverTests (+1 more)

### Community 263 - "HarnessSidebarPanelViewController"
Cohesion: 0.19
Nodes (11): DemoSession, DemoTerminalView, .body, GridCanvas, Bool, CGFloat, String, StyledSegment (+3 more)

### Community 266 - ".path"
Cohesion: 0.20
Nodes (7): Data, ThemeDocumentError, emptyName, malformed, unsupportedVersion, wrongPaletteCount, ThemeDocumentTests

### Community 267 - ".performInstall"
Cohesion: 0.11
Nodes (19): Context, Non-goals, P8: macOS 27 Golden Gate Adoption, Phase 10 — WidgetKit & Desktop Status Panel (P2), Phase 11 — Metal Frame Pacing & DisplayLink Optimization (P2), Phase 12 — Terminal Accessibility Tree (P2), Phase 1 — Compatibility (P0), Phase 2 — Quick Wins (P1) (+11 more)

### Community 268 - "code:bash (# Old (agent-specific):)"
Cohesion: 0.40
Nodes (9): attribute_lines(), main(), redraw_frames(), repeated_chunk(), run_case(), sgr_lines(), truecolor_gradient(), unicode_lines() (+1 more)

### Community 270 - "WindowSession"
Cohesion: 0.08
Nodes (13): PaneBorderStatus, Bool, Command, Data, DispatchWorkItem, PaneID, PaneLeaf, PaneNode (+5 more)

### Community 271 - "StatusLineView.swift"
Cohesion: 0.20
Nodes (12): KouenChrome, KouenChromePalette, Bool, CGFloat, NSColor, String, PaletteFooter, .body (+4 more)

### Community 272 - "SGRMouseEvent"
Cohesion: 0.21
Nodes (14): Close Pane, Close Tab, New Tab, Cmd Shift W Force Closes Tab, Cmd T Creates New Session, Cmd W Closes Pane When Split, Cmd W Closes Tab When Single Pane, Window Survives Full Shortcut Sequence (+6 more)

### Community 273 - "KeySpec"
Cohesion: 0.30
Nodes (3): FileTreeWatcher, FileTreeWatcherTests, URL

### Community 274 - "[2.5.0] - 2026-06-12"
Cohesion: 0.15
Nodes (8): ActivityAssertionManager, .activeAssertionCount, Bool, NSObjectProtocol, Set, String, SurfaceID, ActivityAssertionManagerTests

### Community 275 - "P8: macOS 27 Golden Gate Adoption"
Cohesion: 0.11
Nodes (17): Artifacts, Client Application, Client Application, Client Application, Context, D1 — File preview (read-only), D2 — File/image attach (upload), D3 — Browser mirror (embedded, mirrors Mac's real BrowserPaneView) (+9 more)

### Community 276 - "SyntaxTextView"
Cohesion: 0.08
Nodes (34): .notchSection, .notifySection, ColorHexRow, .body, .colorBinding, .currentHex, .isCustom, PaletteCell (+26 more)

### Community 277 - ".run"
Cohesion: 0.09
Nodes (28): BinaryInstaller, .bundledMacOSDir, CopyOutcome, copied, keptNewerInstalled, skippedIdentical, DetectionStatus, .display (+20 more)

### Community 278 - "BlockTintOverlay"
Cohesion: 0.20
Nodes (9): .init(coder:), NotificationRowView, .init(coder:), .init(entry:), .isHighlighted, .isHovered, NSCoder, NSEvent (+1 more)

### Community 279 - "DisplayPanesOverlay"
Cohesion: 0.08
Nodes (21): Array, FormatColor, none, palette, rgb, StyledSegment, Bool, Element (+13 more)

### Community 280 - ".menu"
Cohesion: 0.13
Nodes (14): State, csiEntry, csiIgnore, csiIntermediate, csiParam, escape, escapeIntermediate, ground (+6 more)

### Community 281 - "TerminalScrollbarView"
Cohesion: 0.18
Nodes (12): ControlModeClient, ControlModeError, daemon, .description, noMatch, noSnapshot, unresolved, Command (+4 more)

### Community 282 - "RemoteHostStoreTests"
Cohesion: 0.14
Nodes (8): NSAttributedString, String, SyntaxHighlighter, SyntaxHighlighterTests, NSAttributedString, NSColor, String, SyntaxHighlightTests

### Community 284 - "click_ui_element"
Cohesion: 0.18
Nodes (6): LSPTextLocation, .position, LSPTextLocationParser, String, URL, LSPTextLocationParserTests

### Community 285 - "After all done, come back and update agent-memory/memory.md and agent-memory/plans/p14-web-browser-pane.md."
Cohesion: 0.29
Nodes (3): SessionStore, DispatchWorkItem, TimeInterval

### Community 288 - "AgentHookStrategy"
Cohesion: 0.21
Nodes (4): AsciiFastPathTests, StaticString, String, UInt

### Community 291 - "JSONDecoder"
Cohesion: 0.20
Nodes (3): String, TerminalGridSnapshot, VTConformanceCorpusTests

### Community 292 - "Release runbook"
Cohesion: 0.25
Nodes (7): Full local signing path (needs a Developer ID cert; not currently used), Full pipeline reference (not implemented in this fork), How this fork actually releases, If the workflow existed: running a release, One-time GitHub setup, Release runbook, What that workflow would publish

### Community 293 - "Fixes Applied (layered)"
Cohesion: 0.10
Nodes (18): CodingKeys, error, id, jsonrpc, method, params, JSONRPCId, int (+10 more)

### Community 294 - "GitHubCLIClient"
Cohesion: 0.21
Nodes (6): ExternalOpenKind, filePreview, terminal, theme, Set, ExternalOpenKindTests

### Community 295 - "AgentApprovalBar"
Cohesion: 0.20
Nodes (7): FileChangeWatcher, DispatchSourceFileSystemObject, DispatchWorkItem, String, TimeInterval, Void, FileChangeWatcherTests

### Community 296 - "NotificationBus"
Cohesion: 0.21
Nodes (6): String, TerminalGridCell, TextGrid, .totalLines, .viewportRows, WordColumnRangeTests

### Community 297 - "settings.json"
Cohesion: 0.17
Nodes (11): PaneBorderStatus, bottom, off, top, PaneRect, PaneRectSolver, Bool, Double (+3 more)

### Community 298 - "jobs"
Cohesion: 0.21
Nodes (11): NSCoder, NSRect, NSTextView, SyntaxLineNumberGutterView, .init(coder:), .init(frame:), .isFlipped, .init(coder:) (+3 more)

### Community 299 - "PaneNode"
Cohesion: 0.08
Nodes (31): FooterIconButton, .body, RecentProjectsMenuButton, .body, .recents, SidebarFooterModel, SidebarFooterView, .body (+23 more)

### Community 300 - "HarnessPaths.swift"
Cohesion: 0.23
Nodes (7): .snapshotPayload, NotificationBus, .postSnapshotChanged(_:), SnapshotChangedPayload, Bool, Data, String

### Community 301 - ".parse"
Cohesion: 0.06
Nodes (26): TerminalGridCell, TerminalGridSnapshot, .captureLines(joinWrapped:), .feed(_:), .promptRows, .readGrid(scrollbackOffset:), .assertAllPathsAgree(_:cols:rows:file:line:), StaticString (+18 more)

### Community 302 - "ThemeDiagnostics"
Cohesion: 0.16
Nodes (8): DetectedProfile, HandoffInfo, SignalFileRouter, Bool, FileManager, String, SignalFileRouterTests, URL

### Community 303 - ".encodeMouse"
Cohesion: 0.13
Nodes (16): Action, DesktopNotifier, .isUNNotificationCenterAvailable, KouenPathDisplay, NotificationPresenter, .userNotificationCenter(_:didReceive:withCompletionHandler:), .userNotificationCenter(_:willPresent:withCompletionHandler:), Bool (+8 more)

### Community 304 - "00-inception-plan.md"
Cohesion: 0.22
Nodes (9): .experienceSection, Bool, String, TriState, auto, .boolValue, .label, off (+1 more)

### Community 305 - ".script"
Cohesion: 0.17
Nodes (5): DirectionalAxis, down, left, right, up

### Community 306 - "RegressionBugFixTests"
Cohesion: 0.12
Nodes (15): Addendum — MAW-pattern validate gate (2026-07-23), Already matched (verified in code, not gaps), Method, Not gaps — deliberate positioning differences (no action), P39 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed / tmux), Phase A — Remote workflow parity (G2) — DONE 2026-07-11, Phase B — Sidebar dev-server visibility (G1) — DONE 2026-07-11, Phase C — Git workflow depth (G3, G4) — SPLIT 2026-07-11 (Opus planning pass) (+7 more)

### Community 307 - "ViPathTokenTests"
Cohesion: 0.53
Nodes (3): ProjectConfig, Bool, String

### Community 308 - "Send Ex Command"
Cohesion: 0.24
Nodes (7): SettingsAdvancedView, .body, Bool, String, SettingsKeysView, .detailView, SwiftUI

### Community 310 - "FrameSignposter"
Cohesion: 0.33
Nodes (6): Command, .targetKind, TargetKind, pane, session, window

### Community 311 - "Bug: Tab-Switch Black Screen"
Cohesion: 0.17
Nodes (5): BoardCommandTests, BoardModelTests, Tab, String, String

### Community 312 - "AgentSnapshot"
Cohesion: 0.20
Nodes (13): Array, Bool, Date, Decoder, PaneID, PaneNode, String, TabID (+5 more)

### Community 313 - "Terminal AI Chat (⌘I inline overlay)"
Cohesion: 0.08
Nodes (26): AgentNotchDashboardProjection, .agentCount, .sessionCount, .waitingCount, .workingCount, AgentNotchProjection, AgentNotchRowSummary, RowKind (+18 more)

### Community 317 - "Memory — harness-terminal"
Cohesion: 0.14
Nodes (13): KouenThemeDefinition, .backgroundHex, .boldHex, .cursorHex, .cursorTextHex, .foregroundHex, .isDark, .paletteHex (+5 more)

### Community 318 - "code:bash (# In a Harness pane:)"
Cohesion: 0.12
Nodes (19): Bool, String, UUID, TaskDaemonBridge, CGFloat, NSCoder, SessionID, String (+11 more)

### Community 319 - "FormatColor"
Cohesion: 0.09
Nodes (19): LaunchdServiceInstaller, .backendName, .isInstalled, ServiceInstaller, ServiceInstallers, .current, ServiceInstallReport, Bool (+11 more)

### Community 320 - "Focus Persistence — Per-Session-Tab Pane Focus (RL-043)"
Cohesion: 0.26
Nodes (14): Agent Command Does Not Crash, Agent Waiting Filter Does Not Crash, Board Command Shows Board Panel, Cd Command Switches To Matching Tab, Copy Path Command Does Not Crash, Errors Command Does Not Crash, Find Command Opens Command Palette On Empty Query, Find Command Resolves Unique File (+6 more)

### Community 321 - "UInt64"
Cohesion: 0.24
Nodes (3): KittyGraphicsConformanceTests, String, Void

### Community 322 - "DesktopNotifier"
Cohesion: 0.15
Nodes (15): FormatContextBuilder, DaemonSurfaceID, String, Array, SessionGroup, .activeTab, .init(from:), .init(id:name:tabs:activeTabID:lastActiveTabID:sortOrder:groupID:persistent:) (+7 more)

### Community 323 - "LayoutNode"
Cohesion: 0.09
Nodes (19): NSScrollView, NSWindow, WorkspaceFileTreeView, Bool, CGFloat, DispatchWorkItem, NSCoder, NSColor (+11 more)

### Community 324 - "WorkspaceSymbolIndex"
Cohesion: 0.18
Nodes (3): RemoteHostStoreTests, String, URL

### Community 326 - "worktree_isolation.robot"
Cohesion: 0.15
Nodes (3): CellColorResolverTests, .resolver, CellColorResolver

### Community 327 - ".theme"
Cohesion: 0.18
Nodes (9): PaneOutputWaiter, PaneOutputWaitResult, SpawnedAgentSurface, Bool, CheckedContinuation, Never, PaneLeaf, Tab (+1 more)

### Community 328 - "README.md"
Cohesion: 0.23
Nodes (4): GroupedSessionTests, SessionGroup, Set, SurfaceID

### Community 329 - "ImmersivePalette.swift"
Cohesion: 0.29
Nodes (8): ShellInfo, ShellStepView, .allConfigured, .body, .noneConfigured, Bool, String, URL

### Community 330 - ".drawGlyph"
Cohesion: 0.19
Nodes (14): CellMetrics, CellMetrics, ComposedTerminalView, .body, .metrics, .pixelHeight, .pixelWidth, Bool (+6 more)

### Community 331 - ".recordReapedGenerationForTesting"
Cohesion: 0.32
Nodes (4): Darwin, Foundation, Glibc, KouenCore

### Community 333 - "RealPty"
Cohesion: 0.08
Nodes (10): SessionEditor, .surfaceID(forPaneID:), .tabIndex(surfaceID:), AgentSessionSummaryTests, Phase67Tests, SessionEditorPhase4Tests, PaneID, TabID (+2 more)

### Community 334 - "ImageProtocolTests.swift"
Cohesion: 0.15
Nodes (12): MouseButton, left, middle, right, wheelDown, wheelLeft, wheelRight, wheelUp (+4 more)

### Community 335 - ".makeModel"
Cohesion: 0.16
Nodes (10): NSView, NSViewCornerConfiguration, String, TimeInterval, Toast, ToastBody, .body, ToastHostingView (+2 more)

### Community 336 - "run.sh"
Cohesion: 0.70
Nodes (4): kill_stale(), kill_stale_prod(), run.sh script, usage()

### Community 337 - "CommandExecutionError"
Cohesion: 0.25
Nodes (4): ControlKeyNormalizer, Bool, String, ControlKeyNormalizerTests

### Community 338 - "CSIParams"
Cohesion: 0.30
Nodes (5): AgentNotchPeekDecider, String, AgentNotchPeekDeciderTests, Bool, String

### Community 339 - "Foundation"
Cohesion: 0.19
Nodes (11): AppKit, CoreGraphics, CoreText, ImageIO, KouenCopyMode, KouenTerminalEngine, KouenTerminalRenderer, KouenTheme (+3 more)

### Community 340 - "code:bash (harness-cli install-hooks openclaw)"
Cohesion: 0.22
Nodes (13): Next Session, Previous Session, Split Down, Split Right, Zombie Crash Rapid Split Close Cycle, Close Pane Removes Split, Session Navigation Cmd Brackets, Split Down Creates Pane (+5 more)

### Community 341 - "code:bash (harness-cli install-hooks pi)"
Cohesion: 0.32
Nodes (3): CGFloat, ScrollReuseTests, NSWindow

### Community 342 - "Added"
Cohesion: 0.30
Nodes (7): Bool, NSPasteboard, NSString, String, URL, TerminalServicesProvider, AutoreleasingUnsafeMutablePointer

### Community 343 - "[2.2.3] - 2026-06-09"
Cohesion: 0.18
Nodes (9): clamp(), statusHelp(), Configuration, String, T, TabBarIconButtonStyle, TabBarInlineIconButtonStyle, tabDisplayTitle() (+1 more)

### Community 344 - "FileViewerViewController"
Cohesion: 0.09
Nodes (17): FileViewerViewController, .acceptsFirstResponder, Bool, NSEvent, Set, String, URL, Void (+9 more)

### Community 346 - "Agent platform icons"
Cohesion: 0.50
Nodes (3): Agent platform icons, Lobe Icons — MIT License, Third-party notices

### Community 347 - "[3.2.0] - 2026-06-16"
Cohesion: 0.11
Nodes (17): 1.1 Architecture, 1.2 Algorithm review, 1.3 Structure findings, 2.1 Structure, 2.2 Risk register (ranked), 3.1 Current implementation, 3.2 Why nothing shows (ranked root-cause candidates), 3.3 Fix plan (+9 more)

### Community 349 - "Contents.json"
Cohesion: 0.19
Nodes (4): KouenSettingsTests, URL, Void, String

### Community 350 - "Background Polling & Snapshot Fanout — P22"
Cohesion: 0.19
Nodes (4): URL, MobileBridgeAttachFileTests, String, URL

### Community 351 - "Architecture Decisions — harness-terminal"
Cohesion: 0.17
Nodes (10): InterruptFlag, .value, ReplayClient, ReplayPlayer, Bool, Data, DispatchSourceSignal, Double (+2 more)

### Community 352 - "Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)"
Cohesion: 0.33
Nodes (6): SurfaceProgressTracker, DispatchWorkItem, MainActor, SurfaceID, TimeInterval, Void

### Community 353 - "GPU Animation Pattern — Layout Once, GPU Paints"
Cohesion: 0.19
Nodes (8): os, DaemonSessionError, daemonError, .description, unexpectedResponse, LatencyMonitor, String, UInt64

### Community 354 - "P10: Performance and Feature Roadmap (Terminal First, IDE Convenient)"
Cohesion: 0.21
Nodes (6): NotificationEntry, .id, SessionID, SurfaceID, TabID, WorkspaceID

### Community 355 - ".deepMerge"
Cohesion: 0.24
Nodes (9): DotView, .init(frame:), statusColor(), Bool, Context, NSColor, NSRect, .workingDot (+1 more)

### Community 356 - "SurfaceProgressTracker"
Cohesion: 0.14
Nodes (6): .snapshot, Bool, String, ThemeService, KouenOptions, NSColor

### Community 357 - ".handleCat"
Cohesion: 0.31
Nodes (6): Bool, Counter, Scheduled, SurfaceProgressTrackerTests, DispatchWorkItem, TimeInterval

### Community 358 - "[3.5.1] - 2026-06-20"
Cohesion: 0.38
Nodes (7): CGFloat, Range, TabBarLayoutMetrics, .pitch, TerminalTabBarBody, .body, TerminalTabBarModel

### Community 359 - "OcclusionTests"
Cohesion: 0.10
Nodes (14): AnyCancellable, NotchMaskAnimator, Bool, CGFloat, CGRect, NSView, NotchPanel, .canBecomeKey (+6 more)

### Community 360 - "State"
Cohesion: 0.19
Nodes (8): NotificationPermission, State, denied, granted, undetermined, MainActor, UNAuthorizationStatus, UserNotifications

### Community 361 - "FormatStyledSegment.swift"
Cohesion: 0.08
Nodes (21): AutomationStore, KouenAutomation, Bool, Date, String, URL, UUID, AutomationScheduler (+13 more)

### Community 362 - "RGBColor"
Cohesion: 0.12
Nodes (10): MainMenuBuilder, MenuTarget, Bool, NSMenu, NSMenuItem, Selector, String, SurfaceID (+2 more)

### Community 363 - "generate-cheatsheet.js"
Cohesion: 0.36
Nodes (5): PaneLeaf, SessionGroup, Any, String, Tab

### Community 364 - "[2.2.4] - 2026-06-11"
Cohesion: 0.15
Nodes (9): RecordingEvent, input, metadata, output, resize, .timeMs, Date, Encoder (+1 more)

### Community 365 - "Fixes Applied (v3.9.1+)"
Cohesion: 0.27
Nodes (3): DaemonReconnectPolicy, TimeInterval, DaemonReconnectPolicyTests

### Community 366 - "Consumers"
Cohesion: 0.08
Nodes (22): OverlayBackground, Context, agentDetail(), AgentInboxBody, .body, .needsAttentionCount, AgentInboxPanelView, .init(agents:onSelect:) (+14 more)

### Community 367 - "DaemonStats"
Cohesion: 0.23
Nodes (10): BlockTintOverlay, .init(coder:), .init(surfaceView:), .isFlipped, Bool, CGFloat, NSCoder, NSEvent (+2 more)

### Community 368 - "Tab"
Cohesion: 0.19
Nodes (10): ConfigError, .errorDescription, unsupportedAgent, writeFailure, MCPConfigWriter, Any, Range, String (+2 more)

### Community 369 - "Git Panel"
Cohesion: 0.20
Nodes (7): TerminalColorRole, background, cursor, foreground, palette, SurfaceColorProviderState, UInt8

### Community 370 - ".encode"
Cohesion: 0.17
Nodes (5): NotificationCenterProbe, .isKnownBad, Bool, Void, NotificationCenterProbeTests

### Community 371 - "P13 — Embedded Browser Pane (cmux parity)"
Cohesion: 0.18
Nodes (8): Date, Never, Task, Void, TabPillView, .pillBackground, .pillBorder, Gesture

### Community 372 - "DynamicInstanceBuffer"
Cohesion: 0.15
Nodes (13): CodingKey, CodingKeys, createdAt, cwd, done, id, sessionID, status (+5 more)

### Community 374 - ".run"
Cohesion: 0.17
Nodes (10): JSONDecoder, JSONEncoder, Kind, input, metadata, output, resize, Decoder (+2 more)

### Community 375 - ".install"
Cohesion: 0.06
Nodes (15): KouenDaemonCore, DaemonBrowserRoutingTests, IPCCodecInvariantTests, String, URL, ConcurrentIndexSet, .count, RawSocketError (+7 more)

### Community 376 - "ScrollReuseTests"
Cohesion: 0.24
Nodes (3): ShortcutRecorderSerializer, String, ShortcutRecorderSerializerTests

### Community 377 - "Identifiable"
Cohesion: 0.39
Nodes (3): ScriptHookCoordinator, Bool, String

### Community 378 - "SurfaceProgressTrackerTests.swift"
Cohesion: 0.13
Nodes (11): ResizeHUDView, .cornerConfiguration, .init(coder:), .init(frame:), DispatchWorkItem, NSCoder, NSColor, NSPoint (+3 more)

### Community 379 - "MCPServer"
Cohesion: 0.24
Nodes (6): ScriptFileWatcher, DispatchSourceFileSystemObject, DispatchWorkItem, String, TimeInterval, Void

### Community 380 - "PromptQueue"
Cohesion: 0.17
Nodes (9): SurfaceRegistryTests, .firstSurfaceID(for:in:), .firstSurfaceID(forSession:in:), PaneID, SessionID, String, SurfaceID, TabID (+1 more)

### Community 382 - "ThaiClusterRenderTests"
Cohesion: 0.22
Nodes (6): merged, JSONMerge, Any, Bool, String, JSONMergeTests

### Community 383 - "terminal_stress_runner.py"
Cohesion: 0.19
Nodes (4): SnapshotCoalescer, MainActor, Void, AgentApprovalBarTests

### Community 384 - "NSTextField Leak in BoardViewController (P20 Performance)"
Cohesion: 0.11
Nodes (20): Identifiable, DiscoverStepView, .body, Point, String, OnboardingStep, complete, discover (+12 more)

### Community 386 - "SKILL-LOG.md"
Cohesion: 0.07
Nodes (22): .webView(_:createWebViewWith:for:windowFeatures:), .webView(_:didCommit:), BrowserPaneViewTests, MockWebView, .isLoading, .url, Any, Bool (+14 more)

### Community 387 - "User Profile"
Cohesion: 0.22
Nodes (9): DisplayPanesChipView, .cornerConfiguration, DisplayPanesOverlay, Any, NSEvent, NSView, NSViewCornerConfiguration, SurfaceID (+1 more)

### Community 388 - "Darwin"
Cohesion: 0.30
Nodes (4): HookRegistryTests, SeededIDs, URL, UUID

### Community 389 - "HarnessCLITests"
Cohesion: 0.29
Nodes (7): AgentNotification, OSCNotificationParser, DaemonSurfaceID, Data, Date, String, SurfaceID

### Community 390 - "UI Automation — Robot Framework (P18)"
Cohesion: 0.29
Nodes (4): RepoResolver, Bool, String, RepoResolverTests

### Community 391 - "AppKit + Metal Patterns"
Cohesion: 0.19
Nodes (12): CLI Isolate Creates Worktree And Session, CLI Isolate With Custom Branch Name, Close Session Keeps Dirty Worktree, Close Session Removes Clean Worktree, Create Isolated Session And Select, Git Checkout In Normal Session Does Not Affect Isolated, Isolate Without Branch Uses Detached HEAD, Run CLI (+4 more)

### Community 402 - "View"
Cohesion: 0.08
Nodes (37): ButtonStyle, CommandRow, .body, GlassCard, .body, GlassPrimaryButtonStyle, GlassSecondaryButtonStyle, GlassSmallButtonStyle (+29 more)

### Community 403 - "PresentAttempt"
Cohesion: 0.21
Nodes (8): Container, .init(coder:), .init(frame:), NotchPulseHost, Context, NSCoder, NSHostingView, NSRect

### Community 404 - "Split Panes (NSSplitView)"
Cohesion: 0.22
Nodes (7): BellScanState, esc, normal, string, stringEsc, SurfaceMonitor, Data

### Community 405 - "AgentIconRenderer"
Cohesion: 0.22
Nodes (9): SSHTunnelError, .description, exitedEarly, invalidConfiguration, launchFailed, notReady, Int32, String (+1 more)

### Community 406 - "main.swift"
Cohesion: 0.26
Nodes (5): Bool, NSRange, NSString, Void, SyntaxTextView

### Community 408 - "IPC Architecture"
Cohesion: 0.17
Nodes (9): NSDraggingInfo, NSDragOperation, PasteController, Bool, Data, NSPasteboard, String, TimeInterval (+1 more)

### Community 409 - "Session/Tab/Pane Hierarchy & Top Bar (CASE-028)"
Cohesion: 0.13
Nodes (19): CustomStringConvertible, DaemonClientError, connectionFailed, .description, timeout, unexpectedResponse, writeFailed, atomicWrite() (+11 more)

### Community 411 - "Task 1: Redesign Session Sidebar"
Cohesion: 0.13
Nodes (14): BinaryInstaller.DetectionStatus, SetupStepView, .body, .canInstall, .hooksDetail, .hooksTone, .hooksValue, .isSuccess (+6 more)

### Community 414 - "json.json"
Cohesion: 0.37
Nodes (3): .block(atPromptLine:), String, TerminalBlockStoreTests

### Community 416 - ".refreshSurfaceMetadata"
Cohesion: 0.11
Nodes (7): tab, .tab(for:), AgentScanner, Bool, DispatchSourceTimer, TimeInterval, .postSnapshotChanged(revision:)

### Community 417 - "rust.json"
Cohesion: 0.40
Nodes (4): SplitDirection, TabID, .body, TerminalTabBarDelegate

### Community 419 - "typescript.json"
Cohesion: 0.13
Nodes (14): Artifacts, Client Application — Shader Presets (F4) — **UI REVERTED 2026-07-11, user call**, Client Application — Task Dashboard (F1), Context, Data Storage — Tasks (F1), Dev Task Progress — P40 MCP Surface Expansion + Shader Presets, Integration, Lessons applied (from `agent-memory/knowledge/rl-lessons.md`, surfaced during this session's P38 review) (+6 more)

### Community 420 - "yaml.json"
Cohesion: 0.12
Nodes (6): NSTextView, KouenApp, KouenCommands, KouenIPC, GitPanelViewDiffPopoverTests, TaskStatusMappingTests

### Community 421 - "FilePreviewCoordinatorTabScopeTests"
Cohesion: 0.33
Nodes (3): String, WorkspaceID, DaemonSyncServiceBranchNotifyTests

### Community 422 - "HintModeOverlay"
Cohesion: 0.26
Nodes (5): Mode, compatible, kouen, TerminalIdentity, TerminalIdentityTests

### Community 423 - "SixelDecoder"
Cohesion: 0.20
Nodes (9): AnyObject, CommandExecutionError, daemonError, .description, noActiveSurface, targetNotFound, unsupportedInThisContext, CommandExecutor (+1 more)

### Community 424 - ".parseDiffHunks"
Cohesion: 0.29
Nodes (3): GitPanelViewHunkStagingTests, String, URL

### Community 425 - "AgentVectorIcon"
Cohesion: 0.17
Nodes (12): CodingKeys, appearance, applyToTerminalOutput, backgroundBlur, backgroundOpacity, contrastGrade, fontFamily, fontSize (+4 more)

### Community 426 - "Bug — Cmd+\ sidebar toggle gone after collapse"
Cohesion: 0.12
Nodes (12): .setupPrompt, AgentHookStrategy, eventArrayJSON, eventMatcherJSON, .filename, namedGroupJSON, ownJSONFile, ownTextFile (+4 more)

### Community 427 - ".delay"
Cohesion: 0.17
Nodes (9): AnyView, .rowList, AgentNotchViewModel, .visibleRows, .waitingCount, Bool, CGFloat, String (+1 more)

### Community 428 - "TaskDashboardView"
Cohesion: 0.24
Nodes (4): GroupedSessionDaemonTests, SessionGroup, String, URL

### Community 429 - "Case: cwd "bleed" — session worktree jumps to wrong dir during builds"
Cohesion: 0.32
Nodes (7): FileTab, .title, FileTabManager, .hasOpenTabs, Bool, FileTabID, String

### Community 430 - "Competitive Position (as of v3.12.0, 2026-07-02)"
Cohesion: 0.18
Nodes (11): Typography, .badge, .kbd, .paletteHeader, .paletteTitle, .rowMeta, .rowTitle, .sectionLabel (+3 more)

### Community 431 - "BoardCardView"
Cohesion: 0.22
Nodes (6): AgentNotchPresentation, closed, open, peek, AgentNotchWindowActivator, Combine

### Community 432 - "PathToken"
Cohesion: 0.40
Nodes (4): PathToken, PathTokenParser, Bool, String

### Community 433 - "LaunchdServiceInstaller"
Cohesion: 0.27
Nodes (7): AgentCatalog, AgentConfig, DiskAgentConfig, Bool, String, .detectionSection, agents

### Community 434 - "Project History"
Cohesion: 0.26
Nodes (4): Bool, String, ThaiClusterRenderTests, .builder

### Community 435 - ".init"
Cohesion: 0.14
Nodes (11): MTLLibrary, MTLRenderPipelineState, ImageTextureCache, MTLDevice, MTLTexture, UInt8, CGFloat, MTLBuffer (+3 more)

### Community 436 - "WaitForRegistry"
Cohesion: 0.27
Nodes (3): TabID, WorkspaceID, GitPanelViewWorktreeNavigationTests

### Community 437 - "PickerItemRow"
Cohesion: 0.36
Nodes (3): .agentInfo(forWorktreePath:tabs:), Tab, GitPanelViewWorktreeAgentTests

### Community 438 - "SessionEditor"
Cohesion: 0.23
Nodes (5): HintModeOverlay, Any, NSEvent, NSView, String

### Community 439 - "SetupStepView"
Cohesion: 0.18
Nodes (9): Status, ciFailing, done, mergeReady, open, running, Bool, Date (+1 more)

### Community 440 - "LegacySnapshot"
Cohesion: 0.27
Nodes (8): LegacySnapshot, LegacyWorkspace, Bool, Date, String, Tab, TabID, WorkspaceID

### Community 442 - "GroupedSessionDaemonTests"
Cohesion: 0.60
Nodes (3): BlockSummary, Date, String

### Community 443 - "main.swift"
Cohesion: 0.24
Nodes (7): buffers, DynamicInstanceBuffer, MTLBuffer, MTLDevice, Range, String, T

### Community 444 - "BlockContextMenuTests"
Cohesion: 0.22
Nodes (7): CLIInstaller, .binDirectory, .installedCLIPath, .installedDaemonPath, Bool, String, URL

### Community 445 - "Section"
Cohesion: 0.15
Nodes (11): .init(coder:), NSCoder, NSHostingView, Tab, TerminalTabBarView, .delegate, .init(coder:), .init(frame:) (+3 more)

### Community 446 - "Modifiers"
Cohesion: 0.12
Nodes (5): FormatContextDaemonTests, PaneID, String, SurfaceID, URL

### Community 447 - "PaletteMode"
Cohesion: 0.18
Nodes (6): CommandPaletteController, PaletteCommandConfig, PaletteFileEntry, PaletteGrepMatch, String, TimeInterval

### Community 448 - "mobile_bridge_pairing_bugs.robot"
Cohesion: 0.18
Nodes (10): Bug 1 - Rotation Grace Slot Keeps The Previous Token Redeemable, Bug 1 - Rotation Shifts The Outgoing Token Into The Grace Slot, Bug 1 - Stop Fully Clears The Grace Slot, Bug 1 - Token Lifetime Not Regressed Below The Human-Flow Window, Bug 2 - Client onerror Does Not Clobber The Server Error Banner, Bug 2 - No Abrupt Cancel Immediately After The Error Text, Bug 2 - Reject Path Closes Gracefully With Policy-Violation Code 1008, Bug 3 - QR Not Printed When No Listener Is Ready (+2 more)

### Community 449 - "PresentAttempt"
Cohesion: 0.09
Nodes (17): .event(_:), .interval(_:_:), StaticString, T, Bool, CAMetalDrawable, .init(themeName:fontFamily:fontSize:vivid:colorRendering:colorGamut:offMainParserFramePipeline:liveResizeReflow:), PendingMainHop (+9 more)

### Community 451 - ".run"
Cohesion: 0.29
Nodes (3): ScriptConfigLocator, Bool, String

### Community 452 - "tmux parity — status, adaptations, and deliberate divergences"
Cohesion: 0.16
Nodes (4): FlippedView, .isFlipped, SessionID, GitPanelViewWorktreeTaskTests

### Community 455 - "ComposerPanel"
Cohesion: 0.14
Nodes (14): center, ComposerPanel, .canBecomeKey, .textView(_:doCommandBy:), .textView(_:shouldChangeTextIn:replacementString:), Bool, NSEvent, NSRange (+6 more)

### Community 456 - "TerminalModes"
Cohesion: 0.23
Nodes (3): TerminalModes, .encode(text:modifiers:modes:), .appCursor

### Community 457 - ".normalizedKey"
Cohesion: 0.17
Nodes (12): AnimatablePair, .body, HorizontalInsetRect, CGRect, Path, NotchShape, .animatableData, CGFloat (+4 more)

### Community 458 - ".deletePersistedScrollback"
Cohesion: 0.38
Nodes (3): DataBox, GitPanelViewDiffErrorTests, String

### Community 459 - ".encode"
Cohesion: 0.42
Nodes (6): InstallResult, ShellCompletionInstaller, Bool, String, URL, ShellIntegration

### Community 460 - "RunState"
Cohesion: 0.28
Nodes (5): Bundle, NSImage, WelcomeStepView, .body, .logo

### Community 461 - ".worktreeList"
Cohesion: 0.22
Nodes (8): MCP Control Allowed With Env Var, MCP Control Denied Without Env Var, MCP KouenBoard Returns Columns, MCP KouenList Returns Sessions, MCP ReadPaneOutput Returns Content, Run MCP Request, Run MCP Request Allowed, Run MCP Request Denied

### Community 462 - "AGENTS.md"
Cohesion: 0.25
Nodes (7): Browser Pane Open Close Rapid, File Preview Open Close, Git Fetch Shows Toast, Launch Kouen Staging, Memory Stability After 30 Seconds, Quit Kouen Staging, Sidebar Toggle Immediately After Launch

### Community 464 - "MouseButton"
Cohesion: 0.14
Nodes (13): Artifacts, Category 1 — Pure refactor + extraction (no behavior change), Category 2 — Agents segment UI + aggregate refresh (A1 + A2), Category 3 — Merge/handoff action (A3), Category 4 — Regression + final gate, Context, Last updated: 2026-07-13, Lessons Learnt reviewed (+5 more)

### Community 465 - "DirectionalAxis"
Cohesion: 0.29
Nodes (6): ChecksStatus, fail, none, pass, pending, Any

### Community 466 - "ReflowFastPathTests"
Cohesion: 0.12
Nodes (8): OnboardingController, KouenOnboarding, Agent, OnboardingEnvironment, Bool, String, BinaryInstallerDisplayTests, OnboardingEnvironmentTests

### Community 467 - ".moveSelection"
Cohesion: 0.29
Nodes (6): TabStatus, done, error, idle, running, waiting

### Community 469 - "PresentAttempt"
Cohesion: 0.31
Nodes (8): daemonLog(), detectStaleInstance(), installSignalHandlers(), removeForeignPIDFile(), removePIDFile(), Sendable, String, writePIDFile()

### Community 470 - "DispatchTime"
Cohesion: 0.32
Nodes (6): TerminalGridCell, ThaiClusterCopyTests, ThaiGrid, .columns, .totalLines, .viewportRows

### Community 471 - ".evaluateStyled"
Cohesion: 0.14
Nodes (13): 1. Tasks — storage + MCP + IPC contracts, 2. Worktree (MCP resource) — MCP contracts only, 3. Hosts (MCP resource) — one read-only tool, 4. Shader Presets — rendering pipeline change, Host (MCP resource) — no new aggregate, Logical Design, Open items for task-design to resolve (not blocking, just unresolved here), P40 — MCP Surface Expansion (Tasks/Worktrees/Hosts) + Shader Presets (+5 more)

### Community 473 - "HarnessOnboarding"
Cohesion: 0.14
Nodes (9): GridCompositorParityTests, LiveCompositorFixture, Bool, String, TerminalGridSnapshot, PortCompositorFixture, Bool, String (+1 more)

### Community 474 - "String"
Cohesion: 0.29
Nodes (7): Toggle Sidebar, Sidebar Toggle Works, Board CLI Shows Columns, Board CLI Shows Running After Long Command, Board Columns Visible After Click, Board Tab Accessible In Sidebar, Split Pane And Resize

### Community 475 - ".hitTest"
Cohesion: 0.08
Nodes (30): ImagePlacementSnapshot, Bool, String, UInt8, TerminalCellWidth, normal, spacerTail, wide (+22 more)

### Community 478 - ".install"
Cohesion: 0.14
Nodes (13): Artifacts, Bigger finding: the planned "Add to Workspace" entry point was unreachable (2026-07-17), Bug found via real `make preview` testing (2026-07-17, post-Task-6), Client Application, Context, Dev Task Progress — Add Repo/Folder to Workspace (P43), Fourth real bug, surfaced by the label becoming honest (2026-07-17), Infrastructure / Data Storage (+5 more)

### Community 479 - "ScrollbackTests"
Cohesion: 0.40
Nodes (3): ReflowFastPathTests, .feeds, String

### Community 480 - "Command Prompt Architecture"
Cohesion: 0.29
Nodes (6): ColorKind, .base, bg, fg, underline, ComposedFrame

### Community 481 - ".testKouenRendererFixtureDefaultTextReportsPlausibleGlyphStats"
Cohesion: 0.15
Nodes (11): .currentRawSelection, RawSelection, Bool, SelectionGranularity, character, line, word, RawSelection (+3 more)

### Community 483 - "Changed"
Cohesion: 0.25
Nodes (3): FlushSessionStateTests, String, URL

### Community 485 - ".testKouenRendererFixtureLigatureShapingPathReportsPlausibleGlyphs"
Cohesion: 0.38
Nodes (6): Cleanup And Quit, Create Config File, No Config File Starts Normally, Script Hot Reload On Save, Script Loads On Startup, Script Syntax Error Does Not Crash

### Community 486 - "TabPillView"
Cohesion: 0.29
Nodes (6): Bug 1 - Browser Pane Deferred Unregister, Bug 1 - Browser Pane Reuse On Rebuild, Bug 2 - New Session Syncs Before Reading Active Tab, Bug 2 - Tab Bar New Tab Also Syncs, Bug 3 - Browser Pane Forces Redraw On Reattach, Build Compiles Successfully

### Community 491 - "Added"
Cohesion: 0.40
Nodes (4): Dispatch, Charset, ascii, decSpecialGraphics

### Community 492 - "Service Decomposition — SessionCoordinator (P17)"
Cohesion: 0.36
Nodes (4): OcclusionTests, NSWindow, String, TimeInterval

### Community 493 - "ccRunStart"
Cohesion: 0.60
Nodes (3): .encode(_:modifiers:event:modes:), SpecialKey, insert

### Community 494 - "ccRunInfo"
Cohesion: 0.33
Nodes (5): Kouen LSP Diagnostics Does Not Crash, Kouen LSP Hover Returns Result, Kouen LSP Start Returns JSON, Kouen View Binary Shows Guard Message, Kouen View Prints File Content

### Community 495 - "ccRuns"
Cohesion: 0.50
Nodes (3): ReplayStep, Data, KeyedDecodingContainer

### Community 496 - ".testProceduralBoxAndBlockCellsDoNotEnterShapedRunCache"
Cohesion: 0.40
Nodes (5): MergeMethod, .flag, merge, rebase, squash

### Community 498 - ".automationList"
Cohesion: 0.50
Nodes (4): KeyRecorderRepresentable, .body, String, Void

### Community 499 - ".routingRuleList"
Cohesion: 0.40
Nodes (5): ColorKind, .base, bg, fg, underline

### Community 500 - ".json"
Cohesion: 0.19
Nodes (9): BinaryRefresher, .binDirectory, .installedCLIPath, .installedDaemonPath, Bool, URL, BinaryRefresherTests, String (+1 more)

### Community 501 - "Fixed"
Cohesion: 0.15
Nodes (12): Artifacts, Client Application, Client Application, Client Application, Context, Dev Task Progress — P37 Phase G: Autocomplete (mobile bridge), G1 — @ file-path picker ✅ DONE 2026-07-13, G2 — shell tab-completion suggestion strip (heuristic, best-effort) ✅ DONE 2026-07-13 (+4 more)

### Community 502 - "ACP Client (Shelved)"
Cohesion: 0.39
Nodes (3): RemoteHostsService, .activeHostName, String

### Community 503 - "Build Scripts Self-Kill Protection"
Cohesion: 0.05
Nodes (53): BrowserPaneRegistry, BrowserPaneView, .activeTab, .init(coder:), .init(url:paneID:), .init(url:paneID:webView:), .webView(_:didFail:withError:), .webView(_:didFailProvisionalNavigation:withError:) (+45 more)

### Community 504 - "Switch To Session 1"
Cohesion: 0.27
Nodes (9): Command Prompt, Find In Files, Git Panel, Open Command Palette, Switch To Session 1, Switch To Session 2, Rapid Session Switch While Typing, Switch Between Isolated And Normal Session (+1 more)

### Community 506 - "KittyGraphicsCommand"
Cohesion: 0.33
Nodes (6): DecoKind, curly, dashed, dotted, double, solid

### Community 507 - "memory_leak_guards.robot"
Cohesion: 0.40
Nodes (4): Leak A - Retiring A Host Drops Its AI Controllers, Leak B - Browser Network Capture Is Bounded, Leak C - Every Per-Surface Dict In Coordinator Has Retire Cleanup, Leak D - Every Per-Surface Dict In NotificationCoordinator Is Snapshot-Swept

### Community 509 - "start.mjs"
Cohesion: 0.70
Nodes (4): main(), runCommand(), selectWithArrows(), selectWithReadline()

### Community 510 - "graphify reference: extra exports and benchmark"
Cohesion: 0.50
Nodes (4): PaletteMode, errors, grep, normal

### Community 511 - ".panePathLookup"
Cohesion: 0.20
Nodes (7): State, error, indeterminate, paused, remove, set, TerminalProgressReport

### Community 512 - "Changelog Archive"
Cohesion: 0.10
Nodes (6): PromptQueue, String, SurfaceID, Void, PromptQueueBar, NSWindow

### Community 514 - "graphify reference: extra exports and benchmark"
Cohesion: 0.27
Nodes (7): Never, Set, String, Task, URL, Void, WorkspaceSymbolIndex

### Community 517 - ".testManyConcurrentSubscribersAllReceiveOutput"
Cohesion: 0.25
Nodes (6): String, URL, ThemeCatalogEmbedTests, .embedSwift, .repoRoot, .sourceJSON

### Community 521 - ".gestureRecognizer"
Cohesion: 0.50
Nodes (4): PresentAttempt, encodeFailure, nilDrawable, presented

### Community 522 - "ShellCompletionInstallerTests"
Cohesion: 0.27
Nodes (7): AmbientBackground, .body, Bool, CGSize, GraphicsContext, TimeInterval, UInt8

### Community 526 - "Kind"
Cohesion: 0.22
Nodes (9): ImmersivePalette, Motion, Radius, Spacing, SUI, CGFloat, Double, NSColor (+1 more)

### Community 527 - "Agent hooks for Harness"
Cohesion: 0.50
Nodes (3): Bug 1 - Hunks Button Has Explicit Size Constraints, Bug 1 - Hunks Button Symbol Has A Guaranteed-Valid Fallback, Build Compiles Successfully

### Community 528 - "worktree_review_dashboard.robot"
Cohesion: 0.50
Nodes (3): Guard A - Merge Call Site Never Passes --no-ff, Guard B - No Auto-Resolve Anywhere In The Merge/Conflict Path, Guard C - Merge Conflict State Is Reconciled, Not Just Read Once

### Community 530 - "HarnessChrome"
Cohesion: 0.29
Nodes (8): FormatColor, none, palette, rgb, StyledSegment, Bool, String, UInt8

### Community 531 - ".text"
Cohesion: 0.35
Nodes (3): ShellCompletionInstallerTests, String, URL

### Community 534 - "ANSIPalette"
Cohesion: 0.13
Nodes (11): Bool, NotificationEvent, agentFinished, agentWaiting, bell, commandFinished, .defaultEnabled, .detail (+3 more)

### Community 535 - "AgentNotification"
Cohesion: 0.17
Nodes (11): A — detection core (`AgentDetector`, pure logic), B — Claude Code Task-subagent hook push (in-process detection), C — IPC / Tab plumbing, Concurrency contract, Corrections to the original plan text (verified against live source, not assumed), D — Client UI indicator, Open items deferred out of this phase (documented, not silently dropped), P38 Phase B — Subagent/Teammate Visibility (+3 more)

### Community 538 - "SessionGroupHeaderRowView"
Cohesion: 0.06
Nodes (34): MainActor, Void, SessionDividerRowView, .init(coder:), .init(frame:), SessionGroupHeaderRowView, .init(coder:), .init(frame:) (+26 more)

### Community 539 - "install-app.sh"
Cohesion: 0.20
Nodes (4): SavedLayoutIPCDaemonTests, String, URL, UUID

### Community 540 - "TransportError"
Cohesion: 0.67
Nodes (3): TransportError, invalidUTF8Header, missingContentLength

### Community 544 - "Task Ledger Archive (Tasks 1–50)"
Cohesion: 0.51
Nodes (9): fuzzyFindFiles(), handleErrors(), handleFind(), handleGrep(), handleMake(), handleRecent(), Int32, String (+1 more)

### Community 546 - "LegacySnapshot"
Cohesion: 0.20
Nodes (4): Tab, TabID, WorkspaceID, TabAlertTests

### Community 547 - "NSObject"
Cohesion: 0.15
Nodes (16): ClosureTarget, MenuActionTarget, OverlayWindow, .canBecomeKey, Phase67UI, PopupWindow, Bool, Command (+8 more)

### Community 553 - "harness.resource"
Cohesion: 0.39
Nodes (5): AutomationSummary, Bool, Date, String, UUID

### Community 559 - "ScrollbackPersistenceTests"
Cohesion: 0.18
Nodes (3): String, URL, TaskIPCDaemonTests

### Community 570 - "CommandHistorySearchController"
Cohesion: 0.08
Nodes (27): CommandHistorySearchController, .tableView(_:heightOfRow:), .tableView(_:rowViewForRow:), .tableView(_:shouldSelectRow:), .tableView(_:viewFor:row:), HistoryItemView, .init(coder:), .init(command:query:) (+19 more)

### Community 578 - "TerminalProgressReport"
Cohesion: 0.21
Nodes (8): FileTreeKeyboardNavigator, FileTreeKeyboardState, Bool, NSEvent, String, Void, NSEvent, Observation

### Community 582 - "FileTreeKeyboardNavigator"
Cohesion: 0.22
Nodes (6): GitStatusProvider, Data, String, GitStatusProviderLargeOutputTests, URL, TimeoutError

### Community 586 - ".statusLineSet"
Cohesion: 0.17
Nodes (7): JSONOutputFormatter, Bool, String, T, WorkspaceSummary, JSONOutputFormatterTests, T

### Community 589 - "Endpoint"
Cohesion: 0.33
Nodes (4): GridCompositorCopyModeTests, PaneRect, String, TerminalGridSnapshot

### Community 596 - "prepare-release.sh"
Cohesion: 0.53
Nodes (4): display_menu(), run(), prepare-release.sh script, usage()

### Community 600 - "HarnessTerminalSurfaceView"
Cohesion: 0.05
Nodes (21): NSCursor, NSEvent, String, Any, NSMenu, NSMenuItem, KouenTerminalSurfaceView, .gridOriginPointsX (+13 more)

### Community 613 - "INDEX.md"
Cohesion: 0.18
Nodes (10): Current architecture relevant to these gaps, P38 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed), Phase A — Cross-agent diff/review dashboard (biggest gap vs Superset/Supacode) — ✅ DONE 2026-07-13, see p38-phase-a-diff-dashboard/{design.md,dev-task-progress.md}, Phase B — Subagent/teammate visibility as panes (vs cmux) — ✅ CLOSED 2026-07-16 (build/test/robot green, live check skipped per user decision), Phase C — Agent "thread" UX on top of existing block capture (vs Zed Terminal Threads) — ⚠️ pivoted 2026-07-15, ✅ CLOSED 2026-07-16 (build/test/robot green, cross-pane jump-to-block live check skipped per user decision), see p38-phase-c-thread-overlay/{design.md,dev-task-progress.md}, Phase D — Terminal image protocol (Kitty Graphics) — vs WezTerm — ✅ D1 DONE 2026-07-14 (finding: NOT deferred), D3 conformance slice built, ✅ CLOSED 2026-07-16 (build/test/robot green, real-client live check skipped per user decision), Phase E — Scripting hook parity (JS vs WezTerm's Lua) — low priority — ✅ DONE 2026-07-14, ✅ CLOSED 2026-07-16 (low-priority live check skipped per user decision), Phases (+2 more)

### Community 614 - "MainSplitViewController"
Cohesion: 0.10
Nodes (19): CGFloat, MainSplitViewController, .setSidebarVisible(_:), SplitChromeDelegate, .splitView(_:constrainMaxCoordinate:ofSubviewAt:), .splitView(_:constrainMinCoordinate:ofSubviewAt:), .splitView(_:effectiveRect:forDrawnRect:ofDividerAt:), .splitView(_:shouldAdjustSizeOfSubview:) (+11 more)

### Community 617 - "ScriptFileWatcher"
Cohesion: 0.10
Nodes (26): CodingKeys, activeSurfaceID, daemonSurfaceID, id, surfaceID, surfaces, PaneLeaf, .init(from:) (+18 more)

### Community 621 - "ViEngine"
Cohesion: 0.13
Nodes (6): ScreenPos, bottom, middle, top, KouenLSP, QuickLookUI

### Community 622 - "[1.3.0-vit] - 2026-06-06"
Cohesion: 0.50
Nodes (3): LiveResizeGeometry, Result, Bool

### Community 623 - "BrowserResponsePayload"
Cohesion: 0.13
Nodes (8): PaneNode, BrowserLeaf, URL, DaemonSyncServiceBrowserPaneMergeTests, PaneID, PaneNode, PaneNodeBrowserTests, PaneNodeLayoutShapeTests

### Community 624 - "[2.5.0] - 2026-06-12"
Cohesion: 0.25
Nodes (7): CopyModeLine, .charIndex(atOrAfter:), .charIndex(atOrBefore:), .lastContentColumn, .text, Character, String

### Community 627 - "ActiveTabCloseDisposition"
Cohesion: 0.29
Nodes (5): OutputTrigger, OutputTriggerStore, Bool, String, Data

### Community 629 - "graphify reference: query, path, explain"
Cohesion: 0.32
Nodes (6): CGFloat, ResizeDirection, down, left, right, up

### Community 637 - "ClientSummary"
Cohesion: 0.09
Nodes (11): Bool, NSDraggingInfo, NSDragOperation, TerminalGridCell, Bool, NSPasteboard, String, TerminalGridCell (+3 more)

### Community 641 - "[3.10.0] - 2026-06-27"
Cohesion: 0.25
Nodes (7): #kouen, #practice, #score, #shell, #total, #unix, #vim

### Community 645 - "stability_release.robot"
Cohesion: 0.28
Nodes (3): KouenMCP, KouenBrowserToolsTests, URL

### Community 646 - "[3.10.1] - 2026-06-27"
Cohesion: 0.24
Nodes (5): RiskyCommandClassifier, Bool, NSRegularExpression, String, RiskyCommandClassifierTests

### Community 648 - "PtyDrainCeilingBenchmark"
Cohesion: 0.18
Nodes (12): Counter, DrainResult, .bytesPerWakeup, .mbps, DrainState, EchoRTT, PtyDrainCeilingBenchmark, Bool (+4 more)

### Community 659 - "MCPServer"
Cohesion: 0.20
Nodes (4): Bool, Double, TerminalReplay, TerminalRecordingTests

### Community 661 - "Remote SSH — Market Comparison"
Cohesion: 0.33
Nodes (5): Kouen vs Competitors (Remote Development over SSH), Our Gaps (vs leaders), Our Strengths, Remote SSH — Market Comparison, Roadmap Opportunities

### Community 662 - "New Tab"
Cohesion: 0.20
Nodes (3): AutomationIPCDaemonTests, String, URL

### Community 664 - "P37 Phase G — Autocomplete (mobile bridge)"
Cohesion: 0.18
Nodes (10): cmd-F contract (C2) — contextual, not a rewrite of `updateFind`, Design: overlay, not a new render subtree, Known caveat (pre-existing, inherited not fixed), Open decisions (not decided here, confirm before Stage 4 if it matters), Original design (2026-07-14, deleted 2026-07-15 — kept for history only), P38 Phase C — Agent Thread UX on Existing Block Capture, Pivot (2026-07-15, mid live-test) — supersedes the original design below, Regression risk: near-zero by construction (+2 more)

### Community 666 - "BrowserIntegrationController"
Cohesion: 0.36
Nodes (7): CLICommand, CLICommandCatalog, .allInvocationNames, .canonicalNames, .jsonCommands, Bool, String

### Community 669 - ".recordReapedGenerationForTesting"
Cohesion: 0.26
Nodes (4): PaneLabelDaemonTests, String, URL, UUID

### Community 670 - "[3.9.1] - 2026-06-22"
Cohesion: 0.20
Nodes (6): LayoutTemplate, evenHorizontal, evenVertical, mainHorizontal, mainVertical, tiled

### Community 671 - "AgentKind"
Cohesion: 0.38
Nodes (5): Result, ShellRCWiring, Bool, String, URL

### Community 672 - "ColorKind"
Cohesion: 0.24
Nodes (9): DiagnosticCheck, DiagnosticStatus, fail, .label, pass, warn, DoctorReport, .exitCode (+1 more)

### Community 675 - ".detect"
Cohesion: 0.29
Nodes (6): Accessibility Identifiers Required, Architecture, Kouen Robot Framework Tests, Prerequisites, Run, Troubleshooting

### Community 685 - "[1.5.1] - 2026-06-06"
Cohesion: 0.33
Nodes (6): emitArray(), hex(), referenceWidth(), String, T, UInt8

### Community 694 - "TerminalScreen"
Cohesion: 0.29
Nodes (6): SecureInputMonitor, DispatchWorkItem, Set, String, SurfaceID, Carbon

### Community 696 - "TerminalTabBarDelegate"
Cohesion: 0.25
Nodes (7): Avoid, Colors, Components, Design Direction, Design System, Spacing / Radius / Motion, Typography

### Community 709 - ".start"
Cohesion: 0.12
Nodes (10): DecodedWSFrame, PipeBuffer, Data, Result, UInt8, WSFrameParseResult, frame, incomplete (+2 more)

### Community 710 - "MainWindowController"
Cohesion: 0.10
Nodes (14): KouenWindow, NSEvent, MainWindowController, Any, NSRect, CGFloat, NSColor, NSPoint (+6 more)

### Community 711 - "FileTabManager"
Cohesion: 0.22
Nodes (3): MobileBridgeSpawnTests, String, URL

### Community 713 - "AutomationScheduler"
Cohesion: 0.28
Nodes (3): String, URL, WorktreeMCPIPCDaemonTests

### Community 715 - "TerminalProgressReport"
Cohesion: 0.50
Nodes (3): String, URL, TreeSitterGrammarBundle

### Community 716 - "ReplayStep"
Cohesion: 0.38
Nodes (3): Bool, String, WorktreeInfoSummary

### Community 718 - "[2.4.0] - 2026-06-12"
Cohesion: 0.14
Nodes (14): .init(coder:), .init(frame:), HunkActionButton, .init(coder:), .init(title:onClick:), StageToggleButton, .init(coder:), .init(frame:) (+6 more)

### Community 727 - "PromptQueueBar"
Cohesion: 0.50
Nodes (3): __kouen_osc133_postexec, __kouen_osc133_preexec, __kouen_osc133_prompt

### Community 732 - "ReplayStep"
Cohesion: 0.50
Nodes (3): SplitDirection, horizontal, vertical

### Community 736 - "graphify reference: add a URL and watch a folder"
Cohesion: 0.25
Nodes (7): Core Features, Core Problems, Out of Scope, Product, Success Metrics, Target Users, Vision

### Community 737 - ".resolve"
Cohesion: 0.40
Nodes (4): #connect, #log, #term, tokenFromQR

### Community 745 - "p11_scripting.robot"
Cohesion: 0.20
Nodes (3): AgentRoutingRuleIPCDaemonTests, String, URL

### Community 760 - "skill-trigger.py"
Cohesion: 0.12
Nodes (13): Tab, AnyObject, TimeInterval, ZombieHoldRegistry, PaneLifecycleManager, Bool, NSView, PaneID (+5 more)

### Community 797 - "Motion"
Cohesion: 0.50
Nodes (3): Kouen Domain Language, MCP Surface, Relationships

### Community 865 - "MCPServer"
Cohesion: 0.29
Nodes (3): KouenMCPServer, MCPServer, String

### Community 961 - ".json"
Cohesion: 0.20
Nodes (5): ProjectTask, ProjectTaskDetector, String, GitHubCLIClientTests, String

### Community 991 - "Changed"
Cohesion: 0.22
Nodes (8): Build order (unchanged from interview decision), G1 — @ file-path picker, G2 — shell tab-completion suggestion strip (heuristic, explicitly best-effort), G3 — AI command suggestion (via `claude` CLI subprocess), Logical Design, P37 Phase G — Autocomplete (mobile bridge), Strategic Design, Tactical Design

### Community 1000 - "Changed"
Cohesion: 0.22
Nodes (8): Artifacts, Client Application — Slice 1 (stacked panes, no persistence), Client Application — Slice 2 (per-workspace divider memory), Context, Dev Task Progress — Workspace Sidebar Panels (P42), Integration, Note on task re-sequencing (2026-07-17), Summary

### Community 1109 - ".tomlKouenBlock"
Cohesion: 0.08
Nodes (23): InlineAICompletionController, KouenSettings, String, InputGate, .siblings, ReconnectLatch, .isTripped, SurfaceIO (+15 more)

### Community 1268 - "[2.2.2] - 2026-06-08"
Cohesion: 0.16
Nodes (11): SettingsAppearanceView, .autoTheme, .body, .themeSection, SliderRow, .body, .displayValue, Bool (+3 more)

### Community 1303 - ".pushAgentActivityNotifications"
Cohesion: 0.50
Nodes (3): exclude_hubs, no_viz, wiki

### Community 1309 - ".startMetadataRefresh"
Cohesion: 0.83
Nodes (3): entries(), cheat.sh script, usage()

### Community 1544 - "TargetSpec.swift"
Cohesion: 0.25
Nodes (8): CodingKeys, cols, createdAt, dataBase64, rows, timeMs, type, version

### Community 1801 - "ClientSummary"
Cohesion: 0.22
Nodes (5): Completed Plans Archive, Active Plans, Completed, Plans Index — kouen-terminal, Quick ref — recent completions

### Community 1832 - "Added"
Cohesion: 0.25
Nodes (7): Claude Code hook push (in-process Task subagent detection), Client UI indicator, Detection core (AgentDetector, pure logic), IPC / Tab plumbing, P38 Phase B — Subagent Visibility — Dev Task Progress, Status: Rewritten 2026-07-14 after original implementation (tasks 1-5) was lost to a concurrent git operation before commit. Closed 2026-07-16 on user instruction, live check skipped., Summary

### Community 1914 - "P43 — Add Repo/Folder to Workspace"
Cohesion: 0.25
Nodes (7): Original overlay build (built 2026-07-14, gated green, then deleted 2026-07-15 mid live-test), P38 Phase C — Agent Thread UX on Existing Block Capture — Dev Task Progress, Pivot — merge into the Recipes picker (2026-07-15), Stage 1-2 — Engine/surface plumbing (built 2026-07-14, unchanged by the pivot, still in use), Status: Implementation pivoted mid-phase from a standalone overlay to a merge into the existing, Summary, Thread grouping — Zed framing folded into the same picker (2026-07-15)

### Community 1933 - ".load"
Cohesion: 0.25
Nodes (6): Kind, path, stack, Bool, Date, UUID

### Community 1943 - "ITerm2InlineImage"
Cohesion: 0.25
Nodes (8): Docs, kouen-mcp, KouenCore, KouenDaemon, KouenIPC, P41 — Automations — Task Progress, Tests, Verification

### Community 2014 - "Added"
Cohesion: 0.36
Nodes (7): Document, Bool, Set, String, URL, ToolPolicy, .defaultURL

### Community 2100 - ".handleWake"
Cohesion: 0.10
Nodes (19): .exit, String, String, String, String, KouenCLI, SessionID, String (+11 more)

### Community 2176 - "Changed"
Cohesion: 0.29
Nodes (6): Locked decisions (user-confirmed), Logical Design, P38 Phase A — Cross-Agent Worktree Diff/Review Dashboard — Design, Strategic Design, Tactical Design, Verification gate (this phase)

### Community 2242 - "P42 — Workspace Sidebar Panels"
Cohesion: 0.29
Nodes (6): Logical Design, Next Step, P42 — Workspace Sidebar Panels, Parked (not in scope), Strategic Design, Tactical Design

### Community 2541 - "P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable"
Cohesion: 0.18
Nodes (11): Competitive comparison (2026-07-13, post Phase D+E), Current architecture (as shipped, build 195), P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable, Phase A — Hardening (daemon only, no UI), Phase B — In-app pairing UX (macOS Settings), Phase C — Real mobile client (W3, replaces smoke-test page) — DONE 2026-07-09, uncommitted, Phase D — File preview, file attach, browser mirror (v1.1 — the former W4/W4b/W5, now scoped), Phase F — candidates from competitive research (not scoped, not scheduled) (+3 more)

### Community 2573 - "P38 Phase D — Kitty Graphics Conformance Slice"
Cohesion: 0.33
Nodes (5): Gate, Implementation, P38 Phase D — Kitty Graphics Conformance Slice, Scope (locked), Tests

### Community 2633 - "P38 Phase E — Scripting Hook Parity (JS vs WezTerm's Lua)"
Cohesion: 0.33
Nodes (5): Gate, Implementation, P38 Phase E — Scripting Hook Parity (JS vs WezTerm's Lua), Scope (locked), Tests

### Community 2639 - "P41 — Automations"
Cohesion: 0.33
Nodes (4): Logical Design, P41 — Automations, Strategic Design, Tactical Design

### Community 2642 - "P43 — Add Repo/Folder to Workspace"
Cohesion: 0.33
Nodes (5): Logical Design, Next Step, P43 — Add Repo/Folder to Workspace, Strategic Design, Tactical Design

### Community 2735 - "BlockSummary"
Cohesion: 0.08
Nodes (20): RealPty, .init(forTesting:), .init(id:cwd:shell:rows:cols:scrollbackBytes:extraEnvironment:termProgram:termProgramVersion:scrollbackURL:), ScrollbackEntry, ScrollbackReplaySegment, Bool, CChar, DaemonSurfaceID (+12 more)

### Community 3131 - "P38 Phase D — Kitty Conformance — Dev Task Progress"
Cohesion: 0.50
Nodes (3): P38 Phase D — Kitty Conformance — Dev Task Progress, Status: Implementation complete, build/test/robot green. Closed 2026-07-16 on user instruction, live check skipped., Summary

### Community 3132 - "P38 Phase E — Scripting Hooks — Dev Task Progress"
Cohesion: 0.50
Nodes (3): P38 Phase E — Scripting Hooks — Dev Task Progress, Status: Implementation complete, build/test/robot green. Closed 2026-07-16 on user instruction, live check skipped (was already lowest priority of B/C/D/E)., Summary

### Community 3135 - "Phase 0 — Swift 6.3+ Concurrency Safety (P0, LESSONS FROM macOS 26.5 CRASH SAGA)"
Cohesion: 0.67
Nodes (3): Phase 0 — Swift 6.3+ Concurrency Safety (P0, LESSONS FROM macOS 26.5 CRASH SAGA), Rules (enforced, not optional), Verification checklist for macOS 27 beta

### Community 3419 - "Page"
Cohesion: 0.25
Nodes (6): AboutPanelController, AboutView, .body, MonoPillButtonStyle, Configuration, NSWindow

### Community 3515 - "RawRepresentable"
Cohesion: 0.10
Nodes (23): Binding, .init(from:), .init(spec:command:note:repeatable:), CodingKeys, bindings, disabledSpecs, id, tables (+15 more)

## Knowledge Gaps
- **3510 isolated node(s):** `AppIntents`, `noActivePane`, `.localizedStringResource`, `horizontal`, `vertical` (+3505 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1575 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.
- **15 possibly unreachable function(s):** `.addSurface(tabID:paneID:)`, `.agentInfo(forWorktreePath:tabs:)`, `.block(atPromptLine:)`, `.block(atPromptLine:)`, `.blocks` (+10 more)
  Not reached from any recognized entry point - could be dead code, or dynamically dispatched/decorator-registered.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Int` connect `code:bash (# Terminal 1: Create workspace with long-running job)` to `Changelog Archive`, `callingPaneTarget`, `graphify reference: extra exports and benchmark`, `EngineConformanceTests`, `IPCRequest`, `AgentNotchRootView`, `LSPMessage`, `TerminalEmulator`, `PerformanceBenchmarks`, `GitPanelView.swift`, `VTParser`, `HarnessTerminalSurfaceView`, `.applyPreedit`, `MetalRendererTests`, `HarnessUILibrary`, `SpecialKey`, `HarnessChrome`, `CopyModeAction`, `SplitPaneCoordinator`, `.request`, `WorktreeManager`, `Harness tmux-style capabilities`, `SessionGroupHeaderRowView`, `.readGrid(scrollbackOffset:)`, `.init`, `Notification`, `Sendable`, `.bufferLine`, `Equatable`, `.addTab`, `.characterIndex`, `MenuTarget`, `Task Ledger Archive (Tasks 1–50)`, `HarnessSettings`, `CodingKeys`, `HarnessSidebarPanelViewController.swift`, `RenderSchedulerTests`, `harness.resource`, `.buildCommand`, `.normalizedKey`, `DaemonServer`, `.keyEvent`, `.handleWake`, `HarnessSplitView`, `TabCell`, `CommandHistorySearchController`, `PasteBufferStore`, `FrecencyDirectoryStore`, `ComposedCell`, `HarnessCLI+Server.swift`, `TerminalProgressReport`, `worktree_isolation_cli.robot`, `XCTestCase`, `.statusLineSet`, `.parse`, `Endpoint`, `HarnessDesign`, `.firstMatch`, `LSPClient`, `TerminalGridCell`, `HarnessPaths`, `.tomlKouenBlock`, `HarnessTerminalSurfaceView`, `TerminalModes`, `P2 — Async IPC Refactor: Design Document`, `AttachInputBatcher`, `shim.c`, `.dispatch`, `ScriptRuntime.swift`, `Session Grouping and Split Session Plan`, `MainSplitViewController`, `DaemonLauncher`, `Recipe`, `AnyCodable`, `domain-design.md`, `AgentNotchViewModel`, `DamageTrackingTests`, `SoftIconButton`, `code:text (:workbench start swift)`, `.makeSnapshot`, `[2.5.0] - 2026-06-12`, `HarnessGridTerminal`, `.encode`, `.firstWaitingTab`, `graphify reference: query, path, explain`, `WorkspaceFileTreeView`, `[1.3.0-vit] - 2026-06-06`, `ViEngine`, `Pipe`, `String`, `ClientSummary`, `HistoryRingBuffer`, `GlyphAtlas`, `code:block1 (SessionCoordinator.snapshot ──┐)`, `.install`, `AgentHookInstaller`, `.startWatching`, `PtyDrainCeilingBenchmark`, `User Story Mapping (MANDATORY)`, `RGBColor`, `CopyModeGridSource`, `How to use Harness from the terminal only (no GUI)`, `PaneStyleSet`, `AsciiFastPathTests`, `MCPServer`, `Community None`, `What You Must Do When Invoked`, `LiveResizeTests`, `Int`, `ThaiCombiningMarkTests`, `MatchCategory`, `What You Must Do When Invoked`, `Workspace`, `CommandPromptController`, `URLDetection`, `[1.5.1] - 2026-06-06`, `BinaryRefresherTests`, `BlockSummary`, `InlineAICompletionView`, `[3.13.1] - 2026-07-02`, `VTConformanceCorpusTests`, `GridCompositorTests`, `P25 — iOS/iPadOS Support`, `SessionSnapshot`, `AppDelegate`, `user-stories.md`, `GlyphRasterizer`, `BinaryInstaller`, `Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag`, `ResizeHUDView`, `AgentSessionSummary`, `.classify`, `.start`, `MCP Server (harness-mcp)`, `[3.9.5] - 2026-06-26`, `HarnessCLI`, `scheduleRender`, `.testDataFrameEncodeVsJSONBase64Output`, `PaneTarget`, `NotchLayoutMetrics`, `GridCompositor`, `Prompt`, `TerminalServicesProvider`, `SSHTunnelManagerTests`, `ExternalOpenKind`, `WorkbenchCommand`, `TerminalMetalRenderer`, `PaneBorderStatus`, `[3.5.1] - 2026-06-20`, `.make`, `ThemeDocumentTests`, `ReflowPreviewTests`, `SessionCoordinator`, `BoardViewController`, `workspace`, `release-hotfix.sh`, `WindowTitleStripView`, `.welcome`, `.install`, `HarnessSidebarPanelViewController`, `.path`, `DefaultTerminalManager`, `WindowSession`, `StatusLineView.swift`, `[2.5.0] - 2026-06-12`, `SyntaxTextView`, `.run`, `DisplayPanesOverlay`, `TerminalScrollbarView`, `FormatColor`, `click_ui_element`, `code:bash (harness-cli install-hooks hermes)`, `AgentHookStrategy`, `StatusLineWidthTests`, `Process`, `JSONDecoder`, `Fixes Applied (layered)`, `NotificationBus`, `settings.json`, `jobs`, `PaneNode`, `HarnessPaths.swift`, `.parse`, `AgentSnapshot`, `Terminal AI Chat (⌘I inline overlay)`, `UInt64`, `DesktopNotifier`, `LayoutNode`, `.theme`, `RealPty`, `ImageProtocolTests.swift`, `code:bash (harness-cli install-hooks pi)`, `FileViewerViewController`, `Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)`, `SurfaceProgressTracker`, `.handleCat`, `[3.5.1] - 2026-06-20`, `FormatStyledSegment.swift`, `[2.2.4] - 2026-06-11`, `Fixes Applied (v3.9.1+)`, `Consumers`, `DaemonStats`, `Git Panel`, `P13 — Embedded Browser Pane (cmux parity)`, `.run`, `.install`, `SurfaceProgressTrackerTests.swift`, `NSTextField Leak in BoardViewController (P20 Performance)`, `User Profile`, `.load`, `main.swift`, `Session/Tab/Pane Hierarchy & Top Bar (CASE-028)`, `go.json`, `json.json`, `.refreshSurfaceMetadata`, `rust.json`, `yaml.json`, `HintModeOverlay`, `.delay`, `PathToken`, `Project History`, `.init`, `SessionEditor`, `LegacySnapshot`, `RemoteHostStore`, `GroupedSessionDaemonTests`, `main.swift`, `PaletteMode`, `PresentAttempt`, `SessionCoordinator.swift`, `tmux parity — status, adaptations, and deliberate divergences`, `TerminalModes`, `DispatchTime`, `HarnessOnboarding`, `.hitTest`, `Added`, `ScrollbackTests`, `Command Prompt Architecture`, `.testKouenRendererFixtureDefaultTextReportsPlausibleGlyphStats`, `ccRunCancel`, `ccRuns`, `.routingRuleList`, `.json`, `Build Scripts Self-Kill Protection`, `.panePathLookup`?**
  _High betweenness centrality (0.297) - this node is a cross-community bridge._
- **Why does `KouenCore` connect `.recordReapedGenerationForTesting` to `Changelog Archive`, `.handleNormal`, `IPCRequest`, `Command`, `.gestureRecognizer`, `HarnessTerminalSurfaceView`, `.applyPreedit`, `MetalRendererTests`, `HarnessUILibrary`, `SpecialKey`, `.text`, `code:block1 (Agent shell process)`, `.request`, `WorktreeManager`, `Harness tmux-style capabilities`, `SessionGroupHeaderRowView`, `install-app.sh`, `Sendable`, `Task Ledger Archive (Tasks 1–50)`, `Equatable`, `LegacySnapshot`, `NSObject`, `String`, `HarnessSettings`, `CodingKeys`, `RenderSchedulerTests`, `HarnessTerminalSurfaceView.swift`, `.buildCommand`, `.normalizedKey`, `ScrollbackPersistenceTests`, `DaemonServer`, `.keyEvent`, `.handleWake`, `HarnessSplitView`, `NSPanel`, `CommandHistorySearchController`, `ViEngine`, `HarnessCLI+Server.swift`, `TerminalProgressReport`, `Completed Plans Archive`, `.compose`, `FileTreeKeyboardNavigator`, `worktree_isolation_cli.robot`, `.statusLineSet`, `.parse`, `TerminalProtocolCompatibilityTests`, `Endpoint`, `HarnessDesign`, `LSPClient`, `LSPDiagnostic`, `.tomlKouenBlock`, `TerminalGridCell`, `SessionCoordinator`, `TerminalModes`, `AttachInputBatcher`, `shim.c`, `Harness Usage`, `PaneContainerView`, `4. Technical Architecture`, `.dispatch`, `Changelog`, `AgentNotchViewModel`, `.resolve`, `ViEngine`, `SoftIconButton`, `BrowserResponsePayload`, `.makeSnapshot`, `DamageTrackingTests`, `.firstWaitingTab`, `.encode`, `SessionGroup`, `PaneNode`, `WorkspaceFileTreeView`, `Pipe`, `code:block1 (SessionCoordinator.snapshot ──┐)`, `.install`, `stability_release.robot`, `code:js (// ~/.config/harness/init.js)`, `ActivePaneService`, `User Story Mapping (MANDATORY)`, `แผนงานการสร้างระบบพรีวิวและแสดงผลไฟล์ (File Viewer & Preview Integration Plan)`, `.testPaneLeafLegacyDecodeBackfillsSurfaceTabs`, `How to use Harness from the terminal only (no GUI)`, `DecodedImage`, `FileTreeWatcher`, `TriState`, `EnvironmentStore`, `MCPServer`, `Community None`, `New Tab`, `What You Must Do When Invoked`, `ThaiCombiningMarkTests`, `.recordReapedGenerationForTesting`, `Harness Terminal — IDE Sidebar Feature Branch`, `AmbientBackground`, `ActiveTabCloseDisposition`, `AgentTableEntry`, `ReflowCorpusTests`, `.decodeKeySpec`, `BlockSummary`, `Added`, `.rects`, `InlineAICompletionView`, `GridCompositorTests`, `TerminalScreen`, `Error`, `AppDelegate`, `ScriptRuntime`, `[2.3.0] - 2026-06-11`, `Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag`, `[2.5.1] - 2026-06-12`, `MainWindowController`, `.classify`, `FileTabManager`, `MCP Server (harness-mcp)`, `PaletteModel`, `AutomationScheduler`, `CopyModeState`, `PaneDropZoneOverlay`, `.translate`, `.lines`, `CellColorResolverTests`, `GridCompositor`, `Prompt`, `Section`, `HarnessPathDisplay`, `sessionRow`, `TextGrid`, `.scan`, `WorkbenchCommand`, `p11_scripting.robot`, `.make`, `AgentBridge`, `.make`, `FileNode`, `ThemeDocumentTests`, `.renderFixture`, `skill-trigger.py`, `DaemonMetrics`, `HarnessTerminalSurfaceWorkerTests`, `[3.4.0] - 2026-06-19`, `ReflowPreviewTests`, `Split Right`, `Sidebar SwiftUI Migration — Knowledge`, `ThemeFileServiceTests`, `Browser Pane (P14)`, `.install`, `KeySpec`, `[2.5.0] - 2026-06-12`, `DisplayPanesOverlay`, `TerminalScrollbarView`, `code:bash (harness-cli install-hooks hermes)`, `.apply`, `.load`, `NotificationBus`, `PaneNode`, `ThemeDiagnostics`, `.encodeMouse`, `Send Ex Command`, `Bug: Tab-Switch Black Screen`, `Terminal AI Chat (⌘I inline overlay)`, `code:bash (# In a Harness pane:)`, `FormatColor`, `DesktopNotifier`, `WorkspaceSymbolIndex`, `.theme`, `README.md`, `RealPty`, `CommandExecutionError`, `CSIParams`, `Foundation`, `[2.2.3] - 2026-06-09`, `FileViewerViewController`, `DaemonLifecycleTests`, `Background Polling & Snapshot Fanout — P22`, `Architecture Decisions — harness-terminal`, `Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)`, `GPU Animation Pattern — Layout Once, GPU Paints`, `MCPServer`, `SurfaceProgressTracker`, `.handleCat`, `State`, `FormatStyledSegment.swift`, `RGBColor`, `generate-cheatsheet.js`, `Consumers`, `Tab`, `.encode`, `.install`, `ScrollReuseTests`, `Identifiable`, `ThaiClusterRenderTests`, `SKILL-LOG.md`, `User Profile`, `Darwin`, `UI Automation — Robot Framework (P18)`, `View`, `PresentAttempt`, `Split Panes (NSSplitView)`, `IPC Architecture`, `markdown.json`, `.refreshSurfaceMetadata`, `RealPtyLifecycleTests`, `yaml.json`, `FilePreviewCoordinatorTabScopeTests`, `HintModeOverlay`, `TaskDashboardView`, `BoardCardView`, `LaunchdServiceInstaller`, `PickerItemRow`, `LegacySnapshot`, `BlockContextMenuTests`, `.json`, `.deinit`, `ReflowFastPathTests`, `Never`, `PresentAttempt`, `HarnessOnboarding`, `Added`, `Changed`, `.json`, `ACP Client (Shelved)`, `Build Scripts Self-Kill Protection`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Why does `KouenTerminalSurfaceView` connect `HarnessTerminalSurfaceView` to `callingPaneTarget`, `TerminalEmulator`, `press_shortcut`, `HarnessTerminalSurfaceView`, `Community None`, `IPC Architecture`, `LiveResizeTests`, `RGBColor`, `.addTab`, `.characterIndex`, `Process`, `BoardCard`, `VTConformanceCorpusTests`, `SessionEditor`, `.init(coder:)`, `PasteBufferStore`, `RawRepresentable`, `PresentAttempt`, `TerminalModes`, `MCP Server (harness-mcp)`, `Harness keybindings`, `.firstMatch`, `Foundation`, `code:bash (harness-cli install-hooks pi)`, `.tomlKouenBlock`, `code:bash (# Terminal 1: Create workspace with long-running job)`, `CellColorResolver`, `.testKouenRendererFixtureDefaultTextReportsPlausibleGlyphStats`, `.dispatch`, `DaemonLauncher`, `.scan`, `Service Decomposition — SessionCoordinator (P17)`, `DaemonStats`, `Git Panel`, `ActiveTabCloseDisposition`, `Build Scripts Self-Kill Protection`, `ViEngine`, `ClientSummary`, `.panePathLookup`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Are the 18 inferred relationships involving `KouenTerminalSurfaceView` (e.g. with `InputEncoder` and `RenderScheduler`) actually correct?**
  _`KouenTerminalSurfaceView` has 18 INFERRED edges - model-reasoned connections that need verification._
- **What connects `AppIntents`, `noActivePane`, `.localizedStringResource` to the rest of the system?**
  _3530 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CodingKey` be split into smaller, more focused modules?**
  _Cohesion score 0.11895161290322581 - nodes in this community are weakly interconnected._
- **Should `callingPaneTarget` be split into smaller, more focused modules?**
  _Cohesion score 0.14840182648401826 - nodes in this community are weakly interconnected._