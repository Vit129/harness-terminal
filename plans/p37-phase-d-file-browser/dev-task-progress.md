# Dev Task Progress — P37 Phase D: File preview, file attach, browser mirror

Last updated: 2026-07-13
Status: Completed

## Context

Continuation of P37 (mobile bridge). Pairing, real xterm.js client, and resize-sync already
shipped (v4.3.0+). Phase D is the former W4/W4b/W5 from the superseded p25 plan, confirmed by
user still needed: file preview, file/image attach (upload), and an embedded browser mirroring
the Mac's real `BrowserPaneView` (not an external Safari open, not an in-page WKWebView —
platform-impossible on a Safari PWA page).

No new bounded context. Everything runs inside the existing daemon process (`MobileBridgeServer`)
or forwards through the existing daemon→GUI push channel. Per-device permission scoping (file vs
shell vs browser) was considered and dropped — shell access already implies file+browser reach
transitively, so gating them separately adds nothing under the existing "shell access is shell
access" threat model.

## Artifacts
- Design: `agent-memory/plans/p37-mobile-connect-v1.md` (## Phase D section)
- Test Scripts: none pre-existing — this project verifies via `swift test --filter` + `Tests/robot/run.sh` + a scripted live-daemon WS client (see P37's own verification gates), not a TDD-skeleton-first flow

## Summary
- Total tasks: 15
- Completed: 15
- Remaining: 0 (post-ship bug-fix pass done as follow-up, see below)

## D1 — File preview (read-only)

### Server Logic
- [x] Add `.readFile(path:)` / `.listDirectory(path:)` handling to `MobileBridgeServer.handleControlMessage` (`MobileBridgeServer.swift`) — plain `FileManager` read/list in-process via new pure statics `readFileInfo(path:)`/`listDirectoryEntries(path:)`, same pattern as `ToolRegistry.readFile`/`.listDirectory`. No IPC round-trip — bridge already runs in the daemon process.
- [x] MIME/encoding detection: text-vs-binary split reuses the exact UTF-8-decode check `ToolRegistry.readFile` already uses (no extension allowlist needed for the split itself); binary gets a small extension→mimeType map (`imageMimeTypesByExtension`: png/jpg/jpeg/gif/webp) for `<img>`-able types, `application/octet-stream` otherwise.
- [x] Size cap: 5 MiB read ceiling (`maxFileReadBytes`), `truncated:true` past that. Correction from original plan: outgoing WS frames aren't capped by `IPCCodec.maxPayloadLength` at all (that's the separate control-socket IPC) — `encodeWSFrame` has no send-side limit, so 5 MiB is a sanity cap, not a protocol requirement.
- [x] ✅ Run test scripts — `Tests/KouenDaemonTests/MobileBridgeFilePreviewTests.swift` (7 tests: utf8 text, binary→base64+image mime, unknown-ext→octet-stream, missing path, directory-as-file, sorted listing with isDirectory flags, missing dir) — all pass. Full `swift test` green except a pre-existing, unrelated `UNUserNotificationCenter` sandbox crash documented at `SessionCoordinatorTypes.swift:51` (macOS-install-specific, nothing to do with this change). `Tests/robot/run.sh` 23/23.

### Client Application
- [x] Embedded page: files sheet (reuses `.list-header`/`.sessions`/`.session-card` classes as-is — zero new list CSS needed) with drill-in/up navigation, opened via a new 📁 toolbar button in `.term-header`; preview view (`#view-file`, wired into the existing `goto()` view switcher) renders `<pre>` for text, `<img src="data:...">` for images, a fallback message for anything else.
- [x] ✅ Run test scripts — `swift test --filter MobileBridge`, `Tests/robot/run.sh` (23/23) both green. Additionally verified LIVE against a real isolated daemon (`make mobile-web`) through a real Chrome tab (not just the WKWebView `kouenBrowserOpen` pane — that one silently failed to open the WS connection at all, root cause not yet understood, noted below as a follow-up rather than blocking this task): full flow exercised — pair → session list → attach → open files sheet (defaulted to the session's own cwd) → drill into `subdir` (renders "Empty directory") → up-navigate back → open `notes.txt` (renders exact text content) → open `pixel.png` (renders the actual base64 image). All matched expectations exactly.

**Note for later:** `mcp__kouen__kouenBrowserOpen` (Kouen's own WKWebView browser pane) opened this page fine but its WebSocket connection silently closed with no error reaching the daemon at all (`ws.onerror` fired client-side, zero corresponding connection ever logged server-side) — worth a follow-up investigation (WKWebView ATS or App-Bound Domains restriction is the leading guess) since it means that pane can't currently be used to dogfood mobile-bridge pages from the desktop app itself. Not a regression from this change and not blocking — real Chrome and (per P37's own gates) a real phone are the actual target clients.

## D2 — File/image attach (upload)

### Server Logic
- [x] **Blocking prerequisite found while building D1 (2026-07-12):** the real incoming-frame ceiling is `MobileBridgeServer.maxWSFrameBytes` (was 64 KiB), enforced by `parseOneWSFrame`/`drainFrames` — NOT the 16 MiB `IPCCodec.maxPayloadLength` this doc originally assumed. Fixed: raised to 8 MiB (headroom above a 5 MiB raw file's base64 size) and swapped the `.oversized` abrupt `connection.cancel()` for `rejectAndClose` with a proper `{"error":"message too large"}`.
- [x] Add `.attachFile(name:mimeType:content:)` handling to `handleControlMessage` — decode base64, write to temp path via new `writeAttachedFile(name:data:)`, paste shell-quoted path into the attached surface's PTY input via `subscription.sendInput`. Reuses `KouenPaths.pastedImagesDirectory` (same dir/permissions/naming convention as desktop's `PasteController.writePastedImage`, not importable directly — AppKit target — so the convention is replicated) and `KouenSettings.ShellQuoting.quote` directly (importable, zero duplication — `KouenDaemonCore` already depends on `KouenSettings`). Filename comes only from the caller's extension, never a full path component, so `name` can't path-traverse.
- [x] Size cap on raw upload: reuses `maxFileReadBytes` (5 MiB, same constant D1 already defined) rather than inventing a second cap.
- [x] ✅ Run test scripts — `Tests/KouenDaemonTests/MobileBridgeAttachFileTests.swift` (5 tests: extension preserved, no-extension name, path-traversal-safe via extension-only usage, 0o644 permissions, 24h prune-on-write) — all pass. Full suite 80/80 (25 skipped, pre-existing sandbox noise), `Tests/robot/run.sh` 23/23.

### Client Application
- [x] Embedded page: attach affordance is a leading "Upload photo or file" row in the files sheet (locked design decision, see Phase E below — not a 4th toolbar icon), wired to a hidden `<input type="file">`. `FileReader.readAsDataURL` → strip the `data:...;base64,` prefix → `{"attachFile":{name,mimeType,content}}` over the existing control-frame channel. Client-side 5 MiB pre-check mirrors the server's own cap so an oversized pick fails fast instead of wasting a slow mobile upload.
- [x] ✅ Run test scripts — `swift test --filter MobileBridge` (85/85), `Tests/robot/run.sh` (23/23). Live-verified against a real isolated daemon (`make mobile-web`) through real Chrome: attached a session, opened the files sheet, dispatched the real `attachSelectedFile` client function against constructed `File` objects (native OS file-picker dialogs aren't automatable through the available browser tools) for both a text file and a binary PNG-header blob — both wrote correctly to `pasted-images/` (content byte-for-byte verified via `xxd`/`cat` on disk) and the shell-quoted path appeared typed into the live terminal, matching the desktop drag-drop flow's end state exactly.

## D3 — Browser mirror (embedded, mirrors Mac's real BrowserPaneView)

### Server Logic
- [x] Add `.browserNavigate(url:)` / `.browserSnapshot` / `.browserInteract(ref:action:)` / `.browserScreenshot` handling to `handleControlMessage` — forward through the existing `browserOpen`/`browserNavigate`/`browserSnapshot`/`browserInteract`/`browserScreenshot`/`browserWait`/`browserClose` IPC cases (`DaemonServer.swift:326-439`), confirmed already fully wired end-to-end to a real `BrowserPaneView` via `DaemonSyncService.handleBrowserRequest` — zero new IPC surface, same `DaemonClient.request(...)` pattern every other MobileBridgeServer operation already uses. `state.browserPaneID` tracks the mirrored pane per connection, opened lazily on first navigate.
- [x] `.browserFrame` push: on-demand base64 PNG from `BrowserPaneView.screenshot()` via `.browserScreenshot` — manual refresh only (client button), no polling built, per the risk note.
- [x] **Two-pass code review (own pass + independent Fable-model agent pass, both converged) found and fixed 3 real bugs before commit:**
  1. Stale `state.browserPaneID` never cleared on a `.error` response (e.g. the Mac user closed the mirrored pane) — every subsequent navigate kept re-targeting the dead pane forever, no recovery short of a full WS reconnect. Fixed: extracted the transition into a pure, testable `nextBrowserPaneID(current:response:)` — `.error` now clears to nil so the next navigate falls through to `.browserOpen`.
  2. Browser panes accumulated on the Mac across iOS's automatic WS reconnects (screen-lock drops the socket; existing `reconnectIfDropped` client logic reopens it) — the old pane was never closed. Fixed: best-effort `.browserClose(paneID:)` fired from the connection's real teardown site (`stateUpdateHandler`'s `.cancelled/.failed` case), off `controlQueue` so a hung GUI can't stall other connections' teardown.
  3. The client's auto-refresh-snapshot-after-navigate raced the real page load, since `DaemonSyncService`'s `.navigate` case acks `.ok` immediately after calling `view.navigate(to:)`, before the page finishes loading — the element list shown after "Go" was systematically the *previous* page's. Fixed: `handleBrowserNavigate` now calls the existing (previously unused by the bridge) `.browserWait(paneID:timeoutSeconds:10)` best-effort before acking, reusing IPC the MCP tool's own load-wait path already established.
  - **Held for separate explicit sign-off, not yet fixed:** a 4th finding — `BrowserPaneView.snapshot()`'s element-enumeration selector (11 selectors) doesn't match `DaemonSyncService`'s interact selector (6 selectors), so a page with an element matched only by the extra 5 (`[role=link]`/`[role=checkbox]`/etc.) before the tapped one causes interact to click the wrong element by index. Pre-existing in the `kouenBrowserInteract` MCP tool too — fix touches shared code the live MCP browser tools also depend on, deliberately not bundled into this phase's commit.
- [x] ✅ Run test scripts — `Tests/KouenDaemonTests/MobileBridgeBrowserTests.swift` (5 tests guarding the paneID state-transition, including the exact regression above) — all pass. Full suite 87/87 (27 skipped, pre-existing sandbox noise), `Tests/robot/run.sh` 23/23.

### Client Application
- [x] Embedded page: browser view (🌐 toolbar icon) — url bar, snapshot-driven tappable element list (`browserElementRow`, ref-based via `browserInteract(ref, action, text)` — not raw x/y hit-testing, matches the MCP tool's own contract), manual "Refresh screenshot" button. Deliberately minimal chrome for this MVP, NOT the tab-strip/webview redesign locked in the Phase E design session — that's separate, not-yet-built scope.
- [x] ✅ Run test scripts — `swift test --filter MobileBridge` (87/87), `Tests/robot/run.sh` (23/23). Live-verified the WS wiring against a real isolated daemon (`make mobile-web`, no GUI) through real Chrome: navigate correctly round-tripped through `forwardBrowserRequest` and surfaced a clean `{"error":...}` to the phone (a "Request timed out" — expected, since with no real GUI running the daemon's `guiBrowserFD` fallback pointed at the bridge's own non-browser-aware snapshot subscription; not a bug, an environment artifact of testing without a real GUI). **Not yet done:** a full round trip against a real `BrowserPaneView` (needs `make preview` with a real GUI window) — attempted, aborted mid-session (user redirected to a full-codebase review instead); flagged here as a genuine open item, same as "real phone E2E" is already flagged for every other phase.

## Integration
- [x] End-to-end wiring — live-verified through one continuous connection: attached a session,
      opened the files sheet, opened both a binary (`.DS_Store`) and text (`.CFUserTextEncoding`)
      file in the tab-strip preview, opened the browser mirror — all in sequence, no reconnect
      needed between capabilities.
- [x] ✅ Run all test scripts (verify GREEN) — `swift build` clean, `swift test --filter
      MobileBridge` 42/42 (3 skipped, live-daemon only), `Tests/robot/run.sh` 23/23. Full
      unfiltered `swift test` has 3 pre-existing failures unrelated to this feature
      (`ExperienceModeTests`, `Phase6KeysTests`, `ReleaseNotesGuardTests` — CHANGELOG/release-notes
      drift, nothing touched by Phase D work).
- [x] Live check against a real isolated daemon (`KOUEN_HOME`-scoped, `Scripts/mobile-web.sh`) —
      done via real browser (Kouen's own `kouenBrowserOpen` pane; `claude-in-chrome` used as
      fallback once mid-session, see bug-fix pass below), not a scripted WS client — matches every
      other phase's own verification convention in this project.
- [x] Code review — see the live bug-fix pass below; findings came from the user's own manual
      testing on a real iPhone rather than a `review-personas` pass, but covered the same ground
      (3 real, confirmed issues found and fixed).

## Post-ship bug-fix pass (real iPhone Safari testing, 2026-07-13)

User live-tested this phase on a real phone (not just desktop-Chrome/Kouen-pane automation) and
found 3 issues; one was a misexpectation, two were real bugs with root causes traced from source
before fixing (debug-mantra: reproduce → know the fail path → fix):

1. **CONFIRMED, FIXED — terminal double-wrap/garbled text on real narrow phone width.**
   Root cause: `mountTerminal()` called `fitAddon.fit()`/`sendResize()` *before* `goto('term')`
   made `#view-term` visible (`.view{display:none}` is the default, `goto()` is what adds
   `.active`). `FitAddon.fit()` measuring a hidden (0-width) container is a no-op, so the fresh
   `Terminal`'s untouched 80×24 default got shipped to the real shell via `sendResize()` — the
   shell then wrapped its output assuming 80 real columns, and xterm re-wrapped that already-
   wrapped output a second time once the real (much narrower) container became visible, producing
   exactly the interleaved/garbled text reported. Survived every earlier live-check because those
   all ran in wide desktop Chrome windows, where a correctly-measured width is close enough to 80
   cols to mask the bug — Phase E's own doc already flagged "phone-width live re-check" as
   unverified; this was that gap.
   Fix: reordered so `goto('term')`/`closeSheet()` run before `fitAddon.fit()`/`sendResize()`.
   Live re-verified against a genuinely narrow real pane (innerWidth 573px): `term.cols` now
   correctly computes `67` (matching the real ~560px container) instead of the stale `80` default.
2. **CONFIRMED, FIXED — "Upload photo or file" tap did nothing on real iPhone Safari.**
   Static analysis of the click chain in desktop Chrome found no JS error and correct wiring
   (`onclick` → hidden `<input type="file">`.click()`), so the failure couldn't be reproduced
   there — consistent with D2's own prior note that the real click→native-picker path was never
   actually verified on any device (D2's live-check used JS-constructed `File` objects instead of
   a real tap). Root cause: `#attach-input` used `style="display:none"` — a known WebKit/mobile-
   Safari trap where a `display:none` file input's `.click()` can silently no-op (no error, no
   picker) even from a real trusted tap; the standard cross-browser-safe pattern keeps the input
   out of visual flow but still laid out (`position:absolute; width:1px; height:1px; clip:rect(...)`
   etc.) specifically to avoid this. Fix applied; **not verified live** — this class of bug is
   invisible to browser automation by nature (the native OS picker isn't part of the DOM/render
   tree), so confirming it actually opens now needs the user's real phone.
3. **NOT A BUG — right-click context menu on file/folder rows.** Checked `design.md` and this
   file: no context menu was ever designed or built for the files sheet — tap-to-select (G1) /
   tap-to-preview (D1) is the entire interaction model. Right-click showing the browser's own
   default menu is expected, not broken. If wanted, that's new scope, not a fix.

Also shipped as a small feature in the same pass: a **copy-path icon** in the preview toolbar
(`#preview-copy`, between reload and the path field) — copies whatever `preview-pathfield` shows
(real file path on a file tab, current URL on a browser tab) via `navigator.clipboard.writeText`
with an `execCommand('copy')` fallback (the clipboard API needs a secure context, and this page is
normally served over plain http on LAN/Tailscale — not `localhost` — where it's often unavailable).
Live-verified: `execCommand('copy')` returns `true` in the live pane.

All 3 changes: `swift build` clean, `swift test --filter MobileBridge` 42/42, `Tests/robot/run.sh`
23/23 after each edit.

## Phase E — Preview chrome redesign + tablet layout (locked design, not yet built)

Design session 2026-07-12, artifact: https://claude.ai/code/artifact/f97619f7-dff3-41b6-8df9-7d8bf4ff2f64 (frames 01–06; 05's docked side-panel was explored and explicitly rejected in favor of 06 — see decision below). Scope confirmed with user to start **after D2 ships**, not instead of it.

**Locked decisions:**
- File preview (D1's current `#view-file`, plain `<pre>`/`<img>`) gets replaced by a **tab strip + webview-style chrome**, ported from desktop's own `FileEditorTabBarView`/`FileTabPillView` (26px pill tabs, accent top-edge on active, `×` close — multiple files open at once, not one-at-a-time) and `BrowserPaneView`'s toolbar shape (back/forward/reload/path field, reused verbatim — path field just shows a file path today, becomes a real URL field once D3 lands and reuses the *same* chrome for a mirrored browser tab).
- Tablet (≥768px): persistent left rail replaces the phone's full-screen session list + bottom switcher sheet (mirrors the desktop app's own sidebar+terminal shape). Rail is independently collapsible (toggle in the terminal header collapses it to a 40px strip with just a reopen control + session-count badge — never a dead end).
- Opening a file (or later, a mirrored browser page) is a **full-screen takeover** on tablet — same pattern as Facebook/Instagram's in-app browser (SFSafariViewController-style): rail and terminal are fully hidden, not squeezed into a side panel. A single back button (top-left, same convention already used everywhere on this page) is the only way out, back to the terminal. On phone this needs no new layout — phone preview was already full-screen, it just gains the new tab-strip/webview chrome (frame 04).
- **Explicitly dropped:** the docked right-side panel (frame 05) — user's call after comparing both: a 300px panel is cramped for actually reading a file or a mirrored page; full-screen reads better for both phone and tablet, one pattern instead of two.

**Not yet task-broken-down** — do this properly (read the artifact, re-open `dev-architect`/`task-design` for this phase specifically) once D2 is fully shipped and committed. Flagging now only so it isn't lost: this is real new scope (multi-tab preview state, a new tablet breakpoint, rail collapse state, full-screen modal takeover), not a styling tweak on top of D1.

**BUILT 2026-07-12.** Two blocking design gaps an Opus-model pre-implementation review surfaced were resolved with the user before coding: (Q1) at most **1 browser tab per connection** (not a map of many — simpler, and avoids a Mac-side pane leak on teardown); (Q2) the ported webview toolbar's back/forward/reload are **hidden/disabled on file tabs**, real and functional on the browser tab.

- [x] Unified `#view-preview` (tab strip + webview chrome) replaces D1's `#view-file` and D3's `#view-browser`. Multiple file tabs can be open; the single browser tab is reused/renavigated rather than duplicated. Routing uses the response's own natural key (file `path`, the single browser tab) — no wire-protocol tab-id was added; a late response for a background tab updates its cache but never steals focus (`goto`/view-switch only happens at open-time, not on response).
- [x] Reconnect handling for the browser tab (the one Opus flagged as a real gap): on every `ws.onopen`, the cached snapshot/frame is cleared, since a fresh connection means a fresh server-side `ConnectionState` and the old `browserPaneID` is gone — the tab doesn't keep showing stale content as if still live.
- [x] New backend: `browserGoBack`/`browserGoForward`/`browserReload`/`browserClose` control messages + handlers — all reuse already-wired `IPCRequest` cases (zero new IPC), matching D3's established pattern exactly. `browserClose` fires on explicit tab-close (×), not just connection teardown (D3 only had the latter).
- [x] Tablet (≥768px): `#tablet-rail` (persistent session list, additive — phone's `<768px` path untouched) + independent collapse (`toggleRailCollapse`, 40px strip, always-reachable reopen control) + `fitAddon.fit()` on collapse/expand (container-resize, not viewport-resize — FitAddon doesn't see it otherwise) + `view-term`'s own empty state ("Select a session from the sidebar") when nothing's attached yet. Opening any preview tab is a full-screen takeover on tablet too (`body.preview-active` hides the rail), same back-button convention used everywhere else on this page.
- [x] ✅ Live-verified (real isolated daemon, real Chrome, tablet-width viewport — the tested window came up ≥768px so this exercised the tablet path directly): rail + empty-state term view on first pair; attach keeps rail visible; open `hello.txt` → full-screen takeover, tab strip shows one pill, nav buttons correctly hidden (file tab); open `second.txt` → two pills, switching preserves cached content with no re-fetch flash; close (×) `second.txt` → correctly re-activates `hello.txt`; rail collapse/expand → terminal re-fits; `openBrowserTab` → nav buttons become visible (browser tab), editable URL field, browser toolbar shown; close browser tab mid-request → clean re-activation, no crash, server error surfaces via the banner (same expected "no GUI attached" timeout D3 already documented, this harness has no real `BrowserPaneView`).
- [ ] **Not verified:** phone-width (`<768px`) live re-check specifically for Phase E — the phone code path itself is unchanged (D1/D2/D3 already verified it live; Phase E's phone-facing changes are the tab-strip/webview chrome replacing single-file/single-browser views, which reuses the same `.view`/`goto()` mechanism already proven). Structurally sound by code review, not re-confirmed live under time constraints — flagging honestly rather than claiming full coverage.
- [ ] Real-GUI round trip for the browser tab (navigate → real `BrowserPaneView` → snapshot → interact) — same open item D3 already carried, still not done; needs `make preview` with a real GUI window, attempted once this session and aborted for the code-review detour.

**Second Opus-model pass (post-implementation, independent) found and Sonnet fixed 3 issues, commit `4a782d69`:**
- **[Important]** `#term-empty`'s only `display` rule lived entirely inside the tablet media query — phone had no base rule, so the tablet-only empty-state label was rendering above the live terminal on every phone session. Fixed: base `display:none` moved outside the media query.
- **[Suggestion]** `handleBrowserNavHistory` (back/forward/reload, added this phase) skipped the same `waitForBrowserLoad` call `handleBrowserNavigate` already needed — the auto-refreshed element list after a history nav was systematically a beat early. Fixed by reusing the same wait (severity was already capped by the `bdfbb0b6` ref-based lookup fix: stale ref → clean "not found", never a wrong click).
- **[Suggestion]** Dead `#file-body` CSS (orphaned when Phase E folded the single-file view into `#preview-body`) retargeted rather than deleted — deleting outright would have silently shipped file-preview text with no padding/code-font/wrap.

Everything else the reviewer checked (cross-boundary WS↔ControlMessage contract completeness, tab state-machine edges — last-tab-close/non-active-close/rapid-double-open/empty-array reads, `sessionCard()` reuse across 3 render targets, `handleBrowserClose`'s deliberate no-guard idempotency, `bdfbb0b6`'s stamp-order/escaping/pre-existing-attribute handling) came back clean.

## Risks carried into implementation
- D3 interaction latency/touch-mapping is the one open UX question in the design — validate snapshot+ref-tap manually before investing in the screenshot-polling client UI.
- Real-phone E2E (camera QR scan → Safari → touch) still hasn't been done for any P37 phase, D included — scripted WS client only proves the protocol, not the on-device UX.
