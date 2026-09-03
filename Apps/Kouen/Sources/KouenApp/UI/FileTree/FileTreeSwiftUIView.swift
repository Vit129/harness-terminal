import AppKit
import Observation
import SwiftUI
import KouenCore

@Observable
@MainActor
final class FileTreeNode: Identifiable {
    let id: String
    let node: FileNode
    var children: [FileTreeNode]?
    var isExpanded: Bool = false

    init(node: FileNode) {
        self.id = node.id
        self.node = node
        self.children = node.isDirectory ? [] : nil
    }

    static func buildSearchTree(
        from rawNodes: [FileNode],
        rootPath: String,
        gitStatus: [String: GitStatusType]
    ) -> [FileTreeNode] {
        let standardizedRoot = URL(fileURLWithPath: rootPath).standardizedFileURL.path
        
        var allPaths = Set<String>()
        var parentPaths = Set<String>()
        
        let lowercasedRoot = standardizedRoot.lowercased()
        for node in rawNodes {
            var currentPath = node.path
            while currentPath.lowercased().hasPrefix(lowercasedRoot) && currentPath.count > standardizedRoot.count {
                allPaths.insert(currentPath)
                let parentPath = (currentPath as NSString).deletingLastPathComponent
                if parentPath == currentPath || parentPath.isEmpty {
                    break
                }
                parentPaths.insert(parentPath.lowercased())
                currentPath = parentPath
            }
        }
        
        var treeNodes: [String: FileTreeNode] = [:]
        let rawNodesByPath = Dictionary(uniqueKeysWithValues: rawNodes.map { ($0.path.lowercased(), $0) })
        
        // First, create FileTreeNode for every path
        for path in allPaths {
            let fileNode: FileNode
            let lowercasedPath = path.lowercased()
            if let matched = rawNodesByPath[lowercasedPath] {
                fileNode = matched
            } else {
                let name = (path as NSString).lastPathComponent
                let prefix = standardizedRoot.hasSuffix("/") ? standardizedRoot : standardizedRoot + "/"
                let rel = path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
                fileNode = FileNode(
                    id: path,
                    name: name,
                    path: path,
                    isDirectory: true,
                    children: nil,
                    gitStatus: gitStatus[rel] ?? .unmodified
                )
            }
            
            let treeNode = FileTreeNode(node: fileNode)
            if parentPaths.contains(lowercasedPath) {
                treeNode.isExpanded = true
            }
            
            treeNodes[lowercasedPath] = treeNode
        }
        
        // Link children to parents
        for treeNode in treeNodes.values {
            let path = treeNode.node.path
            let parentPath = (path as NSString).deletingLastPathComponent
            if let parentNode = treeNodes[parentPath.lowercased()] {
                if parentNode.children == nil {
                    parentNode.children = []
                }
                parentNode.children?.append(treeNode)
            }
        }
        
        // Sort children
        func sortNodes(_ nodes: [FileTreeNode]) -> [FileTreeNode] {
            nodes.sorted { lhs, rhs in
                if lhs.node.isDirectory != rhs.node.isDirectory {
                    return lhs.node.isDirectory && !rhs.node.isDirectory
                }
                return lhs.node.name.localizedStandardCompare(rhs.node.name) == .orderedAscending
            }
        }
        
        for node in treeNodes.values {
            if let children = node.children {
                node.children = sortNodes(children)
            }
        }
        
        // Root level nodes are those whose parent is standardizedRoot
        let rootLevel = treeNodes.values.filter {
            let parentPath = ($0.node.path as NSString).deletingLastPathComponent
            return parentPath.lowercased() == lowercasedRoot
        }
        
        return sortNodes(Array(rootLevel))
    }
}

