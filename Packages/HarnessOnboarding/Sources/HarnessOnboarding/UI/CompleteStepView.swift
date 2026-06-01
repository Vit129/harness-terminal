import SwiftUI
import AppKit

/// Final ready state. Clean text, a few practical commands, and one in-app handoff.
struct CompleteStepView: View {
    let onOpenDemo: () -> Void

    @State private var appeared = false
    @State private var hasPlayedSound = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 26) {
            StepIntro(
                eyebrow: "Ready",
                title: "You are set.",
                bodyText: "Harness is ready. The CLI is installed, your shell can find it, and the daemon is running in the background."
            )

            VStack(spacing: 12) {
                CommandRow("harness-cli ping", "Check the daemon")
                CommandRow("harness-cli list-surfaces", "List your sessions")
                CommandRow("harness-cli attach-window --tab <id>", "Attach to a tab")
            }
            .frame(maxWidth: 420)

            Button(action: onOpenDemo) {
                Text("Open Harness")
                    .frame(width: 200)
            }
            .buttonStyle(GlassPrimaryButtonStyle())
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 10)
        .onAppear(perform: celebrate)
    }

    private func celebrate() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.82)) {
            appeared = true
        }
        guard !hasPlayedSound else { return }
        hasPlayedSound = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            NSSound(named: "Glass")?.play()
        }
    }
}
