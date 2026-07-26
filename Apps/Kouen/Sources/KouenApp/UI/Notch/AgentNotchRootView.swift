import AppKit
import KouenCore
import SwiftUI

struct AgentNotchRootView: View {
    @ObservedObject var model: AgentNotchViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var shellBackground: Color {
        let opacity = KouenChrome.backgroundOpacity
        if opacity < 0.999 {
            return Color(KouenChrome.current.terminalBackground.withAlphaComponent(max(0.65, opacity * 0.85)))
        } else {
            return Color.black
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            shell
                .frame(width: currentWidth, height: currentHeight, alignment: .top)
                .background(shellBackground)
                .clipShape(NotchShape(topRadius: topRadius, bottomRadius: bottomRadius))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(shellBackground)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                // Closed state: only the inner ~3/4 of the pill is hover/click-sensitive, so
                // a fly-by across the menu bar (or a fling to the top edge) never triggers
                // the HUD. Peek/open keep the whole card interactive.
                .contentShape(HorizontalInsetRect(inset: hotZoneInset))
                .onHover { model.handleHover($0) }
                .onTapGesture {
                    if !model.isOpen { model.open() }
                }
                .accessibilityElement(children: .contain)
        }
        .frame(
            width: CGFloat(model.geometry.panelFrame.width),
            height: CGFloat(model.geometry.panelFrame.height),
            alignment: .top
        )
    }

    /// Presentation switch with staggered transitions: the shape (frame/radii, animated by
    /// the model's springs) leads; incoming content fades and settles in just after, and
    /// outgoing content drops away fast — no hard swap.
    @ViewBuilder
    private var shell: some View {
        switch model.presentation {
        case .closed:
            closedView
                .transition(closedTransition)
        case let .peek(event):
            peekView(event)
                .transition(expandedContentTransition)
        case .open:
            openView
                .transition(expandedContentTransition)
        }
    }

    // MARK: - Closed

