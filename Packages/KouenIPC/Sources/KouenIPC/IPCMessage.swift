import Foundation

/// Current IPC wire-format version. Bump whenever a breaking change is made to
/// `IPCRequest` or `IPCResponse`. The daemon rejects `identifyClient` messages
/// whose `protocolVersion` does not match this value.
///
/// Bumped 2026-07-06 (P25 W1 slice 2): added `.mobileListClients`/`.mobileRevokeClient`
/// to `IPCRequest` and `.mobileClients` to `IPCResponse`.
///
/// Bumped 2026-07-08 (P37 Phase B): added `.mobilePairingInfo` to both enums. Bumping
/// (rather than relying on the additive-case graceful-degradation path) is deliberate:
/// this release also changes daemon-side bridge *behavior* (P37 Phase A hardening —
/// rate-limit, per-device secret, off-`.main` queue), and `install-graceful.sh` reuses
/// the running daemon untouched whenever the protocol is unchanged. A bump is the signal
/// that forces the daemon to restart into the new binary so the hardening actually ships.
///
/// Bumped 2026-07-12: added `.activateGUIWindow` to `IPCRequest` and `.activateWindow` to
/// `IPCResponse` — the daemon→GUI window-activation push a mobile-triggered session tap uses
/// to bring the Mac window forward (Feature A). Both are additive/graceful (an old peer
/// ignores them), but a bump forces the daemon to restart into the new binary on
/// `install-graceful.sh` so the new push path is actually served.
///
/// Bumped 2026-08-06 (M2/M5 daemon-side gap, found live in v4.10.0): the M2 Agent Routing
/// Rule (`.routingRuleList`/`Get`/`Create`/`Update`/`Delete`/`Reorder`) and M5 Saved Layouts
/// (`.savedLayoutList`/`Save`/`Delete`) `IPCRequest`/`IPCResponse` cases shipped in v4.10.0
/// without bumping this constant — `install-graceful.sh` read "protocol unchanged" and kept
/// the pre-release daemon running, so those two features' daemon-side handlers
/// (`SurfaceRegistry`) never actually loaded in the live install despite the new GUI binary
/// being in place. Same failure class the 2026-07-08 bump note above already warns about;
/// missed here because the new cases were additive syntactically, not functionally.
///
/// Bumped 2026-08-09 (M10): added `.ccRunStart`/`Get`/`List`/`Cancel` to `IPCRequest` and
/// `.ccRunInfo`/`.ccRuns` to `IPCResponse` for the Claude Code Harness (`ClaudeCodeHarness`).
/// Same functional-not-just-syntactic-additive case as M2/M5 above — bumping deliberately
/// so `install-graceful.sh` restarts into a daemon binary that actually has the handler.
///
/// Bumped 2026-08-09 (M10 follow-up): added `effort: String?` to `.ccRunStart`'s associated
/// values (passed through to `claude --effort`). Changes the case's wire shape, same as any
/// other associated-value change — bump so an old/new pair can't silently decode a case with
/// the wrong arity.
///
/// Bumped 2026-08-10: added `.flushSessionState` to `IPCRequest` — daemon-side handler for
/// `install-graceful.sh`'s pre-kill flush (see that case's doc comment). Same functional-
/// addition rule as M2/M5/M10 above.
///
/// Bumped 2026-08-23: added `.notifyDone` to `IPCRequest` — a Stop-hook ("turn finished
/// normally") notification distinct from `.notify` ("real attention/permission event"). Both
/// used to funnel through `.notify`, which unconditionally set `Tab.status = .waiting` and made
/// the Agent Notch show Reply/Deny/Allow approval controls after every ordinary turn, not just
/// real permission prompts. Same functional-addition rule as M2/M5/M10 above — bump so
/// `install-graceful.sh` restarts into a daemon binary that actually has the new handler.
public let ipcProtocolVersion: Int = 9

