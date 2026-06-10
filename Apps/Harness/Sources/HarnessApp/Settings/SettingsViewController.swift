import AppKit
import HarnessCore
import HarnessTerminalKit
import UserNotifications

@MainActor
final class SettingsViewController: NSViewController, NSFontChanging {
    let themePopup = HarnessSelect(frame: .zero)
    let fontSizeField = HarnessTextField()
    let fontFamilyField = NSTextField() // backing store for the chosen font (not shown)
    let fontReadout = NSTextField(labelWithString: "")
    let shellField = HarnessTextField()
    let cwdField = HarnessTextField()
    let opacitySlider = HarnessSlider(frame: .zero)
    let opacityLabel = NSTextField(labelWithString: "")
    let blurSlider = HarnessSlider(frame: .zero)
    let blurLabel = NSTextField(labelWithString: "")
    let paddingXField = HarnessTextField()
    let paddingYField = HarnessTextField()
    let backgroundHexField = HarnessTextField()
    let foregroundHexField = HarnessTextField()
    let cursorHexField = HarnessTextField()
    let backgroundWell = HarnessSwatchWell(frame: .zero)
    let foregroundWell = HarnessSwatchWell(frame: .zero)
    let cursorWell = HarnessSwatchWell(frame: .zero)
    let useThemeColorsButton = NSButton()
    let scrollbackField = HarnessTextField()
    let transparentTitlebarToggle = HarnessToggle(title: "Transparent title bar")
    let showStatusLineToggle = HarnessToggle(title: "Show status line (bottom bar)")
    let sidebarVisibleToggle = HarnessToggle(title: "Show sidebar")
    let sidebarOnRightToggle = HarnessToggle(title: "Sidebar on right")
    let restoreWindowSizeToggle = HarnessToggle(title: "Remember window size")
    let experienceSegment = HarnessSegmented(frame: .zero)
    // Per-component overrides for the chrome the experience preset would otherwise bundle. Each is
    // tri-state (Auto / On / Off): Auto follows the selected preset; On/Off pin the component
    // independently, so e.g. a Plain terminal can show a status line without arming the prefix.
    let prefixControlSegment = HarnessSegmented(frame: .zero)
    let statusLineControlSegment = HarnessSegmented(frame: .zero)
    let textRenderingSegment = HarnessSegmented(frame: .zero)
    let offMainPipelineToggle = HarnessToggle(title: "Off-main render pipeline")
    let liveResizeReflowToggle = HarnessToggle(title: "Real-time resize")
    let experienceSummaryLabel = NSTextField(wrappingLabelWithString: "")
    let cursorStyleSegment = HarnessSegmented(frame: .zero)
    let cursorBlinkToggle = HarnessToggle(title: "Blinking cursor")
    let copyOnSelectToggle = HarnessToggle(title: "Copy text to clipboard on selection")
    let keepSessionsToggle = HarnessToggle(title: "Keep sessions running after the window closes")
    let defaultTerminalButton = NSButton(title: "Set Harness as default terminal", target: nil, action: nil)
    let defaultTerminalStatusField = NSTextField(wrappingLabelWithString: "")
    let vividColorsToggle = HarnessToggle(title: "Vivid color rendering (Display P3 opt-in)")
    let themeTerminalOutputToggle = HarnessToggle(title: "Apply theme colors to terminal output — off = canvas matches theme, output untouched")
    let ligaturesToggle = HarnessToggle(title: "Programming ligatures (=>, !=, ->) for fonts that have them")
    let promptGutterToggle = HarnessToggle(title: "Prompt gutter — green/red stripe marking command success (needs shell integration)")
    let selectionBgHexField = HarnessTextField()
    let selectionFgHexField = HarnessTextField()
    let boldHexField = HarnessTextField()
    let cursorTextHexField = HarnessTextField()
    let dividerHexField = HarnessTextField()
    let statusLineHexField = HarnessTextField()
    let selectionBgWell = HarnessSwatchWell(frame: .zero)
    let selectionFgWell = HarnessSwatchWell(frame: .zero)
    let boldWell = HarnessSwatchWell(frame: .zero)
    let cursorTextWell = HarnessSwatchWell(frame: .zero)
    let dividerWell = HarnessSwatchWell(frame: .zero)
    let statusLineWell = HarnessSwatchWell(frame: .zero)
    let windowBorderHexField = HarnessTextField()
    let windowBorderWell = HarnessSwatchWell(frame: .zero)
    let windowBorderOpacitySlider = HarnessSlider(frame: .zero)
    let windowBorderOpacityLabel = NSTextField(labelWithString: "")
    let systemNotificationsToggle = HarnessToggle(title: "Show a macOS banner")
    let notificationSoundToggle = HarnessToggle(title: "Play a sound")
    let notchModeSegment = HarnessSegmented(frame: .zero)
    let notchOpenOnHoverToggle = HarnessToggle(title: "Open when I hover near the macOS notch")
    /// One toggle per `NotificationEvent` ("which events notify me"). Built from the enum so a
    /// new case automatically gets a wired row. Lazy so its (main-actor) `HarnessToggle`
    /// construction runs at first access inside a method, not in a stored-property initializer.
    lazy var eventToggles: [NotificationEvent: HarnessToggle] = {
        var toggles: [NotificationEvent: HarnessToggle] = [:]
        for event in NotificationEvent.allCases {
            toggles[event] = HarnessToggle(title: event.title)
        }
        return toggles
    }()
    let commandFinishedThresholdField = HarnessTextField()
    let notchSummaryLabel = NSTextField(wrappingLabelWithString: "")
    // QoL additions: resize overlay (T1), balanced padding (T2), minimum contrast (T5),
    // auto light/dark (T6), paste protection (E).
    let resizeOverlaySegment = HarnessSegmented(frame: .zero)
    let resizeOverlayPositionSegment = HarnessSegmented(frame: .zero)
    let paddingBalanceToggle = HarnessToggle(title: "Center grid (distribute padding evenly)")
    let autoThemeToggle = HarnessToggle(title: "Match the macOS light/dark appearance")
    let lightThemePopup = HarnessSelect(frame: .zero)
    let darkThemePopup = HarnessSelect(frame: .zero)
    let minContrastSlider = HarnessSlider(frame: .zero)
    let minContrastLabel = NSTextField(labelWithString: "")
    let pasteProtectionToggle = HarnessToggle(title: "Confirm risky pastes (multi-line or control characters)")
    let boldIsBrightToggle = HarnessToggle(title: "Bold uses bright colors")
    let notificationTestButton = NSButton(title: "Send Test Notification", target: nil, action: nil)
    let notificationPermissionButton = NSButton(title: "Open System Settings…", target: nil, action: nil)
    let notificationStatusField = NSTextField(labelWithString: "")
    let pageContainer = NSView()
    var pages: [Int: NSView] = [:]
    var currentPage: Int = 0
    /// Group-card surfaces + hairline dividers, tracked so a live theme change can
    /// re-skin them (they're created inline by the `settingsGroup`/`groupDivider`
    /// factories rather than stored individually).
    var groupSurfaces: [NSView] = []
    var groupDividers: [NSView] = []
    /// Text-link buttons (accent baked into the attributed title) re-tinted on theme change.
    var linkButtons: [NSButton] = []
    var paletteWells: [HarnessSwatchWell] = []
    var paletteHexValues: [String?] = Array(repeating: nil, count: 16)
    var agentColorWells: [AgentKind: HarnessSwatchWell] = [:]
    var agentIconViews: [AgentKind: NSImageView] = [:]
    var colorBindings: [ColorBinding] = []
    var keyRecorder: KeyRecorderView!
    /// Live "Installed ✓ / Install hooks" buttons keyed by agent (Agents page).
    var hookButtons: [AgentKind: NSButton] = [:]
    /// "Enable for Chat" toggles keyed by agent (Agents page).
    var chatToggles: [AgentKind: NSButton] = [:]
    var acpAgentRows: NSStackView?
    var lastChromeSignature: String?
    /// Daemon-owned `OptionStore` values, fetched on page build. Keyed by option name.
    var advValues: [String: String] = [:]
    enum AdvKind { case toggle, segment, field }
    var advOptKeys: [ObjectIdentifier: (key: String, kind: AdvKind)] = [:]
    /// Whether the last `loadAdvancedValues` reached the daemon. False = the overlaid values are
    /// builtin defaults, NOT the live daemon state — so the page warns and disables its controls
    /// (a change couldn't be applied) instead of silently presenting defaults as if real.
    var advDaemonReachable = true
    /// The daemon-backed controls (set-option surface), disabled when the daemon is unreachable.
    /// Excludes the performance toggles, which write local settings and stay usable offline.
    var advDaemonControls: [NSControl] = []

