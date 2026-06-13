#!/usr/bin/env bash
# Interactive build & release menu for Harness.app.
#
# Usage:
#   Scripts/start.sh        # interactive menu
#   make start              # same, via Makefile
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

INFO_PLIST="Apps/Harness/Sources/HarnessApp/Resources/Info.plist"
CURRENT_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
NEXT_PATCH="$MAJOR.$MINOR.$((PATCH + 1))"
NEXT_MINOR="$MAJOR.$((MINOR + 1)).0"
NEXT_MAJOR="$((MAJOR + 1)).0.0"

echo ""
echo "Harness build & release"
echo "Current Version: v$CURRENT_VERSION (build $CURRENT_BUILD)"
echo "Next: $NEXT_PATCH patch / $NEXT_MINOR minor / $NEXT_MAJOR major"
echo ""
echo "  1) Commit + push changes"
echo "  2) Preview build, isolated dev/test app (make preview)"
echo "  3) Bump version, then build app and install to /Applications (make install)"
echo "  4) Bump version, then build app only, no copy (make prod)"
echo "  5) Full cycle: bump version -> commit+push (merge if worktree) -> build (3 or 4)"
echo ""
read -rp "Enter choice (1-5): " choice

if [[ ! "$choice" =~ ^[1-5]$ ]]; then
  echo "Invalid choice — enter a number from 1 to 5" >&2
  exit 1
fi

case "$choice" in
  1) exec Scripts/commit-push.sh ;;
  2) exec ./Scripts/run.sh preview ;;
  3)
    ./Scripts/prepare-release.sh
    exec Scripts/install-app.sh
    ;;
  4)
    ./Scripts/prepare-release.sh
    exec ./Scripts/run.sh prod
    ;;
  5) exec Scripts/full-cycle.sh ;;
esac