public enum IPCRequest: Codable, Sendable {
    case ping
    case listWorkspaces
    case listSurfaces
    /// List every running agent (one row per tab carrying a detected `Tab.agent`)
    /// with its workspace/session/tab/pane context, state, and `.waiting` signal.
    case listAgents
    /// P25 F3: list every device currently paired to the mobile WS bridge.
    /// Empty on daemons where the bridge never started (opt-in, see `MobileBridgeServer`).
    case mobileListClients
    /// P25 F3: revoke one paired device by id — cancels its live connection if attached
    /// and drops it from the paired-devices table. `.error` if the id isn't paired.
    case mobileRevokeClient(id: String)
    /// P37 B1: current mobile-bridge pairing state, for the in-app QR panel (Settings ▸
    /// Remote) so a user never has to read the URL out of daemon.log. Returns the live
    /// pairing URL, seconds until the current token rotates, and whether the bridge is
    /// enabled. Nil URL when the bridge is off (opt-in, see `MobileBridgeServer`).
    case mobilePairingInfo
    /// Starts or stops the mobile WS bridge in the already-running daemon, so the Settings
    /// toggle no longer needs a full daemon restart to take effect (that used to drop every
    /// live PTY/agent session hosted by the pane it restarted).
    case setMobileBridgeEnabled(Bool)
    case newWorkspace(name: String)
    case newSession(workspaceID: UUID, cwd: String?, name: String?, shell: String? = nil, worktreePath: String? = nil, parentRepoPath: String? = nil, taskName: String? = nil)
    /// tmux `new-session -t <session>`: an independent session grouped with the target,
    /// sharing its window list (linked windows / shared surfaces).
    case newSessionInGroup(targetSessionID: UUID, name: String?)
    case newTab(workspaceID: UUID, cwd: String?, shell: String? = nil)
    case newTabInWorkspace(named: String, cwd: String?, shell: String? = nil)
    case newSplit(tabID: UUID, paneID: UUID?, direction: SplitDirection, shell: String? = nil, before: Bool = false)
    case newSurface(tabID: UUID, paneID: UUID, shell: String? = nil)
    case selectPaneSurface(tabID: UUID, paneID: UUID, surfaceID: UUID)
    case splitPaneSurface(tabID: UUID, sourcePaneID: UUID, surfaceID: UUID, targetPaneID: UUID, direction: SplitDirection, beforeTarget: Bool)
    case selectWorkspace(id: UUID)
    case selectWorkspaceByName(name: String)
    case selectSession(workspaceID: UUID, sessionID: UUID)
    case selectTab(workspaceID: UUID, tabID: UUID)
    case reorderTab(workspaceID: UUID, tabID: UUID, toIndex: Int)
    case swapTab(workspaceID: UUID, tabID: UUID, withIndex: Int)
    case renumberWindows(sessionID: UUID)
    case reorderSession(workspaceID: UUID, sessionID: UUID, toIndex: Int)
    case closeTab(tabID: UUID)
    case closeSession(sessionID: UUID)
    case closeWorkspace(id: UUID)
    case setTheme(name: String)
    case setKeepSessionsOnQuit(Bool)
    /// Pin/unpin a session so it survives a clean quit even with `keepSessionsOnQuit` off
    /// (Plain mode "promote to persistent"). `true` = persistent, `false` = ephemeral.
    case setSessionPersistent(sessionID: UUID, persistent: Bool)
    /// Pin/unpin an individual tab so it survives a clean quit even when neither
    /// `keepSessionsOnQuit` nor its session's pin is set. `true` = persistent, `false` = ephemeral.
    case setTabPersistent(tabID: UUID, persistent: Bool)
    /// Tags an existing tab with worktree isolation metadata (P32) — used when moving an
    /// already-running tab's shell into a worktree (branch-reactive auto-isolate) rather than
    /// creating a new tab via `newSession`.
    case setTabWorktree(tabID: UUID, worktreePath: String, parentRepoPath: String?, taskName: String? = nil)
    /// Tear down sessions that are neither globally kept nor individually pinned. The GUI calls
    /// this on a *clean* quit so Plain-mode sessions behave like a normal terminal; pinned and
    /// keep-on-quit sessions are left running.
    case closeEphemeralSessions
    case notify(surfaceID: String, title: String, body: String)
    /// A Stop-hook ("agent finished this turn normally") notification — distinct from
    /// `.notify`, which is for a real attention/permission event. Sets `Tab.status = .done`
    /// instead of `.waiting`, so the Agent Notch doesn't show Reply/Deny/Allow controls for a
    /// turn that needed no decision from the user.
    case notifyDone(surfaceID: String, title: String, body: String)
    /// Claude Code's `PreToolUse`(Task)/`SubagentStop` hook push (P38 Phase B) — signals a
    /// Task-tool subagent starting/stopping, which proc-scan can't see (it runs in-process,
    /// no child PID). `active` true = start, false = stop.
    case setSubagentHint(surfaceID: String, kind: AgentKind, active: Bool)
    case clearNotification(surfaceID: String)
    case updateTabTitle(surfaceID: String, title: String)
    /// Sets a durable, agent/human-set purpose label on one pane surface (e.g. "build",
    /// "claude") — distinct from `title`, which is OSC/program-driven and gets overwritten by
    /// the next shell prompt. Nil `label` clears it. Lets an agent disambiguate panes in a
    /// multi-pane tab (`kouenList`'s `paneJSON` exposes it) without guessing from output.
    case setPaneLabel(surfaceID: String, label: String?)
    case updateTabCwd(surfaceID: String, path: String)
    case updateTabGitBranch(workspaceID: UUID, tabID: UUID, branch: String?)
    /// Posted by kouen-mcp after a mutating tool succeeds, so the daemon can
    /// stamp `lastMCPControlAt` on the affected tab and the UI shows a badge.
    case notifyMCPActivity(surfaceID: String, toolName: String)
    case send(surfaceID: String, text: String)
    case sendData(surfaceID: String, data: Data)
    case getSnapshot
    case createSurface(cwd: String?, shell: String?)
    case ensureSurface(surfaceID: String, cwd: String?, shell: String?, rows: UInt16, cols: UInt16, scrollbackBytes: Int?)
    case attachSurface(surfaceID: String)
    /// Close a bare surface not owned by the layout (e.g. a `display-popup` shell).
    case closeSurface(surfaceID: String)
    // Pane + key commands
    case sendKeys(surfaceID: String, keys: [String])
    case capturePane(surfaceID: String, includeScrollback: Bool)
    /// `capture-pane -S <start> -E <end>`: a line range from scrollback+screen,
    /// negative numbers counting back from the bottom (tmux semantics). `escapeSequences`
    /// (`-e`) keeps SGR/escapes raw (byte-stream, faithful to what the program emitted);
    /// otherwise the lines are grid-reconstructed plain text. `joinWrapped` (`-J`) joins
    /// soft-wrapped rows into their logical line (grid path only). Returns `.text`.
    case capturePaneRange(surfaceID: String, start: Int?, end: Int?, escapeSequences: Bool, joinWrapped: Bool)
    /// P34 F3 (`kouenGetLastBlock`/`kouenGetBlock`): a command + its output + exit code,
    /// delimited by OSC 133 `C`/`D`. Nil `blockID` = the most recently *finished* block.
    /// Reconstructed on demand from retained scrollback bytes (the same replay-through-a-fresh-
    /// emulator path `capturePaneRange`'s grid reconstruction already uses) — not a live
    /// subscription, so it also works for a pane no GUI window currently has open. Returns
    /// `.blockInfo`; an old daemon that doesn't know this case replies `.error("unrecognized
    /// request")`.
    case getBlock(surfaceID: String, blockID: Int?)
    /// `pipe-pane`: tee the pane's live output to a spawned shell command's stdin.
    /// `shellCommand == nil` stops an active pipe (toggle off).
    case pipePane(surfaceID: String, shellCommand: String?)
    /// `wait-for <channel>` (mode `wait`/`signal`/`lock`/`unlock`): named-channel
    /// synchronization. `wait`/`lock` may defer the reply (block the client) until a
    /// `signal`/`unlock`. Intercepted at the `DaemonServer` socket layer, never under the
    /// registry lock.
    case waitFor(channel: String, mode: String)
    /// `link-window`: make `tabID`'s panes appear as a new linked tab in another
    /// session (shared surfaces). `unlinkWindow` removes the linked copy.
    case linkWindow(tabID: UUID, targetSessionID: UUID)
    case unlinkWindow(tabID: UUID)
    case killPane(paneID: UUID)
    case swapPanes(srcPaneID: UUID, dstPaneID: UUID)
    case resizePane(paneID: UUID, direction: ResizeDirection, amount: Int)
    /// Set an absolute split ratio. The branch is identified by the representative
    /// (first) leaf of each child subtree, which is unambiguous even when nested.
    case resizePaneRatio(tabID: UUID, firstPaneID: UUID, secondPaneID: UUID, ratio: Double)
    case zoomPane(paneID: UUID)
    case setCopyMode(surfaceID: String, enabled: Bool)
    case renameTab(tabID: UUID, name: String)
    case renameSession(sessionID: UUID, name: String)
    case renameWorkspace(workspaceID: UUID, name: String)
    case detectAgent(surfaceID: String)
    // Surface output streaming + attach
    case subscribeSurfaceOutput(surfaceID: String, label: String?)
    case cancelSubscription(surfaceID: String)
    case replayScrollback(surfaceID: String, fromSequence: UInt64?)
    /// Like `replayScrollback`, but the reply also carries the sequence one past the last
    /// replayed byte (`replayResult`). A client that subscribed FIRST uses that boundary to
    /// dedupe its buffered live frames and close the replay→subscribe gap. An old daemon doesn't
    /// know this case and replies `.error("unrecognized request")`, so the caller degrades to the
    /// plain `replayScrollback` (replay-then-stream) path — no dedup, but never a double-deliver.
    case replayScrollbackSequenced(surfaceID: String, fromSequence: UInt64?)
    case resizeSurface(surfaceID: String, rows: UInt16, cols: UInt16)
    case detachSurface(surfaceID: String)
    /// Identify this connection to the daemon so it shows up in `list-clients`
    /// and can be addressed by `detach-client`. Idempotent; safe to send once
    /// per persistent connection. `protocolVersion` must equal `ipcProtocolVersion`;
    /// the daemon returns `.protocolRejected` and closes the connection if it does not.
    case identifyClient(label: String, protocolVersion: Int)
    case listClients
    case detachClient(clientID: UUID)
    case daemonStats
    // Paste buffers
    case setBuffer(name: String?, data: Data)
    case getBuffer(name: String?)
    case listBuffers
    case deleteBuffer(name: String)
    case pasteBuffer(surfaceID: String, name: String?, bracketed: Bool)
    // Phase 4: layouts + pane ops
    case selectPaneDirectional(currentPaneID: UUID, direction: DirectionalAxis)
    /// Commit the active (focused) pane for a tab, server-side. Distinct from
    /// `selectPaneDirectional`, which only computes a neighbor.
    case selectPane(tabID: UUID, paneID: UUID)
    /// Long-lived subscription: the daemon pushes `snapshotChanged(revision:)` on every
    /// layout commit so clients (the attach-window compositor) re-render on structure
    /// changes without polling. Intercepted by `DaemonServer` (FD-level), like
    /// `subscribeSurfaceOutput`.
    case subscribeSnapshot(label: String?)
    case applyLayout(tabID: UUID, layout: String, mainPaneID: UUID?)
    case nextLayout(tabID: UUID)
    case previousLayout(tabID: UUID)
    case rotatePanes(tabID: UUID, forward: Bool)
    case breakPane(paneID: UUID)
    case joinPane(sourcePaneID: UUID, destPaneID: UUID, direction: SplitDirection, before: Bool = false)
    case respawnPane(surfaceID: String, keepHistory: Bool)
    case clearHistory(surfaceID: String)
    case resizeWindow(tabID: UUID, rows: UInt16, cols: UInt16)
    // Phase 6: options + hooks + display
    case setOption(scope: String, target: String?, key: String, rawValue: String)
    case showOptions(scope: String?)
    /// Environment for spawned shells. `sessionID == nil` → global; `value == nil` → unset.
    case setEnvironment(sessionID: UUID?, key: String, value: String?)
    case showEnvironment(sessionID: UUID?)
    case bindHook(event: String, source: String, condition: String?)
    case unbindHook(id: UUID)
    case listHooks(event: String?)
    case displayMessage(format: String)
    /// tmux `show-messages`: the daemon's recent display-message log (most recent last).
    case showMessages
    case runGit(args: [String], cwd: String)

