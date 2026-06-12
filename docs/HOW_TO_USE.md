# How to use Harness from the terminal only (no GUI)

`HarnessDaemon` runs as a background `launchd` service and owns all session state and PTYs.
The macOS app is just one client; `harness-cli` is another. You can list, attach to, and
drive sessions entirely from a shell, without ever opening `Harness.app`.

For the full multiplexer model and command grammar, see
[MULTIPLEXER_GUIDE.md](MULTIPLEXER_GUIDE.md) and [COMMANDS.md](COMMANDS.md). This page is a
quick-start for the headless/CLI-only workflow.

## 1. Find the CLI

The installed CLI lives at:

```bash
"/Users/supavit.cho/Library/Application Support/Harness/bin/harness-cli"
```

Run `harness-cli install` once to symlink it onto your `PATH`, or add an alias:

```bash
alias hc='"/Users/supavit.cho/Library/Application Support/Harness/bin/harness-cli"'
```

## 2. Check daemon health

```bash
hc doctor   # daemon reachability, socket, version, hooks, shell integration
hc ping
```

A version mismatch warning (`daemon X != CLI Y`) means the running daemon needs a restart
(quit/reopen `Harness.app`, or `hc install` then restart the daemon).

## 3. List what's running (like `tmux ls`)

```bash
hc list-workspaces
hc list-sessions
hc list-surfaces   # surface UUID, workspace, title, cwd — for attach/send targets
```

## 4. Attach to a pane

```bash
hc attach --surface <uuid>
```

- Default detach key: `Ctrl-A d`; override with `--detach-keys "C-a d"`.
- If the GUI has the same surface open, output stays in sync on both sides.

For a full tab layout (all panes, status line, splits) instead of a single pane:

```bash
hc attach-window                  # the active tab
hc attach-window --session work   # a named session
```

## 5. Create sessions/tabs from a script

```bash
hc new-session --workspace Default --name "my-task" --cwd ~/Git/harness-terminal
hc new-tab --workspace Default --cwd ~/some/path
```

## 6. Drive a pane without attaching

```bash
hc send --surface <uuid> --text "ls -la\n"
hc send-keys --surface <uuid> --keys "C-c Up Enter"
hc capture-pane --surface <uuid> --scrollback
```

## 7. tmux control mode

```bash
hc control-mode   # or: hc -CC
```

## 8. Remote/headless daemon

Point the CLI at a daemon on another machine over SSH:

```bash
hc remote add --name devbox --ssh me@devbox --socket "/home/me/.config/harness/harness.sock"
hc new-session --host devbox --cwd ~/Code
hc capture-pane --host devbox --surface <id>
hc doctor --host devbox
```

See [MULTIPLEXER_GUIDE.md § Driving a headless or remote daemon](MULTIPLEXER_GUIDE.md#driving-a-headless-or-remote-daemon)
for details.
