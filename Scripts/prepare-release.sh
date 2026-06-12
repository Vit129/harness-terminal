#!/usr/bin/env bash
# Bumps Info.plist + git tag from the unreleased CHANGELOG.md entry, then offers
# to dispatch Scripts/release-hotfix.sh (the actual signed/notarized CI release —
# requires explicit confirmation since it publishes to all users).
#
# Usage: Scripts/prepare-release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

INFO_PLIST="Apps/Harness/Sources/HarnessApp/Resources/Info.plist"
RELEASE_NOTES_SWIFT="Packages/HarnessCore/Sources/HarnessCore/ReleaseNotes/GeneratedReleaseNotes.swift"

plist_version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
plist_build="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
cl_version="$(grep -m1 -oE '^## \[[^]]+\]' CHANGELOG.md | sed -E 's/^## \[(.+)\]$/\1/')"

echo ""
echo "Info.plist version/build: $plist_version ($plist_build)"
echo "CHANGELOG.md top version:  $cl_version"
echo ""

if [[ "$cl_version" == "$plist_version" ]]; then
  echo "CHANGELOG.md's top entry ($cl_version) matches the shipped Info.plist version." >&2
  echo "Add a new '## [X.Y.Z] - $(date +%Y-%m-%d)' section to CHANGELOG.md describing" >&2
  echo "this release's changes, commit it (Scripts/commit-push.sh), then re-run." >&2
  exit 1
fi

next_build=$((plist_build + 1))
read -rp "Build number for $cl_version [$next_build]: " build_input
build="${build_input:-$next_build}"

echo ""
echo "Regenerating release notes from CHANGELOG.md [$cl_version]..."
make release-notes

if ! git diff --quiet -- "$RELEASE_NOTES_SWIFT" CHANGELOG.md; then
  git add CHANGELOG.md "$RELEASE_NOTES_SWIFT"
  git commit -m "chore: release notes for v$cl_version"
  git push origin main
fi

echo ""
echo "Ready to release v$cl_version via Scripts/release-hotfix.sh."
echo "This bumps Info.plist to $cl_version ($build), pushes, tags v$cl_version,"
echo "and triggers the signed/notarized GitHub Actions release — published to all users."
echo ""
read -rp "Run release-hotfix.sh now? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  ./Scripts/release-hotfix.sh --tag "v$cl_version" --version "$cl_version" --build "$build"
else
  echo "Skipped. Run manually when ready:"
  echo "  ./Scripts/release-hotfix.sh --tag v$cl_version --version $cl_version --build $build"
fi