    // Browser tool integration (P14)
    // `originSurfaceID`: the pane the calling agent is actually running in (from its own
    // `KOUEN_SURFACE` env var) — anchors the new browser pane to that agent's own
    // session/tab instead of whatever tab the human currently has focused in the GUI.
    // `nil` falls back to the GUI's active tab (menu/keyboard-triggered opens have no
    // originating agent surface).
    case browserOpen(url: URL, direction: SplitDirection?, originSurfaceID: UUID?)
    case browserNavigate(paneID: UUID, url: URL)
    case browserWait(paneID: UUID, timeoutSeconds: Double?)
    case browserSnapshot(paneID: UUID, interactive: Bool?)
    case browserInteract(paneID: UUID, action: String, elementID: String, text: String?)
    case browserClose(paneID: UUID)
    case browserScreenshot(paneID: UUID)
    case browserNetwork(paneID: UUID)
    case browserCookies(paneID: UUID)
    case browserStorage(paneID: UUID, storageType: String)
    case browserEvaluate(paneID: UUID, script: String)
    case browserGoBack(paneID: UUID)
    case browserGoForward(paneID: UUID)
    case browserReload(paneID: UUID)
    case browserResponse(id: UUID, response: BrowserResponsePayload)
    // Sidebar navigation
    case openGitPanel(repoPath: String?)
    /// Ask the daemon to tell the GUI to bring its window to the foreground. Sent by
    /// `MobileBridgeServer` after a phone-triggered attach/spawn has already driven the
    /// `.selectWorkspace`/`.selectSession`/`.selectTab` selects, so the Mac window jumps to
    /// (and activates on) the same session the phone just opened. The daemon forwards it to
    /// the GUI's snapshot-subscriber fd as an `.activateWindow` push (same one-way channel as
    /// `.openGitPanel`); a daemon that predates this case replies `.error` and the bridge
    /// simply skips activation.
    case activateGUIWindow

