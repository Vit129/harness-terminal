# Graphify Navigation Guide - harness-terminal

This is the human-readable map for `graphify-out/graph.json`. The raw graph is still the source for `graphify query`, but this report is optimized for quick code navigation.

## At a Glance
- 8,551 nodes, 15,591 edges, 540 communities.
- 515 source files represented in the graph.
- Edge confidence: 13,930 EXTRACTED, 1,661 INFERRED, 0 AMBIGUOUS.
- Built from commit: `3eb9aab5feea6b2fed416784d01c23c34d66456b`.

## How To Use This Folder
- Start with the subsystem index below, then open the top file listed for that community.
- Use `graphify query "term"` for broad navigation and `graphify explain "NodeName"` for one symbol.
- `graph.json` is the machine-readable graph; `.graphify_labels.json` gives communities readable names.
- If the report looks stale, run `graphify update . --force` from the repo root.

## Best Entry Points
| Area | Open first | Why |
| --- | --- | --- |
| Terminal engine | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Emulator/TerminalEmulator.swift` | VT parser driver, terminal modes, responses, OSC/CSI handling |
| Screen/grid model | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Screen/TerminalScreen.swift` | Cell writes, scrollback, reflow, SGR state, character width behavior |
| AppKit terminal surface | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/HarnessTerminalSurfaceView.swift` | Renderer host, input encoding, selection, resize, parser pipeline |
| Daemon/PTY | `Packages/HarnessDaemon/Sources/HarnessDaemon/SurfaceRegistry.swift` | Surface lifecycle, subscriptions, PTY ownership, daemon state |
| IPC contract | `Packages/HarnessCore/Sources/HarnessCore/IPC/IPCMessage.swift` | GUI/daemon/CLI message schema and payloads |
| GUI coordination | `Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift` | Tabs, sessions, settings, app-level orchestration |
| CLI | `Tools/harness/Sources/HarnessCLI/HarnessCLI.swift` | Attach, control commands, capture/replay entrypoints |
| Tests | `Tests/HarnessTerminalEngineTests/TerminalProtocolCompatibilityTests.swift` | Protocol regressions and terminal behavior examples |

## Subsystem Index
### Terminal Engine
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 0 | 131 | Terminal Engine: Model / TerminalGridModel | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Model/TerminalGridModel.swift`<br>`Packages/HarnessOnboarding/Sources/HarnessOnboarding/TerminalKit/TerminalGrid.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Notch/AgentNotchProjection.swift` |
| 3 | 91 | Terminal Engine: Screen / TerminalScreen | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Screen/TerminalScreen.swift` |
| 8 | 89 | Terminal Engine: Emulator / TerminalEmulator | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Emulator/TerminalEmulator.swift`<br>`Tests/HarnessTerminalEngineTests/TerminalProtocolCompatibilityTests.swift`<br>`Tests/HarnessTerminalEngineTests/EngineConformanceTests.swift` |
| 14 | 56 | Terminal Engine: Parser / VTParser | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Parser/VTParser.swift`<br>`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Emulator/TerminalEmulator.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/ACP/ACPClient.swift` |
| 19 | 47 | Terminal Engine: HarnessTerminalEngine / InputEncoder | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/InputEncoder.swift` |
| 91 | 21 | Terminal Engine: HarnessTerminalEngine / InputEncoder | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/InputEncoder.swift`<br>`Tests/HarnessTerminalEngineTests/EngineConformanceTests.swift` |
| 125 | 16 | Terminal Engine: Screen / HistoryRingBuffer | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Screen/HistoryRingBuffer.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Commands/Command.swift` |
| 280 | 14 | Terminal Engine: Images / DecodedImage | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Images/DecodedImage.swift`<br>`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Images/KittyGraphicsProtocol.swift`<br>`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Images/ImageDecoder.swift` |
| 209 | 11 | Terminal Engine: HarnessTerminalEngine / InputEncoder | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/InputEncoder.swift` |
| 374 | 8 | Terminal Engine: Images / SixelDecoder | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Images/SixelDecoder.swift` |
| 445 | 8 | Terminal Engine: HarnessTerminalEngine / InputEncoder | `Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/InputEncoder.swift` |

### Terminal Kit
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 21 | 98 | Terminal Kit: HarnessTerminalKit / HarnessTerminalSurfaceView | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/HarnessTerminalSurfaceView.swift` |
| 277 | 70 | Terminal Kit: HarnessTerminalKit / HarnessTerminalSurfaceView | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/HarnessTerminalSurfaceView.swift` |
| 66 | 31 | Terminal Kit: HarnessTerminalKit / HarnessTerminalSurfaceView | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/HarnessTerminalSurfaceView.swift` |
| 67 | 24 | Terminal Kit: HarnessTerminalKit / TerminalHostView | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/TerminalHostView.swift` |
| 75 | 23 | Terminal Kit: HarnessTerminalKit / GridCompositor | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/GridCompositor.swift` |
| 162 | 14 | Terminal Kit: HarnessTerminalKit / TerminalFindBar | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/TerminalFindBar.swift` |
| 170 | 13 | Terminal Kit: HarnessTerminalKit / ThemeManager | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/ThemeManager.swift` |
| 163 | 12 | Terminal Kit: HarnessTerminalKit / TerminalHostView | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/TerminalHostView.swift` |
| 235 | 12 | Terminal Kit: HarnessTerminalKit / TerminalHostView | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/TerminalHostView.swift` |
| 132 | 11 | Terminal Kit: HarnessTerminalKit / TerminalHostView | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/TerminalHostView.swift` |
| 269 | 11 | Terminal Kit: HarnessTerminalKit / FrameSignposter | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/FrameSignposter.swift` |
| 281 | 8 | Terminal Kit: HarnessTerminalKit / TerminalScrollbarView | `Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/TerminalScrollbarView.swift` |

