import AppKit
import KouenCore
import QuartzCore
import os

@MainActor
final class MainSplitViewController: NSViewController {
    /// ponytail: 4th distinct Cmd+\ regression in this file (keyWindow resolution,
    /// zero-delta trap, placement desync x2, persisted-zero-width) — these lines exist
    /// so the next one leaves real state in Console.app instead of another guessing pass.
    private let sidebarLog = Logger(subsystem: "com.vit129.kouen", category: "sidebar")
    private let split = NSSplitView()
    private var sidebar: KouenSidebarPanelViewController!
    private var content: ContentAreaViewController!
    var contentVC: ContentAreaViewController { content }
    private let statusLine = StatusLineView()
    /// 1px hairline along the inner edge of the sidebar — adds quiet definition
    /// between sidebar/terminal without resorting to a draggable divider line.
    private let edgeDivider = NSView()
    /// Bumped each time a sidebar collapse/expand starts so any in-flight animation
    /// frame bails out — prevents two toggles from fighting over the divider position.
    private var sidebarAnimToken = 0
    private var sidebarDisplayLink: CADisplayLink?
    private var sidebarWidthSaveWorkItem: DispatchWorkItem?
    // params valid while sidebarDisplayLink is non-nil
    private var _sidebarStart: CGFloat = 0
    private var _sidebarTarget: CGFloat = 0
    private var _sidebarT0: CFTimeInterval = 0
    private var _sidebarVisible: Bool = false
    private var didApplyInitialSidebarState = false
    /// Owned (not a singleton) so collapse state is per-window. Carries the
    /// `allowFullCollapse` flag the divider min-coordinate reads.
    private let splitDelegate = SplitChromeDelegate()

