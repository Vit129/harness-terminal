import AppKit
import Darwin
import HarnessCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var menuBarController: MenuBarController?
    private var externalOpenReady = false
    private var queuedExternalOpenURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        StartupMetrics.shared.mark(.launchStart)
        // Build the UI immediately so launch never blocks on the daemon. The
        // coordinator starts from a default snapshot and repopulates the moment
        // the daemon answers (below) — no frozen window, no modal timeout dialog.
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        StartupMetrics.shared.mark(.firstWindow)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.mainMenu = MainMenuBuilder.build()
        // Menu-bar status item: workspaces + active agents, read from the daemon
        // (shell-agnostic). Lives for the app's lifetime.
        menuBarController = MenuBarController()
        PrefixKeymap.shared.install()
        SurfaceShellTracker.shared.start()
        // Request notification authorization once at launch instead of on every
        // notification post. macOS only shows the system prompt the first time
        // and silently denies after; doing it eagerly means notifications can
        // start arriving as soon as the first agent transitions to `waiting`.
        DesktopNotifier.requestAuthorizationIfNeeded()

        // Locate/spawn the daemon off the main thread, then sync from real state.
        DaemonLauncher.shared.ensureRunning { ok in
            if ok { StartupMetrics.shared.mark(.daemonConnected) }
            SessionCoordinator.shared.syncFromDaemon()
            if !ok {
                SessionCoordinator.shared.noteDaemonError(DaemonClientError.timeout)
            }
            Self.reconcileSessionPersistenceWithModeOnce()
            OnboardingController.presentIfNeeded()
            self.externalOpenReady = true
            self.drainQueuedExternalOpenURLs()
        }
    }

    /// One-shot: align the daemon's keep-on-quit default with the chosen experience the first
    /// time we launch with modes. A fresh Plain install becomes ephemeral; an upgraded install
    /// (already keep-on-quit + migrated to Tmux) is a no-op. Keyed so it never overrides a
    /// later explicit choice the user makes in Settings.
    private static func reconcileSessionPersistenceWithModeOnce() {
        let key = "HarnessModePersistenceReconciledV1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let keep = SessionCoordinator.shared.settings.experienceMode.persistsSessionsByDefault
        SessionCoordinator.shared.requestDaemon(.setKeepSessionsOnQuit(keep))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Closing the last window quits the app; the daemon (launchd-managed)
        // keeps sessions alive in the background so reopening reattaches.
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The daemon is owned by launchd and intentionally outlives the GUI — never tear it
        // down on quit. Persistent sessions and scrollback stay alive so `harness-cli attach`
        // and a subsequent app launch see the same state.
        //
        // Ephemeral sessions (Plain mode, not pinned) are the exception: on a *clean* quit we
        // close them so Plain feels like a normal terminal. This is a clean-quit-only contract
        // — a crash or force-quit leaves everything running (the daemon can't tell a crash from
        // "keep my work"), and the next clean quit will reap them. The request is synchronous so
        // it completes before the process exits.
        _ = SessionCoordinator.shared.requestDaemon(.closeEphemeralSessions)
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

    private func enqueueExternalOpen(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        if externalOpenReady {
            DefaultTerminalOpener.open(urls)
        } else {
            queuedExternalOpenURLs.append(contentsOf: urls)
        }
    }

    private func drainQueuedExternalOpenURLs() {
        guard externalOpenReady, !queuedExternalOpenURLs.isEmpty else { return }
        let urls = queuedExternalOpenURLs
        queuedExternalOpenURLs.removeAll()
        DefaultTerminalOpener.open(urls)
    }
}
