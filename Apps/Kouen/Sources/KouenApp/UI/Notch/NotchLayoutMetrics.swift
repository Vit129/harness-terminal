import Foundation
import KouenCore

public struct NotchScreenMetrics: Sendable, Equatable {
    public var minX: Double
    public var minY: Double
    public var width: Double
    public var height: Double
    public var safeAreaTop: Double
    public var auxiliaryTopLeftMaxX: Double?
    public var auxiliaryTopRightMinX: Double?

    public init(
        minX: Double,
        minY: Double,
        width: Double,
        height: Double,
        safeAreaTop: Double = 0,
        auxiliaryTopLeftMaxX: Double? = nil,
        auxiliaryTopRightMinX: Double? = nil
    ) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
        self.safeAreaTop = safeAreaTop
        self.auxiliaryTopLeftMaxX = auxiliaryTopLeftMaxX
        self.auxiliaryTopRightMinX = auxiliaryTopRightMinX
    }
}

public struct NotchRect: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct NotchLayoutMetrics: Sendable, Equatable {
    public static let fallbackClosedWidth: Double = 68
    public static let fallbackClosedHeight: Double = 18
    public static let minimumOpenWidth: Double = 288
    public static let preferredOpenWidth: Double = 360
    public static let preferredOpenHeight: Double = 240
    public static let shadowPadding: Double = 20

    public var hasPhysicalNotch: Bool
    public var closedWidth: Double
    public var closedHeight: Double
    public var openWidth: Double
    public var openHeight: Double
    public var panelFrame: NotchRect

    /// Transient peek card (one-row live activity): slightly wider than the closed notch so
    /// the dropped row reads as the notch stretching, never as a detached toast.
    public var peekWidth: Double { closedWidth + 110 }
    public var peekHeight: Double { closedHeight + 20 }

    public init(
        hasPhysicalNotch: Bool,
        closedWidth: Double,
        closedHeight: Double,
        openWidth: Double,
        openHeight: Double,
        panelFrame: NotchRect
    ) {
        self.hasPhysicalNotch = hasPhysicalNotch
        self.closedWidth = closedWidth
        self.closedHeight = closedHeight
        self.openWidth = openWidth
        self.openHeight = openHeight
        self.panelFrame = panelFrame
    }

    public static func compute(for screen: NotchScreenMetrics) -> NotchLayoutMetrics {
        let availableWidth = max(160, screen.width)
        let hasNotch = screen.safeAreaTop > 0
        let inferredNotchWidth = notchWidth(from: screen)
        let closedWidthMax = min(250, availableWidth - 24)
        let closedWidth: Double
        if let inferredNotchWidth {
            // Hardware-measured notch: floor at 100 as a sanity guard against a bad reading.
            closedWidth = clamp(inferredNotchWidth, min: 100, max: closedWidthMax)
        } else {
            closedWidth = clamp(fallbackClosedWidth, min: 60, max: closedWidthMax)
        }
        let closedHeight: Double
        if hasNotch {
            closedHeight = clamp(screen.safeAreaTop, min: 20, max: 28)
        } else {
            closedHeight = fallbackClosedHeight
        }
        let maxOpenWidth = max(280, availableWidth - 32)
        let minOpenWidth = min(minimumOpenWidth, maxOpenWidth)
        let openWidth = clamp(preferredOpenWidth, min: minOpenWidth, max: maxOpenWidth)
        let openHeight = preferredOpenHeight
        let panelWidth = openWidth + shadowPadding * 2
        let panelHeight = openHeight + shadowPadding
        let panelX = (screen.minX + screen.width / 2 - panelWidth / 2).rounded()
        let panelY = (screen.minY + screen.height - panelHeight).rounded()

        return NotchLayoutMetrics(
            hasPhysicalNotch: hasNotch,
            closedWidth: closedWidth.rounded(),
            closedHeight: closedHeight.rounded(),
            openWidth: openWidth.rounded(),
            openHeight: openHeight.rounded(),
            panelFrame: NotchRect(
                x: panelX,
                y: panelY,
                width: panelWidth.rounded(),
                height: panelHeight.rounded()
            )
        )
    }

    private static func notchWidth(from screen: NotchScreenMetrics) -> Double? {
        guard let leftMaxX = screen.auxiliaryTopLeftMaxX,
              let rightMinX = screen.auxiliaryTopRightMinX
        else { return nil }
        let width = rightMinX - leftMaxX
        guard width >= 120 else { return nil }
        return width
    }

    private static func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}
