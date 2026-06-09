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
  echo "==> Building release..."
  make build
  echo "==> Packaging..."
  Scripts/package-app.sh release
  echo "==> Ad-hoc signing..."
  codesign --force --sign - --deep "$ROOT/Harness.app" >/dev/null
fi

if [[ ! -d "$ROOT/Harness.app" ]]; then
  echo "error: Harness.app not found at $ROOT/Harness.app — run without --no-build" >&2
  exit 1
fi

# --- Stop running daemon (holds old binary on disk) ---
echo "==> Stopping daemon..."
"$ROOT/Harness.app/Contents/MacOS/harness-cli" daemon stop 2>/dev/null || true
sleep 0.5

# Kill any lingering Harness process so macOS releases the old bundle
pkill -x Harness 2>/dev/null || true
sleep 0.3

# --- Install ---
echo "==> Installing to $DEST..."
rm -rf "$DEST"
ditto "$ROOT/Harness.app" "$DEST"

# --- Clear macOS caches ---
echo "==> Clearing quarantine..."
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "==> Flushing LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -kill -r -domain local -domain system -domain user 2>/dev/null || true

echo "==> Done. Launch with: open $DEST"