### Terminal Renderer
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 16 | 48 | Terminal Renderer: HarnessTerminalRenderer / GlyphRasterizer | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/GlyphRasterizer.swift`<br>`Tests/HarnessTerminalRendererTests/GlyphRasterizerTests.swift`<br>`Tests/HarnessTerminalRendererTests/NerdFontFallbackTests.swift` |
| 185 | 27 | Terminal Renderer: HarnessTerminalRenderer / TerminalFrame | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/TerminalFrame.swift`<br>`Tests/HarnessTerminalRendererTests/MetalRendererTests.swift` |
| 220 | 21 | Terminal Renderer: HarnessTerminalRenderer / GlyphAtlas | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/GlyphAtlas.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Keybindings/KeySpec.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Agents/AgentHookInstaller.swift` |
| 6 | 20 | Terminal Renderer: HarnessTerminalRenderer / TerminalMetalRenderer | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/TerminalMetalRenderer.swift` |
| 193 | 18 | Terminal Renderer: HarnessTerminalRenderer / TerminalMetalRenderer | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/TerminalMetalRenderer.swift` |
| 313 | 17 | Terminal Renderer: HarnessTerminalRenderer / RenderColorConversion | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/RenderColorConversion.swift`<br>`Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/TerminalFrame.swift` |
| 350 | 14 | Terminal Renderer: HarnessTerminalRenderer / ImageTextureCache | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/ImageTextureCache.swift`<br>`Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/DynamicInstanceBuffer.swift`<br>`Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/TerminalMetalRenderer.swift` |
| 428 | 13 | Terminal Renderer: HarnessTerminalRenderer / TerminalMetalRenderer | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/TerminalMetalRenderer.swift` |
| 208 | 11 | Terminal Renderer: HarnessTerminalRenderer / CellColorResolver | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/CellColorResolver.swift` |
| 442 | 11 | Terminal Renderer: HarnessTerminalRenderer / BoxDrawing | `Packages/HarnessTerminalRenderer/Sources/HarnessTerminalRenderer/BoxDrawing.swift` |

### HarnessCore
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 4 | 93 | HarnessCore: Settings / HarnessSettings | `Packages/HarnessCore/Sources/HarnessCore/Settings/HarnessSettings.swift`<br>`Packages/HarnessOnboarding/Sources/HarnessOnboarding/Install/ShellProfileInstaller.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Layouts/LayoutTemplate.swift` |
| 5 | 93 | HarnessCore: IPC / IPCMessage | `Packages/HarnessCore/Sources/HarnessCore/IPC/IPCMessage.swift` |
| 7 | 80 | HarnessCore: Commands / Command | `Packages/HarnessCore/Sources/HarnessCore/Commands/Command.swift` |
| 311 | 70 | HarnessCore: IPC / IPCMessage | `Packages/HarnessCore/Sources/HarnessCore/IPC/IPCMessage.swift`<br>`Packages/HarnessLSP/Sources/HarnessLSP/LSPModels.swift`<br>`Tests/HarnessCoreTests/JSONOutputFormatterTests.swift` |
| 46 | 63 | HarnessCore: Commands / CopyModeAction | `Packages/HarnessCore/Sources/HarnessCore/Commands/CopyModeAction.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Commands/CommandParser.swift` |
| 159 | 60 | HarnessCore: FileExplorer / FileTreeWatcher | `Packages/HarnessCore/Sources/HarnessCore/FileExplorer/FileTreeWatcher.swift`<br>`Tools/harness-mcp/Sources/HarnessMCP/ToolRegistry.swift`<br>`Tests/HarnessCoreTests/FileTreeWatcherTests.swift` |
| 25 | 52 | HarnessCore: Session / SessionEditor | `Packages/HarnessCore/Sources/HarnessCore/Session/SessionEditor.swift`<br>`Tests/HarnessCoreTests/SessionEditorTests.swift` |
| 232 | 48 | HarnessCore: Models / Workspace | `Packages/HarnessCore/Sources/HarnessCore/Models/Workspace.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/FileExplorer/FileNode.swift`<br>`Apps/Harness/Sources/HarnessApp/UI/FileTabManager.swift` |
| 89 | 46 | HarnessCore: Remote / SSHTunnelManager | `Packages/HarnessCore/Sources/HarnessCore/Remote/SSHTunnelManager.swift`<br>`Tests/HarnessCoreTests/SSHTunnelManagerTests.swift` |
| 79 | 44 | HarnessCore: Keybindings / KeyTable | `Packages/HarnessCore/Sources/HarnessCore/Keybindings/KeyTable.swift`<br>`Packages/HarnessTheme/Sources/HarnessTheme/ThemeDocument.swift`<br>`Packages/HarnessLSP/Sources/HarnessLSP/LSPModels.swift` |
| 48 | 42 | HarnessCore: Events / HookRegistry | `Packages/HarnessCore/Sources/HarnessCore/Events/HookRegistry.swift`<br>`Tests/HarnessCoreTests/HookRegistryTests.swift` |
| 36 | 40 | HarnessCore: Session / SessionEditor | `Packages/HarnessCore/Sources/HarnessCore/Session/SessionEditor.swift` |

### Daemon
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 23 | 65 | Daemon: HarnessDaemon / RealPty | `Packages/HarnessDaemon/Sources/HarnessDaemon/RealPty.swift`<br>`Packages/CHarnessSys/shim.c`<br>`Tests/HarnessDaemonTests/RealPtyReapRecordTests.swift` |
| 49 | 34 | Daemon: HarnessDaemon / DaemonServer | `Packages/HarnessDaemon/Sources/HarnessDaemon/DaemonServer.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/IPC/IPCMessage.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Platform/PlatformSys.swift` |
| 64 | 34 | Daemon: HarnessDaemon / SurfaceRegistry | `Packages/HarnessDaemon/Sources/HarnessDaemon/SurfaceRegistry.swift` |
| 130 | 16 | Daemon: HarnessDaemon / DaemonMetrics | `Packages/HarnessDaemon/Sources/HarnessDaemon/DaemonMetrics.swift`<br>`Tests/HarnessDaemonTests/DaemonMetricsTests.swift` |
| 435 | 15 | Daemon: HarnessDaemon / SurfaceRegistry | `Packages/HarnessDaemon/Sources/HarnessDaemon/SurfaceRegistry.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Notifications/AgentNotification.swift` |
| 426 | 10 | Daemon: HarnessDaemon / DaemonLifecycle | `Packages/HarnessDaemon/Sources/HarnessDaemon/DaemonLifecycle.swift` |

### Harness App
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 35 | 76 | Harness App: Settings / SettingsViewController | `Apps/Harness/Sources/HarnessApp/Settings/SettingsViewController.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/ACP/AgentConfig.swift` |
| 11 | 62 | Harness App: UI / TerminalTabBarView | `Apps/Harness/Sources/HarnessApp/UI/TerminalTabBarView.swift` |
| 37 | 60 | Harness App: UI / GitPanelView | `Apps/Harness/Sources/HarnessApp/UI/GitPanelView.swift` |
| 9 | 55 | Harness App: Settings / SettingsViewController | `Apps/Harness/Sources/HarnessApp/Settings/SettingsViewController.swift`<br>`docs/AGENT-HANDBOOK.md` |
| 28 | 44 | Harness App: UI / GitPanelView | `Apps/Harness/Sources/HarnessApp/UI/GitPanelView.swift` |
| 306 | 40 | Harness App: UI / HarnessSidebarPanelViewController | `Apps/Harness/Sources/HarnessApp/UI/HarnessSidebarPanelViewController.swift`<br>`Apps/Harness/Sources/HarnessApp/UI/FileEditorTabBarView.swift`<br>`Packages/HarnessTerminalKit/Sources/HarnessTerminalKit/ResizeHUDView.swift` |
| 53 | 39 | Harness App: UI / MainMenuBuilder | `Apps/Harness/Sources/HarnessApp/UI/MainMenuBuilder.swift` |
| 87 | 39 | Harness App: Services / SessionCoordinator | `Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift` |
| 29 | 36 | Harness App: Services / SessionCoordinator | `Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift` |
| 54 | 35 | Harness App: UI / HarnessSidebarPanelViewController | `Apps/Harness/Sources/HarnessApp/UI/HarnessSidebarPanelViewController.swift` |
| 12 | 32 | Harness App: UI / ContentAreaViewController | `Apps/Harness/Sources/HarnessApp/UI/ContentAreaViewController.swift` |
| 117 | 26 | Harness App: UI / WorkspaceFileTreeView | `Apps/Harness/Sources/HarnessApp/UI/WorkspaceFileTreeView.swift`<br>`.aidlc/harness/ide-file-tree/outputs/inception/logical-design.md` |

### Harness CLI
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 1 | 31 | Harness CLI: HarnessCLI | `Tools/harness/Sources/HarnessCLI/HarnessCLI.swift` |
| 41 | 25 | Harness CLI: HarnessCLI / WindowAttachClient | `Tools/harness/Sources/HarnessCLI/WindowAttachClient.swift` |
| 174 | 25 | Harness CLI: HarnessCLI | `Tools/harness/Sources/HarnessCLI/HarnessCLI.swift`<br>`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Screen/TerminalScreen.swift` |
| 325 | 24 | Harness CLI: HarnessCLI | `Tools/harness/Sources/HarnessCLI/HarnessCLI.swift` |
| 110 | 19 | Harness CLI: HarnessCLI / AttachClient | `Tools/harness/Sources/HarnessCLI/AttachClient.swift` |
| 72 | 17 | Harness CLI: HarnessCLI / WindowAttachClient | `Tools/harness/Sources/HarnessCLI/WindowAttachClient.swift`<br>`agent-memory/knowledge/ipc-architecture.md` |
| 180 | 17 | Harness CLI: HarnessCLI / WindowAttachClient | `Tools/harness/Sources/HarnessCLI/WindowAttachClient.swift` |
| 283 | 17 | Harness CLI: HarnessCLI / WindowAttachClient | `Tools/harness/Sources/HarnessCLI/WindowAttachClient.swift` |
| 227 | 16 | Harness CLI: HarnessCLI / RecordClient | `Tools/harness/Sources/HarnessCLI/RecordClient.swift` |
| 228 | 15 | Harness CLI: HarnessCLI / ControlModeClient | `Tools/harness/Sources/HarnessCLI/ControlModeClient.swift` |
| 295 | 12 | Harness CLI: HarnessCLI / WindowAttachClient | `Tools/harness/Sources/HarnessCLI/WindowAttachClient.swift` |
| 330 | 9 | Harness CLI: HarnessCLI / ReplayClient | `Tools/harness/Sources/HarnessCLI/ReplayClient.swift` |

### LSP
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 322 | 21 | LSP: HarnessLSP / LSPClient | `Packages/HarnessLSP/Sources/HarnessLSP/LSPClient.swift` |
| 285 | 14 | LSP: HarnessLSP / LSPTransport | `Packages/HarnessLSP/Sources/HarnessLSP/LSPTransport.swift` |

### Theme
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 34 | 36 | Theme: HarnessTheme / ThemeDocument | `Packages/HarnessTheme/Sources/HarnessTheme/ThemeDocument.swift`<br>`Tests/HarnessThemeTests/HarnessThemeTests.swift` |
| 118 | 12 | Theme: HarnessTheme / ThemeDiagnostics | `Packages/HarnessTheme/Sources/HarnessTheme/ThemeDiagnostics.swift` |
| 274 | 8 | Theme: HarnessTheme / ThemeFileService | `Packages/HarnessTheme/Sources/HarnessTheme/ThemeFileService.swift` |

### Copy Mode
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 42 | 22 | Copy Mode: HarnessCopyMode / CopyModeState | `Packages/HarnessCopyMode/Sources/HarnessCopyMode/CopyModeState.swift` |
| 127 | 19 | Copy Mode: HarnessCopyMode / CopyModeReducer | `Packages/HarnessCopyMode/Sources/HarnessCopyMode/CopyModeReducer.swift`<br>`Packages/HarnessCopyMode/Sources/HarnessCopyMode/CopyModeState.swift` |
| 181 | 11 | Copy Mode: HarnessCopyMode / CopyModeGridSource | `Packages/HarnessCopyMode/Sources/HarnessCopyMode/CopyModeGridSource.swift`<br>`Tests/HarnessCopyModeTests/ThaiClusterCopyTests.swift` |
| 486 | 9 | Copy Mode: HarnessCopyMode / CopyModeState | `Packages/HarnessCopyMode/Sources/HarnessCopyMode/CopyModeState.swift`<br>`Tests/HarnessCopyModeTests/CopyModeReducerTests.swift` |

### Onboarding
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 155 | 39 | Onboarding: Install / BinaryInstaller | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/Install/BinaryInstaller.swift`<br>`Apps/Harness/Sources/HarnessApp/Services/DefaultTerminalManager.swift` |
| 62 | 26 | Onboarding: TerminalKit / GridCompositor | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/TerminalKit/GridCompositor.swift` |
| 97 | 20 | Onboarding: TerminalKit / PaneLayout | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/TerminalKit/PaneLayout.swift` |
| 100 | 19 | Onboarding: Design / Components | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/Design/Components.swift`<br>`Packages/HarnessOnboarding/Sources/HarnessOnboarding/Design/GlassEffectView.swift`<br>`Packages/HarnessOnboarding/Sources/HarnessOnboarding/UI/DemoSession.swift` |
| 126 | 16 | Onboarding: Design / AgentMark | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/Design/AgentMark.swift` |
| 137 | 14 | Onboarding: UI / ImmersiveOnboardingWindowController | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/UI/ImmersiveOnboardingWindowController.swift`<br>`Apps/Harness/Sources/HarnessApp/UI/Notch/NotchPanel.swift`<br>`Apps/Harness/Sources/HarnessApp/UI/CommandPaletteController.swift` |
| 179 | 12 | Onboarding: UI / WelcomeStepView | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/UI/WelcomeStepView.swift`<br>`Packages/HarnessOnboarding/Sources/HarnessOnboarding/UI/CompleteStepView.swift`<br>`Packages/HarnessOnboarding/Sources/HarnessOnboarding/UI/DiscoverStepView.swift` |
| 261 | 11 | Onboarding: UI / DemoSession | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/UI/DemoSession.swift` |
| 244 | 9 | Onboarding: Design / GlassEffectView | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/Design/GlassEffectView.swift` |
| 245 | 9 | Onboarding: UI / SetupStepView | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/UI/SetupStepView.swift` |
| 267 | 8 | Onboarding: UI / ShellStepView | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/UI/ShellStepView.swift` |
| 355 | 8 | Onboarding: UI / ComposedTerminalView | `Packages/HarnessOnboarding/Sources/HarnessOnboarding/UI/ComposedTerminalView.swift` |

