import AppKit
import KouenCore
import KouenTerminalKit

/// Manages pane rebuild lifecycle: structural reloads, zombie-hold of detached views,
/// and pane lookup. Owned by ContentAreaViewController.
@MainActor
final class PaneLifecycleManager {
    private unowned let terminalHost: NSView
    private unowned let containerView: NSView

    private(set) var paneContainer: PaneContainerView?
    private var lastStructureKey = ""
    private var containerCache: [String: PaneContainerView] = [:] // tabID → cached container
    private var activeTabID: String?
    var pendingReload: Bool?

    init(terminalHost: NSView, containerView: NSView) {
        self.terminalHost = terminalHost
        self.containerView = containerView
    }

    // MARK: - Reload

    func reloadIfNeeded(force: Bool) {
        guard terminalHost.bounds.width > 1, terminalHost.bounds.height > 1 else {
            pendingReload = (pendingReload ?? false) || force
            return
        }

        let coordinator = SessionCoordinator.shared
        guard let workspace = coordinator.snapshot.activeWorkspace,
              let tab = workspace.activeTab
        else { return }

        let displayNode = zoomedNode(for: tab) ?? tab.rootPane
        let paneStructureKey = paneKey(displayNode)
        let key = "\(coordinator.structureRevision)|\(workspace.id)|\(tab.id)|\(tab.zoomedPaneID?.uuidString ?? "all")|\(paneStructureKey)"
        guard force || key != lastStructureKey else {
            paneContainer?.refreshChrome(snapshot: coordinator.snapshot)
            return
        }

        let tabID = tab.id.uuidString

        // Fast path: if we have a cached container for THIS tab from a previous visit,
        // just swap visibility. Guard `cached !== paneContainer` ensures we only take
        // this path for tab-switch restores, not for in-place structural changes
        // (e.g. adding a browser pane) where a full rebuild is required.
        if !force, let cached = containerCache[tabID], cached !== paneContainer, cached.superview == terminalHost {
            // Validate that every expected terminal surface is still present in the cached
            // container. Hosts are shared single-instance per surfaceID — any other tab's
            // build can silently steal a host via addSubview, leaving the cache empty.
            // A stale structure (new split added while hidden) also fails this check.
            let expectedSurfaces = Set(displayNode.allSurfaceIDs())
            let cachedHosts = cached.collectTerminalHosts()
            if expectedSurfaces.isSubset(of: Set(cachedHosts.keys)) {
                paneContainer?.isHidden = true
                cached.isHidden = false
                paneContainer = cached
                lastStructureKey = key
                activeTabID = tabID
                coordinator.ensureActivePane(for: tab)
                paneContainer?.refreshChrome(snapshot: coordinator.snapshot)
                cachedHosts.values.forEach { $0.forceRepaint() }
                // WKWebView's remote layer can go stale/black across the isHidden
                // toggle above just like the Metal-rendered terminal hosts — nudge it
                // the same way (see BrowserPaneView.forceRepaint()).
                cached.collectBrowserPanes().values.forEach { $0.forceRepaint() }
                return
            }
            // Hosts were stolen or structure is stale — evict and fall through to rebuild.
            containerCache.removeValue(forKey: tabID)
            cached.removeFromSuperview()
        }

        lastStructureKey = key

        if let window = containerView.window, window.firstResponder is KouenTerminalSurfaceView {
            window.makeFirstResponder(nil)
        }

        let allHosts = coordinator.terminalHosts.allHosts()
        allHosts.forEach { $0.setPresentsWithTransaction(true) }

        // Structural rebuild (force=true): harvest and detach hosts so the new container
        // can reuse surviving ones (same surface IDs). Tab switch (!force): leave the old
        // container's hosts intact — they stay alive in the hidden view and the fast path
        // above renders them correctly on the next switch back. Without this guard,
        // detachHostsOnly() empties the cached container so the fast path reveals black.
        let existingHosts: [SurfaceID: TerminalHostView]
        let existingBrowserPanes: [PaneID: BrowserPaneView]
        if force {
            existingHosts = paneContainer?.collectTerminalHosts() ?? [:]
            existingBrowserPanes = paneContainer?.collectBrowserPanes() ?? [:]
            paneContainer?.detachHostsOnly()
            for host in existingHosts.values { ZombieHoldRegistry.shared.hold(host) }
        } else {
            existingHosts = [:]
            existingBrowserPanes = [:]
        }

        // Hide old container.
        // force=false (tab switch): hosts are intact — cache for fast-path revisit.
        // force=true (structural rebuild): detachHostsOnly() already stripped the hosts —
        //   caching the empty shell causes a black screen on the next revisit. Evict instead.
        if let old = paneContainer {
            old.isHidden = true
            if let prevTabID = activeTabID {
                if force {
                    containerCache.removeValue(forKey: prevTabID)
                    old.removeFromSuperview()
                } else {
                    containerCache[prevTabID] = old
                }
            } else {
                if force { ZombieHoldRegistry.shared.hold(old) }
                old.removeFromSuperview()
            }
        }

        let container = PaneContainerView(
            node: displayNode,
            cwd: tab.cwd,
            themeName: coordinator.snapshot.themeName,
            existingHosts: existingHosts,
            existingBrowserPanes: existingBrowserPanes
        )
        container.translatesAutoresizingMaskIntoConstraints = false
        terminalHost.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: terminalHost.topAnchor),
            container.leadingAnchor.constraint(equalTo: terminalHost.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: terminalHost.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: terminalHost.bottomAnchor),
        ])
        paneContainer = container
        activeTabID = tabID
        // Evict any previous entry for this tab before storing the new one — the old
        // container (if different) would become an orphaned hidden subview with a live
        // Metal surface and display link.
        if let orphan = containerCache[tabID], orphan !== container {
            orphan.removeFromSuperview()
        }
        containerCache[tabID] = container
        coordinator.ensureActivePane(for: tab)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            allHosts.forEach { $0.setPresentsWithTransaction(false) }
        }
        containerView.layout()
        CATransaction.commit()
    }

    // MARK: - Cache Pruning

    /// Remove cached containers for tabs that no longer exist. Without pruning, every
    /// tab ever visited accumulates a hidden Metal-rendered container in memory forever.
    func pruneCache(keepingTabIDs liveTabIDs: Set<String>) {
        let staleKeys = containerCache.keys.filter { !liveTabIDs.contains($0) }
        for key in staleKeys {
            let container = containerCache.removeValue(forKey: key)
            container?.removeFromSuperview()
        }
    }

    // MARK: - Pane Lookup

    func paneShell(for paneID: PaneID) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("pane-\(paneID.uuidString)")
        return paneContainer?.findDescendant(withIdentifier: id)
    }

    // MARK: - Helpers

    private func paneKey(_ node: PaneNode) -> String {
        switch node {
        case let .leaf(leaf):
            return "l:\((leaf.activeSurfaceID ?? leaf.surfaceID).uuidString)"
        case let .browser(leaf):
            return "br:\(leaf.id.uuidString)"
        case let .branch(direction, _, first, second):
            return "b:\(direction.rawValue):\(paneKey(first)):\(paneKey(second))"
        }
    }

    private func zoomedNode(for tab: Tab) -> PaneNode? {
        guard let zoomedPaneID = tab.zoomedPaneID else { return nil }
        return leafNode(paneID: zoomedPaneID, in: tab.rootPane)
    }

    private func leafNode(paneID: PaneID, in node: PaneNode) -> PaneNode? {
        switch node {
        case let .leaf(leaf) where leaf.id == paneID:
            return .leaf(leaf)
        case let .branch(_, _, first, second):
            return leafNode(paneID: paneID, in: first) ?? leafNode(paneID: paneID, in: second)
        default:
            return nil
        }
    }
}
