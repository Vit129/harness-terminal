#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation
import HarnessCore

/// Builds a FormatContext from snapshot state. Extracted from SurfaceRegistry for clarity.
/// Called under registryLock — all inputs are passed explicitly.
enum FormatContextBuilder {
    static func build(
        snapshot: SessionSnapshot,
        editor: SessionEditor,
        surfaceKey: String?,
        clientName: String?,
        sessions: [DaemonSurfaceID: RealPty],  // for PTY-backed live fields
        attachedClientCount: Int?
    ) -> FormatContext {
        // When the event names a specific surface (split/kill/exit), resolve THAT
        // pane's tab AND its owning session, so tokens like #{pane_cwd} and
        // #{session_name} reflect the affected pane — not the active selection.
        let workspace = snapshot.activeWorkspace
        var session = workspace?.activeSession
        var tab = workspace?.activeTab
        if let surfaceKey, let match = editor.tab(forSurfaceKey: surfaceKey) {
            let owningSession = snapshot.workspaces
                .first(where: { $0.id == match.workspaceID })?
                .sessions.first(where: { $0.tabs.contains { $0.id == match.tabID } })
            if let resolved = owningSession?.tabs.first(where: { $0.id == match.tabID }) {
                tab = resolved
                session = owningSession
            }
        }
        // #{pane_active} is true only when the named surface IS its tab's active pane —
        // hooks frequently name a BACKGROUND pane (alert/bell, agent-state, pane-exited),
        // so `surfaceKey != nil` would wrongly report 1. Mirror SnapshotQueryFormatter and
        // the compositor: compare against the active pane's surface.
        let activeSurfaceKey = tab?.activePaneID.flatMap { editor.surfaceID(forPaneID: $0)?.uuidString }
        var context = FormatContext(
            paneID: surfaceKey,
            paneTitle: tab?.title,
            paneCwd: tab?.cwd,
            paneActive: surfaceKey != nil && surfaceKey == activeSurfaceKey,
            paneIndex: nil,
            sessionName: session?.name.isEmpty == false ? session?.name : nil,
            tabName: tab?.title,
            tabIndex: session?.tabs.firstIndex(where: { $0.id == tab?.id }),
            workspaceName: workspace?.name,
            agentKind: tab?.agent?.kind.rawValue,
            agentActivity: tab?.agent?.activity.rawValue,
            gitBranch: tab?.gitBranch,
            clientName: clientName,
            windowFlags: tab.map { ($0.zoomedPaneID != nil ? "Z" : "") + $0.alertFlags }
        )
        // Extended tmux-parity fields. PTY-backed values come from the live surface when the
        // context names one (exact per-pane truth, unlike the per-tab scan metadata); the
        // probes are single ioctls/syscalls — cheap enough at display-message/hook frequency.
        context.paneCurrentCommand = tab?.currentCommand
        if let surfaceKey, let live = sessions[surfaceKey] {
            context.panePID = Int(live.currentChildPID)
            if let command = live.probeForegroundCommand()?.command {
                context.paneCurrentCommand = command
            }
            if let size = live.currentSize() {
                context.paneWidth = size.cols
                context.paneHeight = size.rows
            }
            context.historyBytes = live.historyBytes
        }
        context.paneDead = tab.map { $0.exitStatus != nil }
        context.paneExitStatus = tab?.exitStatus
        context.sessionID = session?.id.uuidString
        context.windowID = tab?.id.uuidString
        context.sessionWindows = session?.tabs.count
        context.windowPanes = tab?.rootPane.allPaneIDs().count
        if let tab, let session { context.windowActive = tab.id == session.activeTabID }
        context.sessionGroup = session.flatMap { snapshot.groupName(of: $0) }
        context.sessionAttached = attachedClientCount
        context.serverPID = Int(getpid())
        return context
    }
}
