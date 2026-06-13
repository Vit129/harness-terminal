# P12 — Agent Orchestration via MCP (cmux parity)

Status: **planned / not started**
Priority: **P2** — implement before P11 mutating pane APIs
Owner surface: **harness-mcp + existing daemon IPC**
Created from gap review: 2026-06-13 WezTerm/tmux/cmux comparison

---

## Goal

Extend `harness-mcp` so an external agent running in a normal shell can control Harness panes and sessions over MCP:

- list workspaces/sessions/tabs/panes
- spawn a session or pane
- send text/keys to a pane
- read pane output/scrollback
- wait for output/idle/exit signals

This gives Harness the practical cmux-style control plane without re-opening the shelved ACP client path.

## Non-Goals

- Do not re-enable the GUI ACP sidebar.
- Do not embed agent binaries inside Harness.app.
- Do not let MCP bypass daemon socket ownership checks.
- Do not add a second terminal/session model inside `harness-mcp`.
- Do not expose write/control tools without an allowlist or explicit opt-in.

## Current State

- `Tools/harness-mcp/Sources/HarnessMCP/ToolRegistry.swift` exposes only file/git/shell tools: `readFile`, `writeFile`, `listDirectory`, `runCommand`, `gitStatus`, `gitDiff`, `gitLog`.
- `HarnessMCP` depends on `HarnessCore`, so it can already link `DaemonClient`, `DaemonClientActor`, IPC types, and command parser/translator types.
- Existing IPC already includes most required primitives:
  - `getSnapshot`
  - `newSession`
  - `newSplit`
  - `send`, `sendData`, `sendKeys`
  - `capturePane`, `capturePaneRange`
  - `subscribeSurfaceOutput`
  - `replayScrollbackSequenced`
  - `resizeSurface`, `closeSurface`, pane/window/session close operations
- Daemon socket is owner-only and peer-credential checked, so MCP should use the normal `Endpoint.localControlSocket`.

## Relationship To ACP

ACP was shelved because Harness-as-ACP-client needs adapter binaries inside the app bundle, has PATH issues, and provides weak tool-control semantics. P12 is the inverse:

```
Agent shell process
    │ MCP stdio
    ▼
harness-mcp
    │ existing owner-only Unix socket IPC
    ▼
HarnessDaemon
```

The agent owns its own runtime and PATH. Harness exposes a controlled tool surface.

## Tool Contract v1

Use camelCase tool names to match the existing `harness-mcp` style.

### Read-only tools

#### `harnessList`

Input:

```json
{
  "includePanes": true,
  "includeAgents": true
}
```

Output:

```json
{
  "workspaces": [
    {
      "id": "...",
      "name": "main",
      "sessions": [
        {
          "id": "...",
          "name": "repo",
          "tabs": [
            {
              "id": "...",
              "title": "zsh",
              "panes": [
                {
                  "paneId": "...",
                  "surfaceId": "...",
                  "title": "zsh",
                  "cwd": "/path",
                  "active": true,
                  "agent": null
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

Implementation:

- Call `.getSnapshot`.
- Flatten only fields agents need.
- Include both `paneId` and `surfaceId`; daemon send/capture APIs use `surfaceID`, layout APIs use pane UUIDs.

#### `readPaneOutput`

Input:

```json
{
  "surfaceId": "...",
  "lines": 200,
  "includeScrollback": true,
  "escapeSequences": false,
  "joinWrapped": true
}
```

Implementation:

- Use `.capturePaneRange` for line-limited reads.
- Use `.capturePane` for whole visible/scrollback fallback only when `lines` is omitted.
- Default max lines: 200.
- Hard cap v1 max lines: 2000 to avoid huge MCP payloads.

#### `waitForPaneOutput`

Input:

```json
{
  "surfaceId": "...",
  "pattern": "Done",
  "timeoutMs": 30000,
  "fromNow": true
}
```

Implementation:

- Subscribe with `subscribeSurfaceOutput`.
- If `fromNow` is false, replay first with `replayScrollbackSequenced`.
- Return matched text tail and sequence.
- Timeout returns structured `timedOut: true`, not a JSON-RPC error.

### Mutating tools

These require allowlist approval once PBI-ORCH-004 lands. During PBI-ORCH-002 local development, keep them behind `HARNESS_MCP_ALLOW_CONTROL=1`.

#### `sendPaneText`

Input:

```json
{
  "surfaceId": "...",
  "text": "npm test\n",
  "bracketed": false
}
```

Implementation:

- Use `.send(surfaceID:text:)` for text.
- Add key-token variant later if needed; do not overload text with key syntax.

#### `sendPaneKeys`

Input:

```json
{
  "surfaceId": "...",
  "keys": ["C-c", "Enter"]
}
```

Implementation:

- Use `.sendKeys(surfaceID:keys:)`.

#### `spawnSession`

Input:

```json
{
  "workspaceId": "...",
  "cwd": "/path",
  "name": "tests",
  "shell": null
}
```

Implementation:

- Use `.newSession(workspaceID:cwd:name:shell:)`.
- Return new `sessionId`.

#### `splitPane`

Input:

```json
{
  "tabId": "...",
  "paneId": "...",
  "direction": "right",
  "shell": null
}
```

Implementation:

- Map `right/left` to Harness side-by-side split direction and `up/down` to stacked direction using existing command semantics, not a new layout interpretation.
- Use `.newSplit(tabID:paneID:direction:shell:)`.
- Return created pane/surface identifiers if IPC already provides them; otherwise return updated snapshot target.

#### `closePane`

Input:

```json
{
  "paneId": "..."
}
```

Implementation:

- Use `.killPane`.

## Allowlist / Control Gate

Initial gate:

- Read-only tools always enabled.
- Mutating tools require `HARNESS_MCP_ALLOW_CONTROL=1`.

Planned persisted gate:

- `~/.config/harness/mcp-policy.json` or Harness Application Support equivalent.
- Default deny for:
  - `sendPaneText`
  - `sendPaneKeys`
  - `spawnSession`
  - `splitPane`
  - `closePane`
  - existing `runCommand`
  - existing `writeFile`
- Default allow for:
  - `harnessList`
  - `readPaneOutput`
  - `gitStatus`
  - `gitDiff`
  - `gitLog`
  - `listDirectory`
  - `readFile`

Policy shape:

```json
{
  "version": 1,
  "allowControl": false,
  "allowedTools": ["harnessList", "readPaneOutput"],
  "workspaceOverrides": {}
}
```

Do not add GUI confirmation in v1. MCP runs headless over stdio; a GUI prompt would deadlock unattended agent workflows.

## Implementation Plan

### PBI-ORCH-001: Read-only daemon connection

Files:

- New: `Tools/harness-mcp/Sources/HarnessMCP/HarnessDaemonTools.swift`
- Touch: `Tools/harness-mcp/Sources/HarnessMCP/ToolRegistry.swift`
- Optional new tests: `Tests/HarnessMCPTests` if executable-target testing is practical; otherwise cover helpers in `HarnessCoreTests` or daemon round-trip tests.

Tasks:

- Add a small `HarnessDaemonTools` wrapper around `DaemonClientActor`.
- Implement `harnessList`.
- Implement `readPaneOutput`.
- Return structured JSON text, not human-only prose, so agents can parse it.
- Handle daemon unavailable with a clear MCP tool error: "Harness daemon is not running".

Tests:

- Unit test snapshot flattening from a fixture.
- Unit test readPaneOutput argument validation.
- `swift build`.

Acceptance:

- MCP `listTools` includes `harnessList` and `readPaneOutput`.
- Calling `harnessList` against a running preview daemon returns workspace/session/pane IDs.

### PBI-ORCH-002: Mutating pane/session tools behind env gate

Files:

- Touch: `HarnessDaemonTools.swift`
- Touch: `ToolRegistry.swift`

Tasks:

- Add `sendPaneText`, `sendPaneKeys`, `spawnSession`, `splitPane`, `closePane`.
- Gate all mutating tools behind `HARNESS_MCP_ALLOW_CONTROL=1`.
- Return a deterministic error when gate is closed.
- Reuse existing IPC requests; do not add daemon message types unless the return shape truly requires it.

Tests:

- Unit test gate closed.
- Unit test UUID parsing and direction parsing.
- Manual smoke with preview daemon:
  - list panes
  - send `echo harness-mcp-ok\n`
  - read output and verify text

Acceptance:

- A headless MCP client can drive a pane without the GUI ACP path.

### PBI-ORCH-003: Output wait / command completion

Files:

- Touch: `HarnessDaemonTools.swift`

Tasks:

- Implement `waitForPaneOutput`.
- Use subscription + timeout, not polling `capturePane` in a tight loop.
- Add max output tail in response to keep payload bounded.
- Return `timedOut`, `matched`, `tail`, `sequence`.

Tests:

- Daemon integration test if stable.
- Manual smoke with command that prints after a delay.

### PBI-ORCH-004: Persisted policy

Files:

- New: `Tools/harness-mcp/Sources/HarnessMCP/ToolPolicy.swift`
- Touch: `ToolRegistry.swift`

Tasks:

- Load policy at MCP process start.
- Preserve env override for development/testing but make file policy the normal user path.
- Apply policy to existing dangerous tools too: `writeFile`, `runCommand`.
- Keep read-only tools enabled by default.

Tests:

- Policy absent uses safe defaults.
- Policy deny blocks control tools.
- Policy allow enables named tool.

### PBI-ORCH-005: Visibility in Harness UI

Files:

- Requires design pass before implementation.

Tasks:

- Add a lightweight "MCP-controlled" indicator only after MCP control is real.
- Avoid persisting this in `HarnessSettings`; this is runtime/session state.

## Target Ordering With P11

P12 should land before P11 mutating script APIs. Both need a narrow, safe pane/session command facade. Build it once for MCP, then let P11 call into the same conceptual surface from inside the app.

Recommended order:

1. P12 read-only tools.
2. P12 gated mutating tools.
3. P12 wait/output tools.
4. P11 runtime + read-only config/events.
5. P11 mutating APIs over the same command facade.
6. P12 persisted policy.
7. P11 config/keybinding polish.

## Acceptance Criteria

- `swift build` passes.
- Existing MCP tools keep their behavior.
- Read-only pane/session tools work with no env vars.
- Mutating tools fail closed by default.
- With `HARNESS_MCP_ALLOW_CONTROL=1`, an agent can send text to an existing pane and read the result back.
- Daemon unavailable errors are explicit and do not hang MCP stdio.

## Risks

- MCP payload size can balloon if output reads are unbounded. Enforce line caps.
- Direction naming can drift from Harness split semantics. Centralize parser and test it.
- Long-lived subscriptions can leak if `waitForPaneOutput` timeout paths do not cancel/close. Test timeout cleanup.
- `runCommand` and `writeFile` are already powerful. PBI-ORCH-004 should include them in policy, not just new pane-control tools.
