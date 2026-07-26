# Graph Report - kouen-terminal  (2026-07-26)

## Corpus Check
- 807 files · ~842,033 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 15548 nodes · 34861 edges · 3363 communities (972 shown, 2391 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 3858 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `fa8a08cf`
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
1. `IPCRequest` - bridges 158 areas (177 edges)
2. `Command` - bridges 101 areas (107 edges)
3. `IPCResponse` - bridges 65 areas (85 edges)
4. `SessionCoordinator` - bridges 60 areas (127 edges)
5. `MenuTarget` - bridges 56 areas (62 edges)
6. `SurfaceRegistry` - bridges 52 areas (183 edges)
7. `KouenPaths` - bridges 52 areas (111 edges)
8. `SpecialKey` - bridges 52 areas (56 edges)
9. `EngineConformanceTests` - bridges 50 areas (76 edges)
10. `AgentKind` - bridges 49 areas (98 edges)

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

## Communities (3363 total, 2391 thin omitted)

### Community 0 - "CodingKey"
Cohesion: 0.08
Nodes (15): tab, .tab(for:), Command, string, PanePipe, SurfaceRegistry, .subscribe(surfaceID:handler:), Bool (+7 more)

### Community 1 - "callingPaneTarget"
Cohesion: 0.07
Nodes (24): CGImage, DisplayWidth, String, Unicode, Run, Data, ReleaseNotes, String (+16 more)

### Community 2 - ".handleNormal"
Cohesion: 0.20
Nodes (7): Recipe, RecipesStore, Bool, String, URL, UUID, RecipesStoreTests

### Community 4 - "EngineConformanceTests"
Cohesion: 0.11
Nodes (10): DaemonRoundTripTests, Data, Int32, String, TimeInterval, RealPtyLifecycleTests, AtomicCounter, OutputAccumulator (+2 more)

### Community 5 - "IPCRequest"
Cohesion: 0.09
Nodes (23): String, UInt16, DecodedReplyFrame, output, reply, DecodedRequestFrame, input, request (+15 more)

### Community 6 - "AgentNotchRootView"
Cohesion: 0.08
Nodes (24): AnyTransition, AnyView, AgentNotchPeekEvent, Reason, errored, finished, needsInput, RowState (+16 more)

### Community 7 - "Command"
Cohesion: 0.30
Nodes (9): .encode(text:shifted:modifiers:event:associatedText:modes:), KeyEventType, press, release, `repeat`, KeyModifiers, Character, String (+1 more)

### Community 8 - "LSPMessage"
Cohesion: 0.09
Nodes (12): .addSurface(tabID:paneID:), .tab(containingPaneID:), .tab(forSurfaceKey:), .tabIndex(surfaceKey:), .tabIndex(workspaceID:tabID:), Date, SessionID, String (+4 more)

### Community 9 - "TerminalEmulator"
Cohesion: 0.12
Nodes (12): colors, PerformanceBenchmarks, SurfaceMainThreadStallSample, SurfaceOffMainStallSample, Bool, Data, Double, String (+4 more)

### Community 10 - "PerformanceBenchmarks"
Cohesion: 0.15
Nodes (10): CommandPromptController, KeyablePanel, Bool, NSControl, NSPanel, NSTextView, Selector, String (+2 more)

### Community 11 - "GitPanelView.swift"
Cohesion: 0.11
Nodes (10): SessionCoordinator, .syncFromDaemon(metadataOnly:), Bool, PaneNode, SessionID, SplitDirection, String, SurfaceID (+2 more)

### Community 13 - "KittyKeyboardTests"
Cohesion: 0.08
Nodes (18): KeyRecorderView, .init(coder:), .init(initial:), Any, Bool, NSCoder, NSEvent, NSPoint (+10 more)

### Community 14 - "VTParser"
Cohesion: 0.08
Nodes (24): State, csiEntry, csiIgnore, csiIntermediate, csiParam, escape, escapeIntermediate, ground (+16 more)

### Community 15 - "HarnessTerminalSurfaceView"
Cohesion: 0.26
Nodes (6): Bool, Character, NSRange, NSTextView, String, ViEngine

### Community 16 - ".applyPreedit"
Cohesion: 0.29
Nodes (7): Bool, NSRange, NSString, NSTextView, String, unichar, ViEngine

### Community 17 - "MetalRendererTests"
Cohesion: 0.15
Nodes (8): ScrollbackFile, Bool, Data, DispatchWorkItem, URL, ScrollbackFileTests, String, URL

### Community 18 - "HarnessUILibrary"
Cohesion: 0.11
Nodes (26): DaemonSubscription, .start(onData:onEnd:buffered:), .start(onResponse:onEnd:), Bool, Data, Int32, TimeInterval, UInt64 (+18 more)

### Community 19 - "SpecialKey"
Cohesion: 0.13
Nodes (19): Equatable, CodingKeys, error, id, jsonrpc, method, params, result (+11 more)

### Community 21 - "HarnessTerminalSurfaceView"
Cohesion: 0.09
Nodes (18): KouenTerminalSurfaceView, Any, Bool, CGFloat, NSDraggingInfo, NSDragOperation, NSEvent, NSMenu (+10 more)

### Community 22 - "CopyModeAction"
Cohesion: 0.22
Nodes (6): Bool, NSString, NSTextView, String, unichar, ViEngine

### Community 23 - "SplitPaneCoordinator"
Cohesion: 0.13
Nodes (17): OptionStore, OptionStore.Value, Scope, pane, session, workspace, ScopedKey, Bool (+9 more)

### Community 24 - ".request"
Cohesion: 0.19
Nodes (4): KouenCLI, Bool, String, UUID

### Community 25 - "WorktreeManager"
Cohesion: 0.17
Nodes (3): KouenSidebarPanelViewController, String, SessionSnapshot

### Community 26 - "Harness tmux-style capabilities"
Cohesion: 0.06
Nodes (37): 10. Status line, mouse, and options, 11. Shell integration, 12. Agent notifications, 13. Out-of-box troubleshooting, 14. One-page cheat sheet, 1. Five-minute setup, 2. Mental model, 3. Prefix key (+29 more)

### Community 27 - "RGBColor"
Cohesion: 0.15
Nodes (5): RenderScheduler, Bool, Void, RenderSchedulerTests, Bool

### Community 28 - ".parse"
Cohesion: 0.14
Nodes (6): PrefixKeymap, Any, Bool, NSEvent, TimeInterval, PrefixKeymapFallbackTests

### Community 30 - "Notification"
Cohesion: 0.12
Nodes (9): Bool, Data, String, UInt8, UnsafeBufferPointer, TerminalEmulator, .captureLines(fromLine:toLine:), .captureLines(joinWrapped:) (+1 more)

### Community 32 - ".addTab"
Cohesion: 0.15
Nodes (8): KouenTerminalSurfaceView, CGFloat, CGRect, NSEvent, NSPoint, Range, String, UInt16

### Community 33 - "Equatable"
Cohesion: 0.14
Nodes (11): DisplayMessage, MainExecutor, RunShell, Bool, Command, MainActor, PaneID, PaneNode (+3 more)

### Community 34 - "DaemonClient"
Cohesion: 0.17
Nodes (9): LSPServerConfiguration, LSPServerRegistry, LSPSettings, Bool, String, URL, LSPServerRegistryTests, String (+1 more)

### Community 35 - "MenuTarget"
Cohesion: 0.07
Nodes (16): Range, String, TerminalGridCell, TerminalBufferMatch, TerminalBufferSearch, String, TerminalGridCell, TextGrid (+8 more)

### Community 37 - "String"
Cohesion: 0.07
Nodes (23): DragDiagnostics, DispatchSourceTimer, String, PaneDragController, Any, Bool, NSEvent, NSView (+15 more)

### Community 39 - "TerminalColorGamut"
Cohesion: 0.21
Nodes (8): ConnectionState, ErrorAck, MobileBridgeServer, Data, NWConnection, T, UInt8, UUID

### Community 40 - "HarnessSettings"
Cohesion: 0.19
Nodes (7): BrowserPaneView, .init(url:paneID:webView:), NSStackView, NSTextField, Selector, String, URL

### Community 41 - "CodingKeys"
Cohesion: 0.08
Nodes (29): ClientRecord, CountBox, DaemonError, alreadyRunning, bindFailed, listenFailed, socketFailed, DaemonServer (+21 more)

### Community 42 - "HarnessSidebarPanelViewController.swift"
Cohesion: 0.21
Nodes (12): CommandParseError, emptyInput, expectedCommand, invalidArgument, missingArgument, missingFlag, unknownCommand, unterminatedString (+4 more)

### Community 43 - "RenderSchedulerTests"
Cohesion: 0.16
Nodes (10): GitStatusType, added, deleted, modified, renamed, unmodified, untracked, GitStatusProvider (+2 more)

### Community 44 - "HarnessOverlayBackground"
Cohesion: 0.13
Nodes (22): CursorRender, CursorStyle, bar, block, underline, .init(resolver:cursorColor:cursorTextColor:canvasOpacity:colorRendering:colorGamut:cursorStyle:selectionBackground:selectionForeground:searchBackground:searchForeground:promptGutterEnabled:), .init(theme:boldBrightens:canvasOpacity:colorRendering:colorGamut:cursorStyle:selectionBackground:selectionForeground:searchBackground:searchForeground:promptGutterEnabled:), .renderColor(_:alpha:) (+14 more)

### Community 45 - "HarnessTerminalSurfaceView.swift"
Cohesion: 0.17
Nodes (5): TimeInterval, SSHTunnelManagerTests, RemoteHost, String, URL

### Community 46 - ".buildCommand"
Cohesion: 0.08
Nodes (25): Endpoint, EndpointError, connectionFailed, notYetSupported, pathTooLong, String, EndpointConnector, Int32 (+17 more)

### Community 47 - ".normalizedKey"
Cohesion: 0.11
Nodes (13): Array, GroupHeaderRow, PickerItemRow, RecipePanel, RecipePickerController, RecipePickerFooter, RecipePickerView, RecipeWindowDelegate (+5 more)

### Community 48 - "HookEvent"
Cohesion: 0.13
Nodes (14): Executor, Hook, HookEvent, HookRegistry, Bool, Command, URL, UUID (+6 more)

### Community 49 - "DaemonServer"
Cohesion: 0.14
Nodes (5): CommandIPCTranslatorTests, Bool, CommandTarget, PaneID, TabID

### Community 51 - ".keyEvent"
Cohesion: 0.12
Nodes (23): CopyModeMatch, ColorKind, bg, fg, underline, CompositorPane, GridCompositor, .render(panes:status:statusSegments:) (+15 more)

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
Cohesion: 0.15
Nodes (3): NWEndpoint, NWListener, UInt16

### Community 61 - "FrecencyDirectoryStore"
Cohesion: 0.13
Nodes (21): ColorKind, bg, fg, underline, ComposedCell, .init(_:), .init(codepoint:fg:bg:underlineColor:bold:dim:italic:underline:blink:inverse:invisible:strikethrough:overline:), CompositorPane (+13 more)

### Community 62 - "ComposedCell"
Cohesion: 0.12
Nodes (10): surfaceID, SessionEditor, .surfaceID(forPaneID:), Command, Tab, SessionEditorPhase4Tests, PaneID, TabID (+2 more)

### Community 63 - "HarnessCLI+Server.swift"
Cohesion: 0.15
Nodes (10): Buffer, Configuration, PasteBufferStore, Bool, Data, Date, String, URL (+2 more)

### Community 64 - ".text"
Cohesion: 0.12
Nodes (12): Int, TerminalGridSnapshot, .readGrid(scrollbackOffset:), SemanticMark, HistoryLine, ImagePlacement, RewrapResult, Bool (+4 more)

### Community 65 - "PrefixKeymap"
Cohesion: 0.10
Nodes (10): KouenTerminalSurfaceView, Bool, CAMetalDrawable, NSEvent, RGBColor, String, KouenTerminalSurfaceView, CGFloat (+2 more)

### Community 66 - "ShellIntegration"
Cohesion: 0.13
Nodes (7): KouenThemeCatalog, String, KouenThemeDefinition, Bool, RGBColor, String, KouenThemeCatalogTests

### Community 67 - "String"
Cohesion: 0.17
Nodes (8): AgentHookInstaller, InstallResult, Any, Bool, Data, String, URL, AgentKind

### Community 69 - ".compose"
Cohesion: 0.10
Nodes (6): ClosedRange, Range, TerminalCellWidth, UnsafeBufferPointer, TerminalScreen, .markRowsDirty(_:)

### Community 70 - "worktree_isolation_cli.robot"
Cohesion: 0.20
Nodes (9): Group, ParsedShortcut, PrefixCheatsheetWindow, PrefixIndicatorWindow, CGFloat, NSTextField, NSView, NSWindow (+1 more)

### Community 71 - "ImportedTerminalConfig"
Cohesion: 0.10
Nodes (13): KouenUILibrary, Type a string of text into the focused element via osascript keystroke., Get cols x rows from active terminal via stty., Send raw keys to active terminal surface., Send :ex command via CLI., Hover over tab pill at given index (AppleScript)., Click the Sync/Fetch button in Git panel., Launch Kouen app. env: 'preview' (debug) or 'staging' (release+isolated). (+5 more)

### Community 72 - "XCTestCase"
Cohesion: 0.07
Nodes (22): CornerInfo, KouenSplitView, .init(coder:), PaneDragGripView, .init(coder:), .init(paneID:), PaneHoverButton, PaneSplitButtonsView (+14 more)

### Community 73 - "README.md"
Cohesion: 0.08
Nodes (17): Codex → Kouen, One-line install, What you'll see, Cursor Agent → Kouen, Manual fallback, One-line install, What you'll see, Hermes → Kouen (+9 more)

### Community 75 - "OptionStore"
Cohesion: 0.11
Nodes (16): CaseIterable, ExperienceMode, agent, full, persistent, plain, Bool, ResizeOverlayMode (+8 more)

### Community 76 - ".parse"
Cohesion: 0.16
Nodes (12): PaneListRow, SessionListRow, SnapshotQueryFormatter, Bool, SessionGroup, SessionSnapshot, String, Tab (+4 more)

### Community 77 - "TerminalProtocolCompatibilityTests"
Cohesion: 0.17
Nodes (4): SessionSnapshot, String, UUID, TargetSpecTests

### Community 79 - "HarnessDesign"
Cohesion: 0.22
Nodes (6): .init(url:paneID:), WKWebView, WeakScriptMessageHandler, WKScriptMessage, WKScriptMessageHandler, WKUserContentController

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
Cohesion: 0.09
Nodes (21): LSPClient, LSPClientError, missingPipe, processNotRunning, serverNotExecutable, Int32, String, Task (+13 more)

### Community 84 - "LSPDiagnostic"
Cohesion: 0.15
Nodes (14): SplitPaneCoordinator, .surfaceID(forPane:in:), .surfaceID(forPaneID:in:), Bool, PaneID, PaneNode, SessionCoordinator, SessionID (+6 more)

### Community 85 - "TerminalGridCell"
Cohesion: 0.09
Nodes (18): requestFailed, FileHandle, LSPMessage, notification, request, response, Decoder, Encoder (+10 more)

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
Cohesion: 0.13
Nodes (6): hooks, AgentHookInstallerTests, String, URL, GitHubCLIClientTests, String

### Community 90 - "Zombie View Crashes on macOS 26.5 + Swift 6.3.2"
Cohesion: 0.12
Nodes (14): Set, DaemonContentionTests, String, URL, SurfaceRegistryTests, .firstSurfaceID(for:in:), .firstSurfaceID(forSession:in:), PaneID (+6 more)

### Community 91 - "TerminalModes"
Cohesion: 0.11
Nodes (5): ContentAreaViewController, Bool, String, TabID, Notification

### Community 92 - "P2 — Async IPC Refactor: Design Document"
Cohesion: 0.08
Nodes (25): code:swift (// DaemonSessionService.swift), code:swift (// ต้องคงเป็น sync เพราะเรียกก่อน process exit), code:swift (// ปัจจุบัน: DispatchQueue.global + DispatchQueue.main.async), code:text (1. DaemonClientActor (new file, ไม่ break อะไร)), code:text (Before:), code:swift (// DaemonClientActor.swift (new)), code:swift (func fetchSnapshot() async throws -> SessionSnapshot {), code:swift (// Packages/HarnessCore/Sources/HarnessCore/IPC/DaemonClient) (+17 more)

### Community 94 - "AttachInputBatcher"
Cohesion: 0.20
Nodes (8): C, AttachInputBatcher, Outcome, Bool, Data, UInt8, AttachInputBatcherTests, UInt8

### Community 95 - "shim.c"
Cohesion: 0.13
Nodes (14): DirectoryItemRow, DirectoryPanel, DirectoryPickerController, DirectoryPickerFooter, DirectoryPickerModel, DirectoryPickerView, DirectoryWindowDelegate, String (+6 more)

### Community 96 - "Harness Usage"
Cohesion: 0.17
Nodes (12): 1. Install Kouen, 2. Install The CLI On PATH, 3. Pick An Experience Mode, 4. Agent Notifications, 5. Recommended Shell Tools, 6. Troubleshooting, Kouen Usage, More Docs (+4 more)

### Community 97 - "PaneContainerView"
Cohesion: 0.13
Nodes (16): SessionSnapshot, PendingVersionBanner, welcome, whatsNew, State, Bool, String, URL (+8 more)

### Community 98 - "4. Technical Architecture"
Cohesion: 0.67
Nodes (3): 4.1 Architecture Pattern, 4. Technical Architecture, 4.2 Technology Stack

### Community 99 - ".dispatch"
Cohesion: 0.17
Nodes (18): TerminalColorGamut, auto, displayP3, sRGB, TerminalColorRenderingMode, accurate, vivid, RenderColor (+10 more)

### Community 100 - "ScriptRuntime.swift"
Cohesion: 0.30
Nodes (12): Decodable, AISuggestRequest, AttachFileRequest, BrowserInteractRequest, BrowserNavigateRequest, ControlMessage, DeviceAuth, DeviceAuthEnvelope (+4 more)

### Community 101 - "Session Grouping and Split Session Plan"
Cohesion: 0.10
Nodes (20): 1. Add Project Group Heuristics, 1. Keep Split State In Session/Tab Structure, 2. Introduce Sidebar Row Model, 2. UX Entry Points, 3. Build Grouped Rows From Filtered Sessions, 4. Update Table Data Source and Delegate, 5. Drag and Drop Rules, code:text (Window) (+12 more)

### Community 102 - "DaemonLauncher"
Cohesion: 0.10
Nodes (21): CopyModeSearch, CopyModeSelectionMode, block, char, line, none, CopyModeSideEffect, beginSearchEntry (+13 more)

### Community 104 - "Recipe"
Cohesion: 0.10
Nodes (25): Bool, UInt8, TerminalCellWidth, normal, spacerTail, wide, TerminalCursor, TerminalCursorShape (+17 more)

### Community 105 - "Changelog"
Cohesion: 0.17
Nodes (8): AgentListFormatter, Date, String, cols, AgentListFormatterTests, Bool, Date, String

### Community 107 - "AgentNotchViewModel"
Cohesion: 0.10
Nodes (17): BoxDrawing, Kind, arms, dashH, dashV, halfDown, halfLeft, halfRight (+9 more)

### Community 108 - ".resolve"
Cohesion: 0.10
Nodes (14): KouenCLITests, URL, KouenCLI, String, String, KouenCLI, KouenFilePreviewLoader, KouenViewError (+6 more)

### Community 109 - "DamageTrackingTests"
Cohesion: 0.13
Nodes (9): SGRMouse, SGRMouseEvent, Bool, PaneRect, S, UInt8, SGRMouseTests, String (+1 more)

### Community 110 - "SoftIconButton"
Cohesion: 0.19
Nodes (5): CopyModeReducerTests, FakeGrid, Set, String, TerminalGridCell

### Community 112 - ".makeSnapshot"
Cohesion: 0.16
Nodes (14): IndexingIterator, LayoutTemplate, .addSurface(to:paneID:surfaceID:cwd:), .split(node:targetPaneID:direction:paneCount:before:), .split(node:targetPaneID:with:direction:beforeTarget:), .surfaceID(forPaneID:in:), .tabIndex(surfaceID:), Bool (+6 more)

### Community 113 - "HarnessGridTerminal"
Cohesion: 0.17
Nodes (14): KouenSettings, .init(fontSize:fontFamily:defaultShell:defaultCWD:transparentTitlebar:sidebarVisible:sidebarOnRight:sidebarCollapsedOnLaunch:restoreWindowSize:backgroundOpacity:backgroundBlur:windowPaddingX:windowPaddingY:customBackgroundHex:customForegroundHex:customCursorHex:importedConfigSignature:prefixKey:scrollbackLines:cursorStyle:cursorBlink:copyOnSelect:selectionBackgroundHex:selectionForegroundHex:boldColorHex:cursorTextHex:paletteHex:agentColorOverrides:dividerHex:statusLineHex:windowBorderHex:windowBorderOpacity:systemNotificationsEnabled:notificationSoundEnabled:notchVisibilityMode:notchOpenOnHover:colorRendering:colorGamut:textRendering:vividColors:linearBlending:applyThemeToTerminalOutput:ligatures:offMainParserFramePipeline:liveResizeReflow:mobileBridgeEnabled:showPromptGutter:showStatusLine:experienceMode:kouenControlsEnabled:prefixKeyEnabled:statusLineEnabled:resizeOverlay:resizeOverlayPosition:windowPaddingBalance:minimumContrast:lightThemeName:darkThemeName:lightThemeOpacity:darkThemeOpacity:pasteProtection:commandFinishedThresholdSeconds:notificationEvents:boldIsBright:lspAutoStart:lspServers:fileClickAction:claudeAPIKey:inlineAICompletion:terminalShaderEffect:browserHomePage:), .init(from:), ResizeOverlayPosition, bottomRight, center, topRight, Decoder (+6 more)

### Community 114 - ".firstWaitingTab"
Cohesion: 0.17
Nodes (7): ImportedTerminalConfig, Bool, Double, Float, String, TerminalConfigImporter, TerminalConfigImporterTests

### Community 115 - ".encode"
Cohesion: 0.13
Nodes (11): ActivePaneService, .surfaceID(forPane:in:), .surfaceID(forPaneID:in:), Bool, PaneID, PaneNode, SessionCoordinator, Set (+3 more)

### Community 116 - "SessionGroup"
Cohesion: 0.09
Nodes (20): DaemonSyncService, .logIfFailed(_:), .request(_:), .sync(metadataOnly:), Bool, Never, SessionCoordinator, SessionSnapshot (+12 more)

### Community 117 - "PaneNode"
Cohesion: 0.11
Nodes (10): NotificationCoordinator, Bool, Date, SessionCoordinator, SessionSnapshot, Set, String, SurfaceID (+2 more)

### Community 118 - "WorkspaceFileTreeView"
Cohesion: 0.10
Nodes (13): ActiveTabCloseDisposition, session, tab, window, workspace, CloseConfirmationCopy, SessionLifecycleService, NSWindow (+5 more)

### Community 119 - "Harness command reference"
Cohesion: 0.12
Nodes (16): Attaching from a plain terminal, Bindings, Buffers (paste store), Composition, Hooks, Inspection (CLI / control mode), Kouen command reference, Local diagnostics (+8 more)

### Community 122 - "ViEngine"
Cohesion: 0.09
Nodes (19): .init(coder:), .init(frame:), HunkActionButton, .init(coder:), .init(title:onClick:), RepoEntry, StageToggleButton, .init(coder:) (+11 more)

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
Cohesion: 0.11
Nodes (21): AtlasEntry, ClusterGlyphKey, GlyphAtlas, .entry(for:), .entry(forCluster:bold:italic:), .entry(forShaped:font:), GlyphAtlasStats, GlyphKey (+13 more)

### Community 129 - "SwiftUI"
Cohesion: 0.17
Nodes (9): EditorDividerView, CGFloat, NSLayoutConstraint, FilePreviewCoordinator, FileTabID, NSView, Set, SplitDirection (+1 more)

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
Cohesion: 0.18
Nodes (5): SessionPersistenceTests, Bool, String, TabID, URL

### Community 135 - "CommandTarget"
Cohesion: 0.12
Nodes (4): .encode(text:modifiers:modes:), KittyKeyboardTests, String, UInt8

### Community 136 - ".startWatching"
Cohesion: 0.19
Nodes (20): Codable, BrowserCookie, BrowserElement, BrowserElementBounds, BrowserNetworkEntry, BrowserSnapshot, BufferSummary, HookEntry (+12 more)

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
Cohesion: 0.16
Nodes (8): DaemonClientActor, TimeInterval, KouenBrowserTools, Bool, Double, String, TimeInterval, .init(client:subscriptionClient:isToolAllowed:disabledError:)

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
Nodes (34): Bool, String, UUID, TaskDaemonBridge, CGFloat, NSCoder, SessionID, String (+26 more)

### Community 147 - "FileTreeWatcher"
Cohesion: 0.14
Nodes (15): CLIInstallLocator, DetachKeys, absent, invalid, parsed, KouenCLI, OptionalUUID, absent (+7 more)

### Community 148 - "TriState"
Cohesion: 0.11
Nodes (18): Architecture, Browser Auto-Retry (P24 Phase 4), Browser Pane (P14), BUG: Tab close button never fired (CASE-055 extended), BUG: Tab close button unresponsive (gesture conflict), CASE: applyLocalSnapshot re-injected closed browser panes (v2.7.1), CASE: collapsed errorBanner intercepted toolbar clicks (v2.7.1), CASE: Google/Apple OAuth blocked by default WKWebView user agent (2026-07-10) (+10 more)

### Community 149 - "EnvironmentStore"
Cohesion: 0.17
Nodes (9): DaemonLauncher, Bool, Double, Int32, MainActor, String, TimeInterval, UInt16 (+1 more)

### Community 150 - "HarnessDaemonToolsTests"
Cohesion: 0.15
Nodes (9): KouenDaemonToolsTests, String, URL, Document, Bool, Set, String, URL (+1 more)

### Community 151 - ".evaluate"
Cohesion: 0.15
Nodes (7): FileManager, String, URL, ThemeFileService, String, URL, ThemeFileServiceTests

### Community 154 - "LiveResizeTests"
Cohesion: 0.14
Nodes (13): KouenGridTerminal, .captureLines(fromLine:toLine:), .captureLines(joinWrapped:), .feed(_:), .readGrid(scrollbackOffset:), Bool, Data, String (+5 more)

### Community 155 - "Int"
Cohesion: 0.14
Nodes (11): FileFuzzyMatcher, FuzzyPathResolution, ambiguous, none, unique, FuzzyPathResolver, Bool, Character (+3 more)

### Community 156 - "ThaiCombiningMarkTests"
Cohesion: 0.21
Nodes (7): NotificationDropdownPanelView, .init(entries:onSelect:onClearAll:onDismiss:), Bool, CGFloat, NSScrollView, NSViewCornerConfiguration, Void

### Community 158 - "Harness Terminal — IDE Sidebar Feature Branch"
Cohesion: 0.12
Nodes (15): Architecture, Branch, Build & Preview, CMUX Pane Splitting, code:block1 (worktree-feature+acp-aidlc), code:bash (cd /tmp/hp  # symlink to worktree (socket path length limit)), code:block3 (HarnessSidebarPanelViewController — Sessions / Files / Git t), Features (+7 more)

### Community 159 - "MatchCategory"
Cohesion: 0.20
Nodes (10): DaemonClient, KouenCLI, String, KouenCLI, SessionGroup, SessionSnapshot, String, UUID (+2 more)

### Community 160 - "AmbientBackground"
Cohesion: 0.17
Nodes (17): Source, activePane, activeTab, focusedPane, focusedSurface, PaneID, PaneLeaf, PaneNode (+9 more)

### Community 161 - "What You Must Do When Invoked"
Cohesion: 0.08
Nodes (25): 10. Universal retire-hold via `removeFromSuperview()` override (definitive), 11. NSEvent local monitor installed in AppDelegate (fix #8 actually deployed), 12. `nonisolated` + `MainActor.assumeIsolated` on high-frequency AppKit callbacks (2026-06-21), 1. `TerminalPaneRegistry.retire()` — deferred dealloc (500ms), 2. Remove `nonisolated` from all layout overrides, 3. Remove `MainActor.assumeIsolated` from callbacks, 4. Detach NSHostingView on teardown (FileTreeSwiftUIView), 5. Avoid `Optional.map {}` in @MainActor code (+17 more)

### Community 162 - "TerminalFindBar"
Cohesion: 0.08
Nodes (16): NSSearchFieldDelegate, Bool, CGFloat, NSButton, NSCoder, NSControl, NSEvent, NSImage (+8 more)

### Community 163 - "Workspace"
Cohesion: 0.23
Nodes (4): Bool, String, TimeInterval, WorktreeInfo

### Community 164 - "CommandPromptController"
Cohesion: 0.14
Nodes (21): ChecksStatus, fail, none, pass, pending, CIRun, GitHubCLIClient, IssueInfo (+13 more)

### Community 165 - "ActiveTabCloseDisposition"
Cohesion: 0.21
Nodes (8): Logger, OSSignposter, FrameDropCause, encodeFailure, nilDrawable, FrameSignposter, Bool, UInt64

### Community 166 - "LiveSession"
Cohesion: 0.10
Nodes (13): AnyCancellable, NotchMaskAnimator, Bool, CGFloat, CGRect, NSView, NotchPanel, Bool (+5 more)

### Community 167 - "AgentTableEntry"
Cohesion: 0.15
Nodes (10): ChromeBackdrop, .init(role:), KouenDesign, RuntimeGlassEffectView, Bool, NSColor, NSPoint, NSSize (+2 more)

### Community 170 - "URLDetection"
Cohesion: 0.13
Nodes (5): Bool, Range, String, URLDetection, StringProtocol

### Community 171 - "ReflowCorpusTests"
Cohesion: 0.14
Nodes (15): AgentApprovalBar, .init(coder:), .init(host:prompt:kind:), ApprovalBarAction, hide, noop, show, NSColor (+7 more)

### Community 172 - ".decodeKeySpec"
Cohesion: 0.06
Nodes (24): CKouenSys, GridCompositor, pipe, termios, AttachClient, Configuration, LiveSession, Bool (+16 more)

### Community 173 - "BoardCard"
Cohesion: 0.11
Nodes (26): PaneRef, bottom, byID, byIndex, last, left, next, previous (+18 more)

### Community 174 - "BinaryRefresherTests"
Cohesion: 0.14
Nodes (6): ISO8601DateFormatter, KouenDaemonTools, .init(client:subscriptionClient:controlEnabled:), SessionSnapshot, String, UUID

### Community 175 - "RGBColorTests"
Cohesion: 0.17
Nodes (7): RemoteHost, RemoteHost, SettingsRemoteView, Bool, NSImage, RemoteHost, String

### Community 176 - "Added"
Cohesion: 0.05
Nodes (36): Never, Set, String, Task, URL, Void, WorkspaceSymbolIndex, NSRegularExpression (+28 more)

### Community 177 - ".rects"
Cohesion: 0.12
Nodes (15): StatusLineView, .init(coder:), CGFloat, FormatColor, Never, NSAttributedString, NSCoder, NSColor (+7 more)

### Community 178 - "InlineAICompletionView"
Cohesion: 0.25
Nodes (7): CopyModeGridSource, ClosedRange, CopyModeReducer, Bool, Character, Range, String

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
Cohesion: 0.04
Nodes (45): Already portable or mostly portable, Build matrix, Competitive Landscape (research 2026-07-04), Current Architecture Fit, D1: Transport model (P0 gate), D2: Renderer reuse boundary (P0 gate), D3: Local terminal support (explicitly deferred), Design: mobile session switcher (2026-07-04/05, recovered 2026-07-06) (+37 more)

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
Cohesion: 0.08
Nodes (32): ImagePlacementSnapshot, Bool, String, UInt8, TerminalCellWidth, normal, spacerTail, wide (+24 more)

### Community 187 - "AppDelegate"
Cohesion: 0.19
Nodes (10): AppDelegate, .application(_:open:), .application(_:openFiles:), QueuedExternalOpen, Bool, NSKeyValueObservation, String, URL (+2 more)

### Community 188 - "BrowserPaneView"
Cohesion: 0.19
Nodes (7): PaneStyle, PaneStyleSet, .init(window:windowActive:pane:paneActive:), Bool, FormatColor, String, PaneStyleTests

### Community 189 - "P5 — ACP (Agent Client Protocol) — Harness as ACP Editor/Client"
Cohesion: 0.12
Nodes (16): Architecture, Bounded Contexts, code:block1 (Agent Process (Claude Code / Codex / Gemini)), code:block2 (Packages/HarnessCore/Sources/HarnessCore/ACP/), code:block3 (Content-Length: 123\r\n), Estimate, Goal, Key Files (New) (+8 more)

### Community 191 - "ScriptRuntime"
Cohesion: 0.12
Nodes (10): ScriptError, evaluationError, unsupportedPlatform, ScriptRuntime, Any, String, URL, JSContext (+2 more)

### Community 192 - "GlyphRasterizer"
Cohesion: 0.08
Nodes (26): CTFontSymbolicTraits, CellMetrics, GlyphRasterizer, .rasterize(cluster:bold:italic:), .rasterize(codepoint:bold:italic:), .rasterize(glyph:font:), RasterizedGlyph, ShapedGlyph (+18 more)

### Community 193 - "BinaryInstaller"
Cohesion: 0.16
Nodes (13): UInt16, TTYSize, RecordClient, RecordingWriter, RecordSession, Summary, Bool, Data (+5 more)

### Community 194 - "Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag"
Cohesion: 0.24
Nodes (9): FileNode, Bool, String, FileTreeScanOptions, ScoredMatch, SearchMatcher, Bool, Character (+1 more)

### Community 195 - "ResizeHUDView"
Cohesion: 0.15
Nodes (11): String, Style, accent, agent, agentWorking, done, error, idle (+3 more)

### Community 196 - "Feature Provenance — harness-terminal"
Cohesion: 0.09
Nodes (20): .init(coder:), .init(frame:), .init(coder:), Kind, primary, secondary, .init(coder:), KouenPillButton (+12 more)

### Community 197 - "AgentSessionSummary"
Cohesion: 0.15
Nodes (12): FlippedView, .removeWorktreeAction(_:), NSButton, NSColor, NSRect, NSScrollView, NSStackView, NSTextField (+4 more)

### Community 198 - ".classify"
Cohesion: 0.23
Nodes (6): DoctorRunner, Bool, URL, DoctorRunnerTests, String, URL

### Community 200 - "BinaryInstallerVersionTests"
Cohesion: 0.15
Nodes (10): InstallResult, Shell, bash, fish, zsh, ShellIntegration, Bool, URL (+2 more)

### Community 201 - "MCP Server (harness-mcp)"
Cohesion: 0.14
Nodes (12): BlockSelection, FrameBuilder, .build(_:region:searchHighlights:copyModeCursor:imageProvider:reusing:damage:), SelectionRegion, block, linear, IndexSet, TerminalGridSnapshot (+4 more)

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
Cohesion: 0.18
Nodes (13): AgentIconRenderer, Scanner, SVGPathParser, Bool, CGFloat, CGPath, CGPoint, Character (+5 more)

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
Cohesion: 0.28
Nodes (6): Channel, Bool, Int32, String, WaitForRegistry, WaitForRegistryTests

### Community 212 - ".translate"
Cohesion: 0.17
Nodes (6): CwdMetadataProvider, GitMetadataProvider, MetadataProvider, String, Tab, GitMetadataProviderTests

### Community 213 - "String"
Cohesion: 0.08
Nodes (24): 1 — Process lifecycle & supervision, 2 — IPC protocol evolution, 3 — Concurrency architecture, 4 — State persistence, 5 — Render/PTY data path & the "mktemp failed" spam, 6 — Build/release pipeline, A10 (Low) — stale `@unchecked Sendable` inventory, A1 (High) — S1 daemon-reuse is undone at GUI relaunch by the build-handshake staleness check (+16 more)

### Community 214 - "NotchLayoutMetrics"
Cohesion: 0.22
Nodes (5): PaneID, BrowserPaneReuseScopeTests, PaneNode, Tab, TabID

### Community 215 - ".lines"
Cohesion: 0.13
Nodes (8): BranchSwitchHelper, FileTreeNode, FileTreeSwiftUIView, Notification.Name, Bool, NSMenuItem, SessionID, Void

### Community 216 - "CellColorResolverTests"
Cohesion: 0.16
Nodes (9): WindowInputRouterTests, KeySpecDecode, complete, incomplete, invalid, literalPrefix, UInt8, Unicode (+1 more)

### Community 217 - "GridCompositor"
Cohesion: 0.09
Nodes (27): CommandPaletteController, PaletteAction, PaletteCommandConfig, PaletteFileEntry, PaletteFooter, PaletteGrepMatch, PaletteItemRow, PaletteMode (+19 more)

### Community 218 - "ScrollbackFile"
Cohesion: 0.12
Nodes (14): DetachedPaneOverlay, .init(coder:), .init(frame:style:), Style, detached, reconnectingChip, NSCoder, NSEvent (+6 more)

### Community 219 - "Prompt"
Cohesion: 0.15
Nodes (14): code:block1 (Refactor `Tools/harness/Sources/HarnessCLI/HarnessCLI.swift`), code:block2 (Extract pure input-routing logic from `Tools/harness/Sources), code:block3, code:block4, code:block5 (Decompose `Packages/HarnessDaemon/Sources/HarnessDaemon/Surf), code:block6, code:block7, code:block8 (+6 more)

### Community 220 - "Section"
Cohesion: 0.20
Nodes (8): NotchGeometry, NSScreen, NotchLayoutMetrics, NotchRect, NotchScreenMetrics, Bool, Double, NotchLayoutMetricsTests

### Community 221 - "TerminalServicesProvider"
Cohesion: 0.07
Nodes (13): keys, DecodedImage, ImageLimits, Bool, UInt8, Data, ITerm2InlineImage, Bool (+5 more)

### Community 222 - "AgentNotchRowSummary"
Cohesion: 0.23
Nodes (7): EnvironmentStore, Persisted, String, URL, global, EnvironmentStoreTests, URL

### Community 223 - "ANSIPalette"
Cohesion: 0.15
Nodes (17): ANSIPalette, CellColorResolver, MochaTheme, ResolvedCellColors, RGBColor, .init(hex:), .init(red:green:blue:alpha:), Bool (+9 more)

### Community 224 - "CellColorResolver"
Cohesion: 0.27
Nodes (10): ANSIPalette, CellColorResolver, .init(palette:defaultForeground:defaultBackground:boldBrightens:faintFraction:minimumContrast:), .init(theme:boldBrightens:minimumContrast:), ResolvedCellColors, Bool, Double, RGBColor (+2 more)

### Community 225 - "HarnessPathDisplay"
Cohesion: 0.06
Nodes (32): CodingKeys, error, id, jsonrpc, method, params, JSONRPCId, int (+24 more)

### Community 226 - "FileChangeWatcher"
Cohesion: 0.20
Nodes (11): ControlModeClient, ControlModeError, daemon, noMatch, noSnapshot, unresolved, Command, Data (+3 more)

### Community 228 - "sessionRow"
Cohesion: 0.22
Nodes (7): KeybindingsStore, URL, KeybindingsStoreTests, URL, Void, KouenCLI, String

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
Cohesion: 0.18
Nodes (3): RegressionBugFixTests, SessionSnapshot, Tab

### Community 234 - ".scan"
Cohesion: 0.16
Nodes (5): Error, Set, SurfaceID, Void, TerminalPaneRegistry

### Community 235 - "WorkbenchCommand"
Cohesion: 0.12
Nodes (13): SettingsHostingController, .init(coder:), .init(page:), SettingsWindowController, NSCoder, NSWindow, Page, advanced (+5 more)

### Community 237 - "TerminalBlockStoreTests"
Cohesion: 0.13
Nodes (10): Bool, CGFloat, NSCoder, NSEvent, NSLayoutConstraint, NSPoint, NSRect, WindowTitleStripView (+2 more)

### Community 238 - ".make"
Cohesion: 0.05
Nodes (29): DefaultTerminalManager, DefaultTerminalOpener, DefaultTerminalRegistrationError, failed, DefaultTerminalStatus, Bool, String, URL (+21 more)

### Community 239 - "TerminalMetalRenderer"
Cohesion: 0.16
Nodes (9): CharacterWidth, Bool, ClosedRange, Unicode, CharacterWidthTable, UInt16, UInt8, UInt32 (+1 more)

### Community 240 - "PaneBorderStatus"
Cohesion: 0.14
Nodes (18): ChooseScope, buffer, client, session, tree, window, Command, MenuItem (+10 more)

### Community 242 - "AgentBridge"
Cohesion: 0.15
Nodes (5): HookFiringTests, NSObjectProtocol, String, URL, XCTestExpectation

### Community 243 - ".make"
Cohesion: 0.12
Nodes (29): Encodable, AISuggestionAck, AttachedAck, BrowserFramePush, BrowserOkAck, BrowserSnapshotAck, Cred, DetachedAck (+21 more)

### Community 244 - "FileNode"
Cohesion: 0.12
Nodes (12): os, DaemonSessionError, daemonError, unexpectedResponse, DaemonSessionService, .request(_:timeout:), LatencyMonitor, Bool (+4 more)

### Community 245 - "ThemeDocumentTests"
Cohesion: 0.21
Nodes (9): InputGate, SurfaceIO, Data, KouenTerminalSurfaceView, SurfaceID, UInt16, UInt64, TerminalHostDelegate (+1 more)

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
Cohesion: 0.23
Nodes (10): AgentRow, HookState, failed, idle, installed, installing, SettingsAgentsView, Bool (+2 more)

### Community 251 - "SessionCoordinator"
Cohesion: 0.22
Nodes (5): SessionCoordinator, Bool, String, SurfaceID, TimeInterval

### Community 252 - "NSViewRepresentable"
Cohesion: 0.17
Nodes (16): OptionSet, BannerShortcut, .init(from:), .init(key:description:showInBanner:), BannerShortcutRegistry, CodingKeys, description, key (+8 more)

### Community 254 - "BoardViewController"
Cohesion: 0.22
Nodes (6): KeyTokenParser, Bool, Data, String, KeyTokenParserTests, Phase6KeysTests

### Community 255 - "release-hotfix.sh"
Cohesion: 0.16
Nodes (9): FileGraphInfo, GraphifyLSPBridge, Double, String, URL, GraphifyLSPBridgeTests, Any, String (+1 more)

### Community 256 - "GitMetadataProvider"
Cohesion: 0.15
Nodes (12): InlineAICompletionView, .init(coder:), .init(frame:), Bool, NSCoder, NSEvent, NSRect, NSTextField (+4 more)

### Community 257 - "Sidebar SwiftUI Migration — Knowledge"
Cohesion: 0.22
Nodes (18): CoreImage, Network, AttachedAck, attachToPairedSurface(), ConnectionState, detectHost(), PairingBox, PendingPairing (+10 more)

### Community 258 - "WindowTitleStripView"
Cohesion: 0.15
Nodes (17): CodingKeys, activeSessionID, activeTabID, id, name, sessions, sortOrder, Decoder (+9 more)

### Community 259 - "ThemeFileServiceTests"
Cohesion: 0.13
Nodes (12): InlineAICompletionController, KouenSettings, String, KouenOptions, ReconnectLatch, Bool, CGFloat, FormatColor (+4 more)

### Community 260 - ".welcome"
Cohesion: 0.25
Nodes (5): Bool, KouenCLI, Bool, String, URL

### Community 261 - "Browser Pane (P14)"
Cohesion: 0.19
Nodes (8): HookNotificationParser, Parsed, Any, Data, String, HookNotificationParserTests, Data, String

### Community 262 - ".install"
Cohesion: 0.21
Nodes (11): KouenTask, Bool, Date, SessionID, String, URL, UUID, TaskStore (+3 more)

### Community 263 - "HarnessSidebarPanelViewController"
Cohesion: 0.20
Nodes (10): DemoSession, DemoTerminalView, GridCanvas, Bool, CGFloat, String, StyledSegment, TerminalGridCell (+2 more)

### Community 266 - ".path"
Cohesion: 0.20
Nodes (7): Data, ThemeDocumentError, emptyName, malformed, unsupportedVersion, wrongPaletteCount, ThemeDocumentTests

### Community 267 - ".performInstall"
Cohesion: 0.11
Nodes (17): Artifacts, Client Application, Client Application, Client Application, Context, D1 — File preview (read-only), D2 — File/image attach (upload), D3 — Browser mirror (embedded, mirrors Mac's real BrowserPaneView) (+9 more)

### Community 270 - "WindowSession"
Cohesion: 0.09
Nodes (13): PaneBorderStatus, Bool, Command, CommandTarget, Data, DispatchWorkItem, KouenGridTerminal, PaneRect (+5 more)

### Community 271 - "StatusLineView.swift"
Cohesion: 0.35
Nodes (6): KouenChrome, KouenChromePalette, Bool, CGFloat, NSColor, String

### Community 272 - "SGRMouseEvent"
Cohesion: 0.14
Nodes (13): Artifacts, Category 1 — Pure refactor + extraction (no behavior change), Category 2 — Agents segment UI + aggregate refresh (A1 + A2), Category 3 — Merge/handoff action (A3), Category 4 — Regression + final gate, Context, Last updated: 2026-07-13, Lessons Learnt reviewed (+5 more)

### Community 273 - "KeySpec"
Cohesion: 0.33
Nodes (3): FileTreeWatcher, FileTreeWatcherTests, URL

### Community 274 - "[2.5.0] - 2026-06-12"
Cohesion: 0.29
Nodes (6): SecureInputMonitor, DispatchWorkItem, Set, String, SurfaceID, Carbon

### Community 275 - "P8: macOS 27 Golden Gate Adoption"
Cohesion: 0.11
Nodes (18): Context, Non-goals, P8: macOS 27 Golden Gate Adoption, Phase 10 — WidgetKit & Desktop Status Panel (P2), Phase 11 — Metal Frame Pacing & DisplayLink Optimization (P2), Phase 12 — Terminal Accessibility Tree (P2), Phase 1 — Compatibility (P0), Phase 2 — Quick Wins (P1) (+10 more)

### Community 276 - "SyntaxTextView"
Cohesion: 0.08
Nodes (21): SettingsAppearanceView, SliderRow, Bool, ClosedRange, Double, String, ColorHexRow, PaletteCell (+13 more)

### Community 278 - "BlockTintOverlay"
Cohesion: 0.31
Nodes (5): KouenSidebarPanelViewController, NSMenu, NSMenuItem, SessionGroup, SessionID

### Community 279 - "DisplayPanesOverlay"
Cohesion: 0.05
Nodes (36): BoardCardView, .init(card:), .init(coder:), BoardViewController, FlippedView, Bool, NSCoder, Set (+28 more)

### Community 280 - ".menu"
Cohesion: 0.25
Nodes (4): StatusLineWidthTests, StatusLineWidth, String, StyledSegment

### Community 281 - "TerminalScrollbarView"
Cohesion: 0.14
Nodes (13): 1. Tasks — storage + MCP + IPC contracts, 2. Worktree (MCP resource) — MCP contracts only, 3. Hosts (MCP resource) — one read-only tool, 4. Shader Presets — rendering pipeline change, Host (MCP resource) — no new aggregate, Logical Design, Open items for task-design to resolve (not blocking, just unresolved here), P40 — MCP Surface Expansion (Tasks/Worktrees/Hosts) + Shader Presets (+5 more)

### Community 282 - "RemoteHostStoreTests"
Cohesion: 0.14
Nodes (8): NSAttributedString, String, SyntaxHighlighter, SyntaxHighlighterTests, NSAttributedString, NSColor, String, SyntaxHighlightTests

### Community 283 - "FormatColor"
Cohesion: 0.24
Nodes (4): RGBColor, String, ThemeDiagnostics, ThemeDiagnosticsTests

### Community 284 - "click_ui_element"
Cohesion: 0.19
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
Cohesion: 0.26
Nodes (5): ScrollbackEntry, ScrollbackReplaySegment, Data, UInt64, RealPtyReplayTests

### Community 294 - "GitHubCLIClient"
Cohesion: 0.05
Nodes (29): AgentDetection, AgentDetector, AgentTable, AgentTableEntry, MatchSource, ownProcess, wrapperLaunch, RawMatch (+21 more)

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
Cohesion: 0.24
Nodes (7): NotificationBus, .postSnapshotChanged(_:), .postSnapshotChanged(revision:), SnapshotChangedPayload, Bool, Data, String

### Community 301 - ".parse"
Cohesion: 0.30
Nodes (3): ImageProtocolTests, String, TerminalEmulator

### Community 302 - "ThemeDiagnostics"
Cohesion: 0.16
Nodes (8): DetectedProfile, HandoffInfo, SignalFileRouter, Bool, FileManager, String, SignalFileRouterTests, URL

### Community 303 - ".encodeMouse"
Cohesion: 0.15
Nodes (14): DesktopNotifier, NotificationPresenter, .userNotificationCenter(_:didReceive:withCompletionHandler:), .userNotificationCenter(_:willPresent:withCompletionHandler:), Bool, MainActor, String, Void (+6 more)

### Community 305 - ".script"
Cohesion: 0.13
Nodes (14): Artifacts, Client Application — Shader Presets (F4) — **UI REVERTED 2026-07-11, user call**, Client Application — Task Dashboard (F1), Context, Data Storage — Tasks (F1), Dev Task Progress — P40 MCP Surface Expansion + Shader Presets, Integration, Lessons applied (from `agent-memory/knowledge/rl-lessons.md`, surfaced during this session's P38 review) (+6 more)

### Community 306 - "RegressionBugFixTests"
Cohesion: 0.25
Nodes (8): Docs, kouen-mcp, KouenCore, KouenDaemon, KouenIPC, P41 — Automations — Task Progress, Tests, Verification

### Community 307 - "ViPathTokenTests"
Cohesion: 0.19
Nodes (7): Bool, NSObjectProtocol, Set, String, Tab, TabID, WorktreeAutoIsolateService

### Community 308 - "Send Ex Command"
Cohesion: 0.19
Nodes (6): FloatingPaneController, Any, Bool, NSEvent, NSObjectProtocol, NSPanel

### Community 310 - "FrameSignposter"
Cohesion: 0.11
Nodes (17): Agent Detection, Branch Detection Flow, Branch Label, Chrome Roles, Drag Reorder, File, Files, Git Branch Detection (+9 more)

### Community 312 - "AgentSnapshot"
Cohesion: 0.24
Nodes (11): Array, Bool, Date, Decoder, PaneID, PaneNode, String, TabID (+3 more)

### Community 313 - "Terminal AI Chat (⌘I inline overlay)"
Cohesion: 0.08
Nodes (29): .agentInfo(forWorktreePath:), AgentNotchDashboardProjection, AgentNotchProjection, AgentNotchRowSummary, RowKind, agent, session, Date (+21 more)

### Community 317 - "Memory — harness-terminal"
Cohesion: 0.18
Nodes (10): 2026-06-25 — OSC 7735:  opens sidebar file viewer, 2026-06-27 — Block output tint + AI explain (Phase 12b), Pruned from MEMORY.md — 2026-07-02, Pruned from MEMORY.md — 2026-07-03, Pruned from MEMORY.md — 2026-07-04, Pruned from MEMORY.md — 2026-07-06, Pruned from MEMORY.md — 2026-07-07, Pruned from MEMORY.md — 2026-07-08 (+2 more)

### Community 319 - "FormatColor"
Cohesion: 0.11
Nodes (13): LaunchdServiceInstaller, ServiceInstaller, ServiceInstallers, ServiceInstallReport, Bool, String, URL, Bool (+5 more)

### Community 320 - "Focus Persistence — Per-Session-Tab Pane Focus (RL-043)"
Cohesion: 0.16
Nodes (5): .init(id:cwd:shell:rows:cols:scrollbackBytes:extraEnvironment:termProgram:termProgramVersion:scrollbackURL:), ShellLaunchProfile, DaemonSurfaceID, URL, ShellLaunchProfileTests

### Community 321 - "UInt64"
Cohesion: 0.13
Nodes (12): KeyRecorderRepresentable, String, Void, OverlayBackground, Context, OverlayBackground, Context, KouenOverlayBackground (+4 more)

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
Cohesion: 0.19
Nodes (11): Hashable, RGBColor, .init(from:), .init(hex:), .init(red:green:blue:alpha:), Bool, Decoder, Double (+3 more)

### Community 326 - "worktree_isolation.robot"
Cohesion: 0.10
Nodes (3): ANSIPaletteTests, CellColorResolverTests, CellColorResolver

### Community 327 - ".theme"
Cohesion: 0.28
Nodes (8): PaneOutputWaiter, PaneOutputWaitResult, Bool, CheckedContinuation, Never, PaneLeaf, Tab, UInt64

### Community 328 - "README.md"
Cohesion: 0.36
Nodes (3): Install, Shell integration (OSC 133 semantic prompts), What gets emitted

### Community 330 - ".drawGlyph"
Cohesion: 0.21
Nodes (12): CellMetrics, ComposedFrame, CellMetrics, ComposedTerminalView, Bool, CellColorResolver, CGFloat, CGPoint (+4 more)

### Community 331 - ".recordReapedGenerationForTesting"
Cohesion: 0.13
Nodes (17): LocalizedError, BinaryInstaller, CopyOutcome, copied, keptNewerInstalled, skippedIdentical, InstallError, missingBundledTools (+9 more)

### Community 333 - "RealPty"
Cohesion: 0.08
Nodes (20): Error, ExpressibleByStringLiteral, InstallError, unsupported, DaemonClientError, connectionFailed, timeout, unexpectedResponse (+12 more)

### Community 334 - "ImageProtocolTests.swift"
Cohesion: 0.14
Nodes (11): MTLLibrary, MTLRenderPipelineState, ImageTextureCache, MTLDevice, MTLTexture, UInt8, CGFloat, MTLBuffer (+3 more)

### Community 335 - ".makeModel"
Cohesion: 0.33
Nodes (6): SurfaceProgressTracker, DispatchWorkItem, MainActor, SurfaceID, TimeInterval, Void

### Community 336 - "run.sh"
Cohesion: 0.70
Nodes (4): kill_stale(), kill_stale_prod(), run.sh script, usage()

### Community 337 - "CommandExecutionError"
Cohesion: 0.09
Nodes (28): RepoGitMetadata, SidebarListModel, SidebarSessionRow, divider, groupHeader, session, worktree, worktreeHeader (+20 more)

### Community 338 - "CSIParams"
Cohesion: 0.30
Nodes (5): AgentNotchPeekDecider, String, AgentNotchPeekDeciderTests, Bool, String

### Community 339 - "Foundation"
Cohesion: 0.14
Nodes (15): CoreGraphics, CoreText, ImageIO, KouenCopyMode, KouenTerminalEngine, KouenTerminalRenderer, KouenTheme, Metal (+7 more)

### Community 342 - "Added"
Cohesion: 0.30
Nodes (7): Bool, NSPasteboard, NSString, String, URL, TerminalServicesProvider, AutoreleasingUnsafeMutablePointer

### Community 343 - "[2.2.3] - 2026-06-09"
Cohesion: 0.19
Nodes (7): .selectWorkspace(_:), .selectWorkspace(byIndex:), TabID, WorkspaceID, ProjectConfig, Bool, String

### Community 344 - "FileViewerViewController"
Cohesion: 0.12
Nodes (13): FileViewerViewController, Bool, NSEvent, Set, String, URL, Void, LSPFileSession (+5 more)

### Community 346 - "Agent platform icons"
Cohesion: 0.50
Nodes (3): Agent platform icons, Lobe Icons — MIT License, Third-party notices

### Community 347 - "[3.2.0] - 2026-06-16"
Cohesion: 0.11
Nodes (17): 1.1 Architecture, 1.2 Algorithm review, 1.3 Structure findings, 2.1 Structure, 2.2 Risk register (ranked), 3.1 Current implementation, 3.2 Why nothing shows (ranked root-cause candidates), 3.3 Fix plan (+9 more)

### Community 349 - "Contents.json"
Cohesion: 0.27
Nodes (3): KouenSettingsTests, URL, Void

### Community 350 - "Background Polling & Snapshot Fanout — P22"
Cohesion: 0.19
Nodes (4): URL, MobileBridgeAttachFileTests, String, URL

### Community 351 - "Architecture Decisions — harness-terminal"
Cohesion: 0.20
Nodes (9): InterruptFlag, ReplayClient, ReplayPlayer, Bool, Data, DispatchSourceSignal, Double, Int32 (+1 more)

### Community 352 - "Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)"
Cohesion: 0.19
Nodes (6): KouenPaths, SessionStore, DispatchWorkItem, SessionSnapshot, TimeInterval, URL

### Community 353 - "GPU Animation Pattern — Layout Once, GPU Paints"
Cohesion: 0.31
Nodes (6): Bool, Counter, Scheduled, SurfaceProgressTrackerTests, DispatchWorkItem, TimeInterval

### Community 354 - "P10: Performance and Feature Roadmap (Terminal First, IDE Convenient)"
Cohesion: 0.22
Nodes (8): 1. Performance Optimization: Scrollback Reflow ($O(\text{history})$ Complexity), 2. convenient Features: Local completion & completion Gutter, 3. IDE Convenient: Keyboard-driven Layout Presets, 4. AI integration: Secure Local ACP Sidebar, Additional features shipped alongside:, Context, Implementation Status (2026-06-11), P10: Performance and Feature Roadmap (Terminal First, IDE Convenient)

### Community 355 - ".deepMerge"
Cohesion: 0.20
Nodes (9): Bug #2 — Cmd+\ squeezes the real terminal pane, real sidebar shows black (2026-07-13), Bug #3 — Same squeeze/black symptom, but from a launch-time layout race, not Settings (2026-07-13), Bug — Cmd+\ sidebar toggle gone after collapse, Confirmed facts, Fix, Related, Suspect A — Dead token guard (confirmed code bug), Suspect B — Zero-delta early exit trap (+1 more)

### Community 356 - "SurfaceProgressTracker"
Cohesion: 0.09
Nodes (26): AgentStatusDot, Context, AgentChipView, BoardColumnKind, ChromeRole, sidebar, tabBar, Divider (+18 more)

### Community 357 - ".handleCat"
Cohesion: 0.21
Nodes (5): NSHostingView, Range, Tab, TerminalTabBarView, .init(frame:)

### Community 358 - "[3.5.1] - 2026-06-20"
Cohesion: 0.17
Nodes (16): FileEditorTabBarBody, FileEditorTabBarModel, FileEditorTabBarView, .init(coder:), .init(frame:), FileTabPillView, Bool, FileTabID (+8 more)

### Community 359 - "OcclusionTests"
Cohesion: 0.22
Nodes (9): Container, .init(coder:), .init(frame:), NotchPulseHost, Content, Context, NSCoder, NSHostingView (+1 more)

### Community 360 - "State"
Cohesion: 0.24
Nodes (7): NotificationPermission, State, denied, granted, undetermined, MainActor, UNAuthorizationStatus

### Community 361 - "FormatStyledSegment.swift"
Cohesion: 0.09
Nodes (19): AutomationStore, KouenAutomation, Bool, Date, String, URL, UUID, AutomationScheduler (+11 more)

### Community 362 - "RGBColor"
Cohesion: 0.27
Nodes (7): MainMenuBuilder, MenuTarget, Bool, NSMenu, NSMenuItem, Selector, String

### Community 363 - "generate-cheatsheet.js"
Cohesion: 0.14
Nodes (8): RealPty, Bool, CChar, Int32, pid_t, String, UInt16, UnsafeMutablePointer

### Community 364 - "[2.2.4] - 2026-06-11"
Cohesion: 0.14
Nodes (11): RecordingEvent, input, metadata, output, resize, ReplayStep, Data, Date (+3 more)

### Community 365 - "Fixes Applied (v3.9.1+)"
Cohesion: 0.16
Nodes (5): TerminalPaneRegistryAccess, KouenTerminalKit, DaemonReconnectPolicy, TimeInterval, DaemonReconnectPolicyTests

### Community 366 - "Consumers"
Cohesion: 0.21
Nodes (10): agentDetail(), AgentInboxBody, AgentInboxPanelView, .init(agents:onSelect:), .init(coder:), AgentInboxRowView, CGFloat, NSCoder (+2 more)

### Community 367 - "DaemonStats"
Cohesion: 0.24
Nodes (10): BlockTintOverlay, .init(coder:), .init(surfaceView:), Bool, CGFloat, KouenTerminalSurfaceView, NSCoder, NSEvent (+2 more)

### Community 368 - "Tab"
Cohesion: 0.21
Nodes (9): ConfigError, unsupportedAgent, writeFailure, MCPConfigWriter, Any, Range, String, URL (+1 more)

### Community 369 - "Git Panel"
Cohesion: 0.22
Nodes (10): DotView, .init(coder:), .init(frame:), Bool, Context, NSCoder, NSColor, NSRect (+2 more)

### Community 370 - ".encode"
Cohesion: 0.19
Nodes (4): NotificationCenterProbe, Bool, Void, NotificationCenterProbeTests

### Community 371 - "P13 — Embedded Browser Pane (cmux parity)"
Cohesion: 0.17
Nodes (11): Architecture, code:block1 (PaneNode (existing binary tree)), Current State, Estimate, Goal, P13 — Embedded Browser Pane (cmux parity), PBI-BROWSER-001: BrowserPaneView + PaneNode integration, PBI-BROWSER-002: Persistence (+3 more)

### Community 372 - "DynamicInstanceBuffer"
Cohesion: 0.11
Nodes (20): LinePos, end, firstNonBlank, start, Bool, CGFloat, Character, NSEvent (+12 more)

### Community 373 - "Prompt"
Cohesion: 0.21
Nodes (12): code:block1 (Add a visual session state indicator to sidebar session card), code:block2 (Add keyboard-driven layout presets to the Harness terminal a), code:block3 (Add workspace-scoped local completion (autocomplete) to the ), code:block4, Context, P10 Implementation Prompts — For Agent Execution, Prompt, Task #1: CMUX Session State Indicator in Sidebar (+4 more)

### Community 374 - ".run"
Cohesion: 0.12
Nodes (16): Agent Config Wiring, Agents, Architecture, Browser Pane, File I/O, Git, Key Files, MCP Server (harness-mcp) (+8 more)

### Community 375 - ".install"
Cohesion: 0.13
Nodes (8): DaemonBrowserRoutingTests, IPCCodecInvariantTests, String, URL, ScrollbackPersistenceTests, String, URL, XCTestCase

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
Cohesion: 0.24
Nodes (7): FSEventStreamBox, escaping, FSEventStreamRef, MainActor, UnsafeMutableRawPointer, Void, WatcherContext

### Community 382 - "ThaiClusterRenderTests"
Cohesion: 0.22
Nodes (6): merged, JSONMerge, Any, Bool, String, JSONMergeTests

### Community 383 - "terminal_stress_runner.py"
Cohesion: 0.40
Nodes (9): attribute_lines(), main(), redraw_frames(), repeated_chunk(), run_case(), sgr_lines(), truecolor_gradient(), unicode_lines() (+1 more)

### Community 384 - "NSTextField Leak in BoardViewController (P20 Performance)"
Cohesion: 0.16
Nodes (12): clamp(), statusColor(), statusHelp(), String, T, tabDisplayTitle(), TabStatus, done (+4 more)

### Community 386 - "SKILL-LOG.md"
Cohesion: 0.13
Nodes (12): .webView(_:createWebViewWith:for:windowFeatures:), .webView(_:didCommit:), BrowserPaneViewTests, MockWebView, Bool, URL, WKNavigation, WebKit (+4 more)

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
Cohesion: 0.28
Nodes (3): CSIParams, TerminalGridColor, UInt8

### Community 402 - "View"
Cohesion: 0.11
Nodes (28): Color, Configuration, TabBarIconButtonStyle, TabBarInlineIconButtonStyle, ButtonStyle, CommandRow, GlassCard, GlassPrimaryButtonStyle (+20 more)

### Community 403 - "themes.json"
Cohesion: 0.22
Nodes (4): GroupedSessionTests, SessionGroup, Set, SurfaceID

### Community 404 - "Split Panes (NSSplitView)"
Cohesion: 0.19
Nodes (3): Pen, SavedCursor, TerminalGridUnderline

### Community 405 - "AgentIconRenderer"
Cohesion: 0.19
Nodes (14): Process, SSHTunnelError, exitedEarly, invalidConfiguration, launchFailed, notReady, SSHTunnelManager, .init(makeTunnelProcess:reachabilityProbe:) (+6 more)

### Community 406 - "main.swift"
Cohesion: 0.17
Nodes (11): A — detection core (`AgentDetector`, pure logic), B — Claude Code Task-subagent hook push (in-process detection), C — IPC / Tab plumbing, Concurrency contract, Corrections to the original plan text (verified against live source, not assumed), D — Client UI indicator, Open items deferred out of this phase (documented, not silently dropped), P38 Phase B — Subagent/Teammate Visibility (+3 more)

### Community 408 - "IPC Architecture"
Cohesion: 0.22
Nodes (7): PasteController, Bool, Data, NSPasteboard, String, TimeInterval, URL

### Community 409 - "Session/Tab/Pane Hierarchy & Top Bar (CASE-028)"
Cohesion: 0.22
Nodes (12): CustomStringConvertible, atomicWrite(), backupCorruptFile(), fnv1aHex(), KouenPathsError, socketPathTooLong, Bool, Data (+4 more)

### Community 411 - "Task 1: Redesign Session Sidebar"
Cohesion: 0.10
Nodes (19): Agent Prompt — Harness Terminal UI Fixes, code:block1 (▶ harness-terminal), code:block2 (▼ harness-terminal  ● Running), code:swift (urlTextField.setContentHuggingPriority(.defaultLow, for: .ho), code:swift (let bv = BrowserPaneView(url: bl.url, paneID: bl.id)), code:bash (cd /Users/supavit.cho/Git/Personal/harness-terminal), code:bash (git add -A), Commit (+11 more)

### Community 412 - "go.json"
Cohesion: 0.28
Nodes (4): PaneLabelDaemonTests, String, URL, UUID

### Community 415 - "markdown.json"
Cohesion: 0.28
Nodes (7): GlassEffectView, RuntimeGlassEffectView, Bool, CGFloat, Context, NSColor, NSView

### Community 416 - "python.json"
Cohesion: 0.20
Nodes (7): Agent Memory Index — harness-terminal, Navigation, Edges, Files, Knowledge Index — Harness Terminal, Search Instructions, Source Map

### Community 417 - "rust.json"
Cohesion: 0.14
Nodes (13): ACP (Agent Client Protocol) — tried, shelved, erased, Command Palette / Power-User Terminal Features, Embedded Browser, Feature Provenance — harness-terminal, Git Panel, Harness MCP, IDE Track — File Tree / Editor / LSP (the "Zed half" made real), Notifications (+5 more)

### Community 418 - ".build"
Cohesion: 0.18
Nodes (10): AppKit / Views, Architecture / Daemon, Browser / WKWebView, Chrome / Theming / Rendering, Git / Process, Notifications / UserNotifications, RL Lessons — harness-terminal, Swift 6 / Concurrency (+2 more)

### Community 419 - "typescript.json"
Cohesion: 0.10
Nodes (22): cardHTML(), closeSheet(), goto(), #list-count, openSession(), renderSessions(), SESSIONS, terminal on mobile research (+14 more)

### Community 420 - "yaml.json"
Cohesion: 0.22
Nodes (4): KeybindingsService, Bool, Command, String

### Community 421 - "FilePreviewCoordinatorTabScopeTests"
Cohesion: 0.22
Nodes (7): .init(coder:), NotificationRowView, .init(coder:), .init(entry:), NSCoder, NSEvent, NSTrackingArea

### Community 422 - "HintModeOverlay"
Cohesion: 0.26
Nodes (5): Mode, compatible, kouen, TerminalIdentity, TerminalIdentityTests

### Community 423 - "SixelDecoder"
Cohesion: 0.12
Nodes (15): AI-IDE landscape (adjacent category — editors, not terminals), Closed 2026-07-11 (P39 phases A–D — build/test green, live-hardware check still owed on each), Competitive Position (as of v4.3.1, 2026-07-11), Deep web research refresh (2026-07-11, 3 parallel research passes), Feature Matrix (2026-07-11), First-party vendor apps + ACP decision (2026-07-11, follow-up research pass), Known Limitations (honest assessment), Kouen Gaps (+7 more)

### Community 424 - ".parseDiffHunks"
Cohesion: 0.33
Nodes (3): GitPanelViewHunkStagingTests, String, URL

### Community 425 - "AgentVectorIcon"
Cohesion: 0.17
Nodes (12): CodingKeys, appearance, applyToTerminalOutput, backgroundBlur, backgroundOpacity, contrastGrade, fontFamily, fontSize (+4 more)

### Community 426 - "Bug — Cmd+\ sidebar toggle gone after collapse"
Cohesion: 0.18
Nodes (10): AgentHookStrategy, eventArrayJSON, eventMatcherJSON, namedGroupJSON, ownJSONFile, ownTextFile, regionEdit, Any (+2 more)

### Community 427 - ".delay"
Cohesion: 0.19
Nodes (3): RemoteHostStoreTests, String, URL

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
Cohesion: 0.27
Nodes (8): Date, String, TerminalBlock, TerminalBlockStore, .block(atPromptLine:), .block(id:), .block(atPromptLine:), .block(id:)

### Community 436 - "WaitForRegistry"
Cohesion: 0.15
Nodes (6): .agentInfo(forWorktreePath:tabs:), Tab, TabID, WorkspaceID, GitPanelViewWorktreeAgentTests, GitPanelViewWorktreeNavigationTests

### Community 437 - "Feature Specs"
Cohesion: 0.18
Nodes (12): Command, CommandTarget, PaneID, SessionGroup, SessionSnapshot, Tab, TargetKind, pane (+4 more)

### Community 438 - "SessionEditor"
Cohesion: 0.27
Nodes (6): HintModeOverlay, Any, KouenTerminalSurfaceView, NSEvent, NSView, String

### Community 439 - "ACP Client"
Cohesion: 0.29
Nodes (7): ACP Client, Architecture, code:block1 (AgentChatPanelView (AppKit UI)), Key Files, Protocol, Shelved Status (June 2025), Tool Call Handling

### Community 440 - "Implementation Phases"
Cohesion: 0.15
Nodes (12): MouseButton, left, middle, right, wheelDown, wheelLeft, wheelRight, wheelUp (+4 more)

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
Cohesion: 0.21
Nodes (3): Double, PaneID, UUID

### Community 448 - "NSSplitView Patterns"
Cohesion: 0.40
Nodes (5): code:swift (private var isApplyingPositions = false), Infinite Recursion Guard (CASE-006), Key Invariants, NSSplitView Patterns, Safe Subview Reorder (CASE-007)

### Community 449 - ".run"
Cohesion: 0.11
Nodes (15): Identifiable, CompleteStepView, Void, DiscoverStepView, Point, String, OnboardingStep, complete (+7 more)

### Community 450 - "MCPServer"
Cohesion: 0.15
Nodes (12): Bug: Tab-Switch Black Screen, Files changed, Final fast-path guard (PaneLifecycleManager.swift), FM-1: detachHostsOnly() before caching (always broken), FM-2: force=true rebuild caches the stripped container, FM-3: Host theft by another tab's build, FM-4: Cache overwrite leaks orphan containers, Instrumentation method (+4 more)

### Community 451 - ".cgPath"
Cohesion: 0.14
Nodes (13): Artifacts, Bigger finding: the planned "Add to Workspace" entry point was unreachable (2026-07-17), Bug found via real `make preview` testing (2026-07-17, post-Task-6), Client Application, Context, Dev Task Progress — Add Repo/Folder to Workspace (P43), Fourth real bug, surfaced by the label becoming honest (2026-07-17), Infrastructure / Data Storage (+5 more)

### Community 452 - "tmux parity — status, adaptations, and deliberate divergences"
Cohesion: 0.29
Nodes (7): Adapted (same capability, Kouen-shaped), At parity, Deferred (tracked, unimplemented), Implemented (previously deferred, now shipped), Invariants this ledger protects, Rejected (with rationale), tmux parity — status, adaptations, and deliberate divergences

### Community 453 - ".update"
Cohesion: 0.14
Nodes (9): BellScanState, esc, normal, stringEsc, SurfaceMonitor, Data, BellScanTests, Bool (+1 more)

### Community 455 - "ComposerPanel"
Cohesion: 0.16
Nodes (10): center, ComposerPanel, Bool, NSEvent, NSTextView, NSWindow, Selector, String (+2 more)

### Community 457 - ".normalizedKey"
Cohesion: 0.31
Nodes (6): AnimatablePair, NotchShape, CGFloat, CGPath, CGRect, Path

### Community 459 - ".encode"
Cohesion: 0.41
Nodes (5): InstallResult, ShellCompletionInstaller, Bool, String, URL

### Community 462 - "AGENTS.md"
Cohesion: 0.13
Nodes (13): Architecture, Build & test, Coding constraints, Communication: GUI ↔ Daemon ↔ CLI, Generated files (do not hand-edit), Graphify + agent-memory, IPC safety, Package map (+5 more)

### Community 464 - "MouseButton"
Cohesion: 0.29
Nodes (7): DiagnosticCheck, DiagnosticStatus, fail, pass, warn, DoctorReport, Int32

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
Cohesion: 0.36
Nodes (11): FooterIconButton, RecentProjectsMenuButton, SidebarFooterModel, SidebarFooterView, SidebarSectionLabelView, SidebarSectionModel, SidebarTabBarView, String (+3 more)

### Community 473 - "HarnessOnboarding"
Cohesion: 0.14
Nodes (9): GridCompositorParityTests, LiveCompositorFixture, Bool, String, TerminalGridSnapshot, PortCompositorFixture, Bool, String (+1 more)

### Community 476 - ".steps"
Cohesion: 0.26
Nodes (5): Bool, NSEvent, NSTrackingArea, WorkspaceSwitcherRow, .init(title:count:isActive:symbol:canDelete:)

### Community 478 - ".install"
Cohesion: 0.18
Nodes (10): cmd-F contract (C2) — contextual, not a rewrite of `updateFind`, Design: overlay, not a new render subtree, Known caveat (pre-existing, inherited not fixed), Open decisions (not decided here, confirm before Stage 4 if it matters), Original design (2026-07-14, deleted 2026-07-15 — kept for history only), P38 Phase C — Agent Thread UX on Existing Block Capture, Pivot (2026-07-15, mid live-test) — supersedes the original design below, Regression risk: near-zero by construction (+2 more)

### Community 479 - "ScrollbackTests"
Cohesion: 0.40
Nodes (3): ReflowFastPathTests, String, TerminalEmulator

### Community 480 - "Command Prompt Architecture"
Cohesion: 0.31
Nodes (3): ReflowPreviewTests, String, TerminalEmulator

### Community 483 - "Changed"
Cohesion: 0.18
Nodes (8): Kind, input, metadata, output, resize, Decoder, KeyedDecodingContainer, String

### Community 490 - "P7: Sidebar UI Polish — Large Screen Layout"
Cohesion: 0.40
Nodes (4): Fix Approach, P7: Sidebar UI Polish — Large Screen Layout, Problems, Status

### Community 492 - "Service Decomposition — SessionCoordinator (P17)"
Cohesion: 0.33
Nodes (3): KouenTerminalSurfaceWorkerTests, Bool, KouenTerminalSurfaceView

### Community 493 - "Browser Tab Close Button Unresponsive"
Cohesion: 0.20
Nodes (9): SettingsTerminalView, Bool, String, TriState, auto, off, on, Typography (+1 more)

### Community 495 - "terminal-cheat-sheet.html"
Cohesion: 0.27
Nodes (6): KittyGraphicsCommand, Bool, Character, Data, String, UInt8

### Community 496 - "CASE — Git / FS / Terminal / Architecture"
Cohesion: 0.17
Nodes (11): ACP vs MCP vs Terminal Chat, AgentProcessManager, Architecture, CLI Print-Mode Args, Context Injection, Key Files, Key Shortcuts (I-family), Non-Obvious Constraints (+3 more)

### Community 498 - "SystemdUserInstaller"
Cohesion: 0.17
Nodes (11): 1. `SessionLifecycleService.swift` (tab bar clicks, sidebar clicks), 2. `MainExecutor.swift` (keyboard shortcuts — the actual user path), Competitive research (from Agy), Data model (correct, no changes needed), Files to read before resuming, Fix applied (compiles, not fully tested), Focus Persistence — Per-Session-Tab Pane Focus (RL-043), Restoration flow (after fix) (+3 more)

### Community 499 - "generate-release-notes.swift"
Cohesion: 0.18
Nodes (10): Current architecture relevant to these gaps, P38 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed), Phase A — Cross-agent diff/review dashboard (biggest gap vs Superset/Supacode) — ✅ DONE 2026-07-13, see p38-phase-a-diff-dashboard/{design.md,dev-task-progress.md}, Phase B — Subagent/teammate visibility as panes (vs cmux) — ✅ CLOSED 2026-07-16 (build/test/robot green, live check skipped per user decision), Phase C — Agent "thread" UX on top of existing block capture (vs Zed Terminal Threads) — ⚠️ pivoted 2026-07-15, ✅ CLOSED 2026-07-16 (build/test/robot green, cross-pane jump-to-block live check skipped per user decision), see p38-phase-c-thread-overlay/{design.md,dev-task-progress.md}, Phase D — Terminal image protocol (Kitty Graphics) — vs WezTerm — ✅ D1 DONE 2026-07-14 (finding: NOT deferred), D3 conformance slice built, ✅ CLOSED 2026-07-16 (build/test/robot green, real-client live check skipped per user decision), Phase E — Scripting hook parity (JS vs WezTerm's Lua) — low priority — ✅ DONE 2026-07-14, ✅ CLOSED 2026-07-16 (low-priority live check skipped per user decision), Phases (+2 more)

### Community 500 - ".json"
Cohesion: 0.25
Nodes (6): BinaryRefresher, Bool, URL, BinaryRefresherTests, String, URL

### Community 501 - "Fixed"
Cohesion: 0.40
Nodes (5): FluidityBenchmarks, KouenTerminalSurfaceView, NSWindow, String, UInt64

### Community 503 - "Build Scripts Self-Kill Protection"
Cohesion: 0.10
Nodes (13): .init(coder:), BrowserProgressLine, .init(coder:), .init(frame:), BrowserTabButton, .init(coder:), .init(title:isActive:onSelect:onClose:), Bool (+5 more)

### Community 506 - "KittyGraphicsCommand"
Cohesion: 0.22
Nodes (7): Bool, NotificationEvent, agentFinished, agentWaiting, bell, commandFinished, Bool

### Community 507 - ".locate"
Cohesion: 0.11
Nodes (6): GitPanelView, Any, DispatchWorkItem, NSMenuItem, UnsafeMutableRawPointer, NSClickGestureRecognizer

### Community 509 - "start.mjs"
Cohesion: 0.70
Nodes (4): main(), runCommand(), selectWithArrows(), selectWithReadline()

### Community 510 - "graphify reference: extra exports and benchmark"
Cohesion: 0.20
Nodes (9): MatchCategory, exactFilename, filenameContains, filenameContainsTokens, filenameEndsWith, filenameStartsWith, fuzzy, pathContains (+1 more)

### Community 511 - ".panePathLookup"
Cohesion: 0.12
Nodes (15): Addendum — MAW-pattern validate gate (2026-07-23), Already matched (verified in code, not gaps), Method, Not gaps — deliberate positioning differences (no action), P39 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed / tmux), Phase A — Remote workflow parity (G2) — DONE 2026-07-11, Phase B — Sidebar dev-server visibility (G1) — DONE 2026-07-11, Phase C — Git workflow depth (G3, G4) — SPLIT 2026-07-11 (Opus planning pass) (+7 more)

### Community 512 - "Changelog Archive"
Cohesion: 0.23
Nodes (4): PromptQueue, String, SurfaceID, Void

### Community 513 - "ThemeDocument"
Cohesion: 0.26
Nodes (9): .webView(_:didFail:withError:), .webView(_:didFailProvisionalNavigation:withError:), .webView(_:didStartProvisionalNavigation:), LoadCompletionState, CheckedContinuation, Error, TimeInterval, Void (+1 more)

### Community 518 - "KouenIPC"
Cohesion: 0.20
Nodes (10): BrowserResponsePayload, cookies, error, network, ok, open, screenshot, snapshot (+2 more)

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
Cohesion: 0.15
Nodes (12): Artifacts, Client Application, Client Application, Client Application, Context, Dev Task Progress — P37 Phase G: Autocomplete (mobile bridge), G1 — @ file-path picker ✅ DONE 2026-07-13, G2 — shell tab-completion suggestion strip (heuristic, best-effort) ✅ DONE 2026-07-13 (+4 more)

### Community 534 - "ANSIPalette"
Cohesion: 0.33
Nodes (4): Bool, SessionCoordinator, String, ThemeService

### Community 535 - "AgentNotification"
Cohesion: 0.29
Nodes (6): Locked decisions (user-confirmed), Logical Design, P38 Phase A — Cross-Agent Worktree Diff/Review Dashboard — Design, Strategic Design, Tactical Design, Verification gate (this phase)

### Community 537 - "TabAlertTests"
Cohesion: 0.36
Nodes (5): OcclusionTests, KouenTerminalSurfaceView, NSWindow, String, TimeInterval

### Community 538 - "SessionGroupHeaderRowView"
Cohesion: 0.06
Nodes (34): MainActor, Void, SessionDividerRowView, .init(coder:), .init(frame:), SessionGroupHeaderRowView, .init(coder:), .init(frame:) (+26 more)

### Community 542 - "SemanticPromptTests"
Cohesion: 0.13
Nodes (11): BrowserIntegrationController, NSView, PaneID, HitTestPassthroughView, PaneContainerView, .init(node:cwd:themeName:existingHosts:existingBrowserPanes:), NSPoint, NSView (+3 more)

### Community 544 - "Task Ledger Archive (Tasks 1–50)"
Cohesion: 0.51
Nodes (9): fuzzyFindFiles(), handleErrors(), handleFind(), handleGrep(), handleMake(), handleRecent(), Int32, String (+1 more)

### Community 545 - "get_window_count"
Cohesion: 0.18
Nodes (10): AI / Agent Connectivity, Architecture Decisions — harness-terminal, Browser Pane, Config / Settings, File Preview / Split Panes, IPC / Daemon, Keybindings, Sessions / Tabs (+2 more)

### Community 546 - "LegacySnapshot"
Cohesion: 0.10
Nodes (14): JSONDecoder, JSONEncoder, LegacySnapshot, LegacyWorkspace, Bool, Date, String, Tab (+6 more)

### Community 547 - "NSObject"
Cohesion: 0.13
Nodes (16): ClosureTarget, MenuActionTarget, OverlayWindow, Phase67UI, PopupWindow, Bool, Command, NSEvent (+8 more)

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
Cohesion: 0.17
Nodes (12): CodingKey, CodingKeys, activeWorkspaceID, keepSessionsOnQuit, revision, savedAt, themeName, version (+4 more)

### Community 557 - "Harness Robot Framework Tests"
Cohesion: 0.13
Nodes (13): RawSelection, Bool, TerminalEmulator, SelectionGranularity, character, line, word, RawSelection (+5 more)

### Community 558 - "ThemeCatalogEmbedTests"
Cohesion: 0.33
Nodes (5): AgentBridge, AgentTarget, Bool, String, SurfaceID

### Community 559 - "ScrollbackPersistenceTests"
Cohesion: 0.18
Nodes (3): String, URL, TaskIPCDaemonTests

### Community 566 - "TerminalTabBarView.swift"
Cohesion: 0.14
Nodes (6): AppKit, AppIdleThrottle, NSObjectProtocol, Action, KouenPathDisplay, UserNotifications

### Community 570 - "CommandHistorySearchController"
Cohesion: 0.08
Nodes (27): CommandHistorySearchController, .tableView(_:heightOfRow:), .tableView(_:rowViewForRow:), .tableView(_:shouldSelectRow:), .tableView(_:viewFor:row:), HistoryItemView, .init(coder:), .init(command:query:) (+19 more)

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
Cohesion: 0.12
Nodes (11): AgentNotchPresentation, closed, open, peek, AgentNotchViewModel, AgentNotchWindowActivator, Bool, CGFloat (+3 more)

### Community 580 - "P4 — LSP + File View (Code Preview in Sidebar)"
Cohesion: 0.15
Nodes (15): Architecture, Components, Estimate, Files, Goal, Grammars, Implementation Notes (MVP — plain-text viewer), LSP Discovery (+7 more)

### Community 581 - "Current Sprint — Post-v2.1.0 Polish & Shelving"
Cohesion: 0.40
Nodes (5): Current Sprint — Post-v2.1.0 Polish & Shelving, Decisions_In_Force, Recent_Lessons, Removed / Reverted Features, Task_Ledger

### Community 582 - "FileTreeKeyboardNavigator"
Cohesion: 0.38
Nodes (3): SettingsAdvancedView, Bool, String

### Community 586 - ".statusLineSet"
Cohesion: 0.18
Nodes (6): JSONOutputFormatter, Bool, String, T, JSONOutputFormatterTests, T

### Community 587 - "LayoutTemplate"
Cohesion: 0.25
Nodes (7): Original overlay build (built 2026-07-14, gated green, then deleted 2026-07-15 mid live-test), P38 Phase C — Agent Thread UX on Existing Block Capture — Dev Task Progress, Pivot — merge into the Recipes picker (2026-07-15), Stage 1-2 — Engine/surface plumbing (built 2026-07-14, unchanged by the pivot, still in use), Status: Implementation pivoted mid-phase from a standalone overlay to a merge into the existing, Summary, Thread grouping — Zed framing folded into the same picker (2026-07-15)

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

### Community 599 - ".cgPath"
Cohesion: 0.29
Nodes (7): AgentNotification, OSCNotificationParser, DaemonSurfaceID, Data, Date, String, SurfaceID

### Community 600 - "HarnessTerminalSurfaceView"
Cohesion: 0.09
Nodes (16): NSRangePointer, NSTextInputClient, KouenTerminalSurfaceView, Any, Bool, NSAttributedString, NSEvent, NSPoint (+8 more)

### Community 603 - "MenuBarController"
Cohesion: 0.13
Nodes (15): AgentRow, AgentRow, MenuBarController, MenuRef, CGFloat, NSImage, NSMenu, NSMenuItem (+7 more)

### Community 613 - "INDEX.md"
Cohesion: 0.25
Nodes (4): Active Plans, Completed, Plans Index — kouen-terminal, Quick ref — recent completions

### Community 614 - "MainSplitViewController"
Cohesion: 0.09
Nodes (21): MainSplitViewController, .setSidebarVisible(_:), .setSidebarVisible(_:animated:), SplitChromeDelegate, .splitView(_:constrainMaxCoordinate:ofSubviewAt:), .splitView(_:constrainMinCoordinate:ofSubviewAt:), .splitView(_:effectiveRect:forDrawnRect:ofDividerAt:), .splitView(_:shouldAdjustSizeOfSubview:) (+13 more)

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
Cohesion: 0.14
Nodes (4): NSTextView, KouenApp, GitPanelViewDiffPopoverTests, GitPanelViewFSEventFilterTests

### Community 621 - "ViEngine"
Cohesion: 0.09
Nodes (10): ScreenPos, bottom, middle, top, Bool, String, ViEngine, KouenCLI (+2 more)

### Community 622 - "[1.3.0-vit] - 2026-06-06"
Cohesion: 0.50
Nodes (3): LiveResizeGeometry, Result, Bool

### Community 623 - "BrowserResponsePayload"
Cohesion: 0.22
Nodes (7): PaneNode, BrowserLeaf, URL, DaemonSyncServiceBrowserPaneMergeTests, PaneID, PaneNode, PaneNodeBrowserTests

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
Cohesion: 0.13
Nodes (12): AnyObject, TimeInterval, ZombieHoldRegistry, PaneLifecycleManager, Bool, NSView, PaneID, PaneNode (+4 more)

### Community 637 - "ClientSummary"
Cohesion: 0.05
Nodes (33): NSCursor, .event(_:), .interval(_:_:), StaticString, T, KouenTerminalSurfaceView, .init(themeName:fontFamily:fontSize:vivid:colorRendering:colorGamut:offMainParserFramePipeline:liveResizeReflow:), .receive(_:) (+25 more)

### Community 641 - "[3.10.0] - 2026-06-27"
Cohesion: 0.25
Nodes (7): #kouen, #practice, #score, #shell, #total, #unix, #vim

### Community 645 - "stability_release.robot"
Cohesion: 0.28
Nodes (3): KouenMCP, KouenBrowserToolsTests, URL

### Community 646 - "[3.10.1] - 2026-06-27"
Cohesion: 0.42
Nodes (3): Lexer, Bool, Character

### Community 648 - "PtyDrainCeilingBenchmark"
Cohesion: 0.15
Nodes (14): Dispatch, Charset, ascii, decSpecialGraphics, Counter, DrainResult, DrainState, EchoRTT (+6 more)

### Community 649 - "Added"
Cohesion: 0.35
Nodes (5): .webView(_:didFinish:), BrowserTab, UUID, tabs, NSAppearance

### Community 650 - "[3.11.0] - 2026-06-28"
Cohesion: 0.08
Nodes (25): DiffLineType, added, deleted, modified, Notification.Name, Bool, NSCoder, NSEvent (+17 more)

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
Cohesion: 0.24
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
Cohesion: 0.22
Nodes (8): Build order (unchanged from interview decision), G1 — @ file-path picker, G2 — shell tab-completion suggestion strip (heuristic, explicitly best-effort), G3 — AI command suggestion (via `claude` CLI subprocess), Logical Design, P37 Phase G — Autocomplete (mobile bridge), Strategic Design, Tactical Design

### Community 665 - "PathToken"
Cohesion: 0.27
Nodes (4): Darwin, Glibc, KouenCLI, String

### Community 666 - "BrowserIntegrationController"
Cohesion: 0.19
Nodes (4): SnapshotCoalescer, MainActor, Void, AgentApprovalBarTests

### Community 669 - ".recordReapedGenerationForTesting"
Cohesion: 0.39
Nodes (5): AutomationSummary, Bool, Date, String, UUID

### Community 670 - "[3.9.1] - 2026-06-22"
Cohesion: 0.20
Nodes (6): LayoutTemplate, evenHorizontal, evenVertical, mainHorizontal, mainVertical, tiled

### Community 671 - "AgentKind"
Cohesion: 0.38
Nodes (5): Result, ShellRCWiring, Bool, String, URL

### Community 672 - "ColorKind"
Cohesion: 0.33
Nodes (5): Gate, Implementation, P38 Phase D — Kitty Graphics Conformance Slice, Scope (locked), Tests

### Community 674 - "P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable"
Cohesion: 0.18
Nodes (11): Competitive comparison (2026-07-13, post Phase D+E), Current architecture (as shipped, build 195), P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable, Phase A — Hardening (daemon only, no UI), Phase B — In-app pairing UX (macOS Settings), Phase C — Real mobile client (W3, replaces smoke-test page) — DONE 2026-07-09, uncommitted, Phase D — File preview, file attach, browser mirror (v1.1 — the former W4/W4b/W5, now scoped), Phase F — candidates from competitive research (not scoped, not scheduled) (+3 more)

### Community 675 - ".detect"
Cohesion: 0.29
Nodes (6): Accessibility Identifiers Required, Architecture, Kouen Robot Framework Tests, Prerequisites, Run, Troubleshooting

### Community 676 - "[2.1.0] - 2026-06-07"
Cohesion: 0.33
Nodes (3): String, URL, ThemeCatalogEmbedTests

### Community 678 - "FilePreviewCoordinator"
Cohesion: 0.22
Nodes (7): State, error, indeterminate, paused, remove, set, TerminalProgressReport

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
Cohesion: 0.25
Nodes (7): Claude Code hook push (in-process Task subagent detection), Client UI indicator, Detection core (AgentDetector, pure logic), IPC / Tab plumbing, P38 Phase B — Subagent Visibility — Dev Task Progress, Status: Rewritten 2026-07-14 after original implementation (tasks 1-5) was lost to a concurrent git operation before commit. Closed 2026-07-16 on user instruction, live check skipped., Summary

### Community 689 - "Bool"
Cohesion: 0.33
Nodes (5): Gate, Implementation, P38 Phase E — Scripting Hook Parity (JS vs WezTerm's Lua), Scope (locked), Tests

### Community 691 - "Phase6KeysTests"
Cohesion: 0.25
Nodes (3): MobileBridgeSpawnTests, String, URL

### Community 692 - ".testOptionLinesAreNotCommands"
Cohesion: 0.40
Nodes (3): KouenGridTerminal, TerminalGridCell, TerminalEmulator

### Community 693 - "[2.0.0] - 2026-06-07"
Cohesion: 0.33
Nodes (5): Claude Code → Kouen, Customizing, One-line install, Verifying, What gets written

### Community 694 - "TerminalScreen"
Cohesion: 0.29
Nodes (6): Logical Design, Next Step, P42 — Workspace Sidebar Panels, Parked (not in scope), Strategic Design, Tactical Design

### Community 696 - "TerminalTabBarDelegate"
Cohesion: 0.25
Nodes (7): Avoid, Colors, Components, Design Direction, Design System, Spacing / Radius / Motion, Typography

### Community 700 - "Lexer"
Cohesion: 0.35
Nodes (4): KouenCLI, SessionID, String, Bool

### Community 708 - "[3.4.0] - 2026-06-19"
Cohesion: 0.22
Nodes (4): AgentScanner, Bool, DispatchSourceTimer, TimeInterval

### Community 709 - ".start"
Cohesion: 0.19
Nodes (3): PipeBuffer, Result, MobileBridgeAISuggestTests

### Community 710 - "MainWindowController"
Cohesion: 0.12
Nodes (12): KouenWindow, NSEvent, MainWindowController, Any, NSRect, CGFloat, NSColor, NSPoint (+4 more)

### Community 711 - "FileTabManager"
Cohesion: 0.13
Nodes (7): KouenCore, KouenDaemonCore, DaemonCommandExecutor, GroupedSessionDaemonTests, SessionGroup, String, URL

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
Nodes (14): .removeWorktreeAction(path:), GitResult, String, ValidateOutcome, Content, NSView, NSViewCornerConfiguration, String (+6 more)

### Community 720 - ".printBoard"
Cohesion: 0.35
Nodes (3): ShellCompletionInstallerTests, String, URL

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

### Community 742 - ".hitTest"
Cohesion: 0.25
Nodes (4): ControlKeyNormalizer, Bool, String, ControlKeyNormalizerTests

### Community 744 - "TerminalGridCellLayoutTests"
Cohesion: 0.50
Nodes (4): Case Index, Grep Command, Open Cases, Playbook — harness-terminal

### Community 745 - "p11_scripting.robot"
Cohesion: 0.31
Nodes (4): object, KouenSettings, Bool, Data

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

### Community 804 - "AgentVectorIcon"
Cohesion: 0.29
Nodes (5): DirectionalAxis, down, left, right, up

### Community 809 - "RawSelection"
Cohesion: 0.29
Nodes (6): Anti-Patterns Avoided, Architecture, Key Design Decisions, Pattern, Service Decomposition — SessionCoordinator (P17), When to Apply This Pattern

### Community 817 - "ProbeOutputBox"
Cohesion: 0.67
Nodes (3): Phase 0 — Swift 6.3+ Concurrency Safety (P0, LESSONS FROM macOS 26.5 CRASH SAGA), Rules (enforced, not optional), Verification checklist for macOS 27 beta

### Community 830 - "graphify reference: transcribe video and audio"
Cohesion: 0.29
Nodes (6): Browser Tab Close Button Unresponsive, Files, Fix Applied, If Fix Is Insufficient, Root Cause, Symptom

### Community 832 - "KouenCLIPaths"
Cohesion: 0.33
Nodes (5): Bug pattern: browser-pane preserve-merge discards real daemon changes, Lesson for the next occurrence, Occurrence 1 — 2026-06-15 (`b76fb0dd`), Occurrence 2 — 2026-07-23 (this session), Root architectural fact

### Community 836 - "ColorKind"
Cohesion: 0.33
Nodes (4): Logical Design, P41 — Automations, Strategic Design, Tactical Design

### Community 839 - "RawSelection"
Cohesion: 0.29
Nodes (6): Architecture / Keybindings, CASE — Git / FS / Terminal / Architecture, Claude Code / Tooling / Environment (the agent running *inside* Harness), Command Prompt / Parser, Git / File System, Terminal / Renderer / Daemon

### Community 840 - "Added"
Cohesion: 0.29
Nodes (6): ACP Client (Shelved), Architecture (Preserved), Re-enablement Criteria, Status: SHELVED (June 2026), What It Is, Why Shelved

### Community 841 - "Now"
Cohesion: 0.29
Nodes (6): Build Scripts Self-Kill Protection, Detection, Fix (applied in `Scripts/run.sh`), Key Invariant, Problem, Related

### Community 865 - "AutomationScheduler"
Cohesion: 0.33
Nodes (4): FormatContextBuilder, DaemonSurfaceID, SessionSnapshot, String

### Community 884 - "WriteOutcome"
Cohesion: 0.22
Nodes (8): Artifacts, Client Application — Slice 1 (stacked panes, no persistence), Client Application — Slice 2 (per-workspace divider memory), Context, Dev Task Progress — Workspace Sidebar Panels (P42), Integration, Note on task re-sequencing (2026-07-17), Summary

### Community 920 - "Fixed"
Cohesion: 0.36
Nodes (3): SplitDirection, TabID, TerminalTabBarDelegate

### Community 949 - "ThaiClusterCopyTests.swift"
Cohesion: 0.27
Nodes (4): BrowserPaneRegistry, NSWindow, PaneID, WeakBrowserPaneView

### Community 964 - "Added"
Cohesion: 0.22
Nodes (6): FormatContextDaemonTests, PaneID, SessionSnapshot, String, SurfaceID, URL

### Community 982 - "PaneID"
Cohesion: 0.33
Nodes (5): Codex Fix Prompt Template, FSEvents Recursive Watcher Pattern (Swift), Full Swift Actor Pattern, Single-file watch (DispatchSource is enough), When to use

### Community 1000 - "Changed"
Cohesion: 0.36
Nodes (7): CGFloat, NSCoder, WorkspaceID, WorkspaceSwitcherPanelView, .init(coder:), .init(workspaces:activeWorkspaceID:onSelect:onNew:onDelete:), .init(coder:)

### Community 1104 - "Added"
Cohesion: 0.54
Nodes (4): CGFloat, TabBarLayoutMetrics, TerminalTabBarBody, TerminalTabBarModel

### Community 1106 - "Added"
Cohesion: 0.36
Nodes (3): KouenSplitViewTests, LayoutProbeView, CGFloat

### Community 1109 - "Changed"
Cohesion: 0.46
Nodes (3): SessionSnapshot, Tab, WorkbenchContextResolverTests

### Community 1155 - "Fixed"
Cohesion: 0.50
Nodes (3): P38 Phase D — Kitty Conformance — Dev Task Progress, Status: Implementation complete, build/test/robot green. Closed 2026-07-16 on user instruction, live check skipped., Summary

### Community 1173 - "Fixed"
Cohesion: 0.29
Nodes (5): NotificationEntry, SessionID, SurfaceID, TabID, WorkspaceID

### Community 1255 - "CLAUDE.md"
Cohesion: 0.50
Nodes (3): P38 Phase E — Scripting Hooks — Dev Task Progress, Status: Implementation complete, build/test/robot green. Closed 2026-07-16 on user instruction, live check skipped (was already lowest priority of B/C/D/E)., Summary

### Community 1303 - ".pushAgentActivityNotifications"
Cohesion: 0.50
Nodes (3): exclude_hubs, no_viz, wiki

### Community 1305 - "TerminalColorRole"
Cohesion: 0.29
Nodes (3): Date, TabPillView, Gesture

### Community 1306 - ".rememberTabForReopen"
Cohesion: 0.20
Nodes (10): Section, actions, errors, files, grep, navigation, projects, recent (+2 more)

### Community 1309 - ".startMetadataRefresh"
Cohesion: 0.83
Nodes (3): entries(), cheat.sh script, usage()

### Community 1398 - "ScrollbackPersistenceTests"
Cohesion: 0.29
Nodes (7): TabContextCommand, close, closeOthers, rename, splitHorizontal, splitVertical, togglePersistent

### Community 1402 - "setupBoardPanel"
Cohesion: 0.16
Nodes (9): DetectionStatus, found, notFound, willInstall, BinaryInstaller.DetectionStatus, SetupStepView, Bool, String (+1 more)

### Community 1544 - "TargetSpec.swift"
Cohesion: 0.29
Nodes (7): CodingKeys, createdAt, dataBase64, rows, timeMs, type, version

### Community 1574 - "Fixed"
Cohesion: 0.60
Nodes (4): CLICommand, CLICommandCatalog, Bool, String

### Community 1578 - "NotificationEntry"
Cohesion: 0.17
Nodes (4): InputEncoder, InputEncoderTests, String, UInt8

### Community 1801 - "ClientSummary"
Cohesion: 0.47
Nodes (5): AgentIconArt, AgentVectorIcon, Bool, CGSize, String

### Community 1857 - "BlockSummary"
Cohesion: 0.60
Nodes (3): BlockSummary, Date, String

### Community 1914 - "P43 — Add Repo/Folder to Workspace"
Cohesion: 0.33
Nodes (5): Logical Design, Next Step, P43 — Add Repo/Folder to Workspace, Strategic Design, Tactical Design

### Community 1933 - ".load"
Cohesion: 0.40
Nodes (5): DecodedWSFrame, WSFrameParseResult, frame, incomplete, oversized

### Community 1943 - "ITerm2InlineImage"
Cohesion: 0.47
Nodes (3): .encode(_:modifiers:event:modes:), SpecialKey, insert

### Community 2006 - ".deleteWorkspaceFromMenu"
Cohesion: 0.33
Nodes (6): DecoKind, curly, dashed, dotted, double, solid

### Community 2055 - "Changed"
Cohesion: 0.50
Nodes (3): .init(forTesting:), UUID, Void

### Community 2126 - ".handleCat"
Cohesion: 0.50
Nodes (3): PaneID, PaneLeaf, PaneNode

### Community 2213 - "ReplayStep"
Cohesion: 0.50
Nodes (4): PresentAttempt, encodeFailure, nilDrawable, presented

### Community 3419 - "Page"
Cohesion: 0.24
Nodes (6): AboutPanelController, AboutView, MonoPillButtonStyle, Configuration, NSWindow, NSHostingController

### Community 3515 - "RawRepresentable"
Cohesion: 0.08
Nodes (29): KeySpec, .init(from:), .init(key:modifiers:), Modifiers, Decoder, String, UInt8, Binding (+21 more)

## Knowledge Gaps
- **3864 isolated node(s):** `unsupportedPlatform`, `unmodified`, `modified`, `added`, `deleted` (+3859 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2391 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.
- **15 possibly unreachable function(s):** `.addSurface(tabID:paneID:)`, `.agentInfo(forWorktreePath:tabs:)`, `.color(_:)`, `.color(_:alpha:)`, `.encode(_:modifiers:event:modes:)` (+10 more)
  Not reached from any recognized entry point - could be dead code, or dynamically dispatched/decorator-registered.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Int` connect `.text` to `Changelog Archive`, `callingPaneTarget`, `CodingKey`, `EngineConformanceTests`, `IPCRequest`, `AgentNotchRootView`, `Command`, `LSPMessage`, `TerminalEmulator`, `PerformanceBenchmarks`, `GitPanelView.swift`, `.run`, `KittyKeyboardTests`, `VTParser`, `HarnessTerminalSurfaceView`, `.applyPreedit`, `MetalRendererTests`, `HarnessUILibrary`, `SpecialKey`, `HarnessChrome`, `HarnessTerminalSurfaceView`, `CopyModeAction`, `SplitPaneCoordinator`, `.request`, `WorktreeManager`, `SessionGroupHeaderRowView`, `install-app.sh`, `.parse`, `RGBColor`, `Notification`, `.addTab`, `Equatable`, `LegacySnapshot`, `MenuTarget`, `.resolve`, `String`, `Task Ledger Archive (Tasks 1–50)`, `TerminalColorGamut`, `HarnessSettings`, `CodingKeys`, `HarnessSidebarPanelViewController.swift`, `HarnessOverlayBackground`, `Harness Robot Framework Tests`, `.buildCommand`, `.normalizedKey`, `DaemonServer`, `.keyEvent`, `HarnessSplitView`, `TabCell`, `newWindow`, `BellScanState`, `CommandHistorySearchController`, `PasteBufferStore`, `ViEngine`, `FrecencyDirectoryStore`, `ComposedCell`, `HarnessCLI+Server.swift`, `PrefixKeymap`, `TerminalProgressReport`, `DecoKind`, `String`, `.compose`, `XCTestCase`, `.parse`, `Endpoint`, `Added`, `selectWorkspace`, `LSPClient`, `TerminalGridCell`, `HarnessPaths`, `HarnessTerminalSurfaceView`, `TerminalModes`, `MenuBarController`, `AttachInputBatcher`, `shim.c`, `.testRenderEncodeIncrementalDamage160x48`, `PaneContainerView`, `ScriptRuntime.swift`, `MainSplitViewController`, `DaemonLauncher`, `Recipe`, `Changelog`, `AnyCodable`, `AgentNotchViewModel`, `NSView`, `DamageTrackingTests`, `SoftIconButton`, `[1.3.0-vit] - 2026-06-06`, `[2.5.0] - 2026-06-12`, `.makeSnapshot`, `HarnessGridTerminal`, `.encode`, `SessionGroup`, `graphify reference: query, path, explain`, `WorkspaceFileTreeView`, `.firstWaitingTab`, `ViEngine`, `HistoryRingBuffer`, `.path`, `ClientSummary`, `GlyphAtlas`, `.install`, `AgentHookInstaller`, `[3.10.1] - 2026-06-27`, `.startWatching`, `Added`, `[3.11.0] - 2026-06-28`, `ActivePaneService`, `PtyDrainCeilingBenchmark`, `PaneStyleSet`, `AsciiFastPathTests`, `MCPServer`, `HarnessDaemonToolsTests`, `LiveResizeTests`, `Int`, `ThaiCombiningMarkTests`, `.recordReapedGenerationForTesting`, `TerminalFindBar`, `.jumpToBlock`, `CommandPromptController`, `ActiveTabCloseDisposition`, `FilePreviewCoordinator`, `URLDetection`, `.decodeKeySpec`, `BoardCard`, `[1.5.1] - 2026-06-06`, `BinaryRefresherTests`, `Added`, `.rects`, `InlineAICompletionView`, `[3.13.1] - 2026-07-02`, `.testOptionLinesAreNotCommands`, `VTConformanceCorpusTests`, `GridCompositorTests`, `LSPServerRegistry`, `SessionSnapshot`, `Error`, `AppDelegate`, `ScriptRuntime`, `GlyphRasterizer`, `BinaryInstaller`, `Tab Bar (TerminalTabBarView) — Layout, Git Branch & Drag`, `AgentSessionSummary`, `.classify`, `MCP Server (harness-mcp)`, `[3.9.5] - 2026-06-26`, `[2.4.0] - 2026-06-12`, `scheduleRender`, `.testDataFrameEncodeVsJSONBase64Output`, `PaneTarget`, `CellColorResolverTests`, `GridCompositor`, `TerminalServicesProvider`, `ANSIPalette`, `CellColorResolver`, `HarnessPathDisplay`, `FileChangeWatcher`, `ExternalOpenKind`, `WorkbenchCommand`, `TerminalMetalRenderer`, `PaneBorderStatus`, `[3.5.1] - 2026-06-20`, `.make`, `ThemeDocumentTests`, `ReflowPreviewTests`, `SessionCoordinator`, `BoardViewController`, `workspace`, `release-hotfix.sh`, `Sidebar SwiftUI Migration — Knowledge`, `WindowTitleStripView`, `ThemeFileServiceTests`, `listSurfaces`, `.welcome`, `HarnessSidebarPanelViewController`, `.userNotificationCenter`, `.path`, `[2.2.4] - 2026-06-11`, `[3.11.2] - 2026-06-28`, `DefaultTerminalManager`, `StatusLineView.swift`, `WindowSession`, `SyntaxTextView`, `.run`, `renumberWindows`, `DisplayPanesOverlay`, `.menu`, `TerminalColorRole`, `.rememberTabForReopen`, `FormatColor`, `click_ui_element`, `AgentHookStrategy`, `StatusLineWidthTests`, `Process`, `JSONDecoder`, `Fixes Applied (layered)`, `GitHubCLIClient`, `NotificationBus`, `settings.json`, `PaneNode`, `HarnessPaths.swift`, `.parse`, `.scrollWheel`, `AgentSnapshot`, `Terminal AI Chat (⌘I inline overlay)`, `Focus Persistence — Per-Session-Tab Pane Focus (RL-043)`, `BlockSummary`, `DesktopNotifier`, `LayoutNode`, `WorkspaceSymbolIndex`, `worktree_isolation.robot`, `.theme`, `.drawGlyph`, `.recordReapedGenerationForTesting`, `RealPty`, `ImageProtocolTests.swift`, `.makeModel`, `CommandExecutionError`, `Foundation`, `[2.2.3] - 2026-06-09`, `Background Polling & Snapshot Fanout — P22`, `AutomationScheduler`, `GPU Animation Pattern — Layout Once, GPU Paints`, `.handleCat`, `FormatStyledSegment.swift`, `projectGroupRootPath`, `[2.2.4] - 2026-06-11`, `generate-cheatsheet.js`, `Consumers`, `DaemonStats`, `Fixes Applied (v3.9.1+)`, `DynamicInstanceBuffer`, `.tabIndex(tabID:)`, `Identifiable`, `SurfaceProgressTrackerTests.swift`, `User Profile`, `HarnessCLITests`, `Source`, `AppKit + Metal Patterns`, `.load`, `Split Panes (NSSplitView)`, `AgentIconRenderer`, `Fixed`, `Session/Tab/Pane Hierarchy & Top Bar (CASE-028)`, `IPC Architecture`, `HintModeOverlay`, `.parseDiffHunks`, `PathToken`, `Project History`, `.highlight`, `Feature Specs`, `SessionEditor`, `Implementation Phases`, `main.swift`, `.run`, `TabPillView`, `.evaluateStyled`, `HarnessOnboarding`, `.steps`, `ScrollbackTests`, `Command Prompt Architecture`, `Changed`, `[3.10.1] - 2026-06-27`, `printThemePreview`, `terminal-cheat-sheet.html`, `requireSessionID`, `resolvedCLIPath`, `.json`, `.locate`, `graphify reference: extra exports and benchmark`?**
  _High betweenness centrality (0.299) - this node is a cross-community bridge._
- **Why does `KouenCore` connect `FileTabManager` to `Changelog Archive`, `callingPaneTarget`, `graphify reference: extra exports and benchmark`, `.handleNormal`, `EngineConformanceTests`, `AgentNotchRootView`, `TerminalEmulator`, `PerformanceBenchmarks`, `.run`, `KittyKeyboardTests`, `MetalRendererTests`, `HarnessUILibrary`, `SpecialKey`, `.request`, `SessionGroupHeaderRowView`, `install-app.sh`, `SemanticPromptTests`, `Task Ledger Archive (Tasks 1–50)`, `Equatable`, `LegacySnapshot`, `NSObject`, `MenuTarget`, `String`, `[3.12.0] - 2026-06-30`, `CodingKeys`, `RenderSchedulerTests`, `HarnessOverlayBackground`, `HarnessTerminalSurfaceView.swift`, `ThemeCatalogEmbedTests`, `.normalizedKey`, `HookEvent`, `DaemonServer`, `.buildCommand`, `.keyEvent`, `ScrollbackPersistenceTests`, `TerminalTabBarView.swift`, `NSPanel`, `BellScanState`, `CommandHistorySearchController`, `ComposedCell`, `HarnessCLI+Server.swift`, `TerminalProgressReport`, `DecoKind`, `FileTreeKeyboardNavigator`, `worktree_isolation_cli.robot`, `XCTestCase`, `.detect`, `.statusLineSet`, `.parse`, `TerminalProtocolCompatibilityTests`, `Endpoint`, `.handleWake`, `LSPClient`, `LSPDiagnostic`, `Changed`, `SessionCoordinator`, `.cursorPos`, `MenuBarController`, `AttachInputBatcher`, `shim.c`, `PaneContainerView`, `.dispatch`, `MainSplitViewController`, `Changelog`, `AgentNotchViewModel`, `NSView`, `ViEngine`, `SoftIconButton`, `BrowserResponsePayload`, `DamageTrackingTests`, `.resolve`, `.encode`, `SessionGroup`, `PaneNode`, `WorkspaceFileTreeView`, `[3.0.0] - 2026-06-15`, `clearSelection`, `ViEngine`, `Pipe`, `String`, `ClientSummary`, `.install`, `.load`, `stability_release.robot`, `PtyDrainCeilingBenchmark`, `ActivePaneService`, `[3.11.0] - 2026-06-28`, `.testPaneLeafLegacyDecodeBackfillsSurfaceTabs`, `CopyModeGridSource`, `DecodedImage`, `MCPServer`, `FileTreeWatcher`, `EnvironmentStore`, `New Tab`, `HarnessDaemonToolsTests`, `What You Must Do When Invoked`, `PathToken`, `ThaiCombiningMarkTests`, `[3.8.0] - 2026-06-22`, `MatchCategory`, `sessionCreated`, `LiveSession`, `ReflowCorpusTests`, `.decodeKeySpec`, `RGBColorTests`, `Added`, `.rects`, `InlineAICompletionView`, `GridCompositorTests`, `AppDelegate`, `BrowserPaneView`, `ScriptRuntime`, `[2.3.0] - 2026-06-11`, `[2.5.1] - 2026-06-12`, `BinaryInstaller`, `[3.4.0] - 2026-06-19`, `.classify`, `BinaryInstallerVersionTests`, `AutomationScheduler`, `PaletteModel`, `CopyModeState`, `scheduleRender`, `.printBoard`, `PaneDropZoneOverlay`, `.translate`, `NotchLayoutMetrics`, `.lines`, `CellColorResolverTests`, `GridCompositor`, `ScrollbackFile`, `Section`, `HarnessPathDisplay`, `FileChangeWatcher`, `SSHTunnelManagerTests`, `sessionRow`, `.hitTest`, `graphify reference: incremental update and cluster-only`, `TextGrid`, `.scan`, `WorkbenchCommand`, `.make`, `AgentBridge`, `.make`, `FileNode`, `FindWindowMatcherTests`, `.renderFixture`, `DaemonMetrics`, `ReflowPreviewTests`, `[3.4.0] - 2026-06-19`, `HarnessTerminalSurfaceWorkerTests`, `SessionCoordinator`, `Split Right`, `BoardViewController`, `Sidebar SwiftUI Migration — Knowledge`, `.welcome`, `Browser Pane (P14)`, `KeySpec`, `[2.5.0] - 2026-06-12`, `SyntaxTextView`, `reorderSession`, `BlockTintOverlay`, `DisplayPanesOverlay`, `CLICommand`, `.menu`, `Added`, `.apply`, `Fixes Applied (layered)`, `GitHubCLIClient`, `.load`, `jobs`, `ThemeDiagnostics`, `ViPathTokenTests`, `Send Ex Command`, `.selectedText`, `Terminal AI Chat (⌘I inline overlay)`, `FormatColor`, `worktree_isolation.robot`, `.theme`, `RealPty`, `.makeModel`, `CommandExecutionError`, `CSIParams`, `Foundation`, `DaemonLifecycleTests`, `Background Polling & Snapshot Fanout — P22`, `Architecture Decisions — harness-terminal`, `AutomationScheduler`, `GPU Animation Pattern — Layout Once, GPU Paints`, `SurfaceProgressTracker`, `[3.5.1] - 2026-06-20`, `FormatStyledSegment.swift`, `Fixes Applied (v3.9.1+)`, `Consumers`, `SurfaceRegistryTests.swift`, `Tab`, `.encode`, `.install`, `Identifiable`, `PromptQueue`, `ThaiClusterRenderTests`, `NSTextField Leak in BoardViewController (P20 Performance)`, `SKILL-LOG.md`, `User Profile`, `UI Automation — Robot Framework (P18)`, `themes.json`, `IPC Architecture`, `go.json`, `yaml.json`, `HintModeOverlay`, `.delay`, `LaunchdServiceInstaller`, `WaitForRegistry`, `ThaiClusterCopyTests.swift`, `RawRepresentable`, `BlockContextMenuTests`, `.run`, `.update`, `PaneLabelDaemonTests`, `ReflowFastPathTests`, `.evaluateStyled`, `HarnessOnboarding`, `.pathDisplayName`, `Browser Tab Close Button Unresponsive`, `.json`, `ACP Client (Shelved)`?**
  _High betweenness centrality (0.048) - this node is a cross-community bridge._
- **Why does `Foundation` connect `Identifiable` to `Changelog Archive`, `callingPaneTarget`, `.handleNormal`, `IPCRequest`, `AgentNotchRootView`, `TerminalEmulator`, `KittyKeyboardTests`, `VTParser`, `HarnessChrome`, `SpecialKey`, `SplitPaneCoordinator`, `.request`, `RGBColor`, `Task Ledger Archive (Tasks 1–50)`, `DaemonClient`, `MenuTarget`, `String`, `Fixed`, `.startWatching`, `[3.12.0] - 2026-06-30`, `CodingKeys`, `HarnessSidebarPanelViewController.swift`, `RenderSchedulerTests`, `HarnessOverlayBackground`, `HarnessTerminalSurfaceView.swift`, `ThemeCatalogEmbedTests`, `.buildCommand`, `HookEvent`, `markPane`, `.keyEvent`, `TerminalTabBarView.swift`, `BellScanState`, `PasteBufferStore`, `FrecencyDirectoryStore`, `HarnessCLI+Server.swift`, `ShellIntegration`, `DecoKind`, `.statusLineSet`, `OptionStore`, `.parse`, `Endpoint`, `.handleWake`, `DaemonSubscription`, `LSPClient`, `LSPDiagnostic`, `TerminalGridCell`, `HarnessPaths`, `SessionCoordinator`, `.cgPath`, `AttachInputBatcher`, `PaneContainerView`, `.dispatch`, `DaemonLauncher`, `KouenCLIPaths`, `Recipe`, `Changelog`, `ScriptFileWatcher`, `AgentNotchViewModel`, `AnyCodable`, `ViEngine`, `DamageTrackingTests`, `BrowserResponsePayload`, `.resolve`, `.firstWaitingTab`, `ActiveTabCloseDisposition`, `SessionGroup`, `PaneNode`, `WorkspaceFileTreeView`, `[3.0.0] - 2026-06-15`, `Pipe`, `HistoryRingBuffer`, `AgentHookInstaller`, `graphify reference: query, path, explain`, `.startWatching`, `ActivePaneService`, `PtyDrainCeilingBenchmark`, `CommandTarget`, `TerminalHostView`, `CopyModeGridSource`, `PaneStyleSet`, `AsciiFastPathTests`, `DecodedImage`, `FileTreeWatcher`, `EnvironmentStore`, `HarnessDaemonToolsTests`, `[3.1.2] - 2026-06-16`, `.evaluate`, `PathToken`, `BrowserIntegrationController`, `Int`, `LiveResizeTests`, `.recordReapedGenerationForTesting`, `[3.9.1] - 2026-06-22`, `AgentKind`, `AmbientBackground`, `MatchCategory`, `Workspace`, `CommandPromptController`, `ActiveTabCloseDisposition`, `FilePreviewCoordinator`, `[2.1.0] - 2026-06-07`, `URLDetection`, `.decodeKeySpec`, `Added`, `.hold`, `InlineAICompletionView`, `[3.13.1] - 2026-07-02`, `GridCompositorTests`, `Error`, `BrowserPaneView`, `GlyphRasterizer`, `BinaryInstaller`, `[3.4.0] - 2026-06-19`, `FileTabManager`, `BinaryInstallerVersionTests`, `PaletteModel`, `TerminalProgressReport`, `ReplayStep`, `grok`, `PaneDropZoneOverlay`, `PaneTarget`, `.translate`, `CellColorResolverTests`, `ScrollbackFile`, `Section`, `ReplayStep`, `AgentNotchRowSummary`, `ANSIPalette`, `TerminalServicesProvider`, `HarnessPathDisplay`, `CellColorResolver`, `FileChangeWatcher`, `SSHTunnelManagerTests`, `.decide`, `.hitTest`, `HarnessGridTerminalTests`, `ExternalOpenKind`, `p11_scripting.robot`, `.scan`, `graphify reference: incremental update and cluster-only`, `.make`, `.copySelection`, `PaneBorderStatus`, `TerminalMetalRenderer`, `FindWindowMatcherTests`, `.make`, `FileNode`, `.renderFixture`, `ReflowPreviewTests`, `NSViewRepresentable`, `BundledThemesData.swift`, `release-hotfix.sh`, `Sidebar SwiftUI Migration — Knowledge`, `WindowTitleStripView`, `.welcome`, `Browser Pane (P14)`, `reorderSession`, `DisplayPanesOverlay`, `harness-cli.fish`, `Added`, `FormatColor`, `click_ui_element`, `JSONDecoder`, `Fixes Applied (layered)`, `GitHubCLIClient`, `AgentApprovalBar`, `.load`, `settings.json`, `jobs`, `PaneNode`, `HarnessPaths.swift`, `.parse`, `ThemeDiagnostics`, `ViPathTokenTests`, `.selectedText`, `AgentSnapshot`, `Terminal AI Chat (⌘I inline overlay)`, `.unmarkText`, `FormatColor`, `BlockSummary`, `DesktopNotifier`, `FloatingPaneController`, `.theme`, `.reopenClosedTab`, `.recordReapedGenerationForTesting`, `RealPty`, `ImageProtocolTests.swift`, `.makeModel`, `Foundation`, `[2.2.3] - 2026-06-09`, `Architecture Decisions — harness-terminal`, `Memory Leak Audit — 34 GB Long-Session Case (2026-06-26)`, `AutomationScheduler`, `GPU Animation Pattern — Layout Once, GPU Paints`, `[3.5.1] - 2026-06-20`, `FormatStyledSegment.swift`, `[2.2.4] - 2026-06-11`, `Fixes Applied (v3.9.1+)`, `Tab`, `.encode`, `PromptQueue`, `ThaiClusterRenderTests`, `NSTextField Leak in BoardViewController (P20 Performance)`, `Darwin`, `UI Automation — Robot Framework (P18)`, `Split Panes (NSSplitView)`, `AgentIconRenderer`, `Session/Tab/Pane Hierarchy & Top Bar (CASE-028)`, `javascript.json`, `json.json`, `yaml.json`, `HintModeOverlay`, `Bug — Cmd+\ sidebar toggle gone after collapse`, `Competitive Position (as of v3.12.0, 2026-07-02)`, `PathToken`, `LaunchdServiceInstaller`, `.highlight`, `Feature Specs`, `Implementation Phases`, `RawRepresentable`, `BlockContextMenuTests`, `main.swift`, `.update`, `.encode`, `PaneLabelDaemonTests`, `MouseButton`, `ReflowFastPathTests`, `HarnessOnboarding`, `Service Decomposition — SessionCoordinator (P17)`, `terminal-cheat-sheet.html`, `.json`, `ACP Client (Shelved)`, `KittyGraphicsCommand`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Are the 48 inferred relationships involving `Int` (e.g. with `.register()` and `.startStallMonitor()`) actually correct?**
  _`Int` has 48 INFERRED edges - model-reasoned connections that need verification._
- **What connects `unsupportedPlatform`, `unmodified`, `modified` to the rest of the system?**
  _3884 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `CodingKey` be split into smaller, more focused modules?**
  _Cohesion score 0.07629288274449565 - nodes in this community are weakly interconnected._
- **Should `callingPaneTarget` be split into smaller, more focused modules?**
  _Cohesion score 0.07191276156793398 - nodes in this community are weakly interconnected._