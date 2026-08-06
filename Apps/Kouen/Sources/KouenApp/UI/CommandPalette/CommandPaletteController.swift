import AppKit
import SwiftUI
import KouenCore
import KouenLSP
import KouenTerminalKit

/// One row in the palette — title + subtitle + SF Symbol + optional shortcut +
/// section. Sections are surfaced as a tinted header above their first row.
@MainActor
struct PaletteAction: Identifiable {
    enum Section: Int, CaseIterable {
        case recent, files, symbols, actions, navigation, tabs, projects, themes, errors, grep

        var title: String {
            switch self {
            case .recent: return "Recent"
            case .files: return "Files"
            case .symbols: return "Symbols"
            case .actions: return "Actions"
            case .navigation: return "Navigation"
            case .tabs: return "Tabs"
            case .projects: return "Switch Project"
            case .themes: return "Themes"
            case .errors: return "Compiler Errors"
            case .grep: return "Search Results"
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let shortcut: String
    let section: Section
    let handler: () -> Void
}

/// Borderless panel that can still take key focus (needed for the search field).
@MainActor
private final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
enum CommandPaletteController {
    private static var panel: NSPanel?
    private static var windowDelegate: PaletteWindowDelegate?

    fileprivate static func clearReferences() {
        panel = nil
        windowDelegate = nil
    }
    /// MRU stack of action IDs the user has just run. Persisted across launches so
    /// the palette feels like it learns from the user.
    private static let recentDefaultsKey = "com.vit129.kouen.palette.recent"
    private static let recentLimit = 5

    // Zoxide cache — refreshed in background every 60s so buildActions() never blocks
    // the main thread with waitUntilExit().
    private static var zoxideCachedPaths: [String] = []
    private static var zoxideLastFetch: TimeInterval = 0  // CACurrentMediaTime epoch

    private static func prefetchZoxideAsync() {
        let now = CACurrentMediaTime()
        guard now - zoxideLastFetch >= 60 else { return }
        zoxideLastFetch = now
        Task.detached(priority: .utility) {
            let paths = (try? Process.zoxideQueryAll())?
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
            await MainActor.run { CommandPaletteController.zoxideCachedPaths = paths }
        }
    }

    enum PaletteMode: Equatable {
        case normal
        case errors
        case grep(query: String)
    }

    static func present(relativeTo parent: NSWindow?, mode: PaletteMode = .normal) {
        panel?.close()
        let actions: [PaletteAction]
        if case .errors = mode, let diagInfo = getActiveDiagnostics() {
            var errorActions: [PaletteAction] = []
            for diag in diagInfo.diagnostics {
                let lineNum = diag.range.start.line + 1
                let colNum = diag.range.start.character + 1
                let severitySymbol = diag.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
                errorActions.append(PaletteAction(
                    id: "error.\(diagInfo.filePath).\(lineNum).\(colNum)",
                    title: diag.message,
                    subtitle: "\((diagInfo.filePath as NSString).lastPathComponent):\(lineNum):\(colNum)",
                    symbol: severitySymbol,
                    shortcut: "",
                    section: .errors
                ) {
                    guard let split = NSApp.keyWindow?.contentViewController as? MainSplitViewController
                        ?? NSApp.mainWindow?.contentViewController as? MainSplitViewController
                    else { return }
                    split.contentVC.openFileTab(path: diagInfo.filePath)
                    split.contentVC.navigateCurrentFile(line: lineNum, column: colNum)
                })
            }
            actions = errorActions
        } else {
            actions = buildActions()
        }
        let model = PaletteModel(actions: actions, recentIDs: loadRecents(), parentWindow: parent, mode: mode)
        let controller = NSHostingController(rootView: PaletteView(model: model))
        let panel = PalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isRestorable = false
        panel.preventsApplicationTerminationWhenModal = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentViewController = controller
        panel.setContentSize(NSSize(width: 620, height: 440))
        let delegate = PaletteWindowDelegate()
        delegate.panel = panel
        panel.delegate = delegate
        windowDelegate = delegate

        // Centered on the parent window — exactly, both axes (no vertical bias).
        // Falling back to screen center when there is no parent window keeps the
        // palette usable from an empty-app launch. Origins are rounded so the
        // borderless panel lands on whole points (no half-pixel blur on its text).
        if let frame = parent?.frame {
            panel.setFrameOrigin(NSPoint(
                x: (frame.midX - panel.frame.width / 2).rounded(),
                y: (frame.midY - panel.frame.height / 2).rounded()
            ))
        } else if let screenFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame {
            panel.setFrameOrigin(NSPoint(
                x: (screenFrame.midX - panel.frame.width / 2).rounded(),
                y: (screenFrame.midY - panel.frame.height / 2).rounded()
            ))
        } else {
            panel.center()
        }
        self.panel = panel
        model.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        KouenMotion.animate(KouenDesign.Motion.fast, timing: KouenDesign.Motion.spring) { _ in
            panel.animator().alphaValue = 1
        }
        model.startFileScan()
    }

    @MainActor
    private static func getActiveDiagnostics() -> (filePath: String, diagnostics: [LSPDiagnostic])? {
        let split = NSApp.keyWindow?.contentViewController as? MainSplitViewController
            ?? NSApp.mainWindow?.contentViewController as? MainSplitViewController
        guard let contentVC = split?.contentVC else { return nil }
        guard let filePath = contentVC.currentFilePath else { return nil }
        return (filePath, contentVC.activeDiagnostics)
    }

    static func recordUsage(_ actionID: String) {
        var current = loadRecents()
        current.removeAll { $0 == actionID }
        current.insert(actionID, at: 0)
        if current.count > recentLimit { current = Array(current.prefix(recentLimit)) }
        UserDefaults.standard.set(current, forKey: recentDefaultsKey)
    }

    private static func loadRecents() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentDefaultsKey) ?? []
    }