    struct ColorBinding {
        let field: HarnessTextField
        let well: HarnessSwatchWell
        let reset: NSButton
        let keyPath: WritableKeyPath<HarnessSettings, String?>
        let themeColor: () -> String?
    }

    enum ColorFormMetrics {
        static let swatchWidth: CGFloat = 42
        static let swatchHeight: CGFloat = 28
        static let labelWidth: CGFloat = 118
        static let fieldWidth: CGFloat = 116
        static let resetSlotWidth: CGFloat = 24
    }

    static let defaultAnsiPalette = [
        ThemeManager.defaultBaselinePaletteHex[0],
        ThemeManager.defaultBaselinePaletteHex[1],
        ThemeManager.defaultBaselinePaletteHex[2],
        ThemeManager.defaultBaselinePaletteHex[3],
        ThemeManager.defaultBaselinePaletteHex[4],
        ThemeManager.defaultBaselinePaletteHex[5],
        ThemeManager.defaultBaselinePaletteHex[6],
        ThemeManager.defaultBaselinePaletteHex[7],
        ThemeManager.defaultBaselinePaletteHex[8],
        ThemeManager.defaultBaselinePaletteHex[9],
        ThemeManager.defaultBaselinePaletteHex[10],
        ThemeManager.defaultBaselinePaletteHex[11],
        ThemeManager.defaultBaselinePaletteHex[12],
        ThemeManager.defaultBaselinePaletteHex[13],
        ThemeManager.defaultBaselinePaletteHex[14],
        ThemeManager.defaultBaselinePaletteHex[15],
    ]
    static let ansiNames = [
        "0 Black", "1 Red", "2 Green", "3 Yellow", "4 Blue", "5 Magenta", "6 Cyan", "7 White",
        "8 Bright Black", "9 Bright Red", "10 Bright Green", "11 Bright Yellow",
        "12 Bright Blue", "13 Bright Magenta", "14 Bright Cyan", "15 Bright White",
    ]
    static let agentColorKinds: [AgentKind] = [
        .codex, .claudeCode, .cursor, .grok, .pi, .hermes,
        .openClaw, .openCode, .aider, .gemini, .goose, .antigravity, .kiro,
    ]

