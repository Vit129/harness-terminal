#!/usr/bin/env bash
# Bump Harness's version (Info.plist) — patch/minor/major — and commit the
# bump on the current branch. Used before install/prod/full-cycle builds.
#
# Usage: Scripts/bump-version.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

INFO_PLIST="Apps/Harness/Sources/HarnessApp/Resources/Info.plist"

current_version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
current_build="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
IFS='.' read -r major minor patch <<< "$current_version"
next_build=$((current_build + 1))

echo ""
echo "Current version: v$current_version (build $current_build)"
echo "  1) patch -> $major.$minor.$((patch + 1))"
echo "  2) minor -> $major.$((minor + 1)).0"
echo "  3) major -> $((major + 1)).0.0"
echo "  4) skip — no version bump"
echo ""
read -rp "Enter choice (1-4): " choice

if [[ ! "$choice" =~ ^[1-4]$ ]]; then
  echo "Invalid choice — enter a number from 1 to 4" >&2
  exit 1
fi

if [[ "$choice" == "4" ]]; then
  echo "Skipping version bump."
  exit 0
fi

case "$choice" in
  1) new_version="$major.$minor.$((patch + 1))" ;;
  2) new_version="$major.$((minor + 1)).0" ;;
  3) new_version="$((major + 1)).0.0" ;;
esac

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $new_version" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $next_build" "$INFO_PLIST"

git add "$INFO_PLIST"
git commit -m "chore: bump version to v$new_version (build $next_build)"

echo "Bumped to v$new_version (build $next_build)."