    private var closedView: some View {
        HStack(spacing: 5) {
            Image(systemName: model.waitingCount > 0 ? "sparkles" : "terminal")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(model.waitingCount > 0 ? Color.orange : Color.white.opacity(0.72))
            agentDots(limit: 4)
            if model.waitingCount > 0 {
                Text("\(model.waitingCount)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.88), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(closedAccessibilityLabel)
    }

    // MARK: - Peek

    /// Transient one-row live activity: dot + agent + one-line reason. Clicking jumps to
    /// the tab; hovering holds it (and promotes to the full HUD after the dwell).
    private func peekView(_ event: AgentNotchPeekEvent) -> some View {
        Button {
            model.openRow(event.row)
        } label: {
            HStack(spacing: 8) {
                statusDot(
                    kind: event.row.agentKind,
                    waiting: event.reason == .needsInput,
                    working: event.row.agentActivity == .working
                )
                VStack(alignment: .leading, spacing: 0) {
                    Text(peekTitle(event))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(peekReason(event))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(peekReasonColor(event.reason))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, CGFloat(model.geometry.hasPhysicalNotch ? model.geometry.closedHeight - 22 : 4))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(peekTitle(event)), \(peekReason(event))")
    }

    private func peekTitle(_ event: AgentNotchPeekEvent) -> String {
        event.row.agentKind?.displayName ?? event.row.title
    }

    private func peekReason(_ event: AgentNotchPeekEvent) -> String {
        switch event.reason {
        case .needsInput:
            return event.row.notificationText ?? "needs your input"
        case .errored:
            return "hit an error"
        case .finished:
            return "finished"
        }
    }

    private func peekReasonColor(_ reason: AgentNotchPeekEvent.Reason) -> Color {
        switch reason {
        case .needsInput: return .orange
        case .errored: return Color(red: 1.0, green: 0.42, blue: 0.40)
        case .finished: return Color(red: 0.42, green: 0.85, blue: 0.50)
        }
    }

    // MARK: - Open

    private var openView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if model.visibleRows.isEmpty {
                emptyState
            } else {
                rowList
            }
        }
        .padding(.horizontal, 13)
        .padding(.top, 9)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityLabel("Kouen Agent Notch")
    }

    private var rowList: some View {
        // Periodic tick only while open, so the relative timestamps ("2m") stay honest
        // without any timer running while the notch is closed.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(model.visibleRows) { row in
                        NotchOverviewRow(
                            row: row,
                            progressPercent: model.rowProgress[row.id],
                            now: context.date,
                            dot: AnyView(statusDot(
                                kind: row.agentKind,
                                waiting: row.waitingCount > 0,
                                working: row.agentActivity == .working
                            )),
                            reduceTransparency: reduceTransparency,
                            onApprove: row.surfaceID != nil ? { model.decideRow(row, approve: true) } : nil,
                            onDeny: row.surfaceID != nil ? { model.decideRow(row, approve: false) } : nil,
                            onReply: row.surfaceID != nil ? { text in model.replyToRow(row, text: text) } : nil
                        ) {
                            model.openRow(row)
                        }
                    }
                    if model.hasOverflowRows {
                        Text("More sessions available in the main window")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.44))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 1)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 3) {
            Text("No active sessions")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text("Agents and sessions appear here as they run")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Kouen Agents")
                    .font(.system(size: 12.5, weight: .semibold))
                Text(model.headerSummary)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Spacer()
            if model.waitingCount > 0 {
                chip("\(model.waitingCount) waiting", color: .orange)
            }
            if model.workingCount > 0 {
                chip("\(model.workingCount) working", color: .green)
            }
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.32), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
    }

    private func agentDots(limit: Int) -> some View {
        HStack(spacing: -2) {
            ForEach(Array(model.agents.prefix(limit).enumerated()), id: \.element.id) { _, agent in
                statusDot(kind: agent.kind, waiting: agent.waiting, working: agent.activity == .working)
                    .overlay(Circle().stroke(Color.black, lineWidth: 1))
            }
        }
        .accessibilityHidden(true)
    }

    private func statusDot(kind: AgentKind?, waiting: Bool, working: Bool) -> some View {
        NotchStatusDot(
            chip: kind?.chip,
            color: dotColor(kind: kind, waiting: waiting),
            working: working,
            waiting: waiting,
            reduceMotion: reduceMotion
        )
    }

    private func dotColor(kind: AgentKind?, waiting: Bool) -> Color {
        if waiting { return .orange }
        guard let kind else { return Color.white.opacity(0.36) }
        let hex = SessionCoordinator.shared.settings.agentColorHex(for: kind)
        return Color(nsColor: NSColor.fromHex(hex) ?? .secondaryLabelColor)
    }

    // MARK: - Geometry

    private var currentWidth: CGFloat {
        switch model.presentation {
        case .closed:
            return CGFloat(model.geometry.closedWidth)
        case .peek:
            return CGFloat(model.geometry.peekWidth)
        case .open:
            return CGFloat(model.geometry.openWidth)
        }
    }

    private var currentHeight: CGFloat {
        switch model.presentation {
        case .closed:
            return CGFloat(model.geometry.closedHeight)
        case .peek:
            return CGFloat(model.geometry.peekHeight)
        case .open:
            return model.openContentHeight
        }
    }

    private var topRadius: CGFloat {
        model.geometry.hasPhysicalNotch ? 2 : 9
    }

    private var bottomRadius: CGFloat {
        switch model.presentation {
        case .closed:
            return model.geometry.hasPhysicalNotch ? 14 : 15
        case .peek:
            return 18
        case .open:
            return 22
        }
    }

    /// Closed-state hover/click hot zone shrinks 24 pt per side (accidental-trigger fix);
    /// peek/open stay fully interactive.
    private var hotZoneInset: CGFloat {
        if case .closed = model.presentation { return 24 }
        return 0
    }

    private var closedTransition: AnyTransition {
        .opacity.animation(.easeOut(duration: reduceMotion ? 0.08 : 0.14))
    }

    /// Incoming expanded content fades in and settles upward just after the shape starts
    /// growing (skill: shape leads by 40–90 ms); outgoing content drops away fast.
    private var expandedContentTransition: AnyTransition {
        if reduceMotion {
            return .opacity.animation(.easeOut(duration: 0.10))
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8))
                .animation(.easeOut(duration: 0.20).delay(0.06)),
            removal: .opacity.animation(.easeIn(duration: 0.10))
        )
    }

    private var closedAccessibilityLabel: String {
        if model.waitingCount > 0 {
            return "Kouen Agent Notch, \(model.waitingCount) agents waiting"
        }
        return "Kouen Agent Notch, \(model.agents.count) agents"
    }
}

/// Hit-test shape for the notch shell: the full rect inset horizontally. Used to shrink the
/// closed pill's hover/click target without changing its visual size.
private struct HorizontalInsetRect: Shape {
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: inset, dy: 0))
    }
}