    // Tasks (P40 F1): session-scoped checklist items, MCP-addressable. `sessionID == nil`
    // in `taskList` returns Tasks across every session (powers the Task Dashboard).
    case taskList(sessionID: UUID?)
    case taskGet(id: UUID)
    case taskCreate(sessionID: UUID, title: String)
    case taskUpdate(id: UUID, title: String?, done: Bool?, status: TaskSummary.Status?)
    case taskDelete(id: UUID)

    // Worktree (MCP resource, P40 F2): wraps `WorktreeManager` 1:1, no new domain logic.
    // `force: true` on `worktreeRemove` requires explicit per-call opt-in (mirrors
    // `WorktreeManager.remove(force:)`'s own default of `false` — never silently discard
    // uncommitted work).
    case worktreeList(repoPath: String)
    case worktreeCreate(repoPath: String, sessionID: String, branch: String?, baseRef: String?)
    case worktreeRemove(repoPath: String, worktreePath: String, force: Bool)

    // Automations (P41): scheduled agent launches. `intervalMinutes == 0` means
    // manual/run-now only — never auto-fires. Connection to `agent-memory/plans` is
    // purely the `prompt` text convention (e.g. "ทำต่อ p40"); Kouen has no plan-file
    // awareness, it just spawns a session and types the prompt, same as a human would.
    case automationList
    case automationGet(id: UUID)
    case automationCreate(repoPath: String, workspaceID: UUID?, agent: String, prompt: String, intervalMinutes: Int)
    case automationUpdate(id: UUID, repoPath: String?, agent: String?, prompt: String?, intervalMinutes: Int?)
    case automationDelete(id: UUID)
    case automationSetEnabled(id: UUID, enabled: Bool)
    case automationRunNow(id: UUID)