/// SwiftUI view for the file-explorer sidebar panel.
///
/// **Git status integration (F1-B/E/F):**
/// - `.task(id:)` uses a combined `sessionID + rootPath` key so it re-runs
///   whenever *either* the directory or the active session changes.
/// - `loadRoot()` runs filesystem scan and `git status` concurrently, then
///   merges the status map into each `FileNode.gitStatus`.
/// - `NodeRow` renders a coloured letter badge and optional strikethrough per
///   status.
///
/// **Live FSEvents watcher (F1-G):**
/// - A second `.task(id:)` with the same key starts the watcher alongside
///   `loadRoot()` and cancels it automatically when the view disappears or the
///   key changes (session/path switch). The watcher fires `loadRoot()` on the
///   main actor after a 500 ms debounce.
@MainActor
struct FileTreeSwiftUIView: View {
    @Bindable var context: FileTreeContext
    let watcher: FileTreeWatcher
    /// Keyboard navigation state — written by AppKit, read here for highlight + scroll.
    let keyboard: FileTreeKeyboardState
    let onPreview: (FileNode) -> Void

    private var rootPath: String { context.rootPath }
    private var sessionID: SessionID? { context.sessionID }
    @State private var rootNodes: [FileTreeNode] = []
    @State private var searchResultNodes: [FileTreeNode] = []
    @State private var gitBranch: String?
    /// RL-040: Hold old nodes for one render cycle so SwiftUI closures that captured
    /// them don't dereference freed @Observable objects mid-body evaluation.
    @State private var retiredNodes: [FileTreeNode] = []
    /// Kept alive across expands so child nodes inherit the same status map.
    @State private var currentGitStatus: [String: GitStatusType] = [:]
    /// Coalesces bursts of `scheduleLoadRoot()` calls (e.g. rapid `.fileTreeDidChange`
    /// notifications) into a single `loadRoot()` — see its doc comment.
    @State private var pendingLoadTask: Task<Void, Never>?
    @AppStorage("KouenFileTreeShowsHiddenFiles") private var showsHiddenFiles = false
    @AppStorage("KouenFileTreeShowsHiddenFolders") private var showsHiddenFolders = false

    private var scanOptions: FileTreeScanOptions {
        FileTreeScanOptions(showsHiddenFiles: showsHiddenFiles, showsHiddenFolders: showsHiddenFolders)
    }

    private var taskID: String {
        "\(sessionID?.uuidString ?? "nil")|\(rootPath)|\(showsHiddenFiles)|\(showsHiddenFolders)"
    }

