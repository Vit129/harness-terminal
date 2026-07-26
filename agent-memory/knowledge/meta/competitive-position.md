# Competitive Position (as of v4.9.0, 2026-07-26)

> Merged from the 2026-07-02 baseline (then named "Harness") + the P39 refresh
> (2026-07-11, added Zed/Superset/tmux, re-verified every claim against current
> source) + the 2026-07-26 monthly refresh (see new section near the bottom —
> 3 parallel web-research passes covering Warp/Supacode/cmux, iTerm2/Ghostty/
> WezTerm, Zed/Superset/tmux, last ~30 days only). See
> `agent-memory/plans/p39-competitive-feature-gaps.md` for the per-gap evidence
> trail and phase-by-phase implementation notes from the earlier pass.
>
> **Policy (2026-07-26, user decision — see "Not gaps" section below):** Kouen
> only builds features with real usage justification, not competitor-checkbox
> parity. New gaps found in this refresh are logged for user review, not
> auto-scoped into a plan.

## Kouen Wins

| vs | Advantage |
|----|-----------|
| Supacode | Daemon persistence, remote/headless, CLI scripting depth, browser pane, multiplexer, macOS 15 support (Supacode needs 26), custom engine (no libghostty), MCP server |
| Warp | Daemon/remote, open source, no account required, multiplexer, agent-aware worktrees, MCP server, agent selector (multi-AI), browser pane |
| iTerm2 | Agent detection, worktree isolation, GitHub PR inline, MCP server, browser pane, agent selector |
| Ghostty | Built-in multiplexer, agent hooks, browser pane, IDE navigation, PR/CI inline, MCP server |
| WezTerm | Agent-aware tabs, worktree isolation, daemon persistence, remote, browser pane, MCP, no Lua required |
| cmux | GitHub PR/CI, IDE navigation, worktree management, experience modes, MCP server, agent selector, compact CMUX-style browser (matched), notification rings (matched) |
| tmux | Full scripting/copy-mode/status-line/hooks/format-string parity (`docs/TMUX_PARITY.md`) plus daemon persistence tmux itself doesn't have across full app quit |
| Zed | CLI-agents-in-panes + MCP context pull (`kouenErrors`/`kouenGetBlock`/`kouenGrep`/`kouenFind`) instead of Zed's UI @-mention Agent Panel — deliberate positioning, not a gap |
| Superset | In-app browser + 27 MCP tools (matched), native Swift vs Electron |

## Kouen Gaps

### Closed 2026-07-11 (P39 phases A–D — build/test green, live-hardware check still owed on each)

| Gap | Who had it | Fix |
|-----|-----------|-----|
| Sidebar dev-server port badge | cmux | `ListeningPortScanner` + sidebar badge |
| SSH agent forwarding on remote hosts | WezTerm | `SettingsRemoteView` toggle on `-A` passthrough |
| PR merge strategy (squash/rebase/merge) in-app | Supacode | `GitHubCLIClient.merge()` + sidebar context menu |
| In-app git hunk staging | Superset | `GitPanelView` hunk popover, `git apply --cached` |
| Fleet dashboard (10+ agents at a glance) | Superset | Footer badge count + inbox header "N running · M need you" |

### Still open (not actionable / not a feature decision)

| Gap | Who has it |
|-----|-----------|
| Large community (1M+ users) | Warp, iTerm2, Ghostty — growth metric, not a feature to build |
| ~~Block-based terminal (command grouping)~~ | **STALE — already shipped, P34, 2026-07-02.** Command-boundary capture (OSC 133 `C`/`D`, zsh/fish native preexec), Copy Output/Command Only, right-click block context menu, `kouenGetLastBlock`/`kouenGetBlock` MCP tools. Only block-bookmarking was deferred, by explicit user choice, not a gap. Feature Matrix row below corrected to ✓. |

## Not gaps — deliberate positioning differences (no action)

