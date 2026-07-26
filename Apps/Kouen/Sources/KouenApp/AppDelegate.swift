import AppKit
import Darwin
import KouenCore
import KouenTerminalKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var menuBarController: MenuBarController?
    private var notchController: NotchPanelController?
    private var terminalServicesProvider: TerminalServicesProvider?
    /// Observes the macOS system appearance so auto light/dark theme switching can follow it.
    private var appearanceObservation: NSKeyValueObservation?
    private var externalOpenReady = false
    private var queuedExternalOpens: [QueuedExternalOpen] = []

    private struct QueuedExternalOpen {
        let url: URL
        let asWindow: Bool
        let kind: ExternalOpenKind
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("DEBUG: Bundle.main.object(forInfoDictionaryKey: 'KouenPreviewHome'): \(String(describing: Bundle.main.object(forInfoDictionaryKey: "KouenPreviewHome")))")
        NSLog("DEBUG: KouenPaths.applicationSupport: \(KouenPaths.applicationSupport.path)")
        NSLog("DEBUG: KouenPaths.socketURL: \(KouenPaths.socketURL.path)")
        StartupMetrics.shared.mark(.launchStart)
        // Build the UI immediately so launch never blocks on the daemon. The
        // coordinator starts from a default snapshot and repopulates the moment
        // the daemon answers (below) — no frozen window, no modal timeout dialog.
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        StartupMetrics.shared.mark(.firstWindow)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.mainMenu = MainMenuBuilder.build()
        // Finder folder right-click "New Kouen Tab/Window Here" (declared in Info.plist NSServices).
        // NSApp.servicesProvider does not retain the provider, so hold it for the app's lifetime.
        let servicesProvider = TerminalServicesProvider()
        terminalServicesProvider = servicesProvider
        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()
        // Menu-bar status item: workspaces + active agents, read from the daemon
        // (shell-agnostic). Lives for the app's lifetime.
        menuBarController = MenuBarController()
        notchController = NotchPanelController.shared
        notchController?.start()
        PrefixKeymap.shared.install()
        QuickTerminalController.shared.install()
FloatingPaneController.shared.install()
        AppIdleThrottle.shared.install()
        WorktreeAutoIsolateService.shared.start()
        BrowserPaneRegistry.shared.prewarm()

        // Fix #8 (RL-040): Swallow key/mouse events targeting views that lost their window.
        // On macOS 26.5 + Swift 6.3, the @objc thunk crashes with EXC_BAD_ACCESS
        // when dispatching to a freed first-responder. This monitor fires before dispatch.
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .mouseMoved, .mouseEntered, .mouseExited]) { event in
            guard event.window != nil else { return event }
            if let responder = event.window?.firstResponder as? NSView, responder.window == nil {
                return nil
            }
            return event
        }
        ScriptHookCoordinator.shared.start()
        // Follow the macOS system appearance for auto light/dark theme switching. The startup
        // application happens post-daemon-sync below (so the theme change reaches a ready daemon);
        // this observer handles every later Light/Dark flip.
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                SessionCoordinator.shared.applyAutoThemeForCurrentAppearance()
                self?.mainWindowController?.applyChrome()
                Self.updateDockIconForCurrentAppearance()
            }
        }
        Self.updateDockIconForCurrentAppearance()
        // Request notification authorization once at launch instead of on every
        // notification post. macOS only shows the system prompt the first time
        // and silently denies after; doing it eagerly means notifications can
        // start arriving as soon as the first agent transitions to `waiting`.
        DesktopNotifier.requestAuthorizationIfNeeded()

        // Locate/spawn the daemon off the main thread, then sync from real state.
        DaemonLauncher.shared.ensureRunning { ok in
            if ok { StartupMetrics.shared.mark(.daemonConnected) }
            Task {
                let synced = await SessionCoordinator.shared.syncFromDaemon()
                if !ok || !synced {
                    SessionCoordinator.shared.noteDaemonError(DaemonClientError.timeout)
                }
                // Apply the auto light/dark theme now that the daemon is hydrated (so the theme change
                // lands), then refresh the window chrome to match.
                SessionCoordinator.shared.applyAutoThemeForCurrentAppearance()
                self.mainWindowController?.applyChrome()
                Self.reconcileSessionPersistenceWithMode()
                OnboardingController.presentIfNeeded()
                Task { await Self.checkForGitCloneUpdate() }
                self.externalOpenReady = true
                if synced {
                    self.drainQueuedExternalOpenURLs()
                } else if !self.queuedExternalOpens.isEmpty {
                    // Daemon wasn't hydrated yet: opening a queued URL/.command now would create its tab
                    // against a not-ready daemon and be dropped. Retry the drain on a bounded backoff
                    // until a sync succeeds, instead of losing the open.
                    self.retryQueuedExternalOpenDrain(attempt: 0)
                }
            }
        }
    }

    private static let modePersistenceLastAppliedKey = "KouenModePersistenceLastAppliedMode"

    /// Record that `mode`'s keep-on-quit default has been applied to the daemon, so the next
    /// launch's reconcile treats the mode as settled. Called after the launch-time apply below and
    /// from Settings when a preset switch applies the default live — without the latter, that
    /// switch would look like a cross-launch mode change and re-clobber any keep-on-quit override
    /// the user made after switching.
    static func recordModePersistenceApplied(_ mode: ExperienceMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: modePersistenceLastAppliedKey)
    }

    /// Align the daemon's keep-on-quit default with the chosen experience whenever the mode
    /// *changes* across launches. Switching presets (Plain ⇄ Persistent/Full/Agent) re-applies that
    /// preset's default; a stable mode is left untouched so an explicit in-Settings keep-on-quit
    /// override — or a per-session / per-tab pin — is never clobbered on relaunch. (The old V1 flag
    /// was a permanent one-shot, so a later mode switch silently failed to re-sync persistence.)
    /// A fresh Plain install becomes ephemeral; an upgraded Full install keeps sessions.
    /// macOS has no static asset-catalog mechanism for a "mac" idiom app icon to auto-swap with
    /// system appearance (that's iOS/iPadOS-only, or Xcode 26's GUI-only Icon Composer `.icon`
    /// format) — so the Dock tile is swapped here instead, at runtime, the same way many
    /// third-party Mac apps fake it. Only affects the running app's Dock icon; Finder/Launchpad/
    /// Get Info keep the static Info.plist icon since those are read before the process exists.
    private static func updateDockIconForCurrentAppearance() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        guard isDark else {
            NSApp.applicationIconImage = nil // falls back to the bundle's default (light) icon
            return
        }
        guard let path = Bundle.main.path(forResource: "AppIcon-1024-dark", ofType: "png"),
              let image = NSImage(contentsOfFile: path) else { return }
        NSApp.applicationIconImage = image
        NSApp.dockTile.display()
    }

    private static func reconcileSessionPersistenceWithMode() {
        let defaults = UserDefaults.standard
        let mode = SessionCoordinator.shared.settings.experienceMode
        // Upgrade seed: installs that ran the old one-shot (V1) reconcile already have a settled —
        // possibly user-overridden — keep-on-quit value in the daemon. Treat the current mode as
        // already applied instead of re-imposing its default, which would clobber an explicit
        // Settings override (e.g. a Plain user who pinned keep-on-quit on would lose sessions on
        // the next quit).
        if defaults.string(forKey: modePersistenceLastAppliedKey) == nil,
           defaults.bool(forKey: "KouenModePersistenceReconciledV1") {
            recordModePersistenceApplied(mode)
            return
        }
        guard defaults.string(forKey: modePersistenceLastAppliedKey) != mode.rawValue else { return }
        let keep = mode.persistsSessionsByDefault
        // Record the applied mode ONLY after the daemon accepts the default. A launch while the
        // daemon is still spawning would otherwise burn the key without ever applying the mode's
        // keep-on-quit default — leaving a fresh Plain install wrongly persistent forever.
        guard SessionCoordinator.shared.requestDaemon(.setKeepSessionsOnQuit(keep)) != nil else { return }
        recordModePersistenceApplied(mode)
    }

    /// Best-effort, one-shot per launch: offers to pull a newer git-clone checkout. Fired as its
    /// own unstructured Task (not awaited) so a slow fetch or a user sitting on the confirmation
    /// alert never delays `externalOpenReady`/queued-open drain above. A fetch failure, a build
    /// that isn't a git checkout, or an already-dismissed version is silently a no-op — see
    /// `GitCloneUpdateChecker`'s doc comment.
    private static func checkForGitCloneUpdate() async {
        guard let result = await GitCloneUpdateChecker.check() else { return }

        guard !result.dirty else {
            let alert = NSAlert()
            alert.messageText = "Kouen update available (v\(result.currentVersion) → v\(result.remoteVersion))"
            alert.informativeText = "\(result.summary)\n\nYour checkout has uncommitted changes — commit or stash, then pull manually later."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Kouen update available (v\(result.currentVersion) → v\(result.remoteVersion))"
        alert.informativeText = "\(result.updated): \(result.summary)\n\nPull the latest changes now?"
        alert.alertStyle = .informational
        let pullButton = alert.addButton(withTitle: "Pull Now")
        let laterButton = alert.addButton(withTitle: "Not Now")
        pullButton.keyEquivalent = ""
        laterButton.keyEquivalent = ""

        guard alert.runModal() == .alertFirstButtonReturn else {
            GitCloneUpdateChecker.dismiss(version: result.remoteVersion)
            return
        }

        let pull = await GitCloneUpdateChecker.pull(gitRoot: result.gitRoot)
        let resultAlert = NSAlert()
        resultAlert.messageText = pull.success ? "Update pulled" : "git pull failed"
        resultAlert.informativeText = pull.success
            ? (pull.output.isEmpty ? "Restart Kouen to pick up the update." : pull.output)
            : (pull.output.isEmpty ? "Resolve the conflict manually." : pull.output)
        resultAlert.alertStyle = pull.success ? .informational : .warning
        resultAlert.addButton(withTitle: "OK")
        resultAlert.runModal()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Closing the last window quits the app; the daemon (launchd-managed)
        // keeps sessions alive in the background so reopening reattaches.
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The daemon is owned by launchd and intentionally outlives the GUI — never tear it
        // down on quit. Persistent sessions and scrollback stay alive so `kouen-cli attach`
        // and a subsequent app launch see the same state.
        //
        // Ephemeral sessions (Plain mode, not pinned) are the exception: on a *clean* quit we
        // close them so Plain feels like a normal terminal. This is a clean-quit-only contract
        // — a crash or force-quit leaves everything running (the daemon can't tell a crash from
        // "keep my work"), and the next clean quit will reap them. Synchronous + longer-timeout +
        // single retry so a momentarily busy daemon still reaps before the process exits.
        SessionCoordinator.shared.closeEphemeralSessionsBeforeQuit()
        ActivityAssertionManager.shared.releaseAll()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        enqueueExternalOpen(urls)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        enqueueExternalOpen(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    /// Entry point for the Finder "New Kouen Tab/Window Here" services (`TerminalServicesProvider`).
    /// Reuses the external-open queue so a service fired at cold launch waits for the daemon.
    func handleServiceOpen(directories: [URL], asWindow: Bool) {
        enqueueExternalOpen(directories, asWindow: asWindow)
    }

    private func enqueueExternalOpen(_ urls: [URL], asWindow: Bool = false) {
        guard !urls.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        if externalOpenReady {
            // Theme files import/apply (touching settings + a setTheme IPC); everything else opens
            // a terminal exactly as before. Both paths need a hydrated daemon, so when not ready
            // each URL is queued with its kind and handled on the drain.
            performExternalOpen(urls.map { QueuedExternalOpen(url: $0, asWindow: asWindow, kind: ExternalOpenKind(for: $0)) })
        } else {
            queuedExternalOpens.append(contentsOf: urls.map {
                QueuedExternalOpen(url: $0, asWindow: asWindow, kind: ExternalOpenKind(for: $0))
            })
        }
    }

    /// Route each opened URL by kind: `.kouentheme` files go through the theme importer, all
    /// others through the terminal opener. Terminal opens batch (one `DefaultTerminalOpener.open`
    /// preserves the existing folder/asWindow semantics); theme and file-preview opens are handled individually.
    private func performExternalOpen(_ opens: [QueuedExternalOpen]) {
        let terminalOpens = opens.filter { $0.kind == .terminal }
        for open in opens where open.kind == .theme {
            ThemeImportController.handle(open.url)
        }
        for open in opens where open.kind == .filePreview {
            openFilePreview(url: open.url)
        }
        for open in terminalOpens {
            DefaultTerminalOpener.open([open.url], asWindow: open.asWindow)
        }
    }

    private func openFilePreview(url: URL) {
        let split = (NSApp.keyWindow?.contentViewController as? MainSplitViewController)
                 ?? (NSApp.mainWindow?.contentViewController as? MainSplitViewController)
        split?.previewExternalFile(path: url.path)
    }

    private func drainQueuedExternalOpenURLs() {
        guard externalOpenReady, !queuedExternalOpens.isEmpty else { return }
        let opens = queuedExternalOpens
        queuedExternalOpens.removeAll()
        performExternalOpen(opens)
    }

    /// Bounded retry to drain opens that were queued at launch when the daemon wasn't yet hydrated.
    /// Re-syncs each tick; once a sync succeeds the queued URLs open against a ready daemon. ~10s cap
    /// so a permanently-down daemon doesn't retry forever.
    private func retryQueuedExternalOpenDrain(attempt: Int) {
        guard !queuedExternalOpens.isEmpty, attempt < 20 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.queuedExternalOpens.isEmpty else { return }
            Task {
                if await SessionCoordinator.shared.syncFromDaemon() {
                    self.drainQueuedExternalOpenURLs()
                } else {
                    self.retryQueuedExternalOpenDrain(attempt: attempt + 1)
                }
            }
        }
    }
}

