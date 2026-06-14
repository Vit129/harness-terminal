# P4 — Terminal-First Code Viewing + Lightweight LSP

Status: **Track 1 DONE; Track 2: PBI-VI-001/002/003 DONE; Track 3: PBI-LSP-001/002/003 DONE**
Priority: **P1** — terminal convenience, not IDE replacement
Depends on: terminal/file viewer infrastructure already exists
Branch: `worktree-p4-track23`

---

## Direction

Harness is returning to a **terminal + Unix + vi command** identity.

The IDE-style panels remain convenience surfaces only. P4 should not become a
test/debugging workbench or VS Code clone. It should add code awareness in the
same spirit as terminal tools:

- Commands first (`view`, `cat`, `lsp`, `:gd`, `:K`)
- Deterministic stdout by default
- Optional annotations through flags, overlays, or side-channel panes
- Vi-style navigation for reading and jumping
- Syntax highlighting like a polished terminal/site code sample, not a full IDE

## Current Shipped State

- `FileViewerViewController` reads files safely with a size guard and binary/non-UTF8 placeholders.
- File tree single-click previews a file; double-click still opens it in the terminal editor.
- Sidebar swaps between file tree and preview with a back affordance.
- **Track 1 (Syntax Highlighting) is DONE** — `SyntaxTextView` (regex-based heuristics, 30+ languages incl. Swift/Python/JS/TS/Rust/Go/JSON/YAML/Markdown/Shell) is wired into `FileViewerViewController`, preserving the size guard, binary/non-UTF8 placeholders, and copy/select/scroll behavior. Covered by `Tests/HarnessAppTests/SyntaxHighlighterTests.swift`. Known gap: no `harness cat --highlight` CLI flag (no `cat`/`view` CLI subcommand exists yet — see Track 1 follow-up note in PBI-VI-002 below, which introduces `harness view`).
- `HarnessLSP` package already has a working `LSPClient` (Content-Length JSON-RPC transport, `initialize`/`openDocument`/`hover`/`definition`), `LSPServerRegistry` (auto-detect server binary per language/project root), and models for Position/Range/Diagnostic/Location/Hover. `LSPFileSession` wraps this and is wired into `FileEditorView` (hover + go-to-definition + diagnostics gutter via `SyntaxTextView`). It is currently GUI-only (no CLI/daemon exposure) and disabled in `FileViewerViewController`.
- Vi normal mode (`ViNormalMode.swift`, ~1700 lines) already implements motions, operators, text objects, marks, registers, macros, jump list, and ex commands `:N`, `:w/:q/:wq/:x`, `:bn/:bp/:ls`, `:e <path>`, `:s///`, `:set ...`. It does **not** yet implement `gf`, `gd`, `K`, `]d`/`[d`, or `:find`/`:view`/`:split <path>`/`:vsplit <path>`/`:cd`/`:mark`/`:copy-path`/`:recent`.
- `CommandPaletteController` already has a `FuzzyMatcher` (prefix/word-start/consecutive scoring) and async file scanning used for Cmd+K file quick-open — reusable for `:find`.

## Non-Goals

Do **not** add these to P4:

- Test runner panel
- Debugger panel
- Breakpoints/watch variables/call stack
- Heavy IDE project model
- Always-on diagnostics that mutate normal terminal command output
- Full editor replacement for `$EDITOR`, Vim, Neovim, or shell tools
- `harness lsp` references/code-lens/completion (only hover/definition/diagnostics in this pass)
- Unifying `ACPTransport`/`LSPTransport` duplication (noted as cleanup follow-up, not in scope)

## Target Model (reference — see PBI breakdown for what ships now)

### 1. Syntax-Highlighted View/Cat — DONE (Track 1)

```bash
harness view src/App.swift        # PBI-VI-002
harness cat src/App.swift --highlight   # follow-up, not in this pass
harness cat src/App.swift --diagnostics # follow-up, not in this pass
```

`harness cat <file>` stays plain/deterministic unless flags request decoration
(no `cat` command exists yet at all — out of scope here; `harness view` is the
new minimal command added by PBI-VI-002).

### 2. Path-Under-Cursor Actions (PBI-VI-001)

