import AppKit
import Combine
import Foundation
import KouenCore
import KouenTerminalKit
import SwiftUI

enum AgentNotchPresentation: Equatable {
    case closed
    /// Transient one-row live activity (agent needs input / finished / errored).
    /// Auto-dismisses; hover promotes it to `.open`.
    case peek(AgentNotchPeekEvent)
    case open
}

@MainActor
final class AgentNotchViewModel: ObservableObject {
    @Published private(set) var presentation: AgentNotchPresentation = .closed
    @Published private(set) var geometry: NotchLayoutMetrics = NotchGeometry.fallback
    @Published private(set) var agents: [AgentSessionSummary] = []
    @Published private(set) var rows: [AgentNotchRowSummary] = []
    @Published private(set) var openOnHover = true
    @Published private(set) var sessionCount = 0
    /// Determinate OSC 9;4 percent per row id, when an agent reports one (build tools do;
    /// Claude Code keep-alives indeterminate). Rendered as "working · 47%" + underline bar.
    @Published private(set) var rowProgress: [String: Int] = [:]

    private var hoverTask: Task<Void, Never>?
    private var peekDismissTask: Task<Void, Never>?
    private var isHovering = false
    private let maximumVisibleRows = 8
    /// Hover must be deliberate: a fly-by across the menu bar should never open the HUD.
    /// 400 ms dwell (skill guidance 250–600 ms); tap still opens instantly.
    private let hoverOpenDelay: UInt64 = 400_000_000
    private let hoverCloseDelay: UInt64 = 190_000_000
    private let peekDuration: Duration = .seconds(4)
    /// Per-row peek cooldown so a flapping detector can't strobe the notch.
    private let peekCooldown: TimeInterval = 10
    private var peekStates: [String: AgentNotchPeekDecider.RowState]?
    private var lastPeekAt: [String: Date] = [:]

    var isOpen: Bool {
        if case .open = presentation { return true }
        return false
    }

    var isPeeking: Bool {
        if case .peek = presentation { return true }
        return false
    }

    var waitingCount: Int {
        rows.reduce(0) { $0 + $1.waitingCount }
    }

    var workingCount: Int {
        rows.filter { $0.agentActivity == .working }.count
    }

    var agentCount: Int {
        rows.filter { $0.agentKind != nil }.count
    }

    var visibleRows: [AgentNotchRowSummary] {
        Array(rows.prefix(maximumVisibleRows))
    }

    var hasOverflowRows: Bool {
        rows.count > maximumVisibleRows
    }

    var headerSummary: String {
        AgentNotchProjection.headerSummary(
            workingCount: workingCount,
            waitingCount: waitingCount,
            sessionCount: sessionCount
        )
    }

    @Published private(set) var openContentHeight: CGFloat = 86

    // MARK: - Motion

