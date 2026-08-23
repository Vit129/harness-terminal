import Foundation
import KouenCore
import KouenSettings

/// Single source of truth for Kouen session layout and notifications.
/// @unchecked Sendable: all access to `sessions` and `editor` is serialized by `lock`.
public final class SurfaceRegistry: @unchecked Sendable {
    private var sessions: [DaemonSurfaceID: RealPty] = [:]
    private var editor = SessionEditor()
    private let store = SessionStore()
    private let lock = NSLock()
    private let bufferStore = PasteBufferStore()
    private let taskStore = TaskStore()
    private let automationStore = AutomationStore()
    private let routingRuleStore = AgentRoutingRuleStore()
    private let savedLayoutStore = SavedLayoutStore()
    public let optionStore = OptionStore()
    public let environmentStore = EnvironmentStore()
    public let hookRegistry = HookRegistry()
    private let persistedDefaultShell: String?
    /// One-shot first-run / post-update banner, consumed by the first freshly created
    /// surface (see `injectVersionBannerIfPending`). nil when disabled (tests, embedded
    /// registries) or once shown for this build.
    private var pendingVersionBanner: PendingVersionBanner?
    private let versionBannerStore = VersionBannerStore()
    /// Set when the seen-build ack failed to reach disk (full disk, permissions): retried
    /// on later surface creations — without re-rendering the banner — so a transient write
    /// failure can't replay the one-shot card on the next daemon start.
    private var versionAckRetryNeeded = false
    /// tmux `show-messages`: recent rendered display-message lines (most recent last),
    /// capped so a chatty hook can't grow the daemon. Own lock (not `lock`): appends
    /// come from both the IPC handler (lock held) and hook firing (hookQueue, no lock).
    private var messageLog: [String] = []
    private let messageLogLock = NSLock()
    private static let messageLogCap = 50
    /// Opt-in lock/output instrumentation (off unless `KOUEN_DAEMON_METRICS=1`),
    /// surfaced via the `SIGUSR1` stats log. `DaemonServer` records output
    /// notifications and backlog through this same instance.
    public let metrics = DaemonMetrics()
    /// Hooks fire fire-and-forget here, never under `lock`, so a hook-bound command
    /// can re-enter `handle` (which locks) without deadlocking. Serial so hook
    /// reactions run in the order their events occurred.
    private let hookQueue = DispatchQueue(label: "com.vit129.kouen.hooks")
    private var hookExecutor: DaemonCommandExecutor?
    private let hookExecutionHelper: HookExecutor
    /// Invoked after every layout commit with the new revision. `DaemonServer` uses
    /// this to push `snapshotChanged` to snapshot subscribers (the compositor).
    public var onSnapshotCommitted: ((Int) -> Void)?

    // MARK: Monitoring (Phase 5)
    /// Cheap per-surface output state, updated on the PTY read thread and drained by
    /// `processMonitors` on a timer. Kept off `lock` (its own tiny lock) so the hot output
    /// path never contends with layout mutations.
    private struct SurfaceMonitor {
        var sawOutput = false
        var sawBell = false
        var lastOutput = Date()
        /// OSC-aware bell-scan state, carried across PTY chunks (a sequence can split over reads).
        var bellScan: SurfaceRegistry.BellScanState = .normal
    }

    /// State for the lightweight bell scan in `noteSurfaceOutput`. A BEL (0x07) is a real terminal
    /// bell only in `normal`; a BEL terminating or inside a string sequence (OSC/DCS/APC/PM/SOS) is
    /// not — most importantly the OSC 133 prompt marks shell integration emits on every prompt.
    enum BellScanState: Equatable { case normal, esc, string, stringEsc }

    /// Scan `data` for real control-BELs, threading `state` across calls so a sequence split across
    /// chunks is handled. Returns true if a genuine bell (not a string-sequence terminator) was
    /// seen. Static + pure so it is unit-testable.
    static func scanForBell(_ data: Data, state: inout BellScanState) -> Bool {
        var sawBell = false
        for byte in data {
            switch state {
            case .normal:
                if byte == 0x1B { state = .esc }
                else if byte == 0x07 { sawBell = true }
            case .esc:
                switch byte {
                case 0x5D, 0x50, 0x5F, 0x5E, 0x58: state = .string   // OSC ] / DCS P / APC _ / PM ^ / SOS X
                case 0x1B: state = .esc                              // ESC restarts escape parsing
                case 0x07: sawBell = true; state = .normal           // BEL after a non-string ESC: real
                default: state = .normal                             // CSI, ST, other escapes
                }
            case .string:
                // A BEL terminates an OSC (xterm) and is data inside the others — never a bell.
                // CAN/SUB abort a string sequence (as the VT parser does), so an unterminated string
                // can't pin the scanner and swallow every later bell.
                if byte == 0x07 { state = .normal }
                else if byte == 0x18 || byte == 0x1A { state = .normal } // CAN / SUB abort
                else if byte == 0x1B { state = .stringEsc }
            case .stringEsc:
                if byte == 0x5C { state = .normal }                  // ST (ESC \) terminates the string
                else if byte == 0x1B { state = .stringEsc }          // another ESC; keep waiting
                else { state = .string }                             // ESC was data; stay in the string
            }
        }
        return sawBell
    }
    private var monitors: [String: SurfaceMonitor] = [:]
    private let monitorLock = NSLock()
    private var monitorTimer: DispatchSourceTimer?

    public init(enableVersionBanner: Bool = false) {
        self.hookExecutionHelper = HookExecutor(hookRegistry: hookRegistry, hookQueue: hookQueue)
        let defaultShell = KouenSettings.load().defaultShell
        let trimmedDefaultShell = defaultShell.trimmingCharacters(in: .whitespacesAndNewlines)
        persistedDefaultShell = trimmedDefaultShell.isEmpty ? nil : defaultShell
        // Captured before `store.load()` materializes anything: "no layout.json" is what
        // distinguishes a true first install (welcome banner) from an update (what's-new).
        let hadExistingLayout = FileManager.default.fileExists(atPath: KouenPaths.snapshotURL.path)
        if enableVersionBanner {
            let lastSeen = versionBannerStore.loadLastSeenBuild()
            pendingVersionBanner = VersionBannerStore.decidePending(
                lastSeenBuild: lastSeen,
                currentBuild: KouenVersion.build,
                hadExistingLayout: hadExistingLayout
            )
            // A downgrade shows nothing, but records the lower build so the eventual
            // re-upgrade banners again.
            if pendingVersionBanner == nil, let lastSeen, lastSeen != KouenVersion.build {
                versionBannerStore.markSeen()
            }
        }
        editor.snapshot = store.load()
        if editor.snapshot.workspaces.isEmpty {
            editor.snapshot = SessionSnapshot()
            try? store.saveImmediately(editor.snapshot)
        }
        ensureAllSnapshotSurfaces()
        // A first install has no layout to restore — the seeded default tab IS the first
        // surface the user ever sees, so the welcome banner lands there instead of waiting
        // for an explicit new-tab. Updates keep restored panes untouched (banner waits for
        // the first user-created surface).
        if !hadExistingLayout, pendingVersionBanner != nil,
           let firstID = editor.snapshot.workspaces.first?.sessions.first?.tabs.first?
               .rootPane.allSurfaceIDs().first,
           let firstSession = sessions[firstID.uuidString] {
            injectVersionBannerIfPending(into: firstSession, columns: 80)
        }
        cleanupOrphanScrollbackFiles()
        // Wire hook execution: bound commands run server-side via the registry's own
        // handlers. `fire` invokes this on `hookQueue` (off-lock), so re-entering
        // `handle` here is safe.
        let executor = DaemonCommandExecutor(registry: self)
        hookExecutor = executor
        hookRegistry.setExecutor { command, context in
            executor.execute(command, context: context)
        }
        startMonitorTimer()
    }

    // MARK: - Output monitoring (activity / silence / bell)

