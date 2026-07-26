import AppKit
import SwiftUI
import KouenCore

// SwiftUI 5.1+ also exports `Tab` (TabView content). Disambiguate.
typealias Tab = KouenIPC.Tab

@MainActor
protocol TerminalTabBarDelegate: AnyObject {
    func tabBarDidSelect(tabID: TabID)
    func tabBarDidRequestNewTab()
    func tabBarDidRequestClose(tabID: TabID)
    func tabBarDidReorder(tabID: TabID, toIndex: Int)
    func tabBarDidRequestCloseOthers(tabID: TabID)
    func tabBarDidRequestRename(tabID: TabID)
    func tabBarDidRequestSplit(tabID: TabID, direction: SplitDirection)
    func tabBarDidRequestTogglePersistent(tabID: TabID)
}

extension TerminalTabBarDelegate {
    func tabBarDidRequestClose(tabID: TabID) {}
    func tabBarDidReorder(tabID: TabID, toIndex: Int) {}
    func tabBarDidRequestCloseOthers(tabID: TabID) {}
    func tabBarDidRequestRename(tabID: TabID) {}
    func tabBarDidRequestSplit(tabID: TabID, direction: SplitDirection) {}
    func tabBarDidRequestTogglePersistent(tabID: TabID) {}
}

enum TabContextCommand {
    case close
    case closeOthers
    case rename
    case splitHorizontal
    case splitVertical
    case togglePersistent
}

@MainActor
@Observable
private final class TerminalTabBarModel {
    var tabs: [Tab] = []
    var activeTabID: TabID?
    var leadingInset: CGFloat = 0
    var trailingInset: CGFloat = 0
    var chromeEpoch: Int = 0
    var draggingTabID: TabID?
    var dragOffsetX: CGFloat = 0
    var dragOriginalIndex: Int?
    var dragTargetIndex: Int?

    @ObservationIgnored weak var delegate: TerminalTabBarDelegate?
}

@MainActor
final class TerminalTabBarView: NSView {
    private let model: TerminalTabBarModel
    private let hostingView: NSHostingView<TerminalTabBarBody>

    weak var delegate: TerminalTabBarDelegate? {
        get { model.delegate }
        set { model.delegate = newValue }
    }

    var leadingInset: CGFloat {
        get { model.leadingInset }
        set { model.leadingInset = newValue }
    }

    var trailingInset: CGFloat {
        get { model.trailingInset }
        set { model.trailingInset = newValue }
    }

    override init(frame frameRect: NSRect) {
        let model = TerminalTabBarModel()
        self.model = model
        self.hostingView = NSHostingView(rootView: TerminalTabBarBody(model: model))
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override var mouseDownCanMoveWindow: Bool { true }

    func reload(tabs: [Tab], activeTabID: TabID?) {
        model.tabs = tabs
        model.activeTabID = activeTabID
        resetDrag()
    }

    func refreshMetadata(tabs: [Tab], activeTabID: TabID?) {
        let currentIDs = model.tabs.map(\.id)
        let newIDs = tabs.map(\.id)
        if currentIDs != newIDs {
            reload(tabs: tabs, activeTabID: activeTabID)
            return
        }

        guard !tabs.isStableEqual(to: model.tabs) || activeTabID != model.activeTabID else {
            return
        }

        model.tabs = tabs
        model.activeTabID = activeTabID
    }

    func applyChrome() {
        KouenDesign.applyTabBarChrome(to: self)
        model.chromeEpoch += 1
    }

    func setLeadingInset(_ inset: CGFloat) {
        leadingInset = inset
    }

    private func setup() {
        wantsLayer = true
        KouenDesign.applyTabBarChrome(to: self)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        let height = heightAnchor.constraint(equalToConstant: KouenDesign.tabBarHeight)
        height.priority = .defaultHigh

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            height,
        ])
    }

    private func resetDrag() {
        model.draggingTabID = nil
        model.dragOffsetX = 0
        model.dragOriginalIndex = nil
        model.dragTargetIndex = nil
    }
}

@MainActor
private struct TerminalTabBarBody: View {
    var model: TerminalTabBarModel

    private let edgeInset: CGFloat = 10
    private let buttonSize: CGFloat = 24
    private let minPillWidth: CGFloat = 72
    private let maxPillWidth: CGFloat = 200
    private let pillSpacing = KouenDesign.Spacing.xs

