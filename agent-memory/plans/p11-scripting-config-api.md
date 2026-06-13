# P11 — Scripting & Config API (WezTerm parity)

Status: **planned / not started**
Priority: **P3** — strategic, implement after P12 unless a user explicitly asks for WezTerm-style config first
Owner surface: **HarnessApp first**, then daemon/CLI only where a script action already maps to IPC
Created from gap review: 2026-06-13 WezTerm/tmux/cmux comparison

---

## Goal

Give Harness a **scriptable config layer** comparable to WezTerm's Lua config/event model, without replacing the existing `settings.json`, `keybindings.json`, `options.json`, or tmux-compatible `source-file` path.

The user-facing result should be:

```js
// ~/.config/harness/init.js
harness.config.set("theme", "Tokyo Night")
harness.events.on("sessionCreated", event => {
  harness.toast(`session: ${event.session.name}`)
})
harness.keys.bind("prefix", "C-r", "source-config")
```

This is a scriptable layer over existing Harness primitives, not a second settings store.

## Non-Goals

- Do not adopt Lua. Use JavaScriptCore because it ships with macOS and avoids a SwiftPM dependency.
- Do not move `HarnessSettings` into scripts. JSON settings remain the persisted source of truth.
- Do not expose arbitrary daemon internals directly. Script mutations must flow through existing command/IPC paths.
- Do not implement a plugin/package manager in P11.
- Do not require scripts for normal users; first-run behavior stays unchanged when no script exists.

## Current State

- `HarnessSettings` persists static GUI config in `Packages/HarnessCore/Sources/HarnessCore/Settings/HarnessSettings.swift`.
- `KeybindingsStore` persists prefix/copy-mode key tables in `keybindings.json`.
- `OptionStore` persists scoped tmux-style options in `options.json`.
- `CommandParser` + `CommandIPCTranslator` already provide a single command vocabulary used by the prompt, keybindings, hooks, CLI, and sourced tmux configs.
- `SessionCoordinator.shared` already has app-side snapshot state and daemon IPC access.
- No embedded scripting runtime exists.

## Config Location Contract

Search order:

1. `$HARNESS_CONFIG_FILE` if set.
2. `$XDG_CONFIG_HOME/harness/init.js` if `XDG_CONFIG_HOME` exists.
3. `$HOME/.config/harness/init.js`.
4. `$HOME/.harness.js`.

Behavior:

- If no file exists, scripting is disabled silently.
- If a configured file exists but fails to parse/evaluate, show a non-blocking Harness notification/toast and keep the last good runtime active.
- Watch only the loaded file in PBI-SCRIPT-001. Module/import watch lists can come later.
- Reload should be explicit and automatic:
  - automatic: single-file watcher on save
  - manual: `harness-cli`/command-prompt action eventually maps to `reload-script-config`

## Architecture

```
HarnessApp launch
    │
    ▼
ScriptHookCoordinator
    ├── discovers config path
    ├── owns single-file watcher
    ├── owns ScriptRuntime lifecycle
    └── bridges app events into JS handlers
            │
            ▼
ScriptRuntime (JavaScriptCore)
    ├── harness.config
    ├── harness.keys
    ├── harness.commands
    ├── harness.sessions
    ├── harness.panes
    └── harness.events
```

Keep `ScriptRuntime` app-owned in the first implementation. A daemon-owned runtime would create a larger security and concurrency surface and is not needed for WezTerm-style startup/config/event parity.

## Public JS API v1

### `harness.config`

- `get(key) -> value | null`
- `set(key, value) -> void`
- `reloadTerminalImport() -> void`

Implementation notes:

- `set` maps only allowlisted `HarnessSettings` fields in v1: theme, font family/size, opacity/blur, padding, default shell/CWD, notification settings.
- Changes persist through `HarnessSettings.save()` and call the same refresh path used by Settings UI.
- Invalid keys throw JS errors; invalid values throw typed JS errors and do not partially save.

### `harness.keys`

- `bind(table, keySpec, commandSource, options?)`
- `unbind(table, keySpec)`
- `reload()`

Implementation notes:

- Parse `commandSource` with `CommandParser`.
- Persist through `KeybindingsStore`.
- `table` v1 allowlist: `prefix`, `copy-mode`, `copy-mode-vi`, `root`.

### `harness.commands`

- `run(commandSource) -> Promise<Result>`
- `parse(commandSource) -> ParsedCommand`

Implementation notes:

- Route through `CommandParser` and `CommandIPCTranslator`.
- App-local UI commands can run only on main actor.
- Commands that require focused pane/session use the current GUI focus context. Headless script execution is not part of P11.

### `harness.sessions` / `harness.panes`

Read-only first:

- `sessions.list() -> Session[]`
- `panes.list(sessionId?) -> Pane[]`
- `pane.readText({ lines }) -> string`

Mutating v1.1:

- `pane.sendText(text)`
- `pane.split({ direction, shell })`
- `pane.close()`
- `session.spawn({ cwd, shell, name })`

Implementation notes:

- Use snapshot data where possible.
- Mutations use the same IPC request/command translator path as GUI actions.
- `readText` should call daemon capture APIs, not scrape AppKit views.

### `harness.events`

- `on(name, handler)`
- `off(name, handler?)`

v1 events:

- `configReloaded`
- `snapshotChanged`
- `sessionCreated`
- `sessionClosed`
- `tabCreated`
- `tabClosed`
- `paneExited`
- `agentStateChanged`
- `notificationPosted`

Implementation notes:

- Event names should be stable JS names; bridge from existing NotificationBus / snapshot diffing.
- Handlers run serially on a script queue.
- Any UI mutation hops to `@MainActor`.
- Handler errors are caught, logged, and surfaced once per reload cycle to avoid toast spam.

## Implementation Plan

### PBI-SCRIPT-001: Runtime shell and config discovery

Files:

- New: `Apps/Harness/Sources/HarnessApp/Scripting/ScriptConfigLocator.swift`
- New: `Apps/Harness/Sources/HarnessApp/Scripting/ScriptRuntime.swift`
- New: `Apps/Harness/Sources/HarnessApp/Scripting/ScriptHookCoordinator.swift`

Tasks:

- Add JavaScriptCore import behind `#if canImport(JavaScriptCore)`.
- Build config search order and tests for path selection.
- Evaluate a minimal script with `harness.version`, `harness.log`, and `harness.toast`.
- Keep no-file startup silent.
- Surface parse/eval errors through display-message/notification path.

Tests:

- Unit test config path selection.
- Unit test missing file is no-op.
- Unit test syntax error does not crash and reports an error.

### PBI-SCRIPT-002: Reload lifecycle

Files:

- New: `Apps/Harness/Sources/HarnessApp/Scripting/ScriptFileWatcher.swift`
- Touch: app launch wiring where `SessionCoordinator`/settings services are initialized.

Tasks:

- Reuse the single-file DispatchSource pattern from RL-011.
- Re-arm watcher after atomic-save rename.
- Add manual `reload-script-config` command only after automatic reload works.
- Keep last good runtime until a replacement script evaluates successfully.

Tests:

- Unit test watcher re-arms on replacement where practical.
- App-level smoke: save `init.js`, verify reload toast/log appears.

### PBI-SCRIPT-003: Read-only API bridge

Files:

- New: `Apps/Harness/Sources/HarnessApp/Scripting/ScriptAPI.swift`
- New: `Apps/Harness/Sources/HarnessApp/Scripting/ScriptSnapshotModels.swift`

Tasks:

- Expose snapshot-derived workspace/session/tab/pane objects.
- Expose `harness.sessions.list()` and `harness.panes.list()`.
- Expose `harness.commands.parse()` for validation/debugging.

Tests:

- Snapshot fixture converts to JS-visible objects.
- JS cannot mutate Swift snapshot models directly.

### PBI-SCRIPT-004: Config/keybinding writes

Files:

- Touch: `HarnessSettings` only if a typed setter helper is needed.
- Touch: `KeybindingsStore` only if a narrower public API is needed.

Tasks:

- Implement allowlisted `harness.config.set`.
- Implement `harness.keys.bind/unbind`.
- Persist through existing stores.
- Trigger the same refresh paths used by Settings UI and `reload-keybindings`.

Tests:

- Invalid key/value fails without writing.
- Valid config write persists and reloads.
- Valid keybinding write parses command and persists.

### PBI-SCRIPT-005: Mutating command/session/pane API

Files:

- Touch: `ScriptAPI.swift`
- Touch: `SessionCoordinator` only for a narrow command execution facade if needed.

Tasks:

- Implement `harness.commands.run`.
- Implement pane/session mutators through command/IPC translation.
- Ensure no unstructured `Task { @MainActor in }` replaces existing FIFO-sensitive terminal output paths.

Tests:

- Command parse + translation unit coverage.
- Smoke: script can split a pane and send text in preview build.

## Security / Safety

- Trust model matches shell rc files: local user scripts run with app privileges.
- Do not execute scripts from project directories in v1.
- Do not support remote script loading.
- Avoid long-running JS on main thread. Runtime dispatch should be serial and bounded where possible.
- Add a setting/option to disable scripting if this becomes user-visible in Settings.

## Acceptance Criteria

- `swift build` passes.
- Harness starts unchanged with no config file.
- A valid `~/.config/harness/init.js` can set an allowlisted setting and bind a key.
- Editing `init.js` reloads without restarting the app.
- A bad script surfaces an error and leaves the last valid behavior intact.
- A script can observe at least one app event (`snapshotChanged`) and run a harmless command (`display-message`).

## Rollout Order

1. Runtime + discovery + no-op startup.
2. Reload lifecycle.
3. Read-only snapshot API.
4. Config/keybinding writes.
5. Mutating pane/session commands.

Do not start PBI-SCRIPT-005 until P12's MCP pane-control API is either implemented or deliberately deferred, because both features want the same narrow pane/session command facade.
