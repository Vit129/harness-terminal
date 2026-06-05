# Brainstorming & 3 Amigos Review: Harness IDE-like UI (File Tree & Git History)

## 1. Perspectives Summary

### Product Owner (PO) Perspective
- **Focus**: User Experience, Sleek Visuals, and Layout Simplicity.
- **Key Constraints**:
  - Resizing: When the user drags to expand into a double-column layout, the terminal grid must reflow cleanly without flickering.
  - Quick Toggles: Provide simple buttons (such as segment tabs in the sidebar header) to switch panels easily.
  - Mime-Routing: Selecting markdown files must show a clean read-only native preview. Clicking source code should seamlessly split the active pane and run the user's default TUI editor.

### Developer (Dev) Perspective
- **Focus**: Performance, Memory Footprint, and macOS Concurrency.
- **Key Challenges**:
  - **Non-blocking Scanning**: Reading workspace files must run on a background actor (`FileScannerActor`) to avoid freezing AppKit's Main Actor.
  - **WKWebView Lifecycle**: Starting WebKit view instances for Monaco is expensive (~100ms and ~80MB memory). We must cache a single reused view and dynamically reload content using JavaScript bindings (`webview.evaluateJavaScript`).
  - **Git Graph Drawing**: Rendering branch lines dynamically in `NSTableView` cells requires calculating parent-child commit paths and snapping bezier lines to integer cell coordinates to prevent wavy baseline lines.

### Quality Assurance (QA) Perspective
- **Focus**: Edge Cases, Performance Limits, and Robustness.
- **Key Risks & Solutions**:
  - **Huge Repositories**: Loading a folder with millions of files (like scanning `node_modules` or `.git` contents) will hang the app.
    - *Solution*: Force default ignore-filters in `FileTreeWatcher` for folders matching `.git`, `.build`, `node_modules`, and `.xcodeproj`.
  - **Giant Git Logs**: Repositories with over 100,000 commits.
    - *Solution*: Set an initial loading cap of 500 commits in `GitLogParser` and implement "Load More" scrolling pagination.
  - **Webview Crashes**: WebKit out-of-memory crashes due to loading huge YAML configuration files in Monaco.
    - *Solution*: Files larger than 2MB will bypass Monaco/Webview routing and fall back to opening in a standard terminal TUI split pane.

---

## 2. Key Action Items

1. **Implement Workspace Path Filters**: Standard directory exclusion list to bypass scanning node modules/build directories.
2. **Dynamic Sidebar Double-Column Resizer**: Clamp the minimum width of the double-column state to 320pt to prevent squishing the Session list card view.
3. **Monaco WebView Pre-warming**: Instantiate the single cached `MonacoEditorViewController` in the background during app startup to avoid open-flash latency.
