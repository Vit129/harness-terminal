import AppKit
import SwiftUI

/// Minimal transient toast — fades in at bottom-center of a host view, holds
/// briefly, fades out. No persistent state; multiple calls stack fresh views.
@MainActor
private final class ToastHostingView<Content: View>: NSHostingView<Content> {
#if compiler(>=6.4)
    @available(macOS 27.0, *)
    override var cornerConfiguration: NSViewCornerConfiguration? {
        .corners(radius: .containerConcentric)
    }
#endif
}

@MainActor
enum Toast {
    static func show(_ message: String, in host: NSView, hold: TimeInterval = 1.0) {
        let hosting = ToastHostingView(rootView: ToastBody(message: message))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.alphaValue = 0
        host.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            hosting.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -28),
        ])
        let fade = 0.18
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = fade
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            hosting.animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + hold + fade) { [weak hosting] in
            guard let hosting else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = fade
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                hosting.animator().alphaValue = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + fade) { [weak hosting] in
                hosting?.removeFromSuperview()
            }
        }
    }
}

private struct ToastBody: View {
    let message: String
    var body: some View {
        let chrome = KouenDesign.chrome
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(chrome.terminalBackground))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(chrome.textPrimary.withAlphaComponent(chrome.isDark ? 0.92 : 0.95)))
            )
            .allowsHitTesting(false)
    }
}