    private func startMonitorTimer() {
        let timer = DispatchSource.makeTimerSource(queue: hookQueue)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in self?.processMonitors() }
        timer.resume()
        monitorTimer = timer
    }

    /// Stop the periodic activity/silence/bell monitor timer (orderly daemon shutdown / tests).
    public func stopMonitoring() {
        monitorTimer?.cancel()
        monitorTimer = nil
    }

    /// Record output for a surface — runs on the PTY read thread, so it must stay cheap
    /// (no `lock`, no snapshot walk): just flag output / bell and stamp the time.
    private func noteSurfaceOutput(surfaceKey: String, data: Data) {
        monitorLock.lock()
        var m = monitors[surfaceKey] ?? SurfaceMonitor()
        m.sawOutput = true
        m.lastOutput = Date()
        // Parser-aware bell: a raw `data.contains(0x07)` mistakes the OSC-terminator BEL that shell
        // integration emits on every prompt (OSC 133) for a real terminal bell. The scan threads
        // its state through `m.bellScan` so a sequence spanning chunks is still handled correctly.
        if Self.scanForBell(data, state: &m.bellScan) { m.sawBell = true }
        monitors[surfaceKey] = m
        monitorLock.unlock()
    }

    /// Drain the monitor state (timer) and raise activity/silence/bell alerts on non-current
    /// windows, gated on the matching option. Sets the tab flag (surfaced as `#`/`~`/`!` in
    /// `#{window_flags}`) and fires the hook — both only on a real transition.
    private func processMonitors() {
        monitorLock.lock()
        let now = Date()
        var drained: [String: (sawOutput: Bool, sawBell: Bool, idle: TimeInterval)] = [:]
        for (key, m) in monitors {
            drained[key] = (m.sawOutput, m.sawBell, now.timeIntervalSince(m.lastOutput))
            monitors[key]?.sawOutput = false
            monitors[key]?.sawBell = false
        }
        monitorLock.unlock()
        guard !drained.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        let wantActivity = optionStore.get("monitor-activity")?.boolValue ?? false
        let wantBell = optionStore.get("monitor-bell")?.boolValue ?? true
        let silenceSeconds = optionStore.get("monitor-silence")?.intValue ?? 0
        // The orphan sweep runs even when every monitor option is off, so dead-surface keys never
        // accumulate; only the alert processing below is gated on the options being enabled.
        let monitoring = wantActivity || wantBell || silenceSeconds > 0
        var changed = false
        var fired: [(HookEvent, String)] = []
        var orphans: [String] = []
        for (key, st) in drained {
            guard let match = editor.tab(forSurfaceKey: key) else {
                // Output for a surface with no tab — an in-flight PTY read raced `closeSurfaces`
                // and re-created the monitor entry after teardown. Evict it so `monitors` can't
                // grow unbounded with dead-surface keys that nothing will ever clean.
                orphans.append(key)
                continue
            }
            guard monitoring,
                  !editor.tabIsCurrent(workspaceID: match.workspaceID, tabID: match.tabID) else { continue }
            if wantActivity, st.sawOutput,
               editor.setTabAlerts(workspaceID: match.workspaceID, tabID: match.tabID, activity: true) {
                changed = true; fired.append((.paneActivity, key))
            }
            if wantBell, st.sawBell,
               editor.setTabAlerts(workspaceID: match.workspaceID, tabID: match.tabID, bell: true) {
                changed = true; fired.append((.paneBell, key))
            }
            if silenceSeconds > 0, !st.sawOutput, st.idle >= Double(silenceSeconds),
               editor.setTabAlerts(workspaceID: match.workspaceID, tabID: match.tabID, silence: true) {
                changed = true; fired.append((.paneSilence, key))
            }
        }
        if changed { commit() }
        for (event, key) in fired { fireHookLocked(event, surfaceKey: key) }
        if !orphans.isEmpty {
            monitorLock.lock()
            for key in orphans { monitors.removeValue(forKey: key) }
            monitorLock.unlock()
        }
    }

    public var snapshot: SessionSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return editor.snapshot
    }

    /// The current layout revision without copying the whole `SessionSnapshot`
    /// (which the `snapshot` getter does, retaining every workspace/tab/pane array).
    /// Used by `daemon-stats` so reading one `Int` doesn't deep-copy under the lock.
    public var revision: Int {
        lock.lock()
        defer { lock.unlock() }
        return editor.snapshot.revision
    }

    /// Aggregate counts for `daemon-stats`. The registry lock is held only long
    /// enough to copy the session references; each `scrollbackByteCount` (which
    /// takes that PTY's own `scrollbackLock`) is then summed **off** the registry
    /// lock, so a stats read no longer blocks layout mutations while it walks
    /// every surface. The `Array` holds **strong references**, so a surface closed
    /// concurrently can't be deallocated mid-sum (its `scrollbackByteCount` stays a
    /// valid guarded read); the totals are mutually consistent with the copied set.
    public var surfaceTelemetry: (surfaceCount: Int, scrollbackBytes: Int) {
        acquireRegistryLock()
        let surfaces = Array(sessions.values)
        lock.unlock()
        let bytes = surfaces.reduce(0) { $0 + $1.scrollbackByteCount }
        return (surfaces.count, bytes)
    }

    /// Acquire the registry lock, timing the wait when metrics are enabled. The
    /// disabled path is a single branch then a plain `lock.lock()`. Paired with a
    /// normal `lock.unlock()` (or `defer`) at the call site. Used at the two
    /// dominant lock holders — `handle` and `surfaceTelemetry`; other `lock.lock()`
    /// sites are left uninstrumented.
    private func acquireRegistryLock() {
        guard metrics.enabled else { lock.lock(); return }
        let start = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        metrics.recordLockWait(nanos: DispatchTime.now().uptimeNanoseconds &- start)
    }

    public func handle(_ request: IPCRequest) -> IPCResponse {
        acquireRegistryLock()
        defer { lock.unlock() }
        switch request {
        case .openGitPanel, .activateGUIWindow:
            return .ok // intercepted at connection layer; never reaches here
        case .mobileListClients, .mobileRevokeClient, .mobilePairingInfo, .setMobileBridgeEnabled:
            return .ok // intercepted at connection layer; never reaches here
        case .ccRunStart, .ccRunGet, .ccRunList, .ccRunCancel:
            return .ok // intercepted at connection layer; never reaches here
        case .ping:
            return .pong
        case .listWorkspaces:
            return .workspaces(editor.snapshot.workspaces.map {
                WorkspaceSummary(id: $0.id, name: $0.name, tabCount: $0.sessions.count)
            })
        case .listSurfaces:
            return .surfaces(editor.listSurfaces())
        case .listAgents:
            return .agents(editor.listAgents())
        case let .newWorkspace(name):
            let id = editor.addWorkspace(name: name)
            commit()
            return .workspaceID(id)
        case let .newSession(workspaceID, cwd, name, shell, worktreePath, parentRepoPath, taskName):
            guard let sessionID = editor.addSession(to: workspaceID, cwd: cwd, name: name) else {
                return .error("Workspace not found")
            }
            if let wt = worktreePath {
                editor.setWorktree(sessionID: sessionID, worktreePath: wt, parentRepoPath: parentRepoPath, taskName: taskName)
            }
            ensureSessionSurfaces(sessionID: sessionID, shell: shell)
            commit()
            fireHookLocked(.afterNewSession)
            fireHookLocked(.sessionCreated)
            return .sessionID(sessionID)
        case let .newSessionInGroup(targetSessionID, name):
            guard let sessionID = editor.addGroupedSession(groupWith: targetSessionID, name: name) else {
                return .error("Target session not found")
            }
            // Linked windows share live surfaces — ensure is an idempotent no-op for
            // them and a revival for any dead leaf.
            ensureSessionSurfaces(sessionID: sessionID, shell: nil)
            commit()
            fireHookLocked(.afterNewSession)
            fireHookLocked(.sessionCreated)
            return .sessionID(sessionID)
        case let .newTab(workspaceID, cwd, shell):
            guard let tabID = editor.addTab(to: workspaceID, cwd: cwd) else {
                return .error("Workspace not found")
            }
            ensureTabSurfaces(tabID: tabID, shell: shell)
            editor.propagateNewTabToGroup(tabID)   // grouped sessions share the window list
            commit()
            fireHookLocked(.afterNewTab)
            return .tabID(tabID)
        case let .newTabInWorkspace(named, cwd, shell):
            guard let workspaceID = editor.resolveWorkspaceID(nameOrID: named) else {
                return .error("Workspace not found: \(named)")
            }
            guard let tabID = editor.addTab(to: workspaceID, cwd: cwd) else {
                return .error("Could not create tab")
            }
            ensureTabSurfaces(tabID: tabID, shell: shell)
            editor.propagateNewTabToGroup(tabID)
            commit()
            fireHookLocked(.afterNewTab)
            return .tabID(tabID)
        case let .newSplit(tabID, paneID, direction, shell, before):
            guard let workspace = editor.snapshot.workspaces.first(where: { ws in
                ws.sessions.contains { session in session.tabs.contains { $0.id == tabID } }
            }) else { return .error("Tab not found") }
            let tab = workspace.sessions.flatMap { $0.tabs }.first { $0.id == tabID }
            // Target-less split focuses the tab's active pane (falling back to its
            // first leaf), matching tmux's "split the current pane".
            let targetPane = paneID ?? tab?.activePaneID ?? tab?.rootPane.allPaneIDs().first
            guard let paneID = targetPane,
                  let newPaneID = editor.splitPane(
                      in: workspace.id,
                      tabID: tabID,
                      paneID: paneID,
                      direction: direction,
                      before: before
                  )
            else { return .error("Could not split pane") }
            if let surfaceID = editor.surfaceID(forPaneID: newPaneID) {
                // Prefer the tab's worktree path (the session's intended workspace),
                // then live cwd of the pane being split. When an agent runs from the
                // repo root, sourceCwd would resolve there instead of the worktree —
                // causing the split to land on 'main' instead of the current branch.
                let tabRef = editor.snapshot.workspaces
                    .flatMap { workspace in workspace.sessions.flatMap { $0.tabs } }
                    .first(where: { $0.id == tabID })
                let sourceCwd = editor.surfaceID(forPaneID: paneID)
                    .flatMap { sessions[$0.uuidString]?.currentWorkingDirectory() }
                let cwd = tabRef?.worktreePath ?? sourceCwd ?? tabRef?.cwd
                _ = createOrEnsureSurface(
                    surfaceID: surfaceID.uuidString,
                    cwd: cwd,
                    shell: shell,
                    rows: 24,
                    cols: 80,
                    scrollbackBytes: nil,
                    freshlyCreated: true
                )
            }
            commit()
            fireHookLocked(.afterSplitPane, surfaceKey: editor.surfaceID(forPaneID: newPaneID)?.uuidString)
            return .paneID(newPaneID)
        case let .newSurface(tabID, paneID, shell):
            guard let surfaceID = editor.addSurface(tabID: tabID, paneID: paneID) else {
                return .error("Could not create surface")
            }
            let cwd = editor.snapshot.workspaces
                .flatMap { workspace in workspace.sessions.flatMap { $0.tabs } }
                .first(where: { $0.id == tabID })?
                .cwd
            _ = createOrEnsureSurface(
                surfaceID: surfaceID.uuidString,
                cwd: cwd,
                shell: shell,
                rows: 24,
                cols: 80,
                scrollbackBytes: nil
            )
            commit()
            return .surfaceID(surfaceID.uuidString)
        case let .selectPaneSurface(tabID, paneID, surfaceID):
            guard editor.selectPaneSurface(tabID: tabID, paneID: paneID, surfaceID: surfaceID) else {
                return .error("Surface not found in pane")
            }
            commit()
            return .ok
        case let .splitPaneSurface(tabID, sourcePaneID, surfaceID, targetPaneID, direction, beforeTarget):
            guard let newPaneID = editor.splitPaneSurface(
                tabID: tabID,
                sourcePaneID: sourcePaneID,
                surfaceID: surfaceID,
                targetPaneID: targetPaneID,
                direction: direction,
                beforeTarget: beforeTarget
            ) else {
                return .error("Could not split surface")
            }
            commit()
            fireHookLocked(.afterSplitPane, surfaceKey: surfaceID.uuidString)
            return .paneID(newPaneID)
        case let .selectWorkspace(id):
            guard editor.selectWorkspace(id) else { return .error("Workspace not found") }
            commit()
            return .ok
        case let .selectWorkspaceByName(name):
            guard let id = editor.resolveWorkspaceID(nameOrID: name) else {
                return .error("Workspace not found: \(name)")
            }
            guard editor.selectWorkspace(id) else { return .error("Workspace not found: \(name)") }
            commit()
            return .workspaceID(id)
        case let .selectSession(workspaceID, sessionID):
            guard editor.selectSession(workspaceID: workspaceID, sessionID: sessionID) else {
                return .error("Session not found")
            }
            commit()
            return .ok
        case let .selectTab(workspaceID, tabID):
            guard editor.selectTab(workspaceID: workspaceID, tabID: tabID) else {
                return .error("Tab not found")
            }
            commit()
            return .ok
        case let .reorderTab(workspaceID, tabID, toIndex):
            guard editor.reorderTab(workspaceID: workspaceID, tabID: tabID, toIndex: toIndex) else {
                return .error("Tab not found")
            }
            commit()
            return .ok
        case let .swapTab(workspaceID, tabID, withIndex):
            guard editor.swapTab(workspaceID: workspaceID, tabID: tabID, withIndex: withIndex) else {
                return .error("Tab not found")
            }
            commit()
            return .ok
        case let .reorderSession(workspaceID, sessionID, toIndex):
            guard editor.reorderSession(workspaceID: workspaceID, sessionID: sessionID, toIndex: toIndex) else {
                return .error("Session not found")
            }
            commit()
            return .ok
        case let .renumberWindows(sessionID):
            guard editor.renumberWindows(sessionID: sessionID) else {
                return .error("Session not found")
            }
            commit()
            return .ok
        case let .closeTab(tabID):
            let owningSession = editor.snapshot.workspaces
                .flatMap(\.sessions)
                .first(where: { $0.tabs.contains { $0.id == tabID } })?.id
            // Grouped sessions: killing a window removes it from every member (tmux).
            // Counterparts + their surfaces gathered BEFORE the close mutates the snapshot.
            let counterparts = editor.groupCounterparts(of: tabID)
            let allTabs = editor.snapshot.workspaces.flatMap { $0.sessions.flatMap { $0.tabs } }
            // Union the surfaces of the window AND its counterparts: a peer's local split can
            // diverge the layout, so a counterpart may carry surfaces this copy doesn't — omit
            // them and those PTYs leak when the peer tab closes (closeSurfaces only reaps the
            // ids it's handed, and nothing else sweeps surfaces orphaned mid-run).
            let closedSurfaces = Array(Set(([tabID] + counterparts).flatMap { id in
                allTabs.first(where: { $0.id == id })?.rootPane.allSurfaceIDs().map(\.uuidString) ?? []
            }))
            guard editor.closeTab(tabID) else { return .error("Tab not found") }
            for counterpart in counterparts { _ = editor.closeTab(counterpart) }
            closeSurfaces(closedSurfaces)
            ensureAllSnapshotSurfaces()
            // tmux `renumber-windows`: keep indices contiguous after a tab closes.
            if optionStore.get("renumber-windows")?.boolValue == true, let owningSession {
                _ = editor.renumberWindows(sessionID: owningSession)
            }
            commit()
            fireHookLocked(.afterKillTab)
            return .ok
        case let .closeSession(sessionID):
            let closingSession = editor.snapshot.workspaces
                .flatMap(\.sessions)
                .first(where: { $0.id == sessionID })
            let closedSurfaces = closingSession?
                .tabs
                .flatMap { $0.rootPane.allSurfaceIDs().map(\.uuidString) } ?? []
            // Capture worktree metadata before close for cleanup.
            let worktreeInfo: (path: String, parent: String?)? = closingSession?.tabs.first.flatMap {
                guard let wt = $0.worktreePath else { return nil }
                return (wt, $0.parentRepoPath)
            }
            // Hook context captured BEFORE the close: `#{session_name}` must describe
            // the session that closed, not whatever survives it.
            let closedContext = buildFormatContext(
                surfaceKey: (closingSession?.activeTab ?? closingSession?.tabs.first)?
                    .rootPane.allSurfaceIDs().first?.uuidString
            )
            guard editor.closeSession(sessionID) else { return .error("Session not found") }
            closeSurfaces(closedSurfaces)
            // Clean up the worktree if it's not dirty.
            if let wt = worktreeInfo {
                let mgr = WorktreeManager()
                let repoPath = wt.parent ?? mgr.repoRoot(for: wt.path) ?? wt.path
                if !mgr.isDirty(worktreePath: wt.path) {
                    // P32 F3: run the project's archiveScript (if any) before the worktree
                    // dir disappears — this is the only point in the lifecycle where the
                    // worktree still exists but the task is definitely ending.
                    if let config = ProjectConfig.load(from: wt.path),
                       let archive = config.archiveScript, !archive.isEmpty {
                        mgr.runArchiveScript(archive, cwd: wt.path, env: config.env)
                    }
                    mgr.remove(repoPath: repoPath, worktreePath: wt.path)
                }
            }
            // Drop the session's per-session env so entries don't accumulate in environment.json.
            environmentStore.clearSession(sessionID.uuidString)
            ensureAllSnapshotSurfaces()
            commit()
            fireHookLocked(.sessionClosed, context: closedContext)
            return .ok
        case let .closeWorkspace(id):
            let workspaceSessionIDs = editor.snapshot.workspaces
                .first(where: { $0.id == id })?
                .sessions.map(\.id) ?? []
            let closedSurfaces = editor.snapshot.workspaces
                .first(where: { $0.id == id })?
                .sessions
                .flatMap { $0.tabs }
                .flatMap { $0.rootPane.allSurfaceIDs().map(\.uuidString) } ?? []
            guard editor.closeWorkspace(id) else { return .error("Cannot close workspace") }
            closeSurfaces(closedSurfaces)
            for sessionID in workspaceSessionIDs { environmentStore.clearSession(sessionID.uuidString) }
            commit()
            return .ok
        case let .setTheme(name):
            editor.setTheme(name)
            commit()
            return .ok
        case let .setKeepSessionsOnQuit(value):
            editor.setKeepSessionsOnQuit(value)
            commit()
            return .ok
        case let .setSessionPersistent(sessionID, persistent):
            guard editor.setSessionPersistent(sessionID, persistent) else {
                return .error("Session not found")
            }
            commit()
            return .ok
        case let .setTabPersistent(tabID, persistent):
            guard editor.setTabPersistent(tabID, persistent) else {
                return .error("Tab not found")
            }
            commit()
            return .ok
        case let .setTabWorktree(tabID, worktreePath, parentRepoPath, taskName):
            guard editor.setTabWorktree(tabID, worktreePath: worktreePath, parentRepoPath: parentRepoPath, taskName: taskName) else {
                return .error("Tab not found")
            }
            commit()
            return .ok
        case .closeEphemeralSessions:
            // Close each ephemeral session inline (NOT via re-entrant handle(.closeSession),
            // which would deadlock on the non-recursive `lock` we already hold). Same helpers
            // the .closeSession case uses, so PTYs are killed and the layout stays consistent.
            let ids = editor.ephemeralSessionIDs()
            // Unpinned tabs kept alive only by a pinned sibling: close them individually so a
            // pinned tab keeps just itself (and its session container) across a clean quit.
            let tabIDs = editor.ephemeralTabIDs()
            guard !ids.isEmpty || !tabIDs.isEmpty else { return .ok }
            for sessionID in ids {
                let closedSurfaces = editor.snapshot.workspaces
                    .flatMap(\.sessions)
                    .first(where: { $0.id == sessionID })?
                    .tabs
                    .flatMap { $0.rootPane.allSurfaceIDs().map(\.uuidString) } ?? []
                guard editor.closeSession(sessionID) else { continue }
                closeSurfaces(closedSurfaces)
                environmentStore.clearSession(sessionID.uuidString)
            }
            for tabID in tabIDs {
                // Gather the tab's surfaces before removing it from the layout (mirrors the
                // session loop above), then kill those PTYs.
                let closedSurfaces = editor.snapshot.workspaces
                    .flatMap(\.sessions).flatMap(\.tabs)
                    .first(where: { $0.id == tabID })?
                    .rootPane.allSurfaceIDs().map(\.uuidString) ?? []
                guard editor.closeTab(tabID) else { continue }
                closeSurfaces(closedSurfaces)
            }
            ensureAllSnapshotSurfaces()
            commit()
            return .ok
        case let .send(surfaceID, text):
            guard let session = sessions[surfaceID] else {
                return .error("Surface not found")
            }
            session.write(text)
            return .ok
        case let .sendData(surfaceID, data):
            guard let session = sessions[surfaceID] else {
                return .error("Surface not found")
            }
            session.write(data)
            return .ok
        case let .notify(surfaceID, title, body):
            let notification = AgentNotification(
                surfaceID: UUID(uuidString: surfaceID),
                daemonSurfaceID: surfaceID,
                title: title,
                body: body
            )
            NotificationBus.shared.post(notification)
            markWaiting(surfaceKey: surfaceID, text: body)
            commit()
            fireHookLocked(.notificationPosted, surfaceKey: surfaceID)
            return .ok
        case let .notifyDone(surfaceID, title, body):
            let notification = AgentNotification(
                surfaceID: UUID(uuidString: surfaceID),
                daemonSurfaceID: surfaceID,
                title: title,
                body: body
            )
            NotificationBus.shared.post(notification)
            markDone(surfaceKey: surfaceID, text: body)
            commit()
            fireHookLocked(.notificationPosted, surfaceKey: surfaceID)
            return .ok
        case let .setSubagentHint(surfaceID, kind, active):
            if active {
                AgentDetector.registerSubagentHint(kind: kind, forSurfaceKey: surfaceID)
            } else {
                AgentDetector.clearSubagentHint(forSurfaceKey: surfaceID)
            }
            // Apply immediately rather than waiting for the next scan tick (up to 30s idle
            // cadence) — a hook push should feel near-instant, unlike the proc-scan fallback.
            editor.setSubagents(AgentDetector.mergedSubagents(forSurfaceKey: surfaceID), forSurfaceKey: surfaceID)
            commit()
            return .ok
        case let .clearNotification(surfaceID):
            if let uuid = UUID(uuidString: surfaceID) {
                editor.clearTabNotification(surfaceID: uuid)
            }
            commit()
            return .ok
        case let .updateTabTitle(surfaceID, title):
            // OSC/program-driven rename. Honor `allow-rename` (global) and the
            // per-tab `automatic-rename` flag — a manual `rename-tab` turns the
            // latter off so the chosen name sticks (tmux semantics).
            if let uuid = UUID(uuidString: surfaceID),
               optionStore.get("allow-rename")?.boolValue ?? true,
               automaticRenameEnabled(forSurfaceKey: surfaceID) {
                // Strip tool-injected suffixes like " (kiro-cli-term)" that Kiro
                // appends to the shell title via OSC 2 — they leak internal process
                // names into the UI and add no user value.
                let cleaned = title.replacing(#/ \(kiro-cli[^)]*\)/#, with: "")
                editor.updateTabTitle(surfaceID: uuid, title: cleaned)
                commit()
                fireHookLocked(.windowRenamed, surfaceKey: surfaceID)
            }
            return .ok
        case let .setPaneLabel(surfaceID, label):
            guard let uuid = UUID(uuidString: surfaceID) else { return .error("Invalid surface id") }
            guard editor.setPaneLabel(surfaceID: uuid, label: label) else { return .error("Pane surface not found") }
            commit()
            return .ok
        case let .updateTabCwd(surfaceID, path):
            if let uuid = UUID(uuidString: surfaceID) {
                editor.updateTabCwd(surfaceID: uuid, path: path)
                commit()
            }
            return .ok
        case let .updateTabGitBranch(workspaceID, tabID, branch):
            editor.updateTabMetadata(workspaceID: workspaceID, tabID: tabID, gitBranch: branch, cwd: nil)
            commit()
            return .ok
        case let .notifyMCPActivity(surfaceID, _):
            if let uuid = UUID(uuidString: surfaceID) {
                editor.stampMCPActivity(surfaceID: uuid, at: Date())
                commit()
            }
            return .ok
        case .getSnapshot:
            return .snapshot(editor.snapshot)
        case let .createSurface(cwd, shell):
            let surfaceID = UUID().uuidString
            return createOrEnsureSurface(
                surfaceID: surfaceID,
                cwd: cwd,
                shell: shell,
                rows: 24,
                cols: 80,
                scrollbackBytes: nil,
                freshlyCreated: true
            ).map { .surfaceID($0) } ?? .error("Failed to launch shell")
        case let .ensureSurface(surfaceID, cwd, shell, rows, cols, scrollbackBytes):
            return createOrEnsureSurface(
                surfaceID: surfaceID,
                cwd: cwd,
                shell: shell,
                rows: rows,
                cols: cols,
                scrollbackBytes: scrollbackBytes
            ).map { _ in .ok } ?? .error("Failed to launch shell")
        case .attachSurface:
            return .ok
        case let .sendKeys(surfaceID, keys):
            let bytes = KeyTokenParser.encode(keys: keys)
            if let session = sessions[surfaceID] {
                session.write(bytes)
                return .ok
            }
            return .error("Surface not found")
        case let .capturePane(surfaceID, includeScrollback):
            if let session = sessions[surfaceID] {
                let text = session.captureScrollback(includeHistory: includeScrollback)
                return .text(text)
            }
            return .error("Surface not found")
        case let .closeSurface(surfaceID):
            closeSurfaces([surfaceID])
            return .ok
        case let .capturePaneRange(surfaceID, start, end, escapeSequences, joinWrapped):
            guard let session = sessions[surfaceID] else { return .error("Surface not found") }
            // `-e` keeps the program's original escapes (raw byte stream); plain capture
            // reconstructs the actual on-screen grid, with `-J` joining soft-wrapped rows.
            if escapeSequences {
                return .text(session.captureRange(start: start, end: end, escapeSequences: true))
            }
            return .text(session.captureGrid(start: start, end: end, joinWrapped: joinWrapped))
        case let .getBlock(surfaceID, blockID):
            guard let session = sessions[surfaceID] else { return .error("Surface not found") }
            return .blockInfo(session.block(id: blockID))
        case let .pipePane(surfaceID, shellCommand):
            guard sessions[surfaceID] != nil else { return .error("Surface not found") }
            if let shellCommand, !shellCommand.isEmpty {
                startPipe(surfaceID: surfaceID, shellCommand: shellCommand)
            } else {
                stopPipe(surfaceID: surfaceID)
            }
            return .ok
        case let .linkWindow(tabID, targetSessionID):
            guard let newTabID = editor.linkWindow(tabID, toSessionID: targetSessionID) else {
                return .error("Could not link window (tab or target session not found)")
            }
            ensureAllSnapshotSurfaces()
            commit()
            fireHookLocked(.windowLinked)
            return .tabID(newTabID)
        case let .unlinkWindow(tabID):
            let removed = editor.snapshot.workspaces
                .flatMap { $0.sessions }.flatMap { $0.tabs }
                .first(where: { $0.id == tabID })?
                .rootPane.allSurfaceIDs().map(\.uuidString) ?? []
            guard editor.unlinkWindow(tabID) else { return .error("Window is not linked") }
            closeSurfaces(removed)   // ref-counted: shared surfaces survive
            commit()
            fireHookLocked(.windowUnlinked)
            return .ok
        case let .killPane(paneID):
            let killedSurfaceID = editor.surfaceID(forPaneID: paneID)?.uuidString
            guard editor.killPane(paneID) else { return .error("Pane not found") }
            if let killedSurfaceID { closeSurfaces([killedSurfaceID]) }
            commit()
            fireHookLocked(.afterKillPane, surfaceKey: killedSurfaceID)
            return .ok
        case let .swapPanes(srcID, dstID):
            guard editor.swapPanes(srcID, dstID) else { return .error("Panes not found") }
            commit()
            return .ok
        case let .resizePane(paneID, direction, amount):
            guard editor.resizePane(paneID, direction: direction, amount: amount) else {
                return .error("Pane not found")
            }
            commit()
            fireHookLocked(.afterResizePane, surfaceKey: editor.surfaceID(forPaneID: paneID)?.uuidString)
            return .ok
        case let .resizePaneRatio(tabID, firstPaneID, secondPaneID, ratio):
            guard editor.setSplitRatio(
                tabID: tabID,
                firstPaneID: firstPaneID,
                secondPaneID: secondPaneID,
                ratio: ratio
            ) else {
                return .error("Split not found")
            }
            commit()
            fireHookLocked(.afterResizePane)
            return .ok
        case let .zoomPane(paneID):
            guard editor.zoomPane(paneID) else { return .error("Pane not found") }
            commit()
            return .ok
        case let .setCopyMode(surfaceID, enabled):
            NotificationBus.shared.postCopyMode(surfaceID: surfaceID, enabled: enabled)
            return .ok
        case let .renameTab(tabID, name):
            guard editor.renameTab(tabID, name: name) else { return .error("Tab not found") }
            // A manual rename sticks: turn off automatic-rename for this tab so a
            // later OSC title doesn't clobber the chosen name.
            optionStore.set(.bool(false), key: "automatic-rename", scope: .tab, target: tabID.uuidString)
            commit()
            // Hook context follows the RENAMED tab (a `-t` can name a non-active one),
            // like the OSC automatic-rename path — never the focused tab's.
            fireHookLocked(.windowRenamed, surfaceKey: editor.snapshot.workspaces
                .flatMap { $0.sessions.flatMap(\.tabs) }
                .first(where: { $0.id == tabID })?
                .rootPane.allSurfaceIDs().first?.uuidString)
            return .ok
        case let .renameSession(sessionID, name):
            guard editor.renameSession(sessionID, name: name) else { return .error("Session not found") }
            commit()
            // Same misroute class: format against the RENAMED session's active tab.
            let renamed = editor.snapshot.workspaces.flatMap(\.sessions).first { $0.id == sessionID }
            fireHookLocked(.sessionRenamed, surfaceKey: (renamed?.activeTab ?? renamed?.tabs.first)?
                .rootPane.allSurfaceIDs().first?.uuidString)
            return .ok
        case let .renameWorkspace(workspaceID, name):
            guard editor.renameWorkspace(workspaceID, name: name) else { return .error("Workspace not found") }
            commit()
            return .ok
        case let .detectAgent(surfaceID):
            return .agentInfo(AgentDetector.snapshot(forSurfaceKey: surfaceID))
        case let .subscribeSurfaceOutput(surfaceID, _):
            return subscribe(surfaceID: surfaceID)
        case .subscribeSnapshot:
            // FD-level streaming, owned by DaemonServer (intercepted before reaching
            // the registry); the stub keeps the switch exhaustive.
            return .error("subscribeSnapshot must be handled by DaemonServer")
        case .waitFor:
            // Socket-layer blocking primitive, owned by DaemonServer (intercepted before
            // the registry so it never blocks this lock); stub keeps the switch exhaustive.
            return .error("wait-for must be handled by DaemonServer")
        case .cancelSubscription:
            // Per-client cancel is owned by DaemonServer (it knows which connection asked and
            // releases only that client's token). Reaching here means a caller bypassed the server
            // — do nothing rather than wiping EVERY subscriber on the surface (the old global
            // `cancelSubscription(token: nil)` dropped other clients' streams too).
            return .ok
        case let .replayScrollback(surfaceID, fromSequence):
            guard let session = sessions[surfaceID] else { return .text("") }
            return .text(session.replay(fromSequence: fromSequence))
        case let .replayScrollbackSequenced(surfaceID, fromSequence):
            // A missing surface still answers (empty replay at sequence 0) so the gap-free attach
            // path gets a usable boundary instead of mistaking it for an old-daemon `.error`.
            guard let session = sessions[surfaceID] else { return .replayResult(text: "", endSequence: 0) }
            let result = session.replayWithEndSequence(fromSequence: fromSequence)
            return .replayResult(text: result.text, endSequence: result.endSequence)
        case let .resizeSurface(surfaceID, rows, cols):
            sessions[surfaceID]?.resize(rows: rows, cols: cols)
            return .ok
        case .detachSurface:
            // Per-client detach is owned by DaemonServer, which knows *which* connection asked
            // and releases only that client's subscription + size vote. The registry can't see
            // the client, so the socket path is intercepted upstream; reaching here would mean a
            // caller bypassed the server — do nothing (the old code wiped *every* subscriber on
            // the surface via cancelSubscription(token: nil), which dropped other clients too).
            return .ok
        case .identifyClient, .listClients, .detachClient, .daemonStats:
            // Client lifecycle and aggregate stats are owned by the DaemonServer
            // layer (it tracks FDs). Server intercepts these before reaching the
            // registry; the stubs here exist only to keep the switch exhaustive.
            return .error("Client lifecycle requests must be handled by DaemonServer")
        case let .setBuffer(name, data):
            guard let final = bufferStore.set(data, name: name) else {
                return .error("set-buffer: payload exceeds the paste-buffer size limit")
            }
            return .text(final)
        case let .getBuffer(name):
            let buffer: PasteBufferStore.Buffer?
            if let name { buffer = bufferStore.get(name) }
            else { buffer = bufferStore.mostRecent() }
            guard let buffer else { return .error("Buffer not found") }
            return .buffer(BufferSummary(
                name: buffer.name,
                byteCount: buffer.data.count,
                preview: buffer.preview,
                createdAt: buffer.createdAt,
                data: buffer.data
            ))
        case .listBuffers:
            let summaries = bufferStore.list().map {
                BufferSummary(name: $0.name, byteCount: $0.data.count, preview: $0.preview, createdAt: $0.createdAt)
            }
            return .buffers(summaries)
        case let .deleteBuffer(name):
            return bufferStore.delete(name) ? .ok : .error("Buffer not found")
        case let .taskList(sessionID):
            let summaries = taskStore.list(sessionID: sessionID).map(Self.taskSummary)
            return .tasks(summaries)
        case let .taskGet(id):
            return .taskInfo(taskStore.get(id: id).map(Self.taskSummary))
        case let .taskCreate(sessionID, title):
            // Captured once, here, because it's the only point this is ever knowable — the
            // owning session can (and per design routinely does) close later, at which point
            // there is no other way to recover which project the Task came from.
            let cwd = editor.snapshot.workspaces
                .flatMap { $0.sessions }
                .first(where: { $0.id == sessionID })?
                .activeTab?.cwd
            return .taskInfo(Self.taskSummary(taskStore.create(sessionID: sessionID, title: title, cwd: cwd)))
        case let .taskUpdate(id, title, done):
            guard let updated = taskStore.update(id: id, title: title, done: done) else {
                return .error("Task not found")
            }
            return .taskInfo(Self.taskSummary(updated))
        case let .taskDelete(id):
            return taskStore.delete(id: id) ? .ok : .error("Task not found")
        case let .worktreeList(repoPath):
            let infos = WorktreeManager().list(repoPath: repoPath).map(Self.worktreeInfoSummary)
            return .worktrees(infos)
        case let .worktreeCreate(repoPath, sessionID, branch, baseRef):
            guard let path = WorktreeManager().create(
                repoPath: repoPath, sessionID: sessionID, branch: branch, baseRef: baseRef
            ) else {
                return .error("git worktree add failed")
            }
            return .worktreePath(path)
        case let .worktreeRemove(repoPath, worktreePath, force):
            let ok = WorktreeManager().remove(repoPath: repoPath, worktreePath: worktreePath, force: force)
            return ok ? .ok : .error("git worktree remove failed")
        case .automationList:
            return .automations(automationStore.list().map(Self.automationSummary))
        case let .automationGet(id):
            return .automationInfo(automationStore.get(id: id).map(Self.automationSummary))
        case let .automationCreate(repoPath, workspaceID, agent, prompt, intervalMinutes):
            let automation = automationStore.create(
                repoPath: repoPath, workspaceID: workspaceID, agent: agent, prompt: prompt,
                intervalMinutes: intervalMinutes
            )
            return .automationInfo(Self.automationSummary(automation))
        case let .automationUpdate(id, repoPath, agent, prompt, intervalMinutes):
            guard let updated = automationStore.update(
                id: id, repoPath: repoPath, agent: agent, prompt: prompt, intervalMinutes: intervalMinutes
            ) else {
                return .error("Automation not found")
            }
            return .automationInfo(Self.automationSummary(updated))
        case let .automationDelete(id):
            return automationStore.delete(id: id) ? .ok : .error("Automation not found")
        case let .automationSetEnabled(id, enabled):
            guard let updated = automationStore.setEnabled(id: id, enabled: enabled) else {
                return .error("Automation not found")
            }
            return .automationInfo(Self.automationSummary(updated))
        case let .automationRunNow(id):
            guard let automation = automationStore.get(id: id) else {
                return .error("Automation not found")
            }
            return fireAutomationLocked(automation) ? .ok : .error("Automation spawn failed")
        case .routingRuleList:
            return .routingRules(routingRuleStore.list().map(Self.routingRuleSummary))
        case let .routingRuleGet(id):
            return .routingRuleInfo(routingRuleStore.get(id: id).map(Self.routingRuleSummary))
        case let .routingRuleCreate(kind, pattern, targetAgent, enabled):
            guard let ruleKind = AgentRoutingRule.Kind(rawValue: kind) else {
                return .error("Unknown rule kind '\(kind)'. Valid values: path, stack")
            }
            guard let agentKind = AgentKind(rawValue: targetAgent) else {
                return .error("Unknown agent '\(targetAgent)'")
            }
            let rule = routingRuleStore.create(kind: ruleKind, pattern: pattern, targetAgent: agentKind, enabled: enabled)
            return .routingRuleInfo(Self.routingRuleSummary(rule))
        case let .routingRuleUpdate(id, kind, pattern, targetAgent, enabled):
            // `kind` is immutable once created (path vs stack rules order independently) —
            // accepted here only so the wire shape matches Create's, but ignored on update.
            _ = kind
            var resolvedAgent: AgentKind?
            if let targetAgent {
                guard let k = AgentKind(rawValue: targetAgent) else {
                    return .error("Unknown agent '\(targetAgent)'")
                }
                resolvedAgent = k
            }
            guard let updated = routingRuleStore.update(
                id: id, pattern: pattern, targetAgent: resolvedAgent, enabled: enabled
            ) else {
                return .error("Routing rule not found")
            }
            return .routingRuleInfo(Self.routingRuleSummary(updated))
        case let .routingRuleDelete(id):
            return routingRuleStore.delete(id: id) ? .ok : .error("Routing rule not found")
        case let .routingRuleReorder(kind, orderedIDs):
            guard let ruleKind = AgentRoutingRule.Kind(rawValue: kind) else {
                return .error("Unknown rule kind '\(kind)'. Valid values: path, stack")
            }
            let reordered = routingRuleStore.reorder(kind: ruleKind, orderedIDs: orderedIDs)
            return .routingRules(reordered.map(Self.routingRuleSummary))
        case .savedLayoutList:
            return .savedLayouts(savedLayoutStore.list())
        case let .savedLayoutSave(name, tabID):
            guard let tab = editor.snapshot.workspaces
                .flatMap({ $0.sessions.flatMap { $0.tabs } })
                .first(where: { $0.id == tabID })
            else {
                return .error("Tab not found")
            }
            let saved = savedLayoutStore.create(name: name, shape: tab.rootPane.paneLayoutShape)
            return .savedLayoutInfo(saved)
        case let .savedLayoutDelete(id):
            return savedLayoutStore.delete(id: id) ? .ok : .error("Saved layout not found")
        case let .pasteBuffer(surfaceID, name, bracketed):
            guard let session = sessions[surfaceID] else { return .error("Surface not found") }
            let buffer: PasteBufferStore.Buffer?
            if let name { buffer = bufferStore.get(name) }
            else { buffer = bufferStore.mostRecent() }
            guard let buffer else { return .error("Buffer not found") }
            if bracketed {
                // tmux `paste-buffer -p`: wrap in bracketed-paste markers so the
                // program treats it as a single pasted block (DECSET 2004).
                var out = Data("\u{1b}[200~".utf8)
                out.append(buffer.data)
                out.append(Data("\u{1b}[201~".utf8))
                session.write(out)
            } else {
                session.write(buffer.data)
            }
            return .ok
        case let .selectPaneDirectional(currentPaneID, direction):
            let target: Command.PaneTarget
            switch direction {
            case .left: target = .left
            case .right: target = .right
            case .up: target = .up
            case .down: target = .down
            }
            guard let neighbor = editor.directionalNeighbor(of: currentPaneID, direction: target) else {
                return .error("No neighbor in that direction")
            }
            // Persist the new focus server-side so every client agrees on the active
            // pane (not just the caller). Best-effort: the neighbor is in the same tab.
            if let loc = editor.tab(containingPaneID: neighbor) {
                _ = editor.setActivePane(workspaceID: loc.workspaceID, tabID: loc.tabID, paneID: neighbor)
                commit()
            }
            return .paneID(neighbor)
        case let .selectPane(tabID, paneID):
            guard let loc = editor.tab(containingPaneID: paneID), loc.tabID == tabID else {
                return .error("Pane not found in tab")
            }
            guard editor.setActivePane(workspaceID: loc.workspaceID, tabID: tabID, paneID: paneID) else {
                return .error("Could not select pane")
            }
            commit()
            return .ok
        case let .applyLayout(tabID, layout, mainPaneID):
            guard let template = LayoutTemplate(rawValue: layout) else {
                return .error("Unknown layout: \(layout)")
            }
            guard editor.applyLayout(tabID: tabID, layout: template, mainPaneID: mainPaneID) else {
                return .error("Tab not found or has fewer than 2 panes")
            }
            commit()
            fireHookLocked(.windowLayoutChanged)
            return .ok
        case let .nextLayout(tabID):
            // No per-tab "last layout" memory yet (lands in Phase 6 with the
            // option store); we cycle from `evenHorizontal` each call. That's
            // already a useful "give me a different layout" gesture.
            guard editor.applyLayout(tabID: tabID, layout: .evenHorizontal.next(), mainPaneID: nil) else {
                return .error("Tab not found")
            }
            commit()
            fireHookLocked(.windowLayoutChanged)
            return .ok
        case let .previousLayout(tabID):
            guard editor.applyLayout(tabID: tabID, layout: .evenHorizontal.previous(), mainPaneID: nil) else {
                return .error("Tab not found")
            }
            commit()
            fireHookLocked(.windowLayoutChanged)
            return .ok
        case let .rotatePanes(tabID, forward):
            guard editor.rotatePanes(tabID: tabID, forward: forward) else {
                return .error("Tab not found")
            }
            commit()
            fireHookLocked(.windowLayoutChanged)
            return .ok
        case let .breakPane(paneID):
            guard let newTab = editor.breakPane(paneID: paneID) else {
                return .error("Cannot break pane (only pane in tab, or pane not found)")
            }
            commit()
            return .tabID(newTab)
        case let .joinPane(source, dest, direction, before):
            guard let newPane = editor.joinPane(sourcePaneID: source, destPaneID: dest, direction: direction, before: before) else {
                return .error("Cannot join pane")
            }
            commit()
            return .paneID(newPane)
        case let .respawnPane(surfaceID, keepHistory):
            // Last-known tab cwd as the fallback: after a natural shell exit there is no
            // live PID left to probe, and respawning into $HOME instead of where the user
            // was working would lose their place.
            let surfaceTab = editor.tab(forSurfaceKey: surfaceID)
            var fallbackCwd: String?
            if let match = surfaceTab {
                fallbackCwd = editor.snapshot.workspaces
                    .first(where: { $0.id == match.workspaceID })?
                    .sessions.flatMap { $0.tabs }
                    .first(where: { $0.id == match.tabID })?
                    .cwd
            }
            if let session = sessions[surfaceID] {
                session.respawn(clearHistory: !keepHistory, fallbackCwd: fallbackCwd)
                return .ok
            }
            // A naturally-exited `remain-on-exit` pane keeps its dead leaf in the layout, but its
            // RealPty was dropped from `sessions` on exit — so respawn-pane (whose entire purpose is
            // reviving such a pane) must recreate the surface rather than fail "Surface not found".
            // Only when the dead leaf still resolves; an unknown surface is a real error.
            guard surfaceTab != nil else { return .error("Surface not found") }
            let scrollbackURL = KouenPaths.scrollbackFileURL(forSurfaceID: surfaceID)
            var reviveScrollbackBytes: Int?
            if keepHistory {
                // Size the revived scrollback cap to at least the on-disk history (and the usual
                // default floor) so reviving never TRIMS scrollback a normal reattach would keep:
                // createOrEnsureSurface's nil default (1 MiB) would otherwise compact a larger
                // persisted log on load. The live-respawn path above keeps the original cap; this
                // is the dead-pane equivalent.
                let onDisk = (try? FileManager.default.attributesOfItem(atPath: scrollbackURL.path)[.size]) as? Int ?? 0
                reviveScrollbackBytes = onDisk > 0 ? max(onDisk, 1024 * 1024) : nil
            } else {
                // Honor `-k`: drop the persisted scrollback before the revived surface seeds its ring
                // from disk, so it starts clean. The RealPty that normally owns this file is gone, so
                // delete it directly; the default cap is fine on a now-empty history.
                try? FileManager.default.removeItem(at: scrollbackURL)
            }
            guard createOrEnsureSurface(surfaceID: surfaceID, cwd: fallbackCwd, shell: nil,
                                        rows: 24, cols: 80, scrollbackBytes: reviveScrollbackBytes) != nil else {
                return .error("Could not respawn surface")
            }
            return .ok
        case let .clearHistory(surfaceID):
            if let session = sessions[surfaceID] {
                session.clearHistory()
                return .ok
            }
            return .error("Surface not found")

        case let .resizeWindow(tabID, rows, cols):
            // Resize all surfaces in the tab to the given dimensions (resize-window override).
            let surfaceIDs = editor.snapshot.workspaces
                .flatMap { $0.sessions }.flatMap { $0.tabs }
                .first(where: { $0.id == tabID })?
                .rootPane.allSurfaceIDs().map(\.uuidString) ?? []
            for sid in surfaceIDs {
                sessions[sid]?.resize(rows: rows, cols: cols)
            }
            return surfaceIDs.isEmpty ? .error("Tab not found") : .ok

        case let .setOption(scopeRaw, target, key, raw):            guard let scope = OptionStore.Scope(rawValue: scopeRaw) else {
                return .error("Unknown option scope: \(scopeRaw)")
            }
            // The on-disk key joins scope:target:key with colons; a colon in the option name or
            // target would mis-parse on read-back. Option names and ID targets never contain one,
            // so reject it rather than silently corrupt the store.
            guard !key.contains(":"), !(target?.contains(":") ?? false) else {
                return .error("Option name/target must not contain ':'")
            }
            // Scoped reads resolve by exact target and only fall back toward broader scopes —
            // a nil-target non-global option is stored but unreachable by every read path.
            // Reject it (defense in depth behind the CLI's own -T requirement).
            guard scope == .global || target != nil else {
                return .error("\(scopeRaw) scope requires a target")
            }
            optionStore.set(.init(parsing: raw), key: key, scope: scope, target: target)
            // Nudge snapshot subscribers (the attach-window compositor) so a runtime option
            // change — status-*, mouse, pane-style, mode-keys — reaches attached clients instead
            // of being stuck at their startup values. Re-uses the snapshot push as a generic
            // "re-read server state" signal (revision unchanged; clients re-pull options).
            onSnapshotCommitted?(editor.snapshot.revision)
            return .ok
        case let .showOptions(scopeRaw):
            let scope = scopeRaw.flatMap(OptionStore.Scope.init(rawValue:))
            let entries = optionStore.snapshot(scope: scope).map { key, value in
                OptionEntry(scope: key.scope.rawValue, target: key.target, key: key.key, value: value.stringValue)
            }
            return .options(entries)
        case let .setEnvironment(sessionID, key, value):
            environmentStore.set(value, key: key, sessionID: sessionID?.uuidString)
            return .ok
        case let .showEnvironment(sessionID):
            let entries = environmentStore.entries(sessionID: sessionID?.uuidString).map { entry in
                OptionEntry(scope: entry.scope, target: sessionID?.uuidString, key: entry.key, value: entry.value)
            }
            return .options(entries)
        case let .bindHook(eventRaw, source, condition):
            guard let event = HookEvent(rawValue: eventRaw) else {
                return .error("Unknown hook event: \(eventRaw)")
            }
            do {
                let command = try CommandParser.parse(source)
                let id = hookRegistry.bind(event: event, command: command, conditionFormat: condition)
                return .hookID(id)
            } catch {
                return .error("Parse failed: \(error)")
            }
        case let .unbindHook(id):
            return hookRegistry.unbind(id: id) ? .ok : .error("Hook not found")
        case let .listHooks(eventRaw):
            let event = eventRaw.flatMap(HookEvent.init(rawValue:))
            let entries = hookRegistry.list(event: event).map {
                HookEntry(id: $0.id, event: $0.event.rawValue, commandSource: $0.command.shortDescription, condition: $0.conditionFormat)
            }
            return .hooks(entries)
        case .showMessages:
            messageLogLock.lock(); defer { messageLogLock.unlock() }
            return .text(messageLog.joined(separator: "\n"))
        case .flushSessionState:
            // Synchronous write, bypassing the normal debounce — see the request's own doc
            // comment. Runs under the registry lock like every other case here, so it can't
            // race a concurrent layout mutation into `editor.snapshot`.
            try? store.saveImmediately(editor.snapshot)
            return .ok
        case let .displayMessage(format):
            // Render via FormatString using whatever context the daemon can
            // build right now (active workspace/tab from snapshot). UI clients
            // observe the notification bus and decide how to surface it.
            postDisplayMessage(FormatString.evaluate(format, context: buildFormatContext()))
            return .ok
        case .runGit, .browserOpen, .browserNavigate, .browserWait, .browserSnapshot, .browserInteract, .browserClose, .browserScreenshot, .browserNetwork, .browserCookies, .browserStorage, .browserEvaluate, .browserGoBack, .browserGoForward, .browserReload, .browserResponse:
            return .error("Browser/Git requests are handled at the daemon server layer")
        }
    }

    /// ISO8601DateFormatter is documented thread-safe; one instance instead of a
    /// per-message allocation while serializing the message lock.
    nonisolated(unsafe) private static let messageTimestamp = ISO8601DateFormatter()

    /// Post an already-rendered display-message line: append to the `show-messages`
    /// log and notify UI clients. Split from the IPC handler so hook-fired
    /// display-message can render with the HOOK's context (the event's subject —
    /// e.g. the closed session) instead of the active chain — which also means
    /// hook-fired messages land in `show-messages` like client-sent ones.
    func postDisplayMessage(_ text: String) {
        messageLogLock.lock()
        messageLog.append("[\(Self.messageTimestamp.string(from: Date()))] \(text)")
        if messageLog.count > Self.messageLogCap { messageLog.removeFirst(messageLog.count - Self.messageLogCap) }
        messageLogLock.unlock()
        NotificationBus.shared.post(AgentNotification(
            surfaceID: nil,
            daemonSurfaceID: nil,
            title: "Kouen",
            body: text
        ))
    }

    private func subscribe(surfaceID: String) -> IPCResponse {
        // Real streaming lives on the daemon socket layer (DaemonServer); here
        // we just acknowledge so callers don't crash.
        return .ok
    }

    public func subscribe(
        surfaceID: String,
        handler: @escaping @Sendable (Data, UInt64) -> Void
    ) -> UUID? {
        lock.lock()
        let session = sessions[surfaceID]
        lock.unlock()
        return session?.subscribe(handler)
    }

    public func cancelSubscription(surfaceID: String, token: UUID) {
        lock.lock()
        let session = sessions[surfaceID]
        lock.unlock()
        session?.cancelSubscription(token: token)
    }

    public func applyAgentChanges(_ changes: [String: AgentDetector.AgentDetection]) {
        lock.lock()
        defer { lock.unlock() }
        // Fire agent-state-changed only on an actual activity transition, so a steady
        // "working" stream of scans doesn't spam the hook.
        var transitioned: [String] = []
        for (surfaceKey, detection) in changes {
            let snapshot = detection.primary
            let before = agentActivityString(forSurfaceKey: surfaceKey)
            editor.setAgent(snapshot, forSurfaceKey: surfaceKey)
            editor.setSubagents(detection.subagents, forSurfaceKey: surfaceKey)
            if before != snapshot?.activity.rawValue { transitioned.append(surfaceKey) }
            // An agent that resumed producing output is no longer "waiting on the user" —
            // clear a stale `waiting` status (left by a notify/stop hook) on the transition
            // into working. Without this, a tab once marked waiting suppressed the working
            // indicator for the whole next turn.
            if snapshot?.activity == .working, before != AgentActivity.working.rawValue {
                clearWaitingStatusLocked(surfaceKey: surfaceKey)
            }
        }
        commit()
        for surfaceKey in transitioned { fireHookLocked(.agentStateChanged, surfaceKey: surfaceKey) }
    }

    /// True if any tab currently has a detected primary agent — drives `AgentScanner`'s
    /// adaptive scan cadence (P38 Phase B).
    public func hasAnyPrimaryAgent() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return editor.snapshot.workspaces.contains {
            $0.sessions.contains { $0.tabs.contains { $0.agent != nil } }
        }
    }

    /// Reset a `waiting` tab back to idle (clearing its notification text). No-op — and no
    /// revision bump — when the tab isn't waiting. Caller must hold `lock`.
    private func clearWaitingStatusLocked(surfaceKey: String) {
        guard let surfaceID = SurfaceID(uuidString: surfaceKey),
              let match = editor.tab(forSurfaceKey: surfaceKey),
              editor.snapshot.workspaces
                  .first(where: { $0.id == match.workspaceID })?
                  .sessions.flatMap(\.tabs)
                  .first(where: { $0.id == match.tabID })?.status == .waiting
        else { return }
        editor.clearTabNotification(surfaceID: surfaceID)
    }

    /// Current agent activity (raw) for the tab backing `surfaceKey`, or nil. Caller
    /// must hold `lock`.
    private func agentActivityString(forSurfaceKey surfaceKey: String) -> String? {
        guard let match = editor.tab(forSurfaceKey: surfaceKey) else { return nil }
        return editor.snapshot.workspaces
            .first(where: { $0.id == match.workspaceID })?
            .sessions.flatMap { $0.tabs }
            .first(where: { $0.id == match.tabID })?
            .agent?.activity.rawValue
    }

    public func refreshSurfaceMetadata() {
        // `currentWorkingDirectory()` runs `ProcessScan.livePIDs()` (a `proc_listpids` of EVERY
        // system PID) per surface — measured 6.2ms@10 panes / 11.7ms@20 — and was previously
        // computed while holding `lock`, blocking ALL IPC (keystroke `sendData`, snapshots) for
        // that whole window every ~1.5s. Mirror the `surfaceTelemetry` pattern: snapshot strong
        // refs under the lock, compute each cwd OFF the lock, then re-acquire to commit — and
        // re-validate identity + the current cwd under the lock before each write.
        lock.lock()
        let snap = Array(sessions)  // [(key, RealPty)] — strong refs keep PTYs alive off-lock
        lock.unlock()

        // Off-lock: walk every surface's process tree without contending with IPC. Keep the
        // exact `session` instance alongside its probed cwd so the re-acquire below can confirm
        // the surface wasn't closed/replaced before committing (PID reuse safety). Capture the PID
        // the cwd was computed for so a respawn during the probe (same RealPty, new child) can't
        // commit the OLD child's cwd for the NEW one.
        let probed: [(key: String, session: RealPty, uuid: UUID, pid: pid_t, cwd: String, command: String?)] = snap.compactMap { key, session in
            guard let uuid = UUID(uuidString: key), let result = session.probeWorkingDirectory() else {
                return nil
            }
            // Foreground command rides the same probe cycle (one extra ioctl + name lookup).
            // Guarded by the same child PID so a respawn can't commit the old child's command.
            let command = session.probeForegroundCommand()
            return (key, session, uuid, result.pid, result.cwd, command?.pid == result.pid ? command?.command : nil)
        }
        guard !probed.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        var changed = false
        for entry in probed {
            // The surface could have been closed/replaced while we were off-lock — only commit if
            // the exact instance we probed is still registered under this key, AND its child PID is
            // still the one we probed. A respawn swaps childPID on the same RealPty instance, so the
            // `===` check alone would commit a stale cwd; skip and let the next ~1.5s cycle re-probe.
            guard sessions[entry.key] === entry.session,
                  entry.session.currentChildPID == entry.pid,
                  let match = editor.tab(for: entry.uuid)
            else { continue }
            // Re-read the tab's stored cwd under the lock; the proc-scan result (`entry.cwd`) was
            // computed off-lock so we never re-run that O(all-PIDs) walk while holding the lock.
            let tab = editor.snapshot.workspaces
                .first(where: { $0.id == match.workspaceID })?
                .sessions
                .flatMap { $0.tabs }
                .first(where: { $0.id == match.tabID })
            if tab?.cwd != entry.cwd {
                editor.updateTabCwd(surfaceID: entry.uuid, path: entry.cwd)
                changed = true
            }
            if let command = entry.command, tab?.currentCommand != command {
                editor.updateTabCurrentCommand(surfaceID: entry.uuid, command: command)
                changed = true
            }
        }
        if changed { commit() }
    }

    /// TCP-listening-port refresh (P39 G1): one batched `lsof` across every surface's process
    /// tree, mirroring `refreshSurfaceMetadata`'s off-lock probe / re-validate-then-commit shape
    /// so a slow `lsof` fork never blocks IPC (`sendData`, snapshots) the way holding `lock`
    /// during the probe would.
    public func refreshListeningPorts() {
        lock.lock()
        let snap = Array(sessions)
        lock.unlock()

        var roots: [String: Int32] = [:]
        var probedPID: [String: pid_t] = [:]
        roots.reserveCapacity(snap.count)
        for (key, session) in snap {
            let pid = session.currentChildPID
            roots[key] = pid
            probedPID[key] = pid
        }
        guard !roots.isEmpty else { return }

        // Off-lock: forks `lsof`, so this must never run while `lock` is held.
        let portsByKey = ListeningPortScanner.scan(roots: roots)

        lock.lock()
        defer { lock.unlock() }
        var changed = false
        for (key, session) in snap {
            // Re-validate identity + child PID before committing — the probed root PID may
            // belong to an already-respawned child by the time `lsof` returns.
            guard sessions[key] === session,
                  session.currentChildPID == probedPID[key],
                  let uuid = UUID(uuidString: key),
                  let match = editor.tab(for: uuid)
            else { continue }
            let tab = editor.snapshot.workspaces
                .first(where: { $0.id == match.workspaceID })?
                .sessions.flatMap { $0.tabs }
                .first(where: { $0.id == match.tabID })
            let ports = portsByKey[key] ?? []
            if tab?.listeningPorts != ports {
                editor.updateTabListeningPorts(surfaceID: uuid, ports: ports)
                changed = true
            }
        }
        if changed { commit() }
    }

    /// Lightweight CWD-only refresh: reads each surface's direct shell PID cwd via a single
    /// `proc_pidinfo` syscall (no process-tree walk). O(N) where N = open surfaces, ~0.1ms
    /// total. Suitable for 500ms polling without significant CPU cost.
    public func refreshCwdOnly() {
        lock.lock()
        let snap = Array(sessions)
        lock.unlock()

        let probed: [(key: String, session: RealPty, uuid: UUID, pid: pid_t, cwd: String)] = snap.compactMap { key, session in
            // Skip surfaces where a subprocess holds the foreground; the 1.5s metadata
            // scan (refreshSurfaceMetadata) covers those. Both paths report the shell's
            // own cwd — never a descendant's — so a session stays pinned to its worktree
            // even while a build/agent subprocess runs in another directory.
            guard session.isShellInForeground(),
                  let uuid = UUID(uuidString: key), let result = session.probeShellCwd() else { return nil }
            return (key, session, uuid, result.pid, result.cwd)
        }
        guard !probed.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }
        var changed = false
        for entry in probed {
            guard sessions[entry.key] === entry.session,
                  entry.session.currentChildPID == entry.pid,
                  let match = editor.tab(for: entry.uuid)
            else { continue }
            let tab = editor.snapshot.workspaces
                .first(where: { $0.id == match.workspaceID })?
                .sessions.flatMap { $0.tabs }
                .first(where: { $0.id == match.tabID })
            if tab?.cwd != entry.cwd {
                editor.updateTabCwd(surfaceID: entry.uuid, path: entry.cwd)
                changed = true
            }
        }
        if changed { commit() }
    }

    /// Count of identified clients, injected by `DaemonServer` (which owns the FDs) for
    /// `#{session_attached}`. Must be safe to call under `lock` from any thread — the
    /// server backs it with its own counter, never a hop onto the daemon queue.
    public var attachedClientCountProvider: (@Sendable () -> Int)?

    /// Build a `FormatContext` from the current snapshot's active selection.
    /// Used by `display-message` and hook firing. Conservative: nil fields
    /// stay nil so format strings render an empty token instead of "(none)".
    public func buildFormatContext(surfaceKey: String? = nil, clientName: String? = nil) -> FormatContext {
        FormatContextBuilder.build(
            snapshot: editor.snapshot,
            editor: editor,
            surfaceKey: surfaceKey,
            clientName: clientName,
            sessions: sessions,
            attachedClientCount: attachedClientCountProvider?()
        )
    }

    // MARK: - Hook firing

    /// Schedule the hooks bound to `event`. MUST be called with `lock` held: it reads
    /// the locked snapshot to build the context, then fires on `hookQueue` so the
    /// commands run after the current mutation commits and the lock is released.
    /// `context` overrides the snapshot-derived one for events whose subject is gone
    /// by fire time (session-closed captures its context before the mutation).
    private func fireHookLocked(_ event: HookEvent, surfaceKey: String? = nil, context: FormatContext? = nil) {
        let resolved = context ?? buildFormatContext(surfaceKey: surfaceKey)
        hookExecutionHelper.fire(event, context: resolved)
    }

    /// Client attach/detach originate in `DaemonServer` (which owns FDs), outside the
    /// registry lock — these acquire the lock to build a consistent context.
    public func fireClientAttached(label: String?) {
        lock.lock(); let context = buildFormatContext(clientName: label); lock.unlock()
        hookExecutionHelper.fire(.clientAttached, context: context)
    }

    public func fireClientDetached(label: String?) {
        lock.lock(); let context = buildFormatContext(clientName: label); lock.unlock()
        hookExecutionHelper.fire(.clientDetached, context: context)
        // `destroy-unattached`: when the last client detaches, kill sessions that have no
        // attached clients if the option is on.
        enforceDestroyUnattached()
    }

    private func enforceDestroyUnattached() {
        lock.lock()
        let enabled = optionStore.get("destroy-unattached")?.boolValue ?? false
        guard enabled else { lock.unlock(); return }
        let attachedCount = attachedClientCountProvider?() ?? 1
        guard attachedCount == 0 else { lock.unlock(); return }
        // Kill every session's surfaces to release PTYs. The editor snapshot will
        // reflect an empty workspace on the next client connect.
        let surfaceIDs = Array(sessions.keys)
        lock.unlock()
        for sid in surfaceIDs {
            lock.lock(); let session = sessions[sid]; lock.unlock()
            session?.close()
        }
    }

    // MARK: - Hook target resolution + shell execution

    /// Active-selection resolvers used by `DaemonCommandExecutor` for target-less hook
    /// commands. Best-effort first-leaf until Phase 2 adds a server-side active pane.
    func activeWorkspaceID() -> WorkspaceID? {
        lock.lock(); defer { lock.unlock() }
        return editor.snapshot.activeWorkspaceID
    }

    func activeTabID() -> TabID? {
        lock.lock(); defer { lock.unlock() }
        return editor.snapshot.activeWorkspace?.activeTab?.id
    }

    func activePaneID() -> PaneID? {
        lock.lock(); defer { lock.unlock() }
        return editor.snapshot.activeWorkspace?.activeTab?.rootPane.allPaneIDs().first
    }

    func activePaneSurfaceKey() -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let pane = editor.snapshot.activeWorkspace?.activeTab?.rootPane.allPaneIDs().first else { return nil }
        return editor.surfaceID(forPaneID: pane)?.uuidString
    }

    /// Run `command` via `/bin/sh -c` for a `run-shell` hook. Async (fire-and-forget);
    /// when `captureToBuffer` is set, stdout is stored in a paste buffer on completion.
    func runShellForHook(_ command: String, captureToBuffer: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let pipe = captureToBuffer ? Pipe() : nil
        if let pipe { process.standardOutput = pipe }
        process.terminationHandler = { [weak self] _ in
            guard captureToBuffer, let pipe, let self else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if !data.isEmpty {
                _ = self.handle(.setBuffer(name: nil, data: data))
            }
        }
        do { try process.run() } catch {
            fputs("KouenDaemon: run-shell hook failed: \(error)\n", kouenStderr)
        }
    }

    /// Run `command` via `/bin/sh -c` synchronously and report exit-0 for `if-shell`.
    /// Called on `hookQueue`, never under the registry lock.
    func evaluateShellCondition(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    public func runGitCommandInDaemon(args: [String], cwd: String) async -> (output: String, stderr: String, success: Bool) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = URL(fileURLWithPath: cwd)
                // GIT_TERMINAL_PROMPT=0: fail fast instead of hanging for credentials.
                // stdin=null: prevent git from blocking on a read that never comes.
                var env = ProcessInfo.processInfo.environment
                env["GIT_TERMINAL_PROMPT"] = "0"
                process.environment = env
                process.standardInput = FileHandle.nullDevice
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                // Kill if git hangs (e.g. SSH passphrase, network stall).
                let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: timeout)
                do {
                    try process.run()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timeout.cancel()
                    let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let stderr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: (output, stderr, process.terminationStatus == 0))
                } catch {
                    timeout.cancel()
                    continuation.resume(returning: ("", error.localizedDescription, false))
                }
            }
        }
    }

    private func markWaiting(surfaceKey: String, text: String) {
        guard let match = editor.tab(forSurfaceKey: surfaceKey) else { return }
        editor.setTabStatus(
            workspaceID: match.workspaceID,
            tabID: match.tabID,
            status: .waiting,
            notificationText: text
        )
    }

    /// Stop-hook completion: the tab isn't blocking on the user, so `.done` (not `.waiting`) —
    /// the Agent Notch only shows Reply/Deny/Allow controls for `.waiting`.
    private func markDone(surfaceKey: String, text: String) {
        guard let match = editor.tab(forSurfaceKey: surfaceKey) else { return }
        editor.setTabStatus(
            workspaceID: match.workspaceID,
            tabID: match.tabID,
            status: .done,
            notificationText: text
        )
    }

    private func commit() {
        let revision = editor.snapshot.revision
        do {
            try store.saveImmediately(editor.snapshot)
        } catch {
            fputs("KouenDaemon snapshot save failed: \(error)\n", kouenStderr)
        }
        NotificationBus.shared.postSnapshotChanged(revision: revision)
        onSnapshotCommitted?(revision)
    }

    /// `freshlyCreated` marks a surface the user just asked for (new tab/session/split/
    /// `createSurface`) as opposed to a boot restore or reattach revival — only a fresh
    /// surface may consume the pending first-run / what's-new banner.
    private func createOrEnsureSurface(
        surfaceID: String,
        cwd: String?,
        shell: String?,
        rows: UInt16,
        cols: UInt16,
        scrollbackBytes: Int?,
        freshlyCreated: Bool = false
    ) -> String? {
        if sessions[surfaceID] != nil {
            // Existing surface: do NOT resize here. A surface's geometry is owned by the
            // per-client resize votes (`resizeSurface`), which every client sends once its
            // view (GUI) or TTY (CLI attach) lays out. `ensureSurface` carries only a
            // placeholder 24×80 — resizing a live PTY to that on every reattach (e.g. an app
            // relaunch that re-grabs daemon-kept surfaces) storms SIGWINCH: the shell redraws
            // its prompt at 80 cols, that redraw overlaps the replayed scrollback (captured at
            // the real width) and the real resize that immediately follows, leaving the garbled
            // overlapping prompt seen on terminal restart. Returning early keeps the surface at
            // its real size until the client's own resize vote arrives.
            return surfaceID
        }
        do {
            let shellPath = Self.resolveShell(shellCandidate(for: shell))
            let workDir = existingWorkingDirectory(cwd)
            // Terminal identity advertised to the child shell (TERM_PROGRAM). Single source: the
            // `terminal-identity` option the GUI/CLI sets; the app reads the same value for its
            // XTVERSION reply.
            let identity = TerminalIdentity.spec(forOption: optionStore.get(TerminalIdentity.optionKey)?.stringValue)
            let session = try RealPty(
                id: surfaceID,
                cwd: workDir,
                shell: shellPath,
                rows: rows,
                cols: cols,
                scrollbackBytes: scrollbackBytes ?? 1024 * 1024,
                extraEnvironment: extraEnvironment(forSurfaceKey: surfaceID),
                termProgram: identity.name,
                termProgramVersion: identity.version,
                scrollbackURL: KouenPaths.scrollbackFileURL(forSurfaceID: surfaceID)
            )
            session.onExit = { [weak self, weak session] exitStatus in
                self?.removeSurfaceIfCurrent(surfaceID: surfaceID, session: session, exitStatus: exitStatus)
            }
            // Internal monitor subscription (Phase 5): cheap output/bell/idle tracking, drained
            // by `processMonitors`. Lives for the surface's lifetime (cleared on teardown).
            _ = session.subscribe { [weak self] data, _ in self?.noteSurfaceOutput(surfaceKey: surfaceID, data: data) }
            sessions[surfaceID] = session
            if freshlyCreated { injectVersionBannerIfPending(into: session, columns: Int(cols)) }
            // A dead retained pane (`remain-on-exit`) carries its exit status until revived —
            // this spawn IS the revival, so clear it. Idempotent: a plain ensure on a live
            // surface reports no change and commits nothing.
            if let sid = UUID(uuidString: surfaceID), editor.setTabExitStatus(surfaceID: sid, status: nil) {
                commit()
            }
            // Begin reading/exit-watching only now that `onExit` is wired and the surface is in
            // `sessions` — so a child that dies instantly (e.g. a bad shell) is reaped via
            // `removeSurfaceIfCurrent` instead of firing into a nil handler and leaking.
            session.start()
            return surfaceID
        } catch {
            fputs("KouenDaemon surface launch failed for \(surfaceID): \(error)\n", kouenStderr)
            return nil
        }
    }

    /// Inject the version banner into a newly created surface.
    /// - whatsNew is one-shot: consumed on the first new surface after an update.
    /// - welcome shows on every new surface (persistent MOTD); the one-shot flag is
    ///   consumed so it doesn't also trigger a redundant whatsNew after a fresh install.
    /// The `update-banner` option (default on) suppresses all output; the durable ack
    /// for whatsNew is written before the option check so it is never re-shown.
    private func injectVersionBannerIfPending(into session: RealPty, columns: Int) {
        if versionAckRetryNeeded { versionAckRetryNeeded = !versionBannerStore.markSeen() }

        if let banner = pendingVersionBanner, case .whatsNew = banner {
            pendingVersionBanner = nil
            // Ack BEFORE the option check: suppressing still consumes the one-shot.
            versionAckRetryNeeded = !versionBannerStore.markSeen()
            guard optionStore.get("update-banner")?.boolValue ?? true else { return }
            session.injectSyntheticOutput(TerminalBanner.whatsNew(ReleaseNotes.current, columns: columns))
            return
        }

        // Consume the first-run one-shot flag (if present) without re-acking —
        // whatsNew already wrote the durable ack on update; welcome never needs one.
        pendingVersionBanner = nil
        guard optionStore.get("update-banner")?.boolValue ?? true else { return }
        session.injectSyntheticOutput(TerminalBanner.welcome(version: KouenVersion.short, columns: columns))
    }

    private func shellCandidate(for requested: String?) -> String {
        if let requested, !requested.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return requested
        }
        return persistedDefaultShell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    /// Validate the requested shell is executable, falling back (with a log) so a bad
    /// `defaultShell` doesn't produce a silently dead pane (`forkpty` child _exit(127)).
    private static func resolveShell(_ candidate: String) -> String {
        let fm = FileManager.default
        if fm.isExecutableFile(atPath: candidate) { return candidate }
        let fallbacks = [ProcessInfo.processInfo.environment["SHELL"], "/bin/zsh", "/bin/bash", "/bin/sh"]
            .compactMap { $0 }
        for fallback in fallbacks where fm.isExecutableFile(atPath: fallback) {
            fputs("KouenDaemon: shell '\(candidate)' is not executable; falling back to '\(fallback)'\n", kouenStderr)
            return fallback
        }
        return candidate
    }

    private func existingWorkingDirectory(_ raw: String?) -> String {
        let fallback = FileManager.default.homeDirectoryForCurrentUser.path
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        let expanded = (raw as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue {
            return expanded
        }
        var candidate = (expanded as NSString).deletingLastPathComponent
        while !candidate.isEmpty {
            if FileManager.default.fileExists(atPath: candidate, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
            let parent = (candidate as NSString).deletingLastPathComponent
            if parent == candidate { break }
            candidate = parent
        }
        return fallback
    }

    func launchedShellForTesting(surfaceID: String) -> String? {
        sessions[surfaceID]?.launchedShellForTesting
    }

    /// Only called for a tab the user just created (`newTab`/`newTabInWorkspace`), so the
    /// spawn is `freshlyCreated` — eligible for the one-shot version banner.
    private func ensureTabSurfaces(tabID: TabID, shell: String?) {
        let tabs = editor.snapshot.workspaces.flatMap { workspace in workspace.sessions.flatMap { $0.tabs } }
        guard let tab = tabs.first(where: { $0.id == tabID })
        else { return }
        for surfaceID in tab.rootPane.allSurfaceIDs() {
            _ = createOrEnsureSurface(
                surfaceID: surfaceID.uuidString,
                cwd: tab.cwd,
                shell: shell,
                rows: 24,
                cols: 80,
                scrollbackBytes: nil,
                freshlyCreated: true
            )
        }
    }

    /// Only called for a session the user just created (`newSession`) — see
    /// `ensureTabSurfaces` on `freshlyCreated`.
    private func ensureSessionSurfaces(sessionID: SessionID, shell: String?) {
        let allSessions = editor.snapshot.workspaces.flatMap { $0.sessions }
        guard let session = allSessions.first(where: { $0.id == sessionID })
        else { return }
        for tab in session.tabs {
            for surfaceID in tab.rootPane.allSurfaceIDs() {
                _ = createOrEnsureSurface(
                    surfaceID: surfaceID.uuidString,
                    cwd: tab.cwd,
                    shell: shell,
                    rows: 24,
                    cols: 80,
                    scrollbackBytes: nil,
                    freshlyCreated: true
                )
            }
        }
    }

    private func ensureAllSnapshotSurfaces() {
        for tab in editor.snapshot.workspaces.flatMap({ workspace in workspace.sessions.flatMap { $0.tabs } }) {
            for surfaceID in tab.rootPane.allSurfaceIDs() {
                _ = createOrEnsureSurface(
                    surfaceID: surfaceID.uuidString,
                    cwd: tab.cwd,
                    shell: nil,
                    rows: 24,
                    cols: 80,
                    scrollbackBytes: nil
                )
            }
        }
    }

    /// Close PTYs for the given surfaces — but only those no longer referenced by
    /// any surviving tab. Linked windows (`link-window`) share surfaces across
    /// tabs/sessions, so a surface lives until its last referencing tab is gone.
    /// Called after the editor mutation, so `editor.snapshot` reflects survivors.
    private func closeSurfaces(_ surfaceIDs: [String]) {
        let stillReferenced = Set(
            editor.snapshot.workspaces
                .flatMap { $0.sessions }
                .flatMap { $0.tabs }
                .flatMap { $0.rootPane.allSurfaceIDs().map(\.uuidString) }
        )
        for surfaceID in surfaceIDs where !stillReferenced.contains(surfaceID) {
            let removed = sessions.removeValue(forKey: surfaceID)
            // The surface is gone from the layout — synchronously drop its persisted scrollback
            // before closing, so no late debounced flush can resurrect the file.
            removed?.deletePersistedScrollback()
            removed?.close()
            // Backstop: when a shell exits naturally (remain-on-exit off), `removeSurfaceIfCurrent`
            // already reaped the RealPty, so `removed` is nil here and the line above is a no-op —
            // remove the file by path so it doesn't linger until the next restart's orphan sweep.
            // The RealPty (and its ScrollbackFile) is gone in that case, so this can't be resurrected.
            try? FileManager.default.removeItem(at: KouenPaths.scrollbackFileURL(forSurfaceID: surfaceID))
            stopPipe(surfaceID: surfaceID)
            // Drop the output monitor too, else it leaks across tab/session/pane churn.
            monitorLock.lock(); monitors.removeValue(forKey: surfaceID); monitorLock.unlock()
        }
    }

    // MARK: pipe-pane

    /// Active `pipe-pane` taps: a surface's live output is tee'd to a spawned
    /// shell command's stdin until toggled off (or the surface closes).
    /// @unchecked Sendable: `backlog` is guarded by `backlogLock`; `token` is only assigned under
    /// the registry `lock` (in `startPipe`, before the process can fire `terminationHandler`); the
    /// rest are immutable.
    private final class PanePipe: @unchecked Sendable {
        let process: Process
        let stdin: FileHandle
        var token: UUID?
        /// Tee writes run here so a stalled consumer (full pipe buffer ⇒ blocking write) can't
        /// stall the surface's shared `deliveryQueue` and starve the GUI/attach subscribers.
        private let writerQueue = DispatchQueue(label: "com.vit129.kouen.pipe-pane.write")
        private let backlogLock = NSLock()
        private var backlog = 0
        private let maxBacklog = 4 * 1024 * 1024

        init(process: Process, stdin: FileHandle) {
            self.process = process
            self.stdin = stdin
        }

        /// Tee `data` to the piped command, bounded: past the backlog cap we drop — a tee is
        /// best-effort and must never accumulate without limit behind a stuck consumer.
        func feed(_ data: Data) {
            backlogLock.lock()
            if backlog + data.count > maxBacklog { backlogLock.unlock(); return }
            backlog += data.count
            backlogLock.unlock()
            let stdin = self.stdin
            let count = data.count
            writerQueue.async { [weak self] in
                _ = try? stdin.write(contentsOf: data) // broken pipe (consumer exited) just drops
                guard let self else { return }
                self.backlogLock.lock(); self.backlog -= count; self.backlogLock.unlock()
            }
        }
    }
    private var pipes: [String: PanePipe] = [:]

    /// Caller holds `lock` (invoked from `handle`/`closeSurfaces`), so this talks to
    /// the `RealPty` directly rather than the locking `subscribe` wrappers.
    private func startPipe(surfaceID: String, shellCommand: String) {
        stopPipe(surfaceID: surfaceID)   // one pipe per surface
        guard let session = sessions[surfaceID] else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", shellCommand]
        let stdinPipe = Pipe()
        process.standardInput = stdinPipe
        process.environment = ProcessInfo.processInfo.environment
        let pipe = PanePipe(process: process, stdin: stdinPipe.fileHandleForWriting)
        // Subscribe + register BEFORE run() so the token is set before a fast-exiting command can
        // fire `terminationHandler` (which must cancel exactly this token, never the global set).
        let token = session.subscribe { [weak pipe] data, _ in pipe?.feed(data) }
        pipe.token = token
        pipes[surfaceID] = pipe
        // Auto-tear-down when the piped command exits on its own (e.g. `head -1`); otherwise the
        // subscriber + map entry leak until the surface closes. Scoped by object identity + token
        // so it never wipes a replacement pipe or every subscriber. Runs off-lock on a background
        // queue, so it takes the registry lock itself.
        process.terminationHandler = { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            if let existing = self.pipes[surfaceID], existing === pipe {
                if let token = existing.token { self.sessions[surfaceID]?.cancelSubscription(token: token) }
                try? existing.stdin.close()
                self.pipes.removeValue(forKey: surfaceID)
            }
            self.lock.unlock()
        }
        if (try? process.run()) == nil {
            // Never log the command itself — a pipe target can carry tokens/paths the user
            // would not want in daemon stderr. The surface id is enough to diagnose.
            fputs("KouenDaemon: pipe-pane failed to launch for surface \(surfaceID)\n", kouenStderr)
            stopPipe(surfaceID: surfaceID)
        }
    }

    private func stopPipe(surfaceID: String) {
        guard let pipe = pipes.removeValue(forKey: surfaceID) else { return }
        if let token = pipe.token { sessions[surfaceID]?.cancelSubscription(token: token) }
        try? pipe.stdin.close()
        if pipe.process.isRunning { pipe.process.terminate() }
    }

    /// Whether OSC/program title auto-rename is enabled for the tab owning
    /// `surfaceKey` (per-tab `automatic-rename`, defaulting on).
    private func automaticRenameEnabled(forSurfaceKey surfaceKey: String) -> Bool {
        guard let match = editor.tab(forSurfaceKey: surfaceKey) else { return true }
        return optionStore.get("automatic-rename", scope: .tab, target: match.tabID.uuidString)?.boolValue ?? true
    }

    /// The extra environment a pane's shell receives: Kouen-owned vars (so
    /// nested tools detect Kouen, the `$TMUX` analog) plus the resolved
    /// `set-environment` map for the surface's owning session.
    private func extraEnvironment(forSurfaceKey surfaceKey: String) -> [String: String] {
        var env: [String: String] = [
            "KOUEN": KouenPaths.socketURL.path,
            "KOUEN_SOCK": KouenPaths.socketURL.path,
        ]
        if let cli = Self.kouenCLIExecutableURL() {
            env["KOUEN_CLI"] = cli.path
        }
        let session = sessionID(forSurfaceKey: surfaceKey)
        for (key, value) in environmentStore.resolved(sessionID: session) { env[key] = value }
        env["PATH"] = Self.pathWithKouenTools(env["PATH"] ?? ProcessInfo.processInfo.environment["PATH"])
        return env
    }

    private static func kouenCLIExecutableURL() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let executable = Bundle.main.executableURL {
            candidates.append(executable.deletingLastPathComponent().appendingPathComponent("kouen-cli"))
        }
        candidates.append(KouenPaths.applicationSupport.appendingPathComponent("bin").appendingPathComponent("kouen-cli"))
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/kouen-cli"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/kouen-cli"))
        return candidates.first { fm.isExecutableFile(atPath: $0.path) }
    }

    private static func pathWithKouenTools(_ inheritedPath: String?) -> String {
        var dirs: [String] = [
            KouenPaths.applicationSupport.appendingPathComponent("bin").path,
        ]
        if let cli = kouenCLIExecutableURL() {
            dirs.append(cli.deletingLastPathComponent().path)
        }
        let basePath = inheritedPath?.isEmpty == false ? inheritedPath! : "/usr/bin:/bin:/usr/sbin:/sbin"
        dirs += basePath
            .split(separator: ":")
            .map(String.init)

        var seen: Set<String> = []
        let unique = dirs.filter { dir in
            guard !dir.isEmpty, !seen.contains(dir) else { return false }
            seen.insert(dir)
            return true
        }
        return unique.joined(separator: ":")
    }

    private func sessionID(forSurfaceKey surfaceKey: String) -> String? {
        guard let uuid = UUID(uuidString: surfaceKey) else { return nil }
        for ws in editor.snapshot.workspaces {
            for session in ws.sessions {
                for tab in session.tabs where tab.rootPane.allSurfaceIDs().contains(uuid) {
                    return session.id.uuidString
                }
            }
        }
        return nil
    }

    /// Synchronously persist every live surface's buffered scrollback. Called on graceful daemon
    /// shutdown (`DaemonServer.stop`) so the last debounce window of output isn't lost.
    public func flushAllScrollback() {
        lock.lock()
        let live = Array(sessions.values)
        lock.unlock()
        for session in live { session.flushScrollback() }
    }

    /// On startup, delete persisted scrollback files for surfaces no longer in the layout. A clean
    /// shutdown removes a surface's file via `closeSurfaces`, but a crash can leave files behind for
    /// surfaces that were closed in-flight; sweep them so the directory doesn't grow without bound.
    /// Runs in `init` after `ensureAllSnapshotSurfaces`.
    ///
    /// Liveness is the union of live PTYs AND snapshot-referenced surfaces — NOT just `sessions`.
    /// `createOrEnsureSurface` returns nil when the `RealPty` fails to spawn (forkpty EAGAIN/ENOMEM),
    /// leaving the surface in `layout.json` but out of `sessions`; keying the sweep on `sessions`
    /// alone would then permanently delete the history of a surface that respawns fine next boot.
    private func cleanupOrphanScrollbackFiles() {
        let dir = KouenPaths.scrollbackDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) else { return }
        let live = scrollbackLiveSurfaceKeys()
        for file in files where file.pathExtension == "scroll" {
            let surfaceID = file.deletingPathExtension().lastPathComponent
            // Delete only genuine crash orphans — files neither backing a live PTY nor referenced
            // anywhere in the layout.
            if !live.contains(surfaceID) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// Surface keys whose persisted scrollback must be preserved on startup: the union of live
    /// PTYs (`sessions`) AND every surface referenced by the snapshot. The snapshot half is what
    /// keeps a failed-to-spawn surface's history (in `layout.json` but absent from `sessions`)
    /// from being swept. `internal` purely so the orphan-sweep safety can be unit-tested.
    func scrollbackLiveSurfaceKeys() -> Set<String> {
        let referenced = Set(editor.snapshot.workspaces
            .flatMap { $0.sessions }.flatMap { $0.tabs }
            .flatMap { $0.rootPane.allSurfaceIDs().map(\.uuidString) })
        return Set(sessions.keys).union(referenced)
    }

    private func removeSurfaceIfCurrent(surfaceID: String, session: RealPty?, exitStatus: Int32? = nil) {
        lock.lock()
        guard let session, sessions[surfaceID] === session else { lock.unlock(); return }
        sessions.removeValue(forKey: surfaceID)
        monitorLock.lock(); monitors.removeValue(forKey: surfaceID); monitorLock.unlock()
        // Natural shell exit must also tear down an active pipe-pane tap, else its `/bin/sh`
        // consumer + write-FD leak (every other close path already calls stopPipe).
        stopPipe(surfaceID: surfaceID)
        AgentDetector.unregisterRootPID(forSurfaceKey: surfaceID)
        // `remain-on-exit` (default on, Kouen's safe default): keep the dead leaf so the
        // surface key still resolves and `respawn-pane` can revive it. Off → close the pane
        // (or the whole tab when it was the pane's last). The close reuses the normal IPC
        // handlers, so it must run off the registry lock — resolve the target here, dispatch
        // there.
        let keep = optionStore.get("remain-on-exit")?.boolValue ?? true
        if keep {
            // The retained dead pane must not keep live-looking metadata: the detector was just
            // unregistered, so no later scanner pass can emit a nil change for this surface —
            // without these clears, list-agents/the notch/tab chips keep showing the old agent
            // and any waiting-notification on a dead pane until respawn.
            editor.setAgent(nil, forSurfaceKey: surfaceID)
            editor.setSubagents([], forSurfaceKey: surfaceID)
            if let sid = UUID(uuidString: surfaceID) {
                editor.clearTabNotification(surfaceID: sid)
                editor.setTabExitStatus(surfaceID: sid, status: exitStatus.map(Int.init))
            }
            commit()
        }
        let toClose = keep ? nil : editor.paneLocation(forSurfaceKey: surfaceID)
        fireHookLocked(.paneExited, surfaceKey: surfaceID)
        lock.unlock()

        if let toClose {
            hookQueue.async { [weak self] in
                guard let self else { return }
                if toClose.paneCount > 1 {
                    _ = self.handle(.killPane(paneID: toClose.paneID))
                } else {
                    _ = self.handle(.closeTab(tabID: toClose.tabID))
                }
            }
        }
    }

    private static func taskSummary(_ task: KouenTask) -> TaskSummary {
        TaskSummary(
            id: task.id, sessionID: task.sessionID, title: task.title, done: task.done,
            createdAt: task.createdAt, updatedAt: task.updatedAt, cwd: task.cwd
        )
    }

    private static func worktreeInfoSummary(_ info: WorktreeManager.WorktreeInfo) -> WorktreeInfoSummary {
        WorktreeInfoSummary(path: info.path, branch: info.branch, head: info.head, bare: info.bare)
    }

    // MARK: - Automations (P41)

    /// Called by `AutomationScheduler`'s timer (own queue, doesn't hold `lock`) once
    /// per tick. Mirrors how `AgentScanner` calls plain registry methods directly.
    public func tickAutomations() {
        acquireRegistryLock()
        let due = automationStore.dueAutomations(asOf: Date())
        for automation in due {
            _ = fireAutomationLocked(automation)
        }
        lock.unlock()
    }

    /// Spawns a session, launches `automation.agent`, then (after a short delay) types
    /// `automation.prompt` — same steps `.newSession`/`.send` perform under `handle()`.
    /// Callers must already hold `lock` (either `handle()`'s own for `.automationRunNow`,
    /// or `tickAutomations()`'s own acquisition for the scheduler).
    @discardableResult
    private func fireAutomationLocked(_ automation: KouenAutomation) -> Bool {
        let workspaceID = automation.workspaceID ?? editor.snapshot.workspaces.first?.id
        guard let workspaceID,
              let sessionID = editor.addSession(to: workspaceID, cwd: automation.repoPath, name: "Automation")
        else {
            automationStore.recordRun(id: automation.id, status: "error: spawn failed")
            return false
        }
        ensureSessionSurfaces(sessionID: sessionID, shell: nil)
        commit()
        fireHookLocked(.afterNewSession)
        fireHookLocked(.sessionCreated)

        guard let ws = editor.snapshot.workspaces.first(where: { $0.id == workspaceID }),
              let session = ws.sessions.first(where: { $0.id == sessionID }),
              let leaf = session.tabs.first?.rootPane.allLeaves().first
        else {
            automationStore.recordRun(id: automation.id, status: "error: surface not ready")
            return false
        }
        let surfaceID = (leaf.activeSurfaceID ?? leaf.surfaceID).uuidString
        let resolvedAgent: String
        if automation.agent.lowercased() == "auto" {
            resolvedAgent = AgentRoutingResolver.resolve(
                cwd: automation.repoPath, rules: routingRuleStore.list(),
                defaultAgent: KouenSettings.load().defaultAgentKind
            ).rawValue
        } else {
            resolvedAgent = automation.agent
        }
        sessions[surfaceID]?.write(Self.automationLaunchCommand(for: resolvedAgent))

        // ponytail: fixed 3s delay before typing the prompt — heuristic for CLI
        // cold-start, not a readiness check. Ceiling: a slow/cold CLI start could still
        // lose the prompt to the shell. Upgrade path: poll pane output for a ready
        // marker (same idea as kouenSpawnAgent's waitForPaneOutput-based callers) if
        // this proves flaky in practice.
        let prompt = automation.prompt
        let automationID = automation.id
        hookQueue.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            _ = self.handle(.send(surfaceID: surfaceID, text: prompt + "\n"))
        }
        automationStore.recordRun(id: automationID, status: "ok")
        return true
    }

    private static func automationLaunchCommand(for agent: String) -> String {
        switch agent.lowercased() {
        case "codex": return "codex\n"
        case "kiro": return "kiro\n"
        case "gemini": return "gemini\n"
        default: return "claude\n"
        }
    }

    private static func automationSummary(_ automation: KouenAutomation) -> AutomationSummary {
        AutomationSummary(
            id: automation.id, repoPath: automation.repoPath, workspaceID: automation.workspaceID,
            agent: automation.agent, prompt: automation.prompt, intervalMinutes: automation.intervalMinutes,
            enabled: automation.enabled, lastRunAt: automation.lastRunAt, lastRunStatus: automation.lastRunStatus,
            nextRunAt: automation.nextRunAt, createdAt: automation.createdAt, updatedAt: automation.updatedAt
        )
    }

    private static func routingRuleSummary(_ rule: AgentRoutingRule) -> AgentRoutingRuleSummary {
        AgentRoutingRuleSummary(
            id: rule.id, order: rule.order, kind: rule.kind.rawValue, pattern: rule.pattern,
            targetAgent: rule.targetAgent.rawValue, enabled: rule.enabled
        )
    }
}
