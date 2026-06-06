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

@MainActor
struct FileTreeSwiftUIView: View {
    let rootPath: String
    let watcher: FileTreeWatcher
    @State private var rootNodes: [FileTreeNode] = []

    var body: some View {
        List {
            ForEach(rootNodes) { node in
                NodeRow(node: node, rootPath: rootPath, watcher: watcher)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .task(id: rootPath) { await loadRoot() }
    }

    private func loadRoot() async {
        do {
            let nodes = try await watcher.scan(rootPath: rootPath)
            rootNodes = nodes.map { FileTreeNode(node: $0) }
        } catch {
            rootNodes = []
        }
    }
}

@MainActor
private struct NodeRow: View {
    let node: FileTreeNode
    let rootPath: String
    let watcher: FileTreeWatcher
    @State private var isExpanded = false

    var body: some View {
        if node.node.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children ?? []) { child in
                    NodeRow(node: child, rootPath: rootPath, watcher: watcher)
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
                .onTapGesture(count: 2) { openFile() }
        }
    }

    private func rowLabel(systemImage: String) -> some View {
        Label(node.node.name, systemImage: systemImage)
            .help(node.node.path)
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

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func loadChildren() async {
        guard node.children?.isEmpty == true else { return }
        do {
            let childNodes = try await watcher.expand(node: node.node)
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