    deinit {
        // A fresh controller is built on each open and the previous one is torn down; drop
        // its observers (the chrome-change observer + the per-field text-change observers
        // registered in `configureLiveAppearanceField`) so a closed window stops reacting.
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 880, height: 660))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureControls()
        layoutShell()
        showPage(0)
        observeChromeChanges()
    }

    // MARK: - Control configuration (initial state from settings)

    private func configureControls() {
        let coordinator = SessionCoordinator.shared
        let settings = coordinator.settings

        themePopup.removeAllItems()
        for name in ThemeManager.allThemeNames() {
            themePopup.addItem(withTitle: name)
        }
        themePopup.selectItem(withTitle: coordinator.snapshot.themeName)
        themePopup.target = self
        themePopup.action = #selector(themeDidChange)

        fontSizeField.stringValue = String(format: "%.0f", settings.fontSize)
        fontSizeField.target = self
        fontSizeField.action = #selector(appearanceTextDidCommit)
        fontFamilyField.stringValue = settings.fontFamily
        shellField.stringValue = settings.defaultShell
        shellField.target = self
        shellField.action = #selector(appearanceTextDidCommit)
        cwdField.stringValue = settings.defaultCWD
        cwdField.target = self
        cwdField.action = #selector(appearanceTextDidCommit)

        // 5%–100% range; 5% floor prevents an invisible window if someone slams to 0.
        opacitySlider.minValue = 0.05
        opacitySlider.maxValue = 1.0
        opacitySlider.doubleValue = Double(settings.backgroundOpacity)
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityDidChange)
        opacitySlider.onCommit = { [weak self] in self?.flushAndApply() }
        opacitySlider.isContinuous = true
        opacityLabel.stringValue = formatPercent(settings.backgroundOpacity)
        opacityLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        opacityLabel.textColor = .secondaryLabelColor
        opacitySlider.toolTip = "Window background opacity (5%–100%)"

        blurSlider.minValue = 0
        blurSlider.maxValue = 100
        blurSlider.doubleValue = Double(settings.backgroundBlur)
        blurSlider.target = self
        blurSlider.action = #selector(blurDidChange)
        blurSlider.onCommit = { [weak self] in self?.flushAndApply() }
        blurSlider.isContinuous = true
        blurLabel.stringValue = formatBlur(settings.backgroundBlur)
        blurLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        blurLabel.textColor = .secondaryLabelColor
        blurSlider.toolTip = "Backdrop blur for the whole window (terminal + chrome), 0–100 px."

        windowBorderOpacitySlider.minValue = 0
        windowBorderOpacitySlider.maxValue = 1
        windowBorderOpacitySlider.doubleValue = Double(settings.windowBorderOpacity)
        windowBorderOpacitySlider.target = self
        windowBorderOpacitySlider.action = #selector(windowBorderOpacityDidChange)
        windowBorderOpacitySlider.onCommit = { [weak self] in self?.flushAndApply() }
        windowBorderOpacitySlider.isContinuous = true
        windowBorderOpacityLabel.stringValue = formatPercent(settings.windowBorderOpacity)
        windowBorderOpacityLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        windowBorderOpacityLabel.textColor = .secondaryLabelColor
        windowBorderOpacitySlider.toolTip = "Faint hairline around the window edge — 0% hides it. Color in Colors ▸ Chrome."

        paddingXField.stringValue = String(format: "%.0f", settings.windowPaddingX)
        paddingXField.target = self
        paddingXField.action = #selector(appearanceTextDidCommit)
        paddingYField.stringValue = String(format: "%.0f", settings.windowPaddingY)
        paddingYField.target = self
        paddingYField.action = #selector(appearanceTextDidCommit)

        colorBindings = [
            ColorBinding(
                field: backgroundHexField, well: backgroundWell, reset: makeResetButton(),
                keyPath: \.customBackgroundHex,
                themeColor: { ThemeManager.backgroundHex(themeName: SessionCoordinator.shared.snapshot.themeName) }
            ),
            ColorBinding(
                field: foregroundHexField, well: foregroundWell, reset: makeResetButton(),
                keyPath: \.customForegroundHex,
                themeColor: { ThemeManager.foregroundHex(themeName: SessionCoordinator.shared.snapshot.themeName) }
            ),
            ColorBinding(
                field: cursorHexField, well: cursorWell, reset: makeResetButton(),
                keyPath: \.customCursorHex,
                themeColor: { ThemeManager.cursorHex(themeName: SessionCoordinator.shared.snapshot.themeName) }
            ),
            ColorBinding(
                field: cursorTextHexField, well: cursorTextWell, reset: makeResetButton(),
                keyPath: \.cursorTextHex,
                themeColor: { ThemeManager.cursorTextHex(themeName: SessionCoordinator.shared.snapshot.themeName) }
            ),
            ColorBinding(
                field: selectionBgHexField, well: selectionBgWell, reset: makeResetButton(),
                keyPath: \.selectionBackgroundHex,
                themeColor: { ThemeManager.selectionBackgroundHex(themeName: SessionCoordinator.shared.snapshot.themeName) }
            ),
            ColorBinding(
                field: selectionFgHexField, well: selectionFgWell, reset: makeResetButton(),
                keyPath: \.selectionForegroundHex,
                themeColor: { ThemeManager.selectionForegroundHex(themeName: SessionCoordinator.shared.snapshot.themeName) }
            ),
            ColorBinding(
                field: boldHexField, well: boldWell, reset: makeResetButton(),
                keyPath: \.boldColorHex,
                themeColor: { ThemeManager.boldHex(themeName: SessionCoordinator.shared.snapshot.themeName) }
            ),
            // Window-chrome accents: the hairline dividers and the status line text.
            // Always honored — not gated by `useCustomColors` — since these are pure
            // chrome and the user explicitly opted in by setting a hex.
            ColorBinding(
                field: dividerHexField, well: dividerWell, reset: makeResetButton(),
                keyPath: \.dividerHex,
                // Match MainSplitViewController.resolvedDividerColor: #1E1E1E on dark themes.
                themeColor: {
                    HarnessChrome.current.isDark
                        ? HarnessChromePalette.defaultDarkDividerHex
                        : ThemeManager.foregroundHex(themeName: SessionCoordinator.shared.snapshot.themeName)
                }
            ),
            ColorBinding(
                field: statusLineHexField, well: statusLineWell, reset: makeResetButton(),
                keyPath: \.statusLineHex,
                themeColor: { ThemeManager.foregroundHex(themeName: SessionCoordinator.shared.snapshot.themeName) }
            ),
            ColorBinding(
                field: windowBorderHexField, well: windowBorderWell, reset: makeResetButton(),
                keyPath: \.windowBorderHex,
                // Match MainWindowController.applyTransparency: white on dark themes, black on
                // light (opacity makes the hairline read as a faint grey).
                themeColor: { HarnessChrome.current.isDark ? "#FFFFFF" : "#000000" }
            ),
        ]
        for binding in colorBindings {
            // Every color is directly editable; an unset (nil) field falls back to
            // the active theme preset inside the resolver.
            let hex = settings[keyPath: binding.keyPath]
            binding.field.stringValue = hex ?? ""
            configureLiveAppearanceField(binding.field)
            configureColorWell(binding.well)
            configureResetButton(binding.reset)
            refreshColorBinding(binding)
        }

        paletteHexValues = HarnessSettings.normalizedPalette(settings.paletteHex)
        buildPaletteWells()
        buildAgentColorWells(settings: settings)

        scrollbackField.stringValue = String(settings.scrollbackLines)
        scrollbackField.target = self
        scrollbackField.action = #selector(appearanceTextDidCommit)

        experienceSegment.setSegments(ExperienceMode.allCases.map(\.displayName))
        experienceSegment.selectItem(withTitle: settings.experienceMode.displayName)
        experienceSegment.target = self
        experienceSegment.action = #selector(experienceModeChanged)
        experienceSummaryLabel.font = .systemFont(ofSize: 11.5)
        experienceSummaryLabel.textColor = .secondaryLabelColor
        experienceSummaryLabel.stringValue = settings.experienceMode.summary

        cursorStyleSegment.setSegments(["Block", "Beam", "Underline"])
        cursorStyleSegment.selectItem(withTitle: cursorStyleTitle(settings.cursorStyle))
        cursorStyleSegment.target = self
        cursorStyleSegment.action = #selector(appearanceTextDidCommit)
        cursorBlinkToggle.state = settings.cursorBlink ? .on : .off
        cursorBlinkToggle.target = self
        cursorBlinkToggle.action = #selector(appearanceTextDidCommit)
        copyOnSelectToggle.state = settings.copyOnSelect ? .on : .off
        copyOnSelectToggle.target = self
        copyOnSelectToggle.action = #selector(appearanceTextDidCommit)
        // Daemon-owned (not a HarnessSettings field) — reflects snapshot truth and
        // commits via IPC on its own action.
        keepSessionsToggle.state = SessionCoordinator.shared.snapshot.keepSessionsOnQuit ? .on : .off
        keepSessionsToggle.target = self
        keepSessionsToggle.action = #selector(toggleKeepSessions)
        defaultTerminalButton.target = self
        defaultTerminalButton.action = #selector(setDefaultTerminalClicked)
        defaultTerminalButton.bezelStyle = .rounded
        defaultTerminalButton.controlSize = .regular
        defaultTerminalStatusField.font = .systemFont(ofSize: 11.5)
        defaultTerminalStatusField.textColor = .secondaryLabelColor
        defaultTerminalStatusField.maximumNumberOfLines = 2
        refreshDefaultTerminalStatus()
        vividColorsToggle.state = settings.colorRendering == .vivid ? .on : .off
        vividColorsToggle.target = self
        vividColorsToggle.action = #selector(appearanceTextDidCommit)
        textRenderingSegment.setSegments(["Native", "Crisp", "Soft"])
        textRenderingSegment.selectItem(withTitle: textRenderingTitle(settings.textRendering))
        textRenderingSegment.target = self
        textRenderingSegment.action = #selector(appearanceTextDidCommit)
        themeTerminalOutputToggle.state = settings.applyThemeToTerminalOutput ? .on : .off
        themeTerminalOutputToggle.target = self
        themeTerminalOutputToggle.action = #selector(appearanceTextDidCommit)
        ligaturesToggle.state = settings.ligatures ? .on : .off
        ligaturesToggle.target = self
        ligaturesToggle.action = #selector(appearanceTextDidCommit)
        promptGutterToggle.state = settings.showPromptGutter ? .on : .off
        promptGutterToggle.target = self
        promptGutterToggle.action = #selector(appearanceTextDidCommit)

        transparentTitlebarToggle.state = settings.transparentTitlebar ? .on : .off
        transparentTitlebarToggle.target = self
        transparentTitlebarToggle.action = #selector(appearanceTextDidCommit)

        showStatusLineToggle.state = settings.showStatusLine ? .on : .off
        showStatusLineToggle.target = self
        showStatusLineToggle.action = #selector(appearanceTextDidCommit)

        sidebarVisibleToggle.state = settings.sidebarVisible ? .on : .off
        sidebarVisibleToggle.target = self
        sidebarVisibleToggle.action = #selector(sidebarVisibilityChanged)

        sidebarOnRightToggle.state = settings.sidebarOnRight ? .on : .off
        sidebarOnRightToggle.target = self
        sidebarOnRightToggle.action = #selector(sidebarOnRightChanged)

        restoreWindowSizeToggle.state = settings.restoreWindowSize ? .on : .off
        restoreWindowSizeToggle.target = self
        restoreWindowSizeToggle.action = #selector(restoreWindowSizeChanged)

        // Optional Harness controls without switching experience mode, now decoupled into two
        // independent tri-states. Auto follows the preset; On/Off pin each via `prefixKeyEnabled` /
        // `statusLineEnabled`. The legacy umbrella `harnessControlsEnabled` is preserved on disk and
        // acts as the fallback when a component is Auto, so existing settings keep their behavior.
        prefixControlSegment.setSegments(["Auto", "On", "Off"])
        prefixControlSegment.selectItem(withTitle: harnessControlsTitle(settings.prefixKeyEnabled))
        prefixControlSegment.target = self
        prefixControlSegment.action = #selector(prefixControlChanged)

        statusLineControlSegment.setSegments(["Auto", "On", "Off"])
        statusLineControlSegment.selectItem(withTitle: harnessControlsTitle(settings.statusLineEnabled))
        statusLineControlSegment.target = self
        statusLineControlSegment.action = #selector(statusLineControlChanged)

        offMainPipelineToggle.state = settings.offMainParserFramePipeline ? .on : .off
        offMainPipelineToggle.target = self
        offMainPipelineToggle.action = #selector(appearanceTextDidCommit)

        liveResizeReflowToggle.state = settings.liveResizeReflow ? .on : .off
        liveResizeReflowToggle.target = self
        liveResizeReflowToggle.action = #selector(appearanceTextDidCommit)

        // Resize overlay (T1)
        resizeOverlaySegment.setSegments(["After first", "Always", "Never"])
        resizeOverlaySegment.selectItem(withTitle: resizeOverlayTitle(settings.resizeOverlay))
        resizeOverlaySegment.target = self
        resizeOverlaySegment.action = #selector(appearanceTextDidCommit)
        resizeOverlayPositionSegment.setSegments(["Center", "Top right", "Bottom right"])
        resizeOverlayPositionSegment.selectItem(withTitle: resizeOverlayPositionTitle(settings.resizeOverlayPosition))
        resizeOverlayPositionSegment.target = self
        resizeOverlayPositionSegment.action = #selector(appearanceTextDidCommit)
        // Balanced padding (T2)
        paddingBalanceToggle.state = settings.windowPaddingBalance ? .on : .off
        paddingBalanceToggle.target = self
        paddingBalanceToggle.action = #selector(appearanceTextDidCommit)
        // Minimum contrast (T5)
        minContrastSlider.minValue = 1
        minContrastSlider.maxValue = 21
        minContrastSlider.doubleValue = settings.minimumContrast
        minContrastSlider.isContinuous = true
        minContrastSlider.target = self
        minContrastSlider.action = #selector(minContrastChanged)
        minContrastSlider.onCommit = { [weak self] in self?.flushAndApply() }
        updateMinContrastLabel()
        // Paste protection (E)
        pasteProtectionToggle.state = settings.pasteProtection ? .on : .off
        pasteProtectionToggle.target = self
        pasteProtectionToggle.action = #selector(appearanceTextDidCommit)
        boldIsBrightToggle.state = settings.boldIsBright ? .on : .off
        boldIsBrightToggle.target = self
        boldIsBrightToggle.action = #selector(appearanceTextDidCommit)
        // Per-event notification toggles ("which events notify me").
        for (event, toggle) in eventToggles {
            toggle.state = settings.isEventEnabled(event) ? .on : .off
            toggle.target = self
            toggle.action = #selector(appearanceTextDidCommit)
        }
        commandFinishedThresholdField.stringValue = String(settings.commandFinishedThresholdSeconds)
        commandFinishedThresholdField.target = self
        commandFinishedThresholdField.action = #selector(appearanceTextDidCommit)
        // Auto light/dark (T6): both pickers seed from the current theme when unset; the single
        // theme picker is disabled while auto drives the active theme.
        let autoThemeOn = settings.lightThemeName != nil && settings.darkThemeName != nil
        autoThemeToggle.state = autoThemeOn ? .on : .off
        autoThemeToggle.target = self
        autoThemeToggle.action = #selector(autoThemeChanged)
        for popup in [lightThemePopup, darkThemePopup] {
            popup.removeAllItems()
            for name in ThemeManager.allThemeNames() { popup.addItem(withTitle: name) }
            popup.target = self
            popup.action = #selector(autoThemeChanged)
            popup.isEnabled = autoThemeOn
        }
        lightThemePopup.selectItem(withTitle: settings.lightThemeName ?? coordinator.snapshot.themeName)
        darkThemePopup.selectItem(withTitle: settings.darkThemeName ?? coordinator.snapshot.themeName)
        themePopup.isEnabled = !autoThemeOn

        useThemeColorsButton.title = "Use Theme Colors"
        useThemeColorsButton.target = self
        useThemeColorsButton.action = #selector(useThemeColors)

        keyRecorder = KeyRecorderView(initial: settings.prefixKey)
        keyRecorder.onChange = { value in
            // Empty = disable the prefix entirely (honored via `effectivePrefixKey`); don't
            // silently snap back to Ctrl-A the way the old code did.
            SessionCoordinator.shared.settings.prefixKey = value
            try? SessionCoordinator.shared.settings.save()
            PrefixKeymap.shared.rebuildFromSettings()
        }

        updateFontReadout()
    }

    // MARK: - Shell layout (sidebar + paged content)

    private func layoutShell() {
        view.wantsLayer = true
        view.layer?.backgroundColor = HarnessChrome.current.terminalBackground.cgColor

        let sidebar = buildSidebar()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebar)

        pageContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageContainer)

        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: view.topAnchor),
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 220),

            pageContainer.topAnchor.constraint(equalTo: view.topAnchor),
            pageContainer.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            pageContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        pages[0] = buildAppearancePage()
        pages[1] = buildColorsPage()
        pages[2] = buildTerminalPage()
        pages[3] = buildKeysPage()
        pages[4] = buildAgentsPage()
        pages[5] = buildAdvancedPage()
    }

    fileprivate func showPage(_ index: Int) {
        for button in sidebarButtons { button.isSelected = (button.tag == index) }
        for subview in pageContainer.subviews { subview.removeFromSuperview() }
        // Rebuild the Advanced page each time it's shown so it re-checks daemon reachability (and
        // re-fetches live option values): a daemon that was down when Settings opened may be back,
        // and vice-versa. The other pages are static enough to stay cached.
        if index == 5 { pages[5] = buildAdvancedPage() }
        guard let page = pages[index] else { return }
        page.translatesAutoresizingMaskIntoConstraints = false
        pageContainer.addSubview(page)
        NSLayoutConstraint.activate([
            page.topAnchor.constraint(equalTo: pageContainer.topAnchor),
            page.leadingAnchor.constraint(equalTo: pageContainer.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: pageContainer.trailingAnchor),
            page.bottomAnchor.constraint(equalTo: pageContainer.bottomAnchor),
        ])
        currentPage = index
    }

    // MARK: - Sidebar

    private var sidebarButtons: [SettingsSidebarButton] = []
    private let settingsSearch = HarnessSearchField()
    let sidebarTitleLabel = NSTextField(labelWithString: "Settings")
    private static let sectionKeywords: [Int: [String]] = [
        0: ["appearance", "theme", "opacity", "blur", "padding", "window", "transparent", "titlebar", "sidebar", "restore", "remember", "size"],
        1: ["colors", "color", "background", "foreground", "cursor", "selection", "palette", "ansi", "vivid", "ligatures", "divider", "status", "soft", "native", "crisp", "rendering", "gamma"],
        2: ["terminal", "font", "shell", "directory", "scrollback", "blink", "copy", "session", "harness", "controls", "experience"],
        3: ["keys", "prefix", "binding", "keybinding", "shortcut"],
        4: ["agents", "agent", "color", "codex", "claude", "cursor", "pi", "hermes", "openclaw", "hook", "notification", "notify", "banner", "bell", "sound", "detection"],
        5: ["advanced", "options", "status", "mouse", "mode", "clipboard", "base-index", "renumber", "monitor", "rename", "repeat", "history", "pane", "border", "harness-cli", "set-option", "performance", "pipeline", "render", "identity", "term_program", "xtversion", "shift+enter", "kitty", "ghostty"],
    ]

    private func buildSidebar() -> NSView {
        // A plain layer-backed view carrying the same themed sidebar chrome (vibrancy +
        // tint) the main window's sidebar uses — never the system `.sidebar` material,
        // which adds a blue cast that breaks the deep-black look.
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        HarnessDesign.applySidebarChrome(to: container)

        let title = sidebarTitleLabel
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = HarnessChrome.current.textPrimary
        title.translatesAutoresizingMaskIntoConstraints = false

        settingsSearch.placeholderString = "Search"
        settingsSearch.onChange = { [weak self] query in self?.filterSections(query) }
        settingsSearch.translatesAutoresizingMaskIntoConstraints = false

        let buttons = NSStackView()
        buttons.orientation = .vertical
        buttons.alignment = .width
        buttons.spacing = 2
        buttons.translatesAutoresizingMaskIntoConstraints = false

        sidebarButtons.removeAll()
        let entries: [(String, String)] = [
            ("Appearance", "paintbrush"),
            ("Colors", "paintpalette"),
            ("Terminal", "terminal"),
            ("Keys", "keyboard"),
            ("Agents", "sparkles"),
            ("Advanced", "slider.horizontal.3"),
        ]
        for (index, entry) in entries.enumerated() {
            let button = SettingsSidebarButton(title: entry.0, symbol: entry.1)
            button.tag = index
            button.isSelected = index == 0
            button.target = self
            button.action = #selector(sidebarItemClicked(_:))
            buttons.addArrangedSubview(button)
            sidebarButtons.append(button)
        }

        container.addSubview(title)
        container.addSubview(settingsSearch)
        container.addSubview(buttons)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 26),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            settingsSearch.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            settingsSearch.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            settingsSearch.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            buttons.topAnchor.constraint(equalTo: settingsSearch.bottomAnchor, constant: 16),
            buttons.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            buttons.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])
        return container
    }

    private func filterSections(_ raw: String) {
        let query = raw.lowercased().trimmingCharacters(in: .whitespaces)
        for button in sidebarButtons {
            if query.isEmpty {
                button.isHidden = false
                continue
            }
            let title = button.buttonTitle.lowercased()
            let keywords = Self.sectionKeywords[button.tag] ?? []
            let hits = title.contains(query) || keywords.contains(where: { $0.contains(query) })
            button.isHidden = !hits
        }
    }


    @objc private func sidebarItemClicked(_ sender: SettingsSidebarButton) {
        showPage(sender.tag)
    }
}