- **Cross-platform GUI (Win/Linux)** — Warp/WezTerm/Ghostty have it. Rejected 2026-07-26: macOS-only is a strategic choice, not an oversight; not revisited.
- **Team sharing / cloud sync** — Warp Teams has it. Rejected 2026-07-26 (usable-feature-only policy below) — no account/cloud dependency is a stated USP, not a gap to close.
- **Extensions/plugins ecosystem** — iTerm2 (python API), WezTerm (Lua), tpm-style plugin manager (resurrect/continuum/thumbs). Rejected 2026-07-26 (usable-feature-only policy below).
- **GPU shader customization** — Ghostty has it (user-authored GLSL). Already evaluated and scoped out in P40 (`design.md:188` — no user-authored shader code / no arbitrary MSL compilation at runtime, closes a real security surface) and reconfirmed rejected 2026-07-26.
- **Zed's built-in chat/Agent Panel UI** — Kouen removed inline AI chat deliberately (`c4e1e15`, 2026-06-29). Re-adding contradicts the CLI-agents-in-terminal-panes + MCP philosophy.

**Usable-feature-only policy (2026-07-26, user decision):** the remaining open competitive gaps as of 2026-07-26 (cross-platform GUI, team sharing/cloud sync, plugin ecosystem, GPU shader customization) are explicitly closed, not deferred — user's own words: "เน้น feature ที่ใช้งานเท่านั้น ไม่เอา gimmick" (focus only on features people actually use, no gimmicks). Don't re-surface these as gaps to fix in future competitive sweeps; a genuinely new, usage-driven feature request is a different thing from chasing a competitor's checkbox.
- **Superset/cmux Electron vs native** — Kouen's native Swift engine is a stated USP.

## Known Limitations (honest assessment)

| Feature | Status | Issue |
|---------|--------|-------|
| MCP server | Works | RL-048: round-trip timeout fixed — 35s timeout matching daemon's 30s internal timeout |
| Inline AI chat (⌘I) | Removed | `c4e1e15` erased ACP + inline AI chat entirely. Agent interaction is CLI-only |
| Agent selector | Works | Persists to settings, switches CLI binary |
| Browser pane | Works | Navigate, tabs, console capture |
| Browser agent API | Works | snapshot/evaluateJS/network/cookies/storage wired via IPC/MCP (P28) |

## Unique Selling Points (no competitor has all)

1. **MCP server built-in** — `kouen-mcp` exposes 27 tools; Claude Code/Codex/Kiro can read panes, control sessions, interact with browser pane
2. **Agent selector** — switch between Claude/Codex/Gemini/Kiro mid-session, persisted to settings
3. **Browser pane with agent API** — navigate, snapshot DOM, read console logs, evaluate JS — no other terminal has this
4. Daemon + Remote + CLI + GUI in one app (tmux-killer)
5. 4 experience modes (plain → persistent → full → agent workspace)
6. macOS 15+ (Supacode requires macOS 26)
7. Custom Swift terminal engine (no libghostty/Electron dependency)
8. Auto-isolate worktrees per branch per agent

## Feature Matrix (2026-07-11)

| Feature | Kouen | Warp | iTerm2 | Ghostty | Supacode | cmux | Zed | Superset | tmux |
|---------|:-----:|:----:|:------:|:-------:|:--------:|:----:|:---:|:--------:|:----:|
| MCP server (agent→terminal) | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | partial | ✓ | ✗ |
| Agent selector (multi-AI) | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Browser pane + agent API | ✓ | ✗ | ✗ | ✗ | ✗ | partial | ✗ | ✓ | ✗ |
| Daemon persistence | ✓ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ | ✓ |
| Remote (SSH tunnel + agent forwarding) | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | partial |
| Built-in multiplexer | ✓ | ✗ | ✓ | ✗ | ✓ | ✗ | ✗ | ✗ | ✓ |
| Worktree auto-isolate | ✓ | ✗ | ✗ | ✗ | ✓ | partial | ✗ | ✓ | ✗ |
| In-app git hunk staging | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| PR merge strategy picker | ✓ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ |
| Sidebar dev-server port badge | ✓ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ |
| Fleet/multi-agent dashboard | partial | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✓ | ✗ |
| No account required | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ |
| Open source | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ | ✓ | ✗ | ✓ |
| Cross-platform GUI | ✗ | ✓ | ✗ | partial | ✗ | ✗ | ✓ | ✗ | ✓ (terminal-native) |
| Block-based terminal | ✓ (P34, shipped 2026-07-02) | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |

## Positioning Statement

> "Kouen is the only terminal with a built-in MCP server + multi-agent selector + browser
> DevTools API — all in one open-source app. Claude Code, Codex, Gemini, and Kiro can
> directly observe and control your terminal sessions, panes, and browser via `kouen-mcp`.
> No account required, runs on macOS 15+, works headless in CI, and combines agent-ready
> MCP tooling + tmux-style persistence + IDE navigation."

## Deep web research refresh (2026-07-11, 3 parallel research passes)

Prior sections above were largely internal-code-verified or lightly researched. This
pass did live web research (official docs/changelogs/GitHub issues, not just marketing
copy) across terminals, AI-agent-terminals, and AI-IDEs. Corrections and new findings:

**Corrections to earlier claims:**
- **G3 (Supacode PR merge strategy) — original "who has it" attribution unverified.**
  Deep research found no confirmed per-hunk staging or squash/rebase/merge picker in
  Supacode's own docs/site. The G3 gap may have been sourced from a stale/inaccurate
  read of Supacode's marketing copy. Kouen's C2 implementation stands regardless (it's
  a real feature we built), but don't cite Supacode as the competitor that forced it.
- **USP #1 ("MCP server built-in" as unique) is no longer fully accurate.** Two
  competitors now expose their own internal state via MCP the same direction as
  `kouen-mcp` (external agent → app), not just consume external MCP servers:
  - **JetBrains IDE MCP Server** (built into IntelliJ/PyCharm/WebStorm/etc. since
    2025.2) — external MCP clients can pull diagnostics, run tests, execute terminal
    commands, modify files. Direct structural analog to `kouen-mcp`.
    [jetbrains.com/help/idea/mcp-server.html]
  - **Superset's own MCP server** (`api.superset.sh/api/v2/agent/mcp`) — exposes
    Tasks/Workspaces/Agents/Terminals/Automations/Projects/Hosts, OAuth2.1 or
    API-key auth. [docs.superset.sh/mcp] — already reflected correctly in the
    Feature Matrix's Superset MCP cell (✓), just wasn't reflected in the USP list.
  Kouen's actual remaining differentiator: combining MCP-server-outward *with* a
  terminal-panes-as-primary-surface + tmux-style daemon multiplexer + browser-pane
  DevTools API, in one native macOS app, no account. No single competitor combines
  all four; several now match one or two.