    /// Asymmetric springs (skill: open livelier, close fully damped); Reduce Motion → fades.
    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var openAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.38, dampingFraction: 0.8)
    }

    var closeAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.10) : .spring(response: 0.45, dampingFraction: 1.0)
    }

    func updateGeometry(_ geometry: NotchLayoutMetrics) {
        guard geometry != self.geometry else { return }
        self.geometry = geometry
        recomputeOpenContentHeight()
    }

    private func recomputeOpenContentHeight() {
        let rowCount = max(1, visibleRows.count)
        let rowStack = CGFloat(rowCount) * 38 + CGFloat(max(0, rowCount - 1)) * 5
        let ideal = 20 + 30 + 6 + rowStack + (hasOverflowRows ? 18 : 0)
        let minimum: CGFloat = rows.isEmpty ? 86 : 98
        openContentHeight = min(CGFloat(geometry.openHeight), max(minimum, ideal.rounded(.up)))
    }

    // MARK: - Data refresh

    func refreshFromCoordinator() {
        let coordinator = SessionCoordinator.shared
        openOnHover = coordinator.settings.notchOpenOnHover
        let currentAgents = coordinator.agentsList()
        agents = AgentNotchProjection.sortedAgents(currentAgents)
        var updatedRows = AgentNotchProjection.rows(from: coordinator.snapshot, agents: currentAgents)
        // Reconcile OSC 9;4 progress state with detector-driven activity. The projection
        // derives agentActivity from the daemon snapshot (AgentDetector), which Claude Code
        // doesn't keep at .working between turns. SurfaceProgressTracker is the
        // terminal-native signal (OSC 9;4); promote a row to .working when any of its tab's
        // surfaces has an active progress report, so the notch agrees with the tab-bar dot.
        let tracker = SurfaceProgressTracker.shared
        let tabSurfaces: [UUID: [SurfaceID]] = coordinator.snapshot.workspaces
            .flatMap(\.sessions)
            .flatMap(\.tabs)
            .reduce(into: [:]) { map, tab in
                map[tab.id] = tab.rootPane.allSurfaceIDs()
            }
        var progress: [String: Int] = [:]
        for i in updatedRows.indices {
            guard let tabID = updatedRows[i].tabID, let surfaces = tabSurfaces[tabID] else { continue }
            if surfaces.contains(where: { tracker.isActive($0) }) {
                updatedRows[i].agentActivity = .working
            }
            if let percent = surfaces.compactMap({ tracker.progressPercent($0) }).first {
                progress[updatedRows[i].id] = percent
            }
        }
        rows = updatedRows
        rowProgress = progress
        sessionCount = Set(rows.map(\.sessionID)).count
        recomputeOpenContentHeight()
        considerPeek()
    }

    // MARK: - Peek

    /// Diff this refresh against the last one and surface at most one peek-worthy
    /// transition. Suppressed while Kouen is frontmost (the user already sees the tab
    /// dot), while the HUD is open, and per-row for `peekCooldown` after a peek.
    private func considerPeek() {
        let (events, next) = AgentNotchPeekDecider.decide(previous: peekStates, rows: rows)
        peekStates = next
        guard !events.isEmpty, !isOpen else { return }
        // Allow peek even when Kouen is frontmost (user sees the notch pop for attention
        // events regardless of app focus — the tab dot alone is too subtle).
        let now = Date()
        guard let event = events.first(where: { event in
            guard let last = lastPeekAt[event.row.id] else { return true }
            return now.timeIntervalSince(last) >= peekCooldown
        }) else { return }
        lastPeekAt[event.row.id] = now
        showPeek(event)
    }

    private func showPeek(_ event: AgentNotchPeekEvent) {
        withAnimation(openAnimation) { presentation = .peek(event) }
        armPeekDismiss(after: peekDuration)
    }

    private func armPeekDismiss(after duration: Duration) {
        peekDismissTask?.cancel()
        peekDismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isPeeking else { return }
                self.close()
            }
        }
    }

    // MARK: - Hover

    func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()
        isHovering = hovering
        if hovering {
            // Hovering a peek keeps it alive and promotes it to the full HUD after the dwell.
            if isPeeking { peekDismissTask?.cancel() }
            guard openOnHover, !isOpen else { return }
            hoverTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: self?.hoverOpenDelay ?? 0)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.isHovering else { return }
                    self.open()
                }
            }
        } else {
            // Hover exit while peeking: resume the auto-dismiss countdown from full duration
            // (hovering paused it — see the `isPeeking` branch above).
            if isPeeking {
                armPeekDismiss(after: peekDuration)
                return
            }
            hoverTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: self?.hoverCloseDelay ?? 0)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, !self.isHovering else { return }
                    self.close()
                }
            }
        }
    }

    // MARK: - Presentation

    func open() {
        peekDismissTask?.cancel()
        refreshFromCoordinator()
        withAnimation(openAnimation) { presentation = .open }
    }

    func close() {
        peekDismissTask?.cancel()
        withAnimation(closeAnimation) { presentation = .closed }
    }

    func toggleOpen() {
        isOpen ? close() : open()
    }

    /// Resolve a waiting agent's approval prompt straight from the notch, without navigating
    /// there first — same bytes `AgentApprovalBar` sends on the pane itself (`\n` to continue,
    /// Ctrl-C to abort), just addressed at the row's surface directly via
    /// `terminalHostIfExists(for:)` so it works for a row that isn't the focused pane.
    /// Deliberately doesn't call `close()` — approving from the notch is meant to let the user
    /// keep working somewhere else, not force-navigate them into the pane they just resolved.
    func decideRow(_ row: AgentNotchRowSummary, approve: Bool) {
        guard let surfaceID = row.surfaceID,
              let host = SessionCoordinator.shared.terminalHostIfExists(for: surfaceID)
        else { return }
        host.sendInput(approve ? Data([0x0A]) : Data([0x03]))
    }

    /// Free-text quick-reply, for when the agent's prompt needs more than Allow/Deny — types
    /// `text` into the row's own pane followed by Enter, same as the user typing it there
    /// directly. Empty/whitespace-only text is a no-op (nothing worth sending).
    func replyToRow(_ row: AgentNotchRowSummary, text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let surfaceID = row.surfaceID,
              let host = SessionCoordinator.shared.terminalHostIfExists(for: surfaceID)
        else { return }
        host.sendInput(Data(text.utf8) + Data([0x0A]))
    }

    func openRow(_ row: AgentNotchRowSummary) {
        let coordinator = SessionCoordinator.shared
        coordinator.selectWorkspace(row.workspaceID)
        coordinator.selectSession(workspaceID: row.workspaceID, sessionID: row.sessionID)
        if let tabID = row.tabID {
            coordinator.selectTab(workspaceID: row.workspaceID, tabID: tabID)
            // Narrow further to the exact split pane the row represents, not just the tab —
            // a tab can hold several panes, and without this the user still has to hunt for
            // the one the agent/session actually lives in.
            if let paneID = row.paneID, let surfaceID = row.surfaceID {
                coordinator.selectPaneSurface(tabID: tabID, paneID: paneID, surfaceID: surfaceID)
            }
        }
        AgentNotchWindowActivator.bringKouenToFront()
        close()
    }
}

@MainActor
enum AgentNotchWindowActivator {
    static func bringKouenToFront() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain && !(window is NSPanel) {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
