# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.1.0] - 2026-06-07

The tmux-parity close-out: every remaining tracked gap is either shipped, adapted with a
documented rationale, or explicitly rejected in [docs/TMUX_PARITY.md](docs/TMUX_PARITY.md) —
Harness now carries its own complete tmux at the capability level. Plus the first-run /
what's-new terminal banner. Each piece was review-hardened pre-merge (every Bugbot finding
adversarially verified, 39 additional findings fixed, all pinned by tests).

### Added
- **First-run welcome tour and post-update "what's new" banner.** A one-shot MOTD in the
  first fresh terminal: a quick tour on a clean install, the release highlights after an
  update. Daemon-injected like real shell output, never repeated (durable ack with retry),
  suppressible via the `update-banner` option.
- **~25 new `#{…}` format variables** — `pane_pid`, `pane_current_command`, `pane_width/height`,
  `pane_dead(+_status)`, `history_bytes`, `session_id`, `window_id`, `session_windows`,
  `window_panes`, `window_active`, `window_flags`, `session_attached`, `session_group`,
  `client_width/height/tty/termname`, `host(_short)`, `pid`, … — with tmux's `$`/`@`/`%`
  ID prefixes so displayed IDs round-trip into `-t` targets.
- **Full `-t` target grammar for `select-pane` / `swap-pane`**, plus `swap-pane -s <src>`
  (swap two arbitrary panes). Strict resolution everywhere: a `-t`/`-s` that names a missing
  session/window/pane fails loudly in every front-end — `kill-pane -t bogus` can no longer
  silently kill the focused pane.
- **Bindable config/buffer/hook verbs** — `set`/`setw`/`show`/`setenv`/`showenv`/`setb`/
  `pasteb`/`deleteb`/`lsb`/`showb`/`set-hook [--if]`/`show-hooks`/`unbind-hook` work from
  `bind-key`, the `:` prompt, hooks, and `source-file`, so a `.tmux.conf`'s config lines
  migrate unchanged.
- **`find-window`** (name/title by default, `-C` pane-content) with loud no-match in every
  front-end; tmux's `copy-mode-vi` table name accepted everywhere a table is typed.
- **Session/window lifecycle hook events** — `session-created/renamed/closed`,
  `window-renamed/linked/unlinked/layout-changed` — with subject-true contexts (a
  `session-closed` hook formats the closed session, not the survivor), plus `set-titles(+string)`,
  `detach-on-destroy`, and `display-time` options.
- **Grouped sessions** (`new-session -t <session>`, CLI `--group-with`): a shared window
  list with per-member focus; window create/kill propagates group-wide, including after
  members' layouts diverge.
- **Server-admin verbs** — `kill-server` / `start-server` adapted to launchd supervision
  (PID-identity-checked, remote-`--host` safe), `respawn-window`, `refresh-client`,
  `show-messages` (includes hook-fired messages).
- **`docs/TMUX_PARITY.md`** — the honest capability ledger: at-parity / adapted / rejected /
  deferred, with the no-silent-misroute invariant it protects.

### Fixed
- `synchronize-panes` is one state across the GUI, the SSH compositor, and `setw` — toggles
  write the per-tab option through, so a snapshot push can't revert a local toggle.
- GUI, compositor, and control mode surface daemon validation errors (unknown hook event,
  bad option scope) instead of reading as success; control mode emits `%error` for them.
- CLI `setw` writes the tab scope like every other front-end (it silently wrote a global);
  scoped CLI sets resolve the calling pane via `$HARNESS_SURFACE`.
- Option/env/buffer values that begin with `-` are no longer swallowed as flags (getopt-style
  parsing with `--` support); a bare `set-environment KEY` errors instead of persisting `""`.
- Detaching `attach-window` restores the outer terminal title (`set-titles`); destroying the
  attached session re-pins the surviving session's workspace.

## [1.7.1] - 2026-06-06

The post-release audit of 1.7.0: a second exhaustive multi-agent pass (56 hunt dimensions across
the release diff and the whole app, refute-by-default verification, every fix below pinned by a
regression test that fails on the pre-fix code where feasible).

### Fixed
- **RIS left the saved cursor alive, so `DECSC → RIS → DECRC` restored pre-reset state.** A full
  reset (`ESC c`) now clears the DECSC save like xterm; DECRC after RIS restores home + the
  default pen instead of leaking the old position and colors into freshly-reset programs.
