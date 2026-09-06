import AppKit
import Combine
import KouenCore
import SwiftUI

@MainActor
final class NotchPanelController: NSObject {
    static let shared = NotchPanelController()

    private let model = AgentNotchViewModel()
    private let coalescer = SnapshotCoalescer()  // cmux: burst → one refresh per runloop turn
    private let maskAnimator = NotchMaskAnimator()  // Zed/Otty: GPU path animation
    private var maskObserver: AnyCancellable?
    private var visibilityObserver: AnyCancellable?
    private var panel: NotchPanel?
    private var started = false

    private override init() {
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        model.refreshFromCoordinator()
        observeNotifications()
        refreshVisibility()
    }

    /// The panel is created (and kept) unconditionally, even with the persistent HUD off —
    /// a transient "finished/errored/needs input" peek should still surface like a system
    /// notification (see `applyIdleVisibility`), and that needs somewhere to render into.
    func refreshVisibility() {
        model.refreshFromCoordinator()
        createPanelIfNeeded()
        updatePanelGeometry()
        if !SessionCoordinator.shared.settings.notchVisibilityMode
            .isEnabled(for: SessionCoordinator.shared.settings.experienceMode) {
            model.close()
        }
        applyIdleVisibility()
    }

    /// Orders the panel front/out based on live agent state.
    ///
    /// With the persistent HUD **on** (`notchVisibilityMode` resolves enabled): hidden while
    /// every agent is idle and the HUD itself is closed, shown the instant any agent starts
    /// working or needs approval — independent of which app has focus. A row `.waiting` on
    /// approval counts as "not idle" too (not just `.working`): hiding the notch while an
    /// agent needs input would bury the one thing the user actually needs to see.
    ///
    /// With it **off** (the default): the always-visible-while-working bar never appears, but
    /// a transient `.peek` (agent finished/errored/needs input) still pops up and auto-dismisses
    /// — same as any other OS notification, not tied to the persistent-HUD toggle.
    private func applyIdleVisibility() {
        guard panel != nil else { return }
        let enabled = SessionCoordinator.shared.settings.notchVisibilityMode
            .isEnabled(for: SessionCoordinator.shared.settings.experienceMode)
        let shouldShow = enabled
            ? (model.workingCount > 0 || model.waitingCount > 0 || model.presentation != .closed)
            : model.isPeeking
        if shouldShow {
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
    }

    func openFromMenu() {
        let coordinator = SessionCoordinator.shared
        if !coordinator.settings.notchVisibilityMode.isEnabled(for: coordinator.settings.experienceMode) {
            coordinator.settings.notchVisibilityMode = .on
            try? coordinator.settings.save()
        }
        refreshVisibility()
        model.open()
        applyIdleVisibility()
    }

    /// Mirrors `openFromMenu`: an explicit menu "Close" is a persistent user override, not
    /// just a `.close()` of the expanded content — otherwise `applyIdleVisibility`'s
    /// by-design "show while any agent is working/awaiting" behavior immediately brings the
    /// compact bar right back, and the menu action looks like it did nothing.
    func closeFromMenu() {
        let coordinator = SessionCoordinator.shared
        if coordinator.settings.notchVisibilityMode.isEnabled(for: coordinator.settings.experienceMode) {
            coordinator.settings.notchVisibilityMode = .off
            try? coordinator.settings.save()
        }
        model.close()
        refreshVisibility()
    }

    func toggleFromMenu() {
        let coordinator = SessionCoordinator.shared
        if !coordinator.settings.notchVisibilityMode.isEnabled(for: coordinator.settings.experienceMode) {
            coordinator.settings.notchVisibilityMode = .on
            try? coordinator.settings.save()
        }
        refreshVisibility()
        model.toggleOpen()
        applyIdleVisibility()
    }

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(snapshotChanged(_:)),
            name: NotificationBus.shared.snapshotChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func createPanelIfNeeded() {
        guard panel == nil else { return }
        let metrics = (NSScreen.main ?? NSScreen.screens.first).map(NotchGeometry.metrics(for:)) ?? NotchGeometry.fallback
        model.updateGeometry(metrics)
        let frame = nsRect(metrics.panelFrame)
        let panel = NotchPanel(contentRect: frame)
        let hosting = NSHostingView(rootView: AgentNotchRootView(model: model))
        maskAnimator.install(on: hosting)
        panel.contentView = hosting
        self.panel = panel

        // Snap mask to closed state (no animation on first paint)
        updateNotchMask(animated: false)

        // GPU path: mask tracks presentation + content height changes via Combine
        maskObserver = Publishers.CombineLatest(model.$presentation, model.$openContentHeight)
            .receive(on: RunLoop.main)
            .dropFirst()  // initial handled by updateNotchMask(animated: false) above
            .sink { [weak self] _, _ in self?.updateNotchMask(animated: true) }

        // Idle-hide: re-evaluate panel ordering whenever agent rows or presentation change,
        // so a snapshot-driven transition (agent starts working while Kouen isn't frontmost)
        // brings the panel back without waiting for a menu action or screen-parameter change.
        visibilityObserver = Publishers.CombineLatest(model.$rows, model.$presentation)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.applyIdleVisibility() }
    }

    private func updatePanelGeometry() {
        guard let panel,
              let screen = NSScreen.main ?? NSScreen.screens.first
        else { return }
        let metrics = NotchGeometry.metrics(for: screen)
        model.updateGeometry(metrics)
        let newFrame = nsRect(metrics.panelFrame)
        guard panel.frame != newFrame else { return }
        panel.setFrame(newFrame, display: true)
        updateNotchMask(animated: false)  // geometry changed — re-snap mask to new coordinate space
    }

    private func updateNotchMask(animated: Bool) {
        let metrics = model.geometry
        let panelW = CGFloat(metrics.panelFrame.width)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        let width: CGFloat
        let height: CGFloat
        let topRadius: CGFloat = metrics.hasPhysicalNotch ? 2 : 9
        let bottomRadius: CGFloat
        let isOpening: Bool

        switch model.presentation {
        case .closed:
            width = CGFloat(metrics.closedWidth)
            height = CGFloat(metrics.closedHeight)
            bottomRadius = metrics.hasPhysicalNotch ? 14 : 15
            isOpening = false
        case .peek:
            width = CGFloat(metrics.peekWidth)
            height = CGFloat(metrics.peekHeight)
            bottomRadius = 18
            isOpening = true
        case .open:
            width = CGFloat(metrics.openWidth)
            height = model.openContentHeight
            bottomRadius = 22
            isOpening = true
        }

        // NSHostingView is flipped (isFlipped=true) → layer y=0 is the top of the view.
        let x = (panelW - width) / 2
        let rect = CGRect(x: x, y: 0, width: width, height: height)
        maskAnimator.update(to: rect, topRadius: topRadius, bottomRadius: bottomRadius,
                            isOpening: isOpening, reduceMotion: reduceMotion, animated: animated)
    }

    @objc private func snapshotChanged(_ note: Notification) {
        guard !note.snapshotPayload.metadataOnly else { return }
        // cmux pattern: coalesce snapshot bursts → one model refresh per runloop turn.
        // Geometry stays frozen here — only screen changes (screenParametersChanged) move the panel.
        coalescer.signal { [weak self] in self?.model.refreshFromCoordinator() }
    }

    @objc private func screenParametersChanged(_ note: Notification) {
        refreshVisibility()
    }

    private func nsRect(_ rect: NotchRect) -> NSRect {
        NSRect(
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height
        )
    }
}