    var body: some View {
        GeometryReader { proxy in
            let _ = model.chromeEpoch
            let metrics = layoutMetrics(availableWidth: proxy.size.width)
            let visibleRange = metrics.visibleStart..<min(model.tabs.count, metrics.visibleStart + metrics.visibleCount)
            let overflowTabs = overflowTabs(visibleRange: visibleRange)

            HStack(spacing: pillSpacing) {
                Color.clear
                    .frame(width: edgeInset)

                ForEach(Array(visibleRange), id: \.self) { index in
                    let tab = model.tabs[index]
                    TabPillView(
                        model: model,
                        tab: tab,
                        isActive: tab.id == model.activeTabID,
                        position: shortcutPosition(for: index),
                        index: index,
                        visibleStart: metrics.visibleStart,
                        visibleCount: metrics.visibleCount,
                        pillWidth: metrics.pillWidth,
                        pitch: metrics.pitch
                    )
                    .frame(width: metrics.pillWidth, height: KouenDesign.tabPillHeight)
                    .offset(x: pillOffset(for: index, metrics: metrics))
                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.82), value: model.dragTargetIndex)
                    .zIndex(model.draggingTabID == tab.id ? 10 : 0)
                }

                Button {
                    model.delegate?.tabBarDidRequestNewTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: buttonSize, height: buttonSize)
                }
                .buttonStyle(TabBarIconButtonStyle())
                .help("New tab")