    @State private var searchText: String = ""

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredNodes: [FileTreeNode] {
        trimmedSearchText.isEmpty ? rootNodes : searchResultNodes
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Filter files…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                hiddenToggle(
                    isOn: $showsHiddenFiles,
                    systemImage: "doc",
                    help: showsHiddenFiles ? "Hide hidden files" : "Show hidden files"
                )
                hiddenToggle(
                    isOn: $showsHiddenFolders,
                    systemImage: "folder",
                    help: showsHiddenFolders ? "Hide hidden folders" : "Show hidden folders"
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            ScrollViewReader { proxy in
                List {
                    if let gitBranch, !gitBranch.isEmpty {
                        branchChip(gitBranch)
                    }
                    ForEach(filteredNodes) { node in
                        NodeRow(
                            node: node,
                            rootPath: rootPath,
                            watcher: watcher,
                            scanOptions: scanOptions,
                            gitStatus: currentGitStatus,
                            keyboard: keyboard,
                            onPreview: onPreview,
                            isSearching: !trimmedSearchText.isEmpty
                        )
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .onChange(of: filteredNodes.map(\.node.path)) { _, _ in
                    updateVisiblePaths()
                }
                .onAppear { updateVisiblePaths() }
                .onChange(of: context.revealPath) { _, path in
                    guard let path else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(path, anchor: .center)
                    }
                    context.revealPath = nil
                }
            }
        }
        .onAppear { refreshGitBranch(); updateVisiblePaths() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("KouenActiveTabGitBranchDidChange"))) { _ in
            refreshGitBranch()
            scheduleLoadRoot()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileTreeDidChange)) { _ in
            scheduleLoadRoot()
        }
        // React to both path and session changes — different sessions may be on
        // different branches sharing the same rootPath.
        .task(id: taskID) { await loadRoot() }
        .task(id: "\(taskID)|search|\(trimmedSearchText)") { await loadSearchResults(query: trimmedSearchText) }
        // FSEvents live watcher: starts alongside loadRoot, auto-cancelled on
        // key change (session/path switch) or view disappearance.
        .task(id: "\(taskID)|watcher") {
            await watcher.startWatching(rootPath: rootPath) {
                // Called on @MainActor after 500ms debounce.
                Task { await loadRoot() }
            }
            // Task is cancelled when view disappears or taskID changes.
            // Await cancellation so we stay alive while the view is visible.
            await withTaskCancellationHandler(operation: {
                // Sleep indefinitely; the watcher fires onChange callbacks independently.
                try? await Task.sleep(nanoseconds: .max)
            }, onCancel: {
                Task { await watcher.stopWatching() }
            })
        }
    }

    private func branchChip(_ name: String) -> some View {
        HStack(spacing: KouenDesign.Spacing.xs) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 10, weight: .medium))
            Text("Git · \(name)")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
        }
        .foregroundStyle(Color(KouenDesign.chrome.textSecondary))
        .padding(.horizontal, KouenDesign.Spacing.sm)
        .padding(.vertical, KouenDesign.Spacing.xs)
        .background(Color(KouenDesign.chrome.surfaceElevated))
        .clipShape(RoundedRectangle(cornerRadius: KouenDesign.Radius.badge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KouenDesign.Radius.badge, style: .continuous)
                .stroke(Color(KouenDesign.chrome.border), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { showBranchSwitcher() }
        .listRowInsets(EdgeInsets(
            top: KouenDesign.Spacing.xs,
            leading: KouenDesign.horizontalInset,
            bottom: KouenDesign.Spacing.sm,
            trailing: KouenDesign.horizontalInset
        ))
        .listRowBackground(Color.clear)
    }

    private func hiddenToggle(isOn: SwiftUI.Binding<Bool>, systemImage: String, help: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? Color.accentColor : Color.secondary)
                
                Image(systemName: isOn.wrappedValue ? "eye" : "eye.slash")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(isOn.wrappedValue ? Color.accentColor : Color.secondary)
                    .padding(1)
                    .background(Color(KouenDesign.chrome.sidebarBackground))
                    .clipShape(Circle())
                    .offset(x: 3, y: 3)
            }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func showBranchSwitcher() {
        Task {
            let branches = await listBranches()
            let current = gitBranch ?? ""
            let menu = NSMenu()
            for branch in branches {
                let item = NSMenuItem(title: branch, action: #selector(BranchSwitchHelper.switchBranch(_:)), keyEquivalent: "")
                item.target = BranchSwitchHelper.shared
                item.representedObject = (rootPath, branch) as (String, String)
                if branch == current { item.state = .on }
                menu.addItem(item)
            }
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
            let mouseLocation = window.mouseLocationOutsideOfEventStream
            menu.popUp(positioning: nil, at: mouseLocation, in: window.contentView)
        }
    }

    private func listBranches() async -> [String] {
        let path = rootPath
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["branch", "--format=%(refname:short)"]
                process.currentDirectoryURL = URL(fileURLWithPath: path)
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let branches = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                    continuation.resume(returning: branches)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func getCurrentBranch() async -> String? {
        let path = rootPath
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
                process.currentDirectoryURL = URL(fileURLWithPath: path)
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: trimmed.isEmpty ? nil : trimmed)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func refreshGitBranch() {
        gitBranch = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.gitBranch
    }

    /// Build a flat ordered list of visible node paths for keyboard navigation.
    private func updateVisiblePaths() {
        var paths: [String] = []
        func collect(_ nodes: [FileTreeNode]) {
            for n in nodes {
                paths.append(n.node.path)
                if n.isExpanded, let children = n.children {
                    collect(children)
                }
            }
        }
        collect(filteredNodes)
        keyboard.visiblePaths = paths
        if keyboard.focusedPath == nil { keyboard.focusedPath = paths.first }
    }

    @discardableResult
    private func loadSearchResults(query: String) async -> [FileTreeNode] {
        guard !query.isEmpty else {
            searchResultNodes = []
            updateVisiblePaths()
            return []
        }

        // 200ms debounce
        do {
            try await Task.sleep(nanoseconds: 200_000_000)
        } catch {
            return []
        }

        guard !Task.isCancelled else { return [] }

        let rawNodes: [FileNode]
        do {
            rawNodes = try await watcher.search(
                rootPath: rootPath,
                query: query,
                gitStatus: currentGitStatus,
                options: scanOptions
            )
        } catch {
            rawNodes = []
        }

        guard !Task.isCancelled else { return [] }
        let results = FileTreeNode.buildSearchTree(from: rawNodes, rootPath: rootPath, gitStatus: currentGitStatus)
        searchResultNodes = results
        updateVisiblePaths()
        return results
    }

    /// Debounces `loadRoot()`: cancels any pending call and reschedules 300ms out, so a
    /// burst of notifications (e.g. many rapid `.fileTreeDidChange` fires during a build)
    /// coalesces into one `git status` invocation instead of spawning one per fire.
    private func scheduleLoadRoot() {
        pendingLoadTask?.cancel()
        pendingLoadTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await loadRoot()
        }
    }

    private func loadRoot() async {
        let taskRootPath = rootPath
        let taskSessionID = sessionID
        refreshGitBranch()
        let statusProvider = GitStatusProvider()
        async let gitStatusTask  = statusProvider.status(rootPath: rootPath)
        async let rawNodesTask   = (try? watcher.scan(rootPath: rootPath, options: scanOptions)) ?? []
        let (status, rawNodes)   = await (gitStatusTask, rawNodesTask)

        // scanDirectory() has no cancellation checks, so a stale scan for a root/session
        // we've since switched away from can still finish and land here. Drop it instead
        // of clobbering whatever the current root's own loadRoot() already wrote.
        guard rootPath == taskRootPath, sessionID == taskSessionID else { return }

        currentGitStatus = status
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        // Build updated node list with git status applied.
        let updatedNodes = rawNodes.map { node -> FileNode in
            let rel = node.path.hasPrefix(prefix)
                ? String(node.path.dropFirst(prefix.count))
                : node.path
            var updated = node
            updated.gitStatus = status[rel] ?? .unmodified
            return updated
        }

        // Reconcile in-place: preserve existing FileTreeNode identity so
        // SwiftUI @State (expand/collapse) is retained.
        let existingByID = Dictionary(uniqueKeysWithValues: rootNodes.map { ($0.id, $0) })
        var reconciled: [FileTreeNode] = []
        for node in updatedNodes {
            if let existing = existingByID[node.id] {
                // Update the FileNode data without replacing the object.
                existing.children = existing.children // keep children intact
                reconciled.append(existing)
            } else {
                reconciled.append(FileTreeNode(node: node))
            }
        }
        rootNodes = reconciled
        // RL-040: Keep removed nodes alive until the next render cycle completes,
        // preventing SwiftUI closures from dereferencing freed @Observable objects.
        retiredNodes = Array(existingByID.values.filter { existing in
            !reconciled.contains { $0 === existing }
        })
        Task { @MainActor in retiredNodes = [] }
        if !trimmedSearchText.isEmpty {
            await loadSearchResults(query: trimmedSearchText)
        }

        let branch = await getCurrentBranch()
        if gitBranch != branch {
            gitBranch = branch
        }
    }
}


