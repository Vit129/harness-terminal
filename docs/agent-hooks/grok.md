# Grok Build → Kouen

[Grok Build](https://x.ai/news/grok-build-cli) (xAI's coding CLI) runs shell
commands at lifecycle events. It merges every `*.json` under `~/.grok/hooks/`,
so Kouen writes its **own** file there and never touches yours.

## One-line install

```bash
kouen-cli install-hooks grok
```

Writes `~/.grok/hooks/kouen.json`:

```json
{
  "on-complete": "PATH=\"$HOME/Library/Application Support/Kouen/bin:$PATH\" kouen-cli notify --surface \"$KOUEN_SURFACE\" --title \"Grok\" --body \"Done\" --status done",
  "on-error": "PATH=\"$HOME/Library/Application Support/Kouen/bin:$PATH\" kouen-cli notify --surface \"$KOUEN_SURFACE\" --title \"Grok\" --body \"Error\""
}
```

`$KOUEN_SURFACE` is exported by Kouen for every pane, so the hook always
notifies the right tab. Because this is a dedicated Kouen file, re-running
`install-hooks grok` simply overwrites it — your other `~/.grok/hooks/*.json`
files are left alone.

## What you'll see

- The tab pill's dot turns Grok blue when a `grok` / `grok-build` process is
  detected in that pane.
- When Grok finishes (or errors), you get a macOS banner + sidebar entry;
  `Cmd+Shift+I` opens the Agent Notch for direct selection, and `Cmd+Shift+U` opens the notifications inbox.

> Grok Build is young and its hook event names are still settling. If
> `on-complete` / `on-error` don't fire in your build, check `grok` docs for the
> current event keys and edit `~/.grok/hooks/kouen.json` — the `kouen-cli
> notify` command is unchanged. Grok also honors Claude Code / Codex hook
> conventions, so the event/matcher style works too if your build prefers it.

The dot color for Grok panes is `#1d9bf0`.
