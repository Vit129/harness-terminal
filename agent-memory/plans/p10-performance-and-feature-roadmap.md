# P10: Performance and Feature Roadmap (Terminal First, IDE Convenient)

## Context
Analysis of the current `harness-terminal` architecture shows a highly performant GPU-accelerated core, but identifies key optimization bottlenecks and potential feature upgrades to deliver on the "terminal first, ide convenient" philosophy.

Priority: P3 (Strategic planning / future-proofing)

## Implementation Status (2026-06-11)

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | Scrollback Reflow | ✅ Done | Lazy reflow — skip O(history) during live drag, full reflow on `viewDidEndLiveResize` |
| 2 | Local Completion | ✅ Done | `WorkspaceSymbolIndex` (110 LOC) + `CompletionPopupView` (192 LOC) |
| 3 | Keyboard Layout Presets | ✅ Done | ⌘+⇧+D IDE mode, ⌘P Focus mode |
| 4 | ACP Sidebar | 🔲 Deferred | Ecosystem not ready |

### Additional features shipped alongside:
- **Session State Dot** — colored indicator on sidebar cards (blue=running, gray=idle, green=exit 0, red=error)
- **IDE Mode Persistence** — editor split state (visible, open tabs, active tab) persists across launches via UserDefaults
- **Diff Syntax Highlighting** — `.diff`/`.patch` files get +/- coloring + gutter markers
- **Git Changes Click-to-Preview** — clicking changed files opens diff in editor panel
- **Git History Right-Click Menu** — Copy Commit ID, Copy Message, Show Diff
- **Task Board Sidebar Tab** — parses Makefile targets + package.json scripts; click to run in active terminal
- **Focus Mode (⌘P)** — hides sidebar + editor for full-screen terminal focus; toggle restores layout
- **CASE-026 Fix** — black terminal on new session (display link race condition)

---

## 1. Performance Optimization: Scrollback Reflow ($O(\text{history})$ Complexity)

**Problem:** 
When the terminal is programmatically resized (e.g. splitting views, toggling the sidebar, or changing window size) and has a deep scrollback history (50,000+ lines), history reflow runs in $O(\text{history})$ time, which can temporarily lag the PTY parser queue.

**Strategy:**
- **Lazy Reflow:** Reflow only the active viewport (`columns * rows` cells) immediately during resize. Defer history-wide reflow using a lazy index-map/segment model.
- **Block-allocated Ring Buffer:** Store scrollback history in a block-allocated ring buffer (pre-allocated structures) rather than native Swift string/array line instances, minimizing allocations and garbage collection overhead.

---

## 2. convenient Features: Local completion & completion Gutter

**Problem:** 
Integrating full Language Server Protocol (LSP) features was shelved due to client-side complexity, socket overhead, and reliability of external CLI adapters. However, developers still need basic auto-completion and symbol navigation in the preview editor.

**Strategy:**
- **Workspace-scoped Tokenizer:** Implement a lightweight, local regex/tokenizer (similar to ctags or treesitter parser) running off-main. It will parse active files in the workspace directory.
- **Word/Symbol Completion:** Inject parsed local keywords and symbols into `SyntaxTextView`'s autocomplete, giving IDE-like auto-completion (tab-completion) without heavy LSP background processes.

---

## 3. IDE Convenient: Keyboard-driven Layout Presets

**Problem:** 
Managing multiple split panes programmatically requires manually performing vertical/horizontal splits, which is slow compared to IDEs.

**Strategy:**
- ** Tiling Layout Presets:** Implement keyboard-driven layouts (e.g., `⌘+⇧+D` for "IDE mode") that split the workspace into pre-configured ratios:
  - Sidebar (File Tree/Git): 20%
  - Editor Preview Panel: 40%
  - Terminal Main Pane: 40%
- **Adjacent Insert CWD Grouping:** Continue utilizing CMUX session tracking so newly spawned panes automatically inherit the layout and CWD group of the active pane.

---

## 4. AI integration: Secure Local ACP Sidebar

**Problem:** 
The Agent Control Protocol (ACP) for sidebar AI chat was shelved due to security concerns (arbitrary tool execution) and PATH resolution issues inside macOS app bundles.

**Strategy:**
- **Lightweight Local ACP Adapter:** Build a localhost-only chat panel that interfaces with local engines (like Ollama) or Gemini API.
- **Consent-gated Tool Execution:** Implement a strict validation layer: any tool execution request by the agent must trigger a visual prompt in the terminal/chat view requiring explicit user approval before running.
