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
/// - `NodeRow` renders a coloured dot and optional strikethrough per status.
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

    var body: some View {
        List {
            if let gitBranch, !gitBranch.isEmpty {
                branchChip(gitBranch)
            }
            ForEach(rootNodes) { node in
                NodeRow(node: node, rootPath: rootPath, watcher: watcher, gitStatus: currentGitStatus, onPreview: onPreview)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .onAppear { refreshGitBranch() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HarnessActiveTabGitBranchDidChange"))) { _ in
            refreshGitBranch()
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
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
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
        .listRowInsets(EdgeInsets(
            top: HarnessDesign.Spacing.xs,
            leading: HarnessDesign.horizontalInset,
            bottom: HarnessDesign.Spacing.sm,
            trailing: HarnessDesign.horizontalInset
        ))
        .listRowBackground(Color.clear)
    }

    private func refreshGitBranch() {
        gitBranch = SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.gitBranch
    }

    private func loadRoot() async {
        let statusProvider = GitStatusProvider()
        // Fetch git status and scan the filesystem concurrently.
        async let gitStatusTask  = statusProvider.status(rootPath: rootPath)
        async let rawNodesTask   = (try? watcher.scan(rootPath: rootPath)) ?? []
        let (status, rawNodes)   = await (gitStatusTask, rawNodesTask)

        currentGitStatus = status
        // Merge status into nodes (watcher also accepts the map, but we already
        // have the raw nodes — apply inline to avoid a second scan).
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        rootNodes = rawNodes.map { node in
            let rel = node.path.hasPrefix(prefix)
                ? String(node.path.dropFirst(prefix.count))
                : node.path
            var updated = node
            updated.gitStatus = status[rel] ?? .unmodified
            return FileTreeNode(node: updated)
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
    @State private var isExpanded = false

    var body: some View {
        if node.node.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children ?? []) { child in
                    NodeRow(node: child, rootPath: rootPath, watcher: watcher, gitStatus: gitStatus, onPreview: onPreview)
                }
            } label: {
                rowLabel(systemImage: "folder")
                    .contentShape(Rectangle())
                    .onTapGesture { isExpanded.toggle() }
            }
            .onChange(of: isExpanded) { _, expanded in
                if expanded { Task { await loadChildren() } }
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
            gitStatusDot(node.node.gitStatus)
        }
        .onDrag {
            NSItemProvider(contentsOf: URL(fileURLWithPath: node.node.path)) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Copy Path") { copyToPasteboard(node.node.path) }
            Button("Copy Relative Path") {
                let rel = node.node.path.replacingOccurrences(of: rootPath + "/", with: "")
                copyToPasteboard(rel)
            }
        }
    }

    // MARK: Git status indicators

    /// A small filled circle indicating the working-tree git status.
    /// Hidden (clear / zero-size) for unmodified files so it takes no space.
    @ViewBuilder
    private func gitStatusDot(_ status: GitStatusType) -> some View {
        let color = gitStatusColor(status)
        if status != .unmodified {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
    }

    private func gitStatusColor(_ status: GitStatusType) -> Color {
        switch status {
        case .modified:   return .yellow
        case .added:      return .green
        case .deleted:    return .red
        case .untracked:  return .secondary
        case .unmodified: return .clear
        }
    }

    // MARK: Actions

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
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