### Tests
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 15 | 73 | Tests: HarnessCoreTests / FormatStringTests | `Tests/HarnessCoreTests/FormatStringTests.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Options/OptionStore.swift`<br>`Apps/Harness/Sources/HarnessApp/UI/StatusLineView.swift` |
| 10 | 63 | Tests: HarnessBenchmarks / PerformanceBenchmarks | `Tests/HarnessBenchmarks/PerformanceBenchmarks.swift`<br>`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Images/SixelDecoder.swift` |
| 13 | 56 | Tests: HarnessTerminalEngineTests / KittyKeyboardTests | `Tests/HarnessTerminalEngineTests/KittyKeyboardTests.swift`<br>`Tests/HarnessTerminalEngineTests/InputEncoderTests.swift`<br>`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/Emulator/TerminalEmulator.swift` |
| 24 | 53 | Tests: HarnessDaemonTests / DaemonRoundTripTests | `Tests/HarnessDaemonTests/DaemonRoundTripTests.swift`<br>`Tests/HarnessDaemonTests/RealPtyLifecycleTests.swift`<br>`Tests/HarnessDaemonTests/TestSupport.swift` |
| 32 | 51 | Tests: HarnessCoreTests / JSONMergeTests | `Tests/HarnessCoreTests/JSONMergeTests.swift`<br>`Tests/HarnessCoreTests/KeyTokenParserTests.swift`<br>`Tests/HarnessTerminalKitTests/SpecialKeyMappingTests.swift` |
| 63 | 51 | Tests: HarnessTerminalKitTests / LiveResizeTests | `Tests/HarnessTerminalKitTests/LiveResizeTests.swift`<br>`Tests/HarnessTerminalKitTests/CellOverlayTests.swift`<br>`Tests/HarnessAppTests/SettingsWindowCloseProxyTests.swift` |
| 27 | 50 | Tests: HarnessTerminalRendererTests / CellColorResolverTests | `Tests/HarnessTerminalRendererTests/CellColorResolverTests.swift`<br>`Packages/HarnessOnboarding/Sources/HarnessOnboarding/TerminalKit/TerminalColor.swift`<br>`Tests/HarnessThemeTests/HarnessThemeTests.swift` |
| 33 | 50 | Tests: HarnessTerminalEngineTests / EngineConformanceTests | `Tests/HarnessTerminalEngineTests/EngineConformanceTests.swift` |
| 47 | 48 | Tests: HarnessDaemonTests / SurfaceRegistryTests | `Tests/HarnessDaemonTests/SurfaceRegistryTests.swift`<br>`Packages/HarnessDaemon/Sources/HarnessDaemon/SurfaceRegistry.swift` |
| 95 | 48 | Tests: HarnessTerminalRendererTests / FrameBuilderTests | `Tests/HarnessTerminalRendererTests/FrameBuilderTests.swift`<br>`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/HarnessGridTerminal.swift`<br>`Tests/HarnessTerminalEngineTests/ClipboardOSCTests.swift` |
| 40 | 46 | Tests: HarnessTerminalEngineTests / ParserRobustnessTests | `Tests/HarnessTerminalEngineTests/ParserRobustnessTests.swift`<br>`Tests/HarnessTerminalEngineTests/EngineConformanceTests.swift`<br>`Packages/HarnessCore/Sources/HarnessCore/Session/SGRMouse.swift` |
| 2 | 40 | Tests: HarnessTerminalRendererTests / MetalRendererTests | `Tests/HarnessTerminalRendererTests/MetalRendererTests.swift` |

