# Implementation Plan: Harness IDE-like UI (File Tree & Git History)

## Status: Planning

## Objective
Implement MVP features of the Harness IDE-like UI: tab selector with accordion panel for File Tree in the sidebar, a routing system to preview markdown/YAML files natively or in TUI split panes, and a native Git history commit list.

## Decision Reference
**Based on decisions from**: [../decisions/00-inception-decisions.md](../decisions/00-inception-decisions.md)

## User Story Mapping (MANDATORY)
**Source**: Reference `outputs/inception/user-stories.md`

### MVP User Stories (Must Implement)
- [ ] **PBI-001**: Sidebar Layout & Navigation - Switch between Sessions, Files, and Git views with accordion outline panels for files.
- [ ] **PBI-002**: Context-Aware File Click Router - Clicking code opens TUI editor in split pane, clicking `.md` opens native macOS viewport preview.
- [ ] **PBI-003**: Native Git Commit History - Vertical scrollable timeline of commits with basic graphical indicators in the Git tab of the sidebar.

### Future User Stories (Post-MVP)
- [ ] **PBI-001-Ext**: Double-column sidebar layout.
- [ ] **PBI-002-Ext**: Web-based Monaco Editor/Live YAML visual previewer inside splits.
- [ ] **PBI-003-Ext**: Complex CoreGraphics branch line graph drawing in the commit list.

---

## Feature Implementation Plan

### Phase 1: Sidebar Tabs & File Outline Tree - Status: Not Started
**User Stories**: PBI-001
**Target**: Sidebar UI tab switching and directory tree listing.

- [ ] Task 1.1: Modify `Apps/Harness/Sources/HarnessApp/UI/HarnessSidebarPanelViewController.swift` to add a Segmented Control selector in the header row, switching the table between Sessions, Files, and Git.
  - *Source*: Read `HarnessSidebarPanelViewController.swift` lines 1-150.
- [ ] Task 1.2: Create `Packages/HarnessCore/Sources/HarnessCore/FileExplorer/FileNode.swift` to define the recursive node data model, including file name, absolute path, type (dir vs file), and status.
  - *Source*: Read `outputs/inception/logical-design.md` Section 5.2.
- [ ] Task 1.3: Create `Packages/HarnessCore/Sources/HarnessCore/FileExplorer/FileTreeWatcher.swift` to scan the active directory asynchronously using a background actor and register a folder watcher.
  - *Source*: Read `outputs/inception/logical-design.md` Section 3.1.
- [ ] Task 1.4: Create `Apps/Harness/Sources/HarnessApp/UI/WorkspaceFileTreeView.swift` implementing `NSOutlineViewDelegate` & `NSOutlineViewDataSource` to render folders and files with visual icons. Add to the accordion panel container.
  - *Source*: Read `HarnessSidebarPanelViewController.swift` and `logical-design.md` Section 6.1.

**Acceptance**: User can open the sidebar, click the "Files" tab, and expand/collapse the local project folders in a graphical tree.
**User Stories Validated**: PBI-001 core features implemented.

---

### Phase 2: File Click Router & Document Viewports - Status: Not Started
**User Stories**: PBI-002
**Target**: Smart routing of file click actions to TUI splits or native previews.

- [ ] Task 2.1: Create `Packages/HarnessCore/Sources/HarnessCore/Routing/FileClickRouter.swift` to detect extension/mime-type. Route code files to PTY split panes, and `.md` files to the native viewer.
  - *Source*: Read `outputs/inception/domain-design.md` Section 7.
- [ ] Task 2.2: Create `Apps/Harness/Sources/HarnessApp/UI/DocumentViewerViewController.swift` to render Markdown documents natively as styled AppKit text containers.
  - *Source*: Read `logical-design.md` Section 6.1.
- [ ] Task 2.3: Integrate routing in `WorkspaceFileTreeView` click events. Hook double-clicks to launch TUI editor splits using `SessionCoordinator.shared` IPC calls.
  - *Source*: Read `WorkspaceFileTreeView.swift` and `SessionCoordinator.swift`.

**Acceptance**: Clicking a `.swift` file opens a terminal pane running a TUI editor. Clicking a `.md` file opens a native read-only formatted text preview panel.
**User Stories Validated**: PBI-002 core features implemented.

---

### Phase 3: Git Log Timeline UI - Status: Not Started
**User Stories**: PBI-003
**Target**: Render a native commit log history in the Git tab.

- [ ] Task 3.1: Create `Packages/HarnessCore/Sources/HarnessCore/Git/GitLogParser.swift` to execute `/usr/bin/git log` asynchronously using `Process` (NSTask) and parse hash, message, date, and branch graph columns.
  - *Source*: Read `logical-design.md` Section 5.3.
- [ ] Task 3.2: Create `Apps/Harness/Sources/HarnessApp/UI/GitHistoryTimelineView.swift` containing an `NSTableView` showing the list of parsed commits. Override cell drawing to render branch line nodes.
  - *Source*: Read `logical-design.md` Section 6.1.
- [ ] Task 3.3: Hook Git tab in the sidebar header to load and display the timeline view on click.
  - *Source*: Read `HarnessSidebarPanelViewController.swift`.

**Acceptance**: Clicking the "Git" tab displays recent commit history with branch graph lines drawn in the list.
**User Stories Validated**: PBI-003 core features implemented.

---

## Technical Setup

### Project Structure
New source files will be integrated directly into the `Apps/Harness` and `Packages/HarnessCore` targets as specified in the directory layout of `logical-design.md`.

---

## Success Criteria (Implementation Validation)
- [ ] Outline view is loaded and populates directory files.
- [ ] Markdown files open native previews, while code files open splits running TUI editors.
- [ ] Git commit timeline displays branch graph lines and commit details.
- [ ] All file system and Git operations execute off the Main Actor.
