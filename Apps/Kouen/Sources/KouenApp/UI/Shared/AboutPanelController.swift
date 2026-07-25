import AppKit
import SwiftUI

@MainActor
final class AboutPanelController: NSObject {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let controller = NSHostingController(rootView: AboutView())
            let win = NSWindow(contentViewController: controller)
            win.title = "About Kouen"
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.isRestorable = false
            win.preventsApplicationTerminationWhenModal = false
            win.setContentSize(NSSize(width: 440, height: 360))
            window = win
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowWillClose(_:)),
                name: NSWindow.willCloseNotification,
                object: win
            )
        }
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private static func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: notification.object)
        window = nil
    }
}

private struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    private let cliPath = CLIInstaller.installedCLIPath.path

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 12) {
                if let logo = KouenDesign.brandLogo() {
                    Image(nsImage: logo)
                        .resizable()
                        .frame(width: 96, height: 96)
                }
                Text("Kouen")
                    .font(.system(size: 24, weight: .bold))
                Text("Version \(version) · build \(build)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.top, -6)
                Text("A native macOS terminal for AI agents and dev sessions.\nGPU-rendered by Kouen's own terminal engine.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                VStack(spacing: 3) {
                    Text("kouen-cli installed at")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(cliPath)
                        .font(.system(size: 10.5).monospaced())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                .padding(.top, 4)
                HStack(spacing: 10) {
                    Button("Copy CLI Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cliPath, forType: .string)
                    }
                    .buttonStyle(MonoPillButtonStyle())
                    Button("Open on GitHub") {
                        if let url = URL(string: "https://github.com/Vit129/kouen-terminal") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(MonoPillButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(.top, 28)
            .padding(.bottom, 28)
            .padding(.horizontal, 24)
        }
        .frame(width: 440, height: 360)
    }
}

/// Monochrome pill — matches `KouenPillButton(kind: .secondary)`: no system-blue tint.
private struct MonoPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.10 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            )
            .foregroundStyle(.primary)
    }
}