    // MARK: - Configurable palette commands

    private struct PaletteCommandConfig: Codable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let shortcut: String
        let section: String
    }

    private static func loadPaletteConfig() -> [PaletteCommandConfig]? {
        let file = KouenPaths.applicationSupport.appendingPathComponent("palette-commands.json")
        guard let data = try? Data(contentsOf: file),
              let configs = try? JSONDecoder().decode([PaletteCommandConfig].self, from: data),
              !configs.isEmpty else { return nil }
        return configs
    }

    private static func sectionFromString(_ str: String) -> PaletteAction.Section {
        switch str {
        case "actions": return .actions
        case "navigation": return .navigation
        case "tabs": return .tabs
        case "projects": return .projects
        default: return .actions
        }
    }

    private static func buildActions() -> [PaletteAction] {
        let coordinator = SessionCoordinator.shared
        let snapshot = coordinator.snapshot

        var actions: [PaletteAction] = []

        // Handler registry — keyed by action ID. Display metadata comes from config or defaults.
        let handlers: [String: () -> Void] = [
            "action.newSession": { if let id = coordinator.snapshot.activeWorkspaceID { coordinator.addSession(to: id) } },
            "action.newTab": { if let id = coordinator.snapshot.activeWorkspaceID { coordinator.addTab(to: id) } },
            "action.newAgentTask": {
                guard let id = coordinator.snapshot.activeWorkspaceID else { return }
                let alert = NSAlert()
                alert.messageText = "New Agent Task"
                alert.informativeText = "Creates an isolated git worktree + branch for this task."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Create")
                alert.addButton(withTitle: "Cancel")
                let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
                alert.accessoryView = input
                alert.window.initialFirstResponder = input
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                if let error = coordinator.addAgentTask(to: id, taskName: name) {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Couldn't Create Agent Task"
                    errorAlert.informativeText = error
                    errorAlert.alertStyle = .warning
                    errorAlert.runModal()
                }
            },
            "action.splitH": { coordinator.splitActivePane(direction: .horizontal) },
            "action.splitV": { coordinator.splitActivePane(direction: .vertical) },
            "action.zoomPane": { coordinator.zoomActivePane() },
            "action.killPane": { coordinator.killActivePane() },
            "action.copyMode": { coordinator.toggleCopyMode() },
            "action.renameTab": { coordinator.beginRenameActiveTab() },
            "action.installCLI": { CLIInstaller.install() },
            "action.settings": { SettingsWindowController.show() },
            "action.reimport": { coordinator.reimportTerminalConfig() },
            "nav.jumpNotification": { coordinator.jumpToLatestNotification() },
            "nav.prevSession": { coordinator.selectAdjacentSession(offset: -1) },
            "nav.nextSession": { coordinator.selectAdjacentSession(offset: 1) },
            "nav.cyclePane": { coordinator.cycleActivePane(forward: true) },
            "pr.openInBrowser": {
                guard let cwd = coordinator.snapshot.activeWorkspace?.activeTab?.cwd else { return }
                let client = GitHubCLIClient()
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let pr = client.prForCurrentBranch(repoPath: cwd),
                          let url = URL(string: pr.url) else { return }
                    DispatchQueue.main.async {
                        coordinator.splitPaneCoordinator.openBrowserPane(url: url, direction: .horizontal)
                    }
                }
            },
            "pr.rerunFailed": {
                guard let cwd = coordinator.snapshot.activeWorkspace?.activeTab?.cwd else { return }
                let client = GitHubCLIClient()
                DispatchQueue.global(qos: .userInitiated).async {
                    let runs = client.ciRuns(repoPath: cwd, limit: 1)
                    if let failedRun = runs.first(where: { $0.conclusion == "failure" }) {
                        client.rerunFailed(repoPath: cwd, runID: failedRun.id)
                    }
                }
            },
        ]

