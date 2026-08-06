# kouen-terminal — Claude Instructions

## Session Start

- Continuation → read `agent-memory/CONTEXT.md` → invoke `macos-swiftui` skill
- Code navigation → `graphify-out/GRAPH_SUMMARY.md`
- Bug/pattern → `grep -rn "<keyword>" agent-memory/knowledge/cases/ agent-memory/MEMORY.md`

## Skills

AppKit/SwiftUI/macOS → `macos-swiftui` | debugging → `debug-mantra` | review → `review-personas`

## Build / Test / Run

| Command | What it does |
|---------|-------------|
| `make preview` | Isolated preview build (own bundle id, socket, state) — dev use |
| `make prod` | Release build, signs, opens `Kouen.app` at repo root |
| `make run` | Re-open existing `Kouen.app`, no rebuild |
| `make install` | Release build, copy to `/Applications/Kouen.app` |
| `swift build --product Kouen` | GUI app only |
| `swift test` | Full test suite |
| `swift test --filter <name>` | Filtered test |
| `Tests/robot/run.sh` | Run BEFORE every build — regression invariants |
| `EXPORT_THEMES=1 swift test --filter ThemeCatalogEmbedTests` | Regenerate `BundledThemesData.swift` after theme edits |

**Release entry point: always `make start`** — never bump version manually.

| Flow | Command |
|------|---------|
| Dev iteration | `make start` → `Preview build` |
| Release (with bump) | `make start` → `Full cycle` → patch / minor / major |
| Release (no bump) | `make start` → `Full cycle` → skip |

Full cycle: verify → bump → commit+push → prod → CHANGELOG → tag → GitHub release → install.

**Version sync rule** — these 4 files must always match. `prepare-release.sh` updates all 4 atomic — never edit one alone:
- `Apps/Kouen/Sources/KouenApp/Resources/Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion`)
- `Packages/KouenCore/Sources/KouenCore/KouenVersion.swift` (`short` + `build`)
- `Packages/KouenCore/Sources/KouenCore/ReleaseNotes/GeneratedReleaseNotes.swift` (via `make release-notes`)
- `CHANGELOG.md` (via `git-cliff --tag vX.Y.Z`)

**Git hooks**: `.githooks/commit-msg` blocks Info.plist in non-version commits. Activate after clone: `git config core.hooksPath .githooks`

## Non-obvious Constraints

- **Swift 6 strict concurrency**: `KouenCore` + `KouenTerminalEngine` use `-warnings-as-errors` — concurrency/deprecation warnings = build failures.
- **`@unchecked Sendable`**: `DaemonClient`, `DaemonServer`, `SurfaceRegistry`, `RealPty`, `DaemonLauncher`, `SurfaceIO`, `InputGate`, `SSHTunnelManager` — preserve lock/queue ownership.
- **Terminal output replay**: `TerminalHostView` uses `DispatchQueue.main.async` + `MainActor.assumeIsolated` to preserve FIFO byte order. `Task { @MainActor in }` can reorder bursty output.
- **IPC framing**: control = 4-byte big-endian length-prefixed JSON. PTY hot path = binary magic `0xF5` (output) / `0xF6` (input). New binary frame type needs version gate — old readers drop connection on unknown magic.
- **ACP shelved**: Agent sidebar + Chat toggle commented out. Code intact for re-enablement.
- **`IPCCodec.maxPayloadLength`**: 16 MiB.
- **Daemon socket**: owner-only `0600`, rejects peers with different uid.
- **`CharacterWidthTable.swift`**: generated + committed. Regenerate via `Scripts/generate-width-table.swift` if `CharacterWidth.swift` changes.
- **`themes.json`**: excluded from SwiftPM build. Regenerate `BundledThemesData.swift` with theme export test.
- **Release packaging order**: `dmg`/`sign`/`finalize` operate on existing `Kouen.app` — wrong order rebuilds away signature.
- **No worktree nested inside `.kouen-worktrees/`**: never `git worktree add` a path under an existing `.kouen-worktrees/<name>` checkout. Create new worktrees only from the main repo root (`~/Git/Personal/kouen-terminal/.kouen-worktrees/<new-name>`), never from inside another worktree.

## Graphify

```
mcp__graphify__query_graph   # focused question
mcp__graphify__shortest_path # dependency path A → B
mcp__graphify__get_node      # explain concept/symbol
```

```bash
graphify update . && ~/.claude/scripts/generate-graph-summary.sh .  # rebuild index (CLI)
```

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<ClassName/FileName>"` for a known symbol/file (name match, not free-form concept search - use `query` for that). These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- After judging a query/path/explain result useful, a dead end, or wrong, run `graphify save-result --question "Q" --answer "A" --outcome useful|dead_end|corrected --nodes N1 N2` - this accumulates across sessions so the same dead end or vocabulary mismatch isn't re-derived every time. At the start of a session, check `graphify-out/reflections/LESSONS.md` if it exists (built via `graphify reflect`) for preferred sources, known dead ends, and past corrections.