/// One open-state row: dot · title + subtitle · progress/badge · relative time. Hover
/// brightens, press compresses — the row should feel like a control, not a label.
private struct NotchOverviewRow: View {
    let row: AgentNotchRowSummary
    let progressPercent: Int?
    let now: Date
    let dot: AnyView
    let reduceTransparency: Bool
    /// Non-nil only when the row is waiting AND has a resolvable surface — resolve the
    /// prompt right here instead of the usual "needs input" badge.
    let onApprove: (() -> Void)?
    let onDeny: (() -> Void)?
    let onReply: ((String) -> Void)?
    let action: () -> Void

    @State private var hovering = false
    @State private var isReplying = false
    @State private var replyText = ""
    @FocusState private var replyFieldFocused: Bool

    private var showsApprovalControls: Bool {
        row.waitingCount > 0 && onApprove != nil && onDeny != nil
    }

    var body: some View {
        if isReplying {
            replyEditor
        } else {
            openableRow
        }
    }

    /// Free-text quick-reply, swapped in for the whole row (not nested inside the row's
    /// `Button`) — a `TextField` inside a `Button`'s label doesn't reliably take keyboard
    /// focus/clicks in SwiftUI, since the outer button intercepts the interaction. Branching
    /// at the top level instead of nesting sidesteps that entirely.
    private var replyEditor: some View {
        HStack(spacing: 6) {
            TextField("Reply…", text: $replyText)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .focused($replyFieldFocused)
                .onSubmit(submitReply)
            Button("Send", action: submitReply)
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(red: 0.30, green: 0.68, blue: 0.42), in: Capsule())
            Button("Cancel") { isReplying = false; replyText = "" }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(height: 38)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .task { replyFieldFocused = true }
    }

    private func submitReply() {
        let text = replyText
        isReplying = false
        replyText = ""
        onReply?(text)
    }

    private var openableRow: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                dot
                VStack(alignment: .leading, spacing: 1) {
                    Text(title.isEmpty ? "Terminal" : title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if showsApprovalControls {
                    approvalControls
                } else {
                    if let relative = relativeTime {
                        Text(relative)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                    if let badge {
                        Text(badge.text)
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(badge.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(badge.color.opacity(0.16), in: Capsule())
                    }
                }
            }
            .frame(height: 38)
            .padding(.horizontal, 8)
            .background(background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(alignment: .bottomLeading) { progressUnderline }
        }
        .buttonStyle(NotchRowButtonStyle())
        .onHover { hovering = $0 }
        .accessibilityLabel("\(title), \(subtitle)")
    }

    /// Deliberately plain `Button`s (not `NotchRowButtonStyle`) nested inside the row's own
    /// button — SwiftUI resolves the innermost control on tap, so Allow/Deny consume the tap
    /// before it reaches `action` (open row) underneath. No `.simultaneousGesture` trick
    /// needed since these aren't overlapping the same hit area, just adjacent in the HStack.
    private var approvalControls: some View {
        HStack(spacing: 6) {
            if onReply != nil {
                Button("Reply", action: { isReplying = true })
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.10), in: Capsule())
            }
            Button("Deny", action: { onDeny?() })
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.10), in: Capsule())
            Button("Allow", action: { onApprove?() })
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(red: 0.30, green: 0.68, blue: 0.42), in: Capsule())
        }
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        guard let agentName = row.agentKind?.displayName else { return row.title }
        let source = row.title.isEmpty ? row.sessionName : row.title
        guard !source.isEmpty, source != agentName else { return agentName }
        return "\(agentName) · \(source)"
    }

    private var subtitle: String {
        // A blocked agent's notification body is the densest thing we can show.
        if row.waitingCount > 0, let text = row.notificationText, !text.isEmpty {
            return text
        }
        return row.detail
    }

    private var subtitleColor: Color {
        row.waitingCount > 0 && row.notificationText != nil
            ? Color.orange.opacity(0.92)
            : Color.white.opacity(0.54)
    }

    private var relativeTime: String? {
        guard let date = row.lastActivityAt else { return nil }
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3_600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3_600))h" }
        return "\(Int(seconds / 86_400))d"
    }

    private var badge: (text: String, color: Color)? {
        if row.waitingCount > 0 {
            return (row.waitingCount == 1 ? "needs input" : "\(row.waitingCount) need input", .orange)
        }
        if row.agentActivity == .errored {
            return ("error", Color(red: 1.0, green: 0.45, blue: 0.42))
        }
        if row.agentActivity == .working {
            if let percent = progressPercent {
                return ("\(percent)%", Color(red: 0.42, green: 0.85, blue: 0.50))
            }
            return ("working", Color(red: 0.42, green: 0.85, blue: 0.50))
        }
        if row.rowKind == .session, row.tabCount > 1 {
            return ("\(row.tabCount) tabs", .white.opacity(0.7))
        }
        return nil
    }

    /// 2 pt determinate progress bar pinned to the row's bottom edge (OSC 9;4 `set`).
    @ViewBuilder
    private var progressUnderline: some View {
        if let percent = progressPercent, row.agentActivity == .working {
            GeometryReader { proxy in
                Capsule()
                    .fill(Color(red: 0.42, green: 0.85, blue: 0.50).opacity(0.85))
                    .frame(width: max(6, proxy.size.width * CGFloat(percent) / 100), height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 2)
            }
            .padding(.horizontal, 10)
            .allowsHitTesting(false)
        }
    }

    private var background: Color {
        let base = reduceTransparency ? 0.13 : 0.08
        return Color.white.opacity(hovering ? base + 0.06 : base)
    }
}

