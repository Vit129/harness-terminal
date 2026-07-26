# P37 Phase G — Autocomplete (mobile bridge)

> Follows Phase F2 (keyboard toolbar, commit `9c4706f3`). Interview completed 2026-07-13
> via `Skill(interview)` → `doc.md` mode; every open question below was resolved with the
> user picking the recommended option. No LANGUAGE.md update needed — this is UI/interaction
> design on an existing bounded context, not a new domain concept.

## Strategic Design

**Bounded context: unchanged.** This extends the same "Mobile Bridge Client Ergonomics" surface
D1-D3/E/F2 already live in — `MobileBridgeServer.swift`'s in-process daemon module (`community=60`
per graphify) plus its embedded client (`embeddedPageHTML`). No new context, no new process, no
new service boundary. Same reasoning Phase D's own doc entry already used: "everything below runs
inside the daemon... no new bounded context, no new process."

**Architecture pattern: monolith, confirmed not reconsidered.** Single daemon process, single Swift
package (`KouenDaemonCore`), one file owns the whole mobile WS protocol. G1-G3 add: 0 new WS
message types (G1), 0 new WS message types (G2, pure client-side), 1 new WS message type (G3).
No case for splitting anything out — the three phases differ wildly in *implementation risk*, not
in *architectural shape*.

**Reused subprocess pattern for G3**, found via blast-radius check before designing:
`Packages/KouenCore/Sources/KouenCore/GitHub/GitHubCLIClient.swift` already wraps a CLI tool
(`gh`) from Swift — cached-path resolution (`/opt/homebrew/bin/...` → `which` fallback) + `Process`
+ `Pipe` for stdout/stderr + `waitUntilExit()`. G3's `claude` CLI wrapper should mirror this shape,
not invent a new one. **Critical difference from `gh pr merge`**: `GitHubCLIClient.merge()` calls
`waitUntilExit()` synchronously, acceptable for a rare, fast, explicitly-triggered git action. A
`claude -p` round trip is neither fast (multi-second LLM latency) nor rare enough to risk running
on any queue shared with PTY relay — R3 in the existing risk register (`p37-mobile-connect-v1.md`)
already flags "one slow/flooding peer stalls the whole daemon event loop" as a live risk on the
`.main`-queue-heavy parts of this server. **Design constraint: the G3 subprocess call must run off
whatever queue handles other connections' PTY frames** — dedicated `DispatchQueue` + async
completion back to the WS connection, never a blocking `waitUntilExit()` inline in the WS message
handler.

## Tactical Design

No new persistent entities — this feature has no storage, no aggregate roots. It's three request/
response interaction shapes layered onto the existing WS connection (which is itself the only
long-lived "entity" already modeled by `ConnectionState` — untouched by this design).

**G1 — file-path insertion.** One-shot interaction: client asks for a directory listing (existing
`listDirectory` request, D1), user picks a leaf entry, client emits the path as literal terminal
input. No new server-side state. No new domain concept — it's D1's existing read-only file
listing, retargeted from "preview this file" to "insert this path."

