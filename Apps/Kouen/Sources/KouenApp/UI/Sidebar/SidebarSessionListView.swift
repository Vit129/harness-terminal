import SwiftUI
import KouenCore

// MARK: - Main container

struct SidebarSessionListView: View {
    var model: SidebarListModel
    var onSelect: (SessionID) -> Void
    var onAddInGroup: (String) -> Void
    var onCloseSession: (SessionID) -> Void
    var onPRClick: (String) -> Void
    var onWorktreeActivate: (SidebarWorktreeEntry, WorkspaceID?) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(model.rows) { row in
                    rowContent(row)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func rowContent(_ row: SidebarSessionRow) -> some View {
        switch row {
        case let .groupHeader(name, rootPath, count, isCollapsed, status):
            SidebarGroupHeaderRow(
                name: name,
                rootPath: rootPath,
                count: count,
                isCollapsed: isCollapsed,
                status: status,
                model: model,
                onToggleCollapse: { model.toggleCollapse(rootPath: rootPath) },
                onAdd: { onAddInGroup(rootPath) }
            )
            .frame(height: 28)

        case let .session(session):
            SidebarSessionItemRow(
                session: session,
                isSelected: session.id == model.activeSessionID,
                metadata: {
                    let tab = session.activeTab ?? session.tabs.first
                    let branch = tab?.gitBranch?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let cwd = tab?.cwd ?? ""
                    return model.gitMetadata(forPath: cwd, branch: branch)
                }(),
                model: model,
                onSelect: { onSelect(session.id) },
                onClose: { onCloseSession(session.id) },
                onPRClick: onPRClick
            )
            .frame(height: 40)

        case let .worktreeHeader(rootPath, count, isCollapsed):
            SidebarWorktreeHeaderRow(
                count: count,
                isCollapsed: isCollapsed,
                onToggleCollapse: { model.toggleWorktreeCollapse(rootPath: rootPath) }
            )
            .frame(height: 24)

        case let .worktree(entry, _):
            SidebarWorktreeItemRow(
                entry: entry,
                metadata: model.gitMetadata(forPath: entry.path, branch: entry.branch),
                onActivate: { onWorktreeActivate(entry, model.activeWorkspaceID) }
            )
            .frame(height: 40)

        case .divider:
            SidebarDividerRow()
                .frame(height: 10)
        }
    }
}

// MARK: - Group header row

private struct SidebarGroupHeaderRow: View {
    let name: String
    let rootPath: String
    let count: Int
    let isCollapsed: Bool
    let status: BoardColumnKind
    var model: SidebarListModel
    var onToggleCollapse: () -> Void
    var onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        let c = KouenDesign.chrome
        HStack(spacing: 6) {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(isHovered
                    ? Color(nsColor: c.textPrimary)
                    : Color(nsColor: c.textSecondary))
                .frame(width: 10, height: 10)

            Text(name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(nsColor: c.textPrimary))
                .lineLimit(1)
                .truncationMode(.tail)

            Circle()
                .fill(Color(nsColor: status.color))
                .frame(width: 6, height: 6)

            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovered
                    ? Color(nsColor: c.textSecondary)
                    : Color(nsColor: c.textTertiary))

            Spacer()