        let defaultConfigs: [PaletteCommandConfig] = [
            .init(id: "action.newSession",    title: "New Session",               subtitle: "Create a fresh session",                         symbol: "rectangle.stack.badge.plus",         shortcut: "⇧⌘N",      section: "actions"),
            .init(id: "action.newTab",        title: "New Tab",                   subtitle: "Open a new shell in the active session",         symbol: "plus.rectangle.on.rectangle",        shortcut: "",          section: "actions"),
            .init(id: "action.newAgentTask",  title: "New Agent Task",            subtitle: "Create an isolated worktree + branch for a named task", symbol: "shippingbox",                  shortcut: "",          section: "actions"),
            .init(id: "action.splitH",        title: "Split Right",               subtitle: "Split the active pane to the right",             symbol: "square.split.2x1",                   shortcut: "⌘D",       section: "actions"),
            .init(id: "action.splitV",        title: "Split Down",                subtitle: "Split the active pane down",                     symbol: "square.split.1x2",                   shortcut: "⌘⇧D",      section: "actions"),
            .init(id: "action.zoomPane",      title: "Zoom Pane",                 subtitle: "Toggle full-tab zoom on the active pane",        symbol: "arrow.up.left.and.arrow.down.right",  shortcut: "Prefix z",  section: "actions"),
            .init(id: "action.killPane",      title: "Kill Pane",                 subtitle: "Close the active pane and its shell",            symbol: "xmark.square",                       shortcut: "Prefix x",  section: "actions"),
            .init(id: "action.copyMode",      title: "Toggle Copy Mode",          subtitle: "Enter scrollback / selection mode",              symbol: "doc.on.clipboard",                   shortcut: "Prefix [",  section: "actions"),
            .init(id: "action.renameTab",     title: "Rename Active Tab",         subtitle: "Set a custom title for the current tab",         symbol: "pencil",                             shortcut: "Prefix ,",  section: "actions"),
            .init(id: "action.installCLI",    title: "Install kouen-cli to PATH", subtitle: "Copy the CLI to Application Support",          symbol: "arrow.down.app",                     shortcut: "",          section: "actions"),
            .init(id: "action.settings",      title: "Open Settings",             subtitle: "Theme, font, agents, key bindings",              symbol: "gearshape",                          shortcut: "⌘,",       section: "actions"),
            .init(id: "action.reimport",      title: "Re-import Terminal Config", subtitle: "Reload theme, colors & font from your terminal config", symbol: "arrow.triangle.2.circlepath", shortcut: "Prefix r",  section: "actions"),
            .init(id: "nav.jumpNotification", title: "Jump to Notification",      subtitle: "Focus the next tab waiting on input",            symbol: "bell.badge",                         shortcut: "⇧⌘U",      section: "navigation"),
            .init(id: "nav.prevSession",      title: "Previous Session",          subtitle: "Cycle to the previous session",                  symbol: "chevron.left.square",                shortcut: "⌘⇧[",     section: "navigation"),
            .init(id: "nav.nextSession",      title: "Next Session",              subtitle: "Cycle to the next session",                      symbol: "chevron.right.square",               shortcut: "⌘⇧]",     section: "navigation"),
            .init(id: "nav.cyclePane",        title: "Cycle Pane",                subtitle: "Move focus to the next pane in the tab",         symbol: "rectangle.3.group",                  shortcut: "⌘]",       section: "navigation"),
            .init(id: "pr.openInBrowser",    title: "Open PR in Browser Pane",   subtitle: "View the current branch's PR inline",            symbol: "arrow.up.right.square",              shortcut: "⌃⌘G",      section: "actions"),
            .init(id: "pr.rerunFailed",      title: "Re-run Failed CI",          subtitle: "Re-run failed jobs for the latest workflow run",  symbol: "arrow.clockwise",                    shortcut: "",          section: "actions"),
        ]

        let configs = loadPaletteConfig() ?? defaultConfigs
        for config in configs {
            guard let handler = handlers[config.id] else { continue }
            actions.append(PaletteAction(
                id: config.id,
                title: config.title,
                subtitle: config.subtitle,
                symbol: config.symbol,
                shortcut: config.shortcut,
                section: sectionFromString(config.section),
                handler: handler
            ))
        }

        // MARK: - Tabs in active workspace (every session, not just the active one — the
        // palette is the only flat "jump anywhere" surface, so all tabs must be reachable).
        if let workspace = snapshot.activeWorkspace {
            let activeSessionID = workspace.activeSessionID
            let multipleSessions = workspace.sessions.count > 1
            for session in workspace.sessions {
                let isActiveSession = session.id == activeSessionID
                for (idx, tab) in session.tabs.enumerated() {
                    let folder = KouenDesign.pathDisplayName(tab.cwd)
                    let title = !folder.isEmpty ? folder : (tab.title.isEmpty ? "Terminal" : tab.title)
                    var subtitle = KouenDesign.shortenPath(tab.cwd)
                    if multipleSessions, !session.name.isEmpty {
                        subtitle = subtitle.isEmpty ? session.name : "\(session.name) · \(subtitle)"
                    }
                    actions.append(PaletteAction(
                        id: "tab.\(tab.id.uuidString)",
                        title: title,
                        subtitle: subtitle,
                        symbol: tab.status == .waiting ? "bell.fill" : (tab.agent != nil ? "sparkles" : "terminal"),
                        // ⌘N only addresses the active session's tabs — don't advertise it
                        // on tabs the shortcut can't actually reach.
                        shortcut: isActiveSession && idx < 9 ? "⌘\(idx + 1)" : "",
                        section: .tabs
                    ) {
                        coordinator.selectTab(workspaceID: workspace.id, tabID: tab.id)
                    })
                }
            }
        }

