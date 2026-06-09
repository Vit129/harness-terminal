import AppKit
import Observation
import SwiftUI
import HarnessCore

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
    let rootPath: String
    /// Session identity included in the `.task` id so switching sessions in the
    /// same repo (e.g. main vs feat/A) re-runs `loadRoot()`.
    let sessionID: SessionID?
    let watcher: FileTreeWatcher
    /// Single-click on a file row — shows a read-only preview in the sidebar.
    let onPreview: (FileNode) -> Void
    @State private var rootNodes: [FileTreeNode] = []
    @State private var gitBranch: String?
    /// Kept alive across expands so child nodes inherit the same status map.
    @State private var currentGitStatus: [String: GitStatusType] = [:]

    private var taskID: String { "\(sessionID?.uuidString ?? "nil")|\(rootPath)|\(gitBranch ?? "nil")" }

    @State private var searchText: String = ""

    private var filteredNodes: [FileTreeNode] {
        guard !searchText.isEmpty else { return rootNodes }
        return rootNodes.filter { matchesSearch($0, query: searchText.lowercased()) }
    }

    private func matchesSearch(_ node: FileTreeNode, query: String) -> Bool {
        if node.node.name.lowercased().contains(query) { return true }
        return node.children?.contains(where: { matchesSearch($0, query: query) }) ?? false
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
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            List {
                if let gitBranch, !gitBranch.isEmpty {
                    branchChip(gitBranch)
                }
                ForEach(filteredNodes) { node in
                    NodeRow(node: node, rootPath: rootPath, watcher: watcher, gitStatus: currentGitStatus, onPreview: onPreview)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .onAppear { refreshGitBranch() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HarnessActiveTabGitBranchDidChange"))) { _ in
            refreshGitBranch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileTreeDidChange)) { _ in
            Task { await loadRoot() }
        }
        // React to both path and session changes — different sessions may be on
        // different branches sharing the same rootPath.
        .task(id: taskID) { await loadRoot() }
        // FSEvents live watcher: starts alongside loadRoot, auto-cancelled on
        // key change (session/path switch) or view disappearance.
        .task(id: taskID) {
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
        HStack(spacing: HarnessDesign.Spacing.xs) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 10, weight: .medium))
            Text("Git · \(name)")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
        }
        .foregroundStyle(Color(HarnessDesign.chrome.textSecondary))
        .padding(.horizontal, HarnessDesign.Spacing.sm)
        .padding(.vertical, HarnessDesign.Spacing.xs)
        .background(Color(HarnessDesign.chrome.surfaceElevated))
        .clipShape(RoundedRectangle(cornerRadius: HarnessDesign.Radius.badge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HarnessDesign.Radius.badge, style: .continuous)
                .stroke(Color(HarnessDesign.chrome.border), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { showBranchSwitcher() }
        .listRowInsets(EdgeInsets(
            top: HarnessDesign.Spacing.xs,
            leading: HarnessDesign.horizontalInset,
            bottom: HarnessDesign.Spacing.sm,
            trailing: HarnessDesign.horizontalInset
        ))
        .listRowBackground(Color.clear)
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
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["branch", "--format=%(refname:short)"]
                process.currentDirectoryURL = URL(fileURLWithPath: rootPath)
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
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
                process.currentDirectoryURL = URL(fileURLWithPath: rootPath)
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

    private func loadRoot() async {
        let statusProvider = GitStatusProvider()
        async let gitStatusTask  = statusProvider.status(rootPath: rootPath)
        async let rawNodesTask   = (try? watcher.scan(rootPath: rootPath)) ?? []
        let (status, rawNodes)   = await (gitStatusTask, rawNodesTask)

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
    let gitStatus: [String: GitStatusType]
    let onPreview: (FileNode) -> Void

    var body: some View {
        if node.node.isDirectory {
            DisclosureGroup(isExpanded: Binding(get: { node.isExpanded }, set: { node.isExpanded = $0 })) {
                ForEach(node.children ?? []) { child in
                    NodeRow(node: child, rootPath: rootPath, watcher: watcher, gitStatus: gitStatus, onPreview: onPreview)
                }
            } label: {
                rowLabel(systemImage: "folder")
                    .contentShape(Rectangle())
                    .onTapGesture { node.isExpanded.toggle() }
            }
            .onChange(of: node.isExpanded) { _, expanded in
                if expanded {
                    Task { await loadChildren() }
                } else {
                    // Reset children so sub-expand states are cleared on collapse.
                    node.children = []
                }
            }
        } else {
            rowLabel(systemImage: "doc")
                .contentShape(Rectangle())
                .gesture(
                    TapGesture(count: 2).onEnded { openFile() }
                        .exclusively(before: TapGesture(count: 1).onEnded { onPreview(node.node) })
                )
        }
    }

    private func rowLabel(systemImage: String) -> some View {
        HStack(spacing: 4) {
            Label {
                Text(node.node.name)
                    .strikethrough(node.node.gitStatus == .deleted, color: gitStatusColor(node.node.gitStatus))
            } icon: {
                Image(systemName: systemImage)
            }
            .help(node.node.path)
            Spacer()
            gitStatusBadge(node.node.gitStatus)
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
                .clipShape(RoundedRectangle(cornerRadius: HarnessDesign.Radius.badge, style: .continuous))
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
        FileManager.default.createFile(atPath: path, contents: nil)
        Self.notifyTreeDidChange()
        renameItem(path: path)
    }

    private func newFolder(in node: FileNode) {
        let dir = node.isDirectory ? node.path : (node.path as NSString).deletingLastPathComponent
        let path = uniquePath(base: dir, name: "untitled folder", ext: "")
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
        Self.notifyTreeDidChange()
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
            let childNodes = try await watcher.expand(node: node.node, gitStatus: gitStatus)
            node.children = childNodes.map { FileTreeNode(node: $0) }
        } catch {
            node.children = []
        }
    }

    private func openFile() {
        let coordinator = SessionCoordinator.shared
        coordinator.splitActivePane(direction: .horizontal)
        guard let surfaceID = coordinator.activeSurfaceID else { return }
        let command = "open \(node.node.path)\r"
        coordinator.requestDaemon(.sendData(surfaceID: surfaceID.uuidString, data: Data(command.utf8)))
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
    static let fileTreeDidChange = Notification.Name("HarnessFileTreeDidChange")
}