**New competitive pressure not previously tracked:**
- **Warp** has invested heavily in agent-hosting (auto-detects/hosts Claude Code,
  Codex, Gemini CLI, OpenCode, Antigravity; Oz cloud agents; subagent swarms as of
  2026.05.14) — broader agent-hosting breadth than Kouen's selector. But confirmed
  **MCP-client-only** (no MCP server of its own), confirmed **no cross-quit daemon
  persistence** (open issue #9416), **no hunk staging** (open issue #8542), **no
  embedded browser pane** (open issues #10627/#9194/#8548) — the things Kouen already
  ships are still open feature requests in Warp's own tracker.
- **Zed** created and open-sourced **ACP** (Agent Client Protocol, Jan 2026,
  co-launched with JetBrains) — lets Claude Code/Gemini CLI/Codex run **side by side
  inside Zed** as first-class guest agents. This is a real competitor to Kouen's
  "agent selector" concept, and Zed is cross-platform (macOS/Linux/Windows) where
  Kouen is macOS-only. Zed does not expose an outward MCP server itself (ACP is
  host-serves-guest-agent, not generic external MCP).
- **JetBrains Air** (free public preview, March 2026, macOS-only) — standalone
  dashboard running Codex/Claude/Gemini/Junie simultaneously on separate tasks with
  real-time per-agent status. Closest 2026 product concept to Kouen's multi-agent
  selector, delivered as a separate app rather than integrated into one terminal.
- **cmux** momentum is high (~18.8k GitHub stars, 48+ releases, v0.64.17 as of
  2026-06-23): daemon-backed session persistence (`~/Library/Application
  Support/cmux/`), scriptable browser pane (DOM snapshot/click/fill/JS-eval,
  imports cookies from 20+ browsers) closely paralleling Kouen's browser-pane API,
  and beta remote-tmux-mirroring-over-SSH. Exposes a Unix-socket + CLI control
  surface, not MCP. No confirmed hunk staging or merge-strategy picker.
- **Category is crowding fast**: new entrants found this pass — **AgentsRoom**
  (agentsroom.dev, visual multi-agent dashboard + mobile companion apps),
  **Parallel Code** (parallelcode.app, git-worktree-per-agent, Electron), **OpenAI's
  own Codex desktop app** (launched 2026-02-02), **GitHub's own Copilot app**
  (announced Build 2026, multi-agent desktop workspace). Platform vendors (OpenAI,
  GitHub) are now shipping first-party competitors to the independent terminal
  wrappers, not just startups. Not yet feature-compared — watch list only.

## AI-IDE landscape (adjacent category — editors, not terminals)

Not directly competing on "terminal" but increasingly overlap on agent-orchestration
and MCP-exposure. Kouen-relevant deltas only (full per-product detail was gathered
but isn't repeated here — re-run the research pass if a fresh full writeup is needed):

| Product | Multi-agent (Kouen selector analog) | Exposes own state via MCP outward | Terminal/daemon model | Platform |
|---|---|---|---|---|
| Zed | ✓ via ACP (Claude/Gemini/Codex side by side) | ✗ (ACP is host-serves-guest, not generic MCP) | Built-in terminal, partial session persistence (agent-thread persistence buggy per open issues) | macOS/Linux/Windows |
| Cursor | Cloud Agents, up to 8 concurrent (task-parallel, not vendor-switching) | ✗ (MCP client only) | Terminal in cloud VM, reported persistence bugs | macOS/Win/Linux (VS Code fork) |
| Windsurf → **rebranded Devin Desktop, 2026-06-02** | Worktree-grouped multi-agent + ACP adoption | Partial (ACP only, not general MCP) | Built-in terminal + separate "Devin for Terminal" CLI | Not confirmed cross-OS in this pass |
| VS Code + Copilot | Companion App for parallel agent sessions (Apr 2026 preview) | Stated but unconfirmed scope ("MCP server bridging to external agents", Apr 2026 release notes) | Standard integrated terminal | macOS/Win/Linux |
| JetBrains (IDE + Air) | ✓ **JetBrains Air** (Codex/Claude/Gemini/Junie simultaneous, Mar 2026 preview) | ✓ **confirmed** — IDE MCP Server since 2025.2 | Standard IDE terminal, no daemon | IDEs cross-platform; Air is macOS-only preview |

Net: JetBrains is the only adjacent-category product that matches Kouen on *both*
multi-agent orchestration and MCP-server-outward — but as two separate products (IDE
+ Air), not unified with a terminal-daemon/multiplexer the way Kouen is.

## Sources (2026-07-11 research)
- cmux: https://github.com/manaflow-ai/cmux , https://github.com/manaflow-ai/cmux/releases
- Supacode: https://supacode.sh/ , https://github.com/supabitapp/supacode
- Superset: https://superset.sh/ , https://github.com/superset-sh/superset , https://docs.superset.sh/mcp
- WezTerm: https://wezterm.org/config/lua/config/mux_enable_ssh_agent.html , https://wezterm.org/multiplexing.html
- Zed: https://zed.dev/docs/ai/agent-panel , https://zed.dev/acp , https://zed.dev/docs/ai/external-agents
- Warp: https://docs.warp.dev/knowledge-and-collaboration/mcp , https://docs.warp.dev/changelog/2026 , github.com/warpdotdev/warp issues #9416/#8542/#10627
- iTerm2: https://iterm2.com/documentation-ai-chat.html , https://iterm2.com/documentation-restoration.html
- Ghostty: https://ghostty.org/docs/features/ssh , github.com/ghostty-org/ghostty discussions #3358/#12571/#12290
- Kitty: https://sw.kovidgoyal.net/kitty/kittens/ssh , https://sw.kovidgoyal.net/kitty/changelog
- Rio: https://github.com/raphamorim/rio
- JetBrains: https://www.jetbrains.com/help/idea/mcp-server.html , https://blog.jetbrains.com/junie/2026/03/junie-cli-the-llm-agnostic-coding-agent-is-now-in-beta/
- Cursor: https://cursor.com/docs/mcp , https://www.buildfastwithai.com/blogs/cursor-cloud-agents-development-environments-2026
- Windsurf/Devin Desktop: https://devin.ai/blog/windsurf-is-now-devin-desktop , https://docs.devin.ai/desktop/changelog
- VS Code/Copilot: https://github.blog/news-insights/product-news/github-copilot-agent-mode-activated/ , https://code.visualstudio.com/docs/agent-customization/mcp-servers
- Watch list: https://agentsroom.dev/ , https://www.producthunt.com/products/parallel-code

## First-party vendor apps + ACP decision (2026-07-11, follow-up research pass)

**Claude Code Desktop** (code.claude.com/docs/en/desktop) — biggest first-party threat.
Rebuilt Apr 2026 around parallel sessions + per-session git worktree isolation. Has an
in-app Browser pane (external sites too, clean profile, permission-gated — announced
Jul 10, 2026) and a Remote/cloud execution mode that survives closing the laptop
entirely, checkable from claude.ai/code or iOS. **MCP: client only** in the desktop
GUI — the CLI can `claude mcp serve` its own native tools, but the desktop app itself
doesn't expose session/pane state outward the way `kouen-mcp` does. No tmux-style
multiplexer, no SSH-agent-forwarding toggle, no PR-merge-strategy picker (has
auto-fix/auto-merge toggle instead, opaque method choice). macOS/Windows/Linux(beta).
No account-free tier — bundled into Claude subscription only.
**Correction (user hands-on observation, not doc-sourced):** the Browser/Terminal
panes are **reactive tool invocations**, not standing infrastructure — they only spin
up when the agent decides to open one or the user types a command that triggers it.
Kouen's daemon keeps terminal panes as the persistent primary surface from app
launch; the browser pane attaches to an already-running daemon-backed process rather
than cold-starting on first use. This is a real architectural difference the doc
research above didn't surface (docs describe *what* the panes do, not *when* they
exist) — worth keeping in the positioning statement as "always-on" vs "on-demand."

**OpenAI Codex** — merged into the unified ChatGPT desktop app Jul 9, 2026 (Chat/Work/
Codex tabs, one binary). Codex mode: worktree-isolated parallel agents, in-app browser
(same on-demand/reactive caveat as Claude Code Desktop above, per user observation),
SSH devbox support, Codex Remote (GA Jun 25, 2026). **MCP: client AND server** — Codex
CLI can itself be invoked as an MCP tool by other clients, a more explicit bidirectional
story than Claude's. No terminal-panes-as-primary-surface, no multiplexer, no git hunk
staging (output model is diff/PR-only, never direct edits). Subscription-bundled only.

**ChatGPT app (Chat/Work modes)** — no longer a separate "app for code"; Work mode
(new Jul 9, 2026, GPT-5.6) does general knowledge-work automation with a browser +
Computer Use, not terminal/git-focused. Not a meaningful separate comparison point
from Codex mode above.

Net: none of the three exposes MCP outward from their primary desktop surface the way
Kouen does (Codex CLI is the closest, via its own MCP-server mode) — but Claude Code
Desktop's Remote execution (survives full machine shutdown, not just app quit) is a
genuinely stronger persistence story than Kouen's daemon in one respect: it doesn't
need *your* Mac running at all. Worth tracking, not yet a gap to close (different
architecture — cloud-hosted vs local-daemon — not a feature toggle).

**Superset/cmux control-surface gap-mine — what's genuinely new for Kouen:**
Skeptical dive into Superset's full MCP tool list (Tasks/Workspaces/Agents/Terminals/
Automations/Projects/Hosts) found most categories already have a Kouen equivalent
under a different name (Agents≈`kouenSpawnAgent`+`kouenList`, Terminals — Kouen is
actually *ahead*, Superset has no output-read tool at all vs Kouen's
`readPaneOutput`/`kouenGetBlock`/`kouenGrep`/etc.). Three real gaps:
1. **Tasks** — persistent MCP-addressable task object (CRUD, status/priority/assignee),
   independent of any running pane. `kouenBoard` is read-only, derived from live pane
   classification — not the same thing.
2. **Automations** — RRULE-scheduled recurring agent runs (pause/resume/run-now/logs).
   No cron/scheduler concept exists anywhere in Kouen today. Real gap.
3. **Hosts via MCP** — `RemoteHostStore` already exists internally (backs Settings →
   Remote), just never exposed as an MCP tool. Smaller lift than it looks — expose,
   don't build.
cmux has no Automations/Hosts-registry either (ad-hoc SSH only) — this isn't an
industry-standard pattern, just a Superset-specific idea worth stealing selectively.
Not scoped into a plan yet — flag for a future P-number if Automations/Tasks get
prioritized.

**ACP re-evaluation — still not worth building.** New data since the earlier "not
worth it" call: Anthropic explicitly closed the `claude-code` ACP request as **"not
planned"** (issue #6686) — confirmed fact now, not a guess. OpenAI pushes MCP-server
mode instead, no official ACP. For both of Kouen's two most-used agents (Claude Code,
Codex), ACP only works via a community/Zed-maintained adapter subprocess — not the
`claude`/`codex` binaries Kouen already runs — trading a working OSC/regex detection
layer for a *different* subprocess dependency, against a protocol still shipping v2
RFDs for core permission UX (not post-1.0). Terminal-category precedent is a single
6-week-old experimental Microsoft Windows Terminal fork, not an established pattern.
Gemini CLI is the one agent with clean native `--acp` support — cheap if Kouen ever
wants ACP for Gemini specifically, but not a reason to build the whole host layer.
**Re-check trigger**: revisit if either Anthropic or OpenAI reverses and ships native
ACP for their main CLI.

