import SwiftUI

/// A concise overview of what Kouen does before setup begins.
struct DiscoverStepView: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let points: [Point] = [
        Point(title: "Splits and layouts, built in", detail: "Make splits, move and resize panes, send keys, and capture output — straight from the command line."),
        Point(title: "Sessions you can name and reopen", detail: "Workspaces, sessions, tabs, and panes are real objects. List them, reopen them, script them."),
        Point(title: "Attach from anywhere", detail: "Render a session's full split layout in any terminal, even over SSH. Your work follows you."),
        Point(title: "Agents tell you when they need you", detail: "Kouen spots Claude Code, Codex, Cursor, and Gemini in your panes and pings you when one finishes or gets stuck."),
        Point(title: "Run Claude Code without opening a pane", detail: "kouen cc run \"prompt\" drives Claude Code headlessly and prints the result — no interactive session needed."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            StepIntro(
                eyebrow: "Overview",
                title: "The command line for a modern terminal.",
                bodyText: "Kouen gives your shells, tabs, panes, and coding agents one command layer — and you can reach it from anywhere."
            )

            VStack(spacing: 0) {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    QuietRow(title: point.title, detail: point.detail)
                        .padding(.vertical, 11)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared || reduceMotion ? 0 : 8)
                        .animation(reduceMotion ? .easeOut(duration: 0.18)
                                   : .spring(response: 0.48, dampingFraction: 0.86).delay(Double(index) * 0.05),
                                   value: appeared)
                    if index < points.count - 1 {
                        Rectangle().fill(.white.opacity(0.075)).frame(height: 1)
                    }
                }
            }
            .frame(maxWidth: 520)
        }
        .onAppear { appeared = true }
    }

    private struct Point: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }
}
