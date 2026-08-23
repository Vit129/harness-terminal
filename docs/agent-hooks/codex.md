# Codex → Kouen

Surface Codex CLI pause / done events as Kouen pane notifications.

## One-line install

```bash
kouen-cli install-hooks codex
```

Writes `~/.codex/hooks.json` (the event/matcher shape Codex uses — the same as Claude
Code, deep-merged into any existing hooks):

```json
{
  "hooks": {
    "PermissionRequest": [
      { "matcher": "*", "hooks": [{ "type": "command", "command": "PATH=\"$HOME/Library/Application Support/Kouen/bin:$PATH\" kouen-cli notify --surface \"$KOUEN_SURFACE\" --title \"Codex\" --body \"Awaiting input\"" }] }
    ],
    "Notification": [
      { "matcher": "*", "hooks": [{ "type": "command", "command": "PATH=\"$HOME/Library/Application Support/Kouen/bin:$PATH\" kouen-cli notify --surface \"$KOUEN_SURFACE\" --title \"Codex\" --body \"Notification\"" }] }
    ],
    "Stop": [
      { "matcher": "*", "hooks": [{ "type": "command", "command": "PATH=\"$HOME/Library/Application Support/Kouen/bin:$PATH\" kouen-cli notify --surface \"$KOUEN_SURFACE\" --title \"Codex\" --body \"Done\" --status done" }] }
    ]
  }
}
```

> **Codex hooks are enabled by default** in current releases — the old
> `[features] hooks = true` flag only *disables* them, so Kouen no longer
> writes `~/.codex/config.toml`. On a very old Codex that ignores `hooks.json`,
> upgrade Codex, or add `[features]` / `hooks = true` to `config.toml` yourself.

## What you'll see

- The tab pill's dot turns OpenAI green when Codex is the running agent.
- When Codex pauses (waiting on approval, etc.), the pane's status flips to
  `awaiting`; `Cmd+Shift+I` opens the Agent Notch for direct selection, and `Cmd+Shift+U` opens the notifications inbox.

If your Codex install uses a different hook config path, copy the JSON above
to the correct location manually.
