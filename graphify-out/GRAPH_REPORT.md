# Graph Report - kouen-terminal  (2026-08-06)

## Corpus Check
- 847 files · ~873,262 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 15986 nodes · 35721 edges · 3451 communities (1020 shown, 2431 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 3954 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3b7b78ec`
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
1. `IPCRequest` - bridges 166 areas (186 edges)
2. `Command` - bridges 101 areas (107 edges)
3. `IPCResponse` - bridges 69 areas (91 edges)
4. `SessionCoordinator` - bridges 59 areas (131 edges)
5. `MenuTarget` - bridges 58 areas (68 edges)
6. `SurfaceRegistry` - bridges 57 areas (195 edges)
7. `KouenPaths` - bridges 56 areas (119 edges)
8. `AgentKind` - bridges 54 areas (108 edges)
9. `EngineConformanceTests` - bridges 50 areas (76 edges)
10. `SpecialKey` - bridges 50 areas (56 edges)

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

## Communities (3451 total, 2431 thin omitted)

### Community 0 - "CodingKey"
Cohesion: 0.11
Nodes (6): .surfaceID(forPaneID:), SessionEditorPhase4Tests, PaneID, TabID, WorkspaceID, SessionEditorTests

### Community 1 - "callingPaneTarget"
Cohesion: 0.24
Nodes (4): TerminalDamage, MetalRendererTests, MTLTexture, RenderColor

### Community 2 - ".handleNormal"
Cohesion: 0.20
Nodes (7): Recipe, RecipesStore, Bool, String, URL, UUID, RecipesStoreTests

### Community 4 - "EngineConformanceTests"
Cohesion: 0.12
Nodes (10): DaemonRoundTripTests, Data, Int32, String, TimeInterval, RealPtyLifecycleTests, AtomicCounter, OutputAccumulator (+2 more)

### Community 5 - "IPCRequest"
Cohesion: 0.09
Nodes (21): DecodedReplyFrame, output, reply, DecodedRequestFrame, input, request, FrameError, tooLarge (+13 more)

### Community 6 - "AgentNotchRootView"
Cohesion: 0.08
Nodes (26): AnyTransition, AnyView, AgentNotchPeekEvent, AgentNotchRootView, Container, .init(coder:), .init(frame:), HorizontalInsetRect (+18 more)

### Community 7 - "Command"
Cohesion: 0.09
Nodes (28): AppEnum, AppIntent, AppIntents, GetTerminalOutputIntent, KouenIntentError, noActivePane, workspaceNotFound, KouenShortcutsProvider (+20 more)

### Community 8 - "LSPMessage"
Cohesion: 0.11
Nodes (16): SessionEditor, .addSurface(tabID:paneID:), .addSurface(to:paneID:surfaceID:cwd:), .tab(containingPaneID:), .tab(forSurfaceKey:), .tabIndex(surfaceID:), .tabIndex(surfaceKey:), .tabIndex(workspaceID:tabID:) (+8 more)

### Community 9 - "TerminalEmulator"
Cohesion: 0.14
Nodes (8): colors, PerformanceBenchmarks, Bool, Double, String, TerminalEmulator, TerminalGridSnapshot, UInt8

### Community 10 - "PerformanceBenchmarks"
Cohesion: 0.16
Nodes (9): CommandPromptController, KeyablePanel, Bool, NSControl, NSPanel, NSTextView, Selector, String (+1 more)

### Community 11 - "GitPanelView.swift"
Cohesion: 0.11
Nodes (9): SessionCoordinator, Bool, Double, PaneID, PaneNode, SplitDirection, SurfaceID, TabID (+1 more)

### Community 13 - "KittyKeyboardTests"
Cohesion: 0.08
Nodes (18): KeyRecorderView, .init(coder:), .init(initial:), Any, Bool, NSCoder, NSEvent, NSPoint (+10 more)

### Community 14 - "VTParser"
Cohesion: 0.07
Nodes (25): State, csiEntry, csiIgnore, csiIntermediate, csiParam, escape, escapeIntermediate, ground (+17 more)

### Community 15 - "HarnessTerminalSurfaceView"
Cohesion: 0.14
Nodes (10): Run, Data, ReleaseNotes, String, TerminalBanner, WelcomeConfig, Data, ReleaseNotes (+2 more)

### Community 16 - ".applyPreedit"
Cohesion: 0.08
Nodes (15): AnyCancellable, SnapshotCoalescer, MainActor, Void, NotchMaskAnimator, Bool, CGFloat, CGRect (+7 more)

### Community 17 - "MetalRendererTests"
Cohesion: 0.18
Nodes (8): ScrollbackFile, Bool, Data, DispatchWorkItem, URL, ScrollbackFileTests, String, URL

### Community 18 - "HarnessUILibrary"
Cohesion: 0.10
Nodes (29): DaemonSubscription, .start(onData:onEnd:buffered:), .start(onResponse:onEnd:), Bool, Data, Int32, String, TimeInterval (+21 more)

### Community 19 - "SpecialKey"
Cohesion: 0.14
Nodes (13): object, LSPDiagnostic, LSPDiagnosticSeverity, error, hint, information, warning, LSPHover (+5 more)

### Community 21 - "HarnessTerminalSurfaceView"
Cohesion: 0.08
Nodes (18): KouenTerminalSurfaceView, Any, Bool, CGFloat, NSDraggingInfo, NSDragOperation, NSEvent, NSMenu (+10 more)

### Community 22 - "CopyModeAction"
Cohesion: 0.06
Nodes (43): AgentBridge, AgentTarget, Bool, String, SurfaceID, Bool, CGFloat, Character (+35 more)

### Community 23 - "SplitPaneCoordinator"
Cohesion: 0.12
Nodes (16): OptionStore, OptionStore.Value, Scope, pane, session, workspace, ScopedKey, Bool (+8 more)

### Community 24 - ".request"
Cohesion: 0.19
Nodes (4): KouenCLI, Bool, String, UUID

### Community 25 - "WorktreeManager"
Cohesion: 0.11
Nodes (5): UnsafeMutableRawPointer, KouenSidebarPanelViewController, String, SessionSnapshot, SidebarTitlebarHeaderView

### Community 26 - "Harness tmux-style capabilities"
Cohesion: 0.06
Nodes (37): 10. Status line, mouse, and options, 11. Shell integration, 12. Agent notifications, 13. Out-of-box troubleshooting, 14. One-page cheat sheet, 1. Five-minute setup, 2. Mental model, 3. Prefix key (+29 more)

### Community 27 - "RGBColor"
Cohesion: 0.15
Nodes (5): RenderScheduler, Bool, Void, RenderSchedulerTests, Bool

### Community 28 - ".parse"
Cohesion: 0.14
Nodes (8): ParsedShortcut, PrefixKeymap, Any, Bool, NSEvent, String, TimeInterval, PrefixKeymapFallbackTests

### Community 30 - "Notification"
Cohesion: 0.12
Nodes (9): Bool, Data, String, UInt8, UnsafeBufferPointer, TerminalEmulator, .captureLines(fromLine:toLine:), .captureLines(joinWrapped:) (+1 more)

### Community 31 - "Sendable"
Cohesion: 0.15
Nodes (11): HitTestPassthroughView, PaneContainerView, .init(node:cwd:themeName:existingHosts:existingBrowserPanes:), .init(paneID:), NSPoint, NSView, PaneID, PaneNode (+3 more)

### Community 32 - ".addTab"
Cohesion: 0.13
Nodes (11): KouenTerminalSurfaceView, RawSelection, Bool, CGFloat, CGRect, NSEvent, NSPoint, Range (+3 more)

### Community 33 - "Equatable"
Cohesion: 0.14
Nodes (11): DisplayMessage, MainExecutor, RunShell, Bool, Command, MainActor, PaneID, PaneNode (+3 more)

### Community 34 - "DaemonClient"
Cohesion: 0.17
Nodes (9): LSPServerConfiguration, LSPServerRegistry, LSPSettings, Bool, String, URL, LSPServerRegistryTests, String (+1 more)

### Community 35 - "MenuTarget"
Cohesion: 0.16
Nodes (4): TerminalEmulator, TerminalGridCell, TerminalGridSnapshot, ThaiCombiningMarkTests

### Community 37 - "String"
Cohesion: 0.08
Nodes (23): DragDiagnostics, DispatchSourceTimer, String, PaneDragController, Any, Bool, NSEvent, NSView (+15 more)

### Community 39 - "TerminalColorGamut"
Cohesion: 0.21
Nodes (8): ConnectionState, ErrorAck, MobileBridgeServer, Data, NWConnection, T, UInt8, UUID

### Community 40 - "HarnessSettings"
Cohesion: 0.33
Nodes (3): Any, WKScriptMessage, WKUserContentController

### Community 41 - "CodingKeys"
Cohesion: 0.12
Nodes (17): ClientRecord, CountBox, DaemonServer, PendingBrowserRequest, PendingWrite, Bool, CheckedContinuation, Data (+9 more)

### Community 42 - "HarnessSidebarPanelViewController.swift"
Cohesion: 0.33
Nodes (6): invalidArgument, missingArgument, CommandParser, Command, Set, String

### Community 43 - "RenderSchedulerTests"
Cohesion: 0.09
Nodes (18): .agentInfo(forWorktreePath:), .agentInfo(forWorktreePath:tabs:), Tab, Reason, errored, finished, needsInput, RowState (+10 more)

### Community 44 - "HarnessOverlayBackground"
Cohesion: 0.04
Nodes (45): Already portable or mostly portable, Build matrix, Competitive Landscape (research 2026-07-04), Current Architecture Fit, D1: Transport model (P0 gate), D2: Renderer reuse boundary (P0 gate), D3: Local terminal support (explicitly deferred), Design: mobile session switcher (2026-07-04/05, recovered 2026-07-06) (+37 more)

### Community 45 - "HarnessTerminalSurfaceView.swift"
Cohesion: 0.17
Nodes (6): SSHTunnelManager, Bool, SSHTunnelManagerTests, RemoteHost, String, URL

### Community 46 - ".buildCommand"
Cohesion: 0.10
Nodes (18): EndpointConnector, Int32, String, decodeBoundedCString(), ignoreSIGPIPE(), makeUnixStreamSocket(), setNoSigPipe(), CChar (+10 more)

### Community 47 - ".normalizedKey"
Cohesion: 0.11
Nodes (13): Array, GroupHeaderRow, PickerItemRow, RecipePanel, RecipePickerController, RecipePickerFooter, RecipePickerView, RecipeWindowDelegate (+5 more)

### Community 48 - "HookEvent"
Cohesion: 0.12
Nodes (14): Executor, Hook, HookEvent, HookRegistry, Bool, Command, URL, UUID (+6 more)

### Community 49 - "DaemonServer"
Cohesion: 0.12
Nodes (6): CommandIPCTranslatorTests, Bool, CommandTarget, PaneID, TabID, Phase67Tests

### Community 51 - ".keyEvent"
Cohesion: 0.13
Nodes (22): ColorKind, bg, fg, underline, CompositorPane, GridCompositor, .render(panes:status:statusSegments:), .render(panes:statusLines:) (+14 more)

### Community 54 - "HarnessSplitView"
Cohesion: 0.19
Nodes (8): ActivityAssertionManager, Bool, NSObjectProtocol, SessionSnapshot, Set, String, SurfaceID, ActivityAssertionManagerTests

### Community 55 - "TabCell"
Cohesion: 0.18
Nodes (6): AnyCodable, JSONRPCError, Bool, Int32, String, ToolRegistry

### Community 56 - "NSPanel"
Cohesion: 0.16
Nodes (10): QuickTerminalController, QuickTerminalPanelDelegate, Any, Bool, NSEvent, NSPanel, NSRect, NSScreen (+2 more)

### Community 57 - "BellScanState"
Cohesion: 0.09
Nodes (19): DaemonLifecycle, PriorInstanceDecision, proceed, refuse, stale, Bool, pid_t, String (+11 more)

### Community 58 - "PasteBufferStore"
Cohesion: 0.12
Nodes (33): MTLClearColor, MTLCommandBuffer, MTLRenderCommandEncoder, TerminalFrame, BgInstance, CursorCacheKey, DecoInstance, EncodedFrameInstances (+25 more)

### Community 59 - "3.2 สิ่งที่ implement แล้ว"
Cohesion: 0.06
Nodes (32): 1. ภาพรวมสถาปัตยกรรม (Architecture Overview), ✅ 2.1 `sidebarRows` คำนวณซ้ำ O(N²) ทุกครั้งที่ reload ตาราง — DONE, ⚠️ 2.2 Blocking IPC บน Main Thread — PENDING (P2), ✅ 2.3 การ scan แบบ triple-nested ต่อ sync — DONE, ✅ 2.4 `applyThemeToAllHosts()` ทำงานทุก non-metadata sync — DONE, ✅ 2.5 Split view double-layout เมื่อ switch tab — DONE, ✅ 2.6 Metadata refresh probe ทุก tab ทุก 2 วินาที — DONE, 2. ปัญหาและแนวทางแก้ไข (Issues & Fixes) (+24 more)

### Community 60 - "ViEngine"
Cohesion: 0.11
Nodes (11): Int, SemanticMark, HistoryLine, ImagePlacement, RewrapResult, Bool, ClosedRange, Range (+3 more)

### Community 61 - "FrecencyDirectoryStore"
Cohesion: 0.13
Nodes (21): ColorKind, bg, fg, underline, ComposedCell, .init(_:), .init(codepoint:fg:bg:underlineColor:bold:dim:italic:underline:blink:inverse:invisible:strikethrough:overline:), CompositorPane (+13 more)

### Community 62 - "ComposedCell"
Cohesion: 0.14
Nodes (13): IndexingIterator, LayoutTemplate, surfaceID, .split(node:targetPaneID:direction:paneCount:before:), .split(node:targetPaneID:with:direction:beforeTarget:), .surfaceID(forPaneID:in:), Command, Double (+5 more)

### Community 63 - "HarnessCLI+Server.swift"
Cohesion: 0.15
Nodes (10): Buffer, Configuration, PasteBufferStore, Bool, Data, Date, String, URL (+2 more)

### Community 64 - ".text"
Cohesion: 0.24
Nodes (8): DaemonClient, KouenCLI, String, KouenCLI, SessionGroup, SessionSnapshot, String, UUID

### Community 65 - "PrefixKeymap"
Cohesion: 0.10
Nodes (11): KouenTerminalSurfaceView, Bool, CAMetalDrawable, NSEvent, RGBColor, String, KouenTerminalSurfaceView, CGFloat (+3 more)

### Community 66 - "ShellIntegration"
Cohesion: 0.13
Nodes (7): KouenThemeCatalog, String, KouenThemeDefinition, Bool, RGBColor, String, KouenThemeCatalogTests

### Community 67 - "String"
Cohesion: 0.20
Nodes (7): AgentHookInstaller, InstallResult, Any, Bool, Data, String, URL

### Community 70 - "worktree_isolation_cli.robot"
Cohesion: 0.23
Nodes (7): Group, PrefixCheatsheetWindow, PrefixIndicatorWindow, CGFloat, NSTextField, NSView, NSWindow

### Community 71 - "ImportedTerminalConfig"
Cohesion: 0.10
Nodes (13): KouenUILibrary, Type a string of text into the focused element via osascript keystroke., Get cols x rows from active terminal via stty., Send raw keys to active terminal surface., Send :ex command via CLI., Hover over tab pill at given index (AppleScript)., Click the Sync/Fetch button in Git panel., Launch Kouen app. env: 'preview' (debug) or 'staging' (release+isolated). (+5 more)

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
Cohesion: 0.17
Nodes (4): SessionSnapshot, String, UUID, TargetSpecTests

### Community 79 - "HarnessDesign"
Cohesion: 0.14
Nodes (18): AgentIconArt, AgentVectorIcon, Bool, CGSize, String, AgentIconRenderer, Scanner, SVGPathParser (+10 more)

### Community 80 - "Agent handbook — Harness (extended reference)"
Cohesion: 0.09
Nodes (21): Build / Test / Run, Graphify, graphify, kouen-terminal — Claude Instructions, Non-obvious Constraints, Session Start, Skills, Agent handbook — Kouen (extended reference) (+13 more)

### Community 81 - "DaemonSubscription"
Cohesion: 0.14
Nodes (13): InstallResult, Profile, Shell, bash, fish, zsh, ShellProfileInstaller, Bool (+5 more)

### Community 82 - ".firstMatch"
Cohesion: 0.16
Nodes (3): LiveResizeTests, KouenTerminalSurfaceView, NSWindow

### Community 83 - "LSPClient"
Cohesion: 0.13
Nodes (16): LSPClient, LSPClientError, missingPipe, processNotRunning, serverNotExecutable, Int32, String, Task (+8 more)

### Community 84 - "LSPDiagnostic"
Cohesion: 0.06
Nodes (32): SplitPaneCoordinator, .surfaceID(forPane:in:), .surfaceID(forPaneID:in:), Bool, PaneID, PaneNode, SessionCoordinator, SessionID (+24 more)

### Community 85 - "TerminalGridCell"
Cohesion: 0.07
Nodes (25): requestFailed, FileHandle, CodingKeys, error, id, jsonrpc, method, params (+17 more)

### Community 86 - "HarnessPaths"
Cohesion: 0.11
Nodes (11): String, WorkbenchMRU, FileEditorView, .init(frame:), Bool, NSRect, String, URL (+3 more)

### Community 87 - "SessionCoordinator"
Cohesion: 0.14
Nodes (16): FindWindowMatcher, SearchScope, all, none, only, Bool, SessionGroup, SessionID (+8 more)

### Community 88 - "Harness as a terminal multiplexer"
Cohesion: 0.11
Nodes (19): 10. Attach over ssh — the compositor, 11. Window search and filtering, 12. Shell integration (prompt marks + the success/failure gutter), 13. Agent hooks (notifications), 14. macOS shortcuts (no prefix), 15. One-screen cheat sheet, 1. The mental model, 2. The prefix key (+11 more)

### Community 89 - ".cursorPos"
Cohesion: 0.14
Nodes (4): hooks, AgentHookInstallerTests, String, URL

### Community 90 - "Zombie View Crashes on macOS 26.5 + Swift 6.3.2"
Cohesion: 0.17
Nodes (9): pipe, termios, AttachClient, LiveSession, Bool, Data, DispatchSourceSignal, Int32 (+1 more)

### Community 91 - "TerminalModes"
Cohesion: 0.13
Nodes (4): ContentAreaViewController, Bool, TabID, Notification

### Community 92 - "P2 — Async IPC Refactor: Design Document"
Cohesion: 0.08
Nodes (25): code:swift (// DaemonSessionService.swift), code:swift (// ต้องคงเป็น sync เพราะเรียกก่อน process exit), code:swift (// ปัจจุบัน: DispatchQueue.global + DispatchQueue.main.async), code:text (1. DaemonClientActor (new file, ไม่ break อะไร)), code:text (Before:), code:swift (// DaemonClientActor.swift (new)), code:swift (func fetchSnapshot() async throws -> SessionSnapshot {), code:swift (// Packages/HarnessCore/Sources/HarnessCore/IPC/DaemonClient) (+17 more)

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
Cohesion: 0.13
Nodes (15): PendingVersionBanner, welcome, whatsNew, State, Bool, String, URL, VersionBannerStore (+7 more)

### Community 98 - "4. Technical Architecture"
Cohesion: 0.67
Nodes (3): 4.1 Architecture Pattern, 4. Technical Architecture, 4.2 Technology Stack

### Community 99 - ".dispatch"
Cohesion: 0.18
Nodes (18): TerminalColorGamut, auto, displayP3, sRGB, TerminalColorRenderingMode, accurate, vivid, RenderColor (+10 more)

### Community 100 - "ScriptRuntime.swift"
Cohesion: 0.30
Nodes (12): Decodable, AISuggestRequest, AttachFileRequest, BrowserInteractRequest, BrowserNavigateRequest, ControlMessage, DeviceAuth, DeviceAuthEnvelope (+4 more)

### Community 101 - "Session Grouping and Split Session Plan"
Cohesion: 0.10
Nodes (20): 1. Add Project Group Heuristics, 1. Keep Split State In Session/Tab Structure, 2. Introduce Sidebar Row Model, 2. UX Entry Points, 3. Build Grouped Rows From Filtered Sessions, 4. Update Table Data Source and Delegate, 5. Drag and Drop Rules, code:text (Window) (+12 more)

### Community 102 - "DaemonLauncher"
Cohesion: 0.10
Nodes (21): CopyModeMatch, CopyModeSearch, CopyModeSelectionMode, block, char, line, none, CopyModeSideEffect (+13 more)

### Community 104 - "Recipe"
Cohesion: 0.10
Nodes (25): Bool, UInt8, TerminalCellWidth, normal, spacerTail, wide, TerminalCursor, TerminalCursorShape (+17 more)

### Community 105 - "Changelog"
Cohesion: 0.17
Nodes (8): AgentListFormatter, Date, String, cols, AgentListFormatterTests, Bool, Date, String

### Community 107 - "AgentNotchViewModel"
Cohesion: 0.22
Nodes (4): PaneRectSolverTests, Bool, PaneNode, PaneRect

### Community 108 - ".resolve"
Cohesion: 0.16
Nodes (11): KouenCLITests, URL, KouenCLI, KouenFilePreviewLoader, KouenViewError, binaryOrUnsupportedEncoding, missingPath, tooLarge (+3 more)

### Community 109 - "DamageTrackingTests"
Cohesion: 0.12
Nodes (9): SGRMouse, SGRMouseEvent, Bool, PaneRect, S, UInt8, SGRMouseTests, String (+1 more)

### Community 110 - "SoftIconButton"
Cohesion: 0.19
Nodes (5): CopyModeReducerTests, FakeGrid, Set, String, TerminalGridCell

### Community 112 - ".makeSnapshot"
Cohesion: 0.16
Nodes (15): SidebarBadgeLabel, SidebarDividerRow, SidebarGroupHeaderRow, SidebarSessionItemRow, SidebarSessionListView, SidebarWorktreeHeaderRow, SidebarWorktreeItemRow, BoardColumnKind (+7 more)

### Community 113 - "HarnessGridTerminal"
Cohesion: 0.15
Nodes (19): KouenSettings, .init(fontSize:fontFamily:defaultShell:defaultCWD:transparentTitlebar:sidebarVisible:sidebarOnRight:sidebarCollapsedOnLaunch:sidebarWidth:restoreWindowSize:backgroundOpacity:backgroundBlur:windowPaddingX:windowPaddingY:customBackgroundHex:customForegroundHex:customCursorHex:importedConfigSignature:prefixKey:scrollbackLines:cursorStyle:cursorBlink:copyOnSelect:selectionBackgroundHex:selectionForegroundHex:boldColorHex:cursorTextHex:paletteHex:agentColorOverrides:defaultAgentKind:dividerHex:statusLineHex:windowBorderHex:windowBorderOpacity:systemNotificationsEnabled:notificationSoundEnabled:notchVisibilityMode:notchOpenOnHover:colorRendering:colorGamut:textRendering:vividColors:linearBlending:applyThemeToTerminalOutput:ligatures:offMainParserFramePipeline:liveResizeReflow:mobileBridgeEnabled:showPromptGutter:showStatusLine:experienceMode:kouenControlsEnabled:prefixKeyEnabled:statusLineEnabled:resizeOverlay:resizeOverlayPosition:windowPaddingBalance:minimumContrast:lightThemeName:darkThemeName:lightThemeOpacity:darkThemeOpacity:pasteProtection:commandFinishedThresholdSeconds:notificationEvents:boldIsBright:lspAutoStart:lspServers:fileClickAction:claudeAPIKey:inlineAICompletion:terminalShaderEffect:browserHomePage:), .init(from:), ResizeOverlayMode, afterFirst, always, never, ResizeOverlayPosition (+11 more)

### Community 114 - ".firstWaitingTab"
Cohesion: 0.15
Nodes (7): ImportedTerminalConfig, Bool, Double, Float, String, TerminalConfigImporter, TerminalConfigImporterTests

### Community 115 - ".encode"
Cohesion: 0.13
Nodes (11): ActivePaneService, .surfaceID(forPane:in:), .surfaceID(forPaneID:in:), Bool, PaneID, PaneNode, SessionCoordinator, Set (+3 more)

### Community 116 - "SessionGroup"
Cohesion: 0.20
Nodes (7): AgentRoutingRuleStore, Bool, String, URL, UUID, AgentRoutingRuleStoreTests, URL

### Community 117 - "PaneNode"
Cohesion: 0.10
Nodes (12): NotificationCoordinator, Bool, Date, SessionCoordinator, SessionSnapshot, Set, String, SurfaceID (+4 more)

### Community 118 - "WorkspaceFileTreeView"
Cohesion: 0.10
Nodes (13): ActiveTabCloseDisposition, session, tab, window, workspace, CloseConfirmationCopy, SessionLifecycleService, NSWindow (+5 more)

### Community 119 - "Harness command reference"
Cohesion: 0.12
Nodes (16): Attaching from a plain terminal, Bindings, Buffers (paste store), Composition, Hooks, Inspection (CLI / control mode), Kouen command reference, Local diagnostics (+8 more)

### Community 122 - "ViEngine"
Cohesion: 0.17
Nodes (5): SessionPersistenceTests, Bool, String, TabID, URL

### Community 123 - "Pipe"
Cohesion: 0.11
Nodes (14): ExternalOpenKind, filePreview, terminal, theme, InstallChoice, cancel, install, installAndApply (+6 more)

### Community 124 - "String"
Cohesion: 0.17
Nodes (6): KouenSidebarPanelViewController, CGFloat, NSMenuItem, NSView, SessionGroup, String

### Community 125 - "HistoryRingBuffer"
Cohesion: 0.12
Nodes (9): ContiguousArray, IteratorProtocol, HistoryRingBuffer, Iterator, Bool, Element, S, Sequence (+1 more)

### Community 126 - ".path"
Cohesion: 0.08
Nodes (25): AgentArt, AgentMark, AgentMarkShape, AgentVectorIcon, Scanner, SVGPath, Bool, CGFloat (+17 more)

### Community 127 - "GlyphAtlas"
Cohesion: 0.10
Nodes (23): Hashable, AtlasEntry, ClusterGlyphKey, GlyphAtlas, .entry(for:), .entry(forCluster:bold:italic:), .entry(forShaped:font:), GlyphAtlasStats (+15 more)

### Community 129 - "SwiftUI"
Cohesion: 0.14
Nodes (11): FilePreviewCoordinator, FileTabID, NSView, Set, SplitDirection, String, FileTab, FileTabManager (+3 more)

### Community 130 - "Harness"
Cohesion: 0.11
Nodes (18): code:bash (harness-cli doctor), AI Browser Control (kouen-mcp), Build From Source, CLI, Development Builds, Documentation, Editor & LSP, How It Feels (+10 more)

### Community 131 - ".install"
Cohesion: 0.16
Nodes (10): PickerItem, historyBlock, recipe, RecipePickerModel, NSWindow, SurfaceID, RecipePickerModelMergeTests, Bool (+2 more)

### Community 132 - "AgentHookInstaller"
Cohesion: 0.12
Nodes (17): CommandIPCTranslator, CommandTarget, CommandTranslation, clientLocal, requests, unresolved, Command, PaneID (+9 more)

### Community 133 - ".load"
Cohesion: 0.31
Nodes (4): SessionSnapshot, BoardModelTests, SessionSnapshot, Tab

### Community 135 - "CommandTarget"
Cohesion: 0.06
Nodes (33): TerminalModes, InputEncoder, .encode(_:modifiers:event:modes:), .encode(text:modifiers:modes:), .encode(text:shifted:modifiers:event:associatedText:modes:), KeyEventType, press, release (+25 more)

### Community 136 - ".startWatching"
Cohesion: 0.18
Nodes (18): Codable, BrowserElement, BrowserElementBounds, BrowserSnapshot, BufferSummary, DirectionalAxis, down, left (+10 more)

### Community 137 - "ActivePaneService"
Cohesion: 0.12
Nodes (13): constantTimeEquals(), PairedDeviceRecord, PairedDeviceStore, SHA256Mini, Bool, Date, String, TimeInterval (+5 more)

### Community 138 - "User Story Mapping (MANDATORY)"
Cohesion: 0.67
Nodes (3): Future User Stories (Post-MVP), MVP User Stories (Must Implement), User Story Mapping (MANDATORY)

### Community 139 - "แผนงานการสร้างระบบพรีวิวและแสดงผลไฟล์ (File Viewer & Preview Integration Plan)"
Cohesion: 0.11
Nodes (18): 1.1 โครงสร้างการทำงานของ Quick Look (Quick Look Architecture), 1.2 สองคลาสหลักในการใช้งาน (QLPreviewPanel vs. QLPreviewView), 1. เบื้องหลังการทำงานของระบบพรีวิวบน macOS (Under the Hood: macOS Quick Look), 2. การกำหนดลำดับขั้นการคัดแยกประเภทไฟล์ (File Routing Model), 3. แผนการแบ่งแทร็กการพัฒนา (Development Tracks), 4.1 ตัวจัดการควบคุมกลยุทธ์การพรีวิว (File Preview Strategy Protocol), 4.2 คอนโทรลเลอร์แสดงผลไฟล์หลัก (FileViewerViewController), 4.3 ตัวพรีวิวเนทีฟด้วย Quick Look (macOSQuickLookStrategy) (+10 more)

### Community 141 - ".testPaneLeafLegacyDecodeBackfillsSurfaceTabs"
Cohesion: 0.16
Nodes (14): Phase, daemonConnected, firstDrawablePresented, firstSnapshot, firstSurfaceAttached, firstWindow, launchStart, StartupMetrics (+6 more)

### Community 142 - "CopyModeGridSource"
Cohesion: 0.26
Nodes (5): KouenBrowserTools, Bool, Double, String, TimeInterval

### Community 143 - "How to use Harness from the terminal only (no GUI)"
Cohesion: 0.10
Nodes (19): 1. Find the CLI, 2. Check daemon health, 3. List what's running (like `tmux ls`), 4. Attach to a pane, 5. Create sessions/tabs from a script, 6. Drive a pane without attaching, 7. tmux control mode, 8. Remote/headless daemon (+11 more)

### Community 144 - "PaneStyleSet"
Cohesion: 0.24
Nodes (7): CheckResult, GitCloneUpdateChecker, RemoteVersion, Bool, String, TimeInterval, URL

### Community 145 - "AsciiFastPathTests"
Cohesion: 0.16
Nodes (3): DamageTrackingTests, IndexSet, TerminalEmulator

### Community 146 - "DecodedImage"
Cohesion: 0.06
Nodes (32): Bool, String, UUID, TaskDaemonBridge, CGFloat, NSCoder, SessionID, String (+24 more)

### Community 147 - "FileTreeWatcher"
Cohesion: 0.11
Nodes (18): Darwin, Glibc, CLIInstallLocator, DetachKeys, absent, invalid, parsed, KouenCLI (+10 more)

### Community 148 - "TriState"
Cohesion: 0.11
Nodes (18): Architecture, Browser Auto-Retry (P24 Phase 4), Browser Pane (P14), BUG: Tab close button never fired (CASE-055 extended), BUG: Tab close button unresponsive (gesture conflict), CASE: applyLocalSnapshot re-injected closed browser panes (v2.7.1), CASE: collapsed errorBanner intercepted toolbar clicks (v2.7.1), CASE: Google/Apple OAuth blocked by default WKWebView user agent (2026-07-10) (+10 more)

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
Cohesion: 0.15
Nodes (9): .init(forTesting:), ScrollbackEntry, ScrollbackReplaySegment, ShellLaunchProfile, Data, UInt64, UUID, Void (+1 more)

### Community 154 - "LiveResizeTests"
Cohesion: 0.14
Nodes (13): KouenGridTerminal, .captureLines(fromLine:toLine:), .captureLines(joinWrapped:), .feed(_:), .readGrid(scrollbackOffset:), Bool, Data, String (+5 more)

### Community 155 - "Int"
Cohesion: 0.14
Nodes (11): FileFuzzyMatcher, FuzzyPathResolution, ambiguous, none, unique, FuzzyPathResolver, Bool, Character (+3 more)

### Community 156 - "ThaiCombiningMarkTests"
Cohesion: 0.10
Nodes (18): NotificationEntry, SessionID, SurfaceID, TabID, WorkspaceID, NotificationDropdownPanelView, .init(coder:), .init(entries:onSelect:onClearAll:onDismiss:) (+10 more)

### Community 158 - "Harness Terminal — IDE Sidebar Feature Branch"
Cohesion: 0.12
Nodes (15): Architecture, Branch, Build & Preview, CMUX Pane Splitting, code:block1 (worktree-feature+acp-aidlc), code:bash (cd /tmp/hp  # symlink to worktree (socket path length limit)), code:block3 (HarnessSidebarPanelViewController — Sessions / Files / Git t), Features (+7 more)

### Community 159 - "MatchCategory"
Cohesion: 0.17
Nodes (6): DefaultTerminalLaunchRequest, ShellQuoting, Bool, String, URL, DefaultTerminalLaunchRequestTests

### Community 160 - "AmbientBackground"
Cohesion: 0.17
Nodes (17): Source, activePane, activeTab, focusedPane, focusedSurface, PaneID, PaneLeaf, PaneNode (+9 more)

### Community 161 - "What You Must Do When Invoked"
Cohesion: 0.08
Nodes (25): 10. Universal retire-hold via `removeFromSuperview()` override (definitive), 11. NSEvent local monitor installed in AppDelegate (fix #8 actually deployed), 12. `nonisolated` + `MainActor.assumeIsolated` on high-frequency AppKit callbacks (2026-06-21), 1. `TerminalPaneRegistry.retire()` — deferred dealloc (500ms), 2. Remove `nonisolated` from all layout overrides, 3. Remove `MainActor.assumeIsolated` from callbacks, 4. Detach NSHostingView on teardown (FileTreeSwiftUIView), 5. Avoid `Optional.map {}` in @MainActor code (+17 more)

### Community 162 - "TerminalFindBar"
Cohesion: 0.09
Nodes (16): NSSearchFieldDelegate, Bool, CGFloat, NSButton, NSCoder, NSControl, NSEvent, NSImage (+8 more)

### Community 163 - "Workspace"
Cohesion: 0.34
Nodes (5): Bool, String, TimeInterval, WorktreeInfo, WorktreeManager

### Community 164 - "CommandPromptController"
Cohesion: 0.14
Nodes (20): ChecksStatus, fail, none, pass, pending, CIRun, GitHubCLIClient, IssueInfo (+12 more)

### Community 165 - "ActiveTabCloseDisposition"
Cohesion: 0.13
Nodes (13): Logger, os, OSSignposter, LatencyMonitor, UInt64, FrameDropCause, encodeFailure, nilDrawable (+5 more)

### Community 166 - "LiveSession"
Cohesion: 0.10
Nodes (22): cardHTML(), closeSheet(), goto(), #list-count, openSession(), renderSessions(), SESSIONS, terminal on mobile research (+14 more)

### Community 167 - "AgentTableEntry"
Cohesion: 0.14
Nodes (12): OverlayBackground, Context, ChromeBackdrop, .init(role:), KouenDesign, KouenOverlayBackground, RuntimeGlassEffectView, Bool (+4 more)

### Community 170 - "URLDetection"
Cohesion: 0.13
Nodes (5): Bool, Range, String, URLDetection, StringProtocol

### Community 171 - "ReflowCorpusTests"
Cohesion: 0.10
Nodes (16): AgentApprovalBar, .init(coder:), .init(host:prompt:kind:), ApprovalBarAction, hide, noop, show, NSColor (+8 more)

### Community 172 - ".decodeKeySpec"
Cohesion: 0.15
Nodes (14): GridCompositor, Configuration, Int32, SessionGroup, SessionID, SessionSnapshot, Tab, TabID (+6 more)

### Community 173 - "BoardCard"
Cohesion: 0.18
Nodes (16): SessionRef, byID, byName, next, previous, String, UUID, TargetSpec (+8 more)

### Community 174 - "BinaryRefresherTests"
Cohesion: 0.11
Nodes (6): ISO8601DateFormatter, KouenDaemonTools, .init(client:subscriptionClient:controlEnabled:), SessionSnapshot, String, UUID

### Community 175 - "RGBColorTests"
Cohesion: 0.17
Nodes (7): RemoteHost, RemoteHost, SettingsRemoteView, Bool, NSImage, RemoteHost, String

### Community 176 - "Added"
Cohesion: 0.09
Nodes (20): CustomStringConvertible, DaemonClientError, connectionFailed, timeout, unexpectedResponse, writeFailed, DaemonSessionError, daemonError (+12 more)

### Community 177 - ".rects"
Cohesion: 0.05
Nodes (35): StatusLineView, .init(coder:), CGFloat, FormatColor, Never, NSAttributedString, NSCoder, NSColor (+27 more)

### Community 178 - "InlineAICompletionView"
Cohesion: 0.23
Nodes (9): CopyModeGridSource, ClosedRange, CopyModeReducer, Bool, Character, NSRegularExpression, Range, String (+1 more)

### Community 179 - "[3.13.1] - 2026-07-02"
Cohesion: 0.14
Nodes (17): PaneBorderStatus, bottom, off, top, PaneLeaf, PaneNode, branch, leaf (+9 more)

### Community 180 - "VTConformanceCorpusTests"
Cohesion: 0.22
Nodes (7): TerminalSelection, CellOverlayTests, IndexSet, KouenTerminalSurfaceView, NSWindow, String, UInt64

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
Cohesion: 0.06
Nodes (36): TerminalGridSnapshot, .readGrid(scrollbackOffset:), ImagePlacementSnapshot, Bool, String, UInt8, TerminalCellWidth, normal (+28 more)

### Community 187 - "AppDelegate"
Cohesion: 0.20
Nodes (10): AppDelegate, .application(_:open:), .application(_:openFiles:), QueuedExternalOpen, Bool, NSKeyValueObservation, String, URL (+2 more)

### Community 188 - "BrowserPaneView"
Cohesion: 0.15
Nodes (13): Motion, CAMediaTimingFunction, KouenOnboarding, Bool, ImmersiveOnboardingWindowController, .init(coder:), .init(onDismiss:), ImmersivePanel (+5 more)

### Community 189 - "P5 — ACP (Agent Client Protocol) — Harness as ACP Editor/Client"
Cohesion: 0.12
Nodes (16): Architecture, Bounded Contexts, code:block1 (Agent Process (Claude Code / Codex / Gemini)), code:block2 (Packages/HarnessCore/Sources/HarnessCore/ACP/), code:block3 (Content-Length: 123\r\n), Estimate, Goal, Key Files (New) (+8 more)

### Community 191 - "ScriptRuntime"
Cohesion: 0.11
Nodes (10): ScriptError, evaluationError, unsupportedPlatform, ScriptRuntime, Any, String, URL, JSContext (+2 more)

### Community 192 - "GlyphRasterizer"
Cohesion: 0.10
Nodes (19): CTFontSymbolicTraits, CellMetrics, GlyphRasterizer, .rasterize(cluster:bold:italic:), .rasterize(codepoint:bold:italic:), .rasterize(glyph:font:), RasterizedGlyph, ShapedGlyph (+11 more)

### Community 193 - "BinaryInstaller"
Cohesion: 0.19
Nodes (11): RecordClient, RecordingWriter, RecordSession, Summary, Bool, Data, DispatchSourceSignal, FileHandle (+3 more)

### Community 194 - "Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag"
Cohesion: 0.08
Nodes (29): FileNode, GitStatusType, added, deleted, modified, renamed, unmodified, untracked (+21 more)

### Community 195 - "ResizeHUDView"
Cohesion: 0.16
Nodes (17): BoardCard, BoardColumn, BoardColumnKind, done, error, idle, needsAttention, running (+9 more)

### Community 196 - "Feature Provenance — harness-terminal"
Cohesion: 0.09
Nodes (20): .init(frame:), .init(coder:), Kind, primary, secondary, .init(coder:), KouenPillButton, .init(coder:) (+12 more)

### Community 197 - "AgentSessionSummary"
Cohesion: 0.14
Nodes (12): FlippedView, .removeWorktreeAction(_:), NSButton, NSColor, NSRect, NSScrollView, NSStackView, NSTextField (+4 more)

### Community 198 - ".classify"
Cohesion: 0.23
Nodes (6): DoctorRunner, Bool, URL, DoctorRunnerTests, String, URL

### Community 200 - "BinaryInstallerVersionTests"
Cohesion: 0.15
Nodes (10): InstallResult, Shell, bash, fish, zsh, ShellIntegration, Bool, URL (+2 more)

### Community 201 - "MCP Server (harness-mcp)"
Cohesion: 0.10
Nodes (31): BlockSelection, CursorRender, CursorStyle, bar, block, underline, FrameBuilder, .build(_:region:searchHighlights:copyModeCursor:imageProvider:reusing:damage:) (+23 more)

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
Nodes (11): NSCoder, NSEvent, NSImage, NSPanel, NSRect, String, Void, TabCell (+3 more)

### Community 207 - "scheduleRender"
Cohesion: 0.05
Nodes (29): AgentDetection, AgentDetector, AgentTable, AgentTableEntry, MatchSource, ownProcess, wrapperLaunch, RawMatch (+21 more)

### Community 208 - ".testDataFrameEncodeVsJSONBase64Output"
Cohesion: 0.13
Nodes (13): CompletionPopupView, .init(coder:), .init(frame:), CompletionRowView, .init(coder:), .init(text:isSelected:), Bool, NSCoder (+5 more)

### Community 209 - "SettingsRemoteView"
Cohesion: 0.13
Nodes (15): BrowserRequestPayload, close, cookies, evaluate, goBack, goForward, interact, navigate (+7 more)

### Community 210 - "PaneDropZoneOverlay"
Cohesion: 0.16
Nodes (7): CLICommand, CLICommandCatalog, Bool, String, CompletionGenerator, String, CompletionGeneratorTests

### Community 211 - "PaneTarget"
Cohesion: 0.30
Nodes (6): Channel, Bool, Int32, String, WaitForRegistry, WaitForRegistryTests

### Community 212 - ".translate"
Cohesion: 0.13
Nodes (9): String, WorkspaceID, CwdMetadataProvider, GitMetadataProvider, MetadataProvider, String, Tab, DaemonSyncServiceBranchNotifyTests (+1 more)

### Community 213 - "String"
Cohesion: 0.08
Nodes (24): 1 — Process lifecycle & supervision, 2 — IPC protocol evolution, 3 — Concurrency architecture, 4 — State persistence, 5 — Render/PTY data path & the "mktemp failed" spam, 6 — Build/release pipeline, A10 (Low) — stale `@unchecked Sendable` inventory, A1 (High) — S1 daemon-reuse is undone at GUI relaunch by the build-handshake staleness check (+16 more)

### Community 214 - "NotchLayoutMetrics"
Cohesion: 0.09
Nodes (22): DaemonSyncService, .logIfFailed(_:), .request(_:), .sync(metadataOnly:), Bool, Never, PaneID, SessionCoordinator (+14 more)

### Community 215 - ".lines"
Cohesion: 0.14
Nodes (9): BranchSwitchHelper, FileTreeSwiftUIView, NodeRow, Notification.Name, Bool, NSMenuItem, SessionID, String (+1 more)

### Community 216 - "CellColorResolverTests"
Cohesion: 0.16
Nodes (9): WindowInputRouterTests, KeySpecDecode, complete, incomplete, invalid, literalPrefix, UInt8, Unicode (+1 more)

### Community 217 - "GridCompositor"
Cohesion: 0.10
Nodes (21): CommandPaletteController, PaletteAction, PaletteCommandConfig, PaletteFileEntry, PaletteFooter, PaletteGrepMatch, PaletteItemRow, PaletteModel (+13 more)

### Community 218 - "ScrollbackFile"
Cohesion: 0.12
Nodes (11): DetachedPaneOverlay, .init(coder:), .init(frame:style:), Style, detached, reconnectingChip, NSCoder, NSEvent (+3 more)

### Community 219 - "Prompt"
Cohesion: 0.15
Nodes (14): code:block1 (Refactor `Tools/harness/Sources/HarnessCLI/HarnessCLI.swift`), code:block2 (Extract pure input-routing logic from `Tools/harness/Sources), code:block3, code:block4, code:block5 (Decompose `Packages/HarnessDaemon/Sources/HarnessDaemon/Surf), code:block6, code:block7, code:block8 (+6 more)

### Community 220 - "Section"
Cohesion: 0.20
Nodes (8): NotchGeometry, NSScreen, NotchLayoutMetrics, NotchRect, NotchScreenMetrics, Bool, Double, NotchLayoutMetricsTests

### Community 221 - "TerminalServicesProvider"
Cohesion: 0.07
Nodes (14): keys, CGImage, DecodedImage, ImageLimits, Bool, UInt8, ImageDecoder, Data (+6 more)

### Community 222 - "AgentNotchRowSummary"
Cohesion: 0.19
Nodes (7): PaneStyle, PaneStyleSet, .init(window:windowActive:pane:paneActive:), Bool, FormatColor, String, PaneStyleTests

### Community 223 - "ANSIPalette"
Cohesion: 0.18
Nodes (7): .removeWorktreeAction(path:), GitResult, Bool, String, ValidateOutcome, WorktreeEntry, CoreServices

### Community 224 - "CellColorResolver"
Cohesion: 0.27
Nodes (10): ANSIPalette, CellColorResolver, .init(palette:defaultForeground:defaultBackground:boldBrightens:faintFraction:minimumContrast:), .init(theme:boldBrightens:minimumContrast:), ResolvedCellColors, Bool, Double, RGBColor (+2 more)

### Community 225 - "HarnessPathDisplay"
Cohesion: 0.18
Nodes (13): JSONRPCMessage, notification, request, response, StdioTransportTests, Data, MCPStdioBuffer, MCPStdioFraming (+5 more)

### Community 226 - "FileChangeWatcher"
Cohesion: 0.27
Nodes (3): NSEvent, NSPopover, .lspPosition(for:)

### Community 227 - "SSHTunnelManagerTests"
Cohesion: 0.15
Nodes (4): AgentHookInstallerCLI, String, KouenCLI, String

### Community 228 - "sessionRow"
Cohesion: 0.12
Nodes (13): KeybindingsService, Bool, Command, String, .init(from:), Decoder, KeybindingsStore, URL (+5 more)

### Community 229 - ".decide"
Cohesion: 0.21
Nodes (6): MutationResult, RemoteHost, RemoteHostStore, Bool, String, T

### Community 230 - "HarnessGridTerminalTests"
Cohesion: 0.27
Nodes (5): ResolvedCanvas, String, ThemeManager, ThemePreset, ThemeManagerTests

### Community 231 - "ExternalOpenKind"
Cohesion: 0.16
Nodes (22): Appearance, .init(backgroundOpacity:backgroundBlur:fontFamily:fontSize:windowPaddingX:windowPaddingY:sourceColorSpace:appearance:supportsWideGamut:contrastGrade:applyToTerminalOutput:), .init(from:), AppearanceKind, dark, light, Colors, ContrastGrade (+14 more)

### Community 232 - "P10 Task: Lazy Scrollback Reflow"
Cohesion: 0.11
Nodes (17): 1. Add a `pendingReflowTask` field to `TerminalScreen`, 2. Split `reflow(toCols:rows:)` into two helpers, 3. In `resize(cols:rows:)`, use the fast path first, Background, code:swift (// In TerminalScreen), code:swift (// Fast path — reflow only viewport + lookahead), code:swift (mutating func resize(cols nc: Int, rows nr: Int) {), code:swift (// TerminalEmulator: add a "live resize in progress" flag) (+9 more)

### Community 233 - "TextGrid"
Cohesion: 0.19
Nodes (3): RegressionBugFixTests, SessionSnapshot, Tab

### Community 234 - ".scan"
Cohesion: 0.25
Nodes (4): Set, SurfaceID, Void, TerminalPaneRegistry

### Community 235 - "WorkbenchCommand"
Cohesion: 0.12
Nodes (13): SettingsHostingController, .init(coder:), .init(page:), SettingsWindowController, NSCoder, NSWindow, Page, advanced (+5 more)

### Community 237 - "TerminalBlockStoreTests"
Cohesion: 0.13
Nodes (10): Bool, CGFloat, NSCoder, NSEvent, NSLayoutConstraint, NSPoint, NSRect, WindowTitleStripView (+2 more)

### Community 238 - ".make"
Cohesion: 0.08
Nodes (24): DefaultTerminalManager, DefaultTerminalOpener, DefaultTerminalRegistrationError, failed, DefaultTerminalStatus, Bool, String, URL (+16 more)

### Community 239 - "TerminalMetalRenderer"
Cohesion: 0.15
Nodes (8): CharacterWidth, Bool, ClosedRange, Unicode, CharacterWidthTable, UInt16, UInt8, CharacterWidthTests

### Community 240 - "PaneBorderStatus"
Cohesion: 0.14
Nodes (18): ChooseScope, buffer, client, session, tree, window, Command, MenuItem (+10 more)

### Community 242 - "AgentBridge"
Cohesion: 0.15
Nodes (5): HookFiringTests, NSObjectProtocol, String, URL, XCTestExpectation

### Community 243 - ".make"
Cohesion: 0.26
Nodes (19): Encodable, AISuggestionAck, AttachedAck, BrowserFramePush, BrowserOkAck, BrowserSnapshotAck, Cred, DetachedAck (+11 more)

### Community 244 - "FileNode"
Cohesion: 0.13
Nodes (9): DaemonClientActor, TimeInterval, DaemonSessionService, .request(_:timeout:), Bool, SessionSnapshot, TimeInterval, Endpoint (+1 more)

### Community 245 - "ThemeDocumentTests"
Cohesion: 0.17
Nodes (9): InputGate, ReconnectLatch, SurfaceIO, Data, Sendable, SurfaceID, UInt16, UInt64 (+1 more)

### Community 246 - "Experience modes"
Cohesion: 0.29
Nodes (7): 1. Plain Terminal, 2. Persistent Terminal, 3. Full Terminal, 4. Agent Workspace, Experience modes, Opting into the prefix + status line without switching modes, Persistence (ephemeral vs. persistent)

### Community 247 - ".renderFixture"
Cohesion: 0.16
Nodes (12): InstallError, daemonNotFound, launchctlFailed, writeFailed, InstallReport, LaunchAgentInstaller, Bool, Int32 (+4 more)

### Community 248 - "DaemonMetrics"
Cohesion: 0.22
Nodes (4): String, URL, UUID, WorktreeIsolationDaemonTests

### Community 249 - "ReflowPreviewTests"
Cohesion: 0.16
Nodes (9): ClientSummary, DaemonStats, Bool, Date, Double, Int32, String, UUID (+1 more)

### Community 250 - "HarnessTerminalSurfaceWorkerTests"
Cohesion: 0.18
Nodes (12): AgentRow, HookState, failed, idle, installed, installing, SettingsAgentsView, Bool (+4 more)

### Community 251 - "SessionCoordinator"
Cohesion: 0.21
Nodes (14): Equatable, ANSIPalette, CellColorResolver, MochaTheme, ResolvedCellColors, RGBColor, .init(hex:), .init(red:green:blue:alpha:) (+6 more)

### Community 252 - "NSViewRepresentable"
Cohesion: 0.18
Nodes (15): BannerShortcut, .init(from:), .init(key:description:showInBanner:), BannerShortcutRegistry, CodingKeys, description, key, showInBanner (+7 more)

### Community 254 - "BoardViewController"
Cohesion: 0.20
Nodes (6): KeyTokenParser, Bool, Data, String, KeyTokenParserTests, Phase6KeysTests

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
Cohesion: 0.14
Nodes (18): CodingKeys, activeSessionID, activeTabID, id, name, sessions, sortOrder, tabs (+10 more)

### Community 259 - "ThemeFileServiceTests"
Cohesion: 0.13
Nodes (13): InlineAICompletionController, KouenSettings, String, KouenOptions, Bool, CGFloat, FormatColor, KouenSettings (+5 more)

### Community 260 - ".welcome"
Cohesion: 0.25
Nodes (6): Bool, AgentKind, KouenCLI, Bool, String, URL

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

### Community 270 - "WindowSession"
Cohesion: 0.14
Nodes (7): DispatchWorkItem, KouenGridTerminal, PaneID, PaneLeaf, PaneNode, PaneRect, WindowSession

### Community 271 - "StatusLineView.swift"
Cohesion: 0.35
Nodes (6): KouenChrome, KouenChromePalette, Bool, CGFloat, NSColor, String

### Community 272 - "SGRMouseEvent"
Cohesion: 0.19
Nodes (4): .init(id:cwd:shell:rows:cols:scrollbackBytes:extraEnvironment:termProgram:termProgramVersion:scrollbackURL:), DaemonSurfaceID, URL, ShellLaunchProfileTests

### Community 273 - "KeySpec"
Cohesion: 0.16
Nodes (10): FileTreeWatcher, FSEventStreamBox, escaping, FSEventStreamRef, MainActor, UnsafeMutableRawPointer, Void, WatcherContext (+2 more)

### Community 274 - "[2.5.0] - 2026-06-12"
Cohesion: 0.09
Nodes (9): SecureInputMonitor, DispatchWorkItem, Set, String, SurfaceID, Float, PromptQueueBar, NSWindow (+1 more)

### Community 275 - "P8: macOS 27 Golden Gate Adoption"
Cohesion: 0.11
Nodes (17): Artifacts, Client Application, Client Application, Client Application, Context, D1 — File preview (read-only), D2 — File/image attach (upload), D3 — Browser mirror (embedded, mirrors Mac's real BrowserPaneView) (+9 more)

### Community 276 - "SyntaxTextView"
Cohesion: 0.15
Nodes (13): ColorHexRow, PaletteCell, SettingsColorsView, Bool, String, WritableKeyPath, SettingsModel, Any (+5 more)

### Community 277 - ".run"
Cohesion: 0.32
Nodes (3): BinaryInstallerVersionTests, String, URL

### Community 278 - "BlockTintOverlay"
Cohesion: 0.13
Nodes (17): BrowserCookie, BrowserNetworkEntry, BrowserResponsePayload, cookies, error, network, ok, open (+9 more)

### Community 279 - "DisplayPanesOverlay"
Cohesion: 0.17
Nodes (6): BoardViewController, FlippedView, Bool, Set, TabID, BoardViewControllerTests

### Community 280 - ".menu"
Cohesion: 0.25
Nodes (4): StatusLineWidthTests, StatusLineWidth, String, StyledSegment

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

### Community 285 - "After all done, come back and update agent-memory/memory.md and agent-memory/plans/p14-web-browser-pane.md."
Cohesion: 0.08
Nodes (24): After all done, come back and update agent-memory/memory.md and agent-memory/plans/p14-web-browser-pane.md., After all done — update memory, Agent Prompt — P14 Browser Pane (PBI-001 through 005), Before writing any code, read:, code:swift (public struct BrowserLeaf: Codable, Sendable, Equatable {), code:swift (case let .browser(bl):), code:swift (// action: SplitPaneCoordinator openBrowserPane(url: URL(str), code:block4 (harnessBrowserOpen(url, direction?) → {paneId}) (+16 more)

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
Cohesion: 0.11
Nodes (13): CodingKeys, error, id, jsonrpc, method, params, JSONRPCId, int (+5 more)

### Community 294 - "GitHubCLIClient"
Cohesion: 0.19
Nodes (8): Range, String, TerminalGridCell, TerminalBufferMatch, TerminalBufferSearch, String, TerminalGridCell, TerminalBufferSearchTests

### Community 295 - "AgentApprovalBar"
Cohesion: 0.20
Nodes (7): FileChangeWatcher, DispatchSourceFileSystemObject, DispatchWorkItem, String, TimeInterval, Void, FileChangeWatcherTests

### Community 296 - "NotificationBus"
Cohesion: 0.26
Nodes (5): KouenCLI, Bool, Int32, Never, String

### Community 297 - "settings.json"
Cohesion: 0.17
Nodes (11): PaneBorderStatus, bottom, off, top, PaneRect, PaneRectSolver, Bool, Double (+3 more)

### Community 298 - "jobs"
Cohesion: 0.18
Nodes (6): ReleaseNotes, ReleaseNotes, Section, String, ReleaseNotesGuardTests, String

### Community 299 - "PaneNode"
Cohesion: 0.23
Nodes (10): PairedDeviceSummary, SessionSnapshot, .init(from:), .init(version:revision:workspaces:activeWorkspaceID:themeName:keepSessionsOnQuit:savedAt:), SurfaceSummary, Bool, Date, Decoder (+2 more)

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
Cohesion: 0.13
Nodes (15): Action, DesktopNotifier, KouenPathDisplay, NotificationPresenter, .userNotificationCenter(_:didReceive:withCompletionHandler:), .userNotificationCenter(_:willPresent:withCompletionHandler:), Bool, MainActor (+7 more)

### Community 305 - ".script"
Cohesion: 0.14
Nodes (4): Error, SessionID, String, WorkspaceID

### Community 306 - "RegressionBugFixTests"
Cohesion: 0.12
Nodes (15): Addendum — MAW-pattern validate gate (2026-07-23), Already matched (verified in code, not gaps), Method, Not gaps — deliberate positioning differences (no action), P39 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed / tmux), Phase A — Remote workflow parity (G2) — DONE 2026-07-11, Phase B — Sidebar dev-server visibility (G1) — DONE 2026-07-11, Phase C — Git workflow depth (G3, G4) — SPLIT 2026-07-11 (Opus planning pass) (+7 more)

### Community 307 - "ViPathTokenTests"
Cohesion: 0.19
Nodes (7): Bool, NSObjectProtocol, Set, String, Tab, TabID, WorktreeAutoIsolateService

### Community 308 - "Send Ex Command"
Cohesion: 0.11
Nodes (15): Error, ExpressibleByStringLiteral, InstallError, unsupported, StringError, .init(_:), .init(stringLiteral:), PtyError (+7 more)

### Community 310 - "FrameSignposter"
Cohesion: 0.11
Nodes (17): Agent Detection, Branch Detection Flow, Branch Label, Chrome Roles, Drag Reorder, File, Files, Git Branch Detection (+9 more)

### Community 311 - "Bug: Tab-Switch Black Screen"
Cohesion: 0.13
Nodes (10): PairingBox, PendingPairing, Bool, Date, TimeInterval, TokenCheck, accepted, expired (+2 more)

### Community 312 - "AgentSnapshot"
Cohesion: 0.14
Nodes (17): Array, Bool, Date, Decoder, PaneID, PaneNode, String, TabID (+9 more)

### Community 313 - "Terminal AI Chat (⌘I inline overlay)"
Cohesion: 0.09
Nodes (23): AgentNotchDashboardProjection, AgentNotchProjection, AgentNotchRowSummary, RowKind, agent, session, Date, PaneID (+15 more)

### Community 317 - "Memory — harness-terminal"
Cohesion: 0.18
Nodes (10): 2026-06-25 — OSC 7735:  opens sidebar file viewer, 2026-06-27 — Block output tint + AI explain (Phase 12b), Pruned from MEMORY.md — 2026-07-02, Pruned from MEMORY.md — 2026-07-03, Pruned from MEMORY.md — 2026-07-04, Pruned from MEMORY.md — 2026-07-06, Pruned from MEMORY.md — 2026-07-07, Pruned from MEMORY.md — 2026-07-08 (+2 more)

### Community 319 - "FormatColor"
Cohesion: 0.11
Nodes (13): LaunchdServiceInstaller, ServiceInstaller, ServiceInstallers, ServiceInstallReport, Bool, String, URL, Bool (+5 more)

### Community 320 - "Focus Persistence — Per-Session-Tab Pane Focus (RL-043)"
Cohesion: 0.23
Nodes (6): RenderedFixture, StaticString, String, TerminalGridSnapshot, UInt, UInt8

### Community 321 - "UInt64"
Cohesion: 0.12
Nodes (10): CoreGraphics, CoreText, ImageIO, ShapedGlyphSignature, Bool, CGFloat, CGGlyph, String (+2 more)

### Community 322 - "DesktopNotifier"
Cohesion: 0.22
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

### Community 326 - "worktree_isolation.robot"
Cohesion: 0.10
Nodes (3): ANSIPaletteTests, CellColorResolverTests, CellColorResolver

### Community 327 - ".theme"
Cohesion: 0.22
Nodes (8): PaneOutputWaiter, PaneOutputWaitResult, Bool, CheckedContinuation, Never, PaneLeaf, Tab, UInt64

### Community 328 - "README.md"
Cohesion: 0.36
Nodes (3): Install, Shell integration (OSC 133 semantic prompts), What gets emitted

### Community 329 - "ImmersivePalette.swift"
Cohesion: 0.21
Nodes (4): PaneBorderStatus, Bool, Command, CommandTarget

### Community 330 - ".drawGlyph"
Cohesion: 0.21
Nodes (12): CellMetrics, ComposedFrame, CellMetrics, ComposedTerminalView, Bool, CellColorResolver, CGFloat, CGPoint (+4 more)

### Community 331 - ".recordReapedGenerationForTesting"
Cohesion: 0.08
Nodes (26): BinaryInstaller, CopyOutcome, copied, keptNewerInstalled, skippedIdentical, DetectionStatus, found, notFound (+18 more)

### Community 333 - "RealPty"
Cohesion: 0.12
Nodes (16): Decisions so far, Destination, M2 — Warp custom model router, M3 — cmux Browser Design Mode, M4 — cmux Fork Conversation, M5 — cmux saved workspace layouts, M6 — iTerm2 AI safety-check, M7 — iTerm2 workgroup review automation (+8 more)

### Community 334 - "ImageProtocolTests.swift"
Cohesion: 0.14
Nodes (11): MTLLibrary, MTLRenderPipelineState, ImageTextureCache, MTLDevice, MTLTexture, UInt8, CGFloat, MTLBuffer (+3 more)

### Community 335 - ".makeModel"
Cohesion: 0.13
Nodes (10): Content, NSView, NSViewCornerConfiguration, String, TimeInterval, Toast, ToastBody, ToastHostingView (+2 more)

### Community 336 - "run.sh"
Cohesion: 0.70
Nodes (4): kill_stale(), kill_stale_prod(), run.sh script, usage()

### Community 337 - "CommandExecutionError"
Cohesion: 0.18
Nodes (15): RepoGitMetadata, SidebarListModel, SidebarSessionRow, divider, groupHeader, session, worktree, worktreeHeader (+7 more)

### Community 338 - "CSIParams"
Cohesion: 0.30
Nodes (5): AgentNotchPeekDecider, String, AgentNotchPeekDeciderTests, Bool, String

### Community 339 - "Foundation"
Cohesion: 0.11
Nodes (23): AppKit, KouenCopyMode, KouenTerminalEngine, KouenTerminalRenderer, KouenTheme, Metal, ImmersiveEffects, CALayer (+15 more)

### Community 342 - "Added"
Cohesion: 0.30
Nodes (7): Bool, NSPasteboard, NSString, String, URL, TerminalServicesProvider, AutoreleasingUnsafeMutablePointer

### Community 343 - "[2.2.3] - 2026-06-09"
Cohesion: 0.16
Nodes (7): .selectWorkspace(_:), .selectWorkspace(byIndex:), String, WorkspaceID, ProjectConfig, Bool, String

### Community 344 - "FileViewerViewController"
Cohesion: 0.19
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
Cohesion: 0.21
Nodes (7): EnvironmentStore, Persisted, String, URL, global, EnvironmentStoreTests, URL

### Community 354 - "P10: Performance and Feature Roadmap (Terminal First, IDE Convenient)"
Cohesion: 0.22
Nodes (8): 1. Performance Optimization: Scrollback Reflow ($O(\text{history})$ Complexity), 2. convenient Features: Local completion & completion Gutter, 3. IDE Convenient: Keyboard-driven Layout Presets, 4. AI integration: Secure Local ACP Sidebar, Additional features shipped alongside:, Context, Implementation Status (2026-06-11), P10: Performance and Feature Roadmap (Terminal First, IDE Convenient)

### Community 355 - ".deepMerge"
Cohesion: 0.20
Nodes (9): Bug #2 — Cmd+\ squeezes the real terminal pane, real sidebar shows black (2026-07-13), Bug #3 — Same squeeze/black symptom, but from a launch-time layout race, not Settings (2026-07-13), Bug — Cmd+\ sidebar toggle gone after collapse, Confirmed facts, Fix, Related, Suspect A — Dead token guard (confirmed code bug), Suspect B — Zero-delta early exit trap (+1 more)

### Community 356 - "SurfaceProgressTracker"
Cohesion: 0.10
Nodes (26): .init(entry:), AgentChipView, .init(coder:), BoardColumnKind, ChromeRole, sidebar, tabBar, Divider (+18 more)

### Community 357 - ".handleCat"
Cohesion: 0.31
Nodes (6): Bool, Counter, Scheduled, SurfaceProgressTrackerTests, DispatchWorkItem, TimeInterval

### Community 358 - "[3.5.1] - 2026-06-20"
Cohesion: 0.26
Nodes (11): FileEditorTabBarBody, FileEditorTabBarModel, FileEditorTabBarView, .init(coder:), .init(frame:), FileTabPillView, Bool, FileTabID (+3 more)

### Community 359 - "OcclusionTests"
Cohesion: 0.13
Nodes (14): Aggregate: `AgentRoutingRule`, Aggregate root: `AgentRoutingRuleStore`, Design — M2: Agent Routing Rule, Domain service: `AgentRoutingResolver`, `kouenSpawnAgent` change (`KouenDaemonTools.swift:319-356`), Logical Design, MCP tools (`kouen-mcp`, naming mirrors Automation's tool family), Next Step (+6 more)

### Community 360 - "State"
Cohesion: 0.19
Nodes (8): NotificationPermission, State, denied, granted, undetermined, MainActor, UNAuthorizationStatus, UserNotifications

### Community 361 - "FormatStyledSegment.swift"
Cohesion: 0.08
Nodes (19): AutomationStore, KouenAutomation, Bool, Date, String, URL, UUID, AutomationScheduler (+11 more)

### Community 362 - "RGBColor"
Cohesion: 0.18
Nodes (7): MainMenuBuilder, MenuTarget, NSMenu, NSMenuItem, Selector, String, MenuTargetForkConversationTests

### Community 363 - "generate-cheatsheet.js"
Cohesion: 0.15
Nodes (8): RealPty, Bool, CChar, Int32, pid_t, String, UInt16, UnsafeMutablePointer

### Community 364 - "[2.2.4] - 2026-06-11"
Cohesion: 0.09
Nodes (19): Kind, input, metadata, output, resize, RecordingEvent, input, metadata (+11 more)

### Community 365 - "Fixes Applied (v3.9.1+)"
Cohesion: 0.10
Nodes (6): SurfaceID, TerminalPaneRegistryAccess, KouenTerminalKit, DaemonReconnectPolicy, TimeInterval, DaemonReconnectPolicyTests

### Community 366 - "Consumers"
Cohesion: 0.16
Nodes (12): agentDetail(), AgentInboxBody, AgentInboxPanelView, .init(agents:onSelect:), .init(coder:), AgentInboxRowView, AgentStatusDot, CGFloat (+4 more)

### Community 367 - "DaemonStats"
Cohesion: 0.24
Nodes (10): BlockTintOverlay, .init(coder:), .init(surfaceView:), Bool, CGFloat, KouenTerminalSurfaceView, NSCoder, NSEvent (+2 more)

### Community 368 - "Tab"
Cohesion: 0.21
Nodes (9): ConfigError, unsupportedAgent, writeFailure, MCPConfigWriter, Any, Range, String, URL (+1 more)

### Community 369 - "Git Panel"
Cohesion: 0.15
Nodes (3): NWEndpoint, NWListener, UInt16

### Community 370 - ".encode"
Cohesion: 0.19
Nodes (4): NotificationCenterProbe, Bool, Void, NotificationCenterProbeTests

### Community 371 - "P13 — Embedded Browser Pane (cmux parity)"
Cohesion: 0.17
Nodes (11): Architecture, code:block1 (PaneNode (existing binary tree)), Current State, Estimate, Goal, P13 — Embedded Browser Pane (cmux parity), PBI-BROWSER-001: BrowserPaneView + PaneNode integration, PBI-BROWSER-002: Persistence (+3 more)

### Community 372 - "DynamicInstanceBuffer"
Cohesion: 0.19
Nodes (6): FloatingPaneController, Any, Bool, NSEvent, NSObjectProtocol, NSPanel

### Community 373 - "Prompt"
Cohesion: 0.21
Nodes (12): code:block1 (Add a visual session state indicator to sidebar session card), code:block2 (Add keyboard-driven layout presets to the Harness terminal a), code:block3 (Add workspace-scoped local completion (autocomplete) to the ), code:block4, Context, P10 Implementation Prompts — For Agent Execution, Prompt, Task #1: CMUX Session State Indicator in Sidebar (+4 more)

### Community 374 - ".run"
Cohesion: 0.12
Nodes (16): Agent Config Wiring, Agents, Architecture, Browser Pane, File I/O, Git, Key Files, MCP Server (harness-mcp) (+8 more)

### Community 375 - ".install"
Cohesion: 0.07
Nodes (12): KouenDaemonCore, Network, DaemonBrowserRoutingTests, IPCCodecInvariantTests, String, URL, EndpointClientTests, String (+4 more)

### Community 376 - "ScrollReuseTests"
Cohesion: 0.13
Nodes (14): 1. @MainActor + Task + Process.waitUntilExit = FREEZE (RL-052), 2. @Observable + mutation in body = infinite re-render loop (RL-053), 3. Re-entrancy guard on rebuildRows, 4. Worktree display rules, Architecture, chromeEpoch — force SwiftUI re-render from static state, Critical Lessons (bugs fixed), File tree: root at git root, expand on CWD change (+6 more)

### Community 377 - "Identifiable"
Cohesion: 0.08
Nodes (12): PluginLoader, String, ScriptAPI, ScriptConfigLocator, Bool, String, ScriptHookCoordinator, Bool (+4 more)

### Community 378 - "SurfaceProgressTrackerTests.swift"
Cohesion: 0.14
Nodes (10): ResizeHUDView, .init(coder:), .init(frame:), DispatchWorkItem, NSCoder, NSColor, NSPoint, NSRect (+2 more)

### Community 379 - "MCPServer"
Cohesion: 0.27
Nodes (6): ScriptFileWatcher, DispatchSourceFileSystemObject, DispatchWorkItem, String, TimeInterval, Void

### Community 380 - "PromptQueue"
Cohesion: 0.12
Nodes (14): Set, DaemonContentionTests, String, URL, SurfaceRegistryTests, .firstSurfaceID(for:in:), .firstSurfaceID(forSession:in:), PaneID (+6 more)

### Community 382 - "ThaiClusterRenderTests"
Cohesion: 0.22
Nodes (6): merged, JSONMerge, Any, Bool, String, JSONMergeTests

### Community 383 - "terminal_stress_runner.py"
Cohesion: 0.40
Nodes (9): attribute_lines(), main(), redraw_frames(), repeated_chunk(), run_case(), sgr_lines(), truecolor_gradient(), unicode_lines() (+1 more)

### Community 384 - "NSTextField Leak in BoardViewController (P20 Performance)"
Cohesion: 0.12
Nodes (15): Identifiable, CompleteStepView, Void, DiscoverStepView, Point, String, OnboardingStep, complete (+7 more)

### Community 386 - "SKILL-LOG.md"
Cohesion: 0.14
Nodes (11): .webView(_:didCommit:), .webView(_:didStartProvisionalNavigation:), WKNavigation, BrowserPaneViewTests, MockWebView, Bool, URL, WKNavigation (+3 more)

### Community 387 - "User Profile"
Cohesion: 0.24
Nodes (8): DisplayPanesChipView, DisplayPanesOverlay, Any, NSEvent, NSView, NSViewCornerConfiguration, SurfaceID, Void

### Community 388 - "Darwin"
Cohesion: 0.12
Nodes (17): Bool, String, WorkbenchCommand, ack, agent, attention, board, cd (+9 more)

### Community 390 - "UI Automation — Robot Framework (P18)"
Cohesion: 0.29
Nodes (4): RepoResolver, Bool, String, RepoResolverTests

### Community 391 - "AppKit + Metal Patterns"
Cohesion: 0.19
Nodes (6): CSIParams, Pen, SavedCursor, TerminalGridColor, TerminalGridUnderline, UInt8

### Community 402 - "View"
Cohesion: 0.10
Nodes (27): Color, Configuration, TabBarIconButtonStyle, TabBarInlineIconButtonStyle, ButtonStyle, CommandRow, GlassCard, GlassPrimaryButtonStyle (+19 more)

### Community 403 - "themes.json"
Cohesion: 0.26
Nodes (4): GroupedSessionTests, SessionGroup, Set, SurfaceID

### Community 404 - "Split Panes (NSSplitView)"
Cohesion: 0.30
Nodes (5): KouenCLI, SessionID, String, T, Void

### Community 405 - "AgentIconRenderer"
Cohesion: 0.20
Nodes (8): SSHTunnelError, exitedEarly, invalidConfiguration, launchFailed, notReady, Int32, String, TimeInterval

### Community 406 - "main.swift"
Cohesion: 0.16
Nodes (13): DiffLineType, added, deleted, modified, Notification.Name, NSCoder, NSRect, NSTextView (+5 more)

### Community 408 - "IPC Architecture"
Cohesion: 0.22
Nodes (7): PasteController, Bool, Data, NSPasteboard, String, TimeInterval, URL

### Community 409 - "Session/Tab/Pane Hierarchy & Top Bar (CASE-028)"
Cohesion: 0.24
Nodes (11): atomicWrite(), backupCorruptFile(), fnv1aHex(), KouenPathsError, socketPathTooLong, Bool, Data, String (+3 more)

### Community 411 - "Task 1: Redesign Session Sidebar"
Cohesion: 0.10
Nodes (19): Agent Prompt — Harness Terminal UI Fixes, code:block1 (▶ harness-terminal), code:block2 (▼ harness-terminal  ● Running), code:swift (urlTextField.setContentHuggingPriority(.defaultLow, for: .ho), code:swift (let bv = BrowserPaneView(url: bl.url, paneID: bl.id)), code:bash (cd /Users/supavit.cho/Git/Personal/harness-terminal), code:bash (git add -A), Commit (+11 more)

### Community 412 - "go.json"
Cohesion: 0.32
Nodes (4): PaneLabelDaemonTests, String, URL, UUID

### Community 415 - "markdown.json"
Cohesion: 0.12
Nodes (15): KeyRecorderRepresentable, String, Void, OverlayBackground, Context, OverlayBackground, Context, NSViewRepresentable (+7 more)

### Community 416 - "python.json"
Cohesion: 0.14
Nodes (11): Agent Memory Index — harness-terminal, Navigation, Edges, Files, Knowledge Index — Harness Terminal, Search Instructions, Source Map, Case Index (+3 more)

### Community 417 - "rust.json"
Cohesion: 0.14
Nodes (13): ACP (Agent Client Protocol) — tried, shelved, erased, Command Palette / Power-User Terminal Features, Embedded Browser, Feature Provenance — harness-terminal, Git Panel, Harness MCP, IDE Track — File Tree / Editor / LSP (the "Zed half" made real), Notifications (+5 more)

### Community 418 - ".build"
Cohesion: 0.18
Nodes (10): AppKit / Views, Architecture / Daemon, Browser / WKWebView, Chrome / Theming / Rendering, Git / Process, Notifications / UserNotifications, RL Lessons — harness-terminal, Swift 6 / Concurrency (+2 more)

### Community 419 - "typescript.json"
Cohesion: 0.13
Nodes (14): Artifacts, Client Application — Shader Presets (F4) — **UI REVERTED 2026-07-11, user call**, Client Application — Task Dashboard (F1), Context, Data Storage — Tasks (F1), Dev Task Progress — P40 MCP Surface Expansion + Shader Presets, Integration, Lessons applied (from `agent-memory/knowledge/rl-lessons.md`, surfaced during this session's P38 review) (+6 more)

### Community 421 - "FilePreviewCoordinatorTabScopeTests"
Cohesion: 0.14
Nodes (12): Logical Design, P41 — Automations, Strategic Design, Tactical Design, Docs, kouen-mcp, KouenCore, KouenDaemon (+4 more)

### Community 422 - "HintModeOverlay"
Cohesion: 0.23
Nodes (6): CaseIterable, Mode, compatible, kouen, TerminalIdentity, TerminalIdentityTests

### Community 423 - "SixelDecoder"
Cohesion: 0.11
Nodes (17): 2026-07-26 monthly refresh (last ~30 days only, 3 parallel research agents), AI-IDE landscape (adjacent category — editors, not terminals), Closed 2026-07-11 (P39 phases A–D — build/test green, live-hardware check still owed on each), Competitive Position (as of v4.9.0, 2026-07-26), Deep web research refresh (2026-07-11, 3 parallel research passes), Feature Matrix (2026-07-11), First-party vendor apps + ACP decision (2026-07-11, follow-up research pass), Known Limitations (honest assessment) (+9 more)

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
Cohesion: 0.20
Nodes (6): CGFloat, NSColor, NSPoint, NSRect, NSWindow, WindowBorderOverlayView

### Community 428 - "P9: Code Complexity Reduction & Structural Refactoring"
Cohesion: 0.18
Nodes (10): 1. HarnessTerminalSurfaceView (~2,320 LOC), 2. HarnessCLI.swift (~1,841 LOC), 3. WindowAttachClient (~1,566 LOC), 4. SurfaceRegistry (~1,848 LOC), 5. GridCompositor Duplication, Context, Execution Order, Execution Status (2026-06-11) (+2 more)

### Community 429 - "Case: cwd "bleed" — session worktree jumps to wrong dir during builds"
Cohesion: 0.14
Nodes (13): 1. Data / Geometry Separation (primary fix), 2. SnapshotCoalescer (cmux NotificationBurstCoalescer pattern), 3. Equality Guard on updateGeometry (Zed pattern), 4. Dirty Flag on setFrame (Otty/WezTerm pattern), 5. GPU Animation — CAShapeLayer Mask (Zed/Otty GPU path), 6. AgentScanner timer split, Files, Fixes Applied (layered) (+5 more)

### Community 431 - "P6: File Editor Opacity Parity with Terminal"
Cohesion: 0.22
Nodes (8): Actual Fix (2026-06-09), code:swift (panel.layer?.backgroundColor = c.terminalBackground), code:swift (private func refreshEditorPanelFill() {), Fix Approach, P6: File Editor Opacity Parity with Terminal, Problem, Root Cause (hypothesis), Status

### Community 432 - "PathToken"
Cohesion: 0.47
Nodes (4): PathToken, PathTokenParser, Bool, String

### Community 433 - "LaunchdServiceInstaller"
Cohesion: 0.30
Nodes (6): AgentCatalog, AgentConfig, DiskAgentConfig, Bool, String, agents

### Community 434 - "Project History"
Cohesion: 0.29
Nodes (3): Bool, String, ThaiClusterRenderTests

### Community 435 - ".highlight"
Cohesion: 0.24
Nodes (8): LSPFileSession, Never, String, Task, URL, Void, URL, SyntaxDefinitionTarget

### Community 436 - "WaitForRegistry"
Cohesion: 0.24
Nodes (3): TabID, WorkspaceID, GitPanelViewWorktreeNavigationTests

### Community 437 - "Feature Specs"
Cohesion: 0.35
Nodes (6): CommandTarget, PaneID, SessionGroup, SessionSnapshot, Tab, first

### Community 438 - "SessionEditor"
Cohesion: 0.27
Nodes (6): HintModeOverlay, Any, KouenTerminalSurfaceView, NSEvent, NSView, String

### Community 439 - "ACP Client"
Cohesion: 0.29
Nodes (7): ACP Client, Architecture, code:block1 (AgentChatPanelView (AppKit UI)), Key Files, Protocol, Shelved Status (June 2025), Tool Call Handling

### Community 440 - "Implementation Phases"
Cohesion: 0.17
Nodes (11): Action items, Fix, How it was found, Post-mortem: Cmd+\ sidebar toggle produces zero visible change (2026-07-29), Related, Root cause, Summary, Symptom (+3 more)

### Community 441 - "RemoteHostStore"
Cohesion: 0.15
Nodes (12): Architecture, Browser DevTools API (P28), Config, Key Bug Fixed: Round-Trip Timeout (RL-048), Key Files, Phase 1 — Core (all via evaluateJS or WKWebView native), Phase 2 — Network, Phase 3 — Storage (+4 more)

### Community 443 - "main.swift"
Cohesion: 0.24
Nodes (7): buffers, DynamicInstanceBuffer, MTLBuffer, MTLDevice, Range, String, T

### Community 444 - "BlockContextMenuTests"
Cohesion: 0.31
Nodes (4): CLIInstaller, Bool, String, URL

### Community 445 - "Section"
Cohesion: 0.18
Nodes (9): clamp(), statusColor(), statusHelp(), Date, String, T, tabDisplayTitle(), TabPillView (+1 more)

### Community 448 - "NSSplitView Patterns"
Cohesion: 0.40
Nodes (5): code:swift (private var isApplyingPositions = false), Infinite Recursion Guard (CASE-006), Key Invariants, NSSplitView Patterns, Safe Subview Reorder (CASE-007)

### Community 449 - ".run"
Cohesion: 0.22
Nodes (9): Style, accent, agent, agentWorking, done, error, idle, running (+1 more)

### Community 450 - "MCPServer"
Cohesion: 0.15
Nodes (12): Bug: Tab-Switch Black Screen, Files changed, Final fast-path guard (PaneLifecycleManager.swift), FM-1: detachHostsOnly() before caching (always broken), FM-2: force=true rebuild caches the stripped container, FM-3: Host theft by another tab's build, FM-4: Cache overwrite leaks orphan containers, Instrumentation method (+4 more)

### Community 451 - ".cgPath"
Cohesion: 0.18
Nodes (10): Action items, Fix, How it was found, Post-mortem: Cmd+\ sidebar toggle unreliable (2026-07-27), Root cause, Summary, Symptom, Validation (+2 more)

### Community 452 - "tmux parity — status, adaptations, and deliberate divergences"
Cohesion: 0.29
Nodes (7): Adapted (same capability, Kouen-shaped), At parity, Deferred (tracked, unimplemented), Implemented (previously deferred, now shipped), Invariants this ledger protects, Rejected (with rationale), tmux parity — status, adaptations, and deliberate divergences

### Community 453 - ".update"
Cohesion: 0.40
Nodes (5): FluidityBenchmarks, KouenTerminalSurfaceView, NSWindow, String, UInt64

### Community 455 - "ComposerPanel"
Cohesion: 0.15
Nodes (10): center, ComposerPanel, Bool, NSEvent, NSTextView, NSWindow, Selector, String (+2 more)

### Community 457 - ".normalizedKey"
Cohesion: 0.31
Nodes (6): AnimatablePair, NotchShape, CGFloat, CGPath, CGRect, Path

### Community 459 - ".encode"
Cohesion: 0.41
Nodes (5): InstallResult, ShellCompletionInstaller, Bool, String, URL

### Community 461 - "PaneLabelDaemonTests"
Cohesion: 0.23
Nodes (3): KouenCore, KouenIPC, XCTest

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

### Community 467 - "─────────────────────────────────────────────────────"
Cohesion: 0.12
Nodes (15): ─────────────────────────────────────────────────────, Agent Prompt — P14 PBI-BROWSER-001 + 002, BrowserPaneView shell + PaneNode integration, code:swift (public struct BrowserLeaf: Codable, Sendable, Equatable {), code:swift (case let .browser(browserLeaf):), code:block3 (feat(p14): PBI-BROWSER-001/002 — BrowserPaneView + PaneNode ), Constraints, ContentAreaViewController.swift — PaneContainerView.build() (+7 more)

### Community 471 - ".evaluateStyled"
Cohesion: 0.14
Nodes (13): 1. Tasks — storage + MCP + IPC contracts, 2. Worktree (MCP resource) — MCP contracts only, 3. Hosts (MCP resource) — one read-only tool, 4. Shader Presets — rendering pipeline change, Host (MCP resource) — no new aggregate, Logical Design, Open items for task-design to resolve (not blocking, just unresolved here), P40 — MCP Surface Expansion (Tasks/Worktrees/Hosts) + Shader Presets (+5 more)

### Community 473 - "HarnessOnboarding"
Cohesion: 0.14
Nodes (9): GridCompositorParityTests, LiveCompositorFixture, Bool, String, TerminalGridSnapshot, PortCompositorFixture, Bool, String (+1 more)

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

### Community 483 - "Changed"
Cohesion: 0.31
Nodes (5): KouenSidebarPanelViewController, NSMenu, NSMenuItem, SessionGroup, SessionID

### Community 490 - "P7: Sidebar UI Polish — Large Screen Layout"
Cohesion: 0.40
Nodes (4): Fix Approach, P7: Sidebar UI Polish — Large Screen Layout, Problems, Status

### Community 491 - "Added"
Cohesion: 0.27
Nodes (8): Date, String, TerminalBlock, TerminalBlockStore, .block(atPromptLine:), .block(id:), .block(atPromptLine:), .block(id:)

### Community 492 - "Service Decomposition — SessionCoordinator (P17)"
Cohesion: 0.33
Nodes (3): KouenTerminalSurfaceWorkerTests, Bool, KouenTerminalSurfaceView

### Community 493 - "Browser Tab Close Button Unresponsive"
Cohesion: 0.20
Nodes (9): SettingsTerminalView, Bool, String, TriState, auto, off, on, Typography (+1 more)

### Community 495 - "terminal-cheat-sheet.html"
Cohesion: 0.25
Nodes (4): ControlKeyNormalizer, Bool, String, ControlKeyNormalizerTests

### Community 496 - "CASE — Git / FS / Terminal / Architecture"
Cohesion: 0.17
Nodes (11): ACP vs MCP vs Terminal Chat, AgentProcessManager, Architecture, CLI Print-Mode Args, Context Injection, Key Files, Key Shortcuts (I-family), Non-Obvious Constraints (+3 more)

### Community 498 - "SystemdUserInstaller"
Cohesion: 0.17
Nodes (11): 1. `SessionLifecycleService.swift` (tab bar clicks, sidebar clicks), 2. `MainExecutor.swift` (keyboard shortcuts — the actual user path), Competitive research (from Agy), Data model (correct, no changes needed), Files to read before resuming, Fix applied (compiles, not fully tested), Focus Persistence — Per-Session-Tab Pane Focus (RL-043), Restoration flow (after fix) (+3 more)

### Community 500 - ".json"
Cohesion: 0.25
Nodes (6): BinaryRefresher, Bool, URL, BinaryRefresherTests, String, URL

### Community 501 - "Fixed"
Cohesion: 0.15
Nodes (12): Artifacts, Client Application, Client Application, Client Application, Context, Dev Task Progress — P37 Phase G: Autocomplete (mobile bridge), G1 — @ file-path picker ✅ DONE 2026-07-13, G2 — shell tab-completion suggestion strip (heuristic, best-effort) ✅ DONE 2026-07-13 (+4 more)

### Community 503 - "Build Scripts Self-Kill Protection"
Cohesion: 0.11
Nodes (18): .init(coder:), BrowserProgressLine, .init(coder:), .init(frame:), BrowserTabButton, .init(coder:), .init(title:isActive:onSelect:onClose:), DesignModePopoverViewController (+10 more)

### Community 506 - "KittyGraphicsCommand"
Cohesion: 0.22
Nodes (7): Bool, NotificationEvent, agentFinished, agentWaiting, bell, commandFinished, Bool

### Community 507 - ".locate"
Cohesion: 0.14
Nodes (5): GitPanelView, Any, DispatchWorkItem, NSMenuItem, NSClickGestureRecognizer

### Community 509 - "start.mjs"
Cohesion: 0.70
Nodes (4): main(), runCommand(), selectWithArrows(), selectWithReadline()

### Community 510 - "graphify reference: extra exports and benchmark"
Cohesion: 0.23
Nodes (10): .init(url:paneID:webView:), .webView(_:createWebViewWith:for:windowFeatures:), .webView(_:didFinish:), BrowserTab, URL, UUID, WKWebView, tabs (+2 more)

### Community 511 - ".panePathLookup"
Cohesion: 0.28
Nodes (7): State, error, indeterminate, paused, remove, set, TerminalProgressReport

### Community 512 - "Changelog Archive"
Cohesion: 0.26
Nodes (4): PromptQueue, String, SurfaceID, Void

### Community 513 - "ThemeDocument"
Cohesion: 0.29
Nodes (7): .webView(_:didFail:withError:), .webView(_:didFailProvisionalNavigation:withError:), LoadCompletionState, CheckedContinuation, Error, TimeInterval, Void

### Community 514 - "graphify reference: extra exports and benchmark"
Cohesion: 0.27
Nodes (7): Never, Set, String, Task, URL, Void, WorkspaceSymbolIndex

### Community 518 - "KouenIPC"
Cohesion: 0.33
Nodes (4): .setSidebarVisible(_:animated:), SidebarPlacementSyncTests, CGFloat, Void

### Community 521 - ".capsLockRootFallback"
Cohesion: 0.18
Nodes (10): 1. SurfaceShellTracker (proc tree walk), 2. DaemonSyncService.startMetadataRefresh (5-s loop), 3. snapshotChanged Fanout, 4. PerfCounters — Instrumentation, 5. Performance Lessons (v3.2.0), Adaptive polling, Background Polling & Snapshot Fanout — P22, Known Non-P22 Callers of syncFromDaemon (+2 more)

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
Cohesion: 0.29
Nodes (5): OptionSet, .init(key:modifiers:), Modifiers, String, UInt8

### Community 535 - "AgentNotification"
Cohesion: 0.17
Nodes (11): A — detection core (`AgentDetector`, pure logic), B — Claude Code Task-subagent hook push (in-process detection), C — IPC / Tab plumbing, Concurrency contract, Corrections to the original plan text (verified against live source, not assumed), D — Client UI indicator, Open items deferred out of this phase (documented, not silently dropped), P38 Phase B — Subagent/Teammate Visibility (+3 more)

### Community 537 - "TabAlertTests"
Cohesion: 0.36
Nodes (5): OcclusionTests, KouenTerminalSurfaceView, NSWindow, String, TimeInterval

### Community 538 - "SessionGroupHeaderRowView"
Cohesion: 0.06
Nodes (33): MainActor, Void, SessionDividerRowView, .init(coder:), .init(frame:), SessionGroupHeaderRowView, .init(coder:), .init(frame:) (+25 more)

### Community 539 - "install-app.sh"
Cohesion: 0.24
Nodes (4): SavedLayoutIPCDaemonTests, String, URL, UUID

### Community 542 - "SemanticPromptTests"
Cohesion: 0.13
Nodes (12): AnyObject, TimeInterval, ZombieHoldRegistry, PaneLifecycleManager, Bool, NSView, PaneID, PaneNode (+4 more)

### Community 544 - "Task Ledger Archive (Tasks 1–50)"
Cohesion: 0.51
Nodes (9): fuzzyFindFiles(), handleErrors(), handleFind(), handleGrep(), handleMake(), handleRecent(), Int32, String (+1 more)

### Community 545 - "get_window_count"
Cohesion: 0.18
Nodes (10): AI / Agent Connectivity, Architecture Decisions — harness-terminal, Browser Pane, Config / Settings, File Preview / Split Panes, IPC / Daemon, Keybindings, Sessions / Tabs (+2 more)

### Community 546 - "LegacySnapshot"
Cohesion: 0.11
Nodes (14): JSONDecoder, JSONEncoder, LegacySnapshot, LegacyWorkspace, Bool, Date, String, Tab (+6 more)

### Community 547 - "NSObject"
Cohesion: 0.13
Nodes (17): ClosureTarget, MenuActionTarget, OverlayWindow, Phase67UI, PopupWindow, Bool, Command, NSEvent (+9 more)

### Community 548 - ".encode"
Cohesion: 0.18
Nodes (10): Cause 1 — `existingHosts` strong dict in TerminalPaneRegistry (DOMINANT), Cause 2 — Insert-only AI controller dicts in SessionCoordinator, Cause 3 — Uncapped browser network capture array, Memory Leak Audit — 34 GB Long-Session Case (2026-06-26), Pattern to watch: "insert-only per-surface dict", Release, Root causes found and fixed, Symptom (+2 more)

### Community 550 - "cheat.sh"
Cohesion: 0.18
Nodes (10): Burst Coalescing (cmux NotificationBurstCoalescer), CA Mask Pattern (Harness Notch), Combine → CA Bridge, Equality Guard (Zed layout phase), GPU Animation Pattern — Layout Once, GPU Paints, Layer Coordinate System, Principle, References (+2 more)

### Community 551 - ".startWatching"
Cohesion: 0.22
Nodes (8): AnyObject, CommandExecutionError, daemonError, noActiveSurface, targetNotFound, unsupportedInThisContext, CommandExecutor, String

### Community 552 - "[3.12.0] - 2026-06-30"
Cohesion: 0.36
Nodes (5): PaneLeaf, SessionGroup, Any, String, Tab

### Community 553 - "harness.resource"
Cohesion: 0.39
Nodes (5): AutomationSummary, Bool, Date, String, UUID

### Community 557 - "Harness Robot Framework Tests"
Cohesion: 0.27
Nodes (3): KouenCLI, String, Set

### Community 558 - "ThemeCatalogEmbedTests"
Cohesion: 0.57
Nodes (3): SessionSnapshot, Tab, WorkbenchContextResolverTests

### Community 559 - "ScrollbackPersistenceTests"
Cohesion: 0.18
Nodes (3): String, URL, TaskIPCDaemonTests

### Community 570 - "CommandHistorySearchController"
Cohesion: 0.08
Nodes (29): CommandHistorySearchController, .tableView(_:heightOfRow:), .tableView(_:rowViewForRow:), .tableView(_:shouldSelectRow:), .tableView(_:viewFor:row:), HistoryItemView, .init(coder:), .init(command:query:) (+21 more)

### Community 574 - "CLAUDE.md"
Cohesion: 0.20
Nodes (9): 1. Sidebar toggle (⌘\), 2. File preview open/close, 3. Tab switch (⌘1-9, ✕ close), 4. presentsWithTransaction order fix (ALL remaining flash cases) — v3.9.x+, Fixes Applied (v3.9.1+), Related Lessons, Root Cause Pattern, Rules (+1 more)

### Community 576 - "[3.10.0] - 2026-06-27"
Cohesion: 0.20
Nodes (9): 1. Board Sidebar Tab (GUI), 2. Harness CLI Command, 3. Scripting API, 4. Read-Only MCP Tool, Agent/Session Board (P16), Centralized Classification, Consumers, Data Model (PBI-BOARD-001) (+1 more)

### Community 578 - "TerminalProgressReport"
Cohesion: 0.10
Nodes (21): FileTreeKeyboardNavigator, FileTreeKeyboardState, Bool, NSEvent, String, Void, FileTreeContext, Bool (+13 more)

### Community 579 - "DecoKind"
Cohesion: 0.11
Nodes (12): AgentNotchPresentation, closed, open, peek, AgentNotchViewModel, AgentNotchWindowActivator, Bool, CGFloat (+4 more)

### Community 580 - "P4 — LSP + File View (Code Preview in Sidebar)"
Cohesion: 0.15
Nodes (15): Architecture, Components, Estimate, Files, Goal, Grammars, Implementation Notes (MVP — plain-text viewer), LSP Discovery (+7 more)

### Community 581 - "Current Sprint — Post-v2.1.0 Polish & Shelving"
Cohesion: 0.40
Nodes (5): Current Sprint — Post-v2.1.0 Polish & Shelving, Decisions_In_Force, Recent_Lessons, Removed / Reverted Features, Task_Ledger

### Community 582 - "FileTreeKeyboardNavigator"
Cohesion: 0.33
Nodes (3): DisplayWidth, String, Unicode

### Community 584 - ".detect"
Cohesion: 0.09
Nodes (10): FormatContextBuilder, DaemonSurfaceID, SessionSnapshot, String, FormatContextDaemonTests, PaneID, SessionSnapshot, String (+2 more)

### Community 586 - ".statusLineSet"
Cohesion: 0.18
Nodes (6): JSONOutputFormatter, Bool, String, T, JSONOutputFormatterTests, T

### Community 589 - "Endpoint"
Cohesion: 0.33
Nodes (4): GridCompositorCopyModeTests, PaneRect, String, TerminalGridSnapshot

### Community 591 - "NodeRow"
Cohesion: 0.47
Nodes (3): ScrollReuseTests, KouenTerminalSurfaceView, NSWindow

### Community 594 - "KeyRecorderView.swift"
Cohesion: 0.28
Nodes (5): SpecialKeyMappingTests, Bool, NSEvent, String, UInt16

### Community 596 - "prepare-release.sh"
Cohesion: 0.53
Nodes (4): display_menu(), run(), prepare-release.sh script, usage()

### Community 598 - ".load"
Cohesion: 0.20
Nodes (9): Architecture, Branch chip — CASE-020, Features, FSEvents Pattern (Swift Actor), Git Panel, History → File Editor, Real-time Refresh, v1 — CASE-009 (resolved, superseded) (+1 more)

### Community 600 - "HarnessTerminalSurfaceView"
Cohesion: 0.08
Nodes (16): NSRangePointer, NSTextInputClient, KouenTerminalSurfaceView, Any, Bool, NSAttributedString, NSEvent, NSPoint (+8 more)

### Community 603 - "MenuBarController"
Cohesion: 0.14
Nodes (15): AgentRow, AgentRow, MenuBarController, MenuRef, CGFloat, NSImage, NSMenu, NSMenuItem (+7 more)

### Community 608 - ".testRenderEncodeIncrementalDamage160x48"
Cohesion: 0.12
Nodes (23): FooterIconButton, RecentProjectsMenuButton, SidebarFooterModel, SidebarFooterView, SidebarSectionLabelView, SidebarSectionModel, SidebarTabBarView, Bool (+15 more)

### Community 613 - "INDEX.md"
Cohesion: 0.18
Nodes (10): Current architecture relevant to these gaps, P38 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed), Phase A — Cross-agent diff/review dashboard (biggest gap vs Superset/Supacode) — ✅ DONE 2026-07-13, see p38-phase-a-diff-dashboard/{design.md,dev-task-progress.md}, Phase B — Subagent/teammate visibility as panes (vs cmux) — ✅ CLOSED 2026-07-16 (build/test/robot green, live check skipped per user decision), Phase C — Agent "thread" UX on top of existing block capture (vs Zed Terminal Threads) — ⚠️ pivoted 2026-07-15, ✅ CLOSED 2026-07-16 (build/test/robot green, cross-pane jump-to-block live check skipped per user decision), see p38-phase-c-thread-overlay/{design.md,dev-task-progress.md}, Phase D — Terminal image protocol (Kitty Graphics) — vs WezTerm — ✅ D1 DONE 2026-07-14 (finding: NOT deferred), D3 conformance slice built, ✅ CLOSED 2026-07-16 (build/test/robot green, real-client live check skipped per user decision), Phase E — Scripting hook parity (JS vs WezTerm's Lua) — low priority — ✅ DONE 2026-07-14, ✅ CLOSED 2026-07-16 (low-priority live check skipped per user decision), Phases (+2 more)

### Community 614 - "MainSplitViewController"
Cohesion: 0.09
Nodes (20): CGFloat, MainSplitViewController, .setSidebarVisible(_:), SplitChromeDelegate, .splitView(_:constrainMaxCoordinate:ofSubviewAt:), .splitView(_:constrainMinCoordinate:ofSubviewAt:), .splitView(_:effectiveRect:forDrawnRect:ofDividerAt:), .splitView(_:shouldAdjustSizeOfSubview:) (+12 more)

### Community 617 - "ScriptFileWatcher"
Cohesion: 0.11
Nodes (23): CodingKeys, activeSurfaceID, daemonSurfaceID, id, surfaceID, surfaces, PaneLeaf, .init(from:) (+15 more)

### Community 618 - "CommandFinishedTests"
Cohesion: 0.22
Nodes (8): CASE-063a — sound toggle, CASE-063b — click doesn't route, Files, Fix Applied, If Fix Is Insufficient, Notification Sound Toggle Ignored + Banner Click Didn't Navigate, Root Cause, Symptom

### Community 619 - "commit-push-merge.sh"
Cohesion: 0.22
Nodes (8): Detection Method, Fix, NSTextField Leak in BoardViewController (P20 Performance), Prevention Rules, Related Files, Root Cause, Symptom, Why CPU Goes Up

### Community 620 - "NSView"
Cohesion: 0.11
Nodes (5): NSTextView, KouenApp, GitPanelViewDiffPopoverTests, GitPanelViewFSEventFilterTests, GitPanelViewWorktreeParsingTests

### Community 621 - "ViEngine"
Cohesion: 0.06
Nodes (12): LinePos, end, firstNonBlank, start, ViDiagnosticNavigator, Bool, String, ViEngine (+4 more)

### Community 622 - "[1.3.0-vit] - 2026-06-06"
Cohesion: 0.50
Nodes (3): LiveResizeGeometry, Result, Bool

### Community 623 - "BrowserResponsePayload"
Cohesion: 0.15
Nodes (10): PaneNode, BrowserLeaf, URL, DaemonSyncServiceBrowserPaneMergeTests, PaneID, PaneNode, DaemonSessionServiceTests, PaneNodeBrowserTests (+2 more)

### Community 624 - "[2.5.0] - 2026-06-12"
Cohesion: 0.33
Nodes (5): CopyModeLine, .charIndex(atOrAfter:), .charIndex(atOrBefore:), Character, String

### Community 626 - "NotificationCoordinator"
Cohesion: 0.29
Nodes (6): 1. Transparency pipeline hardcoded off, 2. Chrome tint double-composited over the window's own tint, 3. One chrome strip not routed through the shared ChromeBackdrop system, 4. Accessibility contrast floor corrupting ANSI/pixel-art content, Cross-cutting, P8 macOS27 adoption — Liquid Glass chrome regressions (2026-07-25/26)

### Community 627 - "ActiveTabCloseDisposition"
Cohesion: 0.39
Nodes (4): OutputTrigger, OutputTriggerStore, Bool, String

### Community 629 - "graphify reference: query, path, explain"
Cohesion: 0.32
Nodes (6): CGFloat, ResizeDirection, down, left, right, up

### Community 630 - "[3.0.0] - 2026-06-15"
Cohesion: 0.18
Nodes (10): Cleanup on toggle off / pane close, Design — M3: Browser Design Mode, JS injection (on toggle ON, via `evaluateJS`, not a persistent `WKUserScript` —, Logical Design, Native message handler, Next Step, Popover UI, Strategic Design (+2 more)

### Community 637 - "ClientSummary"
Cohesion: 0.05
Nodes (30): NSCursor, .interval(_:_:), T, KouenTerminalSurfaceView, .init(themeName:fontFamily:fontSize:vivid:colorRendering:colorGamut:offMainParserFramePipeline:liveResizeReflow:), .receive(_:), PendingMainHop, SurfaceColorProviderState (+22 more)

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
Cohesion: 0.22
Nodes (10): Counter, DrainResult, DrainState, EchoRTT, PtyDrainCeilingBenchmark, Bool, DispatchSemaphore, Double (+2 more)

### Community 649 - "Added"
Cohesion: 0.38
Nodes (3): SettingsAdvancedView, Bool, String

### Community 650 - "[3.11.0] - 2026-06-28"
Cohesion: 0.21
Nodes (7): Bool, NSRange, NSString, Void, SyntaxTextView, .init(frame:), .lspPosition(characterOffset:)

### Community 654 - "press_shortcut"
Cohesion: 0.36
Nodes (3): BlockContextMenuTests, KouenTerminalSurfaceView, String

### Community 655 - "CodingKeys"
Cohesion: 0.22
Nodes (8): Accessibility Requirements, Files, Permission, Running, Stack, Test Strategy, UI Automation — Robot Framework (P18), Why Not Appium

### Community 656 - "Proposal: Merging Devin/Windsurf Kanban & CMUX Multiplexer UX into Harness"
Cohesion: 0.29
Nodes (6): 1. Summary of Davin/Windsurf Kanban + CMUX UX, 2.1 Sidebar Sessions Panel Enhancements, 2.2 Per-Session Top Bar / Tab Strip Enhancements, 2. Integration Proposal for Harness, 3. Concrete File-Level Change List, Proposal: Merging Devin/Windsurf Kanban & CMUX Multiplexer UX into Harness

### Community 658 - "[3.1.0] - 2026-06-15"
Cohesion: 0.22
Nodes (8): AppKit + Metal Patterns, CADisplayLink Lifetime on macOS (CASE-031), Metal Surface Lifecycle (CASE-003), Mouse Selection Must Use Virtual-Line Coordinates (CASE-029), NSFont Italic (CASE-010), NSView Layer Opacity — Preview Parity Pattern (CASE-011), Overlay Above Metal (CASE-004), Window Background Tint for Legibility (CASE-027)

### Community 659 - "MCPServer"
Cohesion: 0.20
Nodes (4): Bool, Double, TerminalReplay, TerminalRecordingTests

### Community 660 - "NotificationEntry"
Cohesion: 0.22
Nodes (8): Architecture, Infinite Recursion (CASE-006), Pane Drag-and-Drop (P27), Ratio Persistence (CASE-002), Split CWD Resolution — Worktree Priority (2026-06-21), Split Panes (NSSplitView), Subview Reorder (CASE-007), Two-Axis Split Parity (P13)

### Community 661 - "Remote SSH — Market Comparison"
Cohesion: 0.33
Nodes (5): Kouen vs Competitors (Remote Development over SSH), Our Gaps (vs leaders), Our Strengths, Remote SSH — Market Comparison, Roadmap Opportunities

### Community 662 - "New Tab"
Cohesion: 0.20
Nodes (3): AutomationIPCDaemonTests, String, URL

### Community 663 - "[3.1.2] - 2026-06-16"
Cohesion: 0.60
Nodes (3): ProjectTask, ProjectTaskDetector, String

### Community 664 - "P37 Phase G — Autocomplete (mobile bridge)"
Cohesion: 0.18
Nodes (10): cmd-F contract (C2) — contextual, not a rewrite of `updateFind`, Design: overlay, not a new render subtree, Known caveat (pre-existing, inherited not fixed), Open decisions (not decided here, confirm before Stage 4 if it matters), Original design (2026-07-14, deleted 2026-07-15 — kept for history only), P38 Phase C — Agent Thread UX on Existing Block Capture, Pivot (2026-07-15, mid live-test) — supersedes the original design below, Regression risk: near-zero by construction (+2 more)

### Community 665 - "PathToken"
Cohesion: 0.24
Nodes (3): Bool, SurfaceID, MenuTargetPeerReviewTests

### Community 666 - "BrowserIntegrationController"
Cohesion: 0.27
Nodes (6): KittyGraphicsCommand, Bool, Character, Data, String, UInt8

### Community 669 - ".recordReapedGenerationForTesting"
Cohesion: 0.27
Nodes (4): FrameBuilderCopyModeTests, RGBColor, String, TerminalGridSnapshot

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

### Community 676 - "[2.1.0] - 2026-06-07"
Cohesion: 0.33
Nodes (3): String, URL, ThemeCatalogEmbedTests

### Community 678 - "FilePreviewCoordinator"
Cohesion: 0.39
Nodes (3): data, SixelDecoder, UInt8

### Community 679 - "[3.5.0] - 2026-06-20"
Cohesion: 0.25
Nodes (7): Framing, IPC Architecture, Key Invariant, Overview, Process Separation, Security, Subscriptions

### Community 680 - "HarnessCLI+Workbench.swift"
Cohesion: 0.25
Nodes (7): ⌘1-9 and ⌘[ / ⌘] = Session-level navigation (CASE-028), Data Model, Session/Tab/Pane Hierarchy & Top Bar (CASE-028), Sidebar Session Groups = One Header Per SessionGroup, Source Map, Tab Pill Visual Details, Top Bar = 1 Pill Per Session (not per-tab)

### Community 681 - "Cross-terminal output-stress benchmark"
Cohesion: 0.40
Nodes (4): Cross-terminal output-stress benchmark, Run, The faithful scoreboard, What it measures — and what it does NOT

### Community 682 - "TreeSitterGrammarBundle"
Cohesion: 0.25
Nodes (7): Case: cwd "bleed" — session worktree jumps to wrong dir during builds, Companion bug: blank panel on first open (CASE-042), Fix, Lesson, Repro (deterministic, headless — no GUI needed), Root cause, Symptom

### Community 684 - "[3.9.5] - 2026-06-26"
Cohesion: 0.25
Nodes (7): Apple Platform Context — Transparency & Legibility, Architecture Decisions, iOS/macOS 26 — Liquid Glass introduction, iOS/macOS 27 — Liquid Glass refinements (WWDC 2026), Known Issues (Current), Project History, Sprint Timeline

### Community 685 - "[1.5.1] - 2026-06-06"
Cohesion: 0.33
Nodes (6): emitArray(), hex(), referenceWidth(), String, T, UInt8

### Community 686 - ".status"
Cohesion: 0.26
Nodes (4): String, TerminalGridCell, TextGrid, WordColumnRangeTests

### Community 689 - "Bool"
Cohesion: 0.40
Nodes (5): CGFloat, Range, TabBarLayoutMetrics, TerminalTabBarBody, TerminalTabBarModel

### Community 691 - "Phase6KeysTests"
Cohesion: 0.19
Nodes (4): BrowserPaneView, DesignModeElementInfo, NSPopover, String

### Community 692 - ".testOptionLinesAreNotCommands"
Cohesion: 0.40
Nodes (3): KouenGridTerminal, TerminalGridCell, TerminalEmulator

### Community 693 - "[2.0.0] - 2026-06-07"
Cohesion: 0.33
Nodes (5): Claude Code → Kouen, Customizing, One-line install, Verifying, What gets written

### Community 694 - "TerminalScreen"
Cohesion: 0.67
Nodes (3): AsyncCLIResultBox, Error, Result

### Community 696 - "TerminalTabBarDelegate"
Cohesion: 0.25
Nodes (7): Avoid, Colors, Components, Design Direction, Design System, Spacing / Radius / Motion, Typography

### Community 700 - "Lexer"
Cohesion: 0.22
Nodes (6): SettingsAppearanceView, SliderRow, Bool, ClosedRange, Double, String

### Community 708 - "[3.4.0] - 2026-06-19"
Cohesion: 0.11
Nodes (17): DaemonCommandExecutor, Command, BellScanState, esc, normal, string, stringEsc, SurfaceMonitor (+9 more)

### Community 709 - ".start"
Cohesion: 0.19
Nodes (3): PipeBuffer, Result, MobileBridgeAISuggestTests

### Community 710 - "MainWindowController"
Cohesion: 0.16
Nodes (7): KouenWindow, NSEvent, MainWindowController, Any, NSRect, NSWindow, NSWindowController

### Community 711 - "FileTabManager"
Cohesion: 0.26
Nodes (3): BellScanTests, Bool, UInt8

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
Cohesion: 0.16
Nodes (13): .init(coder:), .init(frame:), HunkActionButton, .init(coder:), .init(title:onClick:), StageToggleButton, .init(coder:), .init(frame:) (+5 more)

### Community 720 - ".printBoard"
Cohesion: 0.22
Nodes (3): MobileBridgeSpawnTests, String, URL

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

### Community 738 - "AgentHookInstaller.swift"
Cohesion: 0.13
Nodes (15): Command, PaneRef, bottom, byID, byIndex, last, left, next (+7 more)

### Community 744 - "TerminalGridCellLayoutTests"
Cohesion: 0.11
Nodes (10): tab, .tab(for:), AgentScanner, Bool, DispatchSourceTimer, TimeInterval, PanePipe, .subscribe(surfaceID:handler:) (+2 more)

### Community 745 - "p11_scripting.robot"
Cohesion: 0.20
Nodes (3): AgentRoutingRuleIPCDaemonTests, String, URL

### Community 764 - "Workbench commands (IDE-like workflow)"
Cohesion: 0.33
Nodes (6): Board and attention, Errors and LSP, File navigation, Search, Task runner, Workbench commands (IDE-like workflow)

### Community 792 - "harness-cli.fish"
Cohesion: 0.36
Nodes (5): ShellInfo, ShellStepView, Bool, String, URL

### Community 796 - "graphify reference: GitHub clone and cross-repo merge"
Cohesion: 0.29
Nodes (6): Command Prompt Architecture, Files, Gotchas, Key rule: every documented verb needs BOTH layers, Layers, Verb categories

### Community 797 - "Motion"
Cohesion: 0.50
Nodes (3): Kouen Domain Language, MCP Surface, Relationships

### Community 798 - "LayoutProbeView"
Cohesion: 0.33
Nodes (5): Gate: cmd-backslash-sidebar-launch-race-6th, Gate: cmd-backslash-sidebar-toggle, Gate: cmd-backslash-sidebar-zero-width, Gate: kouen-browser-mcp-intermittent-unresponsive, Gate State

### Community 804 - "AgentVectorIcon"
Cohesion: 0.21
Nodes (5): KouenPaths, SessionStore, DispatchWorkItem, SessionSnapshot, TimeInterval

### Community 809 - "RawSelection"
Cohesion: 0.29
Nodes (6): Anti-Patterns Avoided, Architecture, Key Design Decisions, Pattern, Service Decomposition — SessionCoordinator (P17), When to Apply This Pattern

### Community 817 - "ProbeOutputBox"
Cohesion: 0.17
Nodes (12): CodingKey, CodingKeys, activeWorkspaceID, keepSessionsOnQuit, revision, savedAt, themeName, version (+4 more)

### Community 830 - "graphify reference: transcribe video and audio"
Cohesion: 0.29
Nodes (6): Browser Tab Close Button Unresponsive, Files, Fix Applied, If Fix Is Insufficient, Root Cause, Symptom

### Community 832 - "KouenCLIPaths"
Cohesion: 0.33
Nodes (5): Bug pattern: browser-pane preserve-merge discards real daemon changes, Lesson for the next occurrence, Occurrence 1 — 2026-06-15 (`b76fb0dd`), Occurrence 2 — 2026-07-23 (this session), Root architectural fact

### Community 836 - "GroupedSessionDaemonTests"
Cohesion: 0.24
Nodes (4): GroupedSessionDaemonTests, SessionGroup, String, URL

### Community 839 - "RawSelection"
Cohesion: 0.29
Nodes (6): Architecture / Keybindings, CASE — Git / FS / Terminal / Architecture, Claude Code / Tooling / Environment (the agent running *inside* Harness), Command Prompt / Parser, Git / File System, Terminal / Renderer / Daemon

### Community 840 - "Added"
Cohesion: 0.29
Nodes (6): ACP Client (Shelved), Architecture (Preserved), Re-enablement Criteria, Status: SHELVED (June 2026), What It Is, Why Shelved

### Community 841 - "Now"
Cohesion: 0.29
Nodes (6): Build Scripts Self-Kill Protection, Detection, Fix (applied in `Scripts/run.sh`), Key Invariant, Problem, Related

### Community 865 - "MCPServer"
Cohesion: 0.29
Nodes (3): KouenMCPServer, MCPServer, String

### Community 903 - "XCTestCase"
Cohesion: 0.22
Nodes (9): Docs, kouen-mcp, KouenApp (Settings UI), KouenCore, KouenDaemon, KouenIPC, M2 — Agent Routing Rule — Task Progress, Tests (+1 more)

### Community 920 - "generate-release-notes.swift"
Cohesion: 0.44
Nodes (8): digest(), firstMatch(), flushBullet(), Section, stripMarkdown(), summarize(), String, swiftLiteral()

### Community 949 - "ThaiClusterCopyTests.swift"
Cohesion: 0.29
Nodes (5): BrowserPaneRegistry, .init(url:paneID:), NSWindow, PaneID, WeakBrowserPaneView

### Community 982 - "PaneID"
Cohesion: 0.33
Nodes (5): Codex Fix Prompt Template, FSEvents Recursive Watcher Pattern (Swift), Full Swift Actor Pattern, Single-file watch (DispatchSource is enough), When to use

### Community 991 - "Changed"
Cohesion: 0.22
Nodes (8): Build order (unchanged from interview decision), G1 — @ file-path picker, G2 — shell tab-completion suggestion strip (heuristic, explicitly best-effort), G3 — AI command suggestion (via `claude` CLI subprocess), Logical Design, P37 Phase G — Autocomplete (mobile bridge), Strategic Design, Tactical Design

### Community 1000 - "Changed"
Cohesion: 0.22
Nodes (8): Artifacts, Client Application — Slice 1 (stacked panes, no persistence), Client Application — Slice 2 (per-workspace divider memory), Context, Dev Task Progress — Workspace Sidebar Panels (P42), Integration, Note on task re-sequencing (2026-07-17), Summary

### Community 1106 - "shim.c"
Cohesion: 0.13
Nodes (5): CKouenSys, Configuration, UInt16, UInt8, TTYSize

### Community 1109 - ".tomlKouenBlock"
Cohesion: 0.33
Nodes (4): Bool, SessionCoordinator, String, ThemeService

### Community 1155 - "object"
Cohesion: 0.43
Nodes (3): KouenSettings, Bool, Data

### Community 1173 - ".feedBuffer"
Cohesion: 0.42
Nodes (3): BrowserIntegrationController, NSView, PaneID

### Community 1255 - "LayoutProbeView"
Cohesion: 0.36
Nodes (3): KouenSplitViewTests, LayoutProbeView, CGFloat

### Community 1303 - ".pushAgentActivityNotifications"
Cohesion: 0.50
Nodes (3): exclude_hubs, no_viz, wiki

### Community 1305 - "TerminalColorRole"
Cohesion: 0.22
Nodes (10): DotView, .init(coder:), .init(frame:), Bool, Context, NSCoder, NSColor, NSRect (+2 more)

### Community 1306 - ".rememberTabForReopen"
Cohesion: 0.20
Nodes (10): Section, actions, errors, files, grep, navigation, projects, recent (+2 more)

### Community 1309 - ".startMetadataRefresh"
Cohesion: 0.83
Nodes (3): entries(), cheat.sh script, usage()

### Community 1398 - ".tabIDsToNotify"
Cohesion: 0.36
Nodes (4): NSHostingView, Tab, TerminalTabBarView, .init(frame:)

### Community 1402 - "PromptQueueBar"
Cohesion: 0.36
Nodes (3): SplitDirection, TabID, TerminalTabBarDelegate

### Community 1514 - "Changed"
Cohesion: 0.29
Nodes (5): BoardCardView, .init(card:), .init(coder:), NSCoder, Void

### Community 1544 - "TargetSpec.swift"
Cohesion: 0.29
Nodes (7): CodingKeys, createdAt, dataBase64, rows, timeMs, type, version

### Community 1545 - "AutomationScheduler"
Cohesion: 0.42
Nodes (3): Lexer, Bool, Character

### Community 1574 - "Fixed"
Cohesion: 0.33
Nodes (4): SurfaceMainThreadStallSample, SurfaceOffMainStallSample, Data, UInt64

### Community 1801 - "ClientSummary"
Cohesion: 0.25
Nodes (4): Active Plans, Completed, Plans Index — kouen-terminal, Quick ref — recent completions

### Community 1818 - "ClientSummary"
Cohesion: 0.25
Nodes (8): Docs, KouenApp, KouenCore, KouenDaemon, KouenIPC, M5 — Saved Layouts — Task Progress, Tests, Verification

### Community 1832 - "Added"
Cohesion: 0.25
Nodes (7): Claude Code hook push (in-process Task subagent detection), Client UI indicator, Detection core (AgentDetector, pure logic), IPC / Tab plumbing, P38 Phase B — Subagent Visibility — Dev Task Progress, Status: Rewritten 2026-07-14 after original implementation (tasks 1-5) was lost to a concurrent git operation before commit. Closed 2026-07-16 on user instruction, live check skipped., Summary

### Community 1857 - "RawSelection"
Cohesion: 0.54
Nodes (5): Process, .init(makeTunnelProcess:reachabilityProbe:), RemoteHost, URL, Tunnel

### Community 1914 - "P43 — Add Repo/Folder to Workspace"
Cohesion: 0.25
Nodes (7): Original overlay build (built 2026-07-14, gated green, then deleted 2026-07-15 mid live-test), P38 Phase C — Agent Thread UX on Existing Block Capture — Dev Task Progress, Pivot — merge into the Recipes picker (2026-07-15), Stage 1-2 — Engine/surface plumbing (built 2026-07-14, unchanged by the pivot, still in use), Status: Implementation pivoted mid-phase from a standalone overlay to a merge into the existing, Summary, Thread grouping — Zed framing folded into the same picker (2026-07-15)

### Community 1933 - ".load"
Cohesion: 0.25
Nodes (6): Kind, path, stack, Bool, Date, UUID

### Community 1943 - "ITerm2InlineImage"
Cohesion: 0.25
Nodes (8): Docs, kouen-mcp, KouenCore, KouenDaemon, KouenIPC, P41 — Automations — Task Progress, Tests, Verification

### Community 2002 - ".performKeyEquivalent"
Cohesion: 0.15
Nodes (4): SelectAllOnClickTextField, NSEvent, Selector, NSAppearance

### Community 2006 - ".deleteWorkspaceFromMenu"
Cohesion: 0.12
Nodes (20): BoxDrawing, Kind, arms, dashH, dashV, halfDown, halfLeft, halfRight (+12 more)

### Community 2014 - "Added"
Cohesion: 0.43
Nodes (6): Document, Bool, Set, String, URL, ToolPolicy

### Community 2015 - ".pathDisplayName"
Cohesion: 0.29
Nodes (7): TabContextCommand, close, closeOthers, rename, splitHorizontal, splitVertical, togglePersistent

### Community 2055 - "Changed"
Cohesion: 0.29
Nodes (6): CommandParseError, emptyInput, expectedCommand, missingFlag, unknownCommand, unterminatedString

### Community 2067 - "Changed"
Cohesion: 0.33
Nodes (3): NSPoint, NSRect, TerminalFrameOverlayView

### Community 2126 - ".applyFontSize"
Cohesion: 0.48
Nodes (3): ANSIPalette, RGBColor, UInt8

### Community 2147 - "Changed"
Cohesion: 0.33
Nodes (6): Docs, Environment fix discovered this session (not part of M3's diff — `.build/` is gitignored), KouenApp — BrowserPaneView.swift, M3 — Browser Design Mode — Task Progress, Tests, Verification

### Community 2150 - "KouenCLIPaths"
Cohesion: 0.33
Nodes (5): Design — M4: Fork Conversation, Logical Design, Next Step, Strategic Design, Tactical Design

### Community 2176 - "Changed"
Cohesion: 0.29
Nodes (6): Locked decisions (user-confirmed), Logical Design, P38 Phase A — Cross-Agent Worktree Diff/Review Dashboard — Design, Strategic Design, Tactical Design, Verification gate (this phase)

### Community 2178 - "M8 — Merge Waiver — Task Progress"
Cohesion: 0.33
Nodes (6): Docs, KouenApp, KouenCore — GitHubCLIClient.swift, M8 — Merge Waiver — Task Progress, Tests, Verification

### Community 2191 - "Changed"
Cohesion: 0.40
Nodes (5): DecodedWSFrame, WSFrameParseResult, frame, incomplete, oversized

### Community 2213 - "ThaiClusterCopyTests.swift"
Cohesion: 0.53
Nodes (3): TerminalGridCell, ThaiClusterCopyTests, ThaiGrid

### Community 2242 - "P42 — Workspace Sidebar Panels"
Cohesion: 0.29
Nodes (6): Logical Design, Next Step, P42 — Workspace Sidebar Panels, Parked (not in scope), Strategic Design, Tactical Design

### Community 2341 - ".handleCat"
Cohesion: 0.40
Nodes (3): KouenCLI, String, String

### Community 2357 - "M4 — Fork Conversation — Task Progress"
Cohesion: 0.40
Nodes (5): Docs, KouenApp — MainMenuBuilder.swift, M4 — Fork Conversation — Task Progress, Tests, Verification

### Community 2427 - "Fixed"
Cohesion: 0.40
Nodes (5): Docs, KouenApp, M6 — Risky Command Advisory — Task Progress, Tests, Verification

### Community 2523 - "M7 — Request Peer Review — Task Progress"
Cohesion: 0.40
Nodes (5): Docs, KouenApp — MainMenuBuilder.swift, M7 — Request Peer Review — Task Progress, Tests, Verification

### Community 2526 - "M9 — Slash Command Picker — Task Progress"
Cohesion: 0.40
Nodes (5): Docs, KouenApp — ComposerPanel.swift, M9 — Slash Command Picker — Task Progress, Tests, Verification

### Community 2541 - "P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable"
Cohesion: 0.33
Nodes (6): Competitive comparison (2026-07-13, post Phase D+E), Current architecture (as shipped, build 195), P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable, Phase F — candidates from competitive research (not scoped, not scheduled), Risk review (ranked), Verification gates (every phase)

### Community 2554 - "TerminalEmulator.swift"
Cohesion: 0.40
Nodes (4): Dispatch, Charset, ascii, decSpecialGraphics

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

### Community 2681 - "Plans Index — kouen-terminal"
Cohesion: 0.50
Nodes (4): Active Plans, Completed, Plans Index — kouen-terminal, Quick ref — recent completions

### Community 2706 - "PaletteMode"
Cohesion: 0.50
Nodes (4): PaletteMode, errors, grep, normal

### Community 2735 - "BlockSummary"
Cohesion: 0.60
Nodes (3): BlockSummary, Date, String

### Community 2938 - "Phases"
Cohesion: 0.40
Nodes (5): Phase A — Hardening (daemon only, no UI), Phase B — In-app pairing UX (macOS Settings), Phase C — Real mobile client (W3, replaces smoke-test page) — DONE 2026-07-09, uncommitted, Phase D — File preview, file attach, browser mirror (v1.1 — the former W4/W4b/W5, now scoped), Phases

### Community 3130 - "WriteOutcome"
Cohesion: 0.50
Nodes (4): WriteOutcome, complete, failed, wouldBlock

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
Cohesion: 0.24
Nodes (6): AboutPanelController, AboutView, MonoPillButtonStyle, Configuration, NSWindow, NSHostingController

### Community 3515 - "RawRepresentable"
Cohesion: 0.09
Nodes (24): KeySpec, Binding, .init(from:), .init(spec:command:note:repeatable:), CodingKeys, bindings, disabledSpecs, id (+16 more)

## Knowledge Gaps
- **4029 isolated node(s):** `AppIntents`, `noActivePane`, `horizontal`, `vertical`, `unsupportedPlatform` (+4024 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2431 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.
- **15 possibly unreachable function(s):** `.addSurface(tabID:paneID:)`, `.agentInfo(forWorktreePath:tabs:)`, `.color(_:)`, `.color(_:alpha:)`, `.encode(_:modifiers:event:modes:)` (+10 more)
  Not reached from any recognized entry point - could be dead code, or dynamically dispatched/decorator-registered.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Int` connect `ViEngine` to `Changelog Archive`, `callingPaneTarget`, `graphify reference: extra exports and benchmark`, `EngineConformanceTests`, `IPCRequest`, `AgentNotchRootView`, `LSPMessage`, `AutomationScheduler`, `PerformanceBenchmarks`, `GitPanelView.swift`, `TerminalEmulator`, `KittyKeyboardTests`, `VTParser`, `HarnessTerminalSurfaceView`, `MetalRendererTests`, `HarnessUILibrary`, `SpecialKey`, `HarnessChrome`, `HarnessTerminalSurfaceView`, `CopyModeAction`, `SplitPaneCoordinator`, `.request`, `WorktreeManager`, `SessionGroupHeaderRowView`, `RGBColor`, `.parse`, `Notification`, `.addTab`, `Equatable`, `LegacySnapshot`, `MenuTarget`, `.resolve`, `String`, `Fixed`, `TerminalColorGamut`, `Task Ledger Archive (Tasks 1–50)`, `CodingKeys`, `HarnessSidebarPanelViewController.swift`, `RenderSchedulerTests`, `harness.resource`, `.buildCommand`, `.normalizedKey`, `DaemonServer`, `.keyEvent`, `HarnessSplitView`, `TabCell`, `newWindow`, `BellScanState`, `CommandHistorySearchController`, `PasteBufferStore`, `FrecencyDirectoryStore`, `ComposedCell`, `HarnessCLI+Server.swift`, `PrefixKeymap`, `TerminalProgressReport`, `DecoKind`, `String`, `FileTreeKeyboardNavigator`, `XCTestCase`, `.detect`, `.parse`, `Endpoint`, `.applyFontSize`, `HarnessDesign`, `.handleWake`, `selectWorkspace`, `LSPClient`, `.highlightedTitle`, `TerminalGridCell`, `HarnessPaths`, `HarnessTerminalSurfaceView`, `TerminalModes`, `MenuBarController`, `AttachInputBatcher`, `shim.c`, `.testRenderEncodeIncrementalDamage160x48`, `PaneContainerView`, `ScriptRuntime.swift`, `MainSplitViewController`, `DaemonLauncher`, `Recipe`, `Changelog`, `AnyCodable`, `NSView`, `DamageTrackingTests`, `SoftIconButton`, `[1.3.0-vit] - 2026-06-06`, `.makeSnapshot`, `[2.5.0] - 2026-06-12`, `HarnessGridTerminal`, `.encode`, `.firstWaitingTab`, `graphify reference: query, path, explain`, `WorkspaceFileTreeView`, `HistoryRingBuffer`, `.path`, `ClientSummary`, `GlyphAtlas`, `SwiftUI`, `.install`, `AgentHookInstaller`, `CommandTarget`, `.startWatching`, `ActivePaneService`, `[3.11.0] - 2026-06-28`, `PtyDrainCeilingBenchmark`, `Changed`, `PaneStyleSet`, `AsciiFastPathTests`, `MCPServer`, `What You Must Do When Invoked`, `BrowserIntegrationController`, `Int`, `ThaiCombiningMarkTests`, `LiveResizeTests`, `.recordReapedGenerationForTesting`, `P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable`, `TerminalFindBar`, `CommandPromptController`, `ActiveTabCloseDisposition`, `FilePreviewCoordinator`, `.jumpToBlock`, `ThaiClusterCopyTests.swift`, `URLDetection`, `.decodeKeySpec`, `BoardCard`, `[1.5.1] - 2026-06-06`, `BlockSummary`, `Added`, `.rects`, `Bool`, `Phase6KeysTests`, `InlineAICompletionView`, `.testOptionLinesAreNotCommands`, `P25 — iOS/iPadOS Support`, `[3.13.1] - 2026-07-02`, `VTConformanceCorpusTests`, `LSPServerRegistry`, `Error`, `AppDelegate`, `SessionSnapshot`, `GridCompositorTests`, `TerminalScreen`, `ScriptRuntime`, `GlyphRasterizer`, `BinaryInstaller`, `Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag`, `ResizeHUDView`, `[3.4.0] - 2026-06-19`, `AgentSessionSummary`, `.classify`, `MCP Server (harness-mcp)`, `[3.9.5] - 2026-06-26`, `HarnessCLI`, `scheduleRender`, `.testDataFrameEncodeVsJSONBase64Output`, `PaneTarget`, `NotchLayoutMetrics`, `CellColorResolverTests`, `GridCompositor`, `TerminalServicesProvider`, `ANSIPalette`, `CellColorResolver`, `HarnessPathDisplay`, `AgentHookInstaller.swift`, `TargetSpec.swift`, `ExternalOpenKind`, `WorkbenchCommand`, `TerminalMetalRenderer`, `PaneBorderStatus`, `[3.5.1] - 2026-06-20`, `ThemeDocumentTests`, `ReflowPreviewTests`, `SessionCoordinator`, `BoardViewController`, `workspace`, `release-hotfix.sh`, `Sidebar SwiftUI Migration — Knowledge`, `WindowTitleStripView`, `ThemeFileServiceTests`, `listSurfaces`, `.welcome`, `.install`, `HarnessSidebarPanelViewController`, `.userNotificationCenter`, `.path`, `[2.2.4] - 2026-06-11`, `[3.11.2] - 2026-06-28`, `DefaultTerminalManager`, `StatusLineView.swift`, `SGRMouseEvent`, `WindowSession`, `[2.5.0] - 2026-06-12`, `SyntaxTextView`, `.run`, `BlockTintOverlay`, `renumberWindows`, `.menu`, `TerminalScrollbarView`, `.rememberTabForReopen`, `FormatColor`, `click_ui_element`, `AgentHookStrategy`, `StatusLineWidthTests`, `Process`, `JSONDecoder`, `Fixes Applied (layered)`, `GitHubCLIClient`, `.handleCat`, `NotificationBus`, `settings.json`, `PaneNode`, `HarnessPaths.swift`, `.parse`, `.script`, `.scrollWheel`, `Send Ex Command`, `Bug: Tab-Switch Black Screen`, `AgentSnapshot`, `Terminal AI Chat (⌘I inline overlay)`, `Focus Persistence — Per-Session-Tab Pane Focus (RL-043)`, `UInt64`, `DesktopNotifier`, `LayoutNode`, `WorkspaceSymbolIndex`, `worktree_isolation.robot`, `.theme`, `ImmersivePalette.swift`, `.drawGlyph`, `.recordReapedGenerationForTesting`, `ImageProtocolTests.swift`, `.makeModel`, `CommandExecutionError`, `Foundation`, `[2.2.3] - 2026-06-09`, `Background Polling & Snapshot Fanout — P22`, `Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)`, `.handleCat`, `FormatStyledSegment.swift`, `projectGroupRootPath`, `[2.2.4] - 2026-06-11`, `generate-cheatsheet.js`, `Consumers`, `DaemonStats`, `Fixes Applied (v3.9.1+)`, `Git Panel`, `BinaryRefresherTests`, `.consumeInputCore`, `.tabIndex(tabID:)`, `Identifiable`, `PromptQueueBar`, `SurfaceProgressTrackerTests.swift`, `.status`, `NSTextField Leak in BoardViewController (P20 Performance)`, `User Profile`, `HarnessCLITests`, `AppKit + Metal Patterns`, `.load`, `AgentIconRenderer`, `main.swift`, `IPC Architecture`, `Session/Tab/Pane Hierarchy & Top Bar (CASE-028)`, `yaml.json`, `HintModeOverlay`, `.parseDiffHunks`, `PathToken`, `Project History`, `.highlight`, `Feature Specs`, `SessionEditor`, `main.swift`, `Section`, `WorkspaceSwitcherPanelView`, `.deleteWorkspaceFromMenu`, `HarnessOnboarding`, `Added`, `ScrollbackTests`, `Command Prompt Architecture`, `[3.10.1] - 2026-06-27`, `printThemePreview`, `Added`, `requireSessionID`, `resolvedCLIPath`, `.json`, `graphify reference: extra exports and benchmark`, `.panePathLookup`?**
  _High betweenness centrality (0.266) - this node is a cross-community bridge._
- **Why does `KouenCore` connect `PaneLabelDaemonTests` to `CodingKey`, `.handleNormal`, `IPCRequest`, `AgentNotchRootView`, `Command`, `KouenIPC`, `PerformanceBenchmarks`, `KittyKeyboardTests`, `HarnessTerminalSurfaceView`, `MetalRendererTests`, `HarnessUILibrary`, `SpecialKey`, `.text`, `CopyModeAction`, `.request`, `SessionGroupHeaderRowView`, `install-app.sh`, `SemanticPromptTests`, `Task Ledger Archive (Tasks 1–50)`, `Equatable`, `LegacySnapshot`, `NSObject`, `String`, `Fixed`, `[3.12.0] - 2026-06-30`, `CodingKeys`, `RenderSchedulerTests`, `HarnessTerminalSurfaceView.swift`, `.buildCommand`, `.normalizedKey`, `HookEvent`, `DaemonServer`, `ScrollbackPersistenceTests`, `.keyEvent`, `Harness Robot Framework Tests`, `.handleWake`, `NSPanel`, `BellScanState`, `CommandHistorySearchController`, `HarnessCLI+Server.swift`, `.text`, `TerminalProgressReport`, `DecoKind`, `.compose`, `worktree_isolation_cli.robot`, `XCTestCase`, `.detect`, `.statusLineSet`, `LayoutTemplate`, `.parse`, `TerminalProtocolCompatibilityTests`, `Endpoint`, `HarnessDesign`, `KouenCLITests.swift`, `shim.c`, `LSPClient`, `LSPDiagnostic`, `.highlightedTitle`, `SessionCoordinator`, `MenuBarController`, `AttachInputBatcher`, `shim.c`, `.testRenderEncodeIncrementalDamage160x48`, `PaneContainerView`, `.dispatch`, `Changelog`, `AgentNotchViewModel`, `NSView`, `ViEngine`, `SoftIconButton`, `DamageTrackingTests`, `.makeSnapshot`, `.resolve`, `.firstWaitingTab`, `.encode`, `clearSelection`, `PaneNode`, `WorkspaceFileTreeView`, `SessionGroup`, `ViEngine`, `Pipe`, `String`, `.install`, `.load`, `stability_release.robot`, `PtyDrainCeilingBenchmark`, `Added`, `ActivePaneService`, `.testPaneLeafLegacyDecodeBackfillsSurfaceTabs`, `DecodedImage`, `MCPServer`, `FileTreeWatcher`, `EnvironmentStore`, `.feedBuffer`, `New Tab`, `What You Must Do When Invoked`, `PathToken`, `ThaiCombiningMarkTests`, `[3.8.0] - 2026-06-22`, `MatchCategory`, `sessionCreated`, `ThaiClusterCopyTests.swift`, `ReflowCorpusTests`, `.decodeKeySpec`, `.status`, `RGBColorTests`, `.rects`, `InlineAICompletionView`, `GridCompositorTests`, `P25 — iOS/iPadOS Support`, `AppDelegate`, `ScriptRuntime`, `[2.3.0] - 2026-06-11`, `Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag`, `[2.5.1] - 2026-06-12`, `[3.4.0] - 2026-06-19`, `BinaryInstaller`, `MainWindowController`, `.classify`, `BinaryInstallerVersionTests`, `MCP Server (harness-mcp)`, `PaletteModel`, `FileTabManager`, `AutomationScheduler`, `CopyModeState`, `scheduleRender`, `.printBoard`, `PaneDropZoneOverlay`, `NotchLayoutMetrics`, `.lines`, `CellColorResolverTests`, `GridCompositor`, `Section`, `AgentNotchRowSummary`, `ANSIPalette`, `HarnessPathDisplay`, `SSHTunnelManagerTests`, `sessionRow`, `.hitTest`, `graphify reference: incremental update and cluster-only`, `TerminalGridCellLayoutTests`, `p11_scripting.robot`, `.scan`, `WorkbenchCommand`, `.make`, `AgentBridge`, `.make`, `ThemeDocumentTests`, `.renderFixture`, `DaemonMetrics`, `ReflowPreviewTests`, `[3.4.0] - 2026-06-19`, `HarnessTerminalSurfaceWorkerTests`, `Split Right`, `BoardViewController`, `Sidebar SwiftUI Migration — Knowledge`, `.welcome`, `Browser Pane (P14)`, `.install`, `KeySpec`, `[2.5.0] - 2026-06-12`, `SyntaxTextView`, `reorderSession`, `CLICommand`, `DisplayPanesOverlay`, `.menu`, `TerminalScrollbarView`, `.apply`, `.handleCat`, `.load`, `jobs`, `ThemeDiagnostics`, `.encodeMouse`, `ViPathTokenTests`, `Send Ex Command`, `.selectedText`, `Terminal AI Chat (⌘I inline overlay)`, `FormatColor`, `UInt64`, `GroupedSessionDaemonTests`, `worktree_isolation.robot`, `.theme`, `CommandExecutionError`, `CSIParams`, `Foundation`, `DaemonLifecycleTests`, `Background Polling & Snapshot Fanout — P22`, `Architecture Decisions — harness-terminal`, `Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)`, `GPU Animation Pattern — Layout Once, GPU Paints`, `MCPServer`, `SurfaceProgressTracker`, `.handleCat`, `[3.5.1] - 2026-06-20`, `State`, `FormatStyledSegment.swift`, `RGBColor`, `Fixes Applied (v3.9.1+)`, `Consumers`, `SurfaceRegistryTests.swift`, `Tab`, `.encode`, `DynamicInstanceBuffer`, `.install`, `Identifiable`, `ThaiClusterRenderTests`, `NSTextField Leak in BoardViewController (P20 Performance)`, `SKILL-LOG.md`, `User Profile`, `UI Automation — Robot Framework (P18)`, `themes.json`, `main.swift`, `IPC Architecture`, `HintModeOverlay`, `LaunchdServiceInstaller`, `WaitForRegistry`, `ThaiClusterCopyTests.swift`, `RawRepresentable`, `BlockContextMenuTests`, `Section`, `.json`, `WorkspaceSwitcherPanelView`, `ReflowFastPathTests`, `HarnessOnboarding`, `.steps`, `Added`, `Changed`, `Browser Tab Close Button Unresponsive`, `terminal-cheat-sheet.html`, `generate-release-notes.swift`, `.json`, `ACP Client (Shelved)`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Why does `DaemonClient` connect `.text` to `Sidebar SwiftUI Migration — Knowledge`, `ThemeFileServiceTests`, `EngineConformanceTests`, `Command`, `WindowSession`, `DecodedImage`, `HarnessUILibrary`, `FileTreeWatcher`, `EnvironmentStore`, `Split Panes (NSSplitView)`, `.request`, `TerminalScrollbarView`, `.prunePastedImages`, `AgentVectorIcon`, `TerminalColorGamut`, `NotificationBus`, `CodingKeys`, `.decodeKeySpec`, `HarnessTerminalSurfaceView.swift`, `BinaryRefresherTests`, `Harness Robot Framework Tests`, `Added`, `.handleWake`, `BinaryInstaller`, `.handleListHooks`, `.statusLineSet`, `.testCloseEphemeralSessionsKeepsPinnedTabClosesSibling`, `LayoutTemplate`, `.highlightedTitle`, `NotchLayoutMetrics`, `Zombie View Crashes on macOS 26.5 + Swift 6.3.2`, `ANSIPalette`, `.testPingMutationAndSnapshotRoundTrip`, `SSHTunnelManagerTests`, `Git Panel`, `FileNode`, `ThemeDocumentTests`, `Fixed`, `.install`, `PromptQueue`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Are the 48 inferred relationships involving `Int` (e.g. with `.register()` and `.startStallMonitor()`) actually correct?**
  _`Int` has 48 INFERRED edges - model-reasoned connections that need verification._
- **What connects `AppIntents`, `noActivePane`, `horizontal` to the rest of the system?**
  _4049 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CodingKey` be split into smaller, more focused modules?**
  _Cohesion score 0.10984848484848485 - nodes in this community are weakly interconnected._
- **Should `EngineConformanceTests` be split into smaller, more focused modules?**
  _Cohesion score 0.1211840888066605 - nodes in this community are weakly interconnected._