            if isHovered {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: c.textSecondary))
                }
                .buttonStyle(.plain)
                .frame(width: 20, height: 20)
                .help("New session in group")

                Menu {
                    let isPinned = model.pinnedRepos.contains(rootPath)
                    Button(isPinned ? "Unpin Repo" : "Pin Repo") {
                        model.togglePinRepo(rootPath: rootPath)
                    }
                    Divider()
                    Button("Close all sessions in \(name)", role: .destructive) {
                        closeAllSessions(name: name)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(nsColor: c.textSecondary))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20, height: 20)
                .help("Group options")
            }
        }
        .padding(.horizontal, KouenDesign.horizontalInset)
        .contentShape(Rectangle())
        .onTapGesture { onToggleCollapse() }
        .onHover { isHovered = $0 }
        .contextMenu {
            let isPinned = model.pinnedRepos.contains(rootPath)
            Button(isPinned ? "Unpin Repo" : "Pin Repo") {
                model.togglePinRepo(rootPath: rootPath)
            }
            Divider()
            Button("Close all sessions in \(name)", role: .destructive) {
                closeAllSessions(name: name)
            }
        }
    }

    private func closeAllSessions(name: String) {
        let groupSessions = model.sessions.filter { model.repoRootForSession($0) == rootPath }
        guard !groupSessions.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Close all sessions in \(name)?"
        alert.informativeText = "This will close \(groupSessions.count) session\(groupSessions.count == 1 ? "" : "s") and all their tabs."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close All")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = ""
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for session in groupSessions {
            SessionCoordinator.shared.closeSession(session)
        }
        SessionCoordinator.shared.syncFromDaemon()
    }

}

// MARK: - Session card row

private struct SidebarSessionItemRow: View {
    let session: SessionGroup
    let isSelected: Bool
    let metadata: RepoGitMetadata?
    var model: SidebarListModel
    var onSelect: () -> Void
    var onClose: () -> Void
    var onPRClick: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        let c = KouenDesign.chrome
        let tab = session.activeTab ?? session.tabs.first
        let branch = tab?.gitBranch?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cwd = tab?.cwd ?? ""
        let sessionTitle = session.name.isEmpty ? KouenDesign.pathDisplayName(cwd) : session.name
        let displayTitle = tab?.taskName ?? (branch.isEmpty ? sessionTitle : branch)
        let subtitle = KouenDesign.shortenPath(cwd)

        let selectedFill = Color(nsColor: c.accent).opacity(c.isDark ? 0.13 : 0.10)
        let selectedBorder = Color(nsColor: c.focusRing).opacity(c.isDark ? 0.48 : 0.52)
        let fillColor = isSelected ? selectedFill : (isHovered ? Color(nsColor: c.rowHoverFill) : Color.clear)
        let borderColor = isSelected ? selectedBorder : Color.clear