        // MARK: - Projects (open tabs + zoxide frecency)
        var seenRoots = Set<String>()
        for workspace in snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs {
                    let cwd = tab.cwd.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cwd.isEmpty else { continue }
                    let root = KouenDesign.projectGroupRootPath(for: cwd)
                    if seenRoots.insert(root).inserted {
                        let title = KouenDesign.pathDisplayName(root)
                        let subtitle = KouenDesign.shortenPath(root)
                        let wsID = workspace.id
                        let tabID = tab.id
                        actions.append(PaletteAction(
                            id: "project.\(root)",
                            title: title,
                            subtitle: subtitle,
                            symbol: "folder",
                            shortcut: "",
                            section: .projects
                        ) {
                            if coordinator.snapshot.activeWorkspaceID != wsID {
                                coordinator.selectWorkspace(wsID)
                            }
                            coordinator.selectTab(workspaceID: wsID, tabID: tabID)
                        })
                    }
                }
            }
        }
        // Augment with zoxide frecency list — uses a 60s cache to avoid blocking the main
        // thread with waitUntilExit() on every ⌘K open. First open shows cached (empty) list
        // while the background fetch runs; subsequent opens show fresh results.
        prefetchZoxideAsync()
        for path in zoxideCachedPaths {
            let root = path
            guard !root.isEmpty, seenRoots.insert(root).inserted else { continue }
            let title = KouenDesign.pathDisplayName(root)
            let subtitle = KouenDesign.shortenPath(root)
            let capturedRoot = root
            actions.append(PaletteAction(
                id: "project.\(root)",
                title: title,
                subtitle: subtitle,
                symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                shortcut: "",
                section: .projects
            ) {
                // cd active terminal to this directory (IDE-like Switch Project).
                if let surfaceID = coordinator.activeSurfaceID {
                    coordinator.requestDaemon(.sendKeys(surfaceID: surfaceID.uuidString, keys: ["cd \(capturedRoot.shellQuoted)", "Enter"]))
                } else if let wsID = coordinator.snapshot.activeWorkspaceID {
                    coordinator.addSession(to: wsID, cwd: capturedRoot)
                }
            })
        }

        // MARK: - Themes (featured first)
        for theme in ThemeManager.featuredThemes {
            actions.append(PaletteAction(
                id: "theme.\(theme)",
                title: theme,
                subtitle: "Apply theme",
                symbol: "paintpalette",
                shortcut: "",
                section: .themes
            ) {
                coordinator.setTheme(theme)
            })
        }

        return actions
    }

}


// MARK: - SwiftUI palette

struct PaletteFileEntry: Sendable {
    let path: String
    let relativePath: String
    let fileName: String
}

struct PaletteGrepMatch: Sendable {
    let absolutePath: String
    let relativePath: String
    let filename: String
    let line: Int
    let column: Int
    let text: String
    let ordinal: Int
}

enum PaletteRow {
    case header(PaletteAction.Section)
    case item(PaletteAction)
}

@MainActor
@Observable
final class PaletteModel {
    var query: String = ""
    var rows: [PaletteRow] = []
    var selectedIndex: Int = 0
    var selectableIndexes: [Int] = []
    var cachedFileEntries: (rootPath: String, entries: [PaletteFileEntry]) = ("", [])
    var grepActions: [PaletteAction] = []

    let mode: CommandPaletteController.PaletteMode
    let allActions: [PaletteAction]
    let recentIDs: [String]
    weak var parentWindow: NSWindow?
    weak var panel: NSPanel?

    @ObservationIgnored private var fileScanTask: Task<Void, Never>?
    @ObservationIgnored private var grepSearchTask: Task<Void, Never>?
    @ObservationIgnored private let symbolIndex = WorkspaceSymbolIndex()

    var placeholder: String {
        switch mode {
        case .normal:
            return "Search commands, workspaces, themes..."
        case .errors:
            return "Search compiler errors..."
        case .grep:
            return "Search text in files (grep)..."
        }
    }

