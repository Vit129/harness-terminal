# Plan: Inception & Requirements - Zed-like File Tree & Git History

## Status: Planning

## Objective
Establish complete specs, user stories, domain models, logical designs, and a finalized developer plan for implementing the Hybrid Sidebar (File Tree, Git Timeline) and the Context-aware File Click router in Harness Terminal.

## Decision Reference
**Based on decisions from**: [../decisions/00-inception-decisions.md](../decisions/00-inception-decisions.md)

## Task Breakdown

### Phase 1: Requirements Gathering (User Stories)
*This phase defines the user stories and detailed acceptance criteria in BDD format (Given/When/Then).*
- [ ] Task 1.1: Create `.aidlc/harness/ide-file-tree/outputs/inception/user-stories.md`. Write user stories for:
  - US-1: Sidebar layout with tabs (Files, Sessions, Git) and expandable columns.
  - US-2: Accordion panels in the Files tab (Workspace tree vs Open editors).
  - US-3: Clicking files (code opens TUI split, `.md`/`.yaml` opens native/webview preview).
  - US-4: Git branch timeline and history tree rendered natively.
  - *Source*: Read user requirements from the current chat context.

### Phase 1.2: Domain Decomposition
*This phase identifies the bounded contexts, aggregates, and entities required.*
- [ ] Task 1.2: Create `.aidlc/harness/ide-file-tree/outputs/inception/domain-decomposition.md`. Define:
  - Bounded Contexts: Sidebar UI Context, Workspace File Watcher Context, Git Operations Context, Document Viewer/Editor Context.
  - Aggregates/Entities: WorkspaceFolder, FileNode, GitCommit, GitBranchNode, OpenFileEditor.
  - *Source*: Read `user-stories.md` and `HarnessSidebarPanelViewController.swift`.

### Phase 1.4: Domain Design
*This phase designs the domain events, commands, and interfaces.*
- [ ] Task 1.3: Create `.aidlc/harness/ide-file-tree/outputs/inception/domain-design.md`. Design:
  - Domain commands (e.g. `openFile`, `selectSidebarTab`, `toggleDoubleColumn`).
  - Domain events (e.g. `fileModified`, `activeTabChanged`, `gitCommitSelected`).
  - Interfaces for FileWatcher and GitTimelineParser.
  - *Source*: Read `domain-decomposition.md`.

### Phase 1.6: Logical Design
*This phase diagrams the system architecture, component relationships, data flow, and file targets.*
- [ ] Task 1.4: Create `.aidlc/harness/ide-file-tree/outputs/inception/logical-design.md`. Outline:
  - AppKit view hierarchy changes (`HarnessSidebarPanelViewController` to host tab views, segmented controls).
  - File Explorer module: `FileTreeView` (using `NSOutlineView`), file change subscriber.
  - Git timeline module: `GitHistoryTimelineView` (custom cell drawing for lines/nodes).
  - Routing engine: `FileClickRouter` determining how file extensions match preview view controllers vs PTY split-pane commands.
  - Webview editor: integration of Monaco Editor inside a subview.
  - *Source*: Read `domain-design.md` and `HarnessSidebarPanelViewController.swift`.

### Phase 1.8: Brainstorming (3 Amigos)
*This phase runs a review loop using simulated PO, Dev, and QA perspectives.*
- [ ] Task 1.5: Create `.aidlc/harness/ide-file-tree/outputs/inception/brainstorming-summary.md`. Brainstorm:
  - Gaps in current AppKit layouts (how to handle width constraints).
  - Performance: making sure file system watching does not block the UI thread.
  - Edge cases: giant repositories (millions of files) or huge git logs.
  - *Source*: Read `logical-design.md` and run review loop.

---

## Success Criteria (Process Validation)
- [ ] Requirements, domain decomposition, domain design, logical design, and brainstorming files are created in `.aidlc/harness/ide-file-tree/outputs/inception/`.
- [ ] User stories include detailed Given/When/Then acceptance criteria.
- [ ] Logical design maps out exact Swift files/classes to be created or modified.
- [ ] User approval obtained on deliverables.
