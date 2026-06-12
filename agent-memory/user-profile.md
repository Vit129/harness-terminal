# User Profile

<!-- Stable preferences — update only when user explicitly changes them. -->
<!-- Loaded at session start alongside memory.md. -->

## Identity
- **Language:** Thai (interaction), English (docs/code/files)
- **IDE:** Kiro (Autopilot), Claude Code, Gemini CLI
- **Commits:** Conventional Commits

## Domain Expertise
- macOS/AppKit native development
- Swift 6 strict concurrency (actors, Sendable, MainActor isolation)
- Metal rendering pipeline
- Unix IPC (sockets, PTY, process management)
- Terminal emulator internals (VT parsing, grid model)

## Architecture Preferences
- Actor isolation over locks where possible
- Daemon-owned state for persistence
- Minimal external dependencies (one: Sparkle for auto-update)
- Cross-platform core (macOS GUI, Linux headless daemon+CLI)
- Binary tree models for recursive split structures

## Project Scope
- Single macOS app (Harness.app) with embedded daemon and CLI
- Target: developer terminal with IDE features (Zed-like sidebar, git, file editor)
- Agent integration via process-tree detection (passive) and ACP (active, shelved)

## Workflow Preferences
- **Build/run commands — use directly, don't ask:**
  1. "preview" / "show me the app" / "let me try it" → `make preview` (debug build, isolated
     `HarnessPreview.app` under `.harness-preview/`, separate daemon/socket from prod, launches it)
  2. "build" / "build it" / verify it compiles, no copy → `make build` (`swift build` only,
     no `.app` bundle, nothing touches `/Applications`)
  3. "run" / "open the app" with no source changes → `make run` (kills any stale instance,
     re-opens the existing repo-root `Harness.app` — errors if it hasn't been built yet)
  4. "run it" / default dev loop → `make debug` (build debug + package + sign + kill stale +
     open repo-root `Harness.app`); release-config equivalent without copying to
     `/Applications` is `make prod`
  5. "build and copy to Applications" / "install" → `make install` (release build + package +
     ad-hoc sign + stop old daemon + `ditto` into `/Applications/Harness.app` + clear
     quarantine/LaunchServices cache + open it); use `make install-no-build` if `Harness.app` is
     already packaged at repo root and just needs copying
  - "package" / "release" / "dmg" → `CLAUDE.md` release ordering (`make release` → `make sign`
    → `make dmg` → `make finalize`) — confirm first, harder to reverse
  - All of these are already documented in `CLAUDE.md`'s "Build/test/run commands" — check
    there before asking the user to choose between scripts that do the same thing.
