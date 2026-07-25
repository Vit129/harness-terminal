# P8: macOS 27 Golden Gate Adoption

## Context
WWDC26 announced macOS 27 Golden Gate (ships ~Sep 2026). Kouen Terminal
currently targets macOS 26 Tahoe. This plan covers compatibility testing,
new API adoption, and visual alignment with the refined Liquid Glass system.

Key sessions:
- "Modernize your AppKit app" (WWDC26/289)
- "What's new in SwiftUI" (WWDC26/269)
- "Use SwiftUI with AppKit and UIKit" (WWDC26/272)
- Metal guide (no breaking changes for our renderer)

## Priority: High (P0 = ship-blocking, P1 = quality, P2 = nice-to-have)

---

## Phase 0 — Swift 6.3+ Concurrency Safety (P0, LESSONS FROM macOS 26.5 CRASH SAGA)

Critical findings from the 40-crash zombie incident (Jun 16–18, 2026).
These MUST be maintained on any macOS 27 SDK upgrade.

### Rules (enforced, not optional)

1. **Use `nonisolated` on crash-prone AppKit overrides** (`sendEvent`, `close`, `layout`, `hitTest`)
   - On `@MainActor` classes, a plain override generates an `@objc` thunk that calls
     `swift_task_isCurrentExecutorWithFlagsImpl` — this dereferences metadata and crashes
     when the view is a zombie (freed but still receiving events)
   - `nonisolated` **bypasses** that executor check, making the thunk safe on zombie views
   - Real examples: `KouenWindow.sendEvent/close`, `WindowBorderOverlayView.layout/hitTest` (RL-040)
   - Do NOT add `nonisolated` to every override — only to those reachable after dealloc begins

2. **Never use `MainActor.assumeIsolated`** in Timer/NotificationCenter/completion callbacks
   - Use `Task { @MainActor in }` instead
   - `assumeIsolated` can dereference NULL task context on macOS 26.5+ when there is no
     running Swift Task (GCD callbacks and Notification deliveries have no Task context)
   - Exception: `MainExecutor.execute()` uses `assumeIsolated` inside `Thread.isMainThread`
     branch and `DispatchQueue.main.sync {}` — both guarantee main thread, so it is safe

3. **Always `guard window != nil` in `updateTrackingAreas()`**
   - AppKit calls it during dealloc/layout after view left window
   - Without guard: tracking area re-created → event dispatched to zombie

4. **Deferred dealloc (500ms) for terminal hosts**
   - `TerminalPaneRegistry.retire()` holds host alive after removal
   - Covers keyUp, mouseMoved, resetCursorRects that arrive in later event iterations

5. **Avoid `Optional.map {}` closures in `@MainActor` code**
   - Closure triggers executor check → NULL if no task context
   - Use `if let` instead

6. **Kill app BEFORE build in install scripts**
   - Prevents crash loop where old binary crashes repeatedly during build

### Verification checklist for macOS 27 beta

- [x] Run `grep -rn "nonisolated override" Apps/ Packages/` — allowed only in RL-040 sites
      (KouenWindow: sendEvent/close, WindowBorderOverlayView: layout/hitTest); any new site needs a RL-040 comment
      **RESOLVED (2026-07-25):** 3 undocumented sites found — `BoardViewController.swift:9`,
      `GitPanelView.swift:2487` (both `nonisolated override var isFlipped`), correctly `nonisolated`,
      now carry RL-040 comments. `KouenTerminalSurfaceView.swift:1282` (`resetCursorRects`) already had one.