        ZStack {
            RoundedRectangle(cornerRadius: KouenDesign.Radius.card, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: KouenDesign.Radius.card, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )

            HStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let kind = tab?.effectiveAgentKind {
                            Image(nsImage: AgentIconRenderer.templateOrMonogramImage(for: kind, size: 12))
                                .resizable()
                                .renderingMode(.template)
                                .foregroundStyle(agentColor(for: kind))
                        } else {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(nsColor: c.textSecondary))
                        }
                    }
                    .frame(width: 12, height: 12)

                    if let subagents = tab?.subagents, !subagents.isEmpty {
                        Text("+\(subagents.count)")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(1)
                            .background(Circle().fill(Color(nsColor: c.accent)))
                            .offset(x: 3, y: 2)
                    }
                }
                .help(tab?.effectiveAgentKind.map { subagentTooltip(kind: $0, subagents: tab?.subagents ?? []) } ?? "")
                .padding(.leading, 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected
                            ? Color(nsColor: c.textPrimary)
                            : Color(nsColor: c.textSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 3) {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(nsColor: c.textSecondary).opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let notification = waitingNotificationText {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(nsColor: c.textSecondary).opacity(0.4))
                            Text(notification)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(nsColor: .systemBlue))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else if sessionBoardStatus != .idle {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(nsColor: c.textSecondary).opacity(0.4))
                            Text(sessionBoardStatus.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(nsColor: sessionBoardStatus.color))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.leading, 6)

                Spacer()

                HStack(spacing: 4) {
                    // P39 G1: lowest listening port across every tab, so a background dev
                    // server still shows up even when a different tab is active/selected.
                    if let port = session.tabs.compactMap({ $0.listeningPorts.min() }).min() {
                        Button(action: { openInBrowserPane(port: port) }) {
                            SidebarBadgeLabel(text: ":\(port)", color: Color(nsColor: c.textSecondary).opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Open localhost:\(port) in the browser pane")
                    }
                    if let pr = metadata?.prNumber {
                        let prColor: Color = (metadata?.aheadCount ?? 0) > 0
                            ? .green : Color(nsColor: c.accent)
                        Button(action: {
                            if let url = metadata?.prURL { onPRClick(url) }
                        }) {
                            HStack(spacing: 3) {
                                if let dot = checksStatusColor(metadata?.prChecksStatus) {
                                    Circle().fill(dot).frame(width: 6, height: 6)
                                }
                                SidebarBadgeLabel(text: "#\(pr)", color: prColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .help(checksStatusHelp(metadata?.prChecksStatus))
                    }
                    if let ahead = metadata?.aheadCount, ahead > 0 {
                        SidebarBadgeLabel(text: "+\(ahead)", color: .green)
                    }
                    if let behind = metadata?.behindCount, behind > 0 {
                        SidebarBadgeLabel(text: "-\(behind)", color: .red)
                    }
                    if isHovered {
                        Button(action: onClose) {
                            Text("×")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Color(nsColor: c.textSecondary))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 18, height: 18)
                        .help("Close session")
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .padding(.leading, KouenDesign.horizontalInset + 8)
        .padding(.trailing, KouenDesign.horizontalInset - 4)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            sessionContextMenuItems(cwd: cwd, branch: branch, sessionTitle: sessionTitle)
        }
    }

    @ViewBuilder
    private func sessionContextMenuItems(cwd: String, branch: String, sessionTitle: String) -> some View {
        Button("Rename session…") {
            renameSession(currentTitle: sessionTitle)
        }
        Button("Copy working directory") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cwd, forType: .string)
        }
        Button("Copy session title") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(sessionTitle, forType: .string)
        }
        Button("Copy Session ID") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(session.id.uuidString, forType: .string)
        }
        if let prNumber = metadata?.prNumber {
            Divider()
            Button("Merge PR #\(prNumber)…") {
                mergePR(number: prNumber, cwd: cwd, checksWaived: metadata?.prChecksStatus != .pass)
            }
            .disabled(!Self.canOfferMerge(
                checksStatus: metadata?.prChecksStatus, mergeable: metadata?.prMergeable, reviewDecision: metadata?.prReviewDecision
            ))
        }
        Divider()
        Button("Split session right") {
            guard let wsID = model.activeWorkspaceID else { return }
            SessionCoordinator.shared.splitSession(workspaceID: wsID, sessionID: session.id, direction: .horizontal)
        }
        Button("Split session down") {
            guard let wsID = model.activeWorkspaceID else { return }
            SessionCoordinator.shared.splitSession(workspaceID: wsID, sessionID: session.id, direction: .vertical)
        }
        Divider()
        let globallyKept = SessionCoordinator.shared.snapshot.keepSessionsOnQuit
        Button(globallyKept ? "Keep running after quit (all sessions kept)" : "Keep running after quit") {
            SessionCoordinator.shared.requestDaemon(
                .setSessionPersistent(sessionID: session.id, persistent: !session.persistent)
            )
            SessionCoordinator.shared.syncFromDaemon()
        }
        Divider()
        Button("Close session", role: .destructive) {
            confirmClose()
        }
        if model.sessions.count > 1 {
            Button("Close other sessions", role: .destructive) {
                closeOtherSessions()
            }
        }
    }

    /// P39 G3 — minimal-risk merge: no pre-selected method (the picker opens on the placeholder
    /// item; leaving it there and hitting "Merge" is treated as cancel, not "pick one for me"),
    /// confirmation shows PR#/title/target branch, and the caller already gated this action on
    /// `checksStatus == .pass && mergeable == true` — `gh pr merge`'s own branch-protection
    /// refusal is the only additional safety backstop, no app-side force option.
    /// M8: normally requires checks-pass + mergeable (P39 G3's original gate, unchanged).
    /// Waiver path — a maintainer-approved PR can merge with checks not yet green, but
    /// `mergeable` (no conflicts) is never waived regardless of approval.
    static func canOfferMerge(
        checksStatus: GitHubCLIClient.ChecksStatus?, mergeable: Bool?, reviewDecision: String?
    ) -> Bool {
        guard mergeable == true else { return false }
        return checksStatus == .pass || reviewDecision == "APPROVED"
    }

    private func mergePR(number: Int, cwd: String, checksWaived: Bool = false) {
        let title = metadata?.prTitle ?? ""
        let target = metadata?.prBaseBranch ?? "the default branch"

        let alert = NSAlert()
        alert.messageText = "Merge PR #\(number)?"
        alert.informativeText = checksWaived
            ? "\(title)\n\nInto \(target)\n\n⚠️ Checks haven't passed yet — merging on maintainer approval (waiver)."
            : "\(title)\n\nInto \(target)"
        alert.alertStyle = .warning
        let mergeButton = alert.addButton(withTitle: checksWaived ? "Merge Anyway" : "Merge")
        alert.addButton(withTitle: "Cancel")
        mergeButton.keyEquivalent = ""

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 24), pullsDown: false)
        popup.addItem(withTitle: "Choose merge method…")
        popup.addItem(withTitle: "Squash and merge")
        popup.addItem(withTitle: "Rebase and merge")
        popup.addItem(withTitle: "Merge commit")
        popup.selectItem(at: 0)
        alert.accessoryView = popup

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let method: GitHubCLIClient.MergeMethod
        switch popup.indexOfSelectedItem {
        case 1: method = .squash
        case 2: method = .rebase
        case 3: method = .merge
        default: return  // placeholder still selected — no method chosen, treat as cancel
        }

        Task {
            let result = await Task.detached(priority: .utility) {
                GitHubCLIClient().merge(repoPath: cwd, prNumber: number, method: method)
            }.value
            let resultAlert = NSAlert()
            if result.success {
                resultAlert.messageText = "Merged PR #\(number)"
                resultAlert.alertStyle = .informational
            } else {
                resultAlert.messageText = "Merge failed"
                resultAlert.informativeText = result.errorMessage ?? "Unknown error"
                resultAlert.alertStyle = .critical
            }
            resultAlert.addButton(withTitle: "OK")
            resultAlert.runModal()
        }
    }

    private func renameSession(currentTitle: String) {
        let alert = NSAlert()
        alert.messageText = "Rename session"
        alert.informativeText = "Enter a new name for this session."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        input.stringValue = currentTitle
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != session.name else { return }
        SessionCoordinator.shared.requestDaemon(.renameSession(sessionID: session.id, name: trimmed))
        SessionCoordinator.shared.syncFromDaemon()
    }

    private func confirmClose() {
        let alert = NSAlert()
        alert.messageText = "Close session?"
        alert.informativeText = session.tabs.count > 1
            ? "This will close \(session.tabs.count) tabs and their running shells."
            : "This will close the session and its running shell."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close Session")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = ""
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        onClose()
    }

    private func closeOtherSessions() {
        guard let wsID = model.activeWorkspaceID else { return }
        let others = model.sessions.filter { $0.id != session.id }
        guard !others.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Close \(others.count) other session\(others.count == 1 ? "" : "s")?"
        alert.informativeText = "Their tabs and running shells will be closed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close Others")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].keyEquivalent = ""
        alert.buttons[1].keyEquivalent = ""
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        for other in others {
            SessionCoordinator.shared.closeSession(other)
        }
        SessionCoordinator.shared.selectSession(workspaceID: wsID, sessionID: session.id)
        SessionCoordinator.shared.syncFromDaemon()
    }

    private var sessionBoardStatus: BoardColumnKind {
        let kinds = session.tabs.map { BoardModel.columnKind(for: $0) }
        for k in [BoardColumnKind.needsAttention, .error, .running, .done] {
            if kinds.contains(k) { return k }
        }
        return .idle
    }

    /// The most specific attention signal for this row: an agent-hook-fired notification
    /// (`tab.status == .waiting`, e.g. Claude Code's Notification/Stop hooks) carries an
    /// actual message, unlike `sessionBoardStatus`'s coarse category label — surfaced here so
    /// the always-visible sidebar (not just the terminal pane's glow ring or the opt-in Notch
    /// panel) shows which session needs attention and why, without leaving the current tab.
    /// Scans every tab (like `sessionBoardStatus` does), not just the active one — a
    /// background tab's notification must still surface here, that's the whole point.
    private var waitingNotificationText: String? {
        for tab in session.tabs {
            if tab.status == .waiting, let text = tab.notificationText, !text.isEmpty {
                return text
            }
        }
        return nil
    }

    /// Reuses the same notification `KouenTerminalSurfaceView`'s click-to-open localhost-link
    /// handler posts — one browser-pane-opening path for both the passive text-detection route
    /// and this proactive sidebar-badge route (P39 G1).
    private func openInBrowserPane(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NotificationCenter.default.post(
            name: Notification.Name("KouenOpenInBrowserPaneURL"),
            object: nil,
            userInfo: ["url": url]
        )
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

    private func checksStatusColor(_ status: GitHubCLIClient.ChecksStatus?) -> Color? {
        guard let status else { return nil }
        switch status {
        case .pass: return .green
        case .fail: return .red
        case .pending: return .yellow
        case .none: return nil
        }
    }

    private func checksStatusHelp(_ status: GitHubCLIClient.ChecksStatus?) -> String {
        guard let status else { return "Open PR" }
        switch status {
        case .pass: return "Checks passing"
        case .fail: return "Checks failing"
        case .pending: return "Checks pending"
        case .none: return "Open PR"
        }
    }
}

