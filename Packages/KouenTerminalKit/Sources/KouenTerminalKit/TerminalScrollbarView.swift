import AppKit

/// Minimal auto-hiding scrollbar shown while scrolling through scrollback or scrollable lists,
/// with full hover expansion and click-and-drag-to-scroll support.
///
/// Lives as a sibling above the Metal surface in `TerminalHostView` (the surface is layer-hosting
/// and can't take subviews), or above the file list in `WorkspaceFileTreeView`. A thin rounded
/// thumb on the right edge snaps visible on scroll and fades out when idle. Hovering expands the
/// thumb to full width and pauses the fade; left-clicking and dragging smoothly scrubs through
/// the scroll range.
@MainActor
public final class TerminalScrollbarView: NSView {
    /// Track geometry, in fractions of the scrollable range. `progress` is the thumb position
    /// from top (0 = scrolled to the very top of history, 1 = at the live bottom); `heightFraction`
    /// is the visible viewport as a fraction of the total buffer (thumb size).
    private var progress: CGFloat = 1
    private var heightFraction: CGFloat = 1
    private var hideWork: DispatchWorkItem?
    private var thumbColor = NSColor.labelColor
    private var hasScrollableContent = false
    private var trackingArea: NSTrackingArea?

    private var isHovered = false
    private var isDragging = false
    private var dragGrabOffsetY: CGFloat = 0

    /// Width of the entire hit-testable strip along the trailing edge.
    public static let stripWidth: CGFloat = 14

    private let normalThumbWidth: CGFloat = 4
    private let expandedThumbWidth: CGFloat = 8
    private let edgeInset: CGFloat = 3
    private let trackInsetY: CGFloat = 3
    private let minThumbHeight: CGFloat = 28
    private let cornerRadius: CGFloat = 4
    private let fadeOutDelay: TimeInterval = 0.9

    /// Fires when the user clicks or drags the thumb with the normalized progress (0...1).
    public var onScrollToProgress: ((_ progress: CGFloat) -> Void)?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
        alphaValue = 0
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Flipped so thumb math is top-down (line 0 at the top of the buffer).
    public override var isFlipped: Bool { true }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        guard hasScrollableContent else { return }
        isHovered = true
        hideWork?.cancel()
        isHidden = false
        animator().alphaValue = 1
        needsDisplay = true
    }

    public override func mouseMoved(with event: NSEvent) {
        guard hasScrollableContent else { return }
        if !isHovered {
            isHovered = true
            hideWork?.cancel()
            isHidden = false
            alphaValue = 1
            needsDisplay = true
        }
    }

    public override func mouseExited(with event: NSEvent) {
        guard !isDragging else { return }
        isHovered = false
        needsDisplay = true
        armFade()
    }

    /// Theme the thumb to the canvas foreground (legible on any background, like the other overlays).
    public func applyColor(_ color: NSColor) {
        thumbColor = color
        needsDisplay = true
    }

    /// Current visual thumb frame in local coordinates.
    private var thumbRect: NSRect {
        let trackHeight = bounds.height - trackInsetY * 2
        guard trackHeight > 0 else { return .zero }
        let thumbHeight = max(minThumbHeight, min(trackHeight, heightFraction * trackHeight))
        let available = max(0, trackHeight - thumbHeight)
        let y = trackInsetY + progress * available
        let width = (isHovered || isDragging) ? expandedThumbWidth : normalThumbWidth
        let x = bounds.width - width - edgeInset
        return NSRect(x: x, y: y, width: width, height: thumbHeight)
    }

    /// Update the thumb from the scroll state and (re)arm the debounced fade-out. Each call cancels
    /// the prior fade, so continuous scrolling keeps it solid and it fades once scrolling settles.
    /// No-op (and hidden) when the whole buffer fits — nothing to scroll.
    public func show(topLine: Int, totalLines: Int, visibleRows: Int, fadeOutAfter: TimeInterval = 0.9) {
        guard totalLines > visibleRows, visibleRows > 0 else {
            hasScrollableContent = false
            hideNow()
            return
        }
        hasScrollableContent = true
        let scrollable = CGFloat(totalLines - visibleRows)
        if !isDragging {
            progress = max(0, min(1, CGFloat(topLine) / scrollable))
        }
        heightFraction = max(0, min(1, CGFloat(visibleRows) / CGFloat(totalLines)))

        hideWork?.cancel()
        isHidden = false
        alphaValue = 1
        needsDisplay = true
        if !isHovered && !isDragging {
            armFade(after: fadeOutAfter)
        }
    }

    private func armFade(after delay: TimeInterval? = nil) {
        guard !isHovered, !isDragging else { return }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isHovered, !self.isDragging else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                self.animator().alphaValue = 0
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (delay ?? fadeOutDelay), execute: work)
    }

    public func hideNow() {
        hideWork?.cancel()
        hideWork = nil
        isHidden = true
        alphaValue = 0
        isDragging = false
        isHovered = false
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard hasScrollableContent else { return }
        let rect = thumbRect
        guard rect.width > 0, rect.height > 0 else { return }
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        let alpha: CGFloat = isDragging ? 0.8 : (isHovered ? 0.65 : 0.45)
        thumbColor.withAlphaComponent(alpha).setFill()
        path.fill()
    }

    /// Click-through when hidden or when content fits in viewport; interactive when scrollable.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0, hasScrollableContent, let superview else { return nil }
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    public override func mouseDown(with event: NSEvent) {
        guard hasScrollableContent else { return }
        let local = convert(event.locationInWindow, from: nil)
        isDragging = true
        hideWork?.cancel()
        alphaValue = 1

        let thumb = thumbRect
        if thumb.contains(local) {
            dragGrabOffsetY = local.y - thumb.minY
        } else {
            // Clicked track above/below thumb: center thumb on click location
            dragGrabOffsetY = thumb.height / 2
            updateDrag(toY: local.y)
        }
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragging, hasScrollableContent else { return }
        let local = convert(event.locationInWindow, from: nil)
        updateDrag(toY: local.y)
    }

    public override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        needsDisplay = true

        let local = convert(event.locationInWindow, from: nil)
        if !bounds.contains(local) {
            isHovered = false
            armFade(after: 0.3)
        } else {
            armFade(after: fadeOutDelay)
        }
    }

    private func updateDrag(toY y: CGFloat) {
        let trackHeight = bounds.height - trackInsetY * 2
        let thumbHeight = max(minThumbHeight, min(trackHeight, heightFraction * trackHeight))
        let available = max(0, trackHeight - thumbHeight)
        guard available > 0 else { return }

        let targetThumbY = y - dragGrabOffsetY
        let clampedY = max(trackInsetY, min(trackInsetY + available, targetThumbY))
        let newProgress = (clampedY - trackInsetY) / available
        progress = max(0, min(1, newProgress))
        needsDisplay = true
        onScrollToProgress?(progress)
    }
}