@MainActor
final class SettingsFlippedView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class SettingsSidebarButton: NSControl {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovered = false { didSet { applyChrome() } }
    var isSelected = false { didSet { applyChrome() } }
    let buttonTitle: String

    init(title: String, symbol: String) {
        self.buttonTitle = title
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.stringValue = title
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
        ])
        applyChrome()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        if let target, let action {
            _ = NSApp.sendAction(action, to: target, from: self)
        }
    }

    func applyChrome() {
        let c = HarnessChrome.current
        if isSelected {
            layer?.backgroundColor = c.rowSelectedFill.cgColor
            iconView.contentTintColor = c.accent
            label.textColor = c.textPrimary
        } else if isHovered {
            layer?.backgroundColor = c.rowHoverFill.cgColor
            iconView.contentTintColor = c.textSecondary
            label.textColor = c.textPrimary
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            iconView.contentTintColor = c.textTertiary
            label.textColor = c.textSecondary
        }
    }
}

/// Settings opens as a standard, movable, closable macOS window on top of the main
/// window (not embedded). A fresh controller is built on each open so the window always
/// reflects the current theme/settings; any previously open instance is closed first.
@MainActor
enum SettingsWindowController {
    private static var window: NSWindow?
    /// Retained for the window's lifetime so its `windowWillClose` flush actually fires (NSWindow
    /// holds the delegate weakly). Closing the prior window drops the old proxy.
    private static var closeProxy: SettingsWindowCloseProxy?