// MARK: - Worktree header row

private struct SidebarWorktreeHeaderRow: View {
    let count: Int
    let isCollapsed: Bool
    var onToggleCollapse: () -> Void

    var body: some View {
        let c = KouenDesign.chrome
        HStack(spacing: 6) {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(Color(nsColor: c.textTertiary))

            Text("WORKTREES")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(nsColor: c.textTertiary))
                .kerning(0.5)

            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(nsColor: c.textTertiary))

            Spacer()
        }
        .padding(.horizontal, KouenDesign.horizontalInset + 12)
        .contentShape(Rectangle())
        .onTapGesture { onToggleCollapse() }
    }
}

// MARK: - Worktree item row

private struct SidebarWorktreeItemRow: View {
    let entry: SidebarWorktreeEntry
    let metadata: RepoGitMetadata?
    var onActivate: () -> Void

    @State private var isHovered = false

    var body: some View {
        let c = KouenDesign.chrome

        ZStack {
            RoundedRectangle(cornerRadius: KouenDesign.Radius.card, style: .continuous)
                .fill(isHovered ? Color(nsColor: c.rowHoverFill) : Color.clear)

            HStack(spacing: 0) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(nsColor: c.textTertiary))
                    .frame(width: 12, height: 12)
                    .padding(.leading, 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.branch)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(nsColor: c.textSecondary))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(KouenDesign.shortenPath(entry.path))
                        .font(.system(size: 10))
                        .foregroundStyle(Color(nsColor: c.textSecondary).opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.leading, 6)

                Spacer()

                HStack(spacing: 4) {
                    if let pr = metadata?.prNumber {
                        SidebarBadgeLabel(text: "#\(pr)", color: Color(nsColor: c.accent))
                    }
                    if let ahead = metadata?.aheadCount, ahead > 0 {
                        SidebarBadgeLabel(text: "+\(ahead)", color: .green)
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .padding(.leading, KouenDesign.horizontalInset + 16)
        .padding(.trailing, KouenDesign.horizontalInset - 4)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .onHover { isHovered = $0 }
        .help("Open \(entry.branch) in new session")
    }
}

// MARK: - Divider

private struct SidebarDividerRow: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: KouenDesign.chrome.border).opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, KouenDesign.horizontalInset)
    }
}

// MARK: - Badge

private struct SidebarBadgeLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
