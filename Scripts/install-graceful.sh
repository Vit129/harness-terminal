#!/usr/bin/env bash
# Graceful install: preserve session layout across version updates.
# Workspace structure and pane CWDs are restored after restart. The daemon (and every
# PTY/agent task running under it) is only restarted when the IPC wire protocol actually
# changed between the installed build and the new one — most releases are UI-only, so
# running shells/agents survive the install untouched; only the GUI restarts.
#
# Crucially, this script can be run from *inside* a Kouen pane:
# the install work is handed off to a detached background process before
# Kouen is asked to quit, so the pane dying doesn't abort the install.
#
# Usage:
#   Scripts/install-graceful.sh           # build release + graceful install
#   Scripts/install-graceful.sh --no-build # skip build, install existing Kouen.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEST="/Applications/Kouen.app"
APP_SUPPORT="$HOME/Library/Application Support/Kouen"
APP_SUPPORT_BIN="$APP_SUPPORT/bin"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.vit129.kouen.daemon.plist"
LOG="$APP_SUPPORT/install-graceful.log"
NO_BUILD=0

for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    -h|--help)
      echo "Usage: Scripts/install-graceful.sh [--no-build]"
      echo "  --no-build  Skip build; install the existing Kouen.app at repo root"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# --- Build ---
if [[ $NO_BUILD -eq 0 ]]; then
  echo "==> Building release (optimized)..."
  swift build -c release
  echo "==> Packaging..."
  Scripts/package-app.sh release
  echo "==> Ad-hoc signing..."
  codesign --force --sign - --deep "$ROOT/Kouen.app" >/dev/null
fi

if [[ ! -d "$ROOT/Kouen.app" ]]; then
  echo "error: Kouen.app not found at $ROOT/Kouen.app — run without --no-build" >&2
  exit 1
fi

# Absolute paths for the detached helper (it runs in a different cwd)
SRC_ABS=$(cd "$ROOT" && pwd)/Kouen.app
DEST_ABS="$DEST"
UID_NUM=$(id -u)

# --- Decide whether the daemon actually needs to restart ---
# `ipcProtocolVersion` is a compile-time constant baked into kouen-cli, shared by the
# daemon it ships alongside. Comparing the CURRENTLY INSTALLED cli's value (a stand-in for
# the running daemon's protocol, since they were built together) against the NEW build's
# value tells us whether this release touched the wire format at all. Most releases don't —
# they're UI-only — so the daemon (and every PTY/agent task running under it) can survive
# the install untouched; only the GUI needs to restart.
REUSE_DAEMON=0
# `pgrep -f`/`-x` unreliably miss this daemon on some macOS builds (observed: false
# negative even while `ps`/`launchctl print` both confirm it's running) — ask launchd
# directly instead, since that's already the authority STOP_DAEMON_LINES uses to kill it.
if launchctl print "gui/$UID_NUM/com.vit129.kouen.daemon" 2>/dev/null | grep -q "state = running"; then
  INSTALLED_CLI=""
  if [[ -x "$APP_SUPPORT_BIN/kouen-cli" ]]; then
    INSTALLED_CLI="$APP_SUPPORT_BIN/kouen-cli"
  elif [[ -x "$DEST/Contents/MacOS/kouen-cli" ]]; then
    INSTALLED_CLI="$DEST/Contents/MacOS/kouen-cli"
  fi
  if [[ -n "$INSTALLED_CLI" ]]; then
    OLD_PROTO=$("$INSTALLED_CLI" protocol-version 2>/dev/null || echo "")
    NEW_PROTO=$("$SRC_ABS/Contents/MacOS/kouen-cli" protocol-version 2>/dev/null || echo "")
    if [[ -n "$OLD_PROTO" && "$OLD_PROTO" == "$NEW_PROTO" ]]; then
      REUSE_DAEMON=1
      echo "==> IPC protocol unchanged ($OLD_PROTO) — daemon (and running tasks) will keep running."
    else
      echo "==> IPC protocol changed ($OLD_PROTO -> $NEW_PROTO) — daemon must restart."
    fi
  fi
fi

# Lines that stop the daemon, blanked out entirely when it's safe to keep running.
STOP_DAEMON_LINES="
    echo '-- stopping daemon'
    launchctl bootout 'gui/$UID_NUM' '$LAUNCH_AGENT' 2>/dev/null || true
    launchctl bootout 'gui/$UID_NUM/com.vit129.kouen.daemon' 2>/dev/null || true
    pkill -f '/Applications/Kouen.app/Contents/MacOS/KouenDaemon' 2>/dev/null || true
    pkill -f '$APP_SUPPORT_BIN/KouenDaemon' 2>/dev/null || true
    sleep 0.5
