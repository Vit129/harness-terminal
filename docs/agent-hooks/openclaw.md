# OpenClaw → Kouen

[OpenClaw](https://docs.openclaw.ai/cli/hooks) reads a JSON5 config from
`~/.openclaw/openclaw.json` (comments and trailing commas allowed) and supports
shell-command hooks that read event JSON on stdin.

## One-line install

```bash
kouen-cli install-hooks openclaw
```

Inserts a Kouen-managed region just inside the root object of
`~/.openclaw/openclaw.json` (backing the file up first; edited as **text** so
your comments and trailing commas survive — never reserialized):

```json5
{
  // >>> kouen-managed (do not edit) >>>
  "hooks": {
    "kouen-notify": {
      "command": "PATH=\"$HOME/Library/Application Support/Kouen/bin:$PATH\" kouen-cli notify --surface \"$KOUEN_SURFACE\" --title \"OpenClaw\" --body \"Done\" --status done",
    },
  },
  // <<< kouen-managed <<<
  // …your existing config…
}
```

Re-running `install-hooks openclaw` replaces the managed region in place.

> If your `openclaw.json` already defines a top-level `hooks` object, merge the
> `kouen-notify` entry into it by hand — a JSON5 object can't have two `hooks`
> keys. OpenClaw's hook system is gateway/guardrail-oriented; depending on your
> build, you may prefer wiring `kouen-cli notify` into a gateway mapping
> instead. The command itself (and `$KOUEN_SURFACE`) is the same either way.

The dot color for OpenClaw panes is `#f5a623`.
