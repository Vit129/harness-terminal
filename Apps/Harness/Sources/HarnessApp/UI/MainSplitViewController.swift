import AppKit
import HarnessCore
import QuartzCore

@MainActor
final class MainSplitViewController: NSViewController {
    private let split = NSSplitView()
    private let sidebar = HarnessSidebarPanelViewController()
    private let content = ContentAreaViewController()
    var contentVC: ContentAreaViewController { content }
    private let statusLine = StatusLineView()
    /// 1px hairline along the inner edge of the sidebar — adds quiet definition
    /// between sidebar/terminal without resorting to a draggable divider line.
    private let edgeDivider = NSView()
    /// Bumped each time a sidebar collapse/expand starts so any in-flight animation
    /// frame bails out — prevents two toggles from fighting over the divider position.
    private var sidebarAnimToken = 0
    /// Owned (not a singleton) so collapse state is per-window. Carries the
    /// `allowFullCollapse` flag the divider min-coordinate reads.
    private let splitDelegate = SplitChromeDelegate()
    private var isFocusModeActive = false
    private var preFocusSidebarVisible = true
    private var preFocusFileEditorVisible = false

    override func loadView() {
        // The root contentView must stay a plain, NON-layer-backed NSView. A plain NSView
        // draws nothing (transparent by default), so the window blur shows through — but it
        // is *not* layer-backed, so the window server rounds the frame + CGS background blur
        // together. Calling `makeClear` here would set `wantsLayer` and
        // layer-back the whole window, which clips the blur to a rectangle and leaves a dark
        // compositing seam at the rounded edge. See MainWindowController.applyTransparency.
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        split.isVertical = true
        split.dividerStyle = .thin
        // No autosaveName: visibility lives in `settings.sidebarVisible` and is
        // re-applied on load; an autosaved divider width would restore a stale
        // collapsed state and fight the settings-driven restore.
        split.delegate = splitDelegate

        // Container is a transparent wrapper so the sidebar.view's own chrome
        // backdrop is the only one in play. Stacking two ChromeBackdrops (one
        // here, one in HarnessSidebarPanelViewController.loadView) doubled up
        // the glass+tint and shifted the sidebar's perceived tint relative to
        // the terminal side — making the top of the window read as a darker
        // strip even though both regions request the same theme color.
        let sidebarContainer = NSView()
        HarnessDesign.makeClear(sidebarContainer)
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebar.view.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.addSubview(sidebar.view)
        NSLayoutConstraint.activate([
            sidebar.view.topAnchor.constraint(equalTo: sidebarContainer.topAnchor),
            sidebar.view.leadingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor),
            sidebar.view.trailingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor),
            sidebar.view.bottomAnchor.constraint(equalTo: sidebarContainer.bottomAnchor),
        ])

        let sidebarOnRight = SessionCoordinator.shared.settings.sidebarOnRight
        if sidebarOnRight {
            split.addSubview(content.view)
            split.addSubview(sidebarContainer)
        } else {
            split.addSubview(sidebarContainer)
            split.addSubview(content.view)
        }
        addChild(sidebar)
        addChild(content)

        split.translatesAutoresizingMaskIntoConstraints = false
        statusLine.translatesAutoresizingMaskIntoConstraints = false
        edgeDivider.wantsLayer = true
        edgeDivider.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(split)
        view.addSubview(statusLine)
        view.addSubview(edgeDivider)
        NSLayoutConstraint.activate([
            split.topAnchor.constraint(equalTo: view.topAnchor),
            split.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            split.bottomAnchor.constraint(equalTo: statusLine.topAnchor),

            statusLine.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusLine.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusLine.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            edgeDivider.topAnchor.constraint(equalTo: view.topAnchor),
            edgeDivider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            edgeDivider.widthAnchor.constraint(equalToConstant: 1),
        ])
        updateEdgeDividerConstraints(sidebarContainer: sidebarContainer)

        edgeDivider.layer?.backgroundColor = resolvedDividerColor().cgColor

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let settings = SessionCoordinator.shared.settings
            if settings.sidebarCollapsedOnLaunch {
                // Keep `sidebarVisible` in sync with the forced-collapsed state so the
                // first `toggleSidebar()` (e.g. user expanding the sidebar after launch)
                // computes `!false -> true` and actually shows it. Without this, a stale
                // `sidebarVisible == true` from a previous session makes the first toggle
                // collapse (no-op) instead of expand.
                SessionCoordinator.shared.settings.sidebarVisible = false
                self.applySidebarVisibility(false, animated: false)
            } else {
                self.applySidebarVisibility(settings.sidebarVisible, animated: false)
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(snapshotChanged),
            name: NotificationBus.shared.snapshotChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowFullScreenStateChanged),
            name: NSWindow.didEnterFullScreenNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowFullScreenStateChanged),
            name: NSWindow.didExitFullScreenNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openFilePreviewFromTerminal(_:)),
            name: Notification.Name("HarnessOpenFilePreview"),
            object: nil
        )
    }

    @objc private func openFilePreviewFromTerminal(_ notification: Notification) {
        guard let path = notification.userInfo?["path"] as? String else { return }
        contentVC.openFileTab(path: path)
    }

    /// Resolve the divider line color: user override (`settings.dividerHex`) wins; otherwise
    /// a quiet near-background hairline — `#1E1E1E` on dark themes (the default look), and the
    /// theme's border on light themes (where a near-black line would read as a hard rule).
    private func resolvedDividerColor() -> NSColor {
        if let hex = SessionCoordinator.shared.settings.dividerHex, let color = NSColor.fromHex(hex) {
            return color
        }
        let c = HarnessChrome.current
        return c.isDark
            ? (NSColor.fromHex(HarnessChromePalette.defaultDarkDividerHex) ?? c.border)
            : c.border.withAlphaComponent(0.65)
    }

    func applyChrome() {
        // Never `makeClear(view)` here: the root contentView must stay non-layer-backed
        // (see loadView) so the window stays rounded with no dark perimeter seam. It is
        // transparent already; there is nothing to repaint on it.
        if let sidebarContainer = sidebarContainerView {
            // Keep this transparent — the sidebar view inside owns the chrome. This is a
            // child layer-backing island and does not affect the root's backing.
            HarnessDesign.makeClear(sidebarContainer)
        }
        edgeDivider.layer?.backgroundColor = resolvedDividerColor().cgColor
        // Tell the window controller to repaint the window bg with the (possibly
        // new) chrome color × opacity.
        (view.window?.windowController as? MainWindowController)?.applyTransparency()
        sidebar.applyChromeColors()
        content.applyChrome()
        statusLine.applyChrome()
        (view.window?.windowController as? MainWindowController)?.applyTransparency()
        updateContentLeadingInset()
    }

    @objc private func snapshotChanged(_ note: Notification) {
        let metadataOnly = note.userInfo?["metadataOnly"] as? Bool ?? false
        if note.userInfo?["chromeChanged"] as? Bool == true {
            // Cross-dissolve the chrome (theme switch) instead of a hard color pop.
            // Re-arming the flag per cascade means rapid successive switches just
            // restart the fade rather than queueing.
            ChromeBackdrop.crossfadeNextUpdate = true
            applyChrome()
            (view.window?.windowController as? MainWindowController)?.applyChrome()
            ChromeBackdrop.crossfadeNextUpdate = false
        }
        if metadataOnly {
            sidebar.refreshMetadata()
            content.refreshTabBarMetadata()
        } else {
            sidebar.reload()
            content.reloadTabBar()
        }
        updateWindowTitle()
    }

    private func updateWindowTitle() {
        let snap = SessionCoordinator.shared.snapshot
        view.window?.title = snap.activeWorkspace.map { "Harness — \($0.name)" } ?? "Harness"
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateContentLeadingInset()
    }

    @objc private func windowFullScreenStateChanged(_ note: Notification) {
        guard let window = note.object as? NSWindow, window === view.window else { return }
        updateContentLeadingInset()
    }

    func setSidebarVisible(_ visible: Bool) {
        setSidebarVisible(visible, animated: false)
    }

    func setSidebarVisible(_ visible: Bool, animated: Bool) {
        SessionCoordinator.shared.settings.sidebarVisible = visible
        try? SessionCoordinator.shared.settings.save()
        applySidebarVisibility(visible, animated: animated)
    }

    /// Collapse/expand the sidebar. `NSSplitView.setPosition` is not animatable via the
    /// animator proxy, so for a genuinely fluid slide we drive the divider ourselves
    /// with an eased per-frame stepper. A token cancels any in-flight animation.
    ///
    /// `allowFullCollapse` is set on the delegate for the whole move so the divider's
    /// min-coordinate drops to 0 (it's 200 at rest, so a *user drag* can't shrink the
    /// sidebar to an unusable sliver — but a programmatic collapse must reach 0).
    private func applySidebarVisibility(_ visible: Bool, animated: Bool) {
        sidebarAnimToken &+= 1
        let target = visible ? HarnessDesign.sidebarWidth : 0
        splitDelegate.allowFullCollapse = true

        guard animated, let panel = sidebarContainerView else {
            let panel = sidebarContainerView
            panel?.isHidden = false              // unhide so setPosition can size it to 0
            setSidebarWidth(target)
            panel?.isHidden = !visible
            splitDelegate.allowFullCollapse = false
            edgeDivider.isHidden = !visible
            updateContentLeadingInset()
            return
        }

        // Unhide before the slide so the panel is visible as it shrinks/grows.
        panel.isHidden = false
        // Show/hide the inner hairline immediately so it never strands over the terminal.
        edgeDivider.isHidden = !visible
        let start = panel.frame.width
        guard abs(target - start) > 0.5 else {
            setSidebarWidth(target)
            if !visible { panel.isHidden = true }
            splitDelegate.allowFullCollapse = false
            updateContentLeadingInset()
            return
        }
        animateSidebar(from: start, to: target, t0: CACurrentMediaTime(), visible: visible, token: sidebarAnimToken)
    }

    private func animateSidebar(from start: CGFloat, to target: CGFloat, t0: CFTimeInterval, visible: Bool, token: Int) {
        guard token == sidebarAnimToken, let panel = sidebarContainerView else { return }
        let duration = HarnessDesign.Motion.standard
        let raw = min(1, max(0, (CACurrentMediaTime() - t0) / duration))
        // easeInOutQuad — smooth start and settle.
        let eased = raw < 0.5 ? 2 * raw * raw : 1 - pow(-2 * raw + 2, 2) / 2
        let width = start + (target - start) * CGFloat(eased)
        // Drive the divider inside a transaction with implicit actions OFF and lay
        // out synchronously each frame. Without this, the manual per-frame
        // setPosition lets the sidebar's vibrancy/glass backdrop animate its bounds
        // a frame behind the divider — it re-samples at the stale width and smears
        // into the banding seen mid-collapse. Disabling actions + an immediate
        // layout keeps the backdrop locked to the divider every step.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setSidebarWidth(width)
        // Interpolate the tab-strip inset against the live sidebar width so it slides
        // in lockstep with the divider rather than snapping at the end.
        setContentLeadingInset(forSidebarWidth: width)
        split.layoutSubtreeIfNeeded()
        CATransaction.commit()
        if raw >= 1 {
            if !visible { panel.isHidden = true }
            splitDelegate.allowFullCollapse = false   // restore the 200pt drag floor
            updateContentLeadingInset()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) { [weak self] in
            MainActor.assumeIsolated {
                self?.animateSidebar(from: start, to: target, t0: t0, visible: visible, token: token)
            }
        }
    }

    /// Leading inset the title strip's path readout needs to clear the macOS traffic lights
    /// when the sidebar is fully collapsed (content shifts to x=0 under `.fullSizeContentView`).
    /// The tab bar itself sits below the lights and never needs one.
    private let trafficLightInset: CGFloat = 72

    private var effectiveTrafficLightInset: CGFloat {
        guard let window = view.window else { return 0 }
        let settings = SessionCoordinator.shared.settings
        guard settings.transparentTitlebar else { return 0 }
        guard !window.styleMask.contains(.fullScreen) else { return 0 }
        return trafficLightInset
    }

    /// Inset the strip readout proportionally to how collapsed the sidebar is: full inset
    /// at width 0, none once the sidebar is wide enough to cover the traffic lights.
    private func setContentLeadingInset(forSidebarWidth width: CGFloat) {
        if SessionCoordinator.shared.settings.sidebarOnRight {
            content.setTabBarLeadingInset(effectiveTrafficLightInset)
        } else {
            let t = max(0, min(1, 1 - width / trafficLightInset))
            content.setTabBarLeadingInset(effectiveTrafficLightInset * t)
        }
    }

    private func updateContentLeadingInset() {
        if SessionCoordinator.shared.settings.sidebarOnRight {
            content.setTabBarLeadingInset(effectiveTrafficLightInset)
        } else {
            let visible = !(sidebarContainerView?.isHidden ?? true)
            content.setTabBarLeadingInset(visible ? 0 : effectiveTrafficLightInset)
        }
    }

    func toggleSidebar() {
        setSidebarVisible(!SessionCoordinator.shared.settings.sidebarVisible, animated: true)
    }

    func toggleIDEMode() {
        if content.isFileEditorVisible {
            content.hideFileEditorSplit()
        } else {
            setSidebarVisible(true, animated: true)
            content.showFileEditorSplit()
        }
    }

    func toggleFocusMode() {
        if isFocusModeActive {
            setSidebarVisible(preFocusSidebarVisible, animated: true)
            if preFocusFileEditorVisible {
                content.showFileEditorSplit()
            } else {
                content.hideFileEditorSplit()
            }
            isFocusModeActive = false
        } else {
            preFocusSidebarVisible = SessionCoordinator.shared.settings.sidebarVisible
            preFocusFileEditorVisible = content.isFileEditorVisible
            
            if preFocusSidebarVisible || preFocusFileEditorVisible {
                setSidebarVisible(false, animated: true)
                content.hideFileEditorSplit()
                isFocusModeActive = true
            } else {
                setSidebarVisible(true, animated: true)
                isFocusModeActive = false
            }
        }
    }

    private var edgeDividerConstraint: NSLayoutConstraint?

    private func updateEdgeDividerConstraints(sidebarContainer: NSView) {
        edgeDividerConstraint?.isActive = false
        let sidebarOnRight = SessionCoordinator.shared.settings.sidebarOnRight
        if sidebarOnRight {
            edgeDividerConstraint = edgeDivider.trailingAnchor.constraint(equalTo: sidebarContainer.leadingAnchor)
        } else {
            edgeDividerConstraint = edgeDivider.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor)
        }
        edgeDividerConstraint?.isActive = true
    }

    private var sidebarContainerIndex: Int {
        return SessionCoordinator.shared.settings.sidebarOnRight ? 1 : 0
    }

    private var sidebarContainerView: NSView? {
        let subviews = split.subviews
        guard subviews.count >= 2 else { return nil }
        return subviews[sidebarContainerIndex]
    }

    func updateSidebarPlacement() {
        let right = SessionCoordinator.shared.settings.sidebarOnRight
        guard split.subviews.count == 2, let sidebarContainer = sidebar.view.superview else { return }

        let currentFirstIsSidebar = split.subviews[0] === sidebarContainer
        let needsSwap = (right && currentFirstIsSidebar) || (!right && !currentFirstIsSidebar)
        if needsSwap {
            // Swap by removing just the sidebar and reinserting at the other end.
            // This preserves the content view's frame/layer state.
            let sidebarFrame = sidebarContainer.frame
            let contentFrame = content.view.frame
            sidebarContainer.removeFromSuperview()
            if right {
                split.addSubview(sidebarContainer)
            } else {
                split.addSubview(sidebarContainer, positioned: .below, relativeTo: split.subviews.first)
            }
            // Restore frames so NSSplitView doesn't zero-size either pane.
            if right {
                content.view.frame = NSRect(x: 0, y: 0, width: contentFrame.width, height: contentFrame.height)
                sidebarContainer.frame = NSRect(x: contentFrame.width, y: 0, width: sidebarFrame.width, height: sidebarFrame.height)
            } else {
                sidebarContainer.frame = NSRect(x: 0, y: 0, width: sidebarFrame.width, height: sidebarFrame.height)
                content.view.frame = NSRect(x: sidebarFrame.width, y: 0, width: contentFrame.width, height: contentFrame.height)
            }
            split.adjustSubviews()
        }
        updateEdgeDividerConstraints(sidebarContainer: sidebarContainer)
        setSidebarVisible(SessionCoordinator.shared.settings.sidebarVisible, animated: false)
        sidebar.applyChromeColors()
        content.applyChrome()
    }

    private func setSidebarWidth(_ width: CGFloat) {
        let totalWidth = split.bounds.width
        let sidebarOnRight = SessionCoordinator.shared.settings.sidebarOnRight
        let position: CGFloat
        if sidebarOnRight {
            position = totalWidth > width ? (totalWidth - width) : 0
        } else {
            position = width
        }
        split.setPosition(position, ofDividerAt: 0)
    }

    func toggleSidebarPosition() {
        SessionCoordinator.shared.settings.sidebarOnRight.toggle()
        try? SessionCoordinator.shared.settings.save()
        updateSidebarPlacement()
    }

}

@MainActor
private final class SplitChromeDelegate: NSObject, NSSplitViewDelegate {
    /// While a programmatic collapse/expand is running, let the divider reach 0 so the
    /// sidebar can fully disappear. At rest it's false, so a *user drag* still floors
    /// at 200pt and can't shrink the sidebar to an unusable sliver.
    var allowFullCollapse = false

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimum: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        let right = SessionCoordinator.shared.settings.sidebarOnRight
        if right {
            guard index == 0 else { return proposedMinimum }
            let totalWidth = splitView.bounds.width
            return totalWidth - 320
        } else {
            guard index == 0 else { return proposedMinimum }
            return allowFullCollapse ? 0 : 200
        }
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximum: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        let right = SessionCoordinator.shared.settings.sidebarOnRight
        if right {
            guard index == 0 else { return proposedMaximum }
            let totalWidth = splitView.bounds.width
            return allowFullCollapse ? totalWidth : (totalWidth - 200)
        } else {
            return index == 0 ? 320 : proposedMaximum
        }
    }

    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        var rect = proposedEffectiveRect
        rect.size.width = 4
        return rect
    }
}
