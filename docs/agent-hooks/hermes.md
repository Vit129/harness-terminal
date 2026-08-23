# Hermes → Kouen

[Hermes Agent](https://github.com/nousresearch/hermes-agent) declares
shell-script hooks in `~/.hermes/config.yaml`, gated behind a one-time consent
allowlist (`~/.hermes/shell-hooks-allowlist.json`, managed by `hermes hooks`).

## One-line install

```bash
kouen-cli install-hooks hermes
```

Appends a Kouen-managed region to `~/.hermes/config.yaml` (backing the file up
first; the region is replaced in place on re-install, never duplicated):

```yaml
# >>> kouen-managed (do not edit) >>>
hooks:
  - event: stop
    command: 'PATH="$HOME/Library/Application Support/Kouen/bin:$PATH" kouen-cli notify --surface "$KOUEN_SURFACE" --title "Hermes" --body "Done" --status done'
# <<< kouen-managed <<<
```

## Required: approve the hook

Hermes will not run a shell hook until you approve it:

```bash
hermes hooks            # review configured hooks
# approve the Kouen 'stop' hook when prompted
```

Until then the hook is inert (Hermes refuses to run un-allowlisted shell
commands by design). You can verify with `hermes hooks doctor`.

> If your `config.yaml` already has a top-level `hooks:` key, merge the Kouen
> entry into it by hand — YAML allows only one `hooks:` mapping per document.

The dot color for Hermes panes is `#ff7e6b`.