## P40 gap-closure update (2026-07-11, same day, synthesis against research above — no
new web pass run, competitor doc pages don't move within hours)

Of the 4 real Superset/cmux control-surface gaps identified above ("Superset/cmux
control-surface gap-mine"), P40 closed 3:

| Gap | Status | Note |
|---|---|---|
| Tasks | **Closed** — `kouenTaskList/Get/Create/Update/Delete` | Different model than Superset's (session-scoped, not global) — a deliberate choice, not a copy. Superset's Tasks are independent of any session; Kouen's belong to exactly one. |
| Worktree (was "Workspaces") via MCP | **Closed** — `kouenWorktreeList/Create/Remove` | Wraps existing `WorktreeManager`, no new domain logic. |
| Hosts via MCP | **Closed** — `kouenHostList` (read-only) | Exposes existing `RemoteHostStore`, no new storage. |
| Automations | **Closed (P41, 2026-07-11)** — `kouenAutomationList/Get/Create/Update/Delete/Pause/Resume/RunNow` | Simpler model than Superset's: fixed `intervalMinutes` (no RRULE), `lastRunAt`/`lastRunStatus` instead of a full log store. Connection to `agent-memory/plans` is a `prompt`-text convention, not a Kouen-side plan-parsing feature — see LANGUAGE.md. |

Net effect: Kouen's MCP surface grew from 27 to 44 tools this session (Tasks ×5,
Worktree ×3, Hosts ×1, Automations ×8 in the P41 follow-up). This directly narrows the
one dimension where Superset was ahead (breadth of MCP-addressable resources) without
adopting Superset's global-object data model — Kouen's session-scoping stays
consistent with its existing worktree-per-session/agent-per-pane philosophy rather
than bolting on a foreign concept.