- **A torn read in the hook registry could crash the daemon.** `bind-hook`/`unbind-hook` saves
  encoded the live hook array outside the lock; concurrent mutations made `JSONEncoder` trap
  (reproduced: index-out-of-range within 15 runs). Saves now snapshot under the lock, matching
  the option/environment stores.
- **Copying a selection after scrollback eviction silently produced blank text.** The selection
  anchor (unlike the cursor) was never clamped when history shrank under copy mode; stale anchors
  now clamp on every motion and at extraction, so `y` copies real content instead of whitespace.
- **Block/char selections dropped a wide (CJK) glyph when only its trailing cell was covered.**
  Extraction now includes any character whose span intersects the selected columns — the text you
  copy matches the cells the highlight covers.
- **`n`/`N` in copy-mode search jumped to stale rows after scrollback eviction.** Matches are
  re-derived from the live buffer on every search step instead of trusting line numbers cached at
  search time.
- **A wedged binary froze onboarding forever.** The install step's `version --json` probe had no
  timeout; a corrupted/stuck binary blocked the main actor with Continue/Skip locked until
  force-quit. The probe is now fully bounded (3s + SIGTERM/SIGKILL escalation) and surfaces as
  "no version info" so the install continues on the fallback path.
- **Settings fields could show a value the terminals weren't using.** Committing an out-of-range
  fontSize / window padding / scrollback now reflects the clamped value back into the field (the
  command-finished threshold already did); color swatches and placeholder hex now refresh when
  auto light/dark flips the theme while Settings is open.
- **`bind -n` (root-table) bindings ignored caps lock.** An uppercase letter typed without Shift
  now falls back to the lowercase binding, mirroring the prefix table — while Shift+letter stays
  distinct so a typed `C` is never swallowed when only `bind -n c` exists.
- **IME composition over a selection was indistinguishable from the selection.** Preedit text
  inherited the selection / find-highlight background; it now resets its cells to the canvas
  background (translucency intact) so composition always reads as "being typed".
- **`select-pane`/`swap-pane -t` silently misrouted bad targets to the next pane.** Unrecognized
  or dangling `-t` values now fail loudly with the accepted forms (`:.+`, `:.-`, `!`), like every
  other validated flag.
- **Status-line layout counted scalars, not columns.** `status-left`/`status-right` padding and
  `display-message`/`status-format` clipping in `attach-window` overflowed one column per wide
  (CJK) glyph; all measurement and truncation is now display-width-aware.
- **`harness-cli remote add` could report success without persisting.** Write failures in
  `remote-hosts.json` are now surfaced (exit 1, naming the file); concurrent CLI invocations are
  serialized with a cross-process file lock so the second writer no longer silently discards the
  first's hosts.
- **SSH tunnel failures all read as timeouts.** When `ssh` exits before the tunnel is ready the
  error now reports its exit status ("check the host, credentials, and remote socket path")
  instead of the generic not-ready-in-time message.
- **A dangling `--ssh-arg` was silently dropped**; it now errors with exit 64 like the other
  validated flags, and `bind-key`/`unbind-key` no longer eat a key spec literally named `prefix`
  when `-T` wasn't passed.
- **Killed panes leaked their terminal views.** The pane registry now prunes hosts that left the
  daemon snapshot on every structural sync, so split+kill cycles no longer accumulate dead
  Metal-backed views for the life of the app.
- **Hooks installed on Linux pointed at the macOS binary path.** `install-hooks` now emits the
  XDG path (`${XDG_DATA_HOME:-$HOME/.local/share}/harness/bin`) on Linux, so agent notifications
  actually reach the daemon there.
- **Closing a session never cleaned its scoped environment.** `set-environment -t <session>`
  entries now clear on session/workspace close instead of accumulating in `environment.json`
  forever.
- **A respawn racing the metadata scan could briefly publish the dead shell's cwd.** The off-lock
  cwd probe now records which child PID it measured and skips the commit when a respawn swapped
  the child mid-probe.

### Added
- **`.harnesstheme` files now open in Harness.** Double-click (or Open With) imports the theme —
  validate → "Install / Install and Apply" — installing into `Application Support/Harness/themes`
  and optionally applying its colors and appearance immediately. The format was already shipped;
  the app-side wiring was the missing piece.
- Regression tests pinning the daemon-reconnect backoff policy, the OSC 9;4 stale-progress
  timeout, corrupt `layout.json` recovery, reap-generation eviction order, and the onboarding
  probe failure modes (~45 new tests).

## [1.7.0] - 2026-06-06

