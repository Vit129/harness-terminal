# Dev Task Progress — P37 Phase G: Autocomplete (mobile bridge)

Last updated: 2026-07-13
Status: Completed

## Context

Follows Phase F2 (keyboard toolbar, `9c4706f3`). Interview completed via `Skill(interview)` →
`doc.md` mode: user asked for autocomplete "ทั้งในหน้า terminal, ai" (both in the terminal page
and AI-flavored), which resolved into 3 distinct sub-features via AskUserQuestion — @ file-path
insertion, a shell tab-completion suggestion strip, and an AI-powered command suggestion via the
user's own `claude` CLI. No existing AI/LLM backend in this codebase (confirmed via grep — only
hit was an unrelated comment about the user's own separate `ANTHROPIC_API_KEY` env var for their
own CLI use); G3 deliberately reuses that CLI via subprocess rather than building new API
integration. No new bounded context — same reasoning every other Phase D/E/F entry already used.

## Artifacts
- Design: `agent-memory/plans/p37-phase-g-autocomplete/design.md`
- Test Scripts: none pre-existing — same convention as every other phase in this project:
  `swift test --filter` + `Tests/robot/run.sh` + live-daemon check via `make mobile-web`, not a
  TDD-skeleton-first flow

## Summary
- Total tasks: 28
- Completed: 28
- Remaining: 0
- Status: Completed

## G1 — @ file-path picker ✅ DONE 2026-07-13