    init(
        actions: [PaletteAction],
        recentIDs: [String],
        parentWindow: NSWindow?,
        mode: CommandPaletteController.PaletteMode = .normal
    ) {
        self.allActions = actions
        self.recentIDs = recentIDs
        self.parentWindow = parentWindow
        self.mode = mode
        if case let .grep(initialQuery) = mode {
            query = initialQuery
        }
        rebuildRows(query: query)
        if case .grep = mode, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            startGrepSearch(query: query)
        }
    }

    deinit {
        fileScanTask?.cancel()
        grepSearchTask?.cancel()
    }

    func startFileScan() {
        let rootPath = CommandPaletteController.activeWorkbenchRoot()
        guard rootPath != cachedFileEntries.rootPath else { return }
        symbolIndex.scan(root: rootPath)
        fileScanTask?.cancel()
        fileScanTask = Task { [weak self] in
            let entries = await Task.detached(priority: .userInitiated) {
                CommandPaletteController.scanFileEntries(rootPath: rootPath)
            }.value
            guard !Task.isCancelled else { return }
            self?.cachedFileEntries = (rootPath, entries)
            if let query = self?.query, !(self?.isGrepMode ?? false) {
                self?.rebuildRows(query: query)
            }
        }
    }

    func updateQuery(_ newValue: String) {
        if isGrepMode {
            startGrepSearch(query: newValue)
        } else {
            rebuildRows(query: newValue)
        }
    }

    func moveSelection(by offset: Int) {
        guard !selectableIndexes.isEmpty else { return }
        let currentPosition = selectableIndexes.firstIndex(of: selectedIndex) ?? 0
        let targetPosition = (currentPosition + offset + selectableIndexes.count) % selectableIndexes.count
        selectedIndex = selectableIndexes[targetPosition]
    }

    func selectFirstSelectable() {
        selectedIndex = selectableIndexes.first ?? 0
    }

    func activateSelected() {
        activate(rowIndex: selectedIndex)
    }

    func activate(rowIndex: Int) {
        guard rows.indices.contains(rowIndex), case let .item(action) = rows[rowIndex] else { return }
        CommandPaletteController.recordUsage(action.id)
        panel?.close()
        action.handler()
    }

    func close() {
        panel?.close()
    }

    private var isGrepMode: Bool {
        if case .grep = mode { return true }
        return false
    }

    private func startGrepSearch(query rawQuery: String) {
        grepSearchTask?.cancel()
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            grepActions = []
            rebuildRows(query: "")
            return
        }
        let root = CommandPaletteController.activeWorkbenchRoot()
        grepSearchTask = Task { [weak self] in
            let matches = await Task.detached(priority: .userInitiated) {
                CommandPaletteController.grepMatches(query: query, root: root)
            }.value
            guard !Task.isCancelled else { return }
            self?.grepActions = CommandPaletteController.grepActions(from: matches)
            self?.rebuildRows(query: query)
        }
    }

    private func rebuildRows(query rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespaces)
        var newRows: [PaletteRow] = []
        var selectable: [Int] = []

        switch mode {
        case .errors:
            var matches: [(action: PaletteAction, score: Int)] = []
            for action in allActions {
                if query.isEmpty {
                    matches.append((action, 0))
                } else {
                    let score = FileFuzzyMatcher.score(query: query, in: action.title) ?? -1
                    if score >= 0 { matches.append((action, score)) }
                }
            }
            if !query.isEmpty { matches.sort { $0.score > $1.score } }
            appendSection(.errors, entries: matches.map(\.action), rows: &newRows, selectable: &selectable)

        case .grep:
            appendSection(.grep, entries: grepActions, rows: &newRows, selectable: &selectable)

        case .normal:
            var matches: [(action: PaletteAction, score: Int)] = []
            if query.isEmpty {
                let recents = recentIDs.compactMap { id in allActions.first(where: { $0.id == id }) }
                for action in recents {
                    matches.append((action: PaletteAction(
                        id: action.id,
                        title: action.title,
                        subtitle: action.subtitle,
                        symbol: action.symbol,
                        shortcut: action.shortcut,
                        section: .recent,
                        handler: action.handler
                    ), score: 0))
                }

                let recentFiles = WorkbenchMRU.shared.entries
                let scopePath = SessionCoordinator.shared.activeTabCWD
                let scopedFiles = scopePath.map { scope in recentFiles.filter { $0.hasPrefix(scope) } } ?? recentFiles
                for file in scopedFiles {
                    let filename = (file as NSString).lastPathComponent
                    let relativePath = KouenDesign.shortenPath(file)
                    matches.append((action: PaletteAction(
                        id: "recent-file.\(file)",
                        title: filename,
                        subtitle: relativePath,
                        symbol: "doc.text",
                        shortcut: "",
                        section: .recent
                    ) { [weak parentWindow] in
                        guard let split = parentWindow?.contentViewController as? MainSplitViewController
                            ?? NSApp.mainWindow?.contentViewController as? MainSplitViewController
                        else { return }
                        split.contentVC.openFileTab(path: file)
                    }, score: 0))
                }

                for action in allActions {
                    matches.append((action, 0))
                }
            } else {
                for action in allActions {
                    let titleScore = FileFuzzyMatcher.score(query: query, in: action.title) ?? -1
                    let subtitleScore = FileFuzzyMatcher.score(query: query, in: action.subtitle) ?? -1
                    let best = max(titleScore, subtitleScore >= 0 ? subtitleScore - 5 : -1)
                    if best >= 0 {
                        let recencyBoost = recentIDs.firstIndex(of: action.id).map { 15 - $0 } ?? 0
                        matches.append((action, best + recencyBoost))
                    }
                }
                matches.append(contentsOf: fileMatches(query: query))
                matches.append(contentsOf: symbolMatches(query: query))
                matches.sort { $0.score > $1.score }
            }

            if query.isEmpty {
                let sectionsInOrder: [PaletteAction.Section] = [.recent, .actions, .navigation, .tabs, .projects, .themes]
                for section in sectionsInOrder {
                    let entries = matches.filter { $0.action.section == section }.map(\.action)
                    appendSection(section, entries: entries, rows: &newRows, selectable: &selectable)
                }
            } else {
                var bySection: [PaletteAction.Section: [(PaletteAction, Int)]] = [:]
                for entry in matches {
                    bySection[entry.action.section, default: []].append((entry.action, entry.score))
                }
                let sectionsInOrder = PaletteAction.Section.allCases.sorted { a, b in
                    let aBest = bySection[a]?.first?.1 ?? 0
                    let bBest = bySection[b]?.first?.1 ?? 0
                    return aBest > bBest
                }
                for section in sectionsInOrder {
                    guard let entries = bySection[section], !entries.isEmpty else { continue }
                    appendSection(section, entries: entries.map(\.0), rows: &newRows, selectable: &selectable)
                }
            }
        }

        rows = newRows
        selectableIndexes = selectable
        if !selectable.contains(selectedIndex) {
            selectFirstSelectable()
        }
    }

    private func appendSection(
        _ section: PaletteAction.Section,
        entries: [PaletteAction],
        rows: inout [PaletteRow],
        selectable: inout [Int]
    ) {
        guard !entries.isEmpty else { return }
        rows.append(.header(section))
        for action in entries {
            selectable.append(rows.count)
            rows.append(.item(action))
        }
    }

    private func fileMatches(query: String) -> [(action: PaletteAction, score: Int)] {
        guard !cachedFileEntries.rootPath.isEmpty else { return [] }
        var matches: [(action: PaletteAction, score: Int)] = []
        for entry in cachedFileEntries.entries {
            let titleScore = FileFuzzyMatcher.score(query: query, in: entry.fileName) ?? -1
            let pathScore = FileFuzzyMatcher.score(query: query, in: entry.relativePath) ?? -1
            let best = max(titleScore, pathScore >= 0 ? pathScore - 4 : -1)
            guard best >= 0 else { continue }
            let path = entry.path
            matches.append((
                action: PaletteAction(
                    id: "file.\(path)",
                    title: entry.fileName,
                    subtitle: entry.relativePath,
                    symbol: "doc.text",
                    shortcut: "",
                    section: .files
                ) { [weak parentWindow] in
                    guard let split = parentWindow?.contentViewController as? MainSplitViewController
                        ?? NSApp.mainWindow?.contentViewController as? MainSplitViewController
                    else { return }
                    split.contentVC.openFileTab(path: path)
                },
                score: best
            ))
            if matches.count >= 200 { break }
        }
        return matches
            .sorted { $0.score > $1.score }
            .prefix(20)
            .map { $0 }
    }

    private func symbolMatches(query: String) -> [(action: PaletteAction, score: Int)] {
        guard query.count >= 2 else { return [] }
        return symbolIndex.completions(prefix: query, limit: 10).map { symbol in
            (action: PaletteAction(
                id: "symbol.\(symbol)",
                title: symbol,
                subtitle: "Symbol",
                symbol: "curlybraces",
                shortcut: "",
                section: .symbols
            ) {
                let coordinator = SessionCoordinator.shared
                guard let surfaceID = coordinator.activeSurfaceID else { return }
                coordinator.requestDaemon(.sendKeys(surfaceID: surfaceID.uuidString, keys: [symbol]))
            }, score: FileFuzzyMatcher.score(query: query, in: symbol) ?? 0)
        }
    }
}

