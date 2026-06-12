#!/usr/bin/env bash
# Full cycle: commit+push -> prepare release -> build (install or prod).
#
# Usage: Scripts/full-cycle.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./Scripts/commit-push.sh
./Scripts/prepare-release.sh

echo ""
read -rp "Build step — 4) install to /Applications or 5) build only (prod)? [4/5]: " build_choice
case "$build_choice" in
  4) exec Scripts/install-app.sh ;;
  5) exec ./Scripts/run.sh prod ;;
  *) echo "Invalid choice" >&2; exit 1 ;;
esac
