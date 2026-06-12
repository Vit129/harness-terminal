#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage: Scripts/run.sh [command]

Commands:
  preview   Build and launch isolated preview app (.harness-preview) [default]
  debug     Build (debug), package, sign, and open Harness.app
  prod      Build (release), package, sign, and open Harness.app (no /Applications copy)
  run       Re-open the existing Harness.app without rebuilding
  build     Run swift build
  stop      Stop preview app
  graphify  Refresh graphify-out without committed HTML output

Examples:
  make debug              # build (debug) + open
  make prod               # build (release) + open
  make run                # just re-open the existing build
  Scripts/run.sh preview  # isolated preview
  Scripts/run.sh graphify
USAGE
}

# Kill any already-running instance so the new build is what actually loads —
# `open` on a running app just re-activates the old process.
kill_stale() {
  pkill -f "$ROOT/Harness.app/Contents/MacOS/HarnessDaemon" 2>/dev/null || true
  pkill -f "$ROOT/Harness.app/Contents/MacOS/Harness\$" 2>/dev/null || true
  sleep 0.5
}

# prod/run builds at the repo root are release builds, so they share the production
# HARNESS_HOME (~/Library/Application Support/Harness) with /Applications/Harness.app
# and the launchd-managed daemon (`make install`). Without stopping those too, the
# fresh repo-root app reconnects to the old launchd daemon/socket and looks unchanged.
# `debug` builds use an isolated HarnessDebug home and don't need this.
kill_stale_prod() {
  kill_stale
  pkill -f "/Applications/Harness.app/Contents/MacOS/HarnessDaemon" 2>/dev/null || true
  pkill -f "/Applications/Harness.app/Contents/MacOS/Harness\$" 2>/dev/null || true
  launchctl bootout "gui/$(id -u)/com.robert.harness.daemon" 2>/dev/null || true
  pkill -f "$HOME/Library/Application Support/Harness/bin/HarnessDaemon" 2>/dev/null || true
  sleep 0.5
}

command="${1:-preview}"

case "$command" in
  preview)
    exec make preview
    ;;
  debug)
    make build
    Scripts/package-app.sh debug
    codesign --force --sign - --deep Harness.app >/dev/null
    kill_stale
    open Harness.app
    ;;
  prod)
    # `swift build` only honors the last `--product` flag, not all of them — build
    # everything in release config (mirrors `debug`'s `make build`).
    swift build -c release
    Scripts/package-app.sh release
    codesign --force --sign - --deep Harness.app >/dev/null
    kill_stale_prod
    open Harness.app
    ;;
  run)
    if [[ ! -d Harness.app ]]; then
      echo "error: Harness.app not found at repo root — run 'make debug' or 'make prod' first" >&2
      exit 1
    fi
    kill_stale_prod
    open Harness.app
    ;;
  build)
    exec make build
    ;;
  stop)
    exec make preview-stop
    ;;
  graphify)
    graphify update . --force
    find graphify-out -type f -name '*.html' -delete
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
