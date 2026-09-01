import AppKit
import Foundation
import KouenCore
import KouenTerminalKit

/// Handles split pane creation, focus, killing, and pane-tree navigation.
@MainActor
final class SplitPaneCoordinator {
    private unowned let coord: SessionCoordinator

    init(coordinator: SessionCoordinator) {
        self.coord = coordinator
    }

    func splitActivePane(direction: SplitDirection, before: Bool = false) {
        guard let workspace = coord.snapshot.activeWorkspace,
              let tab = workspace.activeTab,
              // Fall back to the last TERMINAL leaf, never a browser leaf — the daemon has no
              // record of browser panes (local-only, see openBrowserPane), so targeting one here
              // would fail server-side with "Pane not found".
              let paneID = coord.activeSurfaceID.flatMap({ paneID(for: $0, in: tab.rootPane) })
                ?? tab.rootPane.allLeaves().last?.id
        else {
            NSLog("[DBG-activestate] splitActivePane() no-op: workspace=\(coord.snapshot.activeWorkspace?.id.uuidString ?? "nil") tab=\(coord.snapshot.activeWorkspace?.activeTab?.id.uuidString ?? "nil") activeSurfaceID=\(coord.activeSurfaceID?.uuidString ?? "nil")")
            return
        }
        NSLog("[DBG-activestate] splitActivePane() workspace=\(workspace.id) tab=\(tab.id) paneID=\(paneID)")
        Task {
            await coord.requestDaemon(.newSplit(tabID: tab.id, paneID: paneID, direction: direction, shell: coord.settings.defaultShell, before: before))
            await coord.syncFromDaemon()
        }
    }

    func splitActivePaneAndRun(direction: SplitDirection, command: String) {
        guard let workspace = coord.snapshot.activeWorkspace,
              let tab = workspace.activeTab,
              let paneID = coord.activeSurfaceID.flatMap({ paneID(for: $0, in: tab.rootPane) })
                ?? tab.rootPane.allPaneIDs().last
        else { return }
        Task {
            guard case let .paneID(newPaneID)? = await coord.requestDaemon(.newSplit(
                tabID: tab.id,
                paneID: paneID,
                direction: direction,
                shell: coord.settings.defaultShell
            )) else {
                await coord.syncFromDaemon()
                return
            }
            await coord.syncFromDaemon()
            guard let activeTab = coord.snapshot.activeWorkspace?.activeTab,
                  let surfaceID = surfaceID(forPaneID: newPaneID, in: activeTab.rootPane)
            else { return }
            coord.setActiveSurface(surfaceID)
            coord.terminalHosts.host(for: surfaceID)?.focusTerminal()
            await coord.requestDaemon(.sendData(surfaceID: surfaceID.uuidString, data: Data((command + "\r").utf8)))
        }
    }

    // MARK: - Saved Layouts (M5)

    func listSavedLayouts() async -> [SavedLayout] {
        guard case let .savedLayouts(list)? = await coord.requestDaemon(.savedLayoutList) else { return [] }
        return list
    }

    func saveCurrentLayout(name: String) {
        guard let tab = coord.snapshot.activeWorkspace?.activeTab else { return }
        Task {
            _ = await coord.requestDaemon(.savedLayoutSave(name: name, tabID: tab.id))
        }
    }

    func deleteSavedLayout(id: UUID) {
        Task {
            _ = await coord.requestDaemon(.savedLayoutDelete(id: id))
        }
    }

    /// Creates a new tab in the active workspace and rebuilds `layout.shape` inside it —
    /// fresh empty shells at every leaf, matching only the split structure. Never restores
    /// any running process; that's daemon session-restore's job, a separate feature.
    func applySavedLayout(_ layout: SavedLayout) {
        guard let workspaceID = coord.snapshot.activeWorkspace?.id else { return }
        Task {
            guard case let .tabID(newTabID)? = await coord.requestDaemon(
                .newTab(workspaceID: workspaceID, cwd: nil, shell: nil)
            ) else {
                await coord.syncFromDaemon()
                return
            }
            await coord.syncFromDaemon()
            guard let rootPaneID = coord.snapshot.activeWorkspace?.sessions
                .flatMap({ $0.tabs })
                .first(where: { $0.id == newTabID })?
                .rootPane.allPaneIDs().first
            else { return }
            await applyLayoutShape(layout.shape, at: rootPaneID, tabID: newTabID)
        }
    }

    private func applyLayoutShape(_ shape: PaneLayoutShape, at paneID: PaneID, tabID: TabID) async {
        guard case let .branch(direction, _, first, second) = shape else { return }
        guard case let .paneID(newPaneID)? = await coord.requestDaemon(.newSplit(
            tabID: tabID, paneID: paneID, direction: direction, shell: coord.settings.defaultShell
        )) else {
            await coord.syncFromDaemon()
            return
        }
        await coord.syncFromDaemon()
        // Ratio is not restored in v1 (documented cut, design.md) — every split lands at
        // the daemon's default 0.5.
        await applyLayoutShape(first, at: paneID, tabID: tabID)
        await applyLayoutShape(second, at: newPaneID, tabID: tabID)
    }