**G2 — completion-strip render.** Purely a client-side *interpretation* of already-arriving PTY
output bytes (`term.buffer.active`, xterm.js's own rendered grid) after a Tab byte was sent — the
daemon does nothing new, sees nothing new, stores nothing new. This is presentation logic
reading state that already exists (the terminal screen buffer), not a new domain event.

**G3 — suggestion event.** The one genuinely new server-side interaction: client sends a
`aiSuggest` request (command-buffer text + cwd), daemon spawns `claude -p` async, daemon
pushes an `aiSuggestion` response back over the same WS connection when the subprocess
completes (or an error, on failure/timeout). This is a request/response pair, not a persistent
event — nothing is stored past the single round trip.

## Logical Design

### G1 — @ file-path picker

**Trigger.** New `@` button appended to the existing `.kbd-toolbar` row (`embeddedPageHTML`,
shipped in `9c4706f3` — Esc/Tab/^C/^D/arrows already there). Deliberately **not** auto-triggered
by typing `@` in the terminal — `@` is a real shell character (`git clone user@host`, npm
`@scope/pkg`, email addresses); auto-intercepting it would corrupt normal typing. This mirrors the
interview's explicit rejection of Claude Code's chat-box `@`-mention pattern for this exact reason
— a raw PTY is not a chat input.

**Wire protocol.** No new WS message types. Reuses D1's existing pair verbatim:
- `{"listDirectory":{"path":"..."}}` → `DirectoryListResponse` (`MobileBridgeServer.swift:1556`)
  drives picker navigation.
- No `readFile` call needed for G1 (unlike D1's preview flow) — G1 only needs the *path*, not
  file contents.

**Client UI.** A lightweight inline picker (not D1's full-screen files sheet) — same visual
language (`.sheet`/`.sheet-backdrop` classes already defined in `embeddedPageHTML`'s CSS, reused
rather than styled fresh), opened from the toolbar, closed on selection or backdrop tap.

**Insertion mechanism.** Selected path is shell-quoted (matching the quoting convention D2's
attach flow already established — desktop-side `shellQuote`, referenced but not reusable directly
since this runs client-side in JS; the mobile client re-derives the equivalent minimal quoting: wrap
in single quotes, escape embedded `'` as `'\''`) and sent via `sendKeySeq` (F2's existing helper,
`MobileBridgeServer.swift` embedded JS) — literal text into the PTY at the current cursor position,
exactly like a keyboard toolbar tap. No new client-to-server send path.

**Errors.** `listDirectory` failure (permission denied, path gone) surfaces inline in the picker,
same pattern D1's files sheet already uses — do not invent a new error-display convention.

### G2 — shell tab-completion suggestion strip (heuristic, explicitly best-effort)

**No new WS message type.** Tab still sends the real `\t` byte exactly as F2 shipped it — this
path is untouched. G2 adds a **read-only observer** on the client: after a Tab send, inspect
`term.buffer.active` (xterm.js's rendered grid, already present in the client — no new dependency)
for a heuristic completion-menu signature.

**Detection heuristic (the actual design decision):**
1. Snapshot the cursor row before sending Tab.
2. After Tab is sent, wait one short debounce window (~150ms — long enough for a local PTY echo
   round trip, short enough to feel instant) for new terminal output.
3. If new rows appeared below the pre-Tab cursor row, and those rows look like a token list (short
   whitespace-separated tokens, no shell prompt string in them, distinct from a full command's
   normal stdout) → treat as a completion menu, extract the tokens, render as a tappable strip
   above the kbd-toolbar.
4. **Any ambiguity → do nothing.** No completion strip shown. This is the hard requirement from
   the interview: never show wrong/garbage suggestions. A missed detection is an acceptable
   failure mode; a wrong one is not.

**Explicitly documented fragility** (per interview decision — ship without a shell-plugin
requirement, accept the tradeoff): the exact rendering of a completion menu differs across zsh
`menu-select`, bash `readline`, fish, and further differs by the user's own prompt theme/plugins.
This heuristic is tuned against zsh (the project's default per `CLAUDE.md`/`Info.plist` shell
detection elsewhere) and is expected to under-fire (miss real completions) on other shells rather
than over-fire (show garbage) — asymmetric by design per the hard requirement above.

**Tap-to-insert.** Same `sendKeySeq` mechanism as G1 — tapping a suggested token sends it as
literal text (with a trailing space, matching normal shell completion behavior).

### G3 — AI command suggestion (via `claude` CLI subprocess)

**Trigger.** Explicit button only (kbd-toolbar or an adjacent affordance) — never auto-suggest
while typing. Two independent reasons from the interview, both real: latency (subprocess spawn +
CLI round trip is multi-second, not keystroke-speed) and cost (a CLI call per keystroke burns the
user's own Claude usage for no benefit).

**New WS message type** (the one new wire-protocol addition in this whole phase):
```
→ {"aiSuggest":{"commandBuffer":"...", "cwd":"..."}}
← {"aiSuggestion":{"suggestion":"..."}}      // success
← {"error":"..."}                            // existing ErrorAck shape, reused
```
`commandBuffer` is whatever text is currently typed but not yet submitted at the shell prompt
(client already has this — it's sitting in xterm.js's input line, same text G1/G2 insert into).
`cwd` comes from the already-tracked attached surface's working directory (available via the
existing session metadata the sidebar list already renders — not a new lookup).

**Daemon-side execution — the one real architectural addition.** New method (name suggestion:
`runClaudeSuggest(commandBuffer:cwd:) async -> Result<String, Error>`), modeled on
`GitHubCLIClient`'s cached-path-resolution + `Process`/`Pipe` shape, but:
- Path resolution: same `/opt/homebrew/bin/claude` → `/usr/local/bin/claude` → `which claude`
  fallback chain `GitHubCLIClient.cachedGhPath` already establishes for `gh`.
- Invocation: `claude -p "<constructed prompt>"` — NOT a bare pass-through of `commandBuffer`;
  wrap it in a short fixed prompt template (e.g. "Suggest a single shell command for: {input}.
  Context: cwd={cwd}. Reply with ONLY the command, no explanation.") so the CLI's own
  free-form chat behavior doesn't leak into what should be a single suggested command.
- **Must run off the connection-handling queue** — dispatch to a dedicated background queue
  (or Swift concurrency `Task` with its own priority), `await` the result, then push the
  `aiSuggestion`/`error` response back onto the originating WS connection. Never call
  `waitUntilExit()` synchronously inside `handleControlMessage` — see Strategic Design's R3 note.
- Timeout: bound the subprocess (e.g. 20s) and kill it + return an error past that, rather than
  let a hung `claude` process pin a connection's suggestion slot forever.

**Privacy flag (explicitly not mitigated in this pass, per interview scope).** `commandBuffer`
(and by extension anything the user has half-typed, which could include a pasted secret, a
partially-typed credential, etc.) is sent to a local subprocess the user already has authenticated
— not a new network egress the user hasn't already implicitly trusted by having `claude` CLI
installed and logged in. This is a materially smaller privacy surface than a direct API call
with a Kouen-managed key would be (recommendation the interview explicitly rejected in favor of
this), but it is not zero risk — flagging here rather than silently treating it as resolved.

**Client UI.** Suggestion renders as a strip above the kbd-toolbar (same visual slot pattern G2's
completion strip uses — reuse the component, don't build two near-identical strip UIs). Tap to
insert via `sendKeySeq`, same as G1/G2.

## Build order (unchanged from interview decision)

**G1 → G2 → G3**, each independently shippable, ranked easiest-to-hardest exactly as D1→D2→D3 and
F2 were sequenced. G1 has zero new server-side surface (pure client + existing D1 endpoints). G2
has zero new wire protocol (pure client heuristic). G3 is the only phase with new IPC/queueing
design risk — sequenced last deliberately so G1/G2 ship value before G3's larger risk is taken on.

Verification gates: same as every other phase in this project — `swift build` + `swift test`
green, `Tests/robot/run.sh` green, and a **live check against a real daemon** (build-green alone
is not done, per `MEMORY.md` 2026-07-07 lesson already governing every other phase in this file).