@MainActor
private struct PaletteView: View {
    @Bindable var model: PaletteModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        let c = KouenChrome.current
        VStack(spacing: 0) {
            TextField(text: $model.query, prompt: Text(model.placeholder).foregroundStyle(Color(nsColor: c.textTertiary))) {
                EmptyView()
            }
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .foregroundStyle(Color(nsColor: c.textPrimary))
            .focused($searchFocused)
            .padding(.horizontal, 18)
            .frame(height: 52)
            .onSubmit { model.activateSelected() }
            .onChange(of: model.query) { _, newValue in
                model.updateQuery(newValue)
            }

            Divider()
                .overlay(Color(nsColor: c.border))

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.rows.enumerated()), id: \.offset) { index, row in
                            switch row {
                            case let .header(section):
                                PaletteSectionHeader(title: section.title.uppercased())
                                    .frame(height: 26)
                                    .id(index)
                            case let .item(action):
                                PaletteItemRow(
                                    action: action,
                                    query: model.query,
                                    isSelected: index == model.selectedIndex
                                )
                                .frame(height: 48)
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.selectedIndex = index
                                    model.activate(rowIndex: index)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .overlay {
                    if model.selectableIndexes.isEmpty {
                        Text("No matching commands")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(nsColor: c.textTertiary))
                    }
                }
                .onChange(of: model.selectedIndex) { _, newValue in
                    withAnimation(.easeOut(duration: KouenDesign.Motion.fast)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            PaletteFooter()
                .frame(height: 40)
        }
        .frame(width: 620, height: 440)
        .background(OverlayBackground())
        .clipShape(RoundedRectangle(cornerRadius: KouenDesign.Radius.overlay, style: .continuous))
        .onAppear {
            searchFocused = true
            model.startFileScan()
        }
        .onKeyPress(.upArrow) {
            model.moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            model.moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.escape) {
            model.close()
            return .handled
        }
    }
}

