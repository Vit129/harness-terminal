# Claude Code Subprocess Harness — Design

## Context

Kouen currently drives `claude` (and other agent CLIs) only by spawning them into a
visible pty pane and screen-scraping output (`kouenSpawnAgent` →
`kouenGetLastBlock`/`waitForPaneOutput`). User wants Kouen to call the Claude Code
CLI programmatically ("เรียก Claude Code CLI ... ได้เองเลย"), scoped to Claude Code
only for this pass (Codex/Agy explicitly deferred). Naming convention should still
anticipate those two: tool stems are `cc` / `codex` / `agy`.

A prior ACP (Agent Client Protocol) JSON-RPC integration was built and shelved
(`agent-memory/knowledge/patterns/acp-client.md`) for 3 reasons: needed a separate
npm adapter binary, PATH resolution failed for GUI/daemon-launched processes, no
tool-level sandboxing. Verified below that `claude`'s own CLI flags solve 2 of 3
natively; the PATH issue has a concrete fix.

## Verified facts (this session, `claude` v2.1.226)

- `com.apple.security.app-sandbox = false` in `Kouen.entitlements` — the ACP PATH
  failure was a **launchd-minimal-PATH** problem, not App Sandbox. Fix: resolve the
  `claude` binary once via a login-shell probe, not the daemon's inherited PATH.
- `claude` is a zsh **function** in interactive shells (injects `-n <dirname>`), not
  directly executable — `zsh -l -c 'whence -p claude'` resolves the real binary:
  confirmed at `/Users/supavit.cho/.local/bin/claude`. Must probe with `whence -p`
  (zsh) / `type -P` (bash), not naive `which`/`command -v` under a non-login shell.
- `-p/--print` + `--output-format stream-json` gives real JSON-lines events.
  Captured a live run; confirmed field names: `{"type":"assistant","message":{...}}`
  for turns, and a final `{"type":"result","is_error":bool,"total_cost_usd":number,
  "result":"<final text>","session_id":"..."}` line. Matches the design below.
- `--permission-mode acceptEdits|auto|bypassPermissions|manual|dontAsk|plan`,
  `--allowedTools`/`--disallowedTools` are first-class flags — no adapter needed,
  directly solves ACP blocker "no tool control."
- `--bare` (minimal mode, skips CLAUDE.md/hooks/keychain) **breaks this user's
  auth** — confirmed empirically: `--bare` run returned `"Not logged in · Please
  run /login"` because it forces `ANTHROPIC_API_KEY`/`apiKeyHelper` and never reads
  OAuth/keychain. **Do not use `--bare`.** A non-`--bare` trivial run cost $0.26 in
  notional pricing purely from cache-creation of the user's full global CLAUDE.md +
  session-start hooks — real overhead, but not a `--bare` situation for this user.
  Mitigate with `--setting-sources` scoping instead (see below), not `--bare`.
- User is on **Claude Code subscription billing**, not pay-per-token — a
  `--max-budget-usd` dollar rail doesn't map to real cost/risk for them. **Not used.**
- `--session-id <uuid>` lets Kouen set the session id up front, so `runId ==
  session id` with no separate mapping table; `--resume <id>` continues it later.

## Decisions (user-confirmed)

| Decision | Choice |
|---|---|
| Default permission profile | **`edit`** — `acceptEdits` + Edit/Write + git-readonly Bash allowlist, `rm`/`sudo`/`git push` denied |
| Cost rail | **None** (`--max-budget-usd` skipped — subscription billing, not per-token) |
| Tool naming | **`kouenCCRun`** / **`kouenCCStatus`** now; `kouenCodexRun`/`kouenAgyRun` reserved, same shape, later |

## Architecture

**One new actor, in the daemon** (same reasoning as why pty sessions live there:
must survive window close / SSH detach, and the daemon already owns process
lifecycle + persistent stores):

`Packages/KouenDaemon/Sources/KouenDaemon/ClaudeCodeHarness.swift`

```swift
actor ClaudeCodeHarness {
    struct Run: Sendable {
        let id: UUID                  // == claude --session-id
        var state: RunState
        var lastAssistantText: String?
        var resultText: String?
        var totalCostUSD: Double?
        var exitCode: Int32?
        let cwd: String
        let startedAt: Date
        let transcriptURL: URL        // raw JSONL, one line per stdout line
    }
    enum RunState: String, Sendable { case running, succeeded, failed, cancelled }

    func start(prompt: String, cwd: String, profile: Profile, model: String?) async -> RunSummary
    func get(id: UUID) -> RunSummary?
    func list() -> [RunSummary]
    func cancel(id: UUID) -> Bool

    private func resolveClaudeBinary() async -> String   // cached after first probe
    private func parseLine(_ line: String, into run: inout Run)
}
```

