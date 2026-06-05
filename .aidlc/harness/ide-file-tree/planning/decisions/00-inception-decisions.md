# Decision Record: Inception - Zed-like File Tree & Git History
 
## Status: Decided

## Background
- **What is this feature?** A native project/file explorer panel in the sidebar similar to Zed, combined with a Git tree/history viewer, interactive click-to-edit/preview for code, `.md`, and `.yaml` files inside terminal split panes.
- **What already exists?** Harness has a sidebar implemented in `HarnessSidebarPanelViewController` showing active sessions/agents, and a PTY tracker `SurfaceShellTracker` that watches directory changes (CWD) and git branches.
- **What is missing?** Graphical File Tree (folder outline), Git history timeline UI, and click-to-open integration between the GUI sidebar and the Terminal editor panes.

---

## Outstanding Decisions

### Decision 1: Sidebar Layout & Integration
**Context**: We need to decide how to present the new File Explorer (File Tree) and Git History alongside the existing Session rail in the Sidebar.

**Options**:
- **A) Multi-tab Sidebar (Unified Panel)**
  - *Rationale*: Switches between tabs (Sessions, File Tree, Git) in the same narrow sidebar space. Saves screen real estate.
  - *Consequences*: User can only see one view at a time. Requires custom tab switching buttons at the top/bottom of the sidebar.
- **B) Double Sidebar Columns (Split Sidebar)**
  - *Rationale*: A secondary column next to the Session card list specifically for the File Tree/Git Tree, similar to traditional IDE sidebars.
  - *Consequences*: Takes up more horizontal screen width. Provides constant visibility of both sessions and files.
- **C) Accordion Panels (Stacked Sections)**
  - *Rationale*: Stacked collapsible header panels (e.g. "Workspaces/Sessions", "File Explorer", "Git History") in a single sidebar.
  - *Consequences*: Clean visual structure. Vertically crowded if all panels are expanded.

**Recommendation**: Option A is recommended for keeping the terminal's compact and sleek design, with quick toggles (e.g., icons in the footer or header).

**Decision**: A + B + C (Hybrid Layout)
**Additional Rationale**: Combine all three for maximum flexibility: Use a Multi-tab Sidebar (Option A) to switch between context modes. In File Explorer mode, show stacked Accordion Panels (Option C) for Open Editors vs Workspace File Tree. If the user wants, allow expanding the sidebar into a Double Sidebar Column layout (Option B) to pin folders next to the active Session list.
**Additional Consequences**: Higher UI complexity. The layout engine needs to adapt dynamically to single-column vs double-column states.

---

### Decision 2: File Click Interaction (Editing & Previews)
**Context**: How clicking files (especially `.md`, `.yaml`, and source code) in the File Tree interacts with the editor or preview panels.

**Options**:
- **A) Auto-open Editor/Viewer in Split Pane (Terminal-native)**
  - *Rationale*: When a file is clicked, programmatically open the system default editor (e.g. `vim`, `nano`, or a TUI editor like `helix`/`micro`) in the active terminal pane or a new split pane using the existing PTY command-sending engine (`harness-cli send-keys`).
  - *Consequences*: Extremely lightweight, keeps terminal focus, uses command line tools already installed. No rendering lag.
- **B) Native macOS Viewport Preview (GUI Editor Component)**
  - *Rationale*: Implement a custom native AppKit text editor/preview panel that sits inside the Content Split, separate from the terminal shell grids.
  - *Consequences*: Requires implementing native markdown rendering and code editor views in Swift. Heavy development effort.
- **C) Web-based editor/preview pane (Monaco/Webview)**
  - *Rationale*: Open a split panel embedding an `WKWebView` running a local editor (like Monaco Editor) or markdown preview.
  - *Consequences*: High-fidelity preview, but increases memory footprint and adds dependency on WebKit.

**Recommendation**: Option A is recommended because Harness is fundamentally a terminal multiplexer. Utilizing TUI editors in splits matches its architecture.

**Decision**: A + B + C (Context-aware Routing)
**Additional Rationale**: Support all three depending on file type and user preference: Clicking code files launches a TUI editor (Option A) in a terminal split pane. Clicking `.md` or `.yaml` files opens a Native macOS Viewport Preview (Option B) for quick read-only document browsing, with the ability to switch to a Web-based Monaco Editor/Live Preview pane (Option C) for rich IDE-like editing/YAML visual results.
**Additional Consequences**: Requires complex routing logic based on file extension and mime-type.

---

### Decision 3: Git Tree and Commit History View
**Context**: We need to choose how the Git branch tree and commit history will be visualized.

**Options**:
- **A) Native AppKit Commit Timeline**
  - *Rationale*: A custom scrollable list of commits in the sidebar showing author, date, and changes, using `NSTableView` with lines drawn for branches.
  - *Consequences*: Clean UI matching macOS appearance. Requires parsing git logs manually via NSTask subprocesses.
- **B) TUI Git split pane (e.g. lazygit integration)**
  - *Rationale*: Clicking "Git History" opens a terminal pane running a Git TUI client (like `lazygit` or `tig`) automatically.
  - *Consequences*: Instantly available without writing rendering logic, but does not look like a native GUI sidebar component.
- **C) Hybrid sidebar list**
  - *Rationale*: A simplified sidebar list of modified files (Git Status) and recent commits, leaving heavy operations to shell commands.
  - *Consequences*: Moderate development effort. Provides the essential status at a glance.

**Recommendation**: Option C provides the best balance of native utility and development efficiency.

**Decision**: A (Native AppKit Commit Timeline)
**Additional Rationale**: Implement a native graphical timeline of git history within the Git tab in the sidebar. This makes Harness feel like a true standalone development environment (IDE) rather than just a wrapper around CLI commands.
**Additional Consequences**: Requires writing Swift code to execute git CLI commands, parse the output, and draw the visual branch lines (commit graph) using CoreGraphics or custom cell rendering.

---

## Decision Summary

| Decision | Chosen Option | Rationale | Impact |
|----------|---------------|-----------|--------|
| Sidebar Layout | A + B + C | Hybrid collapsible tab panel + dual column layout | High |
| File Click Interaction | A + B + C | Context-aware routing (TUI splits + Native Preview + Monaco) | High |
| Git View | A | Native commit timeline with graphical branch lines | High |

## Next Steps
1. Create Phase 1.1 Requirements document (`outputs/inception/user-stories.md`).
2. Proceed with Inception Phase.