### Docs
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 26 | 40 | Docs: HARNESS_TMUX_CAPABILITIES | `docs/HARNESS_TMUX_CAPABILITIES.md` |
| 88 | 31 | Docs: MULTIPLEXER_GUIDE | `docs/MULTIPLEXER_GUIDE.md` |
| 80 | 22 | Docs: AGENT-HANDBOOK | `docs/AGENT-HANDBOOK.md` |
| 119 | 17 | Docs: COMMANDS | `docs/COMMANDS.md` |
| 158 | 16 | Docs: IDE-SIDEBAR | `docs/IDE-SIDEBAR.md` |
| 199 | 11 | Docs: README | `docs/agent-hooks/README.md` |
| 203 | 11 | Docs: KEYBINDINGS | `docs/KEYBINDINGS.md` |
| 204 | 11 | Docs: MIGRATION | `docs/MIGRATION.md` |
| 246 | 9 | Docs: MODES | `docs/MODES.md` |
| 264 | 8 | Docs: claude-code | `docs/agent-hooks/claude-code.md` |
| 265 | 8 | Docs: cursor | `docs/agent-hooks/cursor.md` |

### Agent Memory
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 59 | 33 | Agent Memory: plans / panel-session-performance | `agent-memory/plans/panel-session-performance.md` |
| 92 | 27 | Agent Memory: plans / p2-async-ipc-design | `agent-memory/plans/p2-async-ipc-design.md` |
| 101 | 21 | Agent Memory: plans / session-group-split-session | `agent-memory/plans/session-group-split-session.md` |
| 139 | 20 | Agent Memory: plans / file-viewer-integration | `agent-memory/plans/file-viewer-integration.md` |
| 172 | 18 | Agent Memory: plans / p4-lsp-file-view | `agent-memory/plans/p4-lsp-file-view.md` |
| 189 | 17 | Agent Memory: plans / p5-acp-implementation | `agent-memory/plans/p5-acp-implementation.md` |
| 439 | 14 | Agent Memory: knowledge / acp-client | `agent-memory/knowledge/acp-client.md` |
| 317 | 13 | Agent Memory: Agent Memory / memory | `agent-memory/memory.md` |
| 447 | 11 | Agent Memory: knowledge / ipc-architecture | `agent-memory/knowledge/ipc-architecture.md` |
| 448 | 11 | Agent Memory: knowledge / split-panes | `agent-memory/knowledge/split-panes.md` |
| 333 | 9 | Agent Memory: plans / completed-archive | `agent-memory/plans/completed-archive.md` |
| 431 | 9 | Agent Memory: plans / p6-editor-opacity-parity | `agent-memory/plans/p6-editor-opacity-parity.md` |

