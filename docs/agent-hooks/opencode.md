# OpenCode → Kouen

[OpenCode](https://opencode.ai/docs/plugins/) extends itself with JS/TS
**plugins** auto-loaded from `~/.config/opencode/plugins/`. A plugin subscribes
to session events and can run shell commands via Bun's `$` API — that's how
Kouen gets notified.

## One-line install

```bash
kouen-cli install-hooks opencode
```

Writes `~/.config/opencode/plugins/kouen.js`:

```js
// kouen-managed — surfaces OpenCode session events in Kouen. Safe to delete.
export const KouenNotify = async ({ $ }) => ({
  "session.idle": async () => {
    await $`PATH="$HOME/Library/Application Support/Kouen/bin:$PATH" kouen-cli notify --surface "${process.env.KOUEN_SURFACE ?? ""}" --title OpenCode --body Done --status done`
  },
  "permission.asked": async () => {
    await $`PATH="$HOME/Library/Application Support/Kouen/bin:$PATH" kouen-cli notify --surface "${process.env.KOUEN_SURFACE ?? ""}" --title OpenCode --body "Awaiting input"`
  },
})
```

- `session.idle` fires when the agent finishes a turn and goes quiet.
- `permission.asked` fires when it needs your approval.

The plugin reads `$KOUEN_SURFACE` (exported by Kouen for every pane) so the
notification lands on the right tab. It loads on OpenCode's next session.
Re-running `install-hooks opencode` overwrites this file in place (backing up
the previous copy).

## What you'll see

- The tab pill's dot turns OpenCode teal when an `opencode` process is detected.
- On idle / permission events you get a macOS banner + sidebar entry;
  `Cmd+Shift+I` opens the Agent Notch for direct selection, and `Cmd+Shift+U` opens the notifications inbox.

The dot color for OpenCode panes is `#56b6c2`.