    func focusPaneDirectional(_ direction: DirectionalAxis) {
        guard let workspace = coord.snapshot.activeWorkspace,
              let tab = workspace.activeTab,
              let paneID = coord.activeSurfaceID.flatMap({ paneID(for: $0, in: tab.rootPane) })
                ?? tab.rootPane.allPaneIDs().last
        else { return }
        Task {
            if case let .surfaceID(raw)? = await coord.requestDaemon(.selectPaneDirectional(currentPaneID: paneID, direction: direction)),
               let surfaceID = UUID(uuidString: raw) {
                await coord.syncFromDaemon()
                coord.setActiveSurface(surfaceID)
                coord.terminalHosts.host(for: surfaceID)?.focusTerminal()
            } else {
                await coord.syncFromDaemon()
            }
        }
    }

    func splitPaneSurface(
        tabID: TabID,
        sourcePaneID: PaneID,
        surfaceID: SurfaceID,
        targetPaneID: PaneID,
        direction: SplitDirection,
        beforeTarget: Bool
    ) {
        coord.requestDaemon(.splitPaneSurface(
            tabID: tabID,
            sourcePaneID: sourcePaneID,
            surfaceID: surfaceID,
            targetPaneID: targetPaneID,
            direction: direction,
            beforeTarget: beforeTarget
        ))
        coord.syncFromDaemon()
    }

    func splitTab(workspaceID: WorkspaceID, tabID: TabID, direction: SplitDirection) {
        coord.selectTab(workspaceID: workspaceID, tabID: tabID)
        splitActivePane(direction: direction)
    }

    func splitSession(workspaceID: WorkspaceID, sessionID: SessionID, direction: SplitDirection) {
        coord.selectSession(workspaceID: workspaceID, sessionID: sessionID)
        splitActivePane(direction: direction)
    }

    func killActivePane() {
        guard let workspace = coord.snapshot.activeWorkspace,
              let tab = workspace.activeTab,
              let paneID = coord.activeSurfaceID.flatMap({ paneID(for: $0, in: tab.rootPane) })
                ?? tab.rootPane.allPaneIDs().last
        else { return }
        coord.requestDaemon(.killPane(paneID: paneID))
        coord.syncFromDaemon()
    }

    func killPane(paneID: PaneID) {
        coord.requestDaemon(.killPane(paneID: paneID))
        coord.syncFromDaemon()
    }

    // MARK: - Pane tree helpers

    func paneID(for surfaceID: SurfaceID, in node: PaneNode) -> PaneID? {
        switch node {
        case let .leaf(leaf) where leaf.surfaceIDs.contains(surfaceID):
            return leaf.id
        case let .branch(_, _, first, second):
            return paneID(for: surfaceID, in: first) ?? paneID(for: surfaceID, in: second)
        default:
            return nil
        }
    }

    func firstSurfaceID(forTab tabID: TabID) -> SurfaceID? {
        for workspace in coord.snapshot.workspaces {
            for session in workspace.sessions {
                if let tab = session.tabs.first(where: { $0.id == tabID }) {
                    return tab.rootPane.allSurfaceIDs().first
                }
            }
        }
        return nil
    }

    func surfaceID(forPaneID paneID: PaneID, in node: PaneNode) -> SurfaceID? {
        switch node {
        case let .leaf(leaf): return leaf.id == paneID ? leaf.surfaceID : nil
        case let .branch(_, _, first, second):
            return surfaceID(forPaneID: paneID, in: first) ?? surfaceID(forPaneID: paneID, in: second)
        case .browser:
            return nil
        }
    }

    func surfaceID(forPane paneID: PaneID, in node: PaneNode) -> SurfaceID? {
        switch node {
        case let .leaf(leaf) where leaf.id == paneID:
            return leaf.activeSurfaceID ?? leaf.surfaceID
        case let .branch(_, _, first, second):
            return surfaceID(forPane: paneID, in: first) ?? surfaceID(forPane: paneID, in: second)
        default:
            return nil
        }
    }