    override func loadView() {
        sidebar = KouenSidebarPanelViewController()
        content = ContentAreaViewController()
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
        splitDelegate.onResize = { [weak self] in self?.handlePotentialUserSidebarResize() }

        // Container is a transparent wrapper so the sidebar.view's own chrome
        // backdrop is the only one in play. Stacking two ChromeBackdrops (one
        // here, one in KouenSidebarPanelViewController.loadView) doubled up
        // the glass+tint and shifted the sidebar's perceived tint relative to
        // the terminal side — making the top of the window read as a darker
        // strip even though both regions request the same theme color.
        let sidebarContainer = NSView()
        KouenDesign.makeClear(sidebarContainer)
        // Deliberately NOT translatesAutoresizingMaskIntoConstraints = false here (unlike
        // `sidebar.view` below): `sidebarContainer` is an NSSplitView arranged subview —
        // NSSplitView positions/sizes it via direct frame assignment (setPosition/adjustSubviews),
        // the same autoresizing-mask-based mechanism `content.view` already relies on (never
        // opted out). Opting `sidebarContainer` itself into pure Auto Layout with no constraint
        // defining its own width/position left it ambiguous — any layoutSubtreeIfNeeded()/layout()
        // pass could resolve it to 0 width, wiping out whatever frame NSSplitView had just set via
        // setPosition. `sidebar.view`'s constraints (below) are relative to sidebarContainer's
        // bounds, which stay well-defined as long as sidebarContainer itself stays frame-managed.
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
        // Layer-back the split so the terminal's CAMetalLayer islands are contained within
        // split.layer rather than promoted to the window CA root as separate islands.
        // Without this, dynamically-added terminal Metal layers land above statusLine.layer
        // in the window-root CA compositor (later insertion = higher z), hiding the status bar.
        // With split.layer in play, split.layer vs statusLine.layer ordering follows subview
        // insertion order (split first → statusLine on top), which is correct.
        KouenDesign.makeClear(split)
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
            edgeDivider.widthAnchor.constraint(equalToConstant: KouenDesign.Divider.thickness),
        ])
        updateEdgeDividerConstraints(sidebarContainer: sidebarContainer)

        edgeDivider.layer?.backgroundColor = resolvedDividerColor().cgColor

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
            name: Notification.Name("KouenOpenFilePreview"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openURLInBrowserPaneFromTerminal(_:)),
            name: Notification.Name("KouenOpenInBrowserPaneURL"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(revealFileInTreeFromTerminal(_:)),
            name: Notification.Name("KouenRevealFileInTree"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sidebarPlacementSettingChanged),
            name: Notification.Name("KouenSidebarPlacementChanged"),
            object: nil
        )
    }

    /// Settings window changed `sidebarOnRight` directly (bypassing `toggleSidebarPosition()`,
    /// which flips the flag AND reorders the NSSplitView subviews together). Resync this
    /// window's physical layout to match, or the next sidebar toggle animates the wrong view.
    @objc private func sidebarPlacementSettingChanged(_ note: Notification) {
        updateSidebarPlacement()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func viewDidLayout() {
        super.viewDidLayout()
        // AppKit runs several layout passes on window construction before it's ever
        // shown — at that point the window is still pinned to `minSize` (480x400),
        // not its real launch frame; the real frame lands a few passes later, once
        // the window actually becomes visible. Applying the initial sidebar state
        // (or letting the first Cmd+\ toggle run) against that transient size races
        // the window's own resize-to-real-size, and the two `setPosition` writers can
        // leave the divider at a stale width — content squeezed to sidebar width, the
        // untouched sidebar showing blank. Wait for the window to actually be visible.
        guard view.window?.isVisible == true else { return }
        if !didApplyInitialSidebarState && split.bounds.width > 0 {
            didApplyInitialSidebarState = true
            applyInitialSidebarState()
        }
    }

    private func applyInitialSidebarState() {
        let settings = SessionCoordinator.shared.settings
        if settings.sidebarCollapsedOnLaunch {
            // Keep `sidebarVisible` in sync with the forced-collapsed state so the
            // first `toggleSidebar()` (e.g. user expanding the sidebar after launch)
            // computes `!false -> true` and actually shows it. Without this, a stale
            // `sidebarVisible == true` from a previous session makes the first toggle
            // collapse (no-op) instead of expand.
            SessionCoordinator.shared.settings.sidebarVisible = false
            applySidebarVisibility(false, animated: false)
        } else {
            applySidebarVisibility(settings.sidebarVisible, animated: false)
        }
    }

    @objc private func openFilePreviewFromTerminal(_ notification: Notification) {
        guard let rawPath = notification.userInfo?["path"] as? String else { return }
        // The terminal surface's own OSC-7 cwd tracking can be nil or stale (e.g. a
        // non-interactive agent subprocess that never emits OSC 7), so a raw candidate that
        // doesn't exist as-is gets a second, authoritative resolution attempt here — same
        // workbench-cwd + fuzzy-path fallback vi `:e` uses.
        let resolvedPath = FileManager.default.fileExists(atPath: rawPath)
            ? rawPath
            : contentVC.resolveTerminalLinkPath(rawPath)
        guard let path = resolvedPath else { return }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue,
              // Don't open executables (.app, .command, etc.) — security
              !path.hasSuffix(".app"), !path.hasSuffix(".command"), !path.hasSuffix(".tool")
        else { return }
        // HTML files open in the browser pane, not file preview
        if path.hasSuffix(".html") || path.hasSuffix(".htm") {
            NotificationCenter.default.post(
                name: Notification.Name("KouenOpenInBrowserPaneURL"),
                object: nil,
                userInfo: ["url": URL(fileURLWithPath: path)]
            )
            return
        }
        contentVC.openFileTab(path: path)
        setSidebarVisible(true, animated: true)
        sidebar.selectFilesTab(revealPath: path)
    }

    @objc private func revealFileInTreeFromTerminal(_ notification: Notification) {
        guard let rawPath = notification.userInfo?["path"] as? String else { return }
        let resolvedPath = FileManager.default.fileExists(atPath: rawPath)
            ? rawPath
            : contentVC.resolveTerminalLinkPath(rawPath)
        guard let path = resolvedPath else { return }
        sidebar.revealFileInTreeQuietly(path: path)
    }

    @objc private func openURLInBrowserPaneFromTerminal(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        SessionCoordinator.shared.splitPaneCoordinator.openBrowserPane(url: url, direction: .horizontal)
    }

    /// Resolve the divider line color: user override (`settings.dividerHex`) wins; otherwise
    /// a quiet near-background hairline — `#1E1E1E` on dark themes (the default look), and the
    /// theme's border on light themes (where a near-black line would read as a hard rule).
    private func resolvedDividerColor() -> NSColor {
        if let hex = SessionCoordinator.shared.settings.dividerHex, let color = NSColor.fromHex(hex) {
            return color
        }
        // Match the visibility of the terminal pane-split divider (KouenSplitView)
        // rather than the faint `.border` hairline previously used here.
        return KouenChrome.current.paneDivider
    }

    func previewExternalFile(path: String) {
        sidebar.openExternalFile(path: path)
    }

    func applyChrome() {
        // Never `makeClear(view)` here: the root contentView must stay non-layer-backed
        // (see loadView) so the window stays rounded with no dark perimeter seam. It is
        // transparent already; there is nothing to repaint on it.
        if let sidebarContainer = sidebarContainerView {
            // Keep this transparent — the sidebar view inside owns the chrome. This is a
            // child layer-backing island and does not affect the root's backing.
            KouenDesign.makeClear(sidebarContainer)
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
        guard note.userInfo?["payload"] is SnapshotChangedPayload else { return }
        let payload = note.snapshotPayload
        let metadataOnly = payload.metadataOnly
        if payload.chromeChanged {
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
        view.window?.title = snap.activeWorkspace.map { "Kouen — \($0.name)" } ?? "Kouen"
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
        // Clamp to the same floor `SplitChromeDelegate` enforces on user drags — a
        // persisted width below it (e.g. `sidebarWidth: 0` from a stuck-collapse write,
        // see cmd-backslash-sidebar-zero-width) makes `target == 0` for both directions,
        // so the zero-delta guard below always early-exits and the toggle looks dead.
        let persistedWidth = max(
            SplitChromeDelegate.sidebarMinWidth,
            SessionCoordinator.shared.settings.sidebarWidth.map(CGFloat.init) ?? KouenDesign.sidebarWidth
        )
        let target = visible ? persistedWidth : 0
        splitDelegate.allowFullCollapse = true
        sidebarLog.debug("applySidebarVisibility visible=\(visible) animated=\(animated) persistedWidth=\(persistedWidth) target=\(target) totalWidth=\(self.split.bounds.width) sidebarOnRight=\(SessionCoordinator.shared.settings.sidebarOnRight)")
        guard animated, let panel = sidebarContainerView else {
            let panel = sidebarContainerView
            panel?.isHidden = false              // unhide so setPosition can size it to 0
            let hosts = content.collectTerminalHosts()
            hosts.values.forEach { $0.setPresentsWithTransaction(true) }
            setSidebarWidth(target)
            hosts.values.forEach { $0.setPresentsWithTransaction(false) }
            panel?.isHidden = !visible
            if visible { panel?.layoutSubtreeIfNeeded() }
            splitDelegate.allowFullCollapse = false
            edgeDivider.isHidden = !visible
            updateContentLeadingInset()
            sidebarLog.debug("applySidebarVisibility unanimated path done panelHidden=\(panel?.isHidden ?? true)")
            return
        }

        // Kill any in-flight animation before reading panel.frame.width.
        // Without this, a zero-delta early-exit returns without replacing sidebarDisplayLink,
        // leaving the old link running with stale _sidebarVisible — causing the sidebar to
        // collapse even when the user requested expand.
        sidebarDisplayLink?.invalidate()
        sidebarDisplayLink = nil

        // Unhide before the slide so the panel is visible as it shrinks/grows.
        panel.isHidden = false
        // Show/hide the inner hairline immediately so it never strands over the terminal.
        edgeDivider.isHidden = !visible
        let start = panel.frame.width
        guard abs(target - start) > 0.5 else {
            sidebarLog.debug("applySidebarVisibility zero-delta guard fired start=\(start) target=\(target) — no animation, jumping directly")
            setSidebarWidth(target)
            if !visible { panel.isHidden = true }
            splitDelegate.allowFullCollapse = false
            updateContentLeadingInset()
            return
        }
        sidebarLog.debug("applySidebarVisibility starting animation start=\(start) target=\(target)")
        // ponytail: presentsWithTransaction removed from animated path — was blocking main thread every frame.
        // If black flash reappears during slide, restore only on the final frame (raw >= 1).
        _sidebarStart = start
        _sidebarTarget = target
        _sidebarT0 = CACurrentMediaTime()
        _sidebarVisible = visible
        let link = view.displayLink(target: self, selector: #selector(_sidebarLinkFired))
        link.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
        sidebarDisplayLink = link
    }

    private func animateSidebar(from start: CGFloat, to target: CGFloat, t0: CFTimeInterval, visible: Bool, token: Int) {
        guard token == sidebarAnimToken, let panel = sidebarContainerView else { return }
        let duration = KouenDesign.Motion.standard
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
        split.layout()
        CATransaction.commit()
        if raw >= 1 {
            sidebarDisplayLink?.invalidate()
            sidebarDisplayLink = nil
            if !visible {
                panel.isHidden = true
            } else {
                // split.layout() per-frame moves the divider but doesn't flush
                // pending layouts inside the panel. NSHostingViews (SwiftUI) that
                // started at zero width may not have had a valid layout pass — force
                // one now so content is never blank after the panel opens.
                panel.layoutSubtreeIfNeeded()
            }
            splitDelegate.allowFullCollapse = false   // restore the 200pt drag floor
            updateContentLeadingInset()
            return
        }
        // Display link fires next frame — no asyncAfter needed.
    }

    @objc private func _sidebarLinkFired(_ link: CADisplayLink) {
        animateSidebar(from: _sidebarStart, to: _sidebarTarget, t0: _sidebarT0, visible: _sidebarVisible, token: sidebarAnimToken)
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

    /// Pops up the notifications dropdown. Works regardless of sidebar visibility.
    func showNotificationsDropdown() {
        sidebar.showNotificationsDropdown()
    }

    /// Toggles sidebar visibility (⌘\).
    func toggleSidebar() {
        if !didApplyInitialSidebarState {
            didApplyInitialSidebarState = true
            applyInitialSidebarState()
        }
        let visible = SessionCoordinator.shared.settings.sidebarVisible
        sidebarLog.debug("toggleSidebar() called, currentVisible=\(visible) window=\(String(describing: self.view.window)) keyWindow=\(NSApp.keyWindow === self.view.window)")
        setSidebarVisible(!visible, animated: true)
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
        guard totalWidth > 0 else {
            sidebarLog.debug("setSidebarWidth totalWidth=0, deferring to next runloop turn (width=\(width))")
            DispatchQueue.main.async { [weak self] in self?.setSidebarWidth(width) }
            return
        }
        let sidebarOnRight = SessionCoordinator.shared.settings.sidebarOnRight
        let position: CGFloat
        if sidebarOnRight {
            position = totalWidth > width ? (totalWidth - width) : 0
        } else {
            position = width
        }
        sidebarLog.debug("setSidebarWidth width=\(width) totalWidth=\(totalWidth) sidebarOnRight=\(sidebarOnRight) -> setPosition=\(position)")
        split.setPosition(position, ofDividerAt: 0)
        // Diagnostic for cmd-backslash-sidebar-launch-race-6th's 2026-08-16 recurrence:
        // setPosition is advisory — NSSplitViewDelegate's constrain methods can silently
        // clamp it with no error. Log what was actually accepted vs what was asked for.
        sidebarLog.debug("setSidebarWidth accepted panelWidth=\(self.sidebarContainerView?.frame.width ?? -1) contentWidth=\(self.content.view.frame.width) (asked width=\(width))")
    }

    /// Fired by `SplitChromeDelegate` on every split-view resize — animations, `viewDidLayout`,
    /// `setSidebarVisible`, and genuine user divider drags all funnel through this one
    /// notification with no reliable way to tell them apart by call site: `NSSplitView` doesn't
    /// guarantee the notification fires synchronously inside `setPosition`, so a "was I the one
    /// calling setPosition just now" boolean flag can already be back to `false` by the time
    /// this runs — misclassifying programmatic resizes (including every frame of the open/close
    /// slide animation) as user drags. `NSEvent.pressedMouseButtons` sidesteps the timing
    /// question entirely: it's only nonzero while a mouse button is physically held down, which
    /// is true during an actual divider drag and never true for a menu command, test, or
    /// animation-driven resize. Debounced — a drag fires this continuously, and writing to disk
    /// on every pixel would be wasteful.
    private func handlePotentialUserSidebarResize() {
        guard NSEvent.pressedMouseButtons & 1 != 0,
              let panel = sidebarContainerView, !panel.isHidden
        else { return }
        // Never persist below the delegate's own floor — if `allowFullCollapse` is ever
        // left stuck true (e.g. an interrupted collapse/expand animation) a real drag can
        // reach 0 here, which then bricks every future toggle (see
        // cmd-backslash-sidebar-zero-width: target computes to 0 in both directions).
        let width = max(Float(SplitChromeDelegate.sidebarMinWidth), Float(panel.frame.width))
        sidebarLog.debug("handlePotentialUserSidebarResize persisting width=\(width) (raw panel.frame.width=\(panel.frame.width))")
        sidebarWidthSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [sidebarLog] in
            SessionCoordinator.shared.settings.sidebarWidth = width
            do {
                try SessionCoordinator.shared.settings.save()
            } catch {
                sidebarLog.debug("handlePotentialUserSidebarResize save failed: \(String(describing: error))")
            }
        }
        sidebarWidthSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    func toggleSidebarPosition() {
        SessionCoordinator.shared.settings.sidebarOnRight.toggle()
        try? SessionCoordinator.shared.settings.save()
        updateSidebarPlacement()
    }

}

@MainActor
private final class SplitChromeDelegate: NSObject, NSSplitViewDelegate {
    /// The floor a *user drag* can't shrink the sidebar below, on either side. Also the
    /// floor `MainSplitViewController` clamps a persisted `sidebarWidth` to before
    /// treating it as a toggle target — a width below this reaching disk is exactly how
    /// `cmd-backslash-sidebar-zero-width` bricked every future toggle.
    static let sidebarMinWidth: CGFloat = 200
    /// While a programmatic collapse/expand is running, let the divider reach 0 so the
    /// sidebar can fully disappear. At rest it's false, so a *user drag* still floors
    /// at `sidebarMinWidth` and can't shrink the sidebar to an unusable sliver.
    var allowFullCollapse = false
    /// Fired on every resize (drag or programmatic) — the owner filters for genuine
    /// user drags via `NSEvent.pressedMouseButtons`.
    var onResize: (() -> Void)?

    func splitViewDidResizeSubviews(_ notification: Notification) {
        onResize?()
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimum: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        let right = SessionCoordinator.shared.settings.sidebarOnRight
        if right {
            guard index == 0 else { return proposedMinimum }
            let totalWidth = splitView.bounds.width
            return totalWidth - 320
        } else {
            guard index == 0 else { return proposedMinimum }
            return allowFullCollapse ? 0 : Self.sidebarMinWidth
        }
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximum: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        let right = SessionCoordinator.shared.settings.sidebarOnRight
        if right {
            guard index == 0 else { return proposedMaximum }
            let totalWidth = splitView.bounds.width
            return allowFullCollapse ? totalWidth : (totalWidth - Self.sidebarMinWidth)
        } else {
            return index == 0 ? 320 : proposedMaximum
        }
    }

    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        var rect = proposedEffectiveRect
        rect.size.width = 4
        return rect
    }

    // `setHoldingPriority` alone doesn't stick here — with a classic constrainMin/Max
    // delegate present, NSSplitView still redistributes width proportionally on window
    // resize. Explicitly opt the sidebar out of auto-resize so only the terminal side
    // absorbs window growth/shrink.
    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview subview: NSView) -> Bool {
        let right = SessionCoordinator.shared.settings.sidebarOnRight
        let sidebarIndex = right ? 1 : 0
        guard splitView.subviews.count > sidebarIndex, splitView.subviews[sidebarIndex] === subview else { return true }
        return false
    }
}