- [x] Run `grep -rn "MainActor.assumeIsolated" Apps/` — allowed only in MainExecutor.execute()
      (synchronous bridge with Thread.isMainThread guard) and TerminalHostView hot path ([weak self]+guard)
      **RESOLVED (2026-07-25):** stale 2-exception allow-list replaced with a full 29-site audit
      (agy classification, then hand-reviewed before any edit — see commit history). 18 sites confirmed
      safe (AppKit lifecycle overrides paired with `nonisolated` per RL-040, or `DispatchQueue.main.async`
      hot paths preserving FIFO output order). 10 sites in `BrowserPaneView.swift`, `SettingsModel.swift`,
      `SessionCoordinator.swift`, `WorktreeAutoIsolateService.swift`, `KouenTerminalSurfaceView.swift`,
      `ImmersiveOnboardingWindowController.swift` were genuinely unsafe (Timer/NotificationCenter/
      NSAnimationContext-completion/DispatchSource callbacks with no Task context) — converted to
      `Task { @MainActor in }`. Build + full test suite (swift test, Tests/robot/run.sh) verified after.
- [ ] Run app for 2+ hours without crash
- [ ] Check `heap <PID> | grep NSTextField` — count should be stable (no growth)
- [x] Confirm `updateTrackingAreas` all have `guard window != nil` — fixed 3 missing sites
      (`TabOverviewController.swift:170`, `ContentAreaViewController.swift:706,797`), rest already compliant

See: `agent-memory/knowledge/bugs/zombie-crash-macos26.md` for full details.

---

## Phase 1 — Compatibility (P0)

Ensure Kouen builds and runs correctly on macOS 27 beta without regressions.

- [x] Build with Xcode 27 beta, fix any deprecation warnings-as-errors
      **RESOLVED (2026-07-25):** Xcode 27.0 (27A5228h) now installed at `/Applications/Xcode-beta.app`.
      Clean build via `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build --product Kouen`:
      0 errors, 20 distinct warnings, **none in `KouenCore`/`KouenTerminalEngine`** (the only two
      `-warnings-as-errors` targets) — the checklist item as literally written is satisfied.
      Of the 20: 1 trivial (`FrecencyDirectoryStore.swift:45` var→let, fixed). 8 are in `KouenWindow.swift`
      (RL-040's `nonisolated override sendEvent/close`) — Xcode 27's AppKit headers now annotate
      `NSWindow.contentView`/`firstResponder`/`sendEvent`/`close` etc. as `@MainActor`-isolated, and the
      compiler is correctly flagging that RL-040 *deliberately* violates that isolation to stay safe on
      zombie views. **Do not silence these — every fix either reintroduces the executor check (the crash)
      or is a no-op unsafe cast.** 2 more (`KouenTerminalSurfaceView.swift:2318,2556`) are weak/strong
      capture-list warnings in the FIFO-preserving frame build/present pipeline — same reasoning, left as
      warnings. Remaining ~9 are mechanical (unnecessary `nonisolated(unsafe)`, Sendable-closure captures,
      weak-capture mismatches in non-critical files) — candidates for a follow-up pass, not blocking.
- [ ] Verify Liquid Glass doesn't break custom sidebar chrome (`KouenDesign`,
      `ChromeBackdrop`, `WindowBlur.apply()`) — needs the app actually running on 27, not compile-checkable
- [ ] Verify window corner radius change doesn't clip terminal content or overlays — same, needs a live run
- [ ] Test NSStatusItem (`MenuBarController`) with new expanded interface session API — same, needs a live run
- [ ] Confirm Metal renderer still works (no display pipeline changes expected) — same, needs a live run
- [ ] Run full test suite on macOS 27 — **BLOCKED (2026-07-25):** `swift test` under the beta toolchain
      fails at the XCTest-bundle-loading stage for every target (`dlopen: Library not loaded:
      @rpath/Sparkle.framework/...`) — the vendored Sparkle binary artifact isn't resolving under Xcode 27's
      test harness rpath search. Toolchain/environment issue, not a code defect (`swift build` compiles and
      links the actual app fine). Not chased further — needs Sparkle SPM artifact or search-path fix.

## Phase 2 — Quick Wins (P1)

Low-effort adoptions that improve quality immediately.