// MARK: - NodeRow

@MainActor
private struct NodeRow: View {
    let node: FileTreeNode
    let rootPath: String
    let watcher: FileTreeWatcher
    let scanOptions: FileTreeScanOptions
    let gitStatus: [String: GitStatusType]
    let keyboard: FileTreeKeyboardState
    let onPreview: (FileNode) -> Void
    let isSearching: Bool

    /// Debounces `reconcileChildren()` the same way `FileTreeSwiftUIView.scheduleLoadRoot()`
    /// debounces the root scan — see `reconcileChildren()`'s doc comment for why this exists.
    @State private var pendingReconcileTask: Task<Void, Never>?

    private var isFocused: Bool { keyboard.focusedPath == node.node.path }

    private var parentDirectory: String? {
        guard isSearching else { return nil }
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard node.node.path.hasPrefix(prefix) else { return nil }
        let rel = String(node.node.path.dropFirst(prefix.count))
        let url = URL(fileURLWithPath: rel)
        let parent = url.deletingLastPathComponent().path
        return parent.isEmpty || parent == "/" || parent == "." ? nil : parent
    }

    private var resolvedGitStatus: GitStatusType {
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        let rel = node.node.path.hasPrefix(prefix)
            ? String(node.node.path.dropFirst(prefix.count))
            : node.node.path
        if let status = gitStatus[rel] {
            return status
        }
        let lowerRel = rel.lowercased()
        for (key, status) in gitStatus {
            if key.lowercased() == lowerRel {
                return status
            }
        }
        return .unmodified
    }