**Shader presets — reverted, not a competitive dimension.** Explored as part of this
plan (Ghostty's GPU shader customization gap from the original 5-item list), but the
underlying capability turned out to already exist pre-session with zero UI exposure.
User judged exposing it not worth the surface area ("gimmick") after seeing it live —
reverted the Settings picker. Not a loss against any competitor: none of the terminals
compared in this doc (Warp/iTerm2/WezTerm/cmux/Supacode/Superset) have shipped this
either — Ghostty remains the only one with real GPU shader customization. Kouen's
non-decision here is a legitimate "we could, we chose not to" position, same class as
the ACP non-adoption above — not a gap to revisit unless user reconsiders.

**Where Kouen stands now, one line**: on the MCP-completeness axis specifically
(the dimension Superset led on), Kouen is at parity or ahead for every resource type,
including Projects — closed 2026-07-17 as `kouenProjectsList`. Superset's Projects are
explicitly registered (clone URL / local path); Kouen has no such registry, so this
instead dedupes the repo roots of every currently-open tab — a deliberate scope choice,
not a copy, same pattern as Tasks/Automations above. Everything else from the original
5-item competitive list is closed, deferred by choice, or was never a real gap to
begin with.

## 2026-07-26 monthly refresh (last ~30 days only, 3 parallel research agents)

Scope: only changes dated roughly 2026-06-26 → 2026-07-26, across all 9 previously
tracked competitors (Warp, Supacode, cmux, iTerm2, Ghostty, WezTerm, Zed, Superset,
tmux). Older news already covered above was not re-collected.

**Already-matched / no action** (competitor shipped something Kouen already has,
confirms design direction rather than opening a gap):
- Superset's new "workspace activity strip + dock badge for attention-needed
  workspaces" (2026-07-06) converges on the same idea as Kouen's footer badge +
  inbox "N running · M need you" — independent validation of that design, not a gap.
- Zed's Git panel gaining staged/unstaged hunk grouping + Git Graph (2026-07-15/23)
  is Zed catching up to Kouen's existing in-app hunk staging — narrows Zed's deficit,
  doesn't open one for Kouen.
- tmux 3.7's new **floating panes** (2026-06-26) — verified against Kouen's own
  code: Kouen already shipped floating panes in P30 "Otty Feature Parity"
  (`⌘⌥F`, `NSPanel`-based, v3.11.x, see `feature-provenance.md`) well before this
  tmux release. Already-matched, not new.
- Warp's git branch status chip (ahead/behind count) — cosmetic, already covered by
  Kouen's PR-status + hunk-staging depth.

**Platform/mobile-companion signal (cross-ref existing work, not a new track)**:
cmux shipped an iOS companion reaching feature parity (files gallery, voice
dictation, multi-Mac host switcher) and iTerm2's beta (3.7.0beta6/7) added
"iTerm2 Buddy" (iPhone companion: live session video, e2e-encrypted push
notifications). Both validate the *category* Kouen is already pursuing as
**P37 — Mobile Connect v1** (QR+Tailscale, in-app QR, real client — F2/F3/F4 done
per `INDEX.md`), not a brand-new gap. Worth a glance at P37's remaining scope
(F5/F6) against these two feature sets before calling P37 "done," but this is
in-flight work, not a new item.

**Genuine new gaps found this pass (not yet in any plan, unscoped, flagged for
user review — not auto-built per the no-gimmick policy above)**:

| # | Gap | Source | Why it's not a gimmick (real workflow value) |
|---|-----|--------|-----------------------------------------------|
| M1 | **Warp Cloud Agent Runners** — hosted/cloud execution tier for agents, GA'd to all users 2026-07-23 | docs.warp.dev/changelog/2026 | Different architecture (cloud vs local-daemon) — same class as Claude Code Desktop's Remote mode already noted above as "worth tracking, not yet a gap to close" |
| M2 | **Warp custom model routers** — per-request rules routing agent calls to different LLMs, UI editor added 2026-07-03 | same | Real cost/quality control lever for heavy agent users, not cosmetic |
| M3 | **cmux Browser Design Mode** — visually edit/annotate pages inside the browser pane, 2026-07-19 | cmux.com/docs/changelog | Kouen's browser pane has an agent API but no human-facing visual edit mode — plausible real workflow gap for a human doing quick UI tweaks alongside an agent |
| M4 | **cmux Fork Conversation** — branch a running agent session into a new split/tab/workspace, 2026-07-14/19 | same | Directly useful for "try two approaches from the same point" — a real multi-agent workflow pattern, not decoration |
| M5 | **cmux saved workspace layouts** — named, reusable split-arrangement templates, 2026-07-14 | same | Distinct from Kouen's daemon *restore* (state snapshot) — this is a *reusable template* you apply to a fresh workspace; real repeat-workflow value |
| M6 | **iTerm2 (beta) per-action AI safety-checking** — every agent command/keystroke individually judged against the original request, risky ones held for one-tap approval, 3.7.0beta7, 2026-07-15 | iterm2.com/appcasts/testing_changes3.txt | Safety/trust feature, not a gimmick — relevant given Kouen's agents already run arbitrary shell commands unsupervised |
| M7 | **iTerm2 (beta) Claude Code "workgroup" review automation** — auto-request peer-session code review on idle, auto-paste results back, 3.7.0beta7, 2026-07-15 | same | Real automation of an already-common manual habit (ask a second agent to review) |
| M8 | **Supacode PR worktree status inspector + PR policy waiver on maintainer approval**, v0.10.6, 2026-07-12 | github.com/supabitapp/supacode/releases | Smaller than M1-M7, but a real gap next to Kouen's existing merge-strategy picker (adds an approval-waiver step Kouen's picker doesn't have) |
| M9 | **Superset rich terminal-input composer** (multi-line, @file mentions, slash commands) for CLI agents, 2026-07-12 | superset.sh/changelog/2026-07-12-... | Minor, nice-to-have prompt-composition UX, not core — lowest priority of this list |

**Note on M-numbering**: these are refresh-pass findings, not yet triaged into gap
vs. rejected — unlike the G-numbered items from the 2026-07-11 pass (all resolved
into Closed/Rejected above), none of M1-M9 has a user decision yet. Don't silently
promote these into a plan; surface the list and let the user pick what (if anything)
is worth scoping.

**Nothing new found**: Ghostty (still 1.3.1, Mar 2026 — commits since are Xcode 27
SDK/packaging only, no user-facing feature), WezTerm (no tagged release since Feb
2024; in-window commits are Wayland-blur/bugfixes only), Zed (no fleet-dashboard or
browser-pane changes beyond the git-panel catch-up noted above).

### Sources (2026-07-26 refresh)
- Warp: https://docs.warp.dev/changelog/2026/
- Supacode: https://github.com/supabitapp/supacode/releases
- cmux: https://cmux.com/docs/changelog
- iTerm2: https://iterm2.com/appcasts/full_changes.txt , https://iterm2.com/appcasts/testing_changes3.txt
- Ghostty: https://ghostty.org/docs/install/release-notes , https://github.com/ghostty-org/ghostty/commits/main
- WezTerm: https://wezterm.org/changelog.html , github.com/wezterm/wezterm issues #7615/#7444/#7154
- Zed: https://zed.dev/releases/stable
- Superset: https://superset.sh/changelog/2026-07-06-custom-agents-workspace-activity-fable , https://superset.sh/changelog/2026-07-12-rich-input-ghostty-mistral
- tmux: https://raw.githubusercontent.com/tmux/tmux/master/CHANGES , https://github.com/tmux/tmux/releases
