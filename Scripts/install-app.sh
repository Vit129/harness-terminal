#!/usr/bin/env bash
# Install a locally built Harness.app into /Applications, clearing macOS caches
# that would otherwise serve the old bundle.
#
# Usage:
#   Scripts/install-app.sh           # build release + install
#   Scripts/install-app.sh --no-build # skip build, install existing Harness.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEST="/Applications/Harness.app"
APP_SUPPORT="$HOME/Library/Application Support/Harness"
APP_SUPPORT_BIN="$APP_SUPPORT/bin"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.robert.harness.daemon.plist"
NO_BUILD=0

for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    -h|--help)
      echo "Usage: Scripts/install-app.sh [--no-build]"
      echo "  --no-build  Skip build; install the existing Harness.app at repo root"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# --- Build ---
if [[ $NO_BUILD -eq 0 ]]; then
  echo "==> Building release (optimized)..."
  # `swift build` only honors the last `--product` flag, not all of them — build
  # everything in release config (mirrors `debug`'s `make build`).
  swift build -c release
  echo "==> Packaging..."
  Scripts/package-app.sh release
  echo "==> Ad-hoc signing..."
  codesign --force --sign - --deep "$ROOT/Harness.app" >/dev/null
fi

if [[ ! -d "$ROOT/Harness.app" ]]; then
  echo "error: Harness.app not found at $ROOT/Harness.app — run without --no-build" >&2
  exit 1
fi

# --- Stop production runtime (old app/daemon binaries can be held by launchd) ---
echo "==> Stopping production runtime..."
launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/com.robert.harness.daemon" 2>/dev/null || true
"$ROOT/Harness.app/Contents/MacOS/harness-cli" daemon stop 2>/dev/null || true
pkill -f "/Applications/Harness.app/Contents/MacOS/HarnessDaemon" 2>/dev/null || true
pkill -f "$APP_SUPPORT_BIN/HarnessDaemon" 2>/dev/null || true
sleep 0.5

# Kill any lingering Harness process so macOS releases the old bundle
pkill -x Harness 2>/dev/null || true
sleep 0.3

# --- Install ---
echo "==> Installing to $DEST..."
rm -rf "$DEST"
ditto "$ROOT/Harness.app" "$DEST"

# Keep the launchd-supervised daemon/CLI copies in sync with the installed app
# before first launch. The app also refreshes these on startup, but doing it here
# closes the window where launchd can respawn an old AppSupport daemon.
echo "==> Refreshing app-support binaries..."
mkdir -p "$APP_SUPPORT_BIN"
ditto "$DEST/Contents/MacOS/HarnessDaemon" "$APP_SUPPORT_BIN/HarnessDaemon"
ditto "$DEST/Contents/MacOS/harness-cli" "$APP_SUPPORT_BIN/harness-cli"
chmod +x "$APP_SUPPORT_BIN/HarnessDaemon" "$APP_SUPPORT_BIN/harness-cli"

Scripts/clear-runtime-state.sh

# --- Clear macOS caches ---
echo "==> Clearing quarantine..."
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "==> Flushing LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -kill -r -domain local -domain system -domain user 2>/dev/null || true

# --- Run ---
echo "==> Opening $DEST..."
open "$DEST"
