# P37 — Mobile Connect v1: QR + Tailscale pairing, hardened + usable

> Continuation of P25 W1 (pairing MVP, shipped on `p25-mobile-web-mvp` `97afd2e4`).
> Numbered P37 because P35 (OAuth fix) / P36 (app icon) are already used — see plans INDEX.
> Design reference for the mobile client UI: `p25-mobile-session-switcher-design.html`
> (approved earlier — extend it, don't redesign).

## Current architecture (as shipped, build 195)

```
Kouen.app (GUI)
 └─ DaemonLauncher ── reads KouenSettings.mobileBridgeEnabled
     ├─ launchd path: LaunchAgentInstaller.install(mobileBridgePort:) → plist env var
     └─ DEBUG/preview path: spawnFallbackProcess(forceRestart:) → env var directly
KouenDaemon (launchd-owned)
 └─ main.swift: KOUEN_MOBILE_BRIDGE_PORT present → MobileBridgeServer.start()
     ├─ WS listeners  : loopback:7777 + tailscale:7777 (NWListener + NWProtocolWebSocket)
     ├─ Page listeners: loopback:8080 + tailscale:8080 (embeddedPageHTML, plain HTTP)
     ├─ Pairing loop  : 6-digit token, 15s lifetime, QR (half-block) → stdout, URL → daemon.log
     └─ PairedDeviceStore: persists device IDs, kouen-cli mobile-list-clients / mobile-revoke-client
Phone (Tailscale app, same tailnet)
 └─ Camera scan QR → http://<ts-ip>:8080/?token=NNNNNN&wsport=7777 → auto-connect WS
     → {"sessions":[…]} → attach/detach/spawn JSON control + binary PTY frames
```

## Risk review (ranked)

| # | Risk | Where | Severity | Phase |
|---|------|-------|----------|-------|
| R1 | **Token brute-force window**: 6-digit token, no attempt limit/throttle on WS auth. A hostile tailnet peer can hammer ~10^6 guesses across the 15s window with parallel connections. Tailscale membership is the only gate. | `receiveLoop` auth branch | High (within threat model "compromised tailnet device") | A |
| R2 | **"Paired device" persistence is cosmetic**: `PairedDeviceStore` registers devices, but reconnect auth still only accepts the *current 15s pairing token* — the store's own comment says a paired device shouldn't need a fresh QR scan, yet there's no re-auth-by-device-secret path. Every reconnect = walk to the Mac. | `receiveLoop` (auth only checks `pairingBox`) | High (UX + defeats the store's purpose) | A |
| R3 | **Everything runs on the daemon's `.main` queue**: all listeners and every connection (`connection.start(queue: .main)`, WS + page). One slow/flooding peer stalls the whole daemon event loop (PTY relay for every GUI pane included). | `makeListener` / `makePageListener` | Medium-High | A |
| R4 | **Port conflict is silent to the user**: 7777/8080 hardcoded; if squatted, listener fails with only a daemon.log line. Settings toggle looks on, nothing works, no UI feedback. (Already bitten once — a stale process squatted 8080 during W1 testing.) | `start()` error paths | Medium | B |
| R5 | **daemon.log grows forever while enabled**: pairing loop logs a URL every 15s (~5,760 lines/day) whether or not anyone intends to pair. | `runPairingLoop` | Medium | B |
| R6 | **No TLS on WS/page** — acceptable *only* because binds are loopback+Tailscale (WireGuard encrypts on the wire). Must stay that way; any future "bind LAN" change re-opens this. | design invariant | Low (documented) | — |
| R7 | **Embedded HTML string** in Swift: single source of truth (good) but no syntax checking; a bad edit ships silently. | `embeddedPageHTML` | Low | C |
| R8 | **QR only visible in daemon.log / dev console** — no in-app surface. Pairing UX requires reading a log file. | (gap, known since W1) | Medium (UX) | B |

## Phases