@MainActor
private struct PaletteSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(nsColor: KouenChrome.current.textTertiary))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, KouenDesign.Spacing.xl)
        .padding(.top, 6)
    }
}

@MainActor
private struct PaletteItemRow: View {
    let action: PaletteAction
    let query: String
    let isSelected: Bool

    var body: some View {
        let c = KouenChrome.current
        HStack(spacing: KouenDesign.Spacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: KouenDesign.Radius.control, style: .continuous)
                    .fill(Color(nsColor: c.textPrimary.withAlphaComponent(c.isDark ? 0.06 : 0.07)))
                Image(systemName: action.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(nsColor: c.textSecondary))
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(highlightedTitle(primary: c.textPrimary, accent: c.accent))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color(nsColor: c.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(action.subtitle)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color(nsColor: c.textTertiary))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: KouenDesign.Spacing.md)

            if !action.shortcut.isEmpty {
                Text(action.shortcut)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(nsColor: c.textTertiary))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, KouenDesign.Spacing.xl)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: KouenDesign.Radius.control, style: .continuous)
                    .fill(Color(nsColor: c.accent.withAlphaComponent(c.isDark ? 0.16 : 0.13)))
                    .padding(.horizontal, KouenDesign.Spacing.md)
                    .padding(.vertical, 3)
            }
        }
    }

    private func highlightedTitle(primary: NSColor, accent: NSColor) -> AttributedString {
        var result = AttributedString(action.title)
        guard !query.isEmpty else { return result }
        let lowerTitle = action.title.lowercased()
        let lowerQuery = query.lowercased()
        var searchStart = lowerTitle.startIndex
        for char in lowerQuery {
            guard searchStart < lowerTitle.endIndex else { break }
            guard let found = lowerTitle[searchStart...].firstIndex(of: char) else { break }
            let offset = lowerTitle.distance(from: lowerTitle.startIndex, to: found)
            let attributedIndex = result.index(result.startIndex, offsetByCharacters: offset)
            result[attributedIndex..<result.index(afterCharacter: attributedIndex)].foregroundColor = Color(nsColor: accent)
            result[attributedIndex..<result.index(afterCharacter: attributedIndex)].font = .system(size: 13.5, weight: .heavy)
            searchStart = lowerTitle.index(after: found)
        }
        return result
    }
}

@MainActor
private struct PaletteFooter: View {
    var body: some View {
        let c = KouenChrome.current
        HStack(spacing: KouenDesign.Spacing.lg) {
            hint(keys: "↑↓", label: "Navigate")
            hint(keys: "↩", label: "Run")
            hint(keys: "esc", label: "Close")
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: c.textPrimary.withAlphaComponent(c.isDark ? 0.04 : 0.05)))
    }

    private func hint(keys: String, label: String) -> some View {
        let c = KouenChrome.current
        return HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(nsColor: c.textSecondary))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(nsColor: c.textPrimary.withAlphaComponent(c.isDark ? 0.08 : 0.10)))
                )
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(nsColor: c.textTertiary))
        }
    }
}

private struct OverlayBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> KouenOverlayBackground { KouenOverlayBackground() }
    func updateNSView(_ v: KouenOverlayBackground, context: Context) {}
}

@MainActor
private final class PaletteWindowDelegate: NSObject, NSWindowDelegate {
    weak var panel: NSPanel?
    func windowDidResignKey(_ notification: Notification) { panel?.close() }
    func windowWillClose(_ notification: Notification) {
        CommandPaletteController.clearReferences()
    }
}

// MARK: - Palette data helpers

extension CommandPaletteController {
    @MainActor
    fileprivate static func activeWorkbenchRoot() -> String {
        let coordinator = SessionCoordinator.shared
        return WorkbenchContextResolver.resolve(
            snapshot: coordinator.snapshot,
            focusedSurfaceID: coordinator.activeSurfaceID,
            currentFilePath: nil
        )?.cwd ?? FileManager.default.currentDirectoryPath
    }

