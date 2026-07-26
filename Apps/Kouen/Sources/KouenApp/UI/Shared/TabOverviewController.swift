import AppKit
import KouenCore
import KouenTerminalKit

/// Tab Overview — ⌘⇧\ opens a panel showing all tabs as thumbnails; click to switch.
@MainActor
final class TabOverviewController {
    static let shared = TabOverviewController()
    private var panel: NSPanel?
    private init() {}

    func toggle() {
        if let p = panel, p.isVisible { dismiss(); return }
        present()
    }

    private func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func present() {
        let coord = SessionCoordinator.shared
        guard let ws = coord.snapshot.activeWorkspace else { return }
        let tabs = ws.tabs
        guard !tabs.isEmpty else { return }
        let wsID = ws.id

        // Grid constants
        let cellW: CGFloat = 200, cellH: CGFloat = 150, gap: CGFloat = 12, cols = 4
        let rows = (tabs.count + cols - 1) / cols
        let gridW = CGFloat(min(tabs.count, cols)) * (cellW + gap) + gap
        let gridH = CGFloat(rows) * (cellH + gap) + gap
        let screenH = NSScreen.main?.visibleFrame.height ?? 800
        let panelW = gridW, panelH = min(gridH + 8, screenH * 0.85)

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let panelFrame = NSRect(
            x: screen.frame.midX - panelW / 2,
            y: screen.frame.midY - panelH / 2,
            width: panelW, height: panelH)

        let p = NSPanel(contentRect: panelFrame,
                        styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.title = ""
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.collectionBehavior = [.canJoinAllSpaces]

        let blur = NSVisualEffectView(frame: .zero)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false
        p.contentView?.addSubview(blur)
        if let cv = p.contentView {
            NSLayoutConstraint.activate([
                blur.topAnchor.constraint(equalTo: cv.topAnchor),
                blur.leadingAnchor.constraint(equalTo: cv.leadingAnchor),
                blur.trailingAnchor.constraint(equalTo: cv.trailingAnchor),
                blur.bottomAnchor.constraint(equalTo: cv.bottomAnchor),
            ])
        }

        let thumbSize = NSSize(width: cellW - 8, height: cellH - 28)
        let container = NSView()
        var pendingRenders: [(cell: TabCell, surfaceView: KouenTerminalSurfaceView)] = []
        for (i, tab) in tabs.enumerated() {
            let col = i % cols
            let row = i / cols
            let x = gap + CGFloat(col) * (cellW + gap)
            let y = gridH - CGFloat(row + 1) * (cellH + gap)
            let title = tab.title.isEmpty ? "Terminal" : tab.title
            let tabID = tab.id
            let sv = tab.rootPane.allSurfaceIDs().first
                .flatMap { coord.terminalHostIfExists(for: $0) }?.surfaceView
            let cell = TabCell(frame: NSRect(x: x, y: y, width: cellW, height: cellH),
                               title: title, image: nil) { [weak self] in
                self?.dismiss()
                coord.selectTab(workspaceID: wsID, tabID: tabID)
            }
            container.addSubview(cell)
            if let sv { pendingRenders.append((cell, sv)) }
        }
        container.frame = NSRect(origin: .zero, size: NSSize(width: gridW, height: gridH))

        let scrollView = NSScrollView()
        scrollView.documentView = container
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: blur.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])

        panel = p
        p.makeKeyAndOrderFront(nil)

        // Render thumbnails after the panel is on screen so open feels instant.
        // Task.yield() between renders gives AppKit a run-loop cycle to process events.
        Task { @MainActor [weak self] in
            for (cell, sv) in pendingRenders {
                guard self?.panel != nil else { break }
                await Task.yield()
                cell.setThumbnail(sv.renderThumbnail(size: thumbSize))
            }
        }
    }
}

// MARK: - Tab Cell

@MainActor
private final class TabCell: NSView {
    private let action: () -> Void
    private var imageView: NSImageView!

    init(frame: NSRect, title: String, image: NSImage?, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor

        let thumbH = frame.height - 28
        let iv = NSImageView(frame: NSRect(x: 4, y: 24, width: frame.width - 8, height: thumbH))
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.wantsLayer = true
        iv.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        iv.layer?.cornerRadius = 4
        if let img = image { iv.image = img }
        imageView = iv
        addSubview(iv)

        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 6, y: 4, width: frame.width - 12, height: 18)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setThumbnail(_ image: NSImage?) {
        guard let image else { return }
        imageView.image = image
        imageView.layer?.backgroundColor = nil
    }

    override func mouseUp(with event: NSEvent) { action() }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        guard window != nil else { return }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
    }
}
