# P9: Code Complexity Reduction & Structural Refactoring

## Context
Code review identified 5 areas of concern. This plan addresses them with
concrete decomposition strategies while preserving the current architecture
and test coverage.

Priority: P2 (quality/maintainability — no user-facing urgency)

---

## 1. HarnessTerminalSurfaceView (~2,320 LOC)

**Problem:** Single class owns rendering, input, selection, copy-mode,
scrollback, find, live-resize, paste, drag-drop, and frame scheduling.

**Strategy:** Already partially split via extensions. Further decompose into
coordinator objects (not subclasses):

- [ ] Extract `LiveResizeCoordinator` — owns frozen origin, debounced commit,
      preview token, grid geometry calculation (~300 LOC)
- [ ] Extract `SelectionController` — owns `RawSelection`, granularity,
      unit range resolution, link hover, mouse reporting (~250 LOC from
      `+SelectionAndLinks.swift`)
- [ ] Extract `PasteController` — unsafe paste detection, confirmation,
      image paste, path drop (~100 LOC from `+Find.swift`)
- [ ] Keep rendering/frame-build/display-link in the main class (core responsibility)

**Constraint:** All extracted types must be `@MainActor` (they touch views).
Pass callbacks or weak refs back to surface view — no circular strong refs.

## 2. HarnessCLI.swift (~1,841 LOC)

**Problem:** Giant `main()` with if/else dispatch for 60+ verbs.

**Strategy:** Subcommand handler pattern — each verb group becomes a file:

- [ ] Create `CLIHandlers/` directory under `Tools/harness/Sources/HarnessCLI/`
- [ ] Extract handler groups:
  - `SessionHandlers.swift` — new-session, has-session, select-session, rename, list
  - `TabHandlers.swift` — new-tab, select-tab, close-tab, link/unlink-window
  - `PaneHandlers.swift` — split, select-pane, resize, swap, kill, respawn, zoom
  - `BufferHandlers.swift` — set-buffer, show-buffer, list-buffers, load/save/paste/delete
  - `HookHandlers.swift` — bind-hook, unbind-hook, list-hooks, show-hooks
  - `ServerHandlers.swift` — start-server, kill-server
  - `EnvironmentHandlers.swift` — show-environment, set-environment
  - `KeyHandlers.swift` — bind-key, unbind-key, list-keys
  - `InfoHandlers.swift` — list-sessions, list-windows, list-panes, list-agents, display-message
- [ ] Keep `main()` as thin dispatch table: `verbHandlers[verb]?(args)` or switch
- [ ] Each handler is a free function `func handleXxx(_ args: [String], ...) throws`

**Constraint:** No behavior change. Same CLI interface. Tests must still pass.

## 3. WindowAttachClient (~1,566 LOC)

**Problem:** Dense tmux-like window manager logic, hard to test in isolation.

**Strategy:** Extract pure logic from I/O:

- [ ] Extract `WindowLayout` — pane tree solving, border painting, status line
      composition (pure functions, testable without socket)
- [ ] Extract `WindowInputRouter` — key dispatch, copy-mode byte handling,
      mouse routing (pure state machine, testable with synthetic events)
- [ ] Keep `WindowAttachClient` as the glue: socket I/O + delegates to above
- [ ] Add unit tests for `WindowInputRouter` (key spec decode, root key dispatch)

## 4. SurfaceRegistry (~1,848 LOC)

**Problem:** God-object owns PTY lifecycle, hook firing, agent scanning,
format context building, metadata refresh, pipe management.

**Strategy:** Decompose into focused managers behind same lock:

- [ ] Extract `HookExecutor` — `fireHookLocked()`, condition evaluation,
      shell execution (~150 LOC)
- [ ] Extract `FormatContextBuilder` — `buildFormatContext()` + all token
      resolution (~200 LOC)
- [ ] Extract `PipeManager` — `startPipe()`, `stopPipe()`, `feed()` (~80 LOC)
- [ ] Keep in `SurfaceRegistry`: surface create/ensure, snapshot mutation,
      subscription management, shell resolution (core responsibilities)
- [ ] Extracted types take `SurfaceRegistry` (or a protocol) as dependency
      for snapshot access

**Constraint:** Must stay `@unchecked Sendable` with documented lock
confinement. Extracted types accessed only under `registryLock`.

## 5. GridCompositor Duplication

**Problem:** Two versions — `HarnessTerminalKit/GridCompositor.swift` (532 LOC)
and `HarnessOnboarding/TerminalKit/GridCompositor.swift` (418 LOC).

**Assessment:** This is **intentional** — onboarding uses a simplified model
(`TerminalGridSnapshot` stub, no real engine dependency) to avoid pulling
HarnessTerminalEngine into the onboarding package. The onboarding version:
- Uses its own `ComposedCell` / `ComposedFrame` types
- Doesn't need damage tracking, incremental rendering, or real grid access
- Is a display-only compositor for the demo terminal view

**Decision:** Keep separate. Document the rationale:

- [ ] Add a comment header to both files explaining why duplication exists
- [ ] If onboarding compositor diverges further, consider extracting shared
      SGR-emit logic into a tiny `HarnessTerminalFormat` micro-package (only
      if both need the same escape-code generation in the future)

---

## Execution Order
1. **#2 (CLI)** — lowest risk, pure file reorganization, no runtime change
2. **#5 (GridCompositor)** — just documentation
3. **#4 (SurfaceRegistry)** — medium risk, stays under lock
4. **#1 (SurfaceView)** — higher risk, touches rendering hot path
5. **#3 (WindowAttachClient)** — needs new tests, lowest urgency

## Execution Status (2026-06-11)
- ✅ **#1 (SurfaceView)** — Extracted `LiveResizeGeometry`, `PasteController`, `SelectionResolver`
- 🔲 **#2 (CLI)** — Plan documented; full extraction (88+ handlers) deferred to dedicated session
- 🔲 **#3 (WindowAttachClient)** — Plan documented; needs accompanying unit tests
- 🔲 **#4 (SurfaceRegistry)** — Plan documented; needs lock-confinement audit
- ✅ **#5 (GridCompositor)** — Rationale documented in both files

## Success Criteria
- All existing tests pass unchanged
- No new `@unchecked Sendable` types introduced
- No user-facing behavior changes
- Largest file in each group shrinks by ≥25%