No `@unchecked Sendable` needed (unlike `RealPty`'s fd-level lock partitioning) —
`Process` + a `Pipe` readability handler hopping back into the actor is enough at
this throughput; nothing here touches a raw fd on a hot path.

In-memory run table only; no persistence store. A daemon restart loses the live
run table (transcript file survives on disk; `--resume` can continue the Claude
session id if needed). No run-history UI — the harness is MCP-tool-only in v1.

### PATH / binary resolution

```swift
private func resolveClaudeBinary() async -> String {
    if let cached = cachedPath { return cached }
    if let override = KouenSettings.load().claudeBinaryPath { cachedPath = override; return override }
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    let probeCmd = shell.hasSuffix("zsh") ? "whence -p claude" : "type -P claude"
    // run `$SHELL -l -c "<probeCmd>"`, capture stdout, trim
    // fall back to scanning `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin` for `claude`
}
```

Probe once per daemon lifetime, cache the result.

### Cost/context overhead control — SOLVED, verified

Default invocation loads full user+project CLAUDE.md and fires session-start
hooks — real, measured overhead ($0.26-$0.39/call, ~42-47k cache-creation tokens
of global instructions). `--bare` is ruled out (breaks OAuth — confirmed earlier).

**Fix: `--setting-sources ""` (empty).** Confirmed empirically (`claude -p "say
hi" --setting-sources "" --output-format json`, no `--bare`): cache-creation
dropped from ~42-47k tokens to **6,940** (an 83%+ cut) and OAuth/subscription auth
still worked fine (`"Hi! ..."`, no login error) — this is the CLI-flag surface of
the Claude Agent SDK's documented `settingSources` option (`code.claude.com/docs/
en/agent-sdk/claude-code-features` — "provide an empty array to disable user,
project, and local settings entirely," which the SDK docs confirm covers both
CLAUDE.md loading and hooks). Unlike `--bare`, it does not touch auth resolution
at all — it only skips filesystem settings discovery.

**This is very likely also how Zed's `claude-code-acp` adapter avoids the same
overhead**: Zed's integration spawns the user's own already-authenticated `claude`
CLI as "its own independent process" (per Zed's own blog/docs) rather than using
Anthropic's separate Agent Agent SDK auth path — Anthropic's Agent SDK policy
explicitly bars third parties from offering subscription/OAuth login without
approval, so a personal/unapproved integration riding on subscription auth has to
go through the CLI's own OAuth session, same as this design, then isolate
settings via this same flag (or the SDK's `settingSources: []` if built with the
SDK instead of raw CLI spawning) rather than `--bare`.

**Harness default: pass `--setting-sources ""` on every `kouenCCRun` call.** If a
future use case needs the project's own CLAUDE.md/skills (not the global
`~/.claude` ones), `--setting-sources project` is the middle ground — not needed
for v1.

## Mode decision rule (pty vs harness)

> **"Will a human watch or steer this run while it happens?"**
> - Yes → pty pane (`kouenSpawnAgent`), unchanged, stays the daily-driver default.
> - No, and the machine-readable result matters → this harness (`-p` + `stream-json`).
> - `--bg` + `claude agents --json`: **not used**. The daemon already *is* the
>   persistent supervisor `--bg` exists to substitute for; using it too would
>   create a second source of truth for run state. Revisit only if daemon-restart
>   survival of in-flight runs becomes a real pain point.

Bidirectional `--input-format stream-json` (multi-turn steering) is **deferred** —
v1 is one-shot prompt-in/result-out; a follow-up turn is a new call with
`--resume <runId>`. Interactive steering is what the pty pane is for.

## IPC / wiring

- `Packages/KouenIPC/Sources/KouenIPC/IPCMessage.swift` — additive JSON request
  cases (`ccRunStart`, `ccRunGet`, `ccRunList`, `ccRunCancel`) + response case +
  a small `Codable` `ClaudeRunSummary` struct. Additive over the existing 4-byte
  length-prefixed control framing — no binary-frame version gate needed (that only
  applies to new `0xF5`/`0xF6`-style magic frames).
- `Packages/KouenDaemon/Sources/KouenDaemon/DaemonServer.swift` — dispatch these 4
  cases directly to `ClaudeCodeHarness`, off the `SurfaceRegistry` lock (mirrors
  existing async-out-of-registry handling like `handleWaitFor`).
  **`SurfaceRegistry` itself is untouched.**
- `Tools/kouen-mcp/Sources/KouenMCP/KouenDaemonTools.swift` — new methods
  `kouenCCRun(prompt:cwd:profile:model:)` and `kouenCCStatus(action:runId:)`,
  same shape as the existing `kouenSpawnAgent`/`taskCreate` methods (~L319, ~L529).
- `Tools/kouen-mcp/Sources/KouenMCP/ToolRegistry.swift` — register the two new
  tool schemas next to `kouenSpawnAgent`'s entry (~L910).
- `kouenSpawnAgent` and `AgentRoutingRule`/`AgentRoutingResolver`: **untouched**.
  Different contract (returns a pane, not a result); routing rules answer "which
  CLI for this cwd" for pty spawns, irrelevant to a Claude-only harness.

## Permission profiles

| Profile | Flags |
|---|---|
| `readonly` | `--permission-mode dontAsk --allowedTools Read Glob Grep Task WebFetch` |
| `edit` (**default**) | `--permission-mode acceptEdits --allowedTools Read Glob Grep Task Edit Write "Bash(git status:*)" "Bash(git diff:*)" "Bash(git log:*)" --disallowedTools "Bash(rm:*)" "Bash(sudo:*)" "Bash(git push:*)"` |

Never `bypassPermissions` in v1. Never attach `kouen-mcp` via `--mcp-config` by
default (would hand the child pane-control/`runCommand` tools — reopens the
tool-control hole this design exists to close).

**Verified (2026-08-09, no `--bare`).** `--permission-mode acceptEdits
--allowedTools Read Glob Grep Edit Write "Bash(git status:*)" --disallowedTools
"Bash(rm:*)" "Bash(sudo:*)" "Bash(git push:*)"` against a live prompt:
- Unlisted arbitrary `Bash` (`echo ... > file`) → denied (`permission_denials`
  logged the exact tool_input).
- `Write` to the target file → ultimately succeeded, file created with correct
  content.
- Explicit `rm <file>` in a follow-up run → denied
  (`result: "Denied. Not run."`), file survived.
The `edit` profile's core security property (Edit/Write allowed, `rm`/`sudo`/
`git push` blocked, unlisted Bash blocked) holds as designed. Not yet tested:
whether the `Bash(git status:*)` *positive* allow-pattern itself matches as
expected (only the deny-patterns and the full-block case were exercised).

## Model selection

- Default: leave `--model` unset — inherits the user's own Claude Code config,
  tracks model-family changes (Fable 5/Opus 5/Sonnet 5) with zero Kouen code.
- `model` is an optional pass-through string on `kouenCCRun`; prefer aliases
  (`sonnet`/`opus`/`fable`/`haiku`) over pinned full names so it survives future
  model bumps automatically.
- Not added to `AgentRoutingRule` — that answers "which CLI," not "which model";
  no consumer for a model column yet.
- `--fallback-model`: not used in v1 (no unattended-automation consumer yet).

## Explicitly NOT built (YAGNI)

1. Bidirectional stream-json sessions / mid-run steering (pty pane's job).
2. `--bg` + `claude agents --json` polling (daemon already persists; dual
   source-of-truth risk).
3. Generic `AgentHarness` protocol / multi-CLI abstraction — build it when Codex
   or Agy actually gets implemented, not speculatively now.
4. Reviving the shelved ACP code — this design supersedes its motivation.
5. Run-persistence store / history UI — in-memory table + on-disk JSONL is
   enough; Task Board already covers "what's happening" visibility.
6. `--json-schema`, `--include-hook-events`, `--include-partial-messages`,
   `--forward-subagent-text` — real flags, no v1 consumer.
7. Automation migration (`fireAutomationLocked`'s 3-second-sleep prompt-typing in
   `SurfaceRegistry.swift:2155` could later route through this harness instead) —
   natural v1.1 follow-up, deliberately not pulled into this pass.

## Verification plan — status

- [x] Unit test: stream-line parser against real captured field shapes —
  `Tests/KouenDaemonTests/ClaudeCodeHarnessTests.swift`, 6 tests, all green
  (assistant line, successful result, failed result, malformed line, cancel
  unknown run, empty list).
- [x] `swift build` green for `KouenDaemon`, `kouen-mcp`, `Kouen` (GUI), `kouen-cli`.
- [ ] Lifecycle test with a stub executable standing in for `claude` (like
  `RealPtyLifecycleTests`) — not done, real-CLI manual testing covered the
  permission/enforcement behavior instead (see design sections above).
- [ ] Manual: `kouenCCRun` via kouen-mcp end-to-end against a real repo — not yet
  run through the actual MCP server process (unit-level and direct-CLI checks
  only so far).

## Minor note

The interactive `claude` zsh function auto-injects `-n "$(basename $PWD)"` (session
display name). The harness spawns the raw binary directly, so runs won't carry a
display name in `/resume`/terminal-title unless the harness passes `-n <repo
basename>` itself — trivial one-arg addition if wanted, not required for v1.