### AIDLC
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 60 | 28 | AIDLC: harness / ide-file-tree / outputs / domain-decomposition | `.aidlc/harness/ide-file-tree/outputs/inception/domain-decomposition.md` |
| 77 | 23 | AIDLC: harness / ide-file-tree / outputs / domain-design | `.aidlc/harness/ide-file-tree/outputs/inception/domain-design.md` |
| 98 | 20 | AIDLC: harness / acp / outputs / logical-design | `.aidlc/harness/acp/outputs/inception/logical-design.md` |
| 154 | 20 | AIDLC: harness / ide-file-tree / outputs / logical-design | `.aidlc/harness/ide-file-tree/outputs/inception/logical-design.md` |
| 138 | 15 | AIDLC: harness / acp / planning / 05-implementation | `.aidlc/harness/acp/planning/plans/05-implementation.md` |
| 147 | 15 | AIDLC: harness / ide-file-tree / planning / 05-implementation | `.aidlc/harness/ide-file-tree/planning/plans/05-implementation.md` |
| 177 | 12 | AIDLC: harness / acp / outputs / user-stories | `.aidlc/harness/acp/outputs/inception/user-stories.md` |
| 190 | 12 | AIDLC: harness / ide-file-tree / outputs / user-stories | `.aidlc/harness/ide-file-tree/outputs/inception/user-stories.md` |
| 191 | 12 | AIDLC: harness / ide-file-tree / planning / 00-inception-plan | `.aidlc/harness/ide-file-tree/planning/plans/00-inception-plan.md` |
| 106 | 10 | AIDLC: harness / acp / outputs / domain-design | `.aidlc/harness/acp/outputs/inception/domain-design.md` |
| 223 | 10 | AIDLC: harness / acp / outputs / domain-decomposition | `.aidlc/harness/acp/outputs/inception/domain-decomposition.md` |
| 225 | 10 | AIDLC: harness / acp / planning / 00-inception-decisions | `.aidlc/harness/acp/planning/decisions/00-inception-decisions.md` |

