# Session Grouping and Split Session Plan

Status: done

## Context

The existing draft in `agent-memory/plan` proposes grouping sidebar sessions by
project folder. That direction is useful, but CMUX uses a stricter hierarchy:

```text
Window
  -> Workspace / sidebar entry
       -> Pane / split region
            -> Surface / tab within pane
                 -> Panel / terminal or browser content
```

For Harness, this means the sidebar grouping feature and split-session feature
should not be collapsed into one model change.

- Sidebar grouping is a presentation layer over existing sessions.
- Split-session is a structural feature inside the active session/tab area.
- Drag/drop, selection, and close actions must address real session IDs, not
  table row indexes, once group headers exist.

## Product Target

Match the grouped sidebar behavior shown in the reference screenshot:

- Project/group headers appear as quiet section labels.
- Sessions under the same project/root are visually grouped.
- Empty groups can show a muted "No threads yet" row only if the product later
  supports remembered projects without live sessions.
- Session cards keep existing hover close behavior.
- Search still filters sessions, and group headers only appear for groups that
  contain matching sessions.

For split sessions, match the CMUX concept rather than adding more top-level
sidebar rows:

- Sidebar entry selects a workspace/session group.
- The main content area owns panes.
- Each pane can contain terminal surfaces/tabs.
- Pane zoom temporarily fills the workspace without destroying the split layout.

## Track A: Sidebar Grouping

### 1. Add Project Group Heuristics

Target file:

- `Apps/Harness/Sources/HarnessApp/UI/HarnessDesign.swift`

Add a helper:

```swift
static func projectGroupName(for path: String) -> String
```

Rules:

- Walk upward from `path` until a `.git` file or directory is found.
- Use that directory name as the group name.
- If no `.git` root exists, use `pathDisplayName(path)`.
- Treat empty paths as `"Sessions"` or another stable fallback.
- Keep this helper pure and cheap enough for sidebar reloads.

### 2. Introduce Sidebar Row Model

Target file:

- `Apps/Harness/Sources/HarnessApp/UI/HarnessSidebarPanelViewController.swift`

Add a private enum near the sidebar state:

```swift
private enum SidebarSessionRow {
    case groupHeader(name: String)
    case session(SessionGroup)
}
```

Add helpers:

```swift
private var sidebarRows: [SidebarSessionRow] { ... }
private func sessionRow(at tableRow: Int) -> SessionGroup?
private func rowIndex(for sessionID: SessionID) -> Int?
```

Reason:

`displayedSessions` currently maps 1:1 to table rows. Group headers break that
assumption, so every selection, refresh, close, and drag operation must go
through a row-to-session mapping helper.

### 3. Build Grouped Rows From Filtered Sessions

Use `displayedSessions` as the filtered source.

Algorithm:

1. Map each session to a project group using its active tab cwd, falling back to
   first tab cwd.
2. Preserve the current session order inside each group.
3. Order groups by the first session index found in the existing session order.
4. Emit `.groupHeader(name)` followed by `.session(session)` rows.

This avoids surprising reorder behavior while still making the sidebar scannable.

### 4. Update Table Data Source and Delegate

Change:

- `numberOfRows(in:)` -> `sidebarRows.count`
- `tableView(_:viewFor:row:)` -> switch on `SidebarSessionRow`
- `tableViewSelectionDidChange(_:)` -> ignore group rows
- `selectSessionRow()` -> use `sessionRow(at:)`
- active row restore in `reload()` -> use `rowIndex(for:)`
- `refreshMetadata()` -> update only visible `SessionCardRowView` rows

Group header view:

- Use a simple `NSTableCellView`.
- Uppercase or semibold text, muted tertiary color.
- Height around 22-26 pt.
- No hover/selection chrome.

Session card row:

- Keep existing `SessionCardRowView`.
- Keep close button on hover.
- Keep context menu behavior.

### 5. Drag and Drop Rules

Current drag reorder uses table row index as session index. That will become
wrong once group headers exist.

Required changes:

- `pasteboardWriterForRow` should return nil for group headers.
- Store `session.id.uuidString` or equivalent stable session identifier in the
  pasteboard instead of table row.
- `validateDrop` should reject drops on/above group headers unless explicitly
  supporting cross-group moves.
- For the first implementation, keep reorder allowed only when search is empty
  and only between session rows.
- Translate drop row to a session target index in the underlying `sessions`
  array before calling `reorderSession`.

Recommended first pass:

- Allow reordering within the same visual group.
- Reject cross-group reorder until the product defines whether moving a session
  should also change its cwd/project grouping.

## Track B: Split Session Model

CMUX separates sidebar workspaces from split panes and per-pane tabs. Harness
already has pane/tree concepts (`PaneNode`, `zoomedPaneID`, tab roots), so the
plan should build on that instead of adding split rows to the sidebar.

### 1. Keep Split State In Session/Tab Structure

Do not encode split panes as sidebar groups.

Target areas:

- `Packages/HarnessCore/Sources/HarnessCore/Models/Tab.swift`
- `Packages/HarnessCore/Sources/HarnessCore/Session/SessionEditor.swift`
- `Apps/Harness/Sources/HarnessApp/UI/ContentAreaViewController.swift`

Expected behavior:

- Splits live inside the selected session/tab.
- Sidebar grouping remains project/session navigation.
- Pane zoom fills the current workspace area and restores the previous layout.

### 2. UX Entry Points

Preserve current commands where possible:

- Split horizontal / vertical from menu and keybindings.
- Pane zoom from command palette or keybinding.
- Tab drag/reorder remains in the tab bar, not the sidebar.

Future CMUX-style additions:

- Drag a tab to an edge to create a split.
- Drag tab between panes.
- Optional browser pane support if the product scope expands.

## Implementation Order

1. Implement `projectGroupName(for:)`.
2. Add `SidebarSessionRow` and mapping helpers.
3. Convert table data source to `sidebarRows`.
4. Fix selection and active row restore.
5. Fix metadata refresh for grouped rows.
6. Update drag/drop to use session IDs.
7. Add sidebar grouping tests where practical, or at minimum focused manual
   verification steps.
8. Only after grouped sidebar is stable, revisit split-session UX.

## Manual Verification

Use at least these cases:

- Multiple sessions under the same git repo show under one group.
- Sessions from different repos show separate headers.
- A session outside any git repo falls back to its folder name.
- Search filters sessions and hides empty group headers.
- Clicking a group header does nothing.
- Clicking a session selects it.
- Active session selection restores after snapshot reload.
- Hover close still appears only on session cards.
- Drag reorder does not allow dragging headers.
- Drag reorder does not reorder the wrong session after headers are visible.
- Existing split pane and pane zoom behavior still works in the main content
  area.

## Open Decisions

- Should groups be collapsible, or only static headers for the first version?
- Should Harness show empty remembered project groups like the screenshot's
  "No threads yet" state?
- Should cross-group drag be blocked, or should it become a session move command?
- Should grouping use git root, parent folder, workspace name, or a user-editable
  project label?

## Sources Reviewed

- CMUX Concepts: workspace is the sidebar entry, pane is the split region, and
  surface is a tab within a pane.
- CMUX Splits and panes: split panes live inside each workspace, pane zoom
  temporarily fills the workspace, and tabs can be organized within panes.
- Local Harness sidebar code: current `displayedSessions` maps directly to table
  rows, so grouped rows require explicit row/session mapping.