                if !overflowTabs.isEmpty {
                    Menu {
                        ForEach(overflowTabs, id: \.id) { tab in
                            Button {
                                model.delegate?.tabBarDidSelect(tabID: tab.id)
                            } label: {
                                Label {
                                    Text(tabDisplayTitle(tab))
                                } icon: {
                                    if tab.status == .waiting {
                                        Image(systemName: "bell.fill")
                                    } else if tab.persistent {
                                        Image(systemName: "pin.fill")
                                    } else {
                                        Image(systemName: "terminal")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(TabBarIconButtonStyle())
                    .help("More tabs")
                }

                Spacer(minLength: max(0, edgeInset + model.trailingInset))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            // Fill comes from the NSView-level ChromeBackdrop (KouenDesign.applyTabBarChrome,
            // installed on the parent TerminalTabBarView) — same mechanism as the title strip
            // and sidebar, so all chrome bars read as one consistent surface. This SwiftUI
            // layer must stay clear or it'd paint its own fill on top and defeat that.
            .background(Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(KouenDesign.chrome.border))
                    .frame(height: 1)
            }
        }
        .frame(height: KouenDesign.tabBarHeight)
    }

    private func layoutMetrics(availableWidth: CGFloat) -> TabBarLayoutMetrics {
        let count = model.tabs.count
        guard count > 0 else {
            return TabBarLayoutMetrics(pillWidth: minPillWidth, visibleStart: 0, visibleCount: 0)
        }

        let contentLeft = edgeInset + model.leadingInset
        let contentRight = edgeInset + model.trailingInset
        let allTabsWidth = availableWidth - contentLeft - contentRight - buttonSize - pillSpacing
        let allPillWidth = (allTabsWidth - pillSpacing * CGFloat(max(0, count - 1))) / CGFloat(count)

        if allPillWidth >= minPillWidth {
            return TabBarLayoutMetrics(
                pillWidth: min(maxPillWidth, allPillWidth),
                visibleStart: 0,
                visibleCount: count
            )
        }

        let overflowWidth = availableWidth - contentLeft - contentRight - buttonSize * 2 - pillSpacing * 2
        let visibleCount = min(count, max(1, Int((overflowWidth + pillSpacing) / (minPillWidth + pillSpacing))))
        let pillWidth = min(
            maxPillWidth,
            max(minPillWidth, (overflowWidth - pillSpacing * CGFloat(max(0, visibleCount - 1))) / CGFloat(visibleCount))
        )
        let activeIndex = model.activeTabID.flatMap { id in model.tabs.firstIndex(where: { $0.id == id }) } ?? 0
        let visibleStart = visibleWindowStart(activeIndex: activeIndex, visibleCount: visibleCount, tabCount: count)

        return TabBarLayoutMetrics(
            pillWidth: pillWidth,
            visibleStart: visibleStart,
            visibleCount: visibleCount
        )
    }

    private func visibleWindowStart(activeIndex: Int, visibleCount: Int, tabCount: Int) -> Int {
        guard tabCount > visibleCount else { return 0 }
        let halfWindow = visibleCount / 2
        let preferred = activeIndex - halfWindow
        return min(max(0, preferred), tabCount - visibleCount)
    }

    private func overflowTabs(visibleRange: Range<Int>) -> [Tab] {
        model.tabs.enumerated().compactMap { index, tab in
            visibleRange.contains(index) ? nil : tab
        }
    }

    private func shortcutPosition(for index: Int) -> Int? {
        let position = index + 1
        return position >= 1 && position <= 9 ? position : nil
    }

    private func pillOffset(for index: Int, metrics: TabBarLayoutMetrics) -> CGFloat {
        guard let draggingID = model.draggingTabID,
              let original = model.dragOriginalIndex,
              let target = model.dragTargetIndex
        else { return 0 }

        if model.tabs[index].id == draggingID {
            return model.dragOffsetX
        }

        guard index >= metrics.visibleStart, index < metrics.visibleStart + metrics.visibleCount else {
            return 0
        }

        if target > original, index > original, index <= target {
            return -metrics.pitch
        }
        if target < original, index >= target, index < original {
            return metrics.pitch
        }
        return 0
    }
}

@MainActor
private struct TabPillView: View {
    var model: TerminalTabBarModel
    let tab: Tab
    let isActive: Bool
    let position: Int?
    let index: Int
    let visibleStart: Int
    let visibleCount: Int
    let pillWidth: CGFloat
    let pitch: CGFloat

    @State private var isHovered = false
    @State private var showsMCPBadge = false

    var body: some View {
        let _ = model.chromeEpoch
        let c = KouenDesign.chrome
        let foreground = isActive || isHovered ? c.textPrimary : c.textSecondary
        let branch = tab.gitBranch?.isEmpty == false ? tab.gitBranch : nil

        HStack(spacing: KouenDesign.Spacing.xs) {
            workingDot

            if let kind = tab.effectiveAgentKind {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: AgentIconRenderer.templateOrMonogramImage(for: kind, size: 12))
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(agentColor(for: kind))
                        .frame(width: 12, height: 12)

                    if let subagents = tab.subagents, !subagents.isEmpty {
                        Text("+\(subagents.count)")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 2)
                            .background(Circle().fill(Color(c.accent)))
                            .offset(x: 4, y: 3)
                    }
                }
                .help(subagentTooltip(kind: kind, subagents: tab.subagents ?? []))
            }

            VStack(alignment: .leading, spacing: -1) {
                Text(tabDisplayTitle(tab))
                    .font(.system(size: 12, weight: branch == nil ? .medium : .semibold))
                    .foregroundStyle(Color(foreground))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let branch {
                    Text("⎇ \(branch)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(c.textTertiary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if showsMCPBadge {
                Text("MCP")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color(c.accent))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: KouenDesign.Radius.badge, style: .continuous)
                            .fill(Color(c.accent).opacity(c.isDark ? 0.16 : 0.12))
                    )
            }

            Circle()
                .fill(Color(statusColor(for: tab.status)))
                .frame(width: 6, height: 6)
                .help(statusHelp(for: tab.status))

