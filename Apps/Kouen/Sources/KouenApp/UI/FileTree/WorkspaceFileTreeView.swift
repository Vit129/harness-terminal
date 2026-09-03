// ponytail: intentionally AppKit — SwiftUI List(children:) cannot reorder hierarchical nodes (macOS 26 limitation); NSDraggingItem preview customisation also requires AppKit.
import AppKit
import Observation
import SwiftUI
import KouenCore
import KouenTerminalKit

/// Mutable context observed by `FileTreeSwiftUIView`.
/// Mutating this is safe during a layout pass because SwiftUI will re-render
/// on the next cycle rather than replacing the hosting view's root struct.
@Observable
@MainActor
final class FileTreeContext {
    var rootPath: String
    var sessionID: SessionID?
    /// Set to scroll-and-highlight a file path in the tree; cleared after the scroll fires.
    var revealPath: String?

    init(rootPath: String, sessionID: SessionID?) {
        self.rootPath = rootPath
        self.sessionID = sessionID
    }
}

/// NSView wrapper that hosts `FileTreeSwiftUIView` inside the sidebar.
///
/// **Session-aware refresh (F1-A):** `updateRoot(path:sessionID:)` forces a
/// reload whenever the *session* changes, even if the directory path is the
/// same. This matters when two sessions share a repository root but are on
/// different git branches — the file tree must reflect the active session's
/// branch, not just the path.
@MainActor
final class WorkspaceFileTreeView: NSView {
    private let watcher = FileTreeWatcher()
    private let context: FileTreeContext
    private var hostingView: NSHostingView<FileTreeSwiftUIView>!
    private let scrollbar = TerminalScrollbarView()
    private weak var observedScrollView: NSScrollView?
    let keyboard = FileTreeKeyboardNavigator()

    var onFilePreview: ((FileNode) -> Void)?