### Agent Instructions
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 262 | 27 | Agent Instructions: AGENTS | `AGENTS.md` |

### Release Notes
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 176 | 23 | Release Notes: CHANGELOG | `CHANGELOG.md` |
| 142 | 22 | Release Notes: CHANGELOG | `CHANGELOG.md` |
| 323 | 19 | Release Notes: CHANGELOG | `CHANGELOG.md` |
| 308 | 17 | Release Notes: CHANGELOG | `CHANGELOG.md` |
| 299 | 16 | Release Notes: CHANGELOG | `CHANGELOG.md` |
| 105 | 14 | Release Notes: CHANGELOG | `CHANGELOG.md` |
| 344 | 11 | Release Notes: CHANGELOG | `CHANGELOG.md` |
| 342 | 9 | Release Notes: CHANGELOG | `CHANGELOG.md` |
| 450 | 9 | Release Notes: CHANGELOG | `CHANGELOG.md` |

### Claude Instructions
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 368 | 9 | Claude Instructions: CLAUDE | `CLAUDE.md` |

### Root Docs
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 149 | 26 | Root Docs: README | `README.md` |
| 38 | 24 | Root Docs: README | `README.md` |
| 366 | 12 | Root Docs: README | `README.md` |

### Scripts
| Community | Nodes | Label | Top files |
| --- | ---: | --- | --- |
| 359 | 14 | Scripts: generate-release-notes | `Scripts/generate-release-notes.swift`<br>`Packages/HarnessTerminalEngine/Sources/HarnessTerminalEngine/URLDetection.swift` |
| 224 | 10 | Scripts: terminal_stress_runner.py | `Scripts/benchmarks/terminal_stress_runner.py` |
| 255 | 10 | Scripts: release-hotfix.sh | `Scripts/release-hotfix.sh` |

