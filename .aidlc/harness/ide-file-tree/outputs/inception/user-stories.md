# Product Backlog Items: Harness IDE-like UI (File Tree, Git History & File Viewers)

## PBIs (Product Backlog Items)

### PBI-001: Sidebar Layout & Navigation (Unified File Tree, Sessions & Git Tabs)
**Product Metrics:** User satisfaction with workspace setup time and context-switch speed. Measurable via reduction of shell navigation commands (`cd`, `ls`).

**Goal:** Allow developers to browse project files, manage multiple running PTY sessions, and view version control status in a unified, space-efficient sidebar.

**Persona:** Developer using Harness Terminal as their main local development workspace.

**Requirement:**
- The sidebar must support a tabbed selector at the top (or footer) to switch between three modes: Sessions, Files, and Git.
- The Files tab must display the workspace folder structure in a graphical tree (using `NSOutlineView` or SwiftUI `List`).
- The Files tab must have stacked collapsible sections (Accordion panels):
  - **Open Editors**: Showing currently active preview viewports.
  - **Project Files**: The folder tree of the workspace.
- The sidebar must support double-column expansion, allowing the user to pin the File Tree next to the active Session card list.

**User Flow:**
1. Developer opens Harness Terminal and presses `Cmd+\` to open the sidebar.
2. Developer clicks the "Files" icon/tab in the sidebar.
3. The Project Files accordion panel populates with the directory tree of the current workspace.
4. Developer double-clicks or expands folders to see sub-directories and files.
5. Developer drags the divider to expand the sidebar into a double-column layout to keep both Sessions and Project Files visible.

**Acceptance Criteria:**
* **Given** the developer has opened the sidebar, **when** they click the tab selector, **then** the view switches between Sessions, Files, and Git views.
* **Given** the Files tab is active, **when** a directory is loaded, **then** it displays a tree hierarchy containing subfolders and files with correct folder/file icons.
* **Given** the Files tab is active, **when** the user clicks the accordion headers, **then** the sections ("Open Editors", "Project Files") collapse or expand.
* **Given** the sidebar is open, **when** the user drags the sidebar divider past a threshold, **then** the sidebar transitions into a double-column mode displaying the Sessions list on the left and the Files tree on the right.

---

### PBI-002: Context-Aware File Click Router & Viewports (Code, MD & YAML)
**Product Metrics:** Reduction in the number of external windows opened (e.g. separate editor apps).

**Goal:** Enable quick viewing, editing, and previewing of files inside Harness without leaving the terminal environment, routing to the most appropriate editor/previewer based on file type.

**Persona:** Developer editing config files, markdown documents, and source files.

**Requirement:**
- Clicking a file in the File Tree must invoke a router (`FileClickRouter`) to open it.
- **MIME/Type Routing rules:**
  - **Code Files (e.g. `.swift`, `.py`, `.json`, `.js`):** Programmatically open a terminal split pane running a TUI editor (like `vim`, `helix`, or `micro`) and feed it the file path (Option A).
  - **Markdown Files (`.md`):** Open a Native macOS AppKit Preview viewport (Option B) that renders the markdown cleanly.
  - **YAML/Configuration Files (`.yaml`, `.yml`):** Open a Web-based Monaco Editor/Live Preview pane (Option C) running in a `WKWebView` to display the YAML structure and show a live visual result diagram or validation.
- Double-clicking any file always falls back to opening it in a split terminal pane using a TUI editor.

**User Flow:**
1. Developer clicks a source code file (`main.swift`) in the File Tree.
2. The router opens a new terminal pane split and executes `vim main.swift` (or the default TUI editor).
3. Developer clicks a documentation file (`README.md`).
4. The router opens a native preview pane on the right side of the active split layout showing the formatted markdown text.
5. Developer clicks a configuration file (`settings.yaml`).
6. The router opens a Monaco Editor split pane running WebKit, allowing visual validation of the YAML parameters.

**Acceptance Criteria:**
* **Given** the Files tree is visible, **when** the developer clicks a `.swift` file, **then** the router splits the active tab and executes the configured TUI editor command for that file.
* **Given** the Files tree is visible, **when** the developer clicks a `.md` file, **then** it opens a native macOS preview viewport showing formatted text with styled headings, code snippets, and lists.
* **Given** the Files tree is visible, **when** the developer clicks a `.yaml` file, **then** it opens a split pane hosting a `WKWebView` with Monaco Editor loading the file and displaying syntax validation.

---

### PBI-003: Native Git Tree & Commit History Timeline
**Product Metrics:** Ease of version control tracking within the terminal session.

**Goal:** Allow developers to visualize branching trees, commit logs, and staging states natively without leaving the terminal view.

**Persona:** Developer tracking code modifications and branches.

**Requirement:**
- The Git tab in the sidebar must show a native graphical timeline of commit history.
- The timeline must draw branch lines (branching and merging nodes) using CoreGraphics or AppKit cell rendering.
- It must list commits with author, date, and commit message.
- Clicking a commit must display a list of modified files and allow viewing diffs.

**User Flow:**
1. Developer clicks the "Git" tab in the sidebar.
2. The panel executes a git log command asynchronously in the background.
3. The UI renders a scrollable vertical list of commits with a graphical branch node path on the left edge.
4. Developer clicks a commit to see modified files.

**Acceptance Criteria:**
* **Given** the Git tab is selected, **when** a git repository is active, **then** the sidebar displays a native vertical list of recent commits parsed from the git history.
* **Given** the commit list is loaded, **when** rendering the cells, **then** it draws CoreGraphics line vectors connecting parent and child commits to visualize branches and merges.
* **Given** a commit cell is clicked, **when** the user selects it, **then** a detail popover or split pane displays the list of files changed in that commit.

---

## Business Rules
1. **No Blocked Main Actor:** All file scanning, git parsing, and WebKit initialization must run on background threads/actors, leaving the AppKit Main Actor completely free to handle terminal rendering and UI events without stuttering.
2. **Terminal Authority:** The terminal multiplexer and command prompt are always authoritative. Clicking GUI elements translates to PTY/multiplexer commands wherever possible (e.g. opening split panes uses the `split-window` command command under the hood).
3. **Workspace Bound:** File system operations and git logs must be scoped strictly to the current active workspace directory (or the parent git repo of the active terminal pane CWD).

---

## Non-Functional Requirements

### Performance Requirements
- **Sidebar Loading**: The file tree for directories with up to 10,000 files must populate in less than 200ms using lazy loading.
- **Git Timeline**: Git logs of up to 5,000 commits must be parsed and cached in under 300ms.
- **Memory Overhead**: The Webview Monaco editor instance must be cached and re-used to keep memory overhead below 80MB.

### Usability Requirements
- **Accessibility**: UI outline views must support voice-over narration and standard keyboard arrow navigation (Up/Down/Left/Right to expand folders).
- **Themes**: All new sidebar panels, timeline views, and web editors must inherit the current active Harness theme colors (e.g. canvas background, selection colors, text colors).

---

## Success Criteria
- [x] All high-priority user stories (PBI-001, PBI-002, PBI-003) are defined.
- [x] Each user story has clear Given-When-Then acceptance criteria.
- [x] Business rules are documented.
- [x] Non-functional requirements (performance, memory, usability) are defined.

## MVP Scope
**In MVP:**
- PBI-001 (Sidebar layout, File Tree outline view, accordion panels).
- PBI-002 (Context-aware routing, TUI split editor, native Markdown preview viewport).
- PBI-003 (Simplified Native Git history list with basic branch indicators).

**Post-MVP:**
- PBI-001 (Double-column sidebar expansion).
- PBI-002 (Webview Monaco editor and Live YAML result preview).
- PBI-003 (Full complex CoreGraphics branch timeline drawing).
