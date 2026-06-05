import AppKit
import HarnessCore

@MainActor
final class WorkspaceFileTreeView: NSView, NSOutlineViewDelegate, NSOutlineViewDataSource {
    private let watcher = FileTreeWatcher()
    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private var rootItems: [FileTreeItem] = []
    private var rootPath: String

    init(rootPath: String? = nil) {
        self.rootPath = rootPath
            ?? SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd
            ?? NSHomeDirectory()
        super.init(frame: .zero)
        setupOutlineView()
        Task { [weak self] in
            await self?.loadRoot()
        }
    }

    func updateRoot(path: String) {
        guard path != rootPath else { return }
        rootPath = path
        Task { [weak self] in
            await self?.loadRoot()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupOutlineView() {
        translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.backgroundColor = .clear
        outlineView.rowHeight = 24
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.selectionHighlightStyle = .none
        outlineView.focusRingType = .none
        outlineView.style = .plain
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.doubleAction = #selector(doubleClickFile)

        // Right-click context menu
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu

        // Drag source
        outlineView.setDraggingSourceOperationMask(.copy, forLocal: false)
        outlineView.registerForDraggedTypes([.fileURL])

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsets = NSEdgeInsets(top: 2, left: 0, bottom: 6, right: 0)

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func loadRoot() async {
        do {
            rootItems = try await watcher.scan(rootPath: rootPath).map(FileTreeItem.init(node:))
            outlineView.reloadData()
        } catch {
            rootItems = []
            outlineView.reloadData()
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item = item as? FileTreeItem else { return rootItems.count }
        return item.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let item = item as? FileTreeItem else { return rootItems[index] }
        guard let children = item.children else { return item }
        return children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? FileTreeItem)?.node.isDirectory == true
    }

    func outlineViewItemWillExpand(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] as? FileTreeItem else { return }
        guard item.node.isDirectory, item.children == nil else { return }
        Task { [weak self, weak item] in
            guard let self, let item else { return }
            do {
                item.children = try await watcher.expand(node: item.node).map(FileTreeItem.init(node:))
            } catch {
                item.children = []
            }
            outlineView.reloadItem(item, reloadChildren: true)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? FileTreeItem else { return nil }
        let cell = FileTreeCellView()
        cell.configure(node: item.node)
        return cell
    }

    @objc private func doubleClickFile() {
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0,
              let item = outlineView.item(atRow: row) as? FileTreeItem,
              !item.node.isDirectory
        else { return }

        let coordinator = SessionCoordinator.shared
        coordinator.splitActivePane(direction: .horizontal)
        guard let surfaceID = coordinator.activeSurfaceID else { return }
        let command = "open \(item.node.path)\r"
        coordinator.requestDaemon(.sendData(surfaceID: surfaceID.uuidString, data: Data(command.utf8)))
    }

    // MARK: - Context menu

    private func clickedItem() -> FileTreeItem? {
        let row = outlineView.clickedRow
        guard row >= 0 else { return nil }
        return outlineView.item(atRow: row) as? FileTreeItem
    }

    @objc private func copyPath() {
        guard let item = clickedItem() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.node.path, forType: .string)
    }

    @objc private func copyRelativePath() {
        guard let item = clickedItem() else { return }
        let relative = item.node.path.replacingOccurrences(of: rootPath + "/", with: "")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(relative, forType: .string)
    }

    // MARK: - Drag source

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let item = outlineView.item(atRow: row) as? FileTreeItem else { return nil }
        return NSURL(fileURLWithPath: item.node.path)
    }
}

// MARK: - NSMenuDelegate

extension WorkspaceFileTreeView: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard clickedItem() != nil else { return }
        menu.addItem(NSMenuItem(title: "Copy Path", action: #selector(copyPath), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy Relative Path", action: #selector(copyRelativePath), keyEquivalent: ""))
    }
}

@MainActor
private final class FileTreeItem: NSObject {
    let node: FileNode
    var children: [FileTreeItem]?

    init(node: FileNode) {
        self.node = node
    }
}

@MainActor
private final class FileTreeCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = HarnessDesign.Radius.card
        layer?.cornerCurve = .continuous

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown

        titleLabel.font = HarnessDesign.Typography.sidebarLabel
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 7),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(node: FileNode) {
        iconView.image = icon(for: node)
        titleLabel.stringValue = node.name
        titleLabel.textColor = HarnessDesign.chrome.textSecondary
        toolTip = node.path
    }

    private func icon(for node: FileNode) -> NSImage? {
        if node.isDirectory {
            return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular))
        }
        let image = NSWorkspace.shared.icon(forFile: node.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