    static func show(page: Int = 0) {
        window?.close()
        let controller = SettingsViewController()
        let win = NSWindow(contentViewController: controller)
        win.title = "Settings"
        win.styleMask = [.titled, .closable, .resizable]
        win.titlebarAppearsTransparent = false
        win.titleVisibility = .visible
        win.isMovableByWindowBackground = false
        win.isRestorable = false
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 840, height: 600)
        win.setContentSize(NSSize(width: 940, height: 680))
        // Persist on close (incl. via the titlebar button) so a slider drag that never got its
        // mouse-up still saves its live-applied value (#89). Mirrors `viewWillDisappear`; both are
        // safe to fire because `persistPendingState` is idempotent.
        let proxy = SettingsWindowCloseProxy { [weak controller] in controller?.persistPendingState() }
        win.delegate = proxy
        closeProxy = proxy
        window = win
        // Match the active theme's light/dark so the native titlebar + any system-colored
        // text track the themed chrome (mirrors MainWindowController).
        win.appearance = NSAppearance(named: HarnessChrome.current.isDark ? .darkAqua : .aqua)
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if page != 0 { controller.showPage(page) }
    }
}

/// Thin `NSWindowDelegate` that flushes the settings controller's pending state when the settings
/// window closes. Kept separate from the view controller so the controller doesn't have to be the
/// window's delegate (it isn't responsible for window lifecycle), and retained by
/// `SettingsWindowController` since NSWindow holds its delegate weakly.
@MainActor
final class SettingsWindowCloseProxy: NSObject, NSWindowDelegate {
    private let onWillClose: () -> Void
    init(onWillClose: @escaping () -> Void) { self.onWillClose = onWillClose }
    func windowWillClose(_ notification: Notification) { onWillClose() }
}
