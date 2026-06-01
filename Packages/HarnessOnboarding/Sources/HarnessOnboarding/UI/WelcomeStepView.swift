import SwiftUI
import AppKit

/// First screen: the Harness mark, name, and tagline by themselves.
struct WelcomeStepView: View {
    @State private var appeared = false
    @State private var hasPlayedSound = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 10)

            logo
                .frame(width: 210, height: 210)
                .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 18)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Harness CLI")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("The command line for Harness — drive sessions, splits, and agents from anywhere.")
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 420)
            }

            Spacer(minLength: 20)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 12)
        .onAppear(perform: animateIn)
    }

    @ViewBuilder
    private var logo: some View {
        if let image = Self.logoImage() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: "app.connected.to.app.below.fill")
                .font(.system(size: 92, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }

    static func logoImage(bundle: Bundle = .main) -> NSImage? {
        if let url = bundle.url(forResource: "HarnessLogo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }

    private func animateIn() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.75, dampingFraction: 0.84).delay(0.12)) {
            appeared = true
        }
        playEntrySoundIfNeeded()
    }

    private func playEntrySoundIfNeeded() {
        guard !hasPlayedSound else { return }
        hasPlayedSound = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            NSSound(named: "Glass")?.play()
        }
    }
}
