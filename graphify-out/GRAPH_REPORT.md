# Graph Report - kouen-terminal  (2026-08-19)

## Corpus Check
- 782 files · ~818,353 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 14780 nodes · 35018 edges · 3025 communities (902 shown, 2123 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 3946 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6ebf1320`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## God Nodes (most connected - your core abstractions)
1. `SurfaceRegistry` - 197 edges
2. `IPCRequest` - 191 edges
3. `SessionEditor` - 180 edges
4. `DaemonClient` - 176 edges
5. `AnyCodable` - 163 edges
6. `SessionCoordinator` - 131 edges
7. `JSONRPCError` - 126 edges
8. `KouenTerminalSurfaceView` - 125 edges
9. `KouenPaths` - 122 edges
10. `AgentKind` - 108 edges

## Cross-Cutting Nodes (span the most distinct areas of the codebase)
A high-degree node isn't always architecturally central - a widely-used
utility/config file can rack up more edges than a real coupler while only
ever touching one area. This ranks by how many DIFFERENT communities a
node's neighbors span, not by raw edge count.
1. `IPCRequest` - bridges 174 areas (191 edges)
2. `Command` - bridges 100 areas (107 edges)
3. `IPCResponse` - bridges 76 areas (94 edges)
4. `SessionCoordinator` - bridges 61 areas (131 edges)
5. `SurfaceRegistry` - bridges 58 areas (197 edges)
6. `MenuTarget` - bridges 58 areas (68 edges)
7. `KouenPaths` - bridges 56 areas (122 edges)
8. `AgentKind` - bridges 55 areas (108 edges)
9. `EngineConformanceTests` - bridges 50 areas (76 edges)
10. `SpecialKey` - bridges 49 areas (56 edges)

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

## Import Cycles
- None detected.

## Communities (3025 total, 2123 thin omitted)

### Community 0 - "CodingKey"
Cohesion: 0.13
Nodes (19): BoardCard, BoardColumn, BoardColumnKind, done, error, idle, needsAttention, running (+11 more)

### Community 1 - "callingPaneTarget"
Cohesion: 0.17
Nodes (10): TerminalDamage, MetalRendererTests, RenderedFixture, MTLTexture, RenderColor, StaticString, String, TerminalGridSnapshot (+2 more)

### Community 2 - ".handleNormal"
Cohesion: 0.20
Nodes (7): Recipe, RecipesStore, Bool, String, URL, UUID, RecipesStoreTests

### Community 4 - "EngineConformanceTests"
Cohesion: 0.10
Nodes (11): DaemonRoundTripTests, Data, Int32, String, TimeInterval, URL, RealPtyLifecycleTests, AtomicCounter (+3 more)

### Community 5 - "IPCRequest"
Cohesion: 0.08
Nodes (24): header, String, UInt16, DecodedReplyFrame, output, reply, DecodedRequestFrame, input (+16 more)

### Community 6 - "AgentNotchRootView"
Cohesion: 0.08
Nodes (25): AnyTransition, AnyView, AgentNotchPeekEvent, AgentNotchRootView, Container, .init(coder:), .init(frame:), HorizontalInsetRect (+17 more)

### Community 7 - "Command"
Cohesion: 0.09
Nodes (28): AppEnum, AppIntent, AppIntents, GetTerminalOutputIntent, KouenIntentError, noActivePane, workspaceNotFound, KouenShortcutsProvider (+20 more)

### Community 8 - "LSPMessage"
Cohesion: 0.10
Nodes (11): .addSurface(tabID:paneID:), .tab(containingPaneID:), .tab(forSurfaceKey:), .tabIndex(surfaceID:), .tabIndex(surfaceKey:), .tabIndex(workspaceID:tabID:), Date, String (+3 more)

### Community 9 - "TerminalEmulator"
Cohesion: 0.11
Nodes (13): colors, PerformanceBenchmarks, SurfaceMainThreadStallSample, SurfaceOffMainStallSample, Bool, Data, Double, String (+5 more)

### Community 10 - "PerformanceBenchmarks"
Cohesion: 0.13
Nodes (15): IndexingIterator, LayoutTemplate, surfaceID, .addSurface(to:paneID:surfaceID:cwd:), .split(node:targetPaneID:direction:paneCount:before:), .split(node:targetPaneID:with:direction:beforeTarget:), .surfaceID(forPaneID:in:), Bool (+7 more)

### Community 11 - "GitPanelView.swift"
Cohesion: 0.10
Nodes (10): SessionCoordinator, Bool, Error, PaneNode, SessionID, SplitDirection, String, SurfaceID (+2 more)

### Community 13 - "KittyKeyboardTests"
Cohesion: 0.08
Nodes (18): KeyRecorderView, .init(coder:), .init(initial:), Any, Bool, NSCoder, NSEvent, NSPoint (+10 more)

### Community 14 - "VTParser"
Cohesion: 0.16
Nodes (7): Data, UInt8, UnsafeBufferPointer, VTParser, .feed(_:), VTParserHandler, UnsafeRawPointer

### Community 15 - "HarnessTerminalSurfaceView"
Cohesion: 0.11
Nodes (8): SessionEditor, .surfaceID(forPaneID:), AgentSessionSummaryTests, SessionEditorPhase4Tests, PaneID, TabID, WorkspaceID, SessionEditorTests

### Community 16 - ".applyPreedit"
Cohesion: 0.05
Nodes (44): Decodable, AssistantLine, ClaudeCodeHarness, Content, Message, Profile, edit, readonly (+36 more)

### Community 17 - "MetalRendererTests"
Cohesion: 0.17
Nodes (8): ScrollbackFile, Bool, Data, DispatchWorkItem, URL, ScrollbackFileTests, String, URL

### Community 18 - "HarnessUILibrary"
Cohesion: 0.12
Nodes (24): DaemonSubscription, .start(onData:onEnd:buffered:), .start(onResponse:onEnd:), Bool, Data, Int32, TimeInterval, UInt64 (+16 more)

### Community 19 - "SpecialKey"
Cohesion: 0.18
Nodes (11): LSPDiagnostic, LSPDiagnosticSeverity, error, hint, information, warning, LSPHover, LSPLocation (+3 more)

### Community 20 - "code:block1 (Agent shell process)"
Cohesion: 0.24
Nodes (5): KouenBrowserTools, Bool, Double, String, TimeInterval

### Community 21 - "HarnessTerminalSurfaceView"
Cohesion: 0.08
Nodes (18): KouenTerminalSurfaceView, Any, Bool, CGFloat, NSDraggingInfo, NSDragOperation, NSEvent, NSMenu (+10 more)

### Community 22 - "CopyModeAction"
Cohesion: 0.08
Nodes (8): HistoryLine, ImagePlacement, RewrapResult, Bool, TerminalCellWidth, TerminalGridCell, UnsafeBufferPointer, TerminalScreen

### Community 23 - "SplitPaneCoordinator"
Cohesion: 0.12
Nodes (16): OptionStore, OptionStore.Value, Scope, pane, session, workspace, ScopedKey, Bool (+8 more)

### Community 24 - ".request"
Cohesion: 0.13
Nodes (14): DaemonSyncService, .logIfFailed(_:), .request(_:), .sync(metadataOnly:), Bool, Never, SessionCoordinator, SessionSnapshot (+6 more)

### Community 25 - "WorktreeManager"
Cohesion: 0.08
Nodes (23): LSPFileSession, Never, String, Task, URL, Void, URL, SyntaxDefinitionTarget (+15 more)

### Community 26 - "Harness tmux-style capabilities"
Cohesion: 0.08
Nodes (18): ActivePaneService, .surfaceID(forPane:in:), .surfaceID(forPaneID:in:), Bool, PaneID, PaneNode, SessionCoordinator, Set (+10 more)

### Community 27 - "RGBColor"
Cohesion: 0.15
Nodes (5): RenderScheduler, Bool, Void, RenderSchedulerTests, Bool

### Community 28 - ".parse"
Cohesion: 0.18
Nodes (6): ParsedShortcut, PrefixKeymap, Any, NSEvent, String, TimeInterval

### Community 30 - "Notification"
Cohesion: 0.12
Nodes (10): Bool, Data, String, UInt8, UnsafeBufferPointer, TerminalEmulator, .captureLines(fromLine:toLine:), .captureLines(joinWrapped:) (+2 more)

### Community 31 - "Sendable"
Cohesion: 0.16
Nodes (9): CommandPromptController, KeyablePanel, Bool, NSControl, NSPanel, NSTextView, Selector, String (+1 more)

### Community 32 - ".addTab"
Cohesion: 0.13
Nodes (8): KouenTerminalSurfaceView, CGFloat, CGRect, NSEvent, NSPoint, Range, String, UInt16

### Community 33 - "Equatable"
Cohesion: 0.14
Nodes (11): DisplayMessage, MainExecutor, RunShell, Bool, Command, MainActor, PaneID, PaneNode (+3 more)

### Community 34 - "DaemonClient"
Cohesion: 0.17
Nodes (9): LSPServerConfiguration, LSPServerRegistry, LSPSettings, Bool, String, URL, LSPServerRegistryTests, String (+1 more)

### Community 35 - "MenuTarget"
Cohesion: 0.16
Nodes (4): TerminalEmulator, TerminalGridCell, TerminalGridSnapshot, ThaiCombiningMarkTests

### Community 36 - "code:bash (harness chat "Use the project map first, then inspect this r)"
Cohesion: 0.23
Nodes (5): SessionSnapshot, BoardCommandTests, BoardModelTests, SessionSnapshot, Tab

### Community 37 - "String"
Cohesion: 0.08
Nodes (23): DragDiagnostics, DispatchSourceTimer, String, PaneDragController, Any, Bool, NSEvent, NSView (+15 more)

### Community 39 - "TerminalColorGamut"
Cohesion: 0.19
Nodes (11): NWEndpoint, NWListener, BrowserOkAck, ConnectionState, ErrorAck, MobileBridgeServer, Data, NWConnection (+3 more)

### Community 40 - "HarnessSettings"
Cohesion: 0.13
Nodes (10): Run, Data, ReleaseNotes, String, TerminalBanner, WelcomeConfig, Data, ReleaseNotes (+2 more)

### Community 41 - "CodingKeys"
Cohesion: 0.15
Nodes (17): ClientRecord, CountBox, DaemonServer, PendingBrowserRequest, PendingWrite, Bool, CheckedContinuation, Data (+9 more)

### Community 42 - "HarnessSidebarPanelViewController.swift"
Cohesion: 0.16
Nodes (15): CommandParseError, emptyInput, expectedCommand, invalidArgument, missingArgument, missingFlag, unknownCommand, unterminatedString (+7 more)

### Community 43 - "RenderSchedulerTests"
Cohesion: 0.18
Nodes (13): AgentIconRenderer, Scanner, SVGPathParser, Bool, CGFloat, CGPath, CGPoint, Character (+5 more)

### Community 44 - "HarnessOverlayBackground"
Cohesion: 0.04
Nodes (45): Already portable or mostly portable, Build matrix, Competitive Landscape (research 2026-07-04), Current Architecture Fit, D1: Transport model (P0 gate), D2: Renderer reuse boundary (P0 gate), D3: Local terminal support (explicitly deferred), Design: mobile session switcher (2026-07-04/05, recovered 2026-07-06) (+37 more)

### Community 45 - "HarnessTerminalSurfaceView.swift"
Cohesion: 0.15
Nodes (11): Process, SSHTunnelManager, .init(makeTunnelProcess:reachabilityProbe:), Bool, RemoteHost, URL, Tunnel, SSHTunnelManagerTests (+3 more)

### Community 46 - ".buildCommand"
Cohesion: 0.08
Nodes (25): EndpointError, connectionFailed, notYetSupported, pathTooLong, String, EndpointConnector, Int32, String (+17 more)

### Community 47 - ".normalizedKey"
Cohesion: 0.16
Nodes (9): Array, RecipePanel, RecipePickerController, RecipePickerFooter, RecipePickerView, RecipeWindowDelegate, Bool, Element (+1 more)

### Community 48 - "HookEvent"
Cohesion: 0.15
Nodes (12): Executor, Hook, HookEvent, HookRegistry, Bool, Command, URL, UUID (+4 more)

### Community 49 - "DaemonServer"
Cohesion: 0.13
Nodes (5): CommandIPCTranslatorTests, Bool, CommandTarget, PaneID, TabID

### Community 51 - ".keyEvent"
Cohesion: 0.12
Nodes (23): CopyModeMatch, ColorKind, bg, fg, underline, CompositorPane, GridCompositor, .render(panes:status:statusSegments:) (+15 more)

### Community 54 - "HarnessSplitView"
Cohesion: 0.05
Nodes (48): AgentBridge, AgentTarget, Bool, String, SurfaceID, LinePos, end, firstNonBlank (+40 more)

### Community 55 - "TabCell"
Cohesion: 0.20
Nodes (5): AnyCodable, JSONRPCError, Int32, String, ToolRegistry

### Community 56 - "NSPanel"
Cohesion: 0.16
Nodes (10): QuickTerminalController, QuickTerminalPanelDelegate, Any, Bool, NSEvent, NSPanel, NSRect, NSScreen (+2 more)

### Community 57 - "BellScanState"
Cohesion: 0.06
Nodes (32): ISO8601DateFormatter, KouenTask, Bool, Date, SessionID, String, URL, UUID (+24 more)

### Community 58 - "PasteBufferStore"
Cohesion: 0.11
Nodes (33): MTLClearColor, MTLCommandBuffer, MTLRenderCommandEncoder, TerminalFrame, BgInstance, CursorCacheKey, DecoInstance, EncodedFrameInstances (+25 more)

### Community 59 - "3.2 สิ่งที่ implement แล้ว"
Cohesion: 0.17
Nodes (6): KouenSidebarPanelViewController, CGFloat, NSMenuItem, NSView, SessionGroup, String

### Community 60 - "ViEngine"
Cohesion: 0.13
Nodes (5): SessionPersistenceTests, Bool, String, TabID, URL

### Community 61 - "FrecencyDirectoryStore"
Cohesion: 0.13
Nodes (21): ColorKind, bg, fg, underline, ComposedCell, .init(_:), .init(codepoint:fg:bg:underlineColor:bold:dim:italic:underline:blink:inverse:invisible:strikethrough:overline:), CompositorPane (+13 more)

### Community 62 - "ComposedCell"
Cohesion: 0.18
Nodes (16): SessionRef, byID, byName, next, previous, String, UUID, TargetSpec (+8 more)

### Community 63 - "HarnessCLI+Server.swift"
Cohesion: 0.15
Nodes (10): Buffer, Configuration, PasteBufferStore, Bool, Data, Date, String, URL (+2 more)

### Community 64 - ".text"
Cohesion: 0.13
Nodes (15): DaemonClient, String, KouenCLI, String, KouenCLI, Bool, String, UUID (+7 more)

### Community 65 - "PrefixKeymap"
Cohesion: 0.11
Nodes (10): KouenTerminalSurfaceView, Bool, CAMetalDrawable, NSEvent, RGBColor, String, KouenTerminalSurfaceView, CGFloat (+2 more)

### Community 66 - "ShellIntegration"
Cohesion: 0.12
Nodes (3): String, ANSIPaletteTests, KouenThemeCatalogTests

### Community 67 - "String"
Cohesion: 0.15
Nodes (9): AgentHookInstaller, InstallResult, Any, Bool, Data, String, URL, result (+1 more)

### Community 68 - "Completed Plans Archive"
Cohesion: 0.12
Nodes (10): BellScanState, esc, normal, string, stringEsc, SurfaceMonitor, Data, BellScanTests (+2 more)

### Community 70 - "worktree_isolation_cli.robot"
Cohesion: 0.15
Nodes (14): SidebarBadgeLabel, SidebarDividerRow, SidebarGroupHeaderRow, SidebarSessionItemRow, SidebarSessionListView, SidebarWorktreeHeaderRow, SidebarWorktreeItemRow, BoardColumnKind (+6 more)

### Community 71 - "ImportedTerminalConfig"
Cohesion: 0.06
Nodes (21): KouenUILibrary, KouenUILibrary — Robot Framework keyword library for Kouen terminal automation., Verify a board column exists using kouen CLI., Run a kouen CLI command and assert exit code 0., Run kouen view and assert output contains substring., Type a string of text into the focused element via osascript keystroke., Wait for UI to settle., Verify app is still running (no crash report in last 10s). (+13 more)

### Community 72 - "XCTestCase"
Cohesion: 0.06
Nodes (22): CornerInfo, EditorDividerView, KouenSplitView, .init(coder:), PaneDragGripView, .init(coder:), PaneHoverButton, PaneSplitButtonsView (+14 more)

### Community 73 - "README.md"
Cohesion: 0.08
Nodes (17): Codex → Kouen, One-line install, What you'll see, Cursor Agent → Kouen, Manual fallback, One-line install, What you'll see, Hermes → Kouen (+9 more)

### Community 75 - "OptionStore"
Cohesion: 0.13
Nodes (11): ExperienceMode, agent, full, persistent, plain, Bool, NotchVisibilityMode, automatic (+3 more)

### Community 76 - ".parse"
Cohesion: 0.16
Nodes (12): PaneListRow, SessionListRow, SnapshotQueryFormatter, Bool, SessionGroup, SessionSnapshot, String, Tab (+4 more)

### Community 77 - "TerminalProtocolCompatibilityTests"
Cohesion: 0.21
Nodes (7): EnvironmentStore, Persisted, String, URL, global, EnvironmentStoreTests, URL

### Community 79 - "HarnessDesign"
Cohesion: 0.13
Nodes (15): AgentRow, AgentRow, MenuBarController, MenuRef, CGFloat, NSImage, NSMenu, NSMenuItem (+7 more)

### Community 80 - "Agent handbook — Harness (extended reference)"
Cohesion: 0.09
Nodes (22): Agent Memory, Build / Test / Run, Graphify, graphify, kouen-terminal — Claude Instructions, Non-obvious Constraints, Session Start, Skills (+14 more)

### Community 81 - "DaemonSubscription"
Cohesion: 0.14
Nodes (13): InstallResult, Profile, Shell, bash, fish, zsh, ShellProfileInstaller, Bool (+5 more)

### Community 82 - ".firstMatch"
Cohesion: 0.16
Nodes (3): LiveResizeTests, KouenTerminalSurfaceView, NSWindow

### Community 83 - "LSPClient"
Cohesion: 0.17
Nodes (10): AsyncCLIResultBox, KouenCLI, LSPDefinitionPayload, LSPDiagnosticsPayload, LSPStatusPayload, Error, Result, String (+2 more)

### Community 84 - "LSPDiagnostic"
Cohesion: 0.06
Nodes (32): SplitPaneCoordinator, .surfaceID(forPane:in:), .surfaceID(forPaneID:in:), Bool, PaneID, PaneNode, SessionCoordinator, SessionID (+24 more)

### Community 85 - "TerminalGridCell"
Cohesion: 0.07
Nodes (25): requestFailed, FileHandle, CodingKeys, error, id, jsonrpc, method, params (+17 more)

### Community 86 - "HarnessPaths"
Cohesion: 0.10
Nodes (13): FileEditorView, .init(coder:), .init(frame:), Any, Bool, NSCoder, NSEvent, NSRect (+5 more)

### Community 87 - "SessionCoordinator"
Cohesion: 0.14
Nodes (16): FindWindowMatcher, SearchScope, all, none, only, Bool, SessionGroup, SessionID (+8 more)

### Community 88 - "Harness as a terminal multiplexer"
Cohesion: 0.11
Nodes (19): 10. Attach over ssh — the compositor, 11. Window search and filtering, 12. Shell integration (prompt marks + the success/failure gutter), 13. Agent hooks (notifications), 14. macOS shortcuts (no prefix), 15. One-screen cheat sheet, 1. The mental model, 2. The prefix key (+11 more)

### Community 89 - ".cursorPos"
Cohesion: 0.16
Nodes (4): hooks, AgentHookInstallerTests, String, URL

### Community 90 - "Zombie View Crashes on macOS 26.5 + Swift 6.3.2"
Cohesion: 0.09
Nodes (14): CKouenSys, pipe, termios, AttachClient, Configuration, LiveSession, Bool, Data (+6 more)

### Community 91 - "TerminalModes"
Cohesion: 0.13
Nodes (4): ContentAreaViewController, Bool, TabID, Notification

### Community 92 - "P2 — Async IPC Refactor: Design Document"
Cohesion: 0.27
Nodes (4): AgentTableEntry, Bool, Set, String

### Community 93 - "code:bash (# Terminal 1: Create workspace with long-running job)"
Cohesion: 0.15
Nodes (3): AgentTitleInference, Bool, AgentDetectorTests

### Community 94 - "AttachInputBatcher"
Cohesion: 0.21
Nodes (8): C, AttachInputBatcher, Outcome, Bool, Data, UInt8, AttachInputBatcherTests, UInt8

### Community 95 - "shim.c"
Cohesion: 0.13
Nodes (13): DirectoryItemRow, DirectoryPanel, DirectoryPickerController, DirectoryPickerFooter, DirectoryPickerModel, DirectoryPickerView, DirectoryWindowDelegate, String (+5 more)

### Community 96 - "Harness Usage"
Cohesion: 0.17
Nodes (12): 1. Install Kouen, 2. Install The CLI On PATH, 3. Pick An Experience Mode, 4. Agent Notifications, 5. Recommended Shell Tools, 6. Troubleshooting, Kouen Usage, More Docs (+4 more)

### Community 97 - "PaneContainerView"
Cohesion: 0.07
Nodes (21): DaemonCommandExecutor, HookExecutor, DispatchQueue, SurfaceRegistry, SessionSnapshot, PendingVersionBanner, welcome, whatsNew (+13 more)

### Community 98 - "4. Technical Architecture"
Cohesion: 0.13
Nodes (12): AnyObject, TimeInterval, ZombieHoldRegistry, PaneLifecycleManager, Bool, NSView, PaneID, PaneNode (+4 more)

### Community 99 - ".dispatch"
Cohesion: 0.18
Nodes (18): TerminalColorGamut, auto, displayP3, sRGB, TerminalColorRenderingMode, accurate, vivid, RenderColor (+10 more)

### Community 100 - "ScriptRuntime.swift"
Cohesion: 0.36
Nodes (3): KouenSplitViewTests, LayoutProbeView, CGFloat

### Community 101 - "Session Grouping and Split Session Plan"
Cohesion: 0.12
Nodes (11): BoardCardView, .init(card:), .init(coder:), BoardViewController, FlippedView, Bool, NSCoder, Set (+3 more)

### Community 102 - "DaemonLauncher"
Cohesion: 0.13
Nodes (16): CopyModeSearch, CopyModeSelectionMode, block, char, line, none, CopyModeSideEffect, beginSearchEntry (+8 more)

### Community 104 - "Recipe"
Cohesion: 0.10
Nodes (25): Bool, UInt8, TerminalCellWidth, normal, spacerTail, wide, TerminalCursor, TerminalCursorShape (+17 more)

### Community 105 - "Changelog"
Cohesion: 0.17
Nodes (8): AgentListFormatter, Date, String, cols, AgentListFormatterTests, Bool, Date, String

### Community 106 - "domain-design.md"
Cohesion: 0.17
Nodes (4): SessionSnapshot, String, UUID, TargetSpecTests

### Community 107 - "AgentNotchViewModel"
Cohesion: 0.08
Nodes (24): BoxDrawing, Kind, arms, dashH, dashV, halfDown, halfLeft, halfRight (+16 more)

### Community 108 - ".resolve"
Cohesion: 0.16
Nodes (11): KouenCLITests, URL, KouenCLI, KouenFilePreviewLoader, KouenViewError, binaryOrUnsupportedEncoding, missingPath, tooLarge (+3 more)

### Community 109 - "DamageTrackingTests"
Cohesion: 0.12
Nodes (9): SGRMouse, SGRMouseEvent, Bool, PaneRect, S, UInt8, SGRMouseTests, String (+1 more)

### Community 110 - "SoftIconButton"
Cohesion: 0.19
Nodes (5): CopyModeReducerTests, FakeGrid, Set, String, TerminalGridCell

### Community 111 - "code:text (:workbench start swift)"
Cohesion: 0.40
Nodes (3): Any, WKScriptMessage, WKUserContentController

### Community 112 - ".makeSnapshot"
Cohesion: 0.20
Nodes (6): KeyTokenParser, Bool, Data, String, KeyTokenParserTests, Phase6KeysTests

### Community 113 - "HarnessGridTerminal"
Cohesion: 0.13
Nodes (22): KouenSettings, .init(fontSize:fontFamily:defaultShell:defaultCWD:transparentTitlebar:sidebarVisible:sidebarOnRight:sidebarCollapsedOnLaunch:sidebarWidth:restoreWindowSize:backgroundOpacity:backgroundBlur:windowPaddingX:windowPaddingY:customBackgroundHex:customForegroundHex:customCursorHex:importedConfigSignature:prefixKey:scrollbackLines:cursorStyle:cursorBlink:copyOnSelect:selectionBackgroundHex:selectionForegroundHex:boldColorHex:cursorTextHex:paletteHex:agentColorOverrides:defaultAgentKind:dividerHex:statusLineHex:windowBorderHex:windowBorderOpacity:systemNotificationsEnabled:notificationSoundEnabled:notchVisibilityMode:notchOpenOnHover:colorRendering:colorGamut:textRendering:vividColors:linearBlending:applyThemeToTerminalOutput:ligatures:offMainParserFramePipeline:liveResizeReflow:mobileBridgeEnabled:showPromptGutter:showStatusLine:experienceMode:kouenControlsEnabled:prefixKeyEnabled:statusLineEnabled:resizeOverlay:resizeOverlayPosition:windowPaddingBalance:minimumContrast:lightThemeName:darkThemeName:lightThemeOpacity:darkThemeOpacity:pasteProtection:commandFinishedThresholdSeconds:notificationEvents:boldIsBright:lspAutoStart:lspServers:fileClickAction:claudeAPIKey:inlineAICompletion:terminalShaderEffect:browserHomePage:), .init(from:), LegacyKouenSettingsCodingKeys, commandFinishedNotifications, tmuxControlsEnabled, ResizeOverlayMode, afterFirst (+14 more)

### Community 114 - ".firstWaitingTab"
Cohesion: 0.15
Nodes (7): ImportedTerminalConfig, Bool, Double, Float, String, TerminalConfigImporter, TerminalConfigImporterTests

### Community 115 - ".encode"
Cohesion: 0.31
Nodes (3): NodeRow, Error, String

### Community 116 - "SessionGroup"
Cohesion: 0.20
Nodes (7): AgentRoutingRuleStore, Bool, String, URL, UUID, AgentRoutingRuleStoreTests, URL

### Community 117 - "PaneNode"
Cohesion: 0.10
Nodes (12): NotificationCoordinator, Bool, Date, SessionCoordinator, SessionSnapshot, Set, String, SurfaceID (+4 more)

### Community 118 - "WorkspaceFileTreeView"
Cohesion: 0.12
Nodes (12): ActiveTabCloseDisposition, session, tab, window, workspace, CloseConfirmationCopy, SessionLifecycleService, NSWindow (+4 more)

### Community 119 - "Harness command reference"
Cohesion: 0.12
Nodes (16): Attaching from a plain terminal, Bindings, Buffers (paste store), Composition, Hooks, Inspection (CLI / control mode), Kouen command reference, Local diagnostics (+8 more)

### Community 122 - "ViEngine"
Cohesion: 0.38
Nodes (3): TimeInterval, ProcessScan, Int32

### Community 123 - "Pipe"
Cohesion: 0.20
Nodes (8): InstallChoice, cancel, install, installAndApply, Error, String, URL, ThemeImportController

### Community 124 - "String"
Cohesion: 0.12
Nodes (23): FooterIconButton, RecentProjectsMenuButton, SidebarFooterModel, SidebarFooterView, SidebarSectionLabelView, SidebarSectionModel, SidebarTabBarView, Bool (+15 more)

### Community 125 - "HistoryRingBuffer"
Cohesion: 0.12
Nodes (9): ContiguousArray, IteratorProtocol, HistoryRingBuffer, Iterator, Bool, Element, S, Sequence (+1 more)

### Community 126 - ".path"
Cohesion: 0.08
Nodes (25): AgentArt, AgentMark, AgentMarkShape, AgentVectorIcon, Scanner, SVGPath, Bool, CGFloat (+17 more)

### Community 127 - "GlyphAtlas"
Cohesion: 0.10
Nodes (23): Hashable, AtlasEntry, ClusterGlyphKey, GlyphAtlas, .entry(for:), .entry(forCluster:bold:italic:), .entry(forShaped:font:), GlyphAtlasStats (+15 more)

### Community 128 - "code:block1 (SessionCoordinator.snapshot ──┐)"
Cohesion: 0.10
Nodes (12): AnyCancellable, NotchMaskAnimator, Bool, CGFloat, CGRect, NSView, NotchPanel, Bool (+4 more)

### Community 129 - "SwiftUI"
Cohesion: 0.14
Nodes (11): FilePreviewCoordinator, FileTabID, NSView, Set, SplitDirection, String, FileTab, FileTabManager (+3 more)

### Community 130 - "Harness"
Cohesion: 0.11
Nodes (19): code:bash (harness-cli doctor), AI Browser Control (kouen-mcp), Build From Source, Claude Code Harness, CLI, Development Builds, Documentation, Editor & LSP (+11 more)

### Community 131 - ".install"
Cohesion: 0.15
Nodes (12): GroupHeaderRow, PickerItem, historyBlock, recipe, RecipePickerModel, NSWindow, String, SurfaceID (+4 more)

### Community 132 - "AgentHookInstaller"
Cohesion: 0.12
Nodes (17): CommandIPCTranslator, CommandTarget, CommandTranslation, clientLocal, requests, unresolved, Command, PaneID (+9 more)

### Community 133 - ".load"
Cohesion: 0.14
Nodes (10): BranchSwitchHelper, FileTreeNode, FileTreeSwiftUIView, Notification.Name, Bool, Never, NSMenuItem, SessionID (+2 more)

### Community 134 - "code:js (// ~/.config/harness/init.js)"
Cohesion: 0.19
Nodes (6): FloatingPaneController, Any, Bool, NSEvent, NSObjectProtocol, NSPanel

### Community 135 - "CommandTarget"
Cohesion: 0.06
Nodes (33): TerminalModes, InputEncoder, .encode(_:modifiers:event:modes:), .encode(text:modifiers:modes:), .encode(text:shifted:modifiers:event:associatedText:modes:), KeyEventType, press, release (+25 more)

### Community 136 - ".startWatching"
Cohesion: 0.33
Nodes (11): Codable, BrowserElement, BrowserElementBounds, BrowserNetworkEntry, BrowserSnapshot, HookEntry, IPCResponse, OptionEntry (+3 more)

### Community 137 - "ActivePaneService"
Cohesion: 0.10
Nodes (14): Network, constantTimeEquals(), PairedDeviceRecord, PairedDeviceStore, SHA256Mini, Bool, Date, String (+6 more)

### Community 138 - "User Story Mapping (MANDATORY)"
Cohesion: 0.23
Nodes (5): ListeningPortScanner, Int32, Set, String, ListeningPortScannerTests

### Community 139 - "แผนงานการสร้างระบบพรีวิวและแสดงผลไฟล์ (File Viewer & Preview Integration Plan)"
Cohesion: 0.10
Nodes (17): KeyRecorderRepresentable, String, Void, OverlayBackground, Context, OverlayBackground, Context, OverlayBackground (+9 more)

### Community 141 - ".testPaneLeafLegacyDecodeBackfillsSurfaceTabs"
Cohesion: 0.16
Nodes (14): Phase, daemonConnected, firstDrawablePresented, firstSnapshot, firstSurfaceAttached, firstWindow, launchStart, StartupMetrics (+6 more)

### Community 142 - "CopyModeGridSource"
Cohesion: 0.29
Nodes (4): KittyGraphicsConformanceTests, String, TerminalEmulator, Void

### Community 143 - "How to use Harness from the terminal only (no GUI)"
Cohesion: 0.16
Nodes (9): PairingBox, PendingPairing, Date, TimeInterval, TokenCheck, accepted, expired, mismatch (+1 more)

### Community 144 - "PaneStyleSet"
Cohesion: 0.21
Nodes (9): CheckResult, GitCloneUpdateChecker, RemoteVersion, Bool, Data, Pipe, String, TimeInterval (+1 more)

### Community 145 - "AsciiFastPathTests"
Cohesion: 0.16
Nodes (3): DamageTrackingTests, IndexSet, TerminalEmulator

### Community 146 - "DecodedImage"
Cohesion: 0.09
Nodes (21): Bool, String, UUID, TaskDaemonBridge, CGFloat, NSCoder, SessionID, String (+13 more)

### Community 147 - "FileTreeWatcher"
Cohesion: 0.10
Nodes (20): CLIInstallLocator, DetachKeys, absent, invalid, parsed, KouenCLI, OptionalUUID, absent (+12 more)

### Community 148 - "TriState"
Cohesion: 0.31
Nodes (5): KouenSidebarPanelViewController, NSMenu, NSMenuItem, SessionGroup, SessionID

### Community 149 - "EnvironmentStore"
Cohesion: 0.17
Nodes (9): DaemonLauncher, Bool, Double, Int32, MainActor, String, TimeInterval, UInt16 (+1 more)

### Community 150 - "HarnessDaemonToolsTests"
Cohesion: 0.29
Nodes (3): KouenDaemonToolsTests, String, URL

### Community 151 - ".evaluate"
Cohesion: 0.15
Nodes (7): FileManager, String, URL, ThemeFileService, String, URL, ThemeFileServiceTests

### Community 153 - "What You Must Do When Invoked"
Cohesion: 0.24
Nodes (6): ScrollbackEntry, ScrollbackReplaySegment, ShellLaunchProfile, Data, UInt64, RealPtyReplayTests

### Community 154 - "LiveResizeTests"
Cohesion: 0.09
Nodes (26): Int, Date, String, TerminalBlock, TerminalBlockStore, .block(atPromptLine:), .block(id:), .block(atPromptLine:) (+18 more)

### Community 155 - "Int"
Cohesion: 0.14
Nodes (11): FileFuzzyMatcher, FuzzyPathResolution, ambiguous, none, unique, FuzzyPathResolver, Bool, Character (+3 more)

### Community 156 - "ThaiCombiningMarkTests"
Cohesion: 0.10
Nodes (18): NotificationEntry, SessionID, SurfaceID, TabID, WorkspaceID, NotificationDropdownPanelView, .init(coder:), .init(entries:onSelect:onClearAll:onDismiss:) (+10 more)

### Community 158 - "Harness Terminal — IDE Sidebar Feature Branch"
Cohesion: 0.23
Nodes (7): Group, PrefixCheatsheetWindow, PrefixIndicatorWindow, CGFloat, NSTextField, NSView, NSWindow

### Community 159 - "MatchCategory"
Cohesion: 0.16
Nodes (6): DefaultTerminalLaunchRequest, ShellQuoting, Bool, String, URL, DefaultTerminalLaunchRequestTests

### Community 160 - "AmbientBackground"
Cohesion: 0.26
Nodes (11): FileEditorTabBarBody, FileEditorTabBarModel, FileEditorTabBarView, .init(coder:), .init(frame:), FileTabPillView, Bool, FileTabID (+3 more)

### Community 161 - "What You Must Do When Invoked"
Cohesion: 0.21
Nodes (6): ExternalOpenKind, filePreview, terminal, theme, Set, ExternalOpenKindTests

### Community 162 - "TerminalFindBar"
Cohesion: 0.08
Nodes (16): NSSearchFieldDelegate, Bool, CGFloat, NSButton, NSCoder, NSControl, NSEvent, NSImage (+8 more)

### Community 163 - "Workspace"
Cohesion: 0.32
Nodes (3): BinaryInstallerVersionTests, String, URL

### Community 164 - "CommandPromptController"
Cohesion: 0.14
Nodes (20): ChecksStatus, fail, none, pass, pending, CIRun, GitHubCLIClient, IssueInfo (+12 more)

### Community 166 - "LiveSession"
Cohesion: 0.10
Nodes (22): cardHTML(), closeSheet(), goto(), #list-count, openSession(), renderSessions(), SESSIONS, terminal on mobile research (+14 more)

### Community 167 - "AgentTableEntry"
Cohesion: 0.07
Nodes (36): .init(entry:), AgentChipView, BoardColumnKind, ChromeBackdrop, .init(role:), ChromeRole, sidebar, tabBar (+28 more)

### Community 170 - "URLDetection"
Cohesion: 0.10
Nodes (13): Bool, Range, String, URLDetection, digest(), firstMatch(), flushBullet(), Section (+5 more)

### Community 171 - "ReflowCorpusTests"
Cohesion: 0.14
Nodes (15): AgentApprovalBar, .init(coder:), .init(host:prompt:kind:), ApprovalBarAction, hide, noop, show, NSColor (+7 more)

### Community 172 - ".decodeKeySpec"
Cohesion: 0.15
Nodes (14): GridCompositor, Configuration, Int32, SessionGroup, SessionID, SessionSnapshot, Tab, TabID (+6 more)

### Community 173 - "BoardCard"
Cohesion: 0.29
Nodes (5): KouenCLI, Bool, Int32, Never, String

### Community 174 - "BinaryRefresherTests"
Cohesion: 0.12
Nodes (6): KouenDaemonTools, .init(client:subscriptionClient:controlEnabled:), Bool, SessionSnapshot, String, UUID

### Community 175 - "RGBColorTests"
Cohesion: 0.17
Nodes (7): RemoteHost, RemoteHost, SettingsRemoteView, Bool, NSImage, RemoteHost, String

### Community 176 - "Added"
Cohesion: 0.28
Nodes (8): PairedDeviceSummary, SessionSnapshot, .init(version:revision:workspaces:activeWorkspaceID:themeName:keepSessionsOnQuit:savedAt:), SurfaceSummary, Bool, Date, String, WorkspaceID

### Community 177 - ".rects"
Cohesion: 0.19
Nodes (10): FileNode, GitStatusType, added, deleted, modified, renamed, unmodified, untracked (+2 more)

### Community 178 - "InlineAICompletionView"
Cohesion: 0.23
Nodes (9): CopyModeGridSource, ClosedRange, CopyModeReducer, Bool, Character, NSRegularExpression, Range, String (+1 more)

### Community 179 - "[3.13.1] - 2026-07-02"
Cohesion: 0.14
Nodes (17): PaneBorderStatus, bottom, off, top, PaneLeaf, PaneNode, branch, leaf (+9 more)

### Community 180 - "VTConformanceCorpusTests"
Cohesion: 0.23
Nodes (6): CellOverlayTests, IndexSet, KouenTerminalSurfaceView, NSWindow, String, UInt64

### Community 181 - "GridCompositorTests"
Cohesion: 0.18
Nodes (5): CompositorPane, GridCompositorTests, Bool, String, TerminalGridSnapshot

### Community 182 - "P25 — iOS/iPadOS Support"
Cohesion: 0.22
Nodes (5): SessionCoordinator, Bool, String, SurfaceID, TimeInterval

### Community 183 - "LSPServerRegistry"
Cohesion: 0.08
Nodes (6): CodepointRunFastPathTests, .assertAllPathsAgree(_:cols:rows:file:line:), StaticString, String, UInt, UInt8

### Community 184 - "targets"
Cohesion: 0.09
Nodes (21): name, options, bundleIdPrefix, createIntermediateGroups, deploymentTarget, packages, Kouen, Sparkle (+13 more)

### Community 185 - "SessionSnapshot"
Cohesion: 0.15
Nodes (4): KouenGridTerminalTests, KouenGridTerminal, String, TerminalGridSnapshot

### Community 186 - "Error"
Cohesion: 0.19
Nodes (3): DECSpecialGraphics, CommandParserTests, KeyTableTests

### Community 187 - "AppDelegate"
Cohesion: 0.20
Nodes (10): AppDelegate, .application(_:open:), .application(_:openFiles:), QueuedExternalOpen, Bool, NSKeyValueObservation, String, URL (+2 more)

### Community 188 - "BrowserPaneView"
Cohesion: 0.15
Nodes (13): Motion, CAMediaTimingFunction, KouenOnboarding, Bool, ImmersiveOnboardingWindowController, .init(coder:), .init(onDismiss:), ImmersivePanel (+5 more)

### Community 189 - "P5 — ACP (Agent Client Protocol) — Harness as ACP Editor/Client"
Cohesion: 0.19
Nodes (8): Range, String, TerminalGridCell, TerminalBufferMatch, TerminalBufferSearch, String, TerminalGridCell, TerminalBufferSearchTests

### Community 190 - "user-stories.md"
Cohesion: 0.16
Nodes (9): PaneID, SurfaceID, Tab, TabID, UUID, BrowserPaneReuseScopeTests, PaneNode, Tab (+1 more)

### Community 191 - "ScriptRuntime"
Cohesion: 0.09
Nodes (14): PluginLoader, String, ScriptAPI, ScriptError, evaluationError, unsupportedPlatform, ScriptRuntime, Any (+6 more)

### Community 192 - "GlyphRasterizer"
Cohesion: 0.08
Nodes (25): CTFontSymbolicTraits, CellMetrics, GlyphRasterizer, .rasterize(cluster:bold:italic:), .rasterize(codepoint:bold:italic:), .rasterize(glyph:font:), RasterizedGlyph, ShapedGlyph (+17 more)

### Community 193 - "BinaryInstaller"
Cohesion: 0.19
Nodes (11): RecordClient, RecordingWriter, RecordSession, Summary, Bool, Data, DispatchSourceSignal, FileHandle (+3 more)

### Community 194 - "Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag"
Cohesion: 0.15
Nodes (15): FileTreeScanOptions, MatchCategory, exactFilename, filenameContains, filenameContainsTokens, filenameEndsWith, filenameStartsWith, fuzzy (+7 more)

### Community 195 - "ResizeHUDView"
Cohesion: 0.11
Nodes (6): KouenSidebarPanelViewController, NSMenuItem, NSView, String, SessionSnapshot, SidebarTitlebarHeaderView

### Community 196 - "Feature Provenance — harness-terminal"
Cohesion: 0.06
Nodes (34): .init(coder:), .init(frame:), .init(coder:), Kind, primary, secondary, .init(coder:), KouenPillButton (+26 more)

### Community 197 - "AgentSessionSummary"
Cohesion: 0.11
Nodes (15): FlippedView, GitPanelView, .removeWorktreeAction(_:), Any, NSButton, NSColor, NSMenuItem, NSRect (+7 more)

### Community 198 - ".classify"
Cohesion: 0.23
Nodes (6): DoctorRunner, Bool, URL, DoctorRunnerTests, String, URL

### Community 200 - "BinaryInstallerVersionTests"
Cohesion: 0.14
Nodes (9): InstallResult, Shell, bash, fish, zsh, Bool, URL, ShellIntegrationTests (+1 more)

### Community 201 - "MCP Server (harness-mcp)"
Cohesion: 0.08
Nodes (35): TerminalEmulator, String, TerminalEmulator, BlockSelection, CursorRender, CursorStyle, bar, block (+27 more)

### Community 202 - "PaletteModel"
Cohesion: 0.14
Nodes (10): FrecencyDirectoryStore, FrecencyEntry, Date, Double, Never, String, Task, URL (+2 more)

### Community 203 - "Harness keybindings"
Cohesion: 0.22
Nodes (9): Command prompt, Copy-mode key table, Customizing, Default `prefix` table, Global menu shortcuts, Key spec syntax, Kouen keybindings, Persistence (+1 more)

### Community 204 - "From tmux"
Cohesion: 0.29
Nodes (7): Bringing your `.tmux.conf` over, Deliberate divergences, From tmux, Import Terminal Colors And Fonts, Key-by-key translation, Make Kouen the default terminal, Migrating to Kouen

### Community 205 - "CopyModeState"
Cohesion: 0.14
Nodes (12): NSCoder, NSEvent, NSImage, NSPanel, NSRect, String, Void, TabCell (+4 more)

### Community 206 - "HarnessCLI"
Cohesion: 0.18
Nodes (8): Kind, input, metadata, output, resize, Decoder, KeyedDecodingContainer, String

### Community 207 - "scheduleRender"
Cohesion: 0.17
Nodes (5): AgentDetection, AgentDetector, Date, Int32, AgentSnapshot

### Community 208 - ".testDataFrameEncodeVsJSONBase64Output"
Cohesion: 0.13
Nodes (13): CompletionPopupView, .init(coder:), .init(frame:), CompletionRowView, .init(coder:), .init(text:isSelected:), Bool, NSCoder (+5 more)

### Community 209 - "SettingsRemoteView"
Cohesion: 0.13
Nodes (15): BrowserRequestPayload, close, cookies, evaluate, goBack, goForward, interact, navigate (+7 more)

### Community 210 - "PaneDropZoneOverlay"
Cohesion: 0.22
Nodes (3): CompletionGenerator, String, CompletionGeneratorTests

### Community 211 - "PaneTarget"
Cohesion: 0.30
Nodes (6): Channel, Bool, Int32, String, WaitForRegistry, WaitForRegistryTests

### Community 212 - ".translate"
Cohesion: 0.11
Nodes (9): String, WorkspaceID, CwdMetadataProvider, GitMetadataProvider, MetadataProvider, String, Tab, DaemonSyncServiceBranchNotifyTests (+1 more)

### Community 213 - "String"
Cohesion: 0.08
Nodes (24): 1 — Process lifecycle & supervision, 2 — IPC protocol evolution, 3 — Concurrency architecture, 4 — State persistence, 5 — Render/PTY data path & the "mktemp failed" spam, 6 — Build/release pipeline, A10 (Low) — stale `@unchecked Sendable` inventory, A1 (High) — S1 daemon-reuse is undone at GUI relaunch by the build-handshake staleness check (+16 more)

### Community 214 - "NotchLayoutMetrics"
Cohesion: 0.24
Nodes (7): LaunchdServiceInstaller, ServiceInstaller, ServiceInstallers, ServiceInstallReport, Bool, String, URL

### Community 215 - ".lines"
Cohesion: 0.25
Nodes (8): CodingKeys, activeWorkspaceID, keepSessionsOnQuit, revision, savedAt, themeName, version, workspaces

### Community 216 - "CellColorResolverTests"
Cohesion: 0.16
Nodes (9): WindowInputRouterTests, KeySpecDecode, complete, incomplete, invalid, literalPrefix, UInt8, Unicode (+1 more)

### Community 217 - "GridCompositor"
Cohesion: 0.11
Nodes (21): CommandPaletteController, PaletteAction, PaletteCommandConfig, PaletteFileEntry, PaletteGrepMatch, PaletteItemRow, PaletteModel, PalettePanel (+13 more)

### Community 218 - "ScrollbackFile"
Cohesion: 0.11
Nodes (14): DetachedPaneOverlay, .init(coder:), .init(frame:style:), Style, detached, reconnectingChip, NSCoder, NSEvent (+6 more)

### Community 219 - "Prompt"
Cohesion: 0.20
Nodes (6): CGFloat, NSColor, NSPoint, NSRect, NSWindow, WindowBorderOverlayView

### Community 220 - "Section"
Cohesion: 0.20
Nodes (8): NotchGeometry, NSScreen, NotchLayoutMetrics, NotchRect, NotchScreenMetrics, Bool, Double, NotchLayoutMetricsTests

### Community 221 - "TerminalServicesProvider"
Cohesion: 0.08
Nodes (10): CGImage, ImageLimits, Bool, ImageDecoder, Data, ITerm2InlineImage, Bool, String (+2 more)

### Community 222 - "AgentNotchRowSummary"
Cohesion: 0.19
Nodes (5): .selectWorkspace(_:), .selectWorkspace(byIndex:), String, TabID, WorkspaceID

### Community 223 - "ANSIPalette"
Cohesion: 0.09
Nodes (9): .removeWorktreeAction(path:), GitResult, Bool, DispatchWorkItem, String, ValidateOutcome, WorktreeEntry, GitPanelViewToastErrorSummaryTests (+1 more)

### Community 224 - "CellColorResolver"
Cohesion: 0.27
Nodes (10): ANSIPalette, CellColorResolver, .init(palette:defaultForeground:defaultBackground:boldBrightens:faintFraction:minimumContrast:), .init(theme:boldBrightens:minimumContrast:), ResolvedCellColors, Bool, Double, RGBColor (+2 more)

### Community 225 - "HarnessPathDisplay"
Cohesion: 0.21
Nodes (9): StdioTransportTests, Data, MCPStdioBuffer, MCPStdioFraming, contentLength, newline, StdioTransport, AsyncStream (+1 more)

### Community 226 - "FileChangeWatcher"
Cohesion: 0.17
Nodes (17): Source, activePane, activeTab, focusedPane, focusedSurface, PaneID, PaneLeaf, PaneNode (+9 more)

### Community 227 - "SSHTunnelManagerTests"
Cohesion: 0.11
Nodes (6): SessionID, GroupedSessionTests, SessionGroup, Set, SurfaceID, Phase67Tests

### Community 228 - "sessionRow"
Cohesion: 0.19
Nodes (7): KeybindingsStore, URL, KeybindingsStoreTests, URL, Void, KouenCLI, String

### Community 229 - ".decide"
Cohesion: 0.21
Nodes (6): MutationResult, RemoteHost, RemoteHostStore, Bool, String, T

### Community 230 - "HarnessGridTerminalTests"
Cohesion: 0.23
Nodes (5): ResolvedCanvas, String, ThemeManager, ThemePreset, ThemeManagerTests

### Community 231 - "ExternalOpenKind"
Cohesion: 0.16
Nodes (22): Appearance, .init(backgroundOpacity:backgroundBlur:fontFamily:fontSize:windowPaddingX:windowPaddingY:sourceColorSpace:appearance:supportsWideGamut:contrastGrade:applyToTerminalOutput:), .init(from:), AppearanceKind, dark, light, Colors, ContrastGrade (+14 more)

### Community 232 - "P10 Task: Lazy Scrollback Reflow"
Cohesion: 0.13
Nodes (12): Logger, os, OSSignposter, LatencyMonitor, String, UInt64, FrameDropCause, encodeFailure (+4 more)

### Community 233 - "TextGrid"
Cohesion: 0.18
Nodes (3): RegressionBugFixTests, SessionSnapshot, Tab

### Community 234 - ".scan"
Cohesion: 0.24
Nodes (4): Set, SurfaceID, Void, TerminalPaneRegistry

### Community 235 - "WorkbenchCommand"
Cohesion: 0.11
Nodes (14): SettingsHostingController, .init(coder:), .init(page:), SettingsWindowController, NSCoder, NSWindow, Page, advanced (+6 more)

### Community 237 - "TerminalBlockStoreTests"
Cohesion: 0.13
Nodes (10): Bool, CGFloat, NSCoder, NSEvent, NSLayoutConstraint, NSPoint, NSRect, WindowTitleStripView (+2 more)

### Community 238 - ".make"
Cohesion: 0.08
Nodes (23): DefaultTerminalManager, DefaultTerminalOpener, DefaultTerminalRegistrationError, failed, DefaultTerminalStatus, Bool, String, URL (+15 more)

### Community 239 - "TerminalMetalRenderer"
Cohesion: 0.09
Nodes (12): CharacterWidth, Bool, ClosedRange, Unicode, CharacterWidthTable, UInt16, UInt8, StatusLineWidthTests (+4 more)

### Community 240 - "PaneBorderStatus"
Cohesion: 0.14
Nodes (18): ChooseScope, buffer, client, session, tree, window, Command, MenuItem (+10 more)

### Community 242 - "AgentBridge"
Cohesion: 0.15
Nodes (5): HookFiringTests, NSObjectProtocol, String, URL, XCTestExpectation

### Community 243 - ".make"
Cohesion: 0.12
Nodes (23): Encodable, AISuggestionAck, AttachedAck, BrowserFramePush, BrowserSnapshotAck, Cred, DecodedWSFrame, DetachedAck (+15 more)

### Community 244 - "FileNode"
Cohesion: 0.13
Nodes (10): DaemonClientActor, TimeInterval, daemonError, DaemonSessionService, .request(_:timeout:), Bool, TimeInterval, Endpoint (+2 more)

### Community 245 - "ThemeDocumentTests"
Cohesion: 0.26
Nodes (6): SurfaceIO, Data, SurfaceID, UInt16, UInt64, TerminalHostDelegate

### Community 246 - "Experience modes"
Cohesion: 0.29
Nodes (7): 1. Plain Terminal, 2. Persistent Terminal, 3. Full Terminal, 4. Agent Workspace, Experience modes, Opting into the prefix + status line without switching modes, Persistence (ephemeral vs. persistent)

### Community 247 - ".renderFixture"
Cohesion: 0.16
Nodes (12): InstallError, daemonNotFound, launchctlFailed, writeFailed, InstallReport, LaunchAgentInstaller, Bool, Int32 (+4 more)

### Community 248 - "DaemonMetrics"
Cohesion: 0.25
Nodes (5): WorktreeManager, String, URL, UUID, WorktreeIsolationDaemonTests

### Community 249 - "ReflowPreviewTests"
Cohesion: 0.16
Nodes (9): ClientSummary, DaemonStats, Bool, Date, Double, Int32, String, UUID (+1 more)

### Community 250 - "HarnessTerminalSurfaceWorkerTests"
Cohesion: 0.17
Nodes (12): AgentRow, HookState, failed, idle, installed, installing, SettingsAgentsView, Bool (+4 more)

### Community 252 - "NSViewRepresentable"
Cohesion: 0.29
Nodes (7): FSEventStreamBox, escaping, FSEventStreamRef, MainActor, UnsafeMutableRawPointer, Void, WatcherContext

### Community 254 - "BoardViewController"
Cohesion: 0.35
Nodes (6): CommandTarget, PaneID, SessionGroup, SessionSnapshot, Tab, first

### Community 255 - "release-hotfix.sh"
Cohesion: 0.16
Nodes (9): FileGraphInfo, GraphifyLSPBridge, Double, String, URL, GraphifyLSPBridgeTests, Any, String (+1 more)

### Community 256 - "GitMetadataProvider"
Cohesion: 0.15
Nodes (12): InlineAICompletionView, .init(coder:), .init(frame:), Bool, NSCoder, NSEvent, NSRect, NSTextField (+4 more)

### Community 257 - "Sidebar SwiftUI Migration — Knowledge"
Cohesion: 0.25
Nodes (17): CoreImage, AttachedAck, attachToPairedSurface(), ConnectionState, detectHost(), PairingBox, PendingPairing, qrAsciiArt() (+9 more)

### Community 258 - "WindowTitleStripView"
Cohesion: 0.21
Nodes (13): .init(from:), Decoder, sessions, Decoder, SessionGroup, SessionID, String, Tab (+5 more)

### Community 259 - "ThemeFileServiceTests"
Cohesion: 0.27
Nodes (6): KittyGraphicsCommand, Bool, Character, Data, String, UInt8

### Community 260 - ".welcome"
Cohesion: 0.25
Nodes (5): Bool, KouenCLI, Bool, String, URL

### Community 261 - "Browser Pane (P14)"
Cohesion: 0.19
Nodes (8): HookNotificationParser, Parsed, Any, Data, String, HookNotificationParserTests, Data, String

### Community 262 - ".install"
Cohesion: 0.17
Nodes (8): AgentRoutingResolver, String, AgentRoutingRule, AgentRoutingRuleSummary, Bool, String, UUID, AgentRoutingResolverTests

### Community 263 - "HarnessSidebarPanelViewController"
Cohesion: 0.20
Nodes (10): DemoSession, DemoTerminalView, GridCanvas, Bool, CGFloat, String, StyledSegment, TerminalGridCell (+2 more)

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
Cohesion: 0.10
Nodes (10): PaneBorderStatus, Bool, Command, CommandTarget, DispatchWorkItem, KouenGridTerminal, PaneRect, String (+2 more)

### Community 271 - "StatusLineView.swift"
Cohesion: 0.19
Nodes (10): KouenChrome, KouenChromePalette, Bool, CGFloat, NSColor, String, PaletteFooter, PickerItemRow (+2 more)

### Community 272 - "SGRMouseEvent"
Cohesion: 0.26
Nodes (4): Bool, String, TimeInterval, WorktreeInfo

### Community 273 - "KeySpec"
Cohesion: 0.30
Nodes (3): FileTreeWatcher, FileTreeWatcherTests, URL

### Community 274 - "[2.5.0] - 2026-06-12"
Cohesion: 0.19
Nodes (8): ActivityAssertionManager, Bool, NSObjectProtocol, SessionSnapshot, Set, String, SurfaceID, ActivityAssertionManagerTests

### Community 275 - "P8: macOS 27 Golden Gate Adoption"
Cohesion: 0.11
Nodes (17): Artifacts, Client Application, Client Application, Client Application, Context, D1 — File preview (read-only), D2 — File/image attach (upload), D3 — Browser mirror (embedded, mirrors Mac's real BrowserPaneView) (+9 more)

### Community 276 - "SyntaxTextView"
Cohesion: 0.10
Nodes (19): SettingsAppearanceView, SliderRow, Bool, ClosedRange, Double, String, ColorHexRow, PaletteCell (+11 more)

### Community 277 - ".run"
Cohesion: 0.08
Nodes (27): LocalizedError, BinaryInstaller, CopyOutcome, copied, keptNewerInstalled, skippedIdentical, DetectionStatus, found (+19 more)

### Community 278 - "BlockTintOverlay"
Cohesion: 0.20
Nodes (10): BrowserResponsePayload, cookies, error, network, ok, open, screenshot, snapshot (+2 more)

### Community 279 - "DisplayPanesOverlay"
Cohesion: 0.05
Nodes (35): StatusLineView, .init(coder:), CGFloat, FormatColor, Never, NSAttributedString, NSCoder, NSColor (+27 more)

### Community 280 - ".menu"
Cohesion: 0.14
Nodes (18): Equatable, ANSIPalette, CellColorResolver, MochaTheme, ResolvedCellColors, RGBColor, .init(hex:), .init(red:green:blue:alpha:) (+10 more)

### Community 281 - "TerminalScrollbarView"
Cohesion: 0.20
Nodes (11): ControlModeClient, ControlModeError, daemon, noMatch, noSnapshot, unresolved, Command, Data (+3 more)

### Community 282 - "RemoteHostStoreTests"
Cohesion: 0.14
Nodes (8): NSAttributedString, String, SyntaxHighlighter, SyntaxHighlighterTests, NSAttributedString, NSColor, String, SyntaxHighlightTests

### Community 283 - "FormatColor"
Cohesion: 0.24
Nodes (4): RGBColor, String, ThemeDiagnostics, ThemeDiagnosticsTests

### Community 284 - "click_ui_element"
Cohesion: 0.18
Nodes (5): LSPTextLocation, LSPTextLocationParser, String, URL, LSPTextLocationParserTests

### Community 288 - "AgentHookStrategy"
Cohesion: 0.18
Nodes (4): AsciiFastPathTests, StaticString, String, UInt

### Community 290 - "Process"
Cohesion: 0.26
Nodes (5): Case, ReflowCorpusTests, String, TerminalEmulator, URL

### Community 291 - "JSONDecoder"
Cohesion: 0.20
Nodes (3): String, TerminalGridSnapshot, VTConformanceCorpusTests

### Community 292 - "Release runbook"
Cohesion: 0.25
Nodes (7): Full local signing path (needs a Developer ID cert; not currently used), Full pipeline reference (not implemented in this fork), How this fork actually releases, If the workflow existed: running a release, One-time GitHub setup, Release runbook, What that workflow would publish

### Community 293 - "Fixes Applied (layered)"
Cohesion: 0.10
Nodes (17): CodingKeys, error, id, jsonrpc, method, params, JSONRPCId, int (+9 more)

### Community 294 - "GitHubCLIClient"
Cohesion: 0.15
Nodes (11): HitTestPassthroughView, PaneContainerView, .init(node:cwd:themeName:existingHosts:existingBrowserPanes:), .init(paneID:), NSPoint, NSView, PaneID, PaneNode (+3 more)

### Community 295 - "AgentApprovalBar"
Cohesion: 0.20
Nodes (7): FileChangeWatcher, DispatchSourceFileSystemObject, DispatchWorkItem, String, TimeInterval, Void, FileChangeWatcherTests

### Community 296 - "NotificationBus"
Cohesion: 0.13
Nodes (14): State, csiEntry, csiIgnore, csiIntermediate, csiParam, escape, escapeIntermediate, ground (+6 more)

### Community 297 - "settings.json"
Cohesion: 0.17
Nodes (11): PaneBorderStatus, bottom, off, top, PaneRect, PaneRectSolver, Bool, Double (+3 more)

### Community 298 - "jobs"
Cohesion: 0.18
Nodes (6): ReleaseNotes, ReleaseNotes, Section, String, ReleaseNotesGuardTests, String

### Community 299 - "PaneNode"
Cohesion: 0.27
Nodes (11): BannerShortcut, .init(from:), .init(key:description:showInBanner:), BannerShortcutRegistry, Keybinding, MenuModifiers, Bool, Decoder (+3 more)

### Community 300 - "HarnessPaths.swift"
Cohesion: 0.13
Nodes (14): AgentNotification, OSCNotificationParser, DaemonSurfaceID, Data, Date, String, SurfaceID, NotificationBus (+6 more)

### Community 301 - ".parse"
Cohesion: 0.30
Nodes (3): ImageProtocolTests, String, TerminalEmulator

### Community 302 - "ThemeDiagnostics"
Cohesion: 0.16
Nodes (8): DetectedProfile, HandoffInfo, SignalFileRouter, Bool, FileManager, String, SignalFileRouterTests, URL

### Community 303 - ".encodeMouse"
Cohesion: 0.12
Nodes (16): Action, DesktopNotifier, KouenPathDisplay, NotificationPresenter, .userNotificationCenter(_:didReceive:withCompletionHandler:), .userNotificationCenter(_:willPresent:withCompletionHandler:), Bool, MainActor (+8 more)

### Community 304 - "00-inception-plan.md"
Cohesion: 0.16
Nodes (13): DiffLineType, added, deleted, modified, Notification.Name, NSCoder, NSRect, NSTextView (+5 more)

### Community 305 - ".script"
Cohesion: 0.29
Nodes (5): DirectionalAxis, down, left, right, up

### Community 306 - "RegressionBugFixTests"
Cohesion: 0.12
Nodes (15): Addendum — MAW-pattern validate gate (2026-07-23), Already matched (verified in code, not gaps), Method, Not gaps — deliberate positioning differences (no action), P39 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed / tmux), Phase A — Remote workflow parity (G2) — DONE 2026-07-11, Phase B — Sidebar dev-server visibility (G1) — DONE 2026-07-11, Phase C — Git workflow depth (G3, G4) — SPLIT 2026-07-11 (Opus planning pass) (+7 more)

### Community 307 - "ViPathTokenTests"
Cohesion: 0.19
Nodes (7): Bool, NSObjectProtocol, Set, String, Tab, TabID, WorktreeAutoIsolateService

### Community 308 - "Send Ex Command"
Cohesion: 0.07
Nodes (28): CustomStringConvertible, Error, ExpressibleByStringLiteral, InstallError, unsupported, DaemonClientError, connectionFailed, timeout (+20 more)

### Community 311 - "Bug: Tab-Switch Black Screen"
Cohesion: 0.40
Nodes (5): FluidityBenchmarks, KouenTerminalSurfaceView, NSWindow, String, UInt64

### Community 312 - "AgentSnapshot"
Cohesion: 0.13
Nodes (18): statusColor(), Array, Bool, Date, Decoder, PaneID, PaneNode, String (+10 more)

### Community 313 - "Terminal AI Chat (⌘I inline overlay)"
Cohesion: 0.07
Nodes (31): .agentInfo(forWorktreePath:), AgentNotchDashboardProjection, AgentNotchProjection, AgentNotchRowSummary, RowKind, agent, session, Date (+23 more)

### Community 317 - "Memory — harness-terminal"
Cohesion: 0.44
Nodes (3): SettingsAdvancedView, Bool, String

### Community 319 - "FormatColor"
Cohesion: 0.19
Nodes (6): Bool, Int32, String, URL, SystemdUserInstaller, ServiceInstallerTests

### Community 321 - "UInt64"
Cohesion: 0.29
Nodes (7): TabContextCommand, close, closeOthers, rename, splitHorizontal, splitVertical, togglePersistent

### Community 322 - "DesktopNotifier"
Cohesion: 0.20
Nodes (12): Array, SessionGroup, .init(from:), .init(id:name:tabs:activeTabID:lastActiveTabID:sortOrder:groupID:persistent:), SessionSnapshot, Bool, Decoder, SessionID (+4 more)

### Community 323 - "LayoutNode"
Cohesion: 0.15
Nodes (11): Bool, CGFloat, DispatchWorkItem, NSCoder, NSColor, NSPoint, NSRect, TimeInterval (+3 more)

### Community 324 - "WorkspaceSymbolIndex"
Cohesion: 0.17
Nodes (4): ScrollbackTests, Character, String, TerminalGridSnapshot

### Community 325 - "FloatingPaneController"
Cohesion: 0.21
Nodes (10): RGBColor, .init(from:), .init(hex:), .init(red:green:blue:alpha:), Bool, Decoder, Double, Encoder (+2 more)

### Community 327 - ".theme"
Cohesion: 0.42
Nodes (5): PaneOutputWaiter, PaneOutputWaitResult, CheckedContinuation, Never, UInt64

### Community 328 - "README.md"
Cohesion: 0.36
Nodes (3): Install, Shell integration (OSC 133 semantic prompts), What gets emitted

### Community 329 - "ImmersivePalette.swift"
Cohesion: 0.22
Nodes (3): Double, PaneID, UUID

### Community 330 - ".drawGlyph"
Cohesion: 0.21
Nodes (12): CellMetrics, ComposedFrame, CellMetrics, ComposedTerminalView, Bool, CellColorResolver, CGFloat, CGPoint (+4 more)

### Community 331 - ".recordReapedGenerationForTesting"
Cohesion: 0.20
Nodes (10): PaneRef, bottom, byID, byIndex, last, left, next, previous (+2 more)

### Community 333 - "RealPty"
Cohesion: 0.23
Nodes (5): RealPty, .init(forTesting:), UUID, Void, RealPtyReapRecordTests

### Community 334 - "ImageProtocolTests.swift"
Cohesion: 0.31
Nodes (5): KouenThemeCatalog, KouenThemeDefinition, Bool, RGBColor, String

### Community 335 - ".makeModel"
Cohesion: 0.21
Nodes (8): NSView, NSViewCornerConfiguration, String, TimeInterval, Toast, ToastBody, ToastHostingView, NSHostingView

### Community 336 - "run.sh"
Cohesion: 0.70
Nodes (4): kill_stale(), kill_stale_prod(), run.sh script, usage()

### Community 337 - "CommandExecutionError"
Cohesion: 0.18
Nodes (14): RepoGitMetadata, SidebarListModel, SidebarSessionRow, divider, groupHeader, session, worktree, worktreeHeader (+6 more)

### Community 338 - "CSIParams"
Cohesion: 0.15
Nodes (12): AgentNotchPeekDecider, Reason, errored, finished, needsInput, RowState, Bool, String (+4 more)

### Community 339 - "Foundation"
Cohesion: 0.10
Nodes (18): AppKit, CoreGraphics, CoreText, ImageIO, KouenCopyMode, KouenTerminalEngine, KouenTerminalRenderer, KouenTheme (+10 more)

### Community 341 - "code:bash (harness-cli install-hooks pi)"
Cohesion: 0.31
Nodes (4): FrameBuilderCopyModeTests, RGBColor, String, TerminalGridSnapshot

### Community 342 - "Added"
Cohesion: 0.30
Nodes (7): Bool, NSPasteboard, NSString, String, URL, TerminalServicesProvider, AutoreleasingUnsafeMutablePointer

### Community 343 - "[2.2.3] - 2026-06-09"
Cohesion: 0.33
Nodes (5): CodingKey, CodingKeys, description, key, showInBanner

### Community 344 - "FileViewerViewController"
Cohesion: 0.18
Nodes (7): FileViewerViewController, Bool, NSEvent, Set, String, URL, Void

### Community 346 - "Agent platform icons"
Cohesion: 0.50
Nodes (3): Agent platform icons, Lobe Icons — MIT License, Third-party notices

### Community 347 - "[3.2.0] - 2026-06-16"
Cohesion: 0.11
Nodes (17): 1.1 Architecture, 1.2 Algorithm review, 1.3 Structure findings, 2.1 Structure, 2.2 Risk register (ranked), 3.1 Current implementation, 3.2 Why nothing shows (ranked root-cause candidates), 3.3 Fix plan (+9 more)

### Community 349 - "Contents.json"
Cohesion: 0.24
Nodes (3): KouenSettingsTests, URL, Void

### Community 350 - "Background Polling & Snapshot Fanout — P22"
Cohesion: 0.19
Nodes (4): URL, MobileBridgeAttachFileTests, String, URL

### Community 351 - "Architecture Decisions — harness-terminal"
Cohesion: 0.20
Nodes (9): InterruptFlag, ReplayClient, ReplayPlayer, Bool, Data, DispatchSourceSignal, Double, Int32 (+1 more)

### Community 352 - "Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)"
Cohesion: 0.33
Nodes (6): SurfaceProgressTracker, DispatchWorkItem, MainActor, SurfaceID, TimeInterval, Void

### Community 353 - "GPU Animation Pattern — Layout Once, GPU Paints"
Cohesion: 0.33
Nodes (4): .setSidebarVisible(_:animated:), SidebarPlacementSyncTests, CGFloat, Void

### Community 354 - "P10: Performance and Feature Roadmap (Terminal First, IDE Convenient)"
Cohesion: 0.26
Nodes (4): String, TerminalGridCell, TextGrid, WordColumnRangeTests

### Community 355 - ".deepMerge"
Cohesion: 0.16
Nodes (10): Bool, OptionSet, KeySpec, .init(from:), .init(key:modifiers:), Modifiers, Decoder, String (+2 more)

### Community 356 - "SurfaceProgressTracker"
Cohesion: 0.33
Nodes (4): Bool, SessionCoordinator, String, ThemeService

### Community 357 - ".handleCat"
Cohesion: 0.31
Nodes (6): Bool, Counter, Scheduled, SurfaceProgressTrackerTests, DispatchWorkItem, TimeInterval

### Community 358 - "[3.5.1] - 2026-06-20"
Cohesion: 0.38
Nodes (5): ShellInfo, ShellStepView, Bool, String, URL

### Community 359 - "OcclusionTests"
Cohesion: 0.42
Nodes (3): BrowserIntegrationController, NSView, PaneID

### Community 360 - "State"
Cohesion: 0.23
Nodes (7): NotificationPermission, State, denied, granted, undetermined, MainActor, UNAuthorizationStatus

### Community 361 - "FormatStyledSegment.swift"
Cohesion: 0.08
Nodes (19): AutomationStore, KouenAutomation, Bool, Date, String, URL, UUID, AutomationScheduler (+11 more)

### Community 362 - "RGBColor"
Cohesion: 0.17
Nodes (8): MainMenuBuilder, MenuTarget, Bool, NSMenu, NSMenuItem, Selector, String, MenuTargetForkConversationTests

### Community 363 - "generate-cheatsheet.js"
Cohesion: 0.21
Nodes (7): .init(id:cwd:shell:rows:cols:scrollbackBytes:extraEnvironment:termProgram:termProgramVersion:scrollbackURL:), CChar, DaemonSurfaceID, Int32, UInt16, URL, UnsafeMutablePointer

### Community 364 - "[2.2.4] - 2026-06-11"
Cohesion: 0.14
Nodes (11): RecordingEvent, input, metadata, output, resize, ReplayStep, Data, Date (+3 more)

### Community 365 - "Fixes Applied (v3.9.1+)"
Cohesion: 0.15
Nodes (5): TerminalPaneRegistryAccess, KouenTerminalKit, DaemonReconnectPolicy, TimeInterval, DaemonReconnectPolicyTests

### Community 366 - "Consumers"
Cohesion: 0.16
Nodes (12): agentDetail(), AgentInboxBody, AgentInboxPanelView, .init(agents:onSelect:), .init(coder:), AgentInboxRowView, AgentStatusDot, CGFloat (+4 more)

### Community 367 - "DaemonStats"
Cohesion: 0.26
Nodes (10): BlockTintOverlay, .init(coder:), .init(surfaceView:), Bool, CGFloat, KouenTerminalSurfaceView, NSCoder, NSEvent (+2 more)

### Community 368 - "Tab"
Cohesion: 0.21
Nodes (9): ConfigError, unsupportedAgent, writeFailure, MCPConfigWriter, Any, Range, String, URL (+1 more)

### Community 369 - "Git Panel"
Cohesion: 0.22
Nodes (9): MatchSource, ownProcess, wrapperLaunch, RawMatch, WrapperOptionBehavior, keepScanning, matchValue, skipValue (+1 more)

### Community 370 - ".encode"
Cohesion: 0.21
Nodes (4): NotificationCenterProbe, Bool, Void, NotificationCenterProbeTests

### Community 372 - "DynamicInstanceBuffer"
Cohesion: 0.09
Nodes (20): clamp(), statusHelp(), CGFloat, Date, NSHostingView, Range, SplitDirection, String (+12 more)

### Community 374 - ".run"
Cohesion: 0.25
Nodes (4): ControlKeyNormalizer, Bool, String, ControlKeyNormalizerTests

### Community 375 - ".install"
Cohesion: 0.06
Nodes (15): KouenDaemonCore, ClaudeCodeHarnessIPCTests, String, URL, DaemonBrowserRoutingTests, IPCCodecInvariantTests, String, URL (+7 more)

### Community 377 - "Identifiable"
Cohesion: 0.17
Nodes (6): ScriptConfigLocator, Bool, String, ScriptHookCoordinator, Bool, String

### Community 378 - "SurfaceProgressTrackerTests.swift"
Cohesion: 0.14
Nodes (10): ResizeHUDView, .init(coder:), .init(frame:), DispatchWorkItem, NSCoder, NSColor, NSPoint, NSRect (+2 more)

### Community 379 - "MCPServer"
Cohesion: 0.24
Nodes (6): ScriptFileWatcher, DispatchSourceFileSystemObject, DispatchWorkItem, String, TimeInterval, Void

### Community 380 - "PromptQueue"
Cohesion: 0.16
Nodes (11): Set, SurfaceRegistryTests, .firstSurfaceID(for:in:), .firstSurfaceID(forSession:in:), PaneID, SessionID, SessionSnapshot, String (+3 more)

### Community 382 - "ThaiClusterRenderTests"
Cohesion: 0.22
Nodes (6): merged, JSONMerge, Any, Bool, String, JSONMergeTests

### Community 383 - "terminal_stress_runner.py"
Cohesion: 0.19
Nodes (4): SnapshotCoalescer, MainActor, Void, AgentApprovalBarTests

### Community 384 - "NSTextField Leak in BoardViewController (P20 Performance)"
Cohesion: 0.11
Nodes (15): Identifiable, CompleteStepView, Void, DiscoverStepView, Point, String, OnboardingStep, complete (+7 more)

### Community 386 - "SKILL-LOG.md"
Cohesion: 0.14
Nodes (11): .webView(_:didCommit:), BrowserPaneViewTests, MockWebView, Bool, CGFloat, CGPoint, URL, WKNavigation (+3 more)

### Community 387 - "User Profile"
Cohesion: 0.24
Nodes (8): DisplayPanesChipView, DisplayPanesOverlay, Any, NSEvent, NSView, NSViewCornerConfiguration, SurfaceID, Void

### Community 388 - "Darwin"
Cohesion: 0.12
Nodes (17): Bool, String, WorkbenchCommand, ack, agent, attention, board, cd (+9 more)

### Community 390 - "UI Automation — Robot Framework (P18)"
Cohesion: 0.21
Nodes (6): RepoResolver, Bool, String, RepoResolverTests, KouenCLI, String

### Community 391 - "AppKit + Metal Patterns"
Cohesion: 0.14
Nodes (6): CSIParams, Pen, SavedCursor, TerminalGridColor, TerminalGridUnderline, UInt8

### Community 402 - "View"
Cohesion: 0.10
Nodes (29): Color, MonoPillButtonStyle, Configuration, Configuration, TabBarIconButtonStyle, TabBarInlineIconButtonStyle, ButtonStyle, CommandRow (+21 more)

### Community 403 - "PresentAttempt"
Cohesion: 0.36
Nodes (6): BrowserCookie, IPCRequest, Bool, Double, SplitDirection, URL

### Community 404 - "Split Panes (NSSplitView)"
Cohesion: 0.25
Nodes (7): CodingKeys, activeSessionID, activeTabID, id, name, sortOrder, tabs

### Community 405 - "AgentIconRenderer"
Cohesion: 0.22
Nodes (8): SSHTunnelError, exitedEarly, invalidConfiguration, launchFailed, notReady, Int32, String, TimeInterval

### Community 406 - "main.swift"
Cohesion: 0.13
Nodes (11): Bool, NSEvent, NSPopover, NSRange, NSString, Void, SyntaxTextView, .init(frame:) (+3 more)

### Community 408 - "IPC Architecture"
Cohesion: 0.22
Nodes (7): PasteController, Bool, Data, NSPasteboard, String, TimeInterval, URL

### Community 409 - "Session/Tab/Pane Hierarchy & Top Bar (CASE-028)"
Cohesion: 0.24
Nodes (11): atomicWrite(), backupCorruptFile(), fnv1aHex(), KouenPathsError, socketPathTooLong, Bool, Data, String (+3 more)

### Community 415 - "markdown.json"
Cohesion: 0.46
Nodes (3): SessionSnapshot, Tab, WorkbenchContextResolverTests

### Community 416 - "python.json"
Cohesion: 0.43
Nodes (3): .agentInfo(forWorktreePath:tabs:), Tab, GitPanelViewWorktreeAgentTests

### Community 417 - "rust.json"
Cohesion: 0.33
Nodes (4): FormatContextBuilder, DaemonSurfaceID, SessionSnapshot, String

### Community 418 - ".build"
Cohesion: 0.53
Nodes (3): ProjectConfig, Bool, String

### Community 419 - "typescript.json"
Cohesion: 0.13
Nodes (14): Artifacts, Client Application — Shader Presets (F4) — **UI REVERTED 2026-07-11, user call**, Client Application — Task Dashboard (F1), Context, Data Storage — Tasks (F1), Dev Task Progress — P40 MCP Surface Expansion + Shader Presets, Integration, Lessons applied (from `agent-memory/knowledge/rl-lessons.md`, surfaced during this session's P38 review) (+6 more)

### Community 421 - "FilePreviewCoordinatorTabScopeTests"
Cohesion: 0.33
Nodes (6): RawSelection, Bool, SelectionGranularity, character, line, word

### Community 422 - "HintModeOverlay"
Cohesion: 0.23
Nodes (6): CaseIterable, Mode, compatible, kouen, TerminalIdentity, TerminalIdentityTests

### Community 424 - ".parseDiffHunks"
Cohesion: 0.36
Nodes (3): GitPanelViewHunkStagingTests, String, URL

### Community 425 - "AgentVectorIcon"
Cohesion: 0.17
Nodes (12): CodingKeys, appearance, applyToTerminalOutput, backgroundBlur, backgroundOpacity, contrastGrade, fontFamily, fontSize (+4 more)

### Community 426 - "Bug — Cmd+\ sidebar toggle gone after collapse"
Cohesion: 0.18
Nodes (10): AgentHookStrategy, eventArrayJSON, eventMatcherJSON, namedGroupJSON, ownJSONFile, ownTextFile, regionEdit, Any (+2 more)

### Community 427 - ".delay"
Cohesion: 0.12
Nodes (12): AgentNotchPresentation, closed, open, peek, AgentNotchViewModel, AgentNotchWindowActivator, Bool, CGFloat (+4 more)

### Community 428 - "TaskDashboardView"
Cohesion: 0.33
Nodes (3): DisplayWidth, String, Unicode

### Community 429 - "Case: cwd "bleed" — session worktree jumps to wrong dir during builds"
Cohesion: 0.47
Nodes (5): AgentIconArt, AgentVectorIcon, Bool, CGSize, String

### Community 432 - "PathToken"
Cohesion: 0.47
Nodes (4): PathToken, PathTokenParser, Bool, String

### Community 433 - "LaunchdServiceInstaller"
Cohesion: 0.30
Nodes (6): AgentCatalog, AgentConfig, DiskAgentConfig, Bool, String, agents

### Community 434 - "Project History"
Cohesion: 0.29
Nodes (3): Bool, String, ThaiClusterRenderTests

### Community 435 - ".init"
Cohesion: 0.14
Nodes (11): MTLLibrary, MTLRenderPipelineState, ImageTextureCache, MTLDevice, MTLTexture, UInt8, CGFloat, MTLBuffer (+3 more)

### Community 436 - "WaitForRegistry"
Cohesion: 0.11
Nodes (6): NSTextView, TabID, WorkspaceID, KouenApp, GitPanelViewDiffPopoverTests, GitPanelViewWorktreeNavigationTests

### Community 437 - "Feature Specs"
Cohesion: 0.50
Nodes (4): WriteOutcome, complete, failed, wouldBlock

### Community 438 - "SessionEditor"
Cohesion: 0.24
Nodes (6): HintModeOverlay, Any, KouenTerminalSurfaceView, NSEvent, NSView, String

### Community 439 - "SetupStepView"
Cohesion: 0.40
Nodes (5): Command, TargetKind, pane, session, window

### Community 442 - "GroupedSessionDaemonTests"
Cohesion: 0.60
Nodes (3): BlockSummary, Date, String

### Community 443 - "main.swift"
Cohesion: 0.24
Nodes (7): buffers, DynamicInstanceBuffer, MTLBuffer, MTLDevice, Range, String, T

### Community 444 - "BlockContextMenuTests"
Cohesion: 0.31
Nodes (4): CLIInstaller, Bool, String, URL

### Community 445 - "Section"
Cohesion: 0.22
Nodes (10): DotView, .init(coder:), .init(frame:), Bool, Context, NSCoder, NSColor, NSRect (+2 more)

### Community 446 - "Modifiers"
Cohesion: 0.20
Nodes (6): FormatContextDaemonTests, PaneID, SessionSnapshot, String, SurfaceID, URL

### Community 447 - "PaletteMode"
Cohesion: 0.50
Nodes (4): PaletteMode, errors, grep, normal

### Community 448 - "ClaudeRunSummary"
Cohesion: 0.83
Nodes (3): BufferSummary, Data, Date

### Community 449 - "PresentAttempt"
Cohesion: 0.50
Nodes (4): PresentAttempt, encodeFailure, nilDrawable, presented

### Community 452 - "tmux parity — status, adaptations, and deliberate divergences"
Cohesion: 0.29
Nodes (7): Adapted (same capability, Kouen-shaped), At parity, Deferred (tracked, unimplemented), Implemented (previously deferred, now shipped), Invariants this ledger protects, Rejected (with rationale), tmux parity — status, adaptations, and deliberate divergences

### Community 453 - ".findLeaf"
Cohesion: 0.50
Nodes (3): PaneID, PaneLeaf, PaneNode

### Community 455 - "ComposerPanel"
Cohesion: 0.17
Nodes (11): ComposerPanel, .textView(_:doCommandBy:), .textView(_:shouldChangeTextIn:replacementString:), Bool, NSEvent, NSRange, NSTextView, NSWindow (+3 more)

### Community 457 - ".normalizedKey"
Cohesion: 0.31
Nodes (6): AnimatablePair, NotchShape, CGFloat, CGPath, CGRect, Path

### Community 459 - ".encode"
Cohesion: 0.42
Nodes (6): InstallResult, ShellCompletionInstaller, Bool, String, URL, ShellIntegration

### Community 462 - "AGENTS.md"
Cohesion: 0.13
Nodes (13): Architecture, Build & test, Coding constraints, Communication: GUI ↔ Daemon ↔ CLI, Generated files (do not hand-edit), Graphify + agent-memory, IPC safety, Package map (+5 more)

### Community 464 - "MouseButton"
Cohesion: 0.14
Nodes (13): Artifacts, Category 1 — Pure refactor + extraction (no behavior change), Category 2 — Agents segment UI + aggregate refresh (A1 + A2), Category 3 — Merge/handoff action (A3), Category 4 — Regression + final gate, Context, Last updated: 2026-07-13, Lessons Learnt reviewed (+5 more)

### Community 465 - "DirectionalAxis"
Cohesion: 0.28
Nodes (6): KouenTerminalSurfaceView, Bool, NSEvent, ViInputMode, insert, normal

### Community 466 - "ReflowFastPathTests"
Cohesion: 0.12
Nodes (8): OnboardingController, KouenOnboarding, Agent, OnboardingEnvironment, Bool, String, BinaryInstallerDisplayTests, OnboardingEnvironmentTests

### Community 471 - ".evaluateStyled"
Cohesion: 0.14
Nodes (13): 1. Tasks — storage + MCP + IPC contracts, 2. Worktree (MCP resource) — MCP contracts only, 3. Hosts (MCP resource) — one read-only tool, 4. Shader Presets — rendering pipeline change, Host (MCP resource) — no new aggregate, Logical Design, Open items for task-design to resolve (not blocking, just unresolved here), P40 — MCP Surface Expansion (Tasks/Worktrees/Hosts) + Shader Presets (+5 more)

### Community 473 - "HarnessOnboarding"
Cohesion: 0.14
Nodes (9): GridCompositorParityTests, LiveCompositorFixture, Bool, String, TerminalGridSnapshot, PortCompositorFixture, Bool, String (+1 more)

### Community 475 - ".hitTest"
Cohesion: 0.06
Nodes (36): TerminalGridSnapshot, .readGrid(scrollbackOffset:), ImagePlacementSnapshot, Bool, String, UInt8, TerminalCellWidth, normal (+28 more)

### Community 476 - ".steps"
Cohesion: 0.24
Nodes (3): RemoteHostStoreTests, String, URL

### Community 478 - ".install"
Cohesion: 0.14
Nodes (13): Artifacts, Bigger finding: the planned "Add to Workspace" entry point was unreachable (2026-07-17), Bug found via real `make preview` testing (2026-07-17, post-Task-6), Client Application, Context, Dev Task Progress — Add Repo/Folder to Workspace (P43), Fourth real bug, surfaced by the label becoming honest (2026-07-17), Infrastructure / Data Storage (+5 more)

### Community 479 - "ScrollbackTests"
Cohesion: 0.40
Nodes (3): ReflowFastPathTests, String, TerminalEmulator

### Community 480 - "Command Prompt Architecture"
Cohesion: 0.31
Nodes (3): ReflowPreviewTests, String, TerminalEmulator

### Community 482 - ".resolve"
Cohesion: 0.40
Nodes (4): RawSelection, SelectionResolver, Bool, KouenTerminalSurfaceView

### Community 483 - "Changed"
Cohesion: 0.25
Nodes (3): FlushSessionStateTests, String, URL

### Community 492 - "Service Decomposition — SessionCoordinator (P17)"
Cohesion: 0.33
Nodes (3): KouenTerminalSurfaceWorkerTests, Bool, KouenTerminalSurfaceView

### Community 500 - ".json"
Cohesion: 0.25
Nodes (6): BinaryRefresher, Bool, URL, BinaryRefresherTests, String, URL

### Community 501 - "Fixed"
Cohesion: 0.15
Nodes (12): Artifacts, Client Application, Client Application, Client Application, Context, Dev Task Progress — P37 Phase G: Autocomplete (mobile bridge), G1 — @ file-path picker ✅ DONE 2026-07-13, G2 — shell tab-completion suggestion strip (heuristic, best-effort) ✅ DONE 2026-07-13 (+4 more)

### Community 503 - "Build Scripts Self-Kill Protection"
Cohesion: 0.10
Nodes (21): .init(coder:), BrowserProgressLine, .init(coder:), .init(frame:), BrowserTabButton, .init(coder:), .init(title:isActive:onSelect:onClose:), DesignModePopoverViewController (+13 more)

### Community 506 - "KittyGraphicsCommand"
Cohesion: 0.22
Nodes (7): Bool, NotificationEvent, agentFinished, agentWaiting, bell, commandFinished, Bool

### Community 509 - "start.mjs"
Cohesion: 0.70
Nodes (4): main(), runCommand(), selectWithArrows(), selectWithReadline()

### Community 510 - "graphify reference: extra exports and benchmark"
Cohesion: 0.22
Nodes (9): .init(url:paneID:webView:), .webView(_:createWebViewWith:for:windowFeatures:), .webView(_:didFinish:), BrowserTab, UUID, WKWebView, tabs, WKNavigationAction (+1 more)

### Community 511 - ".panePathLookup"
Cohesion: 0.22
Nodes (7): State, error, indeterminate, paused, remove, set, TerminalProgressReport

### Community 512 - "Changelog Archive"
Cohesion: 0.23
Nodes (4): PromptQueue, String, SurfaceID, Void

### Community 513 - "ThemeDocument"
Cohesion: 0.25
Nodes (8): .webView(_:didFail:withError:), .webView(_:didFailProvisionalNavigation:withError:), .webView(_:didStartProvisionalNavigation:), LoadCompletionState, CheckedContinuation, Error, TimeInterval, WKNavigation

### Community 514 - "graphify reference: extra exports and benchmark"
Cohesion: 0.27
Nodes (7): Never, Set, String, Task, URL, Void, WorkspaceSymbolIndex

### Community 517 - ".testManyConcurrentSubscribersAllReceiveOutput"
Cohesion: 0.24
Nodes (5): ConcurrentIndexSet, DaemonContentionTests, SubscriptionBox, String, URL

### Community 522 - "ShellCompletionInstallerTests"
Cohesion: 0.27
Nodes (6): AmbientBackground, Bool, CGSize, GraphicsContext, TimeInterval, UInt8

### Community 526 - "Kind"
Cohesion: 0.22
Nodes (9): ImmersivePalette, Motion, Radius, Spacing, SUI, CGFloat, Double, NSColor (+1 more)

### Community 527 - "Agent hooks for Harness"
Cohesion: 0.29
Nodes (7): Agent hooks for Kouen, CLI notification, Example Claude Code hook, Jump to waiting agent, OSC sequences (from terminal output), Per-agent guides, Set up via your IDE (copy/paste prompt)

### Community 530 - "HarnessChrome"
Cohesion: 0.29
Nodes (8): FormatColor, none, palette, rgb, StyledSegment, Bool, String, UInt8

### Community 531 - ".text"
Cohesion: 0.35
Nodes (3): ShellCompletionInstallerTests, String, URL

### Community 534 - "ANSIPalette"
Cohesion: 0.28
Nodes (7): SettingsTerminalView, Bool, String, TriState, auto, off, on

### Community 535 - "AgentNotification"
Cohesion: 0.17
Nodes (11): A — detection core (`AgentDetector`, pure logic), B — Claude Code Task-subagent hook push (in-process detection), C — IPC / Tab plumbing, Concurrency contract, Corrections to the original plan text (verified against live source, not assumed), D — Client UI indicator, Open items deferred out of this phase (documented, not silently dropped), P38 Phase B — Subagent/Teammate Visibility (+3 more)

### Community 537 - "TabAlertTests"
Cohesion: 0.36
Nodes (5): OcclusionTests, KouenTerminalSurfaceView, NSWindow, String, TimeInterval

### Community 538 - "SessionGroupHeaderRowView"
Cohesion: 0.06
Nodes (36): PaneLeaf, SessionGroup, Any, String, Tab, MainActor, Void, SessionDividerRowView (+28 more)

### Community 539 - "install-app.sh"
Cohesion: 0.24
Nodes (4): SavedLayoutIPCDaemonTests, String, URL, UUID

### Community 544 - "Task Ledger Archive (Tasks 1–50)"
Cohesion: 0.51
Nodes (9): fuzzyFindFiles(), handleErrors(), handleFind(), handleGrep(), handleMake(), handleRecent(), Int32, String (+1 more)

### Community 546 - "LegacySnapshot"
Cohesion: 0.11
Nodes (14): JSONDecoder, JSONEncoder, LegacySnapshot, LegacyWorkspace, Bool, Date, String, Tab (+6 more)

### Community 547 - "NSObject"
Cohesion: 0.12
Nodes (18): center, ClosureTarget, MenuActionTarget, OverlayWindow, Phase67UI, PopupWindow, Bool, Command (+10 more)

### Community 551 - ".startWatching"
Cohesion: 0.22
Nodes (8): AnyObject, CommandExecutionError, daemonError, noActiveSurface, targetNotFound, unsupportedInThisContext, CommandExecutor, String

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
Cohesion: 0.10
Nodes (21): FileTreeKeyboardNavigator, FileTreeKeyboardState, Bool, NSEvent, String, Void, FileTreeContext, Bool (+13 more)

### Community 582 - "FileTreeKeyboardNavigator"
Cohesion: 0.22
Nodes (6): GitStatusProvider, Data, String, GitStatusProviderLargeOutputTests, URL, TimeoutError

### Community 586 - ".statusLineSet"
Cohesion: 0.19
Nodes (6): JSONOutputFormatter, Bool, String, T, JSONOutputFormatterTests, T

### Community 589 - "Endpoint"
Cohesion: 0.17
Nodes (8): CopyModeViewportSelection, Kind, block, linear, GridCompositorCopyModeTests, PaneRect, String, TerminalGridSnapshot

### Community 591 - "NodeRow"
Cohesion: 0.47
Nodes (3): ScrollReuseTests, KouenTerminalSurfaceView, NSWindow

### Community 594 - "KeyRecorderView.swift"
Cohesion: 0.28
Nodes (5): SpecialKeyMappingTests, Bool, NSEvent, String, UInt16

### Community 596 - "prepare-release.sh"
Cohesion: 0.53
Nodes (4): display_menu(), run(), prepare-release.sh script, usage()

### Community 600 - "HarnessTerminalSurfaceView"
Cohesion: 0.10
Nodes (16): NSRangePointer, NSTextInputClient, KouenTerminalSurfaceView, Any, Bool, NSAttributedString, NSEvent, NSPoint (+8 more)

### Community 613 - "INDEX.md"
Cohesion: 0.18
Nodes (10): Current architecture relevant to these gaps, P38 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed), Phase A — Cross-agent diff/review dashboard (biggest gap vs Superset/Supacode) — ✅ DONE 2026-07-13, see p38-phase-a-diff-dashboard/{design.md,dev-task-progress.md}, Phase B — Subagent/teammate visibility as panes (vs cmux) — ✅ CLOSED 2026-07-16 (build/test/robot green, live check skipped per user decision), Phase C — Agent "thread" UX on top of existing block capture (vs Zed Terminal Threads) — ⚠️ pivoted 2026-07-15, ✅ CLOSED 2026-07-16 (build/test/robot green, cross-pane jump-to-block live check skipped per user decision), see p38-phase-c-thread-overlay/{design.md,dev-task-progress.md}, Phase D — Terminal image protocol (Kitty Graphics) — vs WezTerm — ✅ D1 DONE 2026-07-14 (finding: NOT deferred), D3 conformance slice built, ✅ CLOSED 2026-07-16 (build/test/robot green, real-client live check skipped per user decision), Phase E — Scripting hook parity (JS vs WezTerm's Lua) — low priority — ✅ DONE 2026-07-14, ✅ CLOSED 2026-07-16 (low-priority live check skipped per user decision), Phases (+2 more)

### Community 614 - "MainSplitViewController"
Cohesion: 0.09
Nodes (20): CGFloat, MainSplitViewController, .setSidebarVisible(_:), SplitChromeDelegate, .splitView(_:constrainMaxCoordinate:ofSubviewAt:), .splitView(_:constrainMinCoordinate:ofSubviewAt:), .splitView(_:effectiveRect:forDrawnRect:ofDividerAt:), .splitView(_:shouldAdjustSizeOfSubview:) (+12 more)

### Community 617 - "ScriptFileWatcher"
Cohesion: 0.11
Nodes (23): CodingKeys, activeSurfaceID, daemonSurfaceID, id, surfaceID, surfaces, PaneLeaf, .init(from:) (+15 more)

### Community 621 - "ViEngine"
Cohesion: 0.12
Nodes (6): Bool, String, ViEngine, KouenCLI, KouenLSP, QuickLookUI

### Community 622 - "[1.3.0-vit] - 2026-06-06"
Cohesion: 0.50
Nodes (3): LiveResizeGeometry, Result, Bool

### Community 623 - "BrowserResponsePayload"
Cohesion: 0.12
Nodes (9): PaneNode, KouenIPC, BrowserLeaf, URL, DaemonSyncServiceBrowserPaneMergeTests, PaneID, PaneNode, PaneNodeBrowserTests (+1 more)

### Community 624 - "[2.5.0] - 2026-06-12"
Cohesion: 0.33
Nodes (5): CopyModeLine, .charIndex(atOrAfter:), .charIndex(atOrBefore:), Character, String

### Community 627 - "ActiveTabCloseDisposition"
Cohesion: 0.17
Nodes (8): OutputTrigger, OutputTriggerStore, Bool, String, .event(_:), StaticString, .receive(_:), Data

### Community 629 - "graphify reference: query, path, explain"
Cohesion: 0.32
Nodes (6): CGFloat, ResizeDirection, down, left, right, up

### Community 637 - "ClientSummary"
Cohesion: 0.05
Nodes (29): NSCursor, .interval(_:_:), T, KouenTerminalSurfaceView, .init(themeName:fontFamily:fontSize:vivid:colorRendering:colorGamut:offMainParserFramePipeline:liveResizeReflow:), PendingMainHop, SurfaceColorProviderState, SurfaceEmulatorState (+21 more)

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
Cohesion: 0.15
Nodes (14): Dispatch, Charset, ascii, decSpecialGraphics, Counter, DrainResult, DrainState, EchoRTT (+6 more)

### Community 654 - "press_shortcut"
Cohesion: 0.36
Nodes (3): BlockContextMenuTests, KouenTerminalSurfaceView, String

### Community 659 - "MCPServer"
Cohesion: 0.24
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
Cohesion: 0.60
Nodes (4): CLICommand, CLICommandCatalog, Bool, String

### Community 669 - ".recordReapedGenerationForTesting"
Cohesion: 0.28
Nodes (4): PaneLabelDaemonTests, String, URL, UUID

### Community 670 - "[3.9.1] - 2026-06-22"
Cohesion: 0.20
Nodes (6): LayoutTemplate, evenHorizontal, evenVertical, mainHorizontal, mainVertical, tiled

### Community 671 - "AgentKind"
Cohesion: 0.38
Nodes (5): Result, ShellRCWiring, Bool, String, URL

### Community 672 - "ColorKind"
Cohesion: 0.29
Nodes (7): DiagnosticCheck, DiagnosticStatus, fail, pass, warn, DoctorReport, Int32

### Community 675 - ".detect"
Cohesion: 0.29
Nodes (6): Accessibility Identifiers Required, Architecture, Kouen Robot Framework Tests, Prerequisites, Run, Troubleshooting

### Community 678 - "FilePreviewCoordinator"
Cohesion: 0.39
Nodes (3): data, SixelDecoder, UInt8

### Community 681 - "Cross-terminal output-stress benchmark"
Cohesion: 0.40
Nodes (4): Cross-terminal output-stress benchmark, Run, The faithful scoreboard, What it measures — and what it does NOT

### Community 685 - "[1.5.1] - 2026-06-06"
Cohesion: 0.33
Nodes (6): emitArray(), hex(), referenceWidth(), String, T, UInt8

### Community 691 - "Phase6KeysTests"
Cohesion: 0.12
Nodes (9): BrowserPaneView, DesignModeElementInfo, Bool, NSPopover, NSStackView, Selector, String, URL (+1 more)

### Community 692 - ".testOptionLinesAreNotCommands"
Cohesion: 0.40
Nodes (3): KouenGridTerminal, TerminalGridCell, TerminalEmulator

### Community 693 - "[2.0.0] - 2026-06-07"
Cohesion: 0.33
Nodes (5): Claude Code → Kouen, Customizing, One-line install, Verifying, What gets written

### Community 694 - "TerminalScreen"
Cohesion: 0.29
Nodes (6): SecureInputMonitor, DispatchWorkItem, Set, String, SurfaceID, Carbon

### Community 696 - "TerminalTabBarDelegate"
Cohesion: 0.25
Nodes (7): Avoid, Colors, Components, Design Direction, Design System, Spacing / Radius / Motion, Typography

### Community 708 - "[3.4.0] - 2026-06-19"
Cohesion: 0.12
Nodes (11): Command, PanePipe, .subscribe(surfaceID:handler:), Bool, FileHandle, Int32, SessionID, String (+3 more)

### Community 709 - ".start"
Cohesion: 0.14
Nodes (5): PipeBuffer, Result, String, UInt16, MobileBridgeAISuggestTests

### Community 710 - "MainWindowController"
Cohesion: 0.16
Nodes (7): KouenWindow, NSEvent, MainWindowController, Any, NSRect, NSWindow, NSWindowController

### Community 711 - "FileTabManager"
Cohesion: 0.10
Nodes (12): KouenPaths, SessionStore, DispatchWorkItem, SessionSnapshot, TimeInterval, URL, GroupedSessionDaemonTests, String (+4 more)

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
Cohesion: 0.11
Nodes (18): DataBox, .init(coder:), .init(frame:), HunkActionButton, .init(coder:), .init(title:onClick:), StageToggleButton, .init(coder:) (+10 more)

### Community 727 - "PromptQueueBar"
Cohesion: 0.50
Nodes (3): __kouen_osc133_postexec, __kouen_osc133_preexec, __kouen_osc133_prompt

### Community 728 - "[2.5.1] - 2026-06-12"
Cohesion: 0.50
Nodes (3): Grok Build → Kouen, One-line install, What you'll see

### Community 732 - "ReplayStep"
Cohesion: 0.50
Nodes (3): SplitDirection, horizontal, vertical

### Community 736 - "graphify reference: add a URL and watch a folder"
Cohesion: 0.25
Nodes (7): Core Features, Core Problems, Out of Scope, Product, Success Metrics, Target Users, Vision

### Community 737 - ".resolve"
Cohesion: 0.40
Nodes (4): #connect, #log, #term, tokenFromQR

### Community 744 - "TerminalGridCellLayoutTests"
Cohesion: 0.22
Nodes (4): AgentScanner, Bool, DispatchSourceTimer, TimeInterval

### Community 745 - "p11_scripting.robot"
Cohesion: 0.20
Nodes (3): AgentRoutingRuleIPCDaemonTests, String, URL

### Community 764 - "Workbench commands (IDE-like workflow)"
Cohesion: 0.33
Nodes (6): Board and attention, Errors and LSP, File navigation, Search, Task runner, Workbench commands (IDE-like workflow)

### Community 797 - "Motion"
Cohesion: 0.50
Nodes (3): Kouen Domain Language, MCP Surface, Relationships

### Community 865 - "MCPServer"
Cohesion: 0.29
Nodes (3): KouenMCPServer, MCPServer, String

### Community 949 - "ThaiClusterCopyTests.swift"
Cohesion: 0.23
Nodes (5): BrowserPaneRegistry, .init(url:paneID:), NSWindow, PaneID, WeakBrowserPaneView

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
Cohesion: 0.10
Nodes (15): InlineAICompletionController, KouenSettings, String, KouenOptions, InputGate, ReconnectLatch, Bool, CGFloat (+7 more)

### Community 1173 - ".feedBuffer"
Cohesion: 0.48
Nodes (3): ANSIPalette, RGBColor, UInt8

### Community 1303 - ".pushAgentActivityNotifications"
Cohesion: 0.50
Nodes (3): exclude_hubs, no_viz, wiki

### Community 1306 - ".rememberTabForReopen"
Cohesion: 0.20
Nodes (10): Section, actions, errors, files, grep, navigation, projects, recent (+2 more)

### Community 1309 - ".startMetadataRefresh"
Cohesion: 0.83
Nodes (3): entries(), cheat.sh script, usage()

### Community 1544 - "TargetSpec.swift"
Cohesion: 0.29
Nodes (7): CodingKeys, createdAt, dataBase64, rows, timeMs, type, version

### Community 1801 - "ClientSummary"
Cohesion: 0.25
Nodes (4): Active Plans, Completed, Plans Index — kouen-terminal, Quick ref — recent completions

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
Cohesion: 0.43
Nodes (6): Document, Bool, Set, String, URL, ToolPolicy

### Community 2100 - ".handleWake"
Cohesion: 0.18
Nodes (8): Darwin, Foundation, Glibc, KouenCore, KouenCLI, KouenCLI, String, String

### Community 2176 - "Changed"
Cohesion: 0.29
Nodes (6): Locked decisions (user-confirmed), Logical Design, P38 Phase A — Cross-Agent Worktree Diff/Review Dashboard — Design, Strategic Design, Tactical Design, Verification gate (this phase)

### Community 2242 - "P42 — Workspace Sidebar Panels"
Cohesion: 0.29
Nodes (6): Logical Design, Next Step, P42 — Workspace Sidebar Panels, Parked (not in scope), Strategic Design, Tactical Design

### Community 2541 - "P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable"
Cohesion: 0.33
Nodes (6): Competitive comparison (2026-07-13, post Phase D+E), Current architecture (as shipped, build 195), P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable, Phase F — candidates from competitive research (not scoped, not scheduled), Risk review (ranked), Verification gates (every phase)

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
Cohesion: 0.23
Nodes (3): Bool, pid_t, String

### Community 2938 - "Phases"
Cohesion: 0.40
Nodes (5): Phase A — Hardening (daemon only, no UI), Phase B — In-app pairing UX (macOS Settings), Phase C — Real mobile client (W3, replaces smoke-test page) — DONE 2026-07-09, uncommitted, Phase D — File preview, file attach, browser mirror (v1.1 — the former W4/W4b/W5, now scoped), Phases

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
Cohesion: 0.36
Nodes (4): AboutPanelController, AboutView, NSWindow, NSHostingController

### Community 3515 - "RawRepresentable"
Cohesion: 0.10
Nodes (23): Bool, Command, Binding, .init(from:), .init(spec:command:note:repeatable:), CodingKeys, bindings, disabledSpecs (+15 more)

## Knowledge Gaps
- **3056 isolated node(s):** `AppIntents`, `noActivePane`, `horizontal`, `vertical`, `unsupportedPlatform` (+3051 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2123 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.
- **15 possibly unreachable function(s):** `.addSurface(tabID:paneID:)`, `.agentInfo(forWorktreePath:tabs:)`, `.color(_:)`, `.color(_:alpha:)`, `.encode(_:modifiers:event:modes:)` (+10 more)
  Not reached from any recognized entry point - could be dead code, or dynamically dispatched/decorator-registered.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Int` connect `LiveResizeTests` to `Changelog Archive`, `CodingKey`, `graphify reference: extra exports and benchmark`, `callingPaneTarget`, `EngineConformanceTests`, `IPCRequest`, `AgentNotchRootView`, `.testManyConcurrentSubscribersAllReceiveOutput`, `LSPMessage`, `TerminalEmulator`, `PerformanceBenchmarks`, `GitPanelView.swift`, `KittyKeyboardTests`, `VTParser`, `.applyPreedit`, `MetalRendererTests`, `HarnessUILibrary`, `SpecialKey`, `HarnessChrome`, `HarnessTerminalSurfaceView`, `CopyModeAction`, `SplitPaneCoordinator`, `.request`, `WorktreeManager`, `Harness tmux-style capabilities`, `SessionGroupHeaderRowView`, `.parse`, `RGBColor`, `Notification`, `Sendable`, `.addTab`, `Equatable`, `LegacySnapshot`, `MenuTarget`, `Task Ledger Archive (Tasks 1–50)`, `String`, `HarnessSettings`, `CodingKeys`, `HarnessSidebarPanelViewController.swift`, `RenderSchedulerTests`, `harness.resource`, `.buildCommand`, `.normalizedKey`, `DaemonServer`, `.keyEvent`, `.handleWake`, `HarnessSplitView`, `TabCell`, `newWindow`, `BellScanState`, `CommandHistorySearchController`, `PasteBufferStore`, `FrecencyDirectoryStore`, `ComposedCell`, `HarnessCLI+Server.swift`, `.text`, `PrefixKeymap`, `TerminalProgressReport`, `String`, `worktree_isolation_cli.robot`, `XCTestCase`, `.parse`, `Endpoint`, `HarnessDesign`, `selectWorkspace`, `LSPClient`, `TerminalGridCell`, `HarnessPaths`, `.tomlKouenBlock`, `HarnessTerminalSurfaceView`, `TerminalModes`, `P2 — Async IPC Refactor: Design Document`, `AttachInputBatcher`, `shim.c`, `PaneContainerView`, `MainSplitViewController`, `DaemonLauncher`, `Recipe`, `Changelog`, `AnyCodable`, `AgentNotchViewModel`, `.resolve`, `DamageTrackingTests`, `SoftIconButton`, `[1.3.0-vit] - 2026-06-06`, `.makeSnapshot`, `[2.5.0] - 2026-06-12`, `HarnessGridTerminal`, `.firstWaitingTab`, `graphify reference: query, path, explain`, `WorkspaceFileTreeView`, `ViEngine`, `String`, `HistoryRingBuffer`, `.path`, `ClientSummary`, `GlyphAtlas`, `SwiftUI`, `.install`, `AgentHookInstaller`, `CommandTarget`, `.startWatching`, `ActivePaneService`, `User Story Mapping (MANDATORY)`, `PtyDrainCeilingBenchmark`, `CopyModeGridSource`, `How to use Harness from the terminal only (no GUI)`, `PaneStyleSet`, `AsciiFastPathTests`, `MCPServer`, `.feedBuffer`, `What You Must Do When Invoked`, `Int`, `ThaiCombiningMarkTests`, `TerminalFindBar`, `Workspace`, `CommandPromptController`, `.jumpToBlock`, `FilePreviewCoordinator`, `URLDetection`, `.decodeKeySpec`, `[1.5.1] - 2026-06-06`, `BinaryRefresherTests`, `BlockSummary`, `Added`, `BoardCard`, `InlineAICompletionView`, `Phase6KeysTests`, `.testOptionLinesAreNotCommands`, `[3.13.1] - 2026-07-02`, `P25 — iOS/iPadOS Support`, `LSPServerRegistry`, `VTConformanceCorpusTests`, `SessionSnapshot`, `Error`, `AppDelegate`, `GridCompositorTests`, `P5 — ACP (Agent Client Protocol) — Harness as ACP Editor/Client`, `ScriptRuntime`, `GlyphRasterizer`, `BinaryInstaller`, `Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag`, `ResizeHUDView`, `[3.4.0] - 2026-06-19`, `AgentSessionSummary`, `.classify`, `.start`, `MCP Server (harness-mcp)`, `[3.9.5] - 2026-06-26`, `HarnessCLI`, `scheduleRender`, `.testDataFrameEncodeVsJSONBase64Output`, `PaneTarget`, `CellColorResolverTests`, `GridCompositor`, `TerminalServicesProvider`, `AgentNotchRowSummary`, `ANSIPalette`, `CellColorResolver`, `HarnessPathDisplay`, `SSHTunnelManagerTests`, `ExternalOpenKind`, `P10 Task: Lazy Scrollback Reflow`, `WorkbenchCommand`, `TerminalMetalRenderer`, `PaneBorderStatus`, `[3.5.1] - 2026-06-20`, `.make`, `ThemeDocumentTests`, `ReflowPreviewTests`, `BoardViewController`, `workspace`, `release-hotfix.sh`, `Sidebar SwiftUI Migration — Knowledge`, `WindowTitleStripView`, `ThemeFileServiceTests`, `listSurfaces`, `.welcome`, `.install`, `HarnessSidebarPanelViewController`, `.userNotificationCenter`, `.path`, `[2.2.4] - 2026-06-11`, `[3.11.2] - 2026-06-28`, `DefaultTerminalManager`, `StatusLineView.swift`, `WindowSession`, `[2.5.0] - 2026-06-12`, `SyntaxTextView`, `.run`, `renumberWindows`, `DisplayPanesOverlay`, `.menu`, `TerminalScrollbarView`, `.rememberTabForReopen`, `FormatColor`, `click_ui_element`, `code:bash (harness-cli install-hooks hermes)`, `AgentHookStrategy`, `StatusLineWidthTests`, `Process`, `JSONDecoder`, `Fixes Applied (layered)`, `settings.json`, `HarnessPaths.swift`, `.parse`, `00-inception-plan.md`, `.scrollWheel`, `Send Ex Command`, `FrameSignposter`, `AgentSnapshot`, `Terminal AI Chat (⌘I inline overlay)`, `code:bash (# In a Harness pane:)`, `Focus Persistence — Per-Session-Tab Pane Focus (RL-043)`, `DesktopNotifier`, `LayoutNode`, `WorkspaceSymbolIndex`, `worktree_isolation.robot`, `.theme`, `.drawGlyph`, `.recordReapedGenerationForTesting`, `RealPty`, `.makeModel`, `CommandExecutionError`, `CSIParams`, `Foundation`, `code:bash (harness-cli install-hooks pi)`, `Background Polling & Snapshot Fanout — P22`, `Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)`, `P10: Performance and Feature Roadmap (Terminal First, IDE Convenient)`, `.handleCat`, `FormatStyledSegment.swift`, `generate-cheatsheet.js`, `[2.2.4] - 2026-06-11`, `Fixes Applied (v3.9.1+)`, `Consumers`, `DaemonStats`, `Git Panel`, `DynamicInstanceBuffer`, `.tabIndex(tabID:)`, `SurfaceProgressTrackerTests.swift`, `NSTextField Leak in BoardViewController (P20 Performance)`, `User Profile`, `HarnessCLITests`, `AppKit + Metal Patterns`, `.load`, `PresentAttempt`, `AgentIconRenderer`, `main.swift`, `IPC Architecture`, `Session/Tab/Pane Hierarchy & Top Bar (CASE-028)`, `go.json`, `rust.json`, `FilePreviewCoordinatorTabScopeTests`, `HintModeOverlay`, `.parseDiffHunks`, `.delay`, `TaskDashboardView`, `PathToken`, `Project History`, `.init`, `WaitForRegistry`, `SessionEditor`, `RemoteHostStore`, `GroupedSessionDaemonTests`, `main.swift`, `ClaudeRunSummary`, `RunState`, `.moveSelection`, `HarnessOnboarding`, `.hitTest`, `Added`, `ScrollbackTests`, `Command Prompt Architecture`, `.resolve`, `[3.10.1] - 2026-06-27`, `printThemePreview`, `requireSessionID`, `resolvedCLIPath`, `.json`, `graphify reference: extra exports and benchmark`, `.panePathLookup`?**
  _High betweenness centrality (0.287) - this node is a cross-community bridge._
- **Why does `KouenCore` connect `.handleWake` to `Changelog Archive`, `.handleNormal`, `IPCRequest`, `AgentNotchRootView`, `Command`, `.testManyConcurrentSubscribersAllReceiveOutput`, `TerminalEmulator`, `KittyKeyboardTests`, `HarnessTerminalSurfaceView`, `.applyPreedit`, `MetalRendererTests`, `HarnessUILibrary`, `SpecialKey`, `.text`, `code:block1 (Agent shell process)`, `ANSIPalette`, `WorktreeManager`, `Harness tmux-style capabilities`, `SessionGroupHeaderRowView`, `install-app.sh`, `Sendable`, `Task Ledger Archive (Tasks 1–50)`, `Equatable`, `LegacySnapshot`, `NSObject`, `code:bash (harness chat "Use the project map first, then inspect this r)`, `String`, `HarnessSettings`, `CodingKeys`, `RenderSchedulerTests`, `HarnessTerminalSurfaceView.swift`, `.buildCommand`, `.normalizedKey`, `HookEvent`, `DaemonServer`, `ScrollbackPersistenceTests`, `.keyEvent`, `HarnessSplitView`, `NSPanel`, `BellScanState`, `CommandHistorySearchController`, `3.2 สิ่งที่ implement แล้ว`, `ViEngine`, `HarnessCLI+Server.swift`, `TerminalProgressReport`, `ShellIntegration`, `Completed Plans Archive`, `FileTreeKeyboardNavigator`, `worktree_isolation_cli.robot`, `XCTestCase`, `.statusLineSet`, `.parse`, `TerminalProtocolCompatibilityTests`, `Endpoint`, `HarnessDesign`, `LSPClient`, `LSPDiagnostic`, `.tomlKouenBlock`, `SessionCoordinator`, `Zombie View Crashes on macOS 26.5 + Swift 6.3.2`, `code:bash (# Terminal 1: Create workspace with long-running job)`, `AttachInputBatcher`, `shim.c`, `PaneContainerView`, `4. Technical Architecture`, `.dispatch`, `Session Grouping and Split Session Plan`, `Changelog`, `domain-design.md`, `.resolve`, `ViEngine`, `SoftIconButton`, `BrowserResponsePayload`, `.makeSnapshot`, `DamageTrackingTests`, `.firstWaitingTab`, `clearSelection`, `PaneNode`, `WorkspaceFileTreeView`, `SessionGroup`, `Pipe`, `String`, `ClientSummary`, `.install`, `.load`, `code:js (// ~/.config/harness/init.js)`, `stability_release.robot`, `PtyDrainCeilingBenchmark`, `ActivePaneService`, `User Story Mapping (MANDATORY)`, `.testPaneLeafLegacyDecodeBackfillsSurfaceTabs`, `DecodedImage`, `MCPServer`, `TriState`, `EnvironmentStore`, `New Tab`, `What You Must Do When Invoked`, `ThaiCombiningMarkTests`, `[3.8.0] - 2026-06-22`, `Harness Terminal — IDE Sidebar Feature Branch`, `MatchCategory`, `AmbientBackground`, `sessionCreated`, `.recordReapedGenerationForTesting`, `ActiveTabCloseDisposition`, `AgentTableEntry`, `ReflowCorpusTests`, `.decodeKeySpec`, `RGBColorTests`, `.rects`, `InlineAICompletionView`, `GridCompositorTests`, `TerminalScreen`, `P25 — iOS/iPadOS Support`, `Error`, `AppDelegate`, `user-stories.md`, `ScriptRuntime`, `[2.3.0] - 2026-06-11`, `Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag`, `[2.5.1] - 2026-06-12`, `BinaryInstaller`, `MainWindowController`, `.classify`, `BinaryInstallerVersionTests`, `MCP Server (harness-mcp)`, `PaletteModel`, `FileTabManager`, `AutomationScheduler`, `CopyModeState`, `[2.4.0] - 2026-06-12`, `PaneDropZoneOverlay`, `.translate`, `CellColorResolverTests`, `GridCompositor`, `ScrollbackFile`, `Section`, `ANSIPalette`, `HarnessPathDisplay`, `SSHTunnelManagerTests`, `sessionRow`, `graphify reference: incremental update and cluster-only`, `P10 Task: Lazy Scrollback Reflow`, `TerminalGridCellLayoutTests`, `.scan`, `WorkbenchCommand`, `TextGrid`, `p11_scripting.robot`, `.make`, `TerminalMetalRenderer`, `AgentBridge`, `.make`, `FileNode`, `.renderFixture`, `DaemonMetrics`, `ReflowPreviewTests`, `HarnessTerminalSurfaceWorkerTests`, `[3.4.0] - 2026-06-19`, `Split Right`, `Sidebar SwiftUI Migration — Knowledge`, `.welcome`, `Browser Pane (P14)`, `.install`, `KeySpec`, `SyntaxTextView`, `reorderSession`, `CLICommand`, `DisplayPanesOverlay`, `code:bash (harness-cli install-hooks hermes)`, `.apply`, `.load`, `jobs`, `ThemeDiagnostics`, `.encodeMouse`, `00-inception-plan.md`, `ViPathTokenTests`, `Send Ex Command`, `Terminal AI Chat (⌘I inline overlay)`, `Memory — harness-terminal`, `code:bash (# In a Harness pane:)`, `FormatColor`, `.theme`, `RealPty`, `CommandExecutionError`, `CSIParams`, `Foundation`, `DaemonLifecycleTests`, `Background Polling & Snapshot Fanout — P22`, `Architecture Decisions — harness-terminal`, `Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)`, `GPU Animation Pattern — Layout Once, GPU Paints`, `P10: Performance and Feature Roadmap (Terminal First, IDE Convenient)`, `.deepMerge`, `MCPServer`, `.handleCat`, `OcclusionTests`, `State`, `FormatStyledSegment.swift`, `RGBColor`, `Fixes Applied (v3.9.1+)`, `Consumers`, `SurfaceRegistryTests.swift`, `Tab`, `.encode`, `P13 — Embedded Browser Pane (cmux parity)`, `DynamicInstanceBuffer`, `.run`, `.install`, `Identifiable`, `ThaiClusterRenderTests`, `NSTextField Leak in BoardViewController (P20 Performance)`, `SKILL-LOG.md`, `User Profile`, `UI Automation — Robot Framework (P18)`, `IPC Architecture`, `markdown.json`, `rust.json`, `HintModeOverlay`, `.delay`, `LaunchdServiceInstaller`, `WaitForRegistry`, `ThaiClusterCopyTests.swift`, `BlockContextMenuTests`, `Modifiers`, `.json`, `.run`, `ReflowFastPathTests`, `PresentAttempt`, `HarnessOnboarding`, `.steps`, `Added`, `Changed`, `.json`, `ACP Client (Shelved)`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Why does `Foundation` connect `.handleWake` to `Changelog Archive`, `CodingKey`, `graphify reference: extra exports and benchmark`, `.handleNormal`, `IPCRequest`, `Command`, `TerminalEmulator`, `KittyKeyboardTests`, `.applyPreedit`, `HarnessChrome`, `SpecialKey`, `code:block1 (Agent shell process)`, `SplitPaneCoordinator`, `WorktreeManager`, `SessionGroupHeaderRowView`, `Harness tmux-style capabilities`, `RGBColor`, `Task Ledger Archive (Tasks 1–50)`, `DaemonClient`, `String`, `.startWatching`, `HarnessSettings`, `CodingKeys`, `HarnessSidebarPanelViewController.swift`, `harness.resource`, `HarnessTerminalSurfaceView.swift`, `.buildCommand`, `HookEvent`, `markPane`, `.keyEvent`, `HarnessSplitView`, `BellScanState`, `PasteBufferStore`, `FrecencyDirectoryStore`, `HarnessCLI+Server.swift`, `Completed Plans Archive`, `FileTreeKeyboardNavigator`, `.statusLineSet`, `OptionStore`, `.parse`, `TerminalProtocolCompatibilityTests`, `Endpoint`, `DaemonSubscription`, `LSPClient`, `LSPDiagnostic`, `TerminalGridCell`, `SessionCoordinator`, `Zombie View Crashes on macOS 26.5 + Swift 6.3.2`, `code:bash (# Terminal 1: Create workspace with long-running job)`, `AttachInputBatcher`, `PaneContainerView`, `4. Technical Architecture`, `DaemonLauncher`, `AnyCodable`, `Recipe`, `Changelog`, `ScriptFileWatcher`, `.resolve`, `DamageTrackingTests`, `BrowserResponsePayload`, `.makeSnapshot`, `HarnessGridTerminal`, `.firstWaitingTab`, `ActiveTabCloseDisposition`, `SessionGroup`, `PaneNode`, `WorkspaceFileTreeView`, `ViEngine`, `HistoryRingBuffer`, `SwiftUI`, `AgentHookInstaller`, `[3.10.1] - 2026-06-27`, `CommandTarget`, `.startWatching`, `ActivePaneService`, `User Story Mapping (MANDATORY)`, `PtyDrainCeilingBenchmark`, `graphify reference: query, path, explain`, `TerminalHostView`, `CopyModeGridSource`, `PaneStyleSet`, `AsciiFastPathTests`, `DecodedImage`, `EnvironmentStore`, `.evaluate`, `What You Must Do When Invoked`, `BrowserIntegrationController`, `Int`, `LiveResizeTests`, `[3.9.1] - 2026-06-22`, `MatchCategory`, `ColorKind`, `AgentKind`, `What You Must Do When Invoked`, `CommandPromptController`, `FilePreviewCoordinator`, `URLDetection`, `.decodeKeySpec`, `.hold`, `.rects`, `InlineAICompletionView`, `Added`, `[3.13.1] - 2026-07-02`, `GridCompositorTests`, `Error`, `P5 — ACP (Agent Client Protocol) — Harness as ACP Editor/Client`, `ScriptRuntime`, `BinaryInstaller`, `Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag`, `FileTabManager`, `BinaryInstallerVersionTests`, `MCP Server (harness-mcp)`, `PaletteModel`, `TerminalProgressReport`, `ReplayStep`, `grok`, `PaneDropZoneOverlay`, `PaneTarget`, `.translate`, `NotchLayoutMetrics`, `CellColorResolverTests`, `ScrollbackFile`, `Section`, `ReplayStep`, `TerminalServicesProvider`, `CellColorResolver`, `HarnessPathDisplay`, `FileChangeWatcher`, `sessionRow`, `.decide`, `HarnessGridTerminalTests`, `ExternalOpenKind`, `P10 Task: Lazy Scrollback Reflow`, `TerminalGridCellLayoutTests`, `.scan`, `graphify reference: incremental update and cluster-only`, `.make`, `.copySelection`, `PaneBorderStatus`, `TerminalMetalRenderer`, `.make`, `FileNode`, `.renderFixture`, `ReflowPreviewTests`, `BundledThemesData.swift`, `release-hotfix.sh`, `Sidebar SwiftUI Migration — Knowledge`, `ThemeFileServiceTests`, `.welcome`, `Browser Pane (P14)`, `.install`, `SGRMouseEvent`, `.run`, `reorderSession`, `DisplayPanesOverlay`, `.menu`, `FormatColor`, `click_ui_element`, `JSONDecoder`, `Fixes Applied (layered)`, `.load`, `AgentApprovalBar`, `NotificationBus`, `settings.json`, `jobs`, `PaneNode`, `HarnessPaths.swift`, `.parse`, `ThemeDiagnostics`, `.encodeMouse`, `ViPathTokenTests`, `Send Ex Command`, `AgentSnapshot`, `Terminal AI Chat (⌘I inline overlay)`, `.unmarkText`, `code:bash (# In a Harness pane:)`, `FormatColor`, `DesktopNotifier`, `FloatingPaneController`, `.theme`, `.reopenClosedTab`, `ImageProtocolTests.swift`, `CSIParams`, `Foundation`, `Architecture Decisions — harness-terminal`, `Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)`, `MCPServer`, `.deepMerge`, `.handleCat`, `[3.5.1] - 2026-06-20`, `SessionEditor.swift`, `FormatStyledSegment.swift`, `[2.2.4] - 2026-06-11`, `Fixes Applied (v3.9.1+)`, `Tab`, `Git Panel`, `.run`, `Identifiable`, `MCPServer`, `ThaiClusterRenderTests`, `terminal_stress_runner.py`, `Darwin`, `UI Automation — Robot Framework (P18)`, `AppKit + Metal Patterns`, `.load`, `Split Panes (NSSplitView)`, `Session/Tab/Pane Hierarchy & Top Bar (CASE-028)`, `Task 1: Redesign Session Sidebar`, `javascript.json`, `json.json`, `rust.json`, `.build`, `HintModeOverlay`, `Bug — Cmd+\ sidebar toggle gone after collapse`, `.delay`, `Competitive Position (as of v3.12.0, 2026-07-02)`, `PathToken`, `LaunchdServiceInstaller`, `.init`, `SetupStepView`, `GroupedSessionDaemonTests`, `RawRepresentable`, `BlockContextMenuTests`, `main.swift`, `.json`, `.run`, `.encode`, `ReflowFastPathTests`, `PresentAttempt`, `HarnessOnboarding`, `.hitTest`, `Added`, `Service Decomposition — SessionCoordinator (P17)`, `.json`, `ACP Client (Shelved)`, `KittyGraphicsCommand`, `.panePathLookup`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Are the 48 inferred relationships involving `Int` (e.g. with `.register()` and `.startStallMonitor()`) actually correct?**
  _`Int` has 48 INFERRED edges - model-reasoned connections that need verification._
- **What connects `AppIntents`, `noActivePane`, `horizontal` to the rest of the system?**
  _3076 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CodingKey` be split into smaller, more focused modules?**
  _Cohesion score 0.13105413105413105 - nodes in this community are weakly interconnected._
- **Should `EngineConformanceTests` be split into smaller, more focused modules?**
  _Cohesion score 0.09545454545454546 - nodes in this community are weakly interconnected._