| Action | Meaning |
|---|---|
| `gf` | open path under cursor |
| `gd` | go to definition (LSP) |
| `K` | hover info (LSP) |
| `]d` / `[d` | next/previous diagnostic (LSP) |

### 3. Path Discovery (PBI-VI-002/003)

```text
:view <path|partial>
:edit <path|partial>
:split <path>
:vsplit <path>
:find <query>
```

`:recent`, `:cd`, `:mark`, `:copy-path` are explicitly deferred (see Follow-ups).

### 4. Vi-Style Code Navigation (PBI-VI-001/004)

`gf`, `gd`, `K`, `]d`/`[d`, with LSP-backed actions degrading cleanly (no-op /
status message) when no LSP session is active for the file.

### 5. LSP As A Background Command Service (PBI-LSP-001/002/003)

```bash
harness lsp start
harness lsp status
harness lsp diagnostics --json src/App.swift
harness lsp hover src/App.swift:42:10
harness lsp definition src/App.swift:42:10
```

`harness lsp references` and JSON-RPC daemon integration are deferred.

---

## Implementation Tracks

### Track 1 — Syntax Highlighting — **DONE**

Implemented in `worktree-p4-syntax-highlight`, merged via PR #12. See
"Current Shipped State" above for summary. Follow-ups (not blocking):
missing `harness cat --highlight` ANSI renderer (no CLI `cat`/`view` existed
at the time — `harness view` is now added by PBI-VI-002 in this track, which
unblocks a future `--highlight` flag).

### Track 2 — Vi Navigation

#### PBI-VI-001 — DONE — `gf` path-under-cursor + LSP-backed `gd`/`K`/`]d`/`[d`

- Add path-under-cursor detection to `SyntaxTextView`/`ViNormalMode`: given
  the current cursor position, extract a candidate file path token (handle
  relative paths, `path:line[:col]` suffixes common in compiler/test output).
- `gf` (normal mode): resolve the candidate path against the current file's
  directory and the workspace root; if it resolves to an existing file, open
  it via the existing `onOpenFile`/file-viewer routing (reuse `:e` plumbing).
  If nothing resolves, no-op with a status message (do not error/crash).
- `gd`: if an `LSPFileSession` is active for the current file, call
  `.definition()` and navigate to the result (file + line/col); if no LSP
  session, fall back to `gf`-style path resolution on the identifier (best
  effort) or no-op with a status message.
- `K`: if an `LSPFileSession` is active, call `.hover()` and show the result
  (reuse existing hover popover plumbing from `FileEditorView`/`SyntaxTextView`
  if present); otherwise no-op with a status message.
- `]d` / `[d`: iterate the diagnostics already surfaced by `LSPFileSession`
  (gutter markers in `SyntaxTextView`) and move the cursor to the
  next/previous diagnostic position, wrapping at start/end with a status
  message when there are none.