    // Agent Routing Rules (M2): ordered rules resolving `agent: "auto"` to a concrete
    // AgentKind at spawn time (kouenSpawnAgent, Automation fire). `kind` is "path" or
    // "stack"; `pattern` is the glob (path) or SignalFileRouter stack name (stack).
    case routingRuleList
    case routingRuleGet(id: UUID)
    case routingRuleCreate(kind: String, pattern: String, targetAgent: String, enabled: Bool)
    case routingRuleUpdate(id: UUID, kind: String?, pattern: String?, targetAgent: String?, enabled: Bool?)
    case routingRuleDelete(id: UUID)
    case routingRuleReorder(kind: String, orderedIDs: [UUID])

    // Saved Layouts (M5): named, reusable pane-arrangement templates. `savedLayoutSave`
    // captures `tabID`'s current pane tree SHAPE only (split directions/ratios/leaf
    // positions) — no running processes, no cwd. Applying a layout is entirely client-side
    // (repeated `.newTab` + `.newSplit` requests walking the saved shape), so there is no
    // `.savedLayoutApply` request here.
    case savedLayoutList
    case savedLayoutSave(name: String, tabID: UUID)
    case savedLayoutDelete(id: UUID)

    // Claude Code Harness (M10): drives `claude -p --output-format stream-json` as a real
    // subprocess (`ClaudeCodeHarness`), replacing pty screen-scrape for headless/automation
    // runs. `id` is generated by the caller (kouen-mcp) so it doubles as the Claude
    // `--session-id` — no separate mapping table needed.
    case ccRunStart(id: UUID, prompt: String, cwd: String, profile: String, model: String?, effort: String?)
    case ccRunGet(id: UUID)
    case ccRunList
    case ccRunCancel(id: UUID)

