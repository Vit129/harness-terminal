import AppKit

@MainActor
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = false
        hasShadow = true  // system shadow follows mask alpha — no separate shadow layer needed
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .mainMenu + 3
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
    }

    // `canBecomeKey: true` + `.nonactivatingPanel` (set above) is the standard
    // Spotlight-style HUD combination: this panel CAN take keyboard focus (needed for the
    // notch's quick-reply text field) WITHOUT activating Kouen or stealing focus from
    // whatever app the user is currently typing in — `.nonactivatingPanel` is precisely the
    // style flag that decouples "this window is key" from "this app is active." It only
    // ever becomes key on an explicit click into a focusable control inside it (normal
    // AppKit click-to-focus); showing/hiding the panel itself uses `orderFrontRegardless()`
    // (see NotchPanelController), never `makeKeyAndOrderFront`, so hover-to-open never
    // grabs focus on its own. `canBecomeMain` stays false — this panel should never become
    // the app's main window (menu bar state, etc.), only transiently accept key input.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
