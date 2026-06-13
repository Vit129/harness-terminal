#!/usr/bin/env bash
# Interactive build & release menu for Harness.app.
#
# Usage:
#   Scripts/start.sh        # interactive menu
#   make start               # same, via Makefile
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
echo "  2) Preview build, isolated (make preview)"
echo "  3) Run dev build (make debug)"
echo "  4) Build app and install to /Applications (make install)"
echo "  5) Build app only, no copy (make prod)"
echo "  6) Full cycle: commit+push (merge if worktree) -> prepare release -> build (4 or 5)"
echo ""
read -rp "Enter choice (1-6): " choice

if [[ ! "$choice" =~ ^[1-6]$ ]]; then
  echo "Invalid choice — enter a number from 1 to 6" >&2
  exit 1
fi

case "$choice" in
  1) exec Scripts/commit-push.sh ;;
  2) exec ./Scripts/run.sh preview ;;
  3) exec ./Scripts/run.sh debug ;;
  4) exec Scripts/install-app.sh ;;
  5) exec ./Scripts/run.sh prod ;;
  6) exec Scripts/full-cycle.sh ;;
esac