### Phase A — Hardening (daemon only, no UI)
- **A1 rate-limit pairing auth**: max 5 failed token attempts per pairing window across all connections → bridge refuses further auth attempts until the next token rotates; log the lockout. Constant-time token compare while at it.
- **A2 real device re-auth**: on first successful pairing, issue a per-device secret (UUID + random 32-byte token, stored in `PairedDeviceStore`, sent to the client once). Client stores it in `localStorage`; reconnect sends `{"deviceAuth":{"id":…,"secret":…}}` as the first TEXT frame instead of a pairing token. Revoke via existing `mobile-revoke-client` already cancels live connections — now it also invalidates the secret.
- **A3 move bridge off `.main`**: dedicated serial `DispatchQueue(label:"…mobile-bridge")` for listeners + connections. PTY data path already hops through `DaemonSubscription` callbacks — verify ordering guarantee (FIFO per connection) survives the queue change with a scripted-client echo test.
- Tests: extend the scripted WS client (`ws_probe.py` pattern) into `Tests/robot/` or a Swift test where feasible; lockout + re-auth round-trip + revoke-kills-secret.

### Phase B — In-app pairing UX (macOS Settings)
- **B1 IPC**: new `IPCRequest.mobilePairingInfo` → `IPCResponse.mobilePairingInfo(url: String?, secondsRemaining: Int, enabled: Bool)`. Daemon returns nil URL when bridge off.
- **B2 Settings ▸ Remote panel**: when toggle is ON, show native QR (reuse `CIQRCodeGenerator` → `NSImage`, ~200×200pt) + the URL + a countdown ring that refreshes with each token rotation. Errors surface here too (R4: "port 7777 in use — bridge not listening"). No more reading daemon.log.
- **B3 log hygiene** (R5): pairing loop only *logs* the URL when it changes state (start/stop/error); token rotations stop writing to daemon.log entirely — the GUI polls `mobilePairingInfo` instead.
- UI spec (native, matches existing Settings style — grouped Form):
  - Section "Mobile pairing" (existing toggle stays at top)
  - QR centered, `secondsRemaining` countdown as a thin `ProgressView` under it
  - URL as selectable monospace `Text` + copy button
  - Paired-devices list below (name, first-paired date, Revoke button) — data from `mobile-list-clients` IPC path

### Phase C — Real mobile client (W3, replaces smoke-test page) — DONE 2026-07-09, uncommitted
- xterm.js terminal + session-switcher list per `p25-mobile-session-switcher-design.html` (dark terminal aesthetic already specified there — implementation agent reads that file for tokens/layout, does NOT invent a new design). Shipped: `@xterm/xterm` 5.5.0 + `@xterm/addon-fit` 0.10.0 vendored from jsdelivr (user-confirmed source), all four views from the design doc (home/paired-toast/list/term/sheet).
- Served the same way (embedded in daemon; consider moving to a generated-resource step if the string gets unwieldy — R7). Shipped as-is, embedded — R7 accepted as designed. One twist R7 didn't anticipate: minified xterm.js has literal C0 control bytes (raw ESC 0x1B for mouse-tracking), which a raw Swift string literal rejects outright — vendored as base64 in a new `MobileBridgeWebAssets.swift` instead, decoded once at load.
- Reconnect flow uses A2 device secret (no re-scan). Shipped, reused as-is from Phase A.
- Resize-sync (old W2) folds in here: client sends `{"resize":{cols,rows}}`, daemon forwards to PTY. Shipped: `FitAddon` → `term.onResize` → WS → `handleControlMessage` → `DaemonSubscription.resize()` (per-connection vote, not a fresh `DaemonClient`).
- Out of scope for v1: file preview/attach, git panel, LSP, notifications (former W4+). Still out of scope, untouched.
- Verified: build clean (app+daemon), `MobileBridgePairingTests` 11/11, robot 10/10, AND a live scripted-WS round-trip (auth → sessions → spawn → attach → resize → real PTY echo → detach) against an isolated daemon instance — not just build-green (see MEMORY.md 2026-07-09).
- **Not done:** real-phone scan E2E (only scripted/loopback verified); deploy to the actual running app (`make prod`/`install` + relaunch).

### Phase D — File preview, file attach, browser mirror (v1.1 — the former W4/W4b/W5, now scoped)