- [x] Set `window.autorecalculatesKeyViewLoop = true` on `MainWindowController`
- [x] Set `preventsApplicationTerminationWhenModal = false` on non-critical sheets
      (about panel, settings, command palette)
- [ ] **UNBLOCKED (2026-07-25):** Adopt `NSViewCornerConfiguration` + `.containerConcentric` on:
  - `ToastLabel`
  - `DisplayPanesOverlay` chips
  - `ResizeHUDView`
  - `NotificationDropdownPanelView`
  Was blocked on Xcode 26.6 (`error: cannot find 'NSViewCornerConfiguration' in scope`); re-verified
  it now resolves under Xcode 27.0 beta. Real code work, dispatched to agy with
  `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.
- [x] Adopt sidebar semi-bold selection text style (if system doesn't auto-apply
      due to custom sidebar) — `WorktreeRowView.titleLabel` was hardcoded `.semibold`
      unconditionally; now `.semibold` only when `isSelected`, `.regular` otherwise,
      toggled in `refresh()`. `SessionWorktreeRowView` (leaf worktree rows) has no
      selection concept, left untouched.

## Phase 3 — NSTextSelectionManager (P1)

Replace manual mouse-forwarding in file preview with system text selection.

- [ ] Evaluate `NSTextSelectionManager` for `SyntaxTextView` (file editor)
- [ ] Evaluate for `FileViewerViewController` QuickLook text selection
- [ ] If viable, remove manual `mouseDown/mouseDragged/mouseUp` forwarding
      (currently needed per RL-010/CASE-018)
- [ ] Test bidirectional selection, drag-and-drop text

## Phase 4 — Gesture Recognizer Migration (P2)

Long-term tech debt: replace mouseDown overrides with gesture recognizers.
Not urgent but aligns with Apple's direction.

Priority targets (most complex mouseDown logic):
- [ ] `TerminalTabBarView` — drag reorder + context menu
- [ ] `SessionCardRowView` — click + hover + context menu
- [ ] `KouenControls` (slider, toggle, select) — tracking loops
- [ ] `ContentAreaViewController` split divider drag

Lower priority (simpler or less frequent):
- [ ] `SoftIconButton`, `KouenPillButton`, `NotificationBellButton`
- [ ] `WorkspacePillButton`, `WorkspaceSwitcherRow`

## Phase 5 — State Restoration (P2)

Adopt `NSWindowRestoration` for seamless relaunch after system updates.

- [ ] Evaluate overlap with existing `SessionStore` persistence
- [ ] Implement `encodeRestorableState` on `MainWindowController` (sidebar
      width, selected tab, sidebar visibility, active workspace)
- [ ] Implement `restoreWindow(withIdentifier:)` in restoration class
- [ ] Call `invalidateRestorableState()` on relevant state changes
- [ ] Keep `SessionStore` for daemon-side session state (pane tree, surfaces)
      — restoration handles window chrome only

## Phase 6 — SwiftUI Performance (Free wins)

These require no code changes, just running on macOS 26+/27:

- List 100k+ items 6x faster → benefits `FileTreeSwiftUIView`
- Nested layouts 2x faster resize → benefits sidebar SwiftUI views
- `@State` lazy init (macro) → reduces reconciliation overhead

Verify:
- [ ] File tree with large repos (10k+ files) — measure scroll perf on 27 vs 26

---

## Phase 7 — AppIntents & System Shortcuts Integration (P1)

Expose Kouen CLI/Daemon control to system-wide AppIntents and Shortcuts app.

- [ ] Create `KouenShortcutsProvider` conforming to `AppShortcutsProvider`
- [ ] Define `RunCommandIntent` (execute command in active/specified pane)
- [ ] Define `SplitPaneIntent` (split horizontally/vertically with target profile/command)
- [ ] Define `SwitchWorkspaceIntent` & `GetTerminalOutputIntent`
- [ ] Wire intents to `DaemonClient` / IPC bridge

## Phase 8 — Actionable User Notifications (P1)

Enhance long-running process notifications with interactive action buttons.

- [x] Extend `NotificationCoordinator` to register `UNNotificationCategory` for terminal jobs
- [x] Add notification actions: `Focus Pane`, `Rerun Command`, `Copy Output`
- [x] Handle action callbacks via `UNUserNotificationCenterDelegate` and route to `SessionCoordinator`
  *(Note: Rerun Command reuses the command recorded in `TerminalBlock` via OSC 133 boundaries when available for the surface and resends it via daemon input IPC `.send`. For panes without OSC 133 integration or captured blocks, no hidden state was invented.)*

## Phase 9 — Background Power & Activity Management (P1)

Prevent App Nap / macOS 27 sleep from interrupting active builds and agent tasks.

- [x] Wrap active PTY build sessions in `ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason:)`
- [x] Add `ActivityAssertionManager` to track active agent/subagent runs
      *(Note: "daemon tasks" was originally wired to `TaskStore`/`KouenTask` — turned out to be the
      unrelated Task Dashboard TODO checklist, which deliberately persists after its owning session
      closes. Using it would have kept the Mac awake forever whenever any unchecked TODO item existed
      anywhere. Removed that block rather than keep a wrong signal; "active daemon tasks" in the
      Process-management sense has no existing equivalent in this codebase to wire up yet.)*
- [x] Ensure process assertions release cleanly on task completion or process termination —
      released via `terminalHosts.onRetire` (same real pane-teardown hook as `SecureInputMonitor.release`),
      plus `releaseAll()` on `applicationWillTerminate`

## Phase 10 — WidgetKit & Desktop Status Panel (P2)

Glanceable status widget for desktop and Notification Center.

- [ ] Add WidgetKit extension target for macOS (`KouenWidget`)
- [ ] Implement `TimelineProvider` rendering active pane count, running jobs, and daemon health
- [ ] Share session state via App Group / daemon IPC status snapshot

## Phase 11 — Metal Frame Pacing & DisplayLink Optimization (P2)

Optimize Metal render loop for macOS 27 display pipeline and ProMotion.

- [ ] Review `TerminalMetalRenderer` frame pacing against macOS 27 `CVDisplayLink` / `CAMetalLayer` callbacks
- [ ] Pause display link when terminal surface is static / inactive tab to conserve GPU power
- [ ] Benchmark 120Hz ProMotion vs 60Hz rendering frame latency

## Phase 12 — Terminal Accessibility Tree (P2)

Expose terminal buffer grid to VoiceOver and macOS 27 Accessibility APIs.

- [ ] Implement `NSAccessibility` element provider over `KouenTerminalSurfaceView` grid
- [ ] Expose line-by-line text and prompt location to `NSAccessibilityNavigableStaticText`
- [ ] Test with VoiceOver navigation and macOS 27 system Accessibility inspector

---

## Non-goals
- Liquid Glass full redesign (keep custom chrome for brand identity)
- 3D charts / spatial layout (not relevant for terminal)
- Document API (not a document-based app)
- MetalFX upscaling (2D glyph renderer, not 3D)

## Risks
- Custom `NSVisualEffectView` / `WindowBlur` may conflict with system Liquid
  Glass in unexpected ways — need early beta testing
- `NSTextSelectionManager` may not support our use case (syntax-highlighted
  attributed text with line numbers) — evaluate before committing
- Gesture recognizer migration is large scope, defer if time-constrained
- `AppIntents` and `WidgetKit` require App Group setup for shared IPC status with daemon
- `NSAccessibility` virtual grid mapping can incur performance overhead if re-computed every frame; must diff dirty lines

## Timeline
- **Beta 1–3 (Jun–Aug 2026):** Phase 1 + 2 + 7 + 8
- **RC (Sep 2026):** Phase 3 evaluated, Phase 6 verified, Phase 9 + 11 verified
- **Post-release:** Phase 4 + 5 + 10 + 12 as time allows