    var body: some View {
        if node.node.isDirectory {
            DisclosureGroup(isExpanded: Binding(get: { node.isExpanded }, set: { node.isExpanded = $0 })) {
                ForEach(node.children ?? []) { child in
                    NodeRow(
                        node: child,
                        rootPath: rootPath,
                        watcher: watcher,
                        scanOptions: scanOptions,
                        gitStatus: gitStatus,
                        keyboard: keyboard,
                        onPreview: onPreview,
                        isSearching: false
                    )
                }
            } label: {
                rowLabel(systemImage: "folder")
                    .contentShape(Rectangle())
                    .background(isFocused ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                    .onTapGesture(count: 2) {
                        // Double-click folder → cd terminal to this path
                        let coord = SessionCoordinator.shared
                        if let surfaceID = coord.activeSurfaceID {
                            coord.requestDaemon(.sendKeys(surfaceID: surfaceID.uuidString, keys: ["cd \(node.node.path)", "Enter"]))
                        }
                    }
                    .onTapGesture {
                        keyboard.focusedPath = node.node.path
                        node.isExpanded.toggle()
                    }
            }
            .onChange(of: node.isExpanded) { _, expanded in
                // Keep loaded children in memory on collapse — DisclosureGroup already
                // hides them visually. Wiping here used to reset any nested subfolder's
                // own isExpanded state every time the parent was reopened.
                if expanded {
                    Task { await loadChildren() }
                }
            }
            // h/l expand/collapse via keyboard navigator
            .onChange(of: keyboard.focusedPath) { _, focused in
                guard focused == node.node.path else { return }
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileTreeToggleExpand)) { note in
                guard let path = note.userInfo?["path"] as? String,
                      let action = note.userInfo?["action"] as? String,
                      path == node.node.path else { return }
                if action == "expand" && !node.isExpanded { node.isExpanded = true }
                if action == "collapse" && node.isExpanded { node.isExpanded = false }
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileTreeDidChange)) { _ in
                guard node.isExpanded else { return }
                pendingReconcileTask?.cancel()
                pendingReconcileTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await reconcileChildren()
                }
            }
        } else {
            rowLabel(systemImage: "doc")
                .contentShape(Rectangle())
                .background(isFocused ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(4)
                .onTapGesture(count: 2) { openFile() }
                .onTapGesture {
                    keyboard.focusedPath = node.node.path
                    onPreview(node.node)
                }
        }
    }

    private func rowLabel(systemImage: String) -> some View {
        let status = resolvedGitStatus
        return HStack(spacing: 4) {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.node.name)
                        .strikethrough(status == .deleted, color: gitStatusColor(status))
                    if let parent = parentDirectory {
                        Text(parent)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }
            } icon: {
                Image(systemName: systemImage)
            }
            .help(node.node.path)
            Spacer()
            gitStatusBadge(status)
        }
        .onDrag {
            NSItemProvider(contentsOf: URL(fileURLWithPath: node.node.path)) ?? NSItemProvider()
        }
        .contextMenu {
            Button("New File") { newFile(in: node.node) }
            Button("New Folder") { newFolder(in: node.node) }
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(node.node.path, inFileViewerRootedAtPath: "")
            }
            Button("Open in Default App") {
                NSWorkspace.shared.open(URL(fileURLWithPath: node.node.path))
            }
            Divider()
            Button("Copy Path") { copyToPasteboard(node.node.path) }
            Button("Copy Relative Path") {
                let rel = node.node.path.replacingOccurrences(of: rootPath + "/", with: "")
                copyToPasteboard(rel)
            }
            Divider()
            Button("Rename…") { renameItem(path: node.node.path) }
            Button("Duplicate") { duplicateItem(path: node.node.path) }
            Divider()
            Button("Move to Trash", role: .destructive) {
                moveToTrash(path: node.node.path)
            }
        }
    }

    // MARK: Git status indicators

    /// A compact VS Code-style badge indicating the working-tree git status.
    /// Hidden for unmodified files so clean rows stay visually quiet.
    @ViewBuilder
    private func gitStatusBadge(_ status: GitStatusType) -> some View {
        let color = gitStatusColor(status)
        if status != .unmodified {
            Text(gitStatusLetter(status))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 14, height: 14)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: KouenDesign.Radius.badge, style: .continuous))
                .help(gitStatusDescription(status))
        }
    }

    private func gitStatusColor(_ status: GitStatusType) -> Color {
        switch status {
        case .modified:   return .yellow
        case .added:      return .green
        case .deleted:    return .red
        case .renamed:    return .blue
        case .untracked:  return .secondary
        case .unmodified: return .clear
        }
    }

    private func gitStatusLetter(_ status: GitStatusType) -> String {
        switch status {
        case .modified:   return "M"
        case .added:      return "A"
        case .deleted:    return "D"
        case .renamed:    return "R"
        case .untracked:  return "U"
        case .unmodified: return ""
        }
    }

    private func gitStatusDescription(_ status: GitStatusType) -> String {
        switch status {
        case .modified:   return "Modified"
        case .added:      return "Added"
        case .deleted:    return "Deleted"
        case .renamed:    return "Renamed"
        case .untracked:  return "Untracked"
        case .unmodified: return "Unmodified"
        }
    }

    // MARK: Actions

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func moveToTrash(path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            Self.notifyTreeDidChange()
        } catch {
            NSSound.beep()
        }
    }

    private func newFile(in node: FileNode) {
        let dir = node.isDirectory ? node.path : (node.path as NSString).deletingLastPathComponent
        let path = uniquePath(base: dir, name: "untitled", ext: "")
        guard FileManager.default.createFile(atPath: path, contents: nil) else {
            showCreateError(path: path)
            return
        }
        Self.notifyTreeDidChange()
        renameItem(path: path)
    }

    private func newFolder(in node: FileNode) {
        let dir = node.isDirectory ? node.path : (node.path as NSString).deletingLastPathComponent
        let path = uniquePath(base: dir, name: "untitled folder", ext: "")
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
        } catch {
            showCreateError(path: path, error: error)
            return
        }
        Self.notifyTreeDidChange()
    }

    /// `newFile`/`newFolder` previously discarded failures (`try?` / unchecked `Bool`
    /// return) — a failed create looked identical to a successful one that just hadn't
    /// refreshed yet, no dialog, no beep. Surfacing the actual reason here.
    private func showCreateError(path: String, error: Error? = nil) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't create \"\((path as NSString).lastPathComponent)\""
        alert.informativeText = error?.localizedDescription
            ?? "The item already exists or the location isn't writable."
        alert.runModal()
    }

    private func renameItem(path: String) {
        let url = URL(fileURLWithPath: path)
        let alert = NSAlert()
        alert.messageText = "Rename"
        alert.informativeText = (path as NSString).lastPathComponent
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = (path as NSString).lastPathComponent
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { return }
        let newPath = ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(newName)
        try? FileManager.default.moveItem(at: url, to: URL(fileURLWithPath: newPath))
        Self.notifyTreeDidChange()
    }

    private func duplicateItem(path: String) {
        let ext = (path as NSString).pathExtension
        let base = (path as NSString).deletingPathExtension
        let dir = (path as NSString).deletingLastPathComponent
        let name = (base as NSString).lastPathComponent
        let newName = ext.isEmpty ? "\(name) copy" : "\(name) copy.\(ext)"
        let dest = (dir as NSString).appendingPathComponent(newName)
        try? FileManager.default.copyItem(atPath: path, toPath: dest)
        Self.notifyTreeDidChange()
    }

    private static func notifyTreeDidChange() {
        NotificationCenter.default.post(name: .fileTreeDidChange, object: nil)
    }

    private func uniquePath(base dir: String, name: String, ext: String) -> String {
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        var path = (dir as NSString).appendingPathComponent(name + suffix)
        var i = 2
        while FileManager.default.fileExists(atPath: path) {
            path = (dir as NSString).appendingPathComponent("\(name) \(i)\(suffix)")
            i += 1
        }
        return path
    }

    private func loadChildren() async {
        guard node.children?.isEmpty == true else { return }
        do {
            let childNodes = try await watcher.expand(node: node.node, gitStatus: gitStatus, options: scanOptions)
            node.children = childNodes.map { FileTreeNode(node: $0) }
        } catch {
            node.children = []
        }
    }

    /// `loadRoot()`'s own reconcile deliberately preserves each node's cached `children`
    /// ("keep children intact") so nested expand state survives a root refresh, and
    /// `loadChildren()` only fetches once (`guard children?.isEmpty == true`) — so once a
    /// folder is expanded, nothing ever re-scans it again. A file created/deleted inside an
    /// already-expanded folder (e.g. via this tree's own New File/Folder) never showed up
    /// until the app restarted. Re-scans and merges by id — same identity-preserving
    /// reconcile `loadRoot()` uses for the root level, so already-expanded nested
    /// subfolders keep their own `isExpanded` state instead of resetting.
    private func reconcileChildren() async {
        guard node.isExpanded,
              let fresh = try? await watcher.expand(node: node.node, gitStatus: gitStatus, options: scanOptions)
        else { return }
        let existingByID = Dictionary(uniqueKeysWithValues: (node.children ?? []).map { ($0.id, $0) })
        node.children = fresh.map { existingByID[$0.id] ?? FileTreeNode(node: $0) }
    }

    private func openFile() {
        let ext = (node.node.path as NSString).pathExtension.lowercased()
        if ext == "html" || ext == "htm" {
            SessionCoordinator.shared.splitPaneCoordinator.openBrowserPane(
                url: URL(fileURLWithPath: node.node.path),
                direction: .horizontal
            )
            return
        }
        let coordinator = SessionCoordinator.shared
        let action = coordinator.settings.fileClickAction
        if action == "editor" || action == "preview" {
            guard let split = NSApp.keyWindow?.contentViewController as? MainSplitViewController
                ?? NSApp.mainWindow?.contentViewController as? MainSplitViewController else { return }
            split.contentVC.openFileTab(path: node.node.path)
        } else {
            coordinator.splitActivePane(direction: .horizontal)
            guard let surfaceID = coordinator.activeSurfaceID else { return }
            let cmd: String
            if action == "vi" {
                cmd = "vi \(node.node.path)\r"
            } else if action == "cat" {
                cmd = "cat \(node.node.path)\r"
            } else {
                cmd = "open \(node.node.path)\r"
            }
            coordinator.requestDaemon(.sendData(surfaceID: surfaceID.uuidString, data: Data(cmd.utf8)))
        }
    }
}

// MARK: - Branch switch helper (NSMenu target)

@MainActor
final class BranchSwitchHelper: NSObject {
    static let shared = BranchSwitchHelper()

    @objc func switchBranch(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? (String, String) else { return }
        let (rootPath, branch) = pair
        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["checkout", branch]
            process.currentDirectoryURL = URL(fileURLWithPath: rootPath)
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                DisplayMessage.show("Switched to \(branch)")
                SessionCoordinator.shared.syncFromDaemon()
            }
        }
    }
}

// MARK: - Notification for manual file-tree refresh

extension Notification.Name {
    static let fileTreeDidChange = Notification.Name("KouenFileTreeDidChange")
    static let fileTreeToggleExpand = Notification.Name("KouenFileTreeToggleExpand")
}