    /// `originSurfaceID`: anchors the new browser pane to the tab that surface actually
    /// lives in (e.g. the MCP-calling agent's own pane, via its `KOUEN_SURFACE` env var)
    /// instead of whatever tab the human currently has focused — an agent working in
    /// session A shouldn't have its `kouenBrowserOpen` land in session B just because a
    /// human happened to be looking at B. Falls back to the active tab only when there is
    /// no origin surface at all (menu/keyboard-triggered opens have no originating agent
    /// surface); a present-but-unresolvable origin surface no-ops instead of misrouting.
    func openBrowserPane(url: URL, direction: SplitDirection, paneID: PaneID = UUID(), originSurfaceID: SurfaceID? = nil) {
        let tab: Tab?
        if let originSurfaceID {
            tab = coord.surfaceIndex[originSurfaceID]?.tab
        } else {
            tab = coord.snapshot.activeWorkspace?.activeTab
        }
        guard let tab else { return }

        let resolvedURL: URL
        if let savedURLString = UserDefaults.standard.string(forKey: "browserPane.\(paneID.uuidString).url"),
           let savedURL = URL(string: savedURLString) {
            resolvedURL = savedURL
        } else {
            resolvedURL = url
        }

        let browserLeaf = BrowserLeaf(id: paneID, url: resolvedURL)

        var updatedSnapshot = coord.snapshot
        for (wIdx, ws) in updatedSnapshot.workspaces.enumerated() {
            for (sIdx, session) in ws.sessions.enumerated() {
                for (tIdx, t) in session.tabs.enumerated() {
                    if t.id == tab.id {
                        var updatedTab = t
                        var root = updatedTab.rootPane
                        // Insert browser at the root level (right/bottom of entire tab)
                        // so it sits beside all terminal panes, not nested inside one split.
                        let existing = root
                        root = .branch(direction: direction, ratio: 0.6, first: existing, second: .browser(browserLeaf))
                        updatedTab.rootPane = root
                        updatedTab.activePaneID = paneID
                        updatedTab.lastActivePaneID = tab.activePaneID
                        updatedSnapshot.workspaces[wIdx].sessions[sIdx].tabs[tIdx] = updatedTab

                        coord.daemonSyncService.applyLocalSnapshot(updatedSnapshot)
                        return
                    }
                }
            }
        }
    }

    private func insertBrowserLeaf(
        _ browserLeaf: BrowserLeaf,
        into node: inout PaneNode,
        targetPaneID: PaneID,
        direction: SplitDirection
    ) -> Bool {
        switch node {
        case let .leaf(leaf):
            if leaf.id == targetPaneID {
                node = .branch(direction: direction, ratio: 0.5, first: .leaf(leaf), second: .browser(browserLeaf))
                return true
            }
            return false
        case let .browser(bleaf):
            if bleaf.id == targetPaneID {
                node = .branch(direction: direction, ratio: 0.5, first: .browser(bleaf), second: .browser(browserLeaf))
                return true
            }
            return false
        case .branch(let d, let r, var first, var second):
            if insertBrowserLeaf(browserLeaf, into: &first, targetPaneID: targetPaneID, direction: direction) {
                node = .branch(direction: d, ratio: r, first: first, second: second)
                return true
            }
            if insertBrowserLeaf(browserLeaf, into: &second, targetPaneID: targetPaneID, direction: direction) {
                node = .branch(direction: d, ratio: r, first: first, second: second)
                return true
            }
            return false
        }
    }

    /// Remove a browser pane from the app-side snapshot and deregister it.
    func closeBrowserPane(paneID: PaneID) {
        BrowserPaneRegistry.shared.unregister(paneID)
        var updatedSnapshot = coord.snapshot
        for (wIdx, ws) in updatedSnapshot.workspaces.enumerated() {
            for (sIdx, session) in ws.sessions.enumerated() {
                for (tIdx, tab) in session.tabs.enumerated() {
                    var root = tab.rootPane
                    if removePaneNode(paneID: paneID, from: &root) {
                        updatedSnapshot.workspaces[wIdx].sessions[sIdx].tabs[tIdx].rootPane = root
                        coord.daemonSyncService.applyLocalSnapshot(updatedSnapshot)
                        return
                    }
                }
            }
        }
    }

    /// Returns true and removes the node with matching paneID, collapsing the branch.
    @discardableResult
    func removePaneNode(paneID: PaneID, from node: inout PaneNode) -> Bool {
        switch node {
        case let .leaf(leaf) where leaf.id == paneID: return true
        case let .browser(leaf) where leaf.id == paneID: return true
        case .branch(let dir, let ratio, var first, var second):
            if removePaneNode(paneID: paneID, from: &first) {
                if first.paneID == paneID {
                    node = second
                } else {
                    node = .branch(direction: dir, ratio: ratio, first: first, second: second)
                }
                return true
            }
            if removePaneNode(paneID: paneID, from: &second) {
                if second.paneID == paneID {
                    node = first
                } else {
                    node = .branch(direction: dir, ratio: ratio, first: first, second: second)
                }
                return true
            }
            return false
        default: return false
        }
    }

    // MARK: - Drag-and-drop (P27)

    func swapPanes(srcPaneID: PaneID, dstPaneID: PaneID) {
        Task {
            await coord.requestDaemon(.swapPanes(srcPaneID: srcPaneID, dstPaneID: dstPaneID))
            await coord.syncFromDaemon()
        }
    }

    func movePaneToDirection(sourcePaneID: PaneID, destPaneID: PaneID, direction: SplitDirection, before: Bool) {
        Task {
            await coord.requestDaemon(.joinPane(sourcePaneID: sourcePaneID, destPaneID: destPaneID, direction: direction, before: before))
            await coord.syncFromDaemon()
        }
    }
}