## Largest Communities
| Community | Nodes | Readable label | Representative symbols |
| --- | ---: | --- | --- |
| 0 | 131 | Terminal Engine: Model / TerminalGridModel | `Sendable`, `Equatable`, `TerminalGridUnderline`, `ReleaseNotes`, `AgentNotchRowSummary` |
| 21 | 98 | Terminal Kit: HarnessTerminalKit / HarnessTerminalSurfaceView | `HarnessTerminalSurfaceView`, `NSTextInputClient` |
| 4 | 93 | HarnessCore: Settings / HarnessSettings | `String`, `CaseIterable`, `LayoutTemplate`, `Scope`, `ShellProfileInstaller` |
| 5 | 93 | HarnessCore: IPC / IPCMessage | `IPCRequest`, `zoomPane`, `waitFor`, `updateTabTitle`, `updateTabGitBranch` |
| 3 | 91 | Terminal Engine: Screen / TerminalScreen | `TerminalScreen`, `Pen`, `HistoryLine`, `SavedCursor`, `RewrapResult` |
| 8 | 89 | Terminal Engine: Emulator / TerminalEmulator | `TerminalEmulator`, `TerminalProtocolCompatibilityTests`, `TerminalProgressReport`, `CommandFinishedTests`, `params` |
| 7 | 80 | HarnessCore: Commands / Command | `Command`, `zoomPane`, `unlinkWindow`, `unbindKey`, `unbindHook` |
| 35 | 76 | Harness App: Settings / SettingsViewController | `SettingsViewController`, `NSStackView`, `AgentRegistryStore`, `SettingsWindowController`, `NSFontChanging` |
| 15 | 73 | Tests: HarnessCoreTests / FormatStringTests | `OptionStore`, `FormatStringTests`, `FormatStringExtendedVariableTests`, `StatusLineView`, `ScopedKey` |
| 277 | 70 | Terminal Kit: HarnessTerminalKit / HarnessTerminalSurfaceView | `SurfaceEmulatorState`, `SurfaceFrameBuildResult`, `SurfaceFrameBuildConfiguration`, `SurfaceColorProviderState`, `PresentAttempt` |
| 311 | 70 | HarnessCore: IPC / IPCMessage | `Codable`, `LSPMessage`, `DirectionalAxis`, `WorkspaceSummary`, `ResizeDirection` |
| 23 | 65 | Daemon: HarnessDaemon / RealPty | `RealPty`, `shim.c`, `RealPtyReapRecordTests`, `ScrollbackReplaySegment`, `harness_pty_get_winsize()` |
| 10 | 63 | Tests: HarnessBenchmarks / PerformanceBenchmarks | `PerformanceBenchmarks` |
| 46 | 63 | HarnessCore: Commands / CopyModeAction | `CopyModeAction`, `CommandParser`, `CommandParseError`, `Lexer`, `missingArgument` |
| 11 | 62 | Harness App: UI / TerminalTabBarView | `TabPillView`, `TerminalTabBarView`, `TerminalTabBarDelegate`, `TabContextCommand`, `tabDisplayTitle()` |
| 37 | 60 | Harness App: UI / GitPanelView | `GitPanelView`, `NSButton`, `GitHistoryFileButton` |
| 159 | 60 | HarnessCore: FileExplorer / FileTreeWatcher | `ToolRegistry`, `JSONRPCError`, `FileTreeWatcher`, `FileTreeWatcherTests`, `MCPServer` |
| 13 | 56 | Tests: HarnessTerminalEngineTests / KittyKeyboardTests | `KittyKeyboardTests`, `InputEncoderTests`, `TerminalModes`, `Charset`, `decSpecialGraphics` |
| 14 | 56 | Terminal Engine: Parser / VTParser | `VTParser`, `State`, `VTParserHandler`, `CSIParams`, `AnyObject` |
| 9 | 55 | Harness App: Settings / SettingsViewController | `Settings` |
| 24 | 53 | Tests: HarnessDaemonTests / DaemonRoundTripTests | `DaemonClient`, `DaemonRoundTripTests`, `OutputAccumulator`, `RealPtyLifecycleTests`, `DaemonClientActor` |
| 25 | 52 | HarnessCore: Session / SessionEditor | `SessionEditor`, `SessionEditorTests` |
| 32 | 51 | Tests: HarnessCoreTests / JSONMergeTests | `XCTestCase`, `JSONMergeTests`, `SpecialKeyMappingTests`, `KeyTokenParserTests`, `ThemeManagerTests` |
| 63 | 51 | Tests: HarnessTerminalKitTests / LiveResizeTests | `LiveResizeTests`, `NSWindow`, `SettingsWindowCloseProxy`, `SettingsWindowCloseProxyTests` |
| 27 | 50 | Tests: HarnessTerminalRendererTests / CellColorResolverTests | `RGBColor`, `CellColorResolverTests`, `RGBColorTests`, `ANSIPaletteTests`, `ANSIPalette` |
| 33 | 50 | Tests: HarnessTerminalEngineTests / EngineConformanceTests | `EngineConformanceTests` |
| 16 | 48 | Terminal Renderer: HarnessTerminalRenderer / GlyphRasterizer | `GlyphRasterizer`, `GlyphRasterizerTests`, `NerdFontFallbackTests`, `ShapedRunKey`, `ShapedGlyphSignature` |
| 47 | 48 | Tests: HarnessDaemonTests / SurfaceRegistryTests | `SurfaceRegistry`, `SurfaceRegistryTests` |
| 95 | 48 | Tests: HarnessTerminalRendererTests / FrameBuilderTests | `HarnessGridTerminal`, `FrameBuilderTests`, `ClipboardOSCTests` |
| 232 | 48 | HarnessCore: Models / Workspace | `Identifiable`, `OnboardingStep`, `CodingKeys`, `Workspace`, `GitStatusType` |
| 19 | 47 | Terminal Engine: HarnessTerminalEngine / InputEncoder | `SpecialKey`, `up`, `tab`, `scrollLock`, `rightSuper` |
| 40 | 46 | Tests: HarnessTerminalEngineTests / ParserRobustnessTests | `UInt32`, `UInt8`, `ParserRobustnessTests`, `ANSIPalette`, `SGRMouse` |
| 89 | 46 | HarnessCore: Remote / SSHTunnelManager | `SSHTunnelManager`, `SSHTunnelManagerTests`, `SSHTunnelError`, `invalidConfiguration`, `Tunnel` |
| 28 | 44 | Harness App: UI / GitPanelView | `NSTextField`, `refresh()`, `runGit()`, `runAndRefresh()`, `addWorktreeAction()` |
| 79 | 44 | HarnessCore: Keybindings / KeyTable | `CodingKeys`, `KeyTable`, `Binding`, `KeyTableSet`, `CodingKey` |
| 48 | 42 | HarnessCore: Events / HookRegistry | `HookEvent`, `HookRegistry`, `HookRegistryTests`, `SeededIDs`, `windowUnlinked` |
| 2 | 40 | Tests: HarnessTerminalRendererTests / MetalRendererTests | `MetalRendererTests`, `RenderedFixture` |
| 26 | 40 | Docs: HARNESS_TMUX_CAPABILITIES | `Harness tmux-style capabilities`, `1. Five-minute setup`, `12. Agent notifications`, `9. Key binding customization`, `8. Command prompt and scripting` |
| 36 | 40 | HarnessCore: Session / SessionEditor | - |
| 306 | 40 | Harness App: UI / HarnessSidebarPanelViewController | `NSView`, `WorkspaceSwitcherRow`, `ResizeHUDView`, `WindowBorderOverlayView`, `FileTabPill` |
| 53 | 39 | Harness App: UI / MainMenuBuilder | `MenuTarget`, `MainMenuBuilder`, `NSMenuItemValidation` |
| 87 | 39 | Harness App: Services / SessionCoordinator | - |
| 155 | 39 | Onboarding: Install / BinaryInstaller | `BinaryInstaller`, `DefaultTerminalManager`, `CopyOutcome`, `DetectionStatus`, `ProbeOutputBox` |
| 43 | 38 | Tests: HarnessTerminalKitTests / RenderSchedulerTests | `RenderSchedulerTests`, `RenderScheduler` |
| 121 | 38 | Tests: HarnessTerminalKitTests / CellOverlayTests | `TerminalSelection`, `CellOverlayTests`, `BlockSelection`, `FrameBuilderCopyModeTests`, `ITerm2InlineImage` |
| 84 | 37 | Tests: HarnessCoreTests / CommandParserTests | `CommandParserTests` |
| 29 | 36 | Harness App: Services / SessionCoordinator | `SessionCoordinator` |
| 34 | 36 | Theme: HarnessTheme / ThemeDocument | `ThemeDocumentTests`, `ThemeDocument`, `Colors`, `ContrastGrade`, `ThemeDocumentError` |
| 54 | 35 | Harness App: UI / HarnessSidebarPanelViewController | `HarnessSidebarPanelViewController` |
| 31 | 34 | Tests: HarnessCoreTests / IPCCodecTests | `IPCCodecTests`, `IPCEnvelope` |
| 49 | 34 | Daemon: HarnessDaemon / DaemonServer | `DaemonServer`, `setNoSigPipe()`, `WriteOutcome`, `CountBox`, `clients` |
| 64 | 34 | Daemon: HarnessDaemon / SurfaceRegistry | `PanePipe` |
| 90 | 34 | Tests: HarnessCoreTests / AgentNotchProjectionTests | `SessionGroup`, `AgentSnapshot`, `AgentSessionSummary`, `AgentNotchProjectionTests`, `AgentSessionSummaryTests` |
| 55 | 33 | Tests: HarnessCoreTests / AgentHookInstallerTests | `AgentHookInstallerTests` |
| 59 | 33 | Agent Memory: plans / panel-session-performance | `3.2 สิ่งที่ implement แล้ว`, `2. ปัญหาและแนวทางแก้ไข (Issues & Fixes)`, `6. สิ่งที่ยังเหลือ (Remaining Work)`, `✅ F1-G — FSEvents live watcher — DONE`, `P2 — Async IPC refactor` |
| 76 | 33 | HarnessCore: Agents / AgentSnapshot | `AgentKind`, `AgentActivity`, `InstallResult`, `InstallError`, `AgentTitleInference` |
| 12 | 32 | Harness App: UI / ContentAreaViewController | `ContentAreaViewController` |
| 81 | 32 | Tests: HarnessCoreTests / DaemonClientTests | `DaemonSubscription`, `sysClose()`, `DaemonClientTests`, `makeUnixSocketPair()`, `FrameRecorder` |
| 409 | 32 | Tests: HarnessCLITests | `HarnessCLITests` |
| 1 | 31 | Harness CLI: HarnessCLI | `flagValue()`, `checkedRequest()`, `handleNewSplit()`, `handleNewSession()`, `resolveWorkspaceID()` |

## Noise To Be Aware Of
- The current graph includes planning docs and agent-memory files. They are useful for historical context but can dominate searches for broad terms like `session`, `plan`, or `agent`.
- No `.graphifyignore` exists in this repo, so future rebuilds may include worktrees or generated assets unless ignore rules are added before rebuilding.
- Tests are intentionally present. For implementation tasks, prefer source packages first and use the matching test community after finding the behavior path.

## Regeneration Notes
- This report was compacted from the existing `graphify-out/graph.json`; it did not re-extract the graph.
- `.graphify_labels.json` was rewritten with readable community names derived from dominant source files.
- To rebuild the underlying graph after adding ignore rules, run `graphify update . --force`.