Extends the existing `{"attach"/"detach"/"spawn"/"resize"}` WS vocabulary on the same connection. No new bounded context, no new process — everything below runs inside the daemon (`MobileBridgeServer` already runs in-process there) or forwards through the daemon→GUI push channel `.activateGUIWindow`/`browserOpen` already use.

**Permission scoping — deliberately dropped.** The original p25 plan wanted a per-device "shell only" vs "shell+files" vs "shell+files+browser" grant field on `PairedDeviceRecord`. Checked: no such field exists today, and it shouldn't be added — a device with shell access already has file and browser reach transitively (`cat`/`curl`/`open` from the PTY itself). Gating D1-D3 behind a separate capability the shell already grants is complexity with no real security benefit under the existing "shell access is shell access" threat model (`p37` intro). Skip it.

- **D1 — File preview (read-only).** New WS request `{"readFile":{"path":"..."}}` → `{"file":{"path","mimeType","content","encoding":"utf8"|"base64","truncated"}}`; `{"listDirectory":{"path":"..."}}` → entry list, for the phone's own file picker. Reuse target: `ToolRegistry.readFile`/`.listDirectory` (`Tools/kouen-mcp/Sources/KouenMCP/ToolRegistry.swift:324-360`) — both are a bare `FileManager.default.contents(atPath:)`/`contentsOfDirectory`, no IPC hop, because the caller already runs on the same machine. Mobile bridge is in the same position (in-process in the daemon) — call `FileManager` directly, don't add a round-trip through anything. New case in `handleControlMessage` (`MobileBridgeServer.swift:1273`). Cap reads below `IPCCodec.maxPayloadLength` (16 MiB) with real headroom (e.g. 5 MiB, `truncated:true` past that) — base64 for images adds ~33%. Client: new message handlers + a preview overlay in the embedded page (`<pre>` for text, `<img src="data:...">` for images).

- **D2 — File/image attach (upload).** New WS request `{"attachFile":{"name","mimeType","content":"<base64>"}}`. Daemon decodes, writes to a temp path, then pastes the shell-quoted path into the attached surface's PTY input — mirror the desktop drag-drop flow exactly: `KouenTerminalSurfaceView+Find.swift:233-257` (dropped file URL → paste path) and `PasteController.writePastedImage` (dropped image → temp PNG → paste path); reuse `shellQuote` (`FilePreviewCoordinator.swift:352`) rather than re-deriving quoting rules. Client: `<input type="file">` in the terminal toolbar, base64-encoded over the existing JSON control-frame channel. Cap raw upload size below the same 16 MiB ceiling with margin for base64 overhead.

- **D3 — Browser mirror (embedded, not external-open).** Confirmed with user: mobile "browser" means driving the Mac's real `BrowserPaneView` (`Apps/Kouen/Sources/KouenApp/UI/Chrome/BrowserPaneView.swift`, P14) remotely, not an in-page WKWebView (impossible — Safari can't host one) and not opening the phone's own Safari (that was the old W5, rejected as too shallow a reading of "embed"). New WS requests: `{"browserNavigate":{"url"}}`, `{"browserSnapshot"}` (element-ref tree, same shape `kouenBrowserSnapshot` MCP tool already returns — `KouenBrowserTools.swift:126`), `{"browserInteract":{"ref","action"}}` (ref-based, reusing the *same* contract `kouenBrowserInteract` uses — `KouenBrowserTools.swift:172` — deliberately not raw x/y touch coordinates, which don't map cleanly onto a desktop-rendered page), and `{"browserFrame":{"png":"<base64>"}}` pushes sourced from `BrowserPaneView.screenshot()` (`:871`) for the visual view. Wiring: `MobileBridgeServer` forwards through the same `browserOpen`/`forwardBrowserRequest` IPC path (`DaemonServer.swift:837`) the MCP tools already use, targeting the active `BrowserPaneView` tab (or opens one via its existing `.show()`/`direction` param). Open risk: streaming cadence and interaction cost — start with snapshot+ref-tap only (zero new native code, MCP path already does this today) before adding screenshot polling; only add frame streaming if ref-only proves too sparse for a human visually scanning a page.