    /// Forces an immediate, synchronous `layout.json` write (bypasses the normal 0.5s
    /// debounce). `install-graceful.sh`'s protocol-changed restart path sends this and waits
    /// for `.ok` before killing the daemon, instead of a blind `sleep` racing the debounce —
    /// see `agent-memory/knowledge/cases/` for the incident this closes.
    case flushSessionState
}

public enum BrowserRequestPayload: Codable, Sendable {
    case open(url: URL, direction: SplitDirection?, originSurfaceID: UUID?)
    case navigate(paneID: UUID, url: URL)
    case wait(paneID: UUID, timeoutSeconds: Double?)
    case snapshot(paneID: UUID, interactive: Bool?)
    case screenshot(paneID: UUID)
    case network(paneID: UUID)
    case cookies(paneID: UUID)
    case storage(paneID: UUID, storageType: String)
    case interact(paneID: UUID, action: String, elementID: String, text: String?)
    case close(paneID: UUID)
    case evaluate(paneID: UUID, script: String)
    case goBack(paneID: UUID)
    case goForward(paneID: UUID)
    case reload(paneID: UUID)
}

public enum BrowserResponsePayload: Codable, Sendable {
    case open(paneID: UUID)
    case ok
    case snapshot(BrowserSnapshot)
    case screenshot(String)
    case network([BrowserNetworkEntry])
    case cookies([BrowserCookie])
    case storage([String: String])
    case text(String)
    case error(String)
}

public struct BrowserCookie: Codable, Sendable {
    public var name: String
    public var value: String
    public var domain: String
    public var path: String
    public var expires: Double?
    public var isSecure: Bool
    public var isHTTPOnly: Bool

    public init(name: String, value: String, domain: String, path: String, expires: Double?, isSecure: Bool, isHTTPOnly: Bool) {
        self.name = name; self.value = value; self.domain = domain; self.path = path
        self.expires = expires; self.isSecure = isSecure; self.isHTTPOnly = isHTTPOnly
    }
}

public struct BrowserNetworkEntry: Codable, Sendable {
    public var id: String
    public var url: String
    public var method: String
    public var status: Int?
    public var requestBody: String?
    public var responseBody: String?
    public var duration: Double?
    public var timestamp: Double
}

public struct BrowserSnapshot: Codable, Sendable {
    public var url: String
    public var title: String
    public var text: String
    public var elements: [BrowserElement]
    public var logs: [String]?

    public init(url: String, title: String, text: String, elements: [BrowserElement], logs: [String]? = nil) {
        self.url = url
        self.title = title
        self.text = text
        self.elements = elements
        self.logs = logs
    }
}

public struct BrowserElementBounds: Codable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
}

public struct BrowserElement: Codable, Sendable {
    public var id: String
    public var tag: String
    public var role: String?
    public var text: String
    public var value: String
    public var placeholder: String
    public var href: String?
    public var bounds: BrowserElementBounds?
    public var visible: Bool?
}

public enum DirectionalAxis: String, Codable, Sendable {
    case left, right, up, down

    /// Accept the short spellings (`l`, `L`, `r`, `R`, `u`, `U`, `d`, `D`)
    /// in addition to the full names. Used by CLI flag parsing.
    public init?(short: String) {
        switch short.lowercased() {
        case "l", "left": self = .left
        case "r", "right": self = .right
        case "u", "up": self = .up
        case "d", "down": self = .down
        default: return nil
        }
    }
}