"
if [[ $REUSE_DAEMON -eq 1 ]]; then
  STOP_DAEMON_LINES="    echo '-- reusing running daemon (protocol unchanged); not stopping it'"
fi

if pgrep -x Kouen > /dev/null 2>&1; then
  # Force a synchronous layout.json write and wait for the daemon's ack before killing it —
  # a blind sleep only ever raced the 0.5s debounce timer, with no confirmation the write
  # actually landed (see agent-memory/plans/claude-code-harness/design.md's follow-up
  # incident notes). Falls back to the old sleep if the CURRENTLY RUNNING daemon predates
  # this command (e.g. this exact release, before any daemon has it yet) — `flush-session-
  # state` is itself a new IPC case, so it can't help a daemon that's never seen it.
  echo "==> Flushing session state..."
  FLUSH_CLI=""
  if [[ -x "$APP_SUPPORT_BIN/kouen-cli" ]]; then
    FLUSH_CLI="$APP_SUPPORT_BIN/kouen-cli"
  elif [[ -x "$DEST/Contents/MacOS/kouen-cli" ]]; then
    FLUSH_CLI="$DEST/Contents/MacOS/kouen-cli"
  fi
  if [[ -z "$FLUSH_CLI" ]] || ! "$FLUSH_CLI" flush-session-state >/dev/null 2>&1; then
    echo "==> (flush-session-state unavailable on the running daemon — falling back to a fixed wait)"
    sleep 1
  fi

  echo "==> Scheduling background installer..."
  # Hand install + relaunch off to a process that survives Kouen dying.
  nohup bash -c "
    echo '-- waiting for Kouen GUI to exit'
    for i in \$(seq 1 100); do
      pgrep -x Kouen > /dev/null 2>&1 || break
      sleep 0.1
    done
$STOP_DAEMON_LINES
    echo '-- installing $SRC_ABS -> $DEST_ABS'
    rm -rf '$DEST_ABS'
    ditto '$SRC_ABS' '$DEST_ABS'
    mkdir -p '$APP_SUPPORT_BIN'
    ditto '$DEST_ABS/Contents/MacOS/KouenDaemon' '$APP_SUPPORT_BIN/KouenDaemon'
    ditto '$DEST_ABS/Contents/MacOS/kouen-cli' '$APP_SUPPORT_BIN/kouen-cli'
    chmod +x '$APP_SUPPORT_BIN/KouenDaemon' '$APP_SUPPORT_BIN/kouen-cli'
    xattr -dr com.apple.quarantine '$DEST_ABS' 2>/dev/null || true
    sleep 0.3
    echo '-- launching'
    open '$DEST_ABS'
    echo '-- done'
  " >> "$LOG" 2>&1 &

  echo "==> Quitting Kouen — will restart with new build momentarily..."
  echo "    (log: $LOG)"
  osascript -e 'tell application "Kouen" to quit' 2>/dev/null || \
    pkill -TERM Kouen 2>/dev/null || true

else
  # GUI not running — but a detached daemon (e.g. background agent tasks attached only via
  # `kouen attach`/MCP) may still be alive, so the same reuse check applies.
  if [[ $REUSE_DAEMON -eq 1 ]]; then
    echo "==> Reusing running daemon (protocol unchanged); not stopping it."
  else
    echo "==> Stopping any stale daemon..."
    launchctl bootout "gui/$UID_NUM" "$LAUNCH_AGENT" 2>/dev/null || true
    launchctl bootout "gui/$UID_NUM/com.vit129.kouen.daemon" 2>/dev/null || true
    pkill -f "/Applications/Kouen.app/Contents/MacOS/KouenDaemon" 2>/dev/null || true
    pkill -f "$APP_SUPPORT_BIN/KouenDaemon" 2>/dev/null || true
    sleep 0.5
  fi

  echo "==> Installing to $DEST..."
  rm -rf "$DEST"
  ditto "$ROOT/Kouen.app" "$DEST"
  mkdir -p "$APP_SUPPORT_BIN"
  ditto "$DEST/Contents/MacOS/KouenDaemon" "$APP_SUPPORT_BIN/KouenDaemon"
  ditto "$DEST/Contents/MacOS/kouen-cli" "$APP_SUPPORT_BIN/kouen-cli"
  chmod +x "$APP_SUPPORT_BIN/KouenDaemon" "$APP_SUPPORT_BIN/kouen-cli"
  xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

  echo "==> Opening $DEST..."
  open "$DEST"
fi