/// Press feedback: gentle compression, no color flash.
private struct NotchRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A notch status dot that gently breathes while its agent is working (honoring Reduce Motion),
/// and is a calm static dot otherwise. The breathing is the closed-view "agent is still working"
/// signal that pairs with the red waiting badge.
private struct NotchStatusDot: View {
    let chip: String?
    let color: Color
    let working: Bool
    let waiting: Bool
    let reduceMotion: Bool

    var body: some View {
        // Breathing runs as a CALayer animation on the render server, not a SwiftUI
        // .repeatForever — the latter keeps the notch's NSHostingView ViewGraph re-rendering
        // every frame while an agent works (same CPU class as TerminalTabBarView.workingDot;
        // see knowledge/bugs/notch-cpu-animation.md). The chip/circle still render in SwiftUI;
        // only the scale+opacity pulse is moved off the ViewGraph.
        NotchPulseHost(animates: working && !reduceMotion) {
            Group {
                if let chip {
                    Text(chip)
                        .font(.system(size: 6, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 13, height: 9)
                        .background(color, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
            }
            .shadow(color: color.opacity(waiting ? 0.6 : 0.25), radius: waiting ? 4 : 1.5)
        }
        .frame(width: chip != nil ? 13 : 6, height: chip != nil ? 9 : 6)
    }
}

private let notchBreatheAnimationKey = "notch-breathe"

/// Hosts SwiftUI content in a layer-backed view and breathes it (scale + opacity) via a
/// repeating `CAAnimationGroup`. Moving the loop off SwiftUI stops the per-frame ViewGraph
/// re-render that a `.repeatForever` would otherwise force on the whole NSHostingView.
private struct NotchPulseHost<Content: View>: NSViewRepresentable {
    let animates: Bool
    @ViewBuilder var content: Content

    func makeNSView(context: Context) -> Container { Container() }

    func updateNSView(_ view: Container, context: Context) {
        view.set(content: content, animates: animates)
    }

    final class Container: NSView {
        private var hosting: NSHostingView<Content>?
        private var animates = false

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.masksToBounds = false   // breathing scale + shadow draw past the dot bounds
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func set(content: Content, animates: Bool) {
            if let hosting {
                hosting.rootView = content
            } else {
                let host = NSHostingView(rootView: content)
                addSubview(host)
                hosting = host
            }
            self.animates = animates
            needsLayout = true
            applyPulse()
        }

        override func layout() {
            super.layout()
            guard let host = hosting else { return }
            host.frame = bounds
            // Anchor at center so the scale pulse breathes in place instead of drifting.
            if let hostLayer = host.layer {
                hostLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                hostLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            }
            applyPulse()   // layer may not have existed at makeNSView time
        }

        private func applyPulse() {
            guard let hostLayer = hosting?.layer else { return }
            guard animates else {
                hostLayer.removeAnimation(forKey: notchBreatheAnimationKey)
                return
            }
            guard hostLayer.animation(forKey: notchBreatheAnimationKey) == nil else { return }
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1.0
            scale.toValue = 1.18
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 1.0
            opacity.toValue = 0.62
            let group = CAAnimationGroup()
            group.animations = [scale, opacity]
            group.duration = 0.9
            group.autoreverses = true
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            hostLayer.add(group, forKey: notchBreatheAnimationKey)
        }
    }
}