    nonisolated fileprivate static func scanFileEntries(rootPath: String) -> [PaletteFileEntry] {
        let rootURL = URL(fileURLWithPath: rootPath)
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        var entries: [PaletteFileEntry] = []
        while let url = enumerator?.nextObject() as? URL {
            if Task.isCancelled { break }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isDirectory == true {
                let name = url.lastPathComponent
                if name == "node_modules" || name == ".git" || name == ".build" || name == "DerivedData" {
                    enumerator?.skipDescendants()
                }
                continue
            }
            guard values?.isRegularFile == true else { continue }
            let path = url.path
            let relativePath = path.hasPrefix(rootPrefix) ? String(path.dropFirst(rootPrefix.count)) : url.lastPathComponent
            entries.append(PaletteFileEntry(path: path, relativePath: relativePath, fileName: url.lastPathComponent))
            if entries.count >= 5000 { break }
        }
        return entries
    }

    nonisolated fileprivate static func grepMatches(query: String, root: String) -> [PaletteGrepMatch] {
        let rgPath = ["/opt/homebrew/bin/rg", "/usr/local/bin/rg", "/usr/bin/rg"].first { FileManager.default.fileExists(atPath: $0) }
        let proc = Process()
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        proc.currentDirectoryURL = URL(fileURLWithPath: root)
        if let rgPath {
            proc.executableURL = URL(fileURLWithPath: rgPath)
            proc.arguments = ["--line-number", "--column", "--no-heading", "--color=never", query, "."]
        } else {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
            proc.arguments = ["-rn", query, "."]
        }
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            var matches: [PaletteGrepMatch] = []
            var count = 0
            for line in output.components(separatedBy: "\n") {
                guard !line.isEmpty else { continue }
                let parts = line.components(separatedBy: ":")
                guard parts.count >= 3, let lineNum = Int(parts[1]) else { continue }
                let relPath = parts[0]
                let colNum: Int
                let text: String
                if parts.count >= 4, let col = Int(parts[2]) {
                    colNum = col
                    text = parts.dropFirst(3).joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    colNum = 1
                    text = parts.dropFirst(2).joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let absPath = (root as NSString).appendingPathComponent(relPath)
                let filename = (relPath as NSString).lastPathComponent
                count += 1
                matches.append(PaletteGrepMatch(
                    absolutePath: absPath,
                    relativePath: relPath,
                    filename: filename,
                    line: lineNum,
                    column: colNum,
                    text: text,
                    ordinal: count
                ))
                if matches.count >= 100 { break }
            }
            return matches
        } catch {
            return []
        }
    }

    @MainActor
    fileprivate static func grepActions(from matches: [PaletteGrepMatch]) -> [PaletteAction] {
        matches.map { match in
            PaletteAction(
                id: "grep.\(match.absolutePath).\(match.line).\(match.column).\(match.ordinal)",
                title: match.text.isEmpty ? "Match" : match.text,
                subtitle: "\(match.filename):\(match.line):\(match.column) — \(match.relativePath)",
                symbol: "magnifyingglass",
                shortcut: "",
                section: .grep
            ) {
                guard let split = NSApp.keyWindow?.contentViewController as? MainSplitViewController
                    ?? NSApp.mainWindow?.contentViewController as? MainSplitViewController
                else { return }
                split.contentVC.openFileTab(path: match.absolutePath)
                split.contentVC.navigateCurrentFile(line: match.line, column: match.column)
            }
        }
    }
}

// MARK: - Zoxide helper

extension Process {
    /// Resolves a CLI's absolute path by checking common install locations before relying on
    /// PATH — a GUI-launched app inherits a minimal launchd PATH (`/usr/bin:/bin:…`) that
    /// misses Homebrew *and* version-manager-installed tools (zoxide, npm, pnpm, yarn, bun,
    /// pytest, …). `nil` means "not found anywhere obvious" — callers fall back to
    /// bare-name-via-PATH as a last resort.
    /// ponytail: this list is evidence-based (confirmed via a live PATH-stripped test, not
    /// guessed) — Homebrew + Volta, since that's what was actually found installed. nvm/asdf/fnm
    /// node installs are a known gap this doesn't cover; add their prefixes here if that ever
    /// bites (same pattern, just another `NSHomeDirectory()`-relative candidate).
    static func resolveExecutablePath(_ name: String) -> String? {
        [
            "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)",
            (NSHomeDirectory() as NSString).appendingPathComponent(".volta/bin/\(name)"),
        ]
        .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    /// Run `zoxide query -l` synchronously and return stdout. Returns nil if zoxide is not found
    /// or exits non-zero.
    static func zoxideQueryAll() throws -> String? {
        let binary = resolveExecutablePath("zoxide") ?? "zoxide"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = ["query", "-l"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}