    init(rootPath: String? = nil) {
        let initialPath = rootPath
            ?? SessionCoordinator.shared.snapshot.activeWorkspace?.activeTab?.cwd
            ?? NSHomeDirectory()
        let initialSessionID = SessionCoordinator.shared.snapshot.activeWorkspace?.activeSessionID
        self.context = FileTreeContext(rootPath: initialPath, sessionID: initialSessionID)
        super.init(frame: .zero)
        self.hostingView = NSHostingView(rootView: FileTreeSwiftUIView(
            context: context,
            watcher: watcher,
            keyboard: keyboard.state,
            onPreview: { [weak self] node in self?.onFilePreview?(node) }
        ))
        keyboard.onOpenFile = { [weak self] path in
            guard let self else { return }
            let url = URL(fileURLWithPath: path)
            let node = FileNode(id: path, name: url.lastPathComponent, path: path,
                                isDirectory: url.hasDirectoryPath)
            
            let coordinator = SessionCoordinator.shared
            let action = coordinator.settings.fileClickAction
            if action == "terminalOnly" {
                coordinator.splitActivePane(direction: .horizontal)
                guard let surfaceID = coordinator.activeSurfaceID else { return }
                let command = "open \(path)\r"
                coordinator.requestDaemon(.sendData(surfaceID: surfaceID.uuidString, data: Data(command.utf8)))
            } else if action == "vi" || action == "cat" {
                guard let surfaceID = coordinator.activeSurfaceID else { return }
                let cmd = action == "vi" ? "vi \(path)\r" : "cat \(path)\r"
                coordinator.requestDaemon(.sendData(surfaceID: surfaceID.uuidString, data: Data(cmd.utf8)))
            } else {
                self.onFilePreview?(node)
            }
        }
        keyboard.onPreviewFile = { [weak self] path in
            guard let self else { return }
            let url = URL(fileURLWithPath: path)
            let node = FileNode(id: path, name: url.lastPathComponent, path: path,
                                isDirectory: url.hasDirectoryPath)
            self.onFilePreview?(node)
        }
        keyboard.onToggleExpand = { token in
            if token.hasSuffix("__expand") {
                let path = String(token.dropLast("__expand".count))
                NotificationCenter.default.post(name: .fileTreeToggleExpand, object: nil,
                    userInfo: ["path": path, "action": "expand"])
            } else if token.hasSuffix("__collapse") {
                let path = String(token.dropLast("__collapse".count))
                NotificationCenter.default.post(name: .fileTreeToggleExpand, object: nil,
                    userInfo: ["path": path, "action": "collapse"])
            }
        }
        setup()
        registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if keyboard.handle(event) { return }
        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        externalFileDropOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        externalFileDropOperation(for: sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = KouenTerminalSurfaceView.droppedFileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        var copiedAny = false
        for url in urls {
            let dest = Self.uniqueDestination(base: context.rootPath, name: url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: dest))
                copiedAny = true
            } catch {
                NSSound.beep()
            }
        }
        if copiedAny {
            NotificationCenter.default.post(name: .fileTreeDidChange, object: nil)
        }
        return copiedAny
    }

    /// Rows in `FileTreeSwiftUIView` are drag *sources* only (`.onDrag`, to export to
    /// Finder/other apps) — there's no in-tree drop target, so any drag landing here is
    /// necessarily external (e.g. Finder).
    private func externalFileDropOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        guard !sender.draggingSourceOperationMask.isEmpty else { return [] }
        return KouenTerminalSurfaceView.droppedFileURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    /// Appends " 2", " 3", ... before the extension until `name` doesn't already exist
    /// under `base` — same collision-avoidance the tree's own New File/Folder use.
    private static func uniqueDestination(base: String, name: String) -> String {
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        var path = (base as NSString).appendingPathComponent(name)
        var i = 2
        while FileManager.default.fileExists(atPath: path) {
            path = (base as NSString).appendingPathComponent("\(stem) \(i)\(suffix)")
            i += 1
        }
        return path
    }

    /// Expands all ancestor directories of `path`, highlights it in the keyboard navigator,
    /// then signals the SwiftUI list to scroll to it after a short delay for child loading.
    func revealFileInTree(path: String) {
        let rootPrefix = context.rootPath.hasSuffix("/") ? context.rootPath : context.rootPath + "/"
        if path.hasPrefix(rootPrefix) {
            let relative = String(path.dropFirst(rootPrefix.count))
            let parentRelative = (relative as NSString).deletingLastPathComponent
            let components = parentRelative.components(separatedBy: "/").filter { !$0.isEmpty }
            var accumulated = context.rootPath
            for component in components {
                accumulated = (accumulated as NSString).appendingPathComponent(component)
                NotificationCenter.default.post(
                    name: .fileTreeToggleExpand,
                    object: nil,
                    userInfo: ["path": accumulated, "action": "expand"]
                )
            }
        }
        keyboard.state.focusedPath = path
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.context.revealPath = path
        }
    }

    func updateRoot(path: String, sessionID: SessionID?) {
        guard path != context.rootPath || sessionID != context.sessionID else { return }
        // Mutate the shared context instead of replacing hostingView.rootView.
        // Replacing rootView mid-layout-pass can leave AttributeGraph holding
        // stale @Observable references, causing a UAF crash in swift_getObjectType.
        context.rootPath = path
        context.sessionID = sessionID
    }

    private func setup() {
        attachHostingView()
    }

    /// Adds the hosting view and pins it to the edges. Idempotent: safe to call
    /// again after `viewWillMove(toWindow: nil)` detached it (see `didMoveToWindow`).
    private func attachHostingView() {
        guard hostingView.superview == nil else { return }
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        addSubview(scrollbar)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollbar.topAnchor.constraint(equalTo: topAnchor),
            scrollbar.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollbar.widthAnchor.constraint(equalToConstant: TerminalScrollbarView.stripWidth),
        ])
        scrollbar.applyColor(KouenChrome.current.textSecondary)
        scrollbar.onScrollToProgress = { [weak self] progress in
            guard let self, let scroll = self.findScrollView(), let doc = scroll.documentView else { return }
            let maxScroll = max(0, doc.frame.height - scroll.contentView.bounds.height)
            guard maxScroll > 0 else { return }
            let targetY = progress * maxScroll
            scroll.contentView.scroll(to: NSPoint(x: 0, y: targetY))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        setupScrollObservationIfNeeded()
    }

    override func layout() {
        super.layout()
        setupScrollObservationIfNeeded()
        fileTreeBoundsDidChange()
    }

    private func setupScrollObservationIfNeeded() {
        guard let scroll = findScrollView() else { return }
        if scroll !== observedScrollView {
            observedScrollView = scroll
            scroll.postsBoundsChangedNotifications = true
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(fileTreeBoundsDidChange),
                name: NSView.boundsDidChangeNotification,
                object: scroll.contentView
            )
            if let doc = scroll.documentView {
                doc.postsFrameChangedNotifications = true
                NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: nil)
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(fileTreeBoundsDidChange),
                    name: NSView.frameDidChangeNotification,
                    object: doc
                )
            }
        }
        scroll.verticalScroller?.isHidden = true
    }

    @objc private func fileTreeBoundsDidChange() {
        guard let scroll = observedScrollView ?? findScrollView(),
              let doc = scroll.documentView else { return }
        let totalHeight = doc.frame.height
        let visibleHeight = scroll.contentView.bounds.height
        let scrollY = scroll.contentView.bounds.origin.y
        scrollbar.show(
            topLine: Int(max(0, scrollY)),
            totalLines: Int(totalHeight),
            visibleRows: Int(visibleHeight)
        )
    }

    private func findScrollView() -> NSScrollView? {
        func search(_ v: NSView) -> NSScrollView? {
            if let s = v as? NSScrollView { return s }
            for sub in v.subviews {
                if let s = search(sub) { return s }
            }
            return nil
        }
        return search(hostingView)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            NotificationCenter.default.removeObserver(self)
            observedScrollView = nil
            // Detach the hosting view so SwiftUI stops re-evaluating the body
            // after the backing context is freed (zombie @Observable access → crash).
            // Also cancel pending layout to prevent a queued re-render race.
            hostingView?.needsLayout = false
            hostingView?.needsDisplay = false
            hostingView?.removeFromSuperview()
            scrollbar.removeFromSuperview()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Re-attach after returning to a window: `viewWillMove(toWindow: nil)`
        // removes the hosting view on detach, but the view can come back alive
        // (e.g. sidebar position swap removes/re-adds the container). Without this
        // the file tree stays permanently blank.
        if window != nil {
            attachHostingView()
            setupScrollObservationIfNeeded()
        }
    }
}