public enum IPCResponse: Codable, Sendable {
    case ok
    case pong
    case workspaces([WorkspaceSummary])
    case surfaces([SurfaceSummary])
    case agents([AgentSessionSummary])
    case mobileClients([PairedDeviceSummary])
    /// P37 B1: reply to `mobilePairingInfo`. `url` is nil when the bridge is disabled or
    /// hasn't minted its first token yet; `secondsRemaining` counts down to the next token
    /// rotation; `enabled` mirrors the `mobileBridgeEnabled` setting the daemon started with.
    case mobilePairingInfo(url: String?, secondsRemaining: Int, enabled: Bool)
    case workspaceID(UUID)
    case sessionID(UUID)
    case tabID(UUID)
    case paneID(UUID)
    case surfaceID(String)
    case snapshot(SessionSnapshot)
    case text(String)
    case data(Data, sequence: UInt64)
    /// Reply to `replayScrollbackSequenced`: the replay text plus the sequence one past its last
    /// byte. Only ever sent in answer to that request, so an old client never receives it.
    case replayResult(text: String, endSequence: UInt64)
    /// Pushed on a `subscribeSnapshot` channel when the layout commits at `revision`.
    case snapshotChanged(revision: Int)
    case agentInfo(AgentSnapshot?)
    case clients([ClientSummary])
    case daemonStats(DaemonStats)
    case clientID(UUID)
    case buffer(BufferSummary)
    case buffers([BufferSummary])
    case options([OptionEntry])
    case hookID(UUID)
    case hooks([HookEntry])
    case error(String)
    /// Sent in response to `identifyClient` when the client's `protocolVersion` does not
    /// match `ipcProtocolVersion`. The daemon closes the connection immediately after.
    case protocolRejected(reason: String)
    case gitResult(output: String, stderr: String, success: Bool)
    /// Reply to `getBlock`. Nil when no matching block exists (never started, wrong id, or
    /// the pane's shell doesn't emit OSC 133 `C` yet).
    case blockInfo(BlockSummary?)

    // Browser tool integration (P14)
    case browserRequest(id: UUID, paneID: UUID?, req: BrowserRequestPayload)
    case browserSuccess(BrowserResponsePayload)
    // Sidebar navigation push
    case openGitPanel(repoPath: String?)
    /// Pushed to the GUI's snapshot-subscriber fd (in answer to a mobile bridge
    /// `.activateGUIWindow` request) so the GUI brings its window to the foreground for a
    /// phone-triggered session tap. GUI-directed only; other clients ignore it.
    case activateWindow

    // Tasks (P40 F1)
    case taskInfo(TaskSummary?)
    case tasks([TaskSummary])

    // Worktree (MCP resource, P40 F2)
    case worktrees([WorktreeInfoSummary])
    case worktreePath(String?)

    // Automations (P41)
    case automationInfo(AutomationSummary?)
    case automations([AutomationSummary])

    // Agent Routing Rules (M2)
    case routingRuleInfo(AgentRoutingRuleSummary?)
    case routingRules([AgentRoutingRuleSummary])

    // Saved Layouts (M5)
    case savedLayoutInfo(SavedLayout?)
    case savedLayouts([SavedLayout])

    // Claude Code Harness (M10)
    case ccRunInfo(ClaudeRunSummary?)
    case ccRuns([ClaudeRunSummary])
}

public struct OptionEntry: Codable, Sendable, Equatable {
    public var scope: String
    public var target: String?
    public var key: String
    public var value: String
    public init(scope: String, target: String?, key: String, value: String) {
        self.scope = scope
        self.target = target
        self.key = key
        self.value = value
    }
}

public struct HookEntry: Codable, Sendable, Equatable {
    public var id: UUID
    public var event: String
    public var commandSource: String
    public var condition: String?
    public init(id: UUID, event: String, commandSource: String, condition: String?) {
        self.id = id
        self.event = event
        self.commandSource = commandSource
        self.condition = condition
    }
}

public struct BufferSummary: Codable, Sendable, Equatable {
    public var name: String
    public var byteCount: Int
    public var preview: String
    public var createdAt: Date
    public var data: Data?

    public init(name: String, byteCount: Int, preview: String, createdAt: Date, data: Data? = nil) {
        self.name = name
        self.byteCount = byteCount
        self.preview = preview
        self.createdAt = createdAt
        self.data = data
    }
}

public enum ResizeDirection: String, Codable, Sendable {
    case left
    case right
    case up
    case down
}

public struct WorkspaceSummary: Codable, Sendable {
    public var id: UUID
    public var name: String
    public var tabCount: Int

    public init(id: UUID, name: String, tabCount: Int) {
        self.id = id
        self.name = name
        self.tabCount = tabCount
    }
}

public struct IPCEnvelope: Codable, Sendable {
    public var request: IPCRequest?

    public init(request: IPCRequest) {
        self.request = request
    }
}

public struct IPCReply: Codable, Sendable {
    public var response: IPCResponse

    public init(response: IPCResponse) {
        self.response = response
    }
}