Task order: **D1 → D2 → D3**, each independently shippable. D1/D2 are pure WS-glue + reused daemon-local file I/O (small). D3 is pure WS-glue + reused MCP browser-control path (small) but carries the only real open UX question (interaction latency/mapping) — validate that early with a manual round-trip before polishing the mobile page around it.

## Competitive comparison (2026-07-13, post Phase D+E)

Checked what mobile-terminal / remote-coding-agent apps ship today, to sanity-check whether D1-D3 + Phase E duplicate an already-solved problem or cover new ground.

| App | File preview | File/image attach (upload) | Embedded browser mirror | Mobile session switch | Notes |
|---|---|---|---|---|---|
| **Kouen (this)** | ✅ D1 — full-screen, text+image | ✅ D2 — native picker → PTY paste, mirrors desktop drag-drop | ✅ D3 — drives the real Mac `BrowserPaneView` (WKWebView) via ref-based snapshot/interact, not a screenshot stream, not opening the phone's own Safari | ✅ tab-strip + tablet rail (Phase E) | Local-first: daemon on the Mac, phone only ever talks to it over Tailscale WireGuard — no cloud hop |
| Termius | ✅ full-screen SFTP preview | ✅ paste/drag/share-sheet upload, path auto-pasted into terminal | ❌ none | ✅ (multi-connection side by side) | SFTP-based — separate protocol from the shell session, not driving the same PTY |
| Blink Shell | ❌ no file browser | ❌ (relies on `scp`/`sftp` from the shell itself) | ~ can run `code-server` (VS Code in browser) inside the session, not a mirrored native browser pane | ✅ tmux/Zellij/Herdr session picker | Strongest multiplexer story of the group; file/browser features are shell-native, not app-native |
| Prompt 3 (Panic) | ❌ explicitly none — no SFTP, no file browser by design | ❌ — pushes users to buy their separate Transmit app | ❌ none | ✅ (Panic Sync across devices) | Deliberately terminal-only scope; opposite philosophy from Kouen's "one app, one session" goal |
| Warp | — no mobile app at all | — | — | — (browser tab mirrors the desktop *session*, not phone-native) | Mobile story is literally "open a share link in mobile Safari"; not a comparable client |
| Claude Code Remote Control | N/A (not a terminal client — it's a chat/agent session view) | N/A | ❌ no browser mirror; `@`-autocompletes local file *paths* into the chat, doesn't preview/attach binary files | ✅ (session list in the Claude app) | Closest philosophically (local-first, phone is "a window into the local session") but scoped to agent chat, not a general PTY + files + browser |
| Cursor for iOS | shows diffs/generated artifacts, not arbitrary file preview | ❌ | ❌ | ✅ (agent list, push notifications) | Built around reviewing/approving agent work, not driving an interactive terminal + browser |
| **cmux** (manaflow-ai) | ❌ desktop file preview is still an open feature request (`manaflow-ai/cmux#1311`), so mobile has nothing to inherit yet | ❌ not documented | desktop has a real embedded browser pane (navigate/snapshot/click/type/evaluate — same ref-based DOM contract shape Kouen's `kouenBrowser*` tools use), but **no evidence it's mirrored to the iOS app** — landing page only documents desktop-side browser control | ✅ "cmux Remote" iOS app, Tailscale-paired, realtime terminal mirror + LIVE per-character input + push notifications | **Closest architectural cousin found**: native macOS terminal for AI agents + embedded browser pane + Tailscale-paired mobile companion is the same shape as Kouen's whole stack. But per available docs their mobile app stops at terminal mirror + notifications — file preview/attach and browser mirror on mobile are either unbuilt or undocumented, which is exactly the gap D1-D3 fill |
| tmux | ❌ (not tmux's job — pure multiplexer, no GUI) | ❌ | ❌ | ✅ (the reason it's paired with Termius/Blink at all — session persistence across disconnects) | Not a competing *app*, a protocol-level building block other apps (Termius, Blink) SSH into; zero file/browser features of its own |
| WezTerm | ❌ no built-in file browser found | ❌ not documented | ❌ no embedded/mirrored browser found | ✅ SSH domains / mux server — splits/tabs persist server-side, GUI can hot-swap/reattach without losing the session | Remote story is desktop-to-desktop (mux server over SSH) — no mobile client of its own, same "bring your own SSH app" story as tmux |

**Where Kouen sits:** D1/D2 (file preview + attach) are table stakes — Termius already does both well, so those phases bring Kouen to parity, not ahead. D3 (browser mirror) has no direct match in any surveyed app, **including cmux** — the one app whose desktop architecture (native terminal + embedded ref-based browser pane + Tailscale-paired mobile companion) is closest to Kouen's own, and whose mobile app stops at terminal-mirror-plus-notifications, leaving file preview/attach and browser mirror on mobile either unbuilt (cmux's own desktop file preview is still an open GitHub issue) or undocumented. Termius/Blink/Prompt3 don't touch a browser at all, and the agent-native apps (Claude Code Remote Control, Cursor iOS) don't drive an actual rendered browser pane either — they work with diffs/chat/artifacts instead. The closest *conceptual* cousin outside cmux is Blink's `code-server`-in-browser, but that's a code editor tunnel, not a mirrored native browser pane with ref-based element interaction. D3 is Kouen's most differentiated mobile-bridge feature, not an incremental one — and per this survey, nobody else has shipped the mobile half of it yet.

**Where Kouen is behind:** every surveyed competitor ships a real phone-QA'd, real-App-Store product; Kouen's own real-phone E2E (camera scan → Safari → touch) has never actually been run (flagged since Phase C, still open). Feature parity on paper doesn't cover UX rough edges (keyboard handling, touch latency, connection drop recovery) that Termius/Blink have had years to sand down.

*(Web research 2026-07-13, sources: [Termius](https://termius.com/blog/rethinking-sftp-for-mobile), [Blink Shell](https://blink.sh/), [Prompt 3](https://blog.panic.com/introducing-prompt-3-now-on-all-of-your-devices/), [Warp](https://docs.warp.dev/agent-platform/cli-agents/remote-control/), [Claude Code Remote Control](https://code.claude.com/docs/en/remote-control), [Cursor for iOS](https://cursor.com/blog/ios-mobile-app), [cmux](https://cmux.com/), [cmux browser feature](https://manaflow-ai-cmux.mintlify.app/features/browser), [cmux file-preview feature request](https://github.com/manaflow-ai/cmux/issues/1311), [WezTerm multiplexing](https://wezterm.org/multiplexing.html) — not re-verified against source code, marketing-page/docs level comparison only.)*

## Phase F — candidates from competitive research (not scoped, not scheduled)

Pulled from the 2026-07-13 competitive survey above — ideas worth stealing, not a committed plan. Nothing here has a task breakdown or a green light; listed so they don't get lost, ranked by the two flagged as highest UX impact first.

- **F1 — "needs input" push notification** (cmux). cmux's Inbox ships APNs-backed push specifically for Claude/Codex-style "needs input" prompts, with a settings toggle so only actual blocking events raise an iOS banner (everything else lands quietly in an inbox with unread badges — not a banner per keystroke). Kouen has no mobile push today; a phone user has to keep the tab open to notice an agent stalled waiting for approval. Needs an APNs cert + a daemon-side "is anything waiting on input" signal — non-trivial, biggest lift on this list.
- **F2 — on-screen keyboard toolbar** (Blink Shell). ✅ **DONE 2026-07-13**, commit `9c4706f3`. Quick-tap row (Esc/Tab/^C/^D/arrows) pinned below `#xterm-container`, sending raw control sequences straight over the existing WS binary channel via a new `sendKeySeq(seq)` helper (also refactored `term.onData` to reuse it — same code path, no behavior change there). Visibility piggybacks on the existing `tablet-unattached` body class, no new state. Live-verified against a real PTY (isolated `make mobile-web` instance, real Chrome, not WKWebView — see `MEMORY.md` note on why): Tab triggered real zsh completion, ^C sent real SIGINT and cleared the line, Up-arrow recalled real shell history. Build clean, `MobileBridgePairingTests`/`MobileBridgeSpawnTests` 14/14 (3 skipped, live-daemon-only).
- **F3 — LIVE per-character input mode** (cmux). ✅ **Already true, confirmed 2026-07-13, no code change**. `term.onData(sendKeySeq)` (`MobileBridgeServer.swift:767`) fires per xterm.js keystroke and sends immediately over the WS — no batching/debounce ever existed here. Closed as a non-issue.
- **F4 — connection-drop resilience, Mosh-style** (Blink Shell / Claude Code Remote Control). ✅ **DONE 2026-07-13.** Reading the actual `reconnectIfDropped()`/`ws.onclose` code (not a live Mac-sleep/cellular test — couldn't force either scenario for real) surfaced 2 real gaps, both fixed:
  1. `reconnectIfDropped()` (fires on `visibilitychange`/`pageshow`) skipped reconnecting whenever `ws.readyState === OPEN` — but after the *Mac itself* sleeps (not just the phone backgrounding), the TCP can sit frozen the whole nap with the browser never told it died; `readyState` keeps reporting OPEN until a send/receive times out. Fixed: foregrounding now unconditionally detaches the old socket's handlers, closes it, and reconnects fresh — cheap and infrequent enough that forcing a refresh beats trying to detect staleness.
  2. Auto-reconnect only ever fired from `visibilitychange`/`pageshow` — a wifi↔cellular handoff happening while the tab stays foregrounded the whole time (never backgrounded) had zero automatic recovery, just a "Connection lost" banner and a manual reload. Fixed: `ws.onclose` now schedules an exponential-backoff retry (1s→2s→4s...capped 30s, reset on next successful `onopen`) whenever `authed` was true (a real session had been up) — a rejected pairing attempt (`!authed`) still doesn't retry-storm.
  Live-verified against the real isolated daemon (not just build-green): force-closed the live WS mid-session via `ws.close()` while `authed` — a brand-new socket came up OPEN automatically within ~1s (`reconnectAttempt` reset to 0 after). Separately called `reconnectIfDropped()` directly while the old socket still reported OPEN — confirmed it was torn down and replaced with a fresh OPEN connection anyway (old handlers nulled first, no stray close event corrupted state, no error banner flashed).
  `swift build` clean, `swift test --filter MobileBridge` 42/42, `Tests/robot/run.sh` 23/23.
  **Not tested** (no way to force these for real without the actual hardware/OS event): an actual Mac going to sleep, and a real cellular↔wifi radio handoff — the fixes address the code-level gaps that would cause failures in those scenarios, but the scenarios themselves weren't reproduced.
- **F5 — share-sheet upload entry point** (Termius). iOS share sheet ("share this photo/file to Kouen") as an alternate entry into D2's attach flow, instead of only a picker launched from inside the app. Native-iOS-integration work — bigger lift than F2/F3, needs an iOS share extension, which Kouen doesn't have any Swift/Xcode-project surface for today (the mobile client is the embedded web page, not a native iOS app). **Explicitly deferred 2026-07-13** — user declined to start a native iOS app project (would re-open the direction P25 abandoned in favor of this phase's web-based approach) once the real tradeoffs were surfaced (Apple Developer Program cost for wider distribution, App-Group pairing plumbing for the extension, "bare host app" vs "fuller companion app" scope creep). Hold until the web-based (PWA) mobile-bridge feature set is complete; do not restart without a fresh ask.
- **F6 — volume-button surface cycling** (cmux). Physical volume buttons cycle sessions/panes for one-handed switching. Low value relative to effort — parking, not pursuing, unless a future UX pass specifically targets one-handed use.

No task order implied — these compete with whatever the next real feature ask is, not with each other. Revisit when planning past Phase E.

## Verification gates (every phase)
- `swift build` + `swift test` green, `Tests/robot/run.sh` 10/10
- Live check against a real daemon (preview KOUEN_HOME flip, scripted WS client) — build-green alone is NOT done (see MEMORY.md 2026-07-07 lesson)
- Phase B: real phone scans QR from the Settings panel end-to-end