The production-hardening release: a full adversarial audit (multi-dimension bug hunt →
refute-by-default verification → fixes → post-fix review → live validation) across the daemon,
IPC, terminal engine, CLI, settings, and onboarding. Every fix below was verified with a repro
or code-trace before it was written, and the fix batch itself was adversarially re-reviewed
(#96–#98 are that review's catches).

### Fixed
- **Daemon could refuse to start forever after a force-kill or reboot.** (#93) The stale-instance
  gate trusted `daemon.pid` + `kill(pid, 0)` alone; a recycled PID belonging to any live process
  made the fresh daemon exit, and launchd's restart loop never escaped. The gate now verifies the
  prior PID is actually a HarnessDaemon via `proc_pidpath` and otherwise clears the stale file —
  the socket-ping guard remains the authority.
- **Attaching to a busy surface could silently drop output.** (#95) Attach was
  replay-then-subscribe across two sockets with no backfill: bytes arriving in the window were
  persisted but never delivered (repro'd: 217 lost markers). Attach now subscribes first, buffers
  live frames, replays, then flushes the buffer deduplicated by the daemon's byte sequence — with
  a compatible fallback against older daemons.
- **Keystrokes typed while a daemon subscription was dying were silently dropped.** (#95)
  `sendInput` now reports failure and input immediately falls back to the one-shot request path.
- **Daemon startup could permanently delete scrollback for a surface whose shell failed to
  spawn.** (#93) The orphan-file sweep only considered live PTYs; it now keeps any scrollback
  referenced by the layout, so a transient spawn failure (fork pressure, missing shell) no longer
  costs the pane's history.
- **A keystroke could stall behind a full process-tree scan every 1.5s.** (#93) The metadata
  refresher held the registry lock — the one every IPC request needs — across an
  all-system-PIDs walk per pane (measured 6–12ms at 10–20 panes). The scan now runs off-lock
  with identity-checked write-back, plus a `childPID` read race and the log-rotation race fixed
  and the PID file made owner-checked.
- **Children that ignore SIGTERM+SIGHUP leaked a blocked reaper thread per close.** (#93)
  `close()`/`respawn()` now escalate to SIGKILL after a grace period, with PID-reuse guards;
  the watcher remains the sole reaper.
- **Thai: SARA AM after a marked base rendered a dotted circle** (น้ำ, ต่ำ, ซ้ำ). (#94, closes #66)
  U+0E33 now decomposes on input into NIKHAHIT (folded onto the base) + SARA AA, so CoreText never
  shapes an orphaned spacing mark; buffer search splits the needle the same way so precomposed
  queries keep matching, and the cursor-text color now applies on marked clusters.
- **`harness-cli bind-hook --if <cond>` crashed with a Swift range trap.** (#92) Malformed
  argument shapes now print usage and exit 1 before any IPC.
- **Invalid `--detach-keys` silently attached with the default detach binding.** (#92) Both attach
  paths now fail loudly (exit 64) naming the bad value and accepted formats; `new-split --pane`
  and `select-layout --main` with a malformed UUID now error instead of silently acting on the
  active pane.
- **CSI parameters above 65535 dropped the whole control sequence.** (#91) `ESC[99999H` (the
  "jump to bottom" idiom) was a no-op; oversized values now clamp (xterm/Ghostty parity) while the
  DoS guards for parameter count stay intact. Invalid DECSTBM (`top ≥ bottom`) no longer clobbers
  the scroll region and homes the cursor (now a no-op), and DECRC without a prior DECSC restores
  the default pen instead of leaking the current SGR state.
- **`fontSize` from a hand-edited settings.json was unclamped.** (#89) Extreme values blanked
  glyphs (atlas overflow at ~500pt) or allocated hundreds of MB of grid (sub-1pt); the persistence
  boundary now clamps to the same 8–32 the zoom shortcuts use. An empty font family now falls back
  to Menlo like an unknown one.
- **Re-running onboarding from an older Harness.app could silently downgrade newer installed
  binaries.** (#90) Install is now version-aware (build-number probe): byte-identical copies are
  skipped and a newer installed daemon/CLI is kept, with the outcome shown in the wizard.
- **The onboarding fish completion drifted from the real CLI.** (#90) The wizard now uses the same
  catalog-driven generator as `harness-cli completions`; the catalog gained the missing verbs and
  a drift-guard test asserts it covers every dispatch case.

### Changed
- **Slider drags persist once on release.** (#89) Opacity/blur/border/contrast drags wrote
  settings.json on every tick (60–120Hz); live-apply is now decoupled from persistence.
- **Destructive resets ask first.** (#89) "Reset to defaults" and "Reset agent colors" confirm
  before wiping; the resize-overlay position picker is now exposed in Appearance.
- **Hex color fields and the notification threshold re-sync after commit** instead of silently
  reverting invalid input. (#89)
- **A disconnected pane now shows a "Reconnecting…" chip** instead of freezing silently for up to
  a minute, and the Settings Advanced page shows an explicit banner (controls disabled) when the
  daemon is unreachable instead of rendering defaults as if they were real. Session IPC requests
  past 250ms now emit throttled signposts. (#95)
- **Onboarding locks navigation while installs run, notes when the CLI won't be on PATH, and
  rescans for agents when the window regains focus.** (#90)

### Added
- **SSH tunnel characterization tests** (16 — the remote-host path previously had zero coverage)
  and a **GridCompositor drift canary** asserting the onboarding preview's compositor port stays
  byte-identical to the live one. (#88)

## [1.6.0] - 2026-06-05

The redraw-efficiency release, from a proven-best-practice deep dive (kitty/foot/Alacritty/
Windows Terminal parity + Apple Metal guidance): overlays no longer disable damage-driven
rendering, streaming output reuses the scrolled band, and invisible panes stop presenting.

### Changed
- **Selection, find highlights, and IME composition ride damage-driven rendering.** (#85) Any of
  these used to force a full grid rebuild every frame for their whole duration and poison the
  reuse caches. The live view now always builds clean and a cell-overlay pass re-shades only the
  overlay rows (byte-identical by construction — it runs the same row resolver the baked path
  used); per-row fingerprints add exactly the changed rows to the damage. A selection drag
  re-encodes the rows it crossed instead of the grid; an idle find bar adds zero per-frame work;
  composition dirties only its row.
- **Streaming output shift-copies the scrolled band.** (#84) Whole-viewport scrolls (`cat`,
  builds, `tail -f`) report a purely additive damage hint; the frame builder re-resolves only the
  fresh rows and the renderer rotates its row-instance cache, as it already did for scrollback
  scrolls. Frame builds during streaming: 299µs → 74µs per tick at 200×60 (4×).
- **Covered and minimized windows stop presenting.** (#86) A pane with output flowing in a fully
  occluded window presented invisibly at full cadence; per Apple guidance it now never acquires a
  drawable while covered (parsing continues; one fresh frame presents on un-occlusion).
- **ProMotion displays render at the panel's full rate while active.** (#83) The render display
  link now requests the variable-refresh panel's maximum via `preferredFrameRateRange`; the link
  still pauses at idle.
- **Frame telemetry: p99 percentiles and classified drops.** (#83) The signpost flush line gains
  p99 (tail dropouts were invisible between p95 and max) and splits dropped presents by cause
  (drawable-pool exhaustion vs encode failure). Cursor-blink cost is pinned by test at ≤1
  re-encoded row per toggle (#87).

## [1.5.1] - 2026-06-05

Cursor and resize-fluidity fixes on the live-resize release: the cursor no longer turns into a
permanent block after a TUI resets it, streaming output keeps moving while you drag, and the
per-boundary re-wrap is 3× faster on deep scrollback.

### Fixed
- **Cursor stuck as a thick block after running a TUI.** (#80) `CSI 0 SP q` (and the parameter-less
  `CSI SP q`) — the standard "reset cursor" sequence programs emit on exit — was mapped to a hard
  blinking block instead of the user's configured style (the Ghostty/kitty/xterm de-facto
  semantics). Because attach replays the persisted scrollback tail, a leaked reset re-applied the
  block at every launch, making it look permanent. `0` now resolves back to your configured
  cursor style; `1` remains the explicit blinking block.

### Changed
- **PTY output presents live during a drag.** (#81) Output arriving mid-drag (a TUI's redraw after
  `SIGWINCH`, streaming logs, keystroke echo) previously reached the screen only at the next
  cell-boundary commit — content rode one boundary behind the drag and froze while the pointer
  held still. Output now presents continuously during the drag inside explicit Core Animation
  transactions. The resize target moved into queue-shared state (`pendingResize`) applied by
  whichever build runs next, so the latest-wins build coalescing can never strand the grid at a
  stale size after the PTY vote went out.
- **Width reflow is 3× faster on deep scrollback.** (#82) The per-boundary re-wrap — paid at every
  cell-boundary crossing of a live drag — streamed source rows by reference and re-wraps
  wide-glyph-free lines with bulk slice copies instead of three full buffer materializations and
  per-cell stepping. Measured at the 10k-line scrollback cap (release): 30.25ms → 10.04ms per
  reflow (CJK-heavy content 1.5×; the drag preview 2.6×). Byte-identical to the previous
  algorithm across the golden corpus, property, fast-path, and preview-parity suites.

## [1.5.0] - 2026-06-05

The live-resize release: dragging a window edge now drives the running program in real time
(Ghostty parity), notifications split into per-event controls, and agents launched through
wrappers are recognized.

### Added
- **Real-time live resize (Ghostty parity).** (#77) Dragging the window edge now reflows the grid and
  signals the running program (`SIGWINCH`) at every cell boundary, so interactive programs
  (vim/htop/btop/tmux/less) and alternate-screen TUIs redraw *during* the drag instead of snapping
  at release. The authoritative reflow runs off-main with latest-wins coalescing (a fast drag runs
  ~1–3 reflows, not one per column), presents inside an explicit `CATransaction` so it flushes even
  when the pointer is held still, and the PTY vote coalesces per-fd and to distinct cell counts so
  the daemon isn't stormed. Default on, with a **Real-time resize** setting (`liveResizeReflow`)
  that reverts to the previous defer-to-release behavior. The non-mutating re-wrap preview is
  retained as instant feedback under the live reflow.
- **Tab persistence indicator.** (#78) A tab pinned to stay running after a clean quit
  ("Keep Tab Running After Quit") now shows a small accent pin at the leading edge of
  its tab pill — a tmux-style window flag — so kept-alive tabs are identifiable at a
  glance instead of only through the right-click checkmark. The pin also appears beside
  the tab in the overflow menu.
- **Granular notification settings.** (#79) Settings → Agents now splits notifications into
  *Notify me about* (per-event toggles for **Agent needs input**, **Agent finished**,
  **Terminal bell**, and **Command finished**) and *Delivery* (macOS banner + sound),
  so you can pick exactly which events ping you instead of one all-or-nothing switch.
  Defaults preserve prior behavior, and an existing "command finished" choice migrates
  automatically. Backed by a new `NotificationEvent` type and a sparse
  `notificationEvents` map in settings; only desktop banners are gated — the in-app
  bell/waiting indicators are unaffected.
- **Wrapper-aware agent detection (Hermes).** (#51) Agents launched through a wrapper —
  `python3 …/hermes --tui`, `uv run hermes`, `env FOO=1 hermes` — are now detected: the
  process scan parses wrapper argv with flag-aware semantics (a `-c` body never false-matches;
  non-wrapper commands never scan their arguments, so `vim hermes-notes.txt` stays invisible).
  Agents without a bundled icon get a monogram glyph in the tab pill and agent UI instead of
  falling back to generic text.

### Fixed
- **Focusing a pane clears its notification.** (#61) Clicking into a pane or ⌘-Tabbing back to
  the app now clears its waiting badge — previously only a programmatic tab switch did. The
  clear is gated on the tab actually showing a waiting badge, so ordinary focus changes skip
  the daemon round-trip.

## [1.4.1] - 2026-06-04

The resize-parity release: the live render path stops crossing full-frame value boundaries.
A width-drag boundary tick now costs the main thread no more than a sub-cell tick, and
steady-state frames cost O(damage), not O(grid) — the Ghostty `Contents` model.

### Performance
- **Async re-wrap preview.** (#72) Crossing a cell boundary mid-drag no longer blocks the main
  thread on the emulator queue for the reflow + full frame build (~3ms per crossing, scaling
  with grid height): the preview builds asynchronously with latest-wins coalescing and lands on
  the next hop, while the drag keeps re-presenting the cached frame at full frame rate. Under
  heavy output the re-wrap now works instead of being skipped. Hardening: previews coalesce in
  their own token namespace (output bursts during animated resizes — sidebar slides — can no
  longer cancel them), the debounced grid commit defers while the drag holds (a stationary
  >60ms hold used to freeze the screen until the next pointer move), and stale previews are
  dropped at drag end and across pane re-mounts.
- **Content-keyed row salvage.** (#76) A column-count change used to discard the renderer's
  whole row cache; rows whose rendered content is unchanged (hashed over every render-affecting
  field) now re-bind their cached instances across the width change — per crossing, the CPU
  instance encode drops 1510→338µs and the GPU upload 71KB→13KB; a non-rewrapping width change
  re-encodes zero rows.
- **Persistent instance arrays.** (#74) Every frame used to re-flatten all rows' instances into
  freshly allocated arrays (megabytes of copies per frame on large grids, even for a one-row
  keystroke). The renderer now owns persistent flat arrays with a per-row segment table and
  splices only dirty rows in place — clean rows' bytes are never touched, and steady state
  allocates nothing. Scattered damage (a status row plus the cursor row) uploads two row-sized
  spans instead of everything between them.
- **Images no longer disable render caching.** (#75) Any inline image (Sixel / Kitty / iTerm2)
  forced every frame of that pane to re-encode every row; images draw as a separate quad pass,
  so image-bearing panes now keep incremental row reuse — typing next to an image re-encodes
  one row instead of the whole grid.
>>>>>>> upstream/main

### Added
- **Expanded syntax highlighting** — Added keyword highlighting for Kotlin, Java, C/C++, Shell (bash/zsh), Ruby, Dart, Lua, PHP, SQL, HTML, CSS/SCSS. Total: 22 languages with full keywords + comments + strings + numbers coloring.

### Fixed
- **Preview/Production isolation** — `make preview` no longer interferes with a running production Harness app. Preview `DaemonLauncher` skips all LaunchAgent interaction (no `launchctl kickstart/relaunch`) when `HarnessPreviewHome` is set, using direct daemon spawn only.
- **Preview build speed** — `make preview` skips `swift build` when `.build/debug/Harness` is already up-to-date (source mtime check). Removed redundant pre-spawn of daemon from `preview.sh` — the app's `DaemonLauncher` handles it.

### Changed
- **LSP disabled by default** — LSP integration (hover, go-to-definition, diagnostics) commented out in `FileViewerViewController` and `FileEditorView`. File preview still works with syntax highlighting. Re-enable by uncommenting `LSPFileSession` usage and setting `lspAutoStart = true`.

## [2.0.0] - 2026-06-07

### Philosophy
**Terminal First, IDE Convenience** — Harness is a terminal, not an editor with a terminal panel. Every IDE feature is a shortcut that saves you from typing `cat`, `git status`, or `vim`.

### Added
- **File Editor Panel** — Split panel file viewer in the content area (30% editor, 70% terminal). Click a file in sidebar to preview; terminal stays dominant and fully usable.
- **Vi-like editing** — Files open in read-only mode (like `less`). Press `i` to enter INSERT mode, `Esc` to return to normal mode. `⌘S` to save.
- **Syntax highlighting** — Regex-based highlighting for Swift, TypeScript/JavaScript, Python, Rust, Go, JSON, YAML. Keywords, strings, comments, and numbers colored.
- **Line numbers gutter** — Monospaced line numbers alongside the editor with scroll sync.
- **Git diff gutter** — Colored 3px bars next to line numbers: green (added), yellow (modified), red (deleted). Runs `git diff` async on file load.
- **File tabs** — Open multiple files in tabs with close buttons. Tab bar above editor panel.
- **Quick Look** — Images and PDFs rendered inline (PNG, JPG, GIF, WebP, SVG, PDF).
- **Find & Replace** — `⌘F` for find bar, `⌘⇧F` for find and replace (native macOS NSTextFinder).
- **Undo/Redo** — `⌘Z` / `⌘⇧Z` with full NSTextView undo stack.
- **File tree context menu** — New File, New Folder, Reveal in Finder, Open in Default App, Copy Path, Copy Relative Path, Rename, Duplicate, Move to Trash.
- **Real-time sidebar position toggle** — Move sidebar left/right instantly via View menu or right-click toggle button. No restart required.
- **Right-click sidebar toggle** — Context menu on toggle button and session rows for "Move Sidebar to Left/Right".

### Changed
- **Split Down removed** — Vertical/downward splits removed from all menus, command palette, context menus, keybindings, and documentation. Split Right remains fully functional.
- **UI Polish (P6)** — SF Symbols everywhere, animated disclosure chevrons, `configurePillButton` shared helper, sidebar vibrancy `.sidebar` material, git stage checkbox pulse animation.
- **Git panel toasts** — Progress feedback for fetch/pull/push/stage operations.
- **Metal CADisplayLink fix** — `viewDidMoveToSuperview()` restarts display link on reparent, fixing terminal black screen after split.

## [1.6.0] - 2026-06-07

### Added
- **Right Sidebar support** — Added settings configuration to align the main Sessions/Files sidebar to either the left or right side of the window. Can be toggled via Settings panel under "Window" or via "View" menu ("Move Sidebar to Right" / "Move Sidebar to Left").
- **Dynamic Icons & Insets** — Sidebar toggle button symbols and position constraints dynamically update to match the sidebar alignment (e.g. `sidebar.left`/`sidebar.right`), preventing overlap with traffic lights and other controls.

## [1.5.0] - 2026-06-06

### Added
- **CMUX-style split panes** — Split right with ⌘D, navigate panes with ⌥⌘←→↑↓, close pane with ⌥⇧⌘W. Split buttons (split right + close) appear at top-right corner of each pane.
- **Enhanced Git panel** — Commit ▼ dropdown menu (Commit Tracked, Amend, Signoff). Sync button with per-remote submenus (Fetch From, Pull Rebase, Push To). Auto-switches between "Fetch ▼" and "Push ▼" based on upstream status.

### Changed
- **Removed pane-local surface tabs (S1/S2/S3)** — Replaced broken drag-to-split UX with CMUX-inspired keyboard shortcuts and icon buttons. Each pane is now 1 terminal (no multi-surface per pane).

### Known Issues
- Split down (⌘⇧D) causes terminal to go black (Metal CADisplayLink not re-activated on same-window reparent).
- Split 3+ panes stack to the right (nested binary 50/50). Planned fix: N-ary PaneNode + single NSSplitView with adjustSubviews().

## [1.3.0] - 2026-06-06

### Added
- **Antigravity / agy and Kiro support** — Full native support for the Antigravity agent family (process-tree detection, `agy`/`antigravity` title inference, custom brand color, and the Gemini spark vector brand mark) and the Kiro agent family (process-tree detection, custom brand color, and the official Kiro brand mark in the session UI).
- **File Tree Auto-Update & Git Status** — Integrated real-time FSEvents filesystem watcher for auto-refreshing the file tree on branch switches and file changes. Added Git status color indicators directly in the file tree (yellow for modified, green for untracked, red/strikethrough for deleted).
- **Richer Sidebar UI** — Default session titles now show the active AI agent name (e.g., `Claude Code`, `Codex`, `Antigravity`, `Kiro`), while the subtitle shows the repository name, active Git branch, running command/process, and directory path.
- **Dynamic Session Group Headers** — Enlarged font size/weight of group session names (`13 semibold`) and disclosure chevrons (`15 bold`), with dynamic color highlights on hover (`textSecondary` -> `textPrimary` white).

### Fixed
- **Sidebar Reload Performance (P1)** — Cached row calculations to eliminate O(N²) calculations during table reload.
- **O(1) Surface/Tab Registry Lookup (P3)** — Added `surfaceIndex` flat map dictionary to bypass triple-nested workspace/session/tab scanning.
- **Redundant Theme Application (P4)** — Guarded `applyThemeToAllHosts()` with a theme signature key to prevent expensive restyling on simple pane switches.
- **Split Pane Layout Flicker (P5)** — Synchronously enforced `layoutSubtreeIfNeeded()` during split pane construction to eliminate double-layout layout stutter/PTY SIGWINCH.
- **Metadata Probe Deduplication (P6)** — Deduplicated CWD path checking during metadata refreshes and extended the poll interval.

## [1.2.0] - 2026-06-06

### Added
- **Double-click window zoom & drag** — Enabled full-width window dragging and double-click maximizing/zooming across the entire top panel, including the empty space of the tab bar, the folder path/icon area in the middle of the titlebar, and the sidebar titlebar header region.
- **Grouped sessions options** — Added a context options menu (`...`) on project headers in the sidebar with options such as closing all sessions in the group, alongside disclosure chevrons to expand and collapse groups.

<<<<<<< HEAD
### Changed
- **Sidebar Tabs** — Simplified the sidebar tab navigation to show only "Sessions" and "Files" tabs, hiding the "Git" tab to keep the interface clean and focused.

## [1.1.2] - 2026-06-06

### Added
- **Grouped sessions** — sidebar project groups now render as headers, with a `+` affordance on each header to open a new session in that project root.

### Changed
- README and changelog now describe the grouped session sidebar and the group-header add action.
- Refreshed `graphify-out` artifacts for the current codebase snapshot without committing generated HTML.

### Fixed
- Version metadata is bumped in lockstep across `HarnessVersion.swift` and `Info.plist` for release packaging.

## [1.1.1] - 2026-06-06

### Added
- **Session row close** — session cards now show a `×` close affordance on hover and reuse the existing close-confirmation flow.
- **Run script** — `make run` / `Scripts/run.sh app` now provide one entrypoint for building, packaging, signing, and opening `Harness.app`; `make preview` remains the isolated preview path.

### Fixed
- README IDE sidebar section no longer contains stale merge-conflict markers.
- `HarnessVersion.swift` now matches the app bundle version metadata for packaging.

### Changed
- README quick install keeps developers on `make preview`, while `make run` now opens a production-style app bundle with embedded Sparkle framework.
- Refreshed `graphify-out` navigation artifacts without committed HTML output.

## [1.1.0] - 2026-06-06

### Added
- **Files tab** — SwiftUI rewrite: click folder name to expand/collapse (DisclosureGroup)
- **Files tab** — drag file or folder from tree into terminal pastes shell-quoted path (fixed)
- **Files tab** — lazy child loading on first folder expansion
- **Drag-to-terminal** — image drag support (writes temp PNG, pastes path)
- **Drag-to-terminal** — relaxed operation mask accepts `.generic` / `.every` source masks

### Fixed
- File tree drag-drop broken: removed `registerForDraggedTypes` on NSOutlineView that conflicted with drop routing
- File tree drag-drop broken: removed empty `outlineView.action` that blocked drag initiation
- App crash on launch (macOS 26 beta): `UNUserNotificationCenter.current()` throws during `dispatch_once` init — disabled all `UNUserNotificationCenter` calls in `DesktopNotifier` and `NotificationPermission`; sound fallback preserved

### Changed
- File tree rebuilt in SwiftUI (`List` + `DisclosureGroup`) — replaced 160-line NSOutlineView+delegate implementation with 100-line SwiftUI view
- Desktop notifications disabled on macOS 26 beta (system bug — re-enable when Apple fixes `UNUserNotificationCenter` init)

### Known Issues
- Git tab checkbox stage/unstage not receiving clicks (CASE-001 — needs Xcode View Debugger)
- Desktop notifications unavailable on macOS 26 beta (workaround: sound alert still plays)

## [1.0.0] - 2026-06-05

### Added
- **IDE Sidebar** — Sessions / Files / Git tabs with segmented control
- **Files tab** — project file tree (NSOutlineView) that follows active session cwd
- **Files tab** — right-click Copy Path / Copy Relative Path
- **Files tab** — drag files from tree into terminal to paste shell-quoted path
- **Git tab** — Zed-style Changes / History sub-tabs
- **Git tab** — stage/unstage checkboxes per file, Stage All button
- **Git tab** — commit message area + Commit Tracked button
- **Git tab** — History view with SourceTree-style commit cards (subject + author · time · hash)
- **Git tab** — branch switcher dropdown (click branch name)
- **Git tab** — Fetch ▾ sync dropdown (Fetch / Pull / Push / Force Push)
- **Session-as-tab** — tab bar shows sessions (1 session = 1 project), not tabs within a session
- **Tab bar +** — creates new session
- **Tab bar ✕** — always-visible close button on each tab
- **Sidebar +** — opens Finder to pick project folder for new session
- **Recent projects** — clock button dropdown of last 10 projects, auto-records from active sessions
- **Recent projects** — switches to existing session if project already open
- **Session row ✕** — always-visible close button on sidebar session cards
- **Sidebar toggle** — button appears at left of tab bar when sidebar is closed
- **agent-memory** — project memory system bootstrapped

### Changed
- Version reset to 1.0.0 (build 1) for fork
- README updated with fork links, installation instructions, IDE sidebar docs
- All GitHub links point to Vit129/harness-terminal

### Known Issues
- Git tab checkbox stage/unstage not receiving clicks (CASE-001 — needs Xcode View Debugger)
- File tree click/expand may not work in some layouts (same root cause as CASE-001)
=======
[1.5.1]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.5.1
[1.5.0]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.5.0
[1.4.1]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.4.1
[1.4.0]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.4.0
[1.3.2]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.3.2
[1.3.1]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.3.1
[1.3.0]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.3.0
[1.2.0]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.2.0
[1.1.2]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.1.2
[1.1.1]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.1.1
[1.1.0]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.1.0
[1.0.6]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.0.6
[1.0.5]: https://github.com/robzilla1738/harness-terminal/releases/tag/v1.0.5
>>>>>>> upstream/main
