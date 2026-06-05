# Domain Design: Harness IDE-like UI (File Tree & Git History)

## 1. Domain Overview

**Bounded Context**: Unified IDE-like Sidebar & Workspace Navigation
**Core Domain Focus**: Desktop folder trees, file event routing, and Git commit graph timeline rendering.
**Context Boundaries**: 
- **Included**: Local file tree outline structure, Git log graph parsing, Markdown and Monaco visual previews, and click-to-pane splitting rules.
- **Excluded**: File system editing (writing contents is owned by the PTY shell editors or WebKit instances), raw git CLI actions (Harness does not replace git commit/push buttons; it only shows history).

---

## 2. Domain Entities

### WorkspaceExplorer
**Type**: Aggregate Root
**Purpose**: Represents the directory tree of the currently active folder workspace.
**Identity**: `WorkspaceID` (UUID) mapped to the absolute root directory path.

**Attributes**:
- `rootPath`: `FilePath` - The absolute root path of the project.
- `rootNode`: `FileNode` - The top-level folder node.
- `isExpanded`: `Bool` - State of the sidebar column expansion.

**Business Rules**:
- A workspace folder must exist in the local OS file system.
- Scanning must be triggered on root directory modification.

**Invariants**:
- All sub-files and directories in the tree must be descendants of `rootPath`.

---

### FileNode
**Type**: Entity
**Purpose**: A single node in the folder outline representing a directory or file.
**Identity**: Absolute file path string.

**Attributes**:
- `path`: `FilePath` - The absolute path to the file/folder.
- `name`: `String` - Basename of the file.
- `isDirectory`: `Bool` - True if folder, false if file.
- `gitStatus`: `GitStatusType` - Modified, Added, Deleted, or Untracked.
- `children`: `[FileNode]` - List of child nodes (empty for files).

**Business Rules**:
- Children are sorted alphabetically with folders appearing first.

---

### GitCommitNode
**Type**: Entity
**Purpose**: Represents a single commit node inside the Git history graph.
**Identity**: Commit SHA hash string (e.g. `fcfd70b`).

**Attributes**:
- `sha`: `String` - Short and full SHA hash.
- `author`: `String` - Commit author name.
- `date`: `Date` - Commit timestamp.
- `message`: `String` - Short commit message summary.
- `parents`: `[String]` - Parent SHA hashes.
- `graphColumn`: `Int` - Visual column index for drawing branch lines.

---

## 3. Value Objects

### FilePath
**Purpose**: Validates and represents absolute directory and file paths.
**Immutability**: Yes.

**Properties**:
- `absoluteString`: `String` - The raw path string.

**Validation Rules**:
- Must be a valid POSIX path.
- Must not escape the parent workspace sandbox directory structure.

---

## 4. Aggregates

### WorkspaceOutline
**Aggregate Root**: `WorkspaceExplorer`
**Boundary**: Includes `FileNode`, `FilePath`
**Purpose**: Manages the file outline model. Ensure thread-safe updates when the file system changes.

**Consistency Rules**:
- Adding a file must append it to the correct parent `FileNode.children` in alphabetical order.

**Business Operations**:
- `scanDirectory()`: Triggers recursive, lazy-loaded folder scanner.
- `reloadNode(at:)`: Refreshes a sub-folder node.

---

### GitHistoryLog
**Aggregate Root**: `GitCommitNode`
**Boundary**: Includes list of `GitCommitNode` objects.
**Purpose**: Represents the parsed commit log ready to be rendered in the graph view.

**Consistency Rules**:
- History nodes must be ordered chronologically by commit date.

**Business Operations**:
- `parseGitLog(limit: 1000)`: Asynchronously runs git command and returns tree nodes.

---

## 5. Domain Events

### FileSelected
**Trigger**: Developer clicks a file node in the outline view.
**Purpose**: Alerts the view router to determine the appropriate viewer/editor pane.
**Data**: File path, file type, selection timestamp.

```
FileSelected {
  eventId: UUID
  filePath: String
  isDirectory: Bool
  timestamp: DateTime
}
```

---

### GitCommitSelected
**Trigger**: Developer clicks a commit cell in the history list.
**Purpose**: Displays the commit details and modified files list.
**Data**: Commit SHA hash, list of modified file paths.

```
GitCommitSelected {
  eventId: UUID
  commitSha: String
  modifiedFiles: [String]
  timestamp: DateTime
}
```

---

## 6. Domain Services

### FileClickRouter
**Purpose**: Determines how to route a file click event to the target viewport.
**Operations**:
- `route(file: FileNode, in: SessionTab)`: Analyzes file extension and chooses TUI Split (Option A), Native Preview (Option B), or Web Monaco (Option C).

---

## 7. Business Rules (Pseudocode)

### Routing File Clicks
```
WHEN FileSelected event is emitted
IF FileSelected.isDirectory is True
  THEN Toggle folder expansion state in OutlineView
ELSE
  LET fileExtension = getExtension(FileSelected.filePath)
  CASE fileExtension
    IN [".md", ".markdown"] ->
      EMIT OpenNativePreviewEvent(filePath)
    IN [".yaml", ".yml"] ->
      EMIT OpenMonacoWebviewEvent(filePath, previewStyle: "YAML")
    DEFAULT ->
      EMIT OpenTuiSplitEditorEvent(filePath)
  END
END
```

---

## 8. Success Criteria
- [x] WorkspaceExplorer, FileNode, and GitCommitNode entities defined.
- [x] FilePath value object defined.
- [x] Domain events (FileSelected, GitCommitSelected) specified.
- [x] FileClickRouter pseudocode logic documented.