            if tab.persistent {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color(c.accent))
                    .help("Kept running after quit")
            }

            if isHovered {
                Button {
                    model.delegate?.tabBarDidRequestClose(tabID: tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(TabBarInlineIconButtonStyle())
                .help("Close tab")
            } else if let position {
                Text("⌘\(position)")
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(isActive ? c.textSecondary : c.textTertiary))
                    .frame(width: 22, alignment: .trailing)
            }
        }
        .padding(.horizontal, KouenDesign.Spacing.sm)
        .frame(height: KouenDesign.tabPillHeight)
        .background(pillBackground)
        .overlay(pillBorder)
        .shadow(
            color: isActive ? Color.black.opacity(c.isDark ? 0.20 : 0.10) : .clear,
            radius: isActive ? 3 : 0,
            x: 0,
            y: isActive ? 1 : 0
        )
        .contentShape(RoundedRectangle(cornerRadius: KouenDesign.Radius.card, style: .continuous))
        .onHover { hovered in
            isHovered = hovered
        }
        .onTapGesture(count: 2) {
            model.delegate?.tabBarDidRequestRename(tabID: tab.id)
        }
        // simultaneousGesture fires immediately on any tap without waiting for the
        // double-click disambiguation window (~300 ms delay that onTapGesture(count:1) adds).
        .simultaneousGesture(TapGesture().onEnded {
            model.delegate?.tabBarDidSelect(tabID: tab.id)
        })
        .contextMenu {
            Button("Close Tab") {
                model.delegate?.tabBarDidRequestClose(tabID: tab.id)
            }
            Button("Close Other Tabs") {
                model.delegate?.tabBarDidRequestCloseOthers(tabID: tab.id)
            }
            Divider()
            Button("Rename…") {
                model.delegate?.tabBarDidRequestRename(tabID: tab.id)
            }
            Divider()
            Button {
                model.delegate?.tabBarDidRequestTogglePersistent(tabID: tab.id)
            } label: {
                if tab.persistent {
                        Label("Keep Tab Running After Quit", systemImage: "checkmark")
                    } else {
                        Text("Keep Tab Running After Quit")
                    }
            }
            Divider()
            Button("Split Right") {
                model.delegate?.tabBarDidRequestSplit(tabID: tab.id, direction: .vertical)
            }
            Button("Split Down") {
                model.delegate?.tabBarDidRequestSplit(tabID: tab.id, direction: .horizontal)
            }
        }
        .gesture(dragGesture)
        .task(id: tab.lastMCPControlAt) {
            await updateMCPBadge(lastAt: tab.lastMCPControlAt)
        }
    }

    private var workingDot: some View {
        // Pulse runs on the render server via CABasicAnimation, NOT SwiftUI. A SwiftUI
        // .repeatForever here keeps the whole NSHostingView ViewGraph re-rendering every
        // frame (profiled build 183: ~33% CPU in ViewGraph.updateOutputs while any tab is
        // working). CALayer animates off the ViewGraph. See knowledge/bugs/notch-cpu-animation.md.
        WorkingDotView(isWorking: tab.agent != nil && tab.status == .running,
                       color: KouenDesign.chrome.textSecondary)
            .frame(width: 2, height: 2)
    }

    private var pillBackground: some View {
        let c = KouenDesign.chrome
        return RoundedRectangle(cornerRadius: KouenDesign.Radius.card, style: .continuous)
            .fill(backgroundColor(chrome: c))
    }

    private var pillBorder: some View {
        RoundedRectangle(cornerRadius: KouenDesign.Radius.card, style: .continuous)
            .stroke(isActive ? Color(KouenDesign.chrome.focusRing).opacity(0.48) : .clear, lineWidth: 1)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if model.draggingTabID == nil {
                    model.draggingTabID = tab.id
                    model.dragOriginalIndex = index
                    model.dragTargetIndex = index
                }

                guard model.draggingTabID == tab.id else { return }

                model.dragOffsetX = value.translation.width
                let leadingX = CGFloat(index - visibleStart) * pitch
                let dragX = leadingX + value.translation.width
                let globalTarget = Int((dragX / max(1, pitch)).rounded()) + visibleStart
                model.dragTargetIndex = clamp(globalTarget, lower: 0, upper: max(0, model.tabs.count - 1))
            }
            .onEnded { _ in
                defer {
                    model.draggingTabID = nil
                    model.dragOffsetX = 0
                    model.dragOriginalIndex = nil
                    model.dragTargetIndex = nil
                }

                guard model.draggingTabID == tab.id,
                      let original = model.dragOriginalIndex,
                      let target = model.dragTargetIndex,
                      original != target
                else { return }

                model.delegate?.tabBarDidReorder(tabID: tab.id, toIndex: target)
            }
    }

    private func backgroundColor(chrome c: KouenChromePalette) -> Color {
        if isHovered {
            return Color(c.rowHoverFill)
        }
        return .clear
    }

    private func updateMCPBadge(lastAt: Date?) async {
        guard let lastAt else {
            showsMCPBadge = false
            return
        }

        let elapsed = Date().timeIntervalSince(lastAt)
        guard elapsed < 5 else {
            showsMCPBadge = false
            return
        }

        showsMCPBadge = true
        let remaining = max(0, 5 - elapsed)
        do {
            try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        } catch {
            return
        }
        showsMCPBadge = false
    }

    private func agentColor(for kind: AgentKind) -> Color {
        Color(nsColor: NSColor.fromHex(SessionCoordinator.shared.settings.agentColorHex(for: kind)) ?? KouenDesign.chrome.textSecondary)
    }

    /// P38 Phase B: presence/kind/age only — the shared PTY makes attributing output bytes to
    /// a specific subagent impossible, so this deliberately doesn't claim activity state.
    private func subagentTooltip(kind: AgentKind, subagents: [AgentSnapshot]) -> String {
        guard !subagents.isEmpty else { return kind.displayName }
        let lines = subagents.map { sub -> String in
            let source = sub.pid == 0 ? "hook" : "pid \(sub.pid)"
            let elapsed = Int(Date().timeIntervalSince(sub.lastActivityAt))
            return "\(sub.kind.displayName) (\(source), \(elapsed)s)"
        }
        return ([kind.displayName] + lines).joined(separator: "\n")
    }
}

