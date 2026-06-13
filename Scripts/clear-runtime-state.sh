#!/usr/bin/env bash
# Clear production runtime state that can make a freshly built Harness.app
# reconnect to stale panes, scrollback, sockets, or daemon buffers.
#
# Intentionally preserves user configuration: settings, keybindings, themes,
# options, hooks, environment, and installed agent metadata.
set -euo pipefail

APP_SUPPORT="$HOME/Library/Application Support/Harness"
CACHE_ROOT="$HOME/Library/Caches/Harness"

echo "==> Clearing production runtime state..."
rm -rf "$APP_SUPPORT/sessions"
rm -rf "$APP_SUPPORT/tunnels"
rm -rf "$APP_SUPPORT/logs"
rm -f "$APP_SUPPORT/harness.sock"
rm -f "$APP_SUPPORT/daemon.pid"
rm -f "$APP_SUPPORT/buffers.json"
rm -f "$APP_SUPPORT/version-state.json"
rm -f "$APP_SUPPORT/command-history.json"
rm -rf "$CACHE_ROOT/pasted-images"
