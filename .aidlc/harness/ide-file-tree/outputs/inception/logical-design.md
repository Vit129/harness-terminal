# Logical Design: Zed-like File Tree & Git History

## 1. User Story Mapping

| User Story ID | Description | Backend/Core Components | Frontend/UI Components | MVP |
|---------------|-------------|-------------------|-------------------|-----|
| US-001 | Unified Sidebar Layout with Tabs (Files, Sessions, Git) | `HarnessCore.SessionCoordinator` | `SidebarTabSelector`, `HarnessSidebarPanelViewController` | ✅ |
| US-002 | Accordion Outline folder tree | `HarnessCore.FileTreeWatcher`, `FileNode` | `WorkspaceFileTreeView` (`NSOutlineView`) | ✅ |
| US-003 | Click file -> Split TUI pane / Native MD preview / Monaco YAML preview | `HarnessCore.FileClickRouter`, `CLICommandRouter` | `MarkdownPreviewViewController`, `MonacoEditorWebViewController` | ✅ |
| US-004 | Native Git timeline & commit branch lines drawing | `HarnessCore.GitLogParser` | `GitHistoryTimelineView` (Custom AppKit Cell rendering) | ✅ |

---

## 2. Non-Functional Requirements

| Category | Requirement | Technical Impact | User Story |
|----------|-------------|------------------|------------|
| Performance | Render File Tree outlines with 10k+ nodes without UI lag. | Scan folders recursively on a background thread using Swift Actor (`FileScannerActor`). | US-002 |
| Performance | Commit list rendering must draw CoreGraphics lines at 60fps. | Cache parsed commit branch nodes and only redraw changed cells. | US-004 |
| Memory | Embedded Monaco editors must not leak. | Cache a pool of maximum 2 `WKProcessPool` instances and reuse WebViews. | US-003 |

---

## 3. Project Structure

### 3.1 Directory Layout (Monolith Structure)
```
harness/
├── Apps/Harness/Sources/HarnessApp/
│   ├── Services/
│   │   ├── SurfaceShellTracker.swift (Read CWD/Git)
│   │   └── SessionCoordinator.swift
│   └── UI/
│       ├── HarnessSidebarPanelViewController.swift (Modify for tabs)
│       ├── WorkspaceFileTreeView.swift (New OutlineView)
│       ├── GitHistoryTimelineView.swift (New commit timeline)
│       ├── DocumentViewerViewController.swift (New Native MD viewer)
│       └── MonacoEditorViewController.swift (New Monaco WebView)
├── Packages/HarnessCore/Sources/HarnessCore/
│   ├── FileExplorer/
│   │   ├── FileNode.swift (Data structure)
│   │   └── FileTreeWatcher.swift (Async folder scanner)
│   ├── Git/
│   │   ├── GitCommitNode.swift
│   │   └── GitLogParser.swift (Command parser)
│   └── Routing/
│       └── FileClickRouter.swift (Click actions routing engine)
└── Tests/
    ├── HarnessCoreTests/
    │   └── FileClickRouterTests.swift
    └── HarnessTerminalKitTests/
        └── FileTreeWatcherTests.swift
```

---

## 4. Technical Architecture

### 4.1 Architecture Pattern
- **Choice**: Modular Monolith on macOS AppKit desktop application framework.
- **Reasoning**: All components run locally in a single macOS process, communicating via direct in-memory API calls, standard delegation, and local PTY UNIX sockets.

### 4.2 Technology Stack
| Category | Choice | Source |
|----------|--------|--------|
| Frontend UI | AppKit (NSViewController, NSOutlineView, NSTableView) | Main macOS project stack |
| Concurrency | Swift 6 async/await, Actors | Codebase strict concurrency guidelines |
| Web Integration | WebKit (WKWebView) | Monaco editor hosting |
| Git access | shell execution of `/usr/bin/git` | Process (NSTask) calls |

---

## 5. Backend/Core Logic Design

### 5.1 System APIs and IPC Protocols
No new daemon IPC messages are required since the File explorer and Git parsing run directly on the client side (AppKit App process). However, file double-clicks will call the existing daemon IPC:
- `split-window` (creates a pane split)
- `send-keys` (runs TUI commands)

### 5.2 Core Data Models

#### FileNode
```swift
struct FileNode: Identifiable {
    let id: String // Absolute path
    let name: String
    let isDirectory: Bool
    var children: [FileNode]?
    var gitStatus: GitStatusType
}
```

#### GitCommitNode
```swift
struct GitCommitNode: Identifiable {
    let id: String // SHA
    let author: String
    let date: Date
    let message: String
    let parentSHAs: [String]
    var graphColumn: Int // Calculated offset for line drawing
}
```

### 5.3 Business Logic (Pseudo-code)

#### Git Commit Graph Branch Line Parsing Algorithm
```
1. Run `git log --graph --pretty=format:"%h|%p|%an|%ad|%s" -n 500`
2. Map lines. Read parents, assign columns:
   - Keep a list of active columns.
   - For each commit, if its SHA matches an active column, use it.
   - Draw lines from parents to child nodes based on SHA connections.
```

---

## 6. Frontend / UI Design

### 6.1 UI Components

#### WorkspaceFileTreeView
- Implements `NSOutlineViewDelegate` and `NSOutlineViewDataSource`.
- Connects to `FileTreeWatcher` to refresh dynamically on file additions/deletions.

#### GitHistoryTimelineView
- Implements `NSTableViewDelegate` with a custom `NSTableCellView` cell.
- Overrides `draw(_ dirtyRect: NSRect)` in the cell view to draw vector lines for branching/merges using `NSBezierPath` based on `GitCommitNode.graphColumn`.

#### MarkdownPreviewViewController
- Parses Markdown text into styled `NSAttributedString` matching the active Harness theme.

#### MonacoEditorViewController
- Instantiates a single `WKWebView` and loads Monaco Editor with dark mode and YAML validation plugins.

---

## 7. MVP Implementation Plan

### Phase 1: Sidebar Tabs & File Explorer
- Modify `HarnessSidebarPanelViewController` to show Segmented Controls (Sessions, Files, Git).
- Build `WorkspaceFileTreeView` outline list showing directories under active CWD.

### Phase 2: Context Router & Viewports
- Build `FileClickRouter` rules.
- Add `MarkdownPreviewViewController` and Monaco webview panel inside splits.

### Phase 3: Git timeline
- Build Git commit parser.
- Render Git history list with graphical lines.

---

## 8. Validation Checklist
- [x] Folder structures and paths defined.
- [x] NSOutlineView and Custom Cell drawings mapped.
- [x] Subprocess git process logging defined.
- [x] Markdown previewer and Monaco WebView mapped.
