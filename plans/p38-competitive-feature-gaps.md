# P38 — Competitive Feature Gaps (cmux / Supacode / Superset / WezTerm / Zed)

> Source: competitive analysis session 2026-07-11 comparing Kouen against cmux, Supacode,
> Superset (all three: Ghostty-based "run N agents in parallel" command-center terminals),
> WezTerm, and Zed's Agent Panel / Terminal Threads. Full comparison table not persisted
> elsewhere — this plan is the durable artifact of that analysis. Ranked by leverage: how much
> of the gap is already closed by existing infra (worktree isolation, block capture, MCP tools)
> vs net-new build.

## Where Kouen already leads (don't rebuild these)
- Daemon-owned sessions surviving restart + remote/headless daemon over SSH (Linux) — no
  competitor in this set does this.
- `kouen-mcp` browser control (open/snapshot/interact/screenshot/network/cookies/storage) —
  deeper than Superset's 2026 in-app-browser addition, which has no MCP tool surface this rich.
- Built-in editor + LSP across 21 languages — none of cmux/Supacode/Superset have this; Zed has
  it but Zed isn't terminal/multiplexer-first.
- Per-tab git worktree auto-isolation already exists (`WorktreeAutoIsolateService` +
  `WorktreeManager`, keyed off branch change) — the *substrate* cmux/Supacode/Superset build
  their whole pitch on. We have the substrate; we're missing the UI on top (Phase A).
- Command-boundary block capture already exists (P34: `TerminalBlock`, `BlockSummary`,
  `kouenGetLastBlock`/`kouenGetBlock`) — this is most of what Zed's "Terminal Threads" needs;
  we're missing the thread-level UX wrapper (Phase C).

## Current architecture relevant to these gaps
```
WorktreeAutoIsolateService (Apps/Kouen/.../Services)
 └─ observes KouenActiveTabGitBranchDidChange → WorktreeManager.create/list
     → tab.worktreePath set, one worktree per non-default branch per workspace

AgentDetector → AgentKind (KouenIPC/AgentSnapshot.swift: codex/claudeCode/cursor/grok/pi/
hermes/openClaw/openCode/aider/gemini/goose/antigravity/kiro/generic)
 └─ process-tree inspection + CLI hook hints → per-pane agent identity, statusline

TerminalEmulator → TerminalBlock (engine-side, line-range only)
 └─ BlockSummary (KouenIPC, pre-joined text) → kouenGetLastBlock / kouenGetBlock MCP tools
```

## Phases

### Phase A — Cross-agent diff/review dashboard (biggest gap vs Superset/Supacode) — ✅ DONE 2026-07-13, see p38-phase-a-diff-dashboard/{design.md,dev-task-progress.md}
Superset and Supacode's core pitch is: agent runs in isolated worktree → single dashboard
shows every agent's diff → review/merge/handoff without leaving the app. We have the worktree
isolation; we have no aggregate view.
- **A1 inventory**: enumerate all tabs in a workspace with `worktreePath != nil`, resolve each
  to `git diff` against its base branch (reuse whatever git-diff plumbing the existing sidebar
  Git panel already calls — do not re-implement diff parsing).
- **A2 UI**: new sidebar section or command-palette action ("Review Agent Work") listing one
  row per isolated tab: branch name, agent kind (from `AgentKind`, if a pane in that worktree
  has one), files changed count, last commit time. Click → existing diff popover/viewer.
- **A3 handoff action**: per-row action to merge the worktree branch into the tab's original
  branch (shell out to `git merge`/`git rebase`, surface conflicts inline — do not auto-resolve).
- Explicitly out of scope for v1: cross-agent conflict prediction, auto-merge, N-way diff UI.

### Phase B — Subagent/teammate visibility as panes (vs cmux) — ✅ CLOSED 2026-07-16 (build/test/robot green, live check skipped per user decision)
cmux auto-splits a new pane whenever a running agent spawns a subagent/teammate, so nested
agent work is never a hidden background process.
- **B1 investigate detection surface**: does `AgentDetector`'s process-tree walk already see
  child agent processes (e.g. Claude Code's Task tool spawning a nested `claude` process)? If
  yes, this is a wiring problem, not a detection problem — confirm before scoping further.
- **B2 auto-split on detection**: when a new agent-kind process is detected as a child of an
  existing agent-kind process in the same pane's process tree, prompt (or auto, behind a
  setting) split the pane and attach a view onto the child's own output stream — needs a way to
  address a subprocess's I/O independently of the parent PTY, which may not exist yet (RealPty
  is one PTY per pane, not per-process). Flag as the likely hard part; may require design
  discussion before implementation.