**Deviation from design.md, smaller than planned:** design.md called for "a lightweight inline
picker (not D1's full-screen files sheet)". On implementation, reusing D1's existing files-sheet
DOM/CSS/state wholesale (`filesCwd`, `listFiles`, `fileEntryRow`, `renderFileEntries`) with a new
`filesPickerMode` flag turned out strictly smaller than building a second near-identical sheet —
same sheet, file-tap now branches `openFileTab(...)` (preview, D1) vs `insertFilePath(...)` (G1)
on the flag, D2's upload row hidden via the same flag. No new CSS at all.

### Client Application
- [x] Add `@` button to the existing `.kbd-toolbar` row (`embeddedPageHTML`, shipped in `9c4706f3`)
- [x] Picker UI — reused D1's files-sheet wholesale (see deviation note above) instead of a new
      one; drives navigation via the existing `listDirectory` WS request (D1, zero new
      server-side surface)
- [x] Path selection → client-side shell-quote (`shellQuotePath`, single-quote wrap) → insert via
      `sendKeySeq` (F2's existing helper)
- [x] Error handling: already covered for free — `listDirectory` failures already route through
      the existing generic `msg.error` → `showError()` path every WS response shares, nothing
      picker-specific needed
- [x] ✅ Run test scripts — `swift build` clean, `swift test --filter MobileBridge` (35/35, 3
      skipped live-daemon-only, as before — no new server-side code path so no new unit tests),
      `Tests/robot/run.sh` 23/23
- [x] Live check: real Chrome + isolated `make mobile-web` daemon (fresh instance, non-default
      ports to avoid the prod-daemon port conflict noted during F2 testing) — paired, attached
      `Shell` session, tapped `@`, picker opened showing the real home directory (125 items, D2's
      upload row correctly hidden), tapped `.DS_Store`, sheet closed and
      `'/Users/supavit.cho/.DS_Store'` landed correctly in the real PTY input line, shell-quoted
      exactly as designed

## G2 — shell tab-completion suggestion strip (heuristic, best-effort) ✅ DONE 2026-07-13

**Deviation from design.md, found via live-testing:** the original heuristic (cursor-row-moved
detection) was wrong — live-verified against a real zsh session, cursor position doesn't move at
all after a multi-candidate Tab listing. zsh prints candidates below the prompt line then restores
the cursor to its original position (a standard cursor save/restore trick so the in-progress
command line isn't visually disturbed). Rewrote as a **content diff** instead: snapshot a fixed
window of rows below the cursor before sending Tab, compare the same rows after — a row counts as
fresh completion output only if it was blank before and has content now. This is resilient to
cursor-restore behavior (what zsh actually does) and would also work in the design's originally
assumed case (cursor moves to a reprinted prompt below) since it only depends on content, not
cursor position.

### Client Application
- [x] `snapshotRowsBelowCursor()` / content-diff detection (~150ms debounce) — see deviation above
- [x] Heuristic token-list detection — hard rule holds: ambiguous result → show nothing
- [x] Render detected tokens as a tappable strip (`.suggest-strip`, shared component — G3 will
      reuse the same class/render function rather than a second strip)
- [x] Tap-to-insert via `sendKeySeq`, trailing space appended
- [x] ✅ Run test scripts — `swift build` clean, `swift test --filter MobileBridge` (35/35),
      `Tests/robot/run.sh` 23/23 (pure client heuristic, no new server-side test surface — no
      JS-level test harness built, live-check is the real verification for this one)
- [x] Live check: real Chrome + isolated daemon, real zsh session, typed `ls .a` (matches 10 real
      dotfiles/dirs in the home directory) and tapped Tab — real zsh menu appeared, strip rendered
      all 10 candidates correctly (`.ado_orgs.cache`, `.agents/`, `.amazon-q.dotfiles.bak/`, etc.,
      trailing `/` on directories preserved), tapped `.agents/` → inserted with trailing space,
      strip cleared. **Known UX rough edge, not fixed this pass**: zsh's listing shows full
      candidate names, not just the unmatched suffix, so tapping a candidate concatenates onto
      whatever prefix was already typed (`ls .a` + tap `.agents/` → `ls .a.agents/`, needs manual
      cleanup) — inherent to the heuristic (no visibility into "how much of the token the user
      already typed" without real completion-protocol integration, which was explicitly the
      shell-plugin option the interview rejected). **Not tested this session**: the
      single-candidate inline-complete case (no menu). High confidence it's a no-op by
      construction (nothing prints below the cursor, so the content diff finds nothing, so
      nothing renders) but not empirically observed — flagging rather than silently assuming.

## G3 — AI command suggestion (via `claude` CLI subprocess) ✅ DONE 2026-07-13

**Two deviations from design.md, both found via reading actual code / live-testing before/while
implementing:**

1. **Queue design was over-engineered relative to the codebase's own established pattern.**
   design.md called for a dedicated background dispatch queue, reasoning from the risk register's
   R3 note ("everything runs on `.main`, one slow peer stalls the whole daemon"). Reading
   `handleControlMessage`'s actual dispatch code before implementing showed every handler already
   runs on `state.controlQueue` — a queue instance **per connection**, not a shared one — and
   `handleBrowserNavigate` (right next to where G3's handler was added) already blocks that same
   per-connection queue for up to 31s on a live `DaemonClient.request` call, uncontested. A slow
   `claude` call on one connection's queue only delays that same connection's next message, never
   other connections/PTY relay — R3's actual unaddressed target is the network *listener* layer
   (Phase A3, still unbuilt), not this per-connection dispatch. Implemented the simpler way,
   synchronous on `controlQueue` like every sibling handler — no new queueing complexity.
2. **`claude` CLI path resolution needed a 3rd candidate, found by checking THIS machine.** The
   design assumed `GitHubCLIClient`'s Homebrew-only path list (`/opt/homebrew/bin`,
   `/usr/local/bin`) would generalize to `claude` the same way it does for `gh`. It doesn't — on
   this machine `claude` installs to `~/.local/bin/claude` (curl-installer default), which is
   also outside the launchd-daemon's inherited `PATH`, so the `which` fallback wouldn't have
   caught it either. Added `~/.local/bin/claude` as the first candidate.

### Server Logic
- [x] New WS message pair: `{"aiSuggest":{"commandBuffer","cwd"}}` →
      `{"aiSuggestion":{"suggestion"}}` / `{"error":...}` (reuses existing `ErrorAck` shape)
- [x] `claude` CLI path resolution — `~/.local/bin/claude` → Homebrew paths → `which` fallback
      (see deviation #2 above)
- [x] Subprocess invocation wrapped in a fixed prompt template (`buildSuggestPrompt`, extracted as
      a pure function specifically so it's unit-testable without spawning a process) — never
      passes `commandBuffer` to the CLI unwrapped
- [x] Runs synchronously on `state.controlQueue`, matching every sibling handler (see deviation #1
      above — no separate background dispatch queue, that would've been new complexity this
      codebase doesn't use anywhere else for comparably slow operations)
- [x] Timeout 20s — polls `process.isRunning` against a deadline, `process.terminate()` past it
- [x] ✅ Run test scripts — new `MobileBridgeAISuggestTests.swift` (3 tests: prompt template wraps
      commandBuffer+cwd, doesn't choke on an empty commandBuffer, cwd-guard fails fast on a
      missing directory *before* even touching `cachedClaudePath` — deliberately ordered so this
      guard is testable regardless of whether `claude` happens to be installed on the machine
      running the test). Full `swift test --filter MobileBridge` 38/38 (3 skipped, as before),
      `Tests/robot/run.sh` 23/23. **Not unit-tested** (would need a real or faked `claude` binary,
      out of scope for a fast test): successful subprocess output parsing, the timeout-kills-path.

### Client Application
- [x] Explicit trigger button ("AI" in the kbd-toolbar) — never auto-suggests while typing
- [x] Reuses G2's `.suggest-strip`/`renderCompletionStrip` for the result (same tap-to-insert)
- [x] Loading state: new `renderLoadingStrip()` — same visual slot, but a non-interactive `<span>`
      instead of buttons, so a stray tap during the multi-second wait can't send literal
      placeholder text ("Asking claude…") into the shell
- [x] `currentLineText()` reads the currently-rendered cursor row as the best available
      approximation of "what's typed so far" — xterm.js has no actual input-line-buffer concept
      (the shell's own readline/zle owns that); documented as a known noise source on custom
      prompt themes rather than assumed clean
- [x] ✅ Run test scripts — build clean, full suite green (38/38, 23/23 robot)
- [x] Live check: real Chrome + isolated `make mobile-web` daemon, real installed+authenticated
      `claude` CLI (fixed path resolution first — see deviation #2). Typed "find all python files
      here", tapped AI, "Asking claude…" showed immediately (non-interactive, confirmed a tap on
      it does nothing), ~8s later a real suggestion arrived: `find . -name "*.py"` — genuinely
      correct for the prompt. Tapped it → inserted correctly, strip cleared. **Same known
      concatenation caveat as G2** (inserts onto whatever was already typed, no separator —
      `find all python files here` + tap → `find all python files herefind . -name "*.py" `,
      needs manual cleanup): inherent to "insert as literal terminal input," not a bug.
      **Not tested**: the timeout-kills-subprocess path (would need artificially hanging `claude`,
      not attempted this session — flagging rather than assuming it works).

## Integration
- [x] End-to-end wiring — verified live: one continuous WS connection (no reconnect), same
      attached `Shell` session, exercised G2 (Tab → real completion strip) → G1 (`@` → picker →
      insert `.DS_Store` path) → G3 (AI button → real `claude` suggestion using that inserted path
      as context — genuinely suggested `rm ~/.DS_Store`, showing the AI picked up the actual
      terminal state) in sequence, no reconnect needed between any of them
- [x] ✅ Run all test scripts (verify GREEN) — `swift build`, `swift test` 38/38, `Tests/robot/run.sh` 23/23
- [x] Live check against a real daemon — satisfied by every phase's own live-check above (all
      three ran against real isolated `make mobile-web` daemons + real Chrome, not just
      build-green), plus the combined Integration check just above
- [x] Code review — Opus-model pass (background Agent, per this session's standing two-model
      workflow) against the full G1/G2/G3 diff, cross-referenced with `GitHubCLIClient`/
      `handleBrowserNavigate` as the claimed-consistency baselines. Found 3 real issues, none
      previously self-flagged, all fixed same-pass (Sonnet):
      1. **IMPORTANT — G3 newline auto-execute.** `runClaudeSuggest`'s success path only trimmed
         leading/trailing whitespace; an embedded newline in the CLI's reply would survive into
         `sendKeySeq`, and LF triggers `accept-line` in bash/zsh line editing same as CR — tapping
         a 2-line suggestion would silently auto-run the first line. Fixed: extracted a pure
         `MobileBridgeServer.firstLine(of:)`, take only the first line before returning `.success`.
         Regression-tested (`testFirstLineStripsEmbeddedNewlines_soAMultiLineReplyCannotAutoSubmitASecondCommand`
         and 3 sibling cases) since the failure mode is exactly the kind debug-mantra's own
         "write a regression test that fails without the fix" rule targets, even though this was
         caught by review rather than a live incident.
      2. **IMPORTANT — G3 pipes drained only after process exit.** `runClaudeSuggest` originally
         did `readDataToEndOfFile()` after `waitUntilExit()` — correctly mirrors
         `GitHubCLIClient.merge`'s pattern (verified accurate by the reviewer), but `gh pr merge`'s
         output is small/bounded and `claude -p`'s isn't; a reply larger than the OS pipe buffer
         would block the child on `write()` forever, surfacing as a false "claude CLI timed out"
         instead of the real answer. Fixed: `readabilityHandler`-based concurrent draining into a
         lock-protected `PipeBuffer` (a tiny `@unchecked Sendable` class — Swift 6 strict
         concurrency rejects a captured `var Data` mutated from `readabilityHandler`'s background
         queue even behind a manually-paired `NSLock`, same reasoning this file already applies to
         `ConnectionState`). Live re-verified after the refactor — real suggestion round-trip
         still works correctly.
      3. **MINOR — `aiSuggestPending` could get stuck / stale suggestion could render into the
         wrong session.** Only ever cleared by the WS response handler — a session switch mid
         -request left it stuck true, and a late response could pop into whichever session
         happened to be active when it landed. Fixed: reset `aiSuggestPending = false` and
         `clearCompletionStrip()` in both `mountTerminal` and `disposeTerminal`.
      Reviewer also explicitly verified (not findings, confirmed correct): the `controlQueue`
      per-connection reasoning from deviation #1, the `GitHubCLIClient` pattern match from
      deviation #2, `shellQuotePath`'s escaping, G1's `filesPickerMode` close-path invariant, G2's
      buffer-index bounds, Swift 6 Sendable conformance, and no shell-injection path (arguments
      passed via `process.arguments` array, never shell-interpolated). Full diff details in the
      review agent's report (not persisted as a separate file — summarized here per this
      project's existing convention of recording review outcomes inline in the task doc, same as
      Phase D3/E's own two-pass review entries above).
      Post-fix: `swift build` clean, `swift test --filter MobileBridge` 42/42 (3 skipped, as
      before — 4 new regression tests for finding #1), `Tests/robot/run.sh` 23/23, live re-verify
      of the AI suggestion round trip after the pipe-draining refactor.
