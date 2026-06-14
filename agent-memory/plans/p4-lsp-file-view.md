# P4 — LSP + File View (Code Preview in Sidebar)

Status: **Track 1 DONE (Syntax Highlighting)** — see "Implementation Notes" below  
Priority: **P1** — new feature  
Depends on: none (sidebar infrastructure exists)  
Branch: `worktree-p4-file-view`

---

## Implementation Notes (MVP — plain-text viewer)

Shipped a reduced Track 1 slice: **plain-text preview that replaces the file
tree in place** (no syntax highlighting / TreeSitter yet — descoped to avoid
the ~2MB grammar bundle and SPM resource setup for the MVP).

**New/changed files:**
- `Apps/Harness/Sources/HarnessApp/UI/FileViewerViewController.swift` (new) —
  read-only `NSTextView` in an `NSScrollView`, back button + path header,
  1MB size guard and binary/non-UTF8 placeholder messages. Uses
  `HarnessDesign` tokens throughout.
- `FileTreeSwiftUIView.swift` — `NodeRow` gained an `onPreview` callback;
  single-click previews a file, double-click still opens it in the terminal
  editor (disambiguated via `TapGesture(count:).exclusively(before:)`).
- `WorkspaceFileTreeView.swift` — exposes `onFilePreview` closure forwarded
  into the SwiftUI tree via a stable wrapper (no rebuild on assignment).
- `HarnessSidebarPanelViewController.swift` — hosts `FileViewerViewController`
  as a child VC layered over the same area as the file tree (`setupFileViewer`),
  toggles `.isHidden` on click / back / tab switch — same visibility-toggle
  pattern as the existing Sessions/Files/Git tabs (no NSViewController
  containment / navigation stack).

**UX model (current — to be replaced):** single-click a file *replaces* the
file tree view in the sidebar; a back arrow restores the tree. This was the
fastest integration given the sidebar's existing "swap visibility" pattern.

**Next planned change (per user 2026-06-07):** replace the in-place
replacement model with **browser-style tabs** — open files in tabs rather than
swapping out the tree. This is a UX redesign on top of the same
`FileViewerViewController`; expect to add a tab strip/host above or beside the
viewer and rework how `onFilePreview` routes (open-in-new-tab vs. reuse).

**Deferred (still in original plan scope):**
- Track 1 syntax highlighting (TreeSitter grammars — Swift/Python/TS/JS/JSON/YAML/MD/Rust/Go)
- Line numbers gutter
- Track 2 (Quick Look for images/PDFs via `QLPreviewView`)
- Track 3 (LSP integration)

See also `agent-memory/plans/file-viewer-integration.md` for a broader
Quick-Look + Monaco/LSP design sketch (separate, more ambitious proposal —
not what was implemented here).

---

## Goal

Click a file in the sidebar file tree → preview its content with syntax highlighting.  
Optionally connect to a running LSP server for go-to-definition, hover, diagnostics.

## Architecture

```
Sidebar File Tree (existing WorkspaceFileTreeView)
  └─ Click file → FileViewerViewController (new)
       ├─ Track 1: Native NSTextView + TreeSitter highlighting (fast, no dependencies)
       ├─ Track 2: QLPreviewView for images/PDFs (Quick Look)
       └─ Track 3: LSP client for diagnostics/hover/goto (optional, progressive)
```

## Track 1 — Syntax-Highlighted File Viewer (MVP)

> [!NOTE]
> **Track 1 — Syntax Highlighting: DONE**
> - Integrated `SyntaxTextView` with syntax highlighting (regex-based heuristics for 30+ languages including Swift, Python, JS/TS, Rust, Go, JSON, YAML, Markdown, Shell) into `FileViewerViewController`.
> - Preserved existing size guards (1MB), binary / unsupported encoding placeholders, scroll state, and copy/selection behaviors.
> - Created unit tests in `SyntaxHighlighterTests.swift` to verify syntax coloring on multiple fixtures.
> - Note: A dedicated CLI command like `harness cat` does not yet exist in the CLI target. Therefore, the CLI `--highlight` flag was skipped as outlined in the implementation guidelines.

### Components
- `FileViewerViewController` — replaces file tree when file is selected, back button returns to tree
- `SyntaxTextView` — NSTextView subclass with TreeSitter grammar highlighting
- TreeSitter grammars: Swift, Python, TypeScript, JavaScript, JSON, YAML, Markdown, Rust, Go

### Steps
1. Add `FileViewerViewController` to sidebar, triggered by file tree click
2. Read file content (< 1MB guard, show "file too large" for bigger)
3. Apply TreeSitter highlighting via bundled grammars
4. Line numbers gutter
5. Read-only (no editing — terminal is the editor)
6. Copy selection, Cmd+A select all
7. Back button / Escape returns to file tree

### Grammars
Bundle as SPM resources (`tree-sitter-swift`, `tree-sitter-typescript`, etc.) — ~2MB total.

## Track 2 — Quick Look Preview

For non-code files (images, PDFs, rich documents):
- Use `QLPreviewView` embedded in the same `FileViewerViewController`
- Route by MIME type: code → SyntaxTextView, image/pdf → QLPreviewView

## Track 3 — LSP Integration (Post-MVP)

### Architecture
```
LSPClient (new, Packages/HarnessLSP/)
  ├─ Connects to running LSP server (sourcekit-lsp, tsserver, pyright, etc.)
  ├─ JSON-RPC over stdio pipe
  └─ Provides: diagnostics, hover, go-to-definition, symbol outline

FileViewerViewController
  └─ Subscribes to LSPClient for:
       - Inline diagnostics (red/yellow underlines)
       - Hover popup on mouse-over
       - Cmd+Click → go-to-definition (open that file)
       - Outline panel (document symbols)
```

### LSP Discovery
- Detect project type from root files (Package.swift → sourcekit-lsp, package.json → tsserver)
- Auto-start LSP server as child process (or reuse running one)
- Settings: `lsp.autoStart`, `lsp.servers` (custom binary paths)

### Steps
1. `LSPClient` — JSON-RPC stdio transport, initialize/shutdown lifecycle
2. `LSPServerRegistry` — auto-detect + launch LSP per project type
3. Wire diagnostics to SyntaxTextView (underlines + gutter markers)
4. Hover provider → popover with type info
5. Go-to-definition → navigate FileViewerViewController to target file:line

## Files

| File | Purpose |
|------|---------|
| `Apps/Harness/Sources/HarnessApp/UI/FileViewerViewController.swift` | New — file preview controller |
| `Apps/Harness/Sources/HarnessApp/UI/SyntaxTextView.swift` | New — highlighted text view |
| `Packages/HarnessLSP/` | New package — LSP client |
| `Apps/Harness/Sources/HarnessApp/UI/WorkspaceFileTreeView.swift` | Modify — route clicks to viewer |

## Estimate

- Track 1 (syntax viewer): 1–2 sessions
- Track 2 (Quick Look): 0.5 session
- Track 3 (LSP): 3–4 sessions