### Phase C — Agent "thread" UX on top of existing block capture (vs Zed Terminal Threads) — ⚠️ pivoted 2026-07-15, ✅ CLOSED 2026-07-16 (build/test/robot green, cross-pane jump-to-block live check skipped per user decision), see p38-phase-c-thread-overlay/{design.md,dev-task-progress.md}
Zed's Terminal Threads treats each agent CLI session as a searchable thread with turn-level
structure. We already capture command blocks (P34); missing piece is presenting them as a
navigable thread rather than raw scrollback.

**Built as a standalone `TerminalThreadOverlay` (⇧⌘L) first, gated green, then deleted during live
testing** — double-click/filter never worked, and the user asked to merge it with Recipes instead
of debugging it separately. Current implementation: merged into `RecipePickerController` (⌘⇧R
only, single flat list of recipes + history). Still missing: a unit test for the merge logic, and
a live check that selecting a history item actually jumps to its output.
- **C1** reuse `TerminalBlock`/`BlockSummary` to render a per-pane "thread view" (block list,
  jump-to-block) as an alternate view mode on the existing pane, not a new surface.
- **C2** cmd-F search should search block boundaries/commands first, fall back to raw scrollback
  search (existing ⌘F) for content within a block.
- Verify this doesn't regress the F1-F4 P34 deliverables (see completed-archive.md P34 entry)
  before touching `TerminalBlock`.

### Phase D — Terminal image protocol (Kitty Graphics) — vs WezTerm — ✅ D1 DONE 2026-07-14 (finding: NOT deferred), D3 conformance slice built, ✅ CLOSED 2026-07-16 (build/test/robot green, real-client live check skipped per user decision)
**Correction (2026-07-14, Fable-consulted D1 investigation):** this phase's own premise was
stale. Kitty Graphics (APC `\x1b_G`), Sixel (DCS), and iTerm2 OSC 1337 image protocols were NOT
deferred from P30 — they shipped 2026-05-30 (`0fc22101`/`1a07a4aa`): full multi-chunk Kitty
transmit+display (f=24/32/100), a Sixel decoder, iTerm2 inline images, placement model with
scroll/reflow/eviction handling, Metal texture-upload render pass (`ImageTextureCache`,
`TerminalMetalRenderer.drawImages`), and 14 engine tests. `INDEX.md`'s P30 entry and this
section's own "deferred" framing were simply out of date — no code was ever missing at the
transmit+display level.
- **D1** ~~confirm still deferred~~ — DONE, finding: not deferred, see above.
- **D2** ~~if truly greenfield, scope as its own plan~~ — moot, not greenfield.
- **D3 conformance slice (built)**: the real gap was narrower — `handleKittyGraphics` dropped
  `a=q` (query), `a=t`+`a=p` (transmit-then-place-by-id), and `a=d` (delete). Added all three
  (see `agent-memory/plans/p38-phase-d-kitty-conformance/`), PNG/RGB/RGBA + direct base64 only,
  matching the existing v1 format support. Deferred further (documented, not silently dropped):
  animation, Unicode placeholders/tmux passthrough, `t=f`/`t=s`/`t=t` mediums, `o=z` compression,
  cropping/offsets/placement-ids beyond simple id-based place.

### Phase E — Scripting hook parity (JS vs WezTerm's Lua) — low priority — ✅ DONE 2026-07-14, ✅ CLOSED 2026-07-16 (low-priority live check skipped per user decision)
- **E1** audit which WezTerm-style lifecycle hooks (window-resized, new-tab, pane-focus-changed)
  the JavaScriptCore layer already exposes vs not, before deciding this is worth doing. Don't
  build blind — likely small delta, possibly already covered.
- **Finding**: capability parity already existed (21 daemon `HookRegistry` lifecycle hooks + JS
  can run any command those hooks can) — the plan's own suspicion was correct, no hook-parity
  build needed. One real defect found and fixed: `paneCreated`/`paneRemoved` were documented in
  `ScriptAPI.swift`'s `kouen.plugin.on` comment but never dispatched. See
  `agent-memory/plans/p38-phase-e-scripting-hooks/`.

## Verification gates (every phase)
- `swift build` + `swift test` green, `Tests/robot/run.sh` green (26/26 as of Phase E, grew from
  the 10 baseline as each phase added structural guards)
- Phase A/B: live check with a real multi-worktree workspace (not just unit tests) — spawn 2+
  tabs on different branches, confirm dashboard reflects real `git diff` output
- Phase C: confirm scrollback search and P34 block MCP tools still pass their existing tests
- Phase D/B: design-review checkpoint before implementation (both flagged as architecturally
  uncertain above) — don't start coding until the hard part (subprocess I/O addressing for B,
  escape-sequence handling for D) has an actual design
