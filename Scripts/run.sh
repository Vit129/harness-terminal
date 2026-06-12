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
    swift build -c release --product Harness --product HarnessDaemon --product harness-cli
    Scripts/package-app.sh release
    codesign --force --sign - --deep Harness.app >/dev/null
    kill_stale
    open Harness.app
    ;;
  run)
    if [[ ! -d Harness.app ]]; then
      echo "error: Harness.app not found at repo root — run 'make debug' or 'make prod' first" >&2
      exit 1
    fi
    kill_stale
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