- All four must degrade gracefully with **no crash and no error dialog** when
  LSP is unavailable — this is explicitly required by the plan ("Use LSP only
  when available; otherwise degrade cleanly").

- Implementation Notes:
  - Added low-risk `gf` support in `Apps/Harness/Sources/HarnessApp/UI/ViNormalMode.swift`: extracts a path-like token under the cursor, strips common `:line[:col]` suffixes, and routes through the existing `onOpenFile` path.
  - Wired `gd`, `K`, `]d`, and `[d` through `SyntaxTextView`'s existing LSP callbacks and diagnostics state. `gd` calls `LSPFileSession.definition()` and navigates to file:line:column when available, falling back to path-under-cursor/no-op status messaging. `K` calls `hover()` and displays hover text in the existing ex-message/status panel. Diagnostic jumps use the surfaced diagnostics array, wrap at the ends, and show a no-diagnostics status when empty.
  - Added focused `ViDiagnosticNavigatorTests` for diagnostic ordering and wrap behavior.

#### PBI-VI-002 — DONE — `:view`, `:edit`, `:split <path>`, `:vsplit <path>`, `harness view`

- Add `Command` enum cases (or reuse existing where equivalent) for
  `view(path)`, and extend existing `:e`/`edit` ex command to accept a path
  argument if it doesn't already (check `ViNormalMode.swift` ~1517-1520).
- `:split <path>` / `:vsplit <path>`: open `<path>` in a new pane via the
  existing split-pane machinery (PaneNode/SessionCoordinator from P13),
  defaulting to `$EDITOR <path>` in the new pane (terminal-first per the
  plan's Direction section), not a GUI file-viewer split.
- `:view <path>` opens the file in the read-only `FileViewerViewController`
  (sidebar preview) rather than the terminal editor.
- `harness view <file>`: new CLI subcommand under `Tools/harness/Sources/HarnessCLI`
  that prints the file's content to stdout (plain, deterministic — same
  guarantee as the plan's `harness cat`). This is the first CLI file-reading
  command; keep it minimal (read file, size guard matching
  `FileViewerViewController`'s, binary detection message) since no `cat`
  command exists to extend.

- Implementation Notes:
  - Added `harness-cli view <file>` in `Tools/harness/Sources/HarnessCLI/HarnessCLI+View.swift`, dispatched before daemon client creation so it works without a running daemon.
  - Added preview-size and binary/UTF-8 guard tests in `Tests/HarnessCLITests/HarnessCLITests.swift`.
  - Added `:edit` alias, `:view`, `:split`, and `:vsplit` notifications in `ViNormalMode.swift`/`SyntaxTextView.swift`.
  - `:view` opens the sidebar `FileViewerViewController` via `HarnessSidebarPanelViewController.previewFile(path:)`; `:split`/`:vsplit` use `SessionCoordinator.splitActivePaneAndRun` to create a terminal pane and run `${EDITOR:-vi} <path>`.

#### PBI-VI-003 — DONE — `:find <query>` fuzzy path resolution

- Extract/reuse `FuzzyMatcher` from `CommandPaletteController.swift` into a
  location both `HarnessApp` UI and ex-command handling can call (e.g. a
  small shared type in `HarnessApp` — do not move it into `HarnessCore` unless
  trivial, since file scanning is AppKit/filesystem-bound).
- `:find <query>` fuzzy-searches files under the workspace root (reuse
  `FileTreeWatcher`/existing file scan) and either opens a unique match
  directly (via the same routing as `:view`) or shows a picker/prints ranked
  matches if ambiguous.
- `:view <partial>` / `:edit <partial>`: if the argument is not an existing
  path, resolve it via the same fuzzy matcher; if there's a unique
  high-confidence match, open it; if ambiguous, fall back to `:find`'s
  picker/listing behavior.

- Implementation Notes:
  - Extracted reusable app-side fuzzy scoring/ranking into `Apps/Harness/Sources/HarnessApp/UI/FuzzyPathResolver.swift` and rewired `CommandPaletteController.swift` to use it.
  - Added `Tests/HarnessAppTests/FuzzyPathResolverTests.swift` for score/ranking behavior.
  - Added `:find <query>` notification handling in `ContentAreaViewController.swift`; it scans under the active tab CWD, opens the best match, and displays the top matches when ambiguous.
  - Added fuzzy fallback for `:edit <partial>` and `:view <partial>`.
  - Ambiguous fuzzy results now use a terminal-first `:ls`-style ranked list and do not silently open the best match. Unique clear winners still open directly; no-match cases show a status message. The same behavior applies to `:find`, `:edit <partial>`, and `:view <partial>`.

#### Track 2 Follow-ups (explicitly deferred, not in this pass)

- `:recent` (MRU file list + selection by index)
- `:cd root` / `:cd <bookmark>` and `:mark <name> <path>` / `:cd <mark>`
- `:copy-path`
- `:grep`, `:make`
- File-view cursor model beyond reusing `NSTextView` selection (no new model needed for PBI-VI-001 as scoped)

### Track 3 — LSP Command API

#### PBI-LSP-001 — DONE — `harness lsp start` / `harness lsp status`

- New `harness lsp` subcommand group in `Tools/harness/Sources/HarnessCLI`.
- `harness lsp start [--lang <id>] [path]`: use `LSPServerRegistry` to detect
  and launch the appropriate language server for the given path/project root
  (defaulting to cwd), via `LSPClient.launch()` + `.initialize()`. Print
  JSON status (`{"status":"started","server":"sourcekit-lsp","root":"..."}`)
  or a human-readable line if no `--json`.
- `harness lsp status [--json]`: report whether a server process is currently
  tracked for the cwd/workspace (in-process for this CLI invocation is fine —
  do not require daemon-level persistence; document this limitation).
- Keep this CLI-process-local (no new daemon IPC) — `HarnessLSP` already
  manages a subprocess per `LSPClient`; a CLI invocation that starts a server
  and immediately queries it in the same process is acceptable for this pass.

- Implementation Notes:
  - Added `harness-cli lsp start/status` in `Tools/harness/Sources/HarnessCLI/HarnessCLI+LSP.swift`, dispatched before daemon client creation.
  - `start` launches and initializes the detected server for the invocation, then exits cleanly; `status` explicitly reports no daemon-persistent LSP server is tracked.
  - Updated `Package.swift`, `CLICommandCatalog`, usage text, and CLI dispatch tests for the new top-level `lsp` command.

#### PBI-LSP-002 — DONE — `harness lsp hover` / `harness lsp definition`

- `harness lsp hover <file>:<line>:<col> [--json]`: launch/initialize the
  appropriate `LSPClient` for `<file>`'s project, open the document, call
  `.hover()` at the given position, print the result (plain text by default,
  full JSON with `--json`).
- `harness lsp definition <file>:<line>:<col> [--json]`: same flow calling
  `.definition()`, printing the resulting location(s) as `path:line:col` (or
  JSON).
- Parse `<file>:<line>:<col>` consistently (1-based line/col, matching
  compiler/grep conventions) — add a small shared parsing helper since both
  subcommands and PBI-VI-001's `gd`/`K` conceptually need the same format.

- Implementation Notes:
  - Added public `LSPTextLocationParser` in `Packages/HarnessLSP/Sources/HarnessLSP/LSPTextLocation.swift`; it parses the final two colon-separated fields as 1-based line/column and preserves colons inside file paths.
  - Added parser unit tests in `Tests/HarnessCLITests/HarnessCLITests.swift`.
  - Added one-shot `hover` and `definition` CLI flows that detect the server, open the document, query the requested position, and print plain or JSON output.

#### PBI-LSP-003 — DONE — `harness lsp diagnostics --json <file>`

- `harness lsp diagnostics <file> [--json]`: open the document via `LSPClient`,
  wait for/collect the first diagnostics notification for that file (with a
  reasonable timeout), and print them (plain summary by default, full JSON
  with `--json`).
- This is the only Track 3 command exposing diagnostics; it must be opt-in
  (a separate subcommand/flag) and must not change `harness view`'s plain
  output — consistent with "`harness cat <file>` ... only `--highlight`/
  `--diagnostics` add decoration" from the plan.

- Implementation Notes:
  - Added `harness-cli lsp diagnostics <file> [--json]` with a bounded wait for the first `textDocument/publishDiagnostics` notification.
  - Diagnostics remain opt-in through the `lsp diagnostics` subcommand; `harness view` output remains plain file text or deterministic guard messages.
  - Plain diagnostics render as `path:line:column: message`; JSON emits the decoded diagnostic payload.

#### Track 3 Follow-ups (explicitly deferred, not in this pass)

- `harness lsp references`
- Daemon-owned/persistent LSP server lifecycle (currently CLI-process-local)
- Unifying `ACPTransport`/`LSPTransport`
- MCP tool exposure of LSP commands

## Success Criteria

- Reading code in Harness feels closer to a polished terminal code sample than
  a heavy IDE panel.
- `harness view` is deterministic by default (no future `cat` command exists
  yet, so this is the closest analog for now).
- A path printed in terminal output can be opened with `gf` without touching
  the IDE panel.
- `:find`/`:view <partial>`/`:edit <partial>` work via fuzzy fragments so users
  do not need to memorize full paths.
- Syntax highlighting works in the viewer without requiring LSP (already true
  — Track 1 DONE).
- `gd`/`K`/`]d`/`[d` and `harness lsp ...` are addressable and degrade cleanly
  without LSP.
- No test/debugging UI is added under P4.