@MainActor
private struct TabBarLayoutMetrics {
    let pillWidth: CGFloat
    let visibleStart: Int
    let visibleCount: Int

    var pitch: CGFloat {
        pillWidth + KouenDesign.Spacing.xs
    }
}

@MainActor
private struct TabBarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(KouenDesign.chrome.textSecondary))
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color(KouenDesign.chrome.iconHoverFill).opacity(0.85) : Color.clear)
            )
            .contentShape(Circle())
    }
}

@MainActor
private struct TabBarInlineIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(KouenDesign.chrome.textSecondary))
            .background(
                RoundedRectangle(cornerRadius: KouenDesign.Radius.badge, style: .continuous)
                    .fill(configuration.isPressed ? Color(KouenDesign.chrome.iconHoverFill) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: KouenDesign.Radius.badge, style: .continuous))
    }
}

@MainActor
private func tabDisplayTitle(_ tab: Tab) -> String {
    let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !title.isEmpty {
        return title
    }

    let leaf = (tab.cwd as NSString).lastPathComponent
    return leaf.isEmpty ? tab.cwd : leaf
}

@MainActor
private func statusColor(for status: TabStatus) -> NSColor {
    switch status {
    case .idle:
        return BoardColumnKind.idle.color
    case .waiting:
        return BoardColumnKind.needsAttention.color
    case .running:
        return BoardColumnKind.running.color
    case .done:
        return BoardColumnKind.done.color
    case .error:
        return BoardColumnKind.error.color
    }
}

private func statusHelp(for status: TabStatus) -> String {
    switch status {
    case .idle:
        return "Idle"
    case .waiting:
        return "Waiting"
    case .running:
        return "Running"
    case .done:
        return "Done"
    case .error:
        return "Error"
    }
}

private func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
    min(max(value, lower), upper)
}

/// A 2pt "working" dot whose horizontal pulse runs as a `CABasicAnimation` on the render
/// server instead of a SwiftUI `.repeatForever`. The SwiftUI version kept the entire
/// `NSHostingView(rootView: TerminalTabBarBody)` ViewGraph re-rendering every display frame
/// (profiled: ~33% CPU). A CALayer animation is invisible to the ViewGraph: layout once,
/// GPU paints. See knowledge/bugs/notch-cpu-animation.md (Instance 2).
private struct WorkingDotView: NSViewRepresentable {
    let isWorking: Bool
    let color: NSColor

    func makeNSView(context: Context) -> DotView { DotView() }

    func updateNSView(_ view: DotView, context: Context) {
        view.apply(isWorking: isWorking, color: color)
    }

    final class DotView: NSView {
        private static let animationKey = "working-pulse"
        private let dot = CALayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.masksToBounds = false   // pulse travels ±2.5pt outside the 2pt footprint
            dot.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
            layer?.addSublayer(dot)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func apply(isWorking: Bool, color: NSColor) {
            dot.backgroundColor = color.cgColor
            dot.isHidden = !isWorking
            let animate = isWorking && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            guard animate else {
                dot.removeAnimation(forKey: Self.animationKey)
                return
            }
            guard dot.animation(forKey: Self.animationKey) == nil else { return }
            let pulse = CABasicAnimation(keyPath: "transform.translation.x")
            pulse.fromValue = -2.5
            pulse.toValue = 2.5
            pulse.duration = 1.2
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dot.add(pulse, forKey: Self.animationKey)
        }
    }
}
