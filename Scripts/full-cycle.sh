#!/usr/bin/env bash
# Full cycle: commit+push (merging into main first if run from a worktree)
# -> prepare release -> build (install or prod).
#
# Usage: Scripts/full-cycle.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

git_dir="$(git rev-parse --git-dir)"

if [[ "$git_dir" == *"worktrees"* ]]; then
  echo "Detected: running in a worktree — merging into main first."
  ./Scripts/commit-push-merge.sh

  common_dir="$(git rev-parse --git-common-dir)"
  main_repo="$(cd "$(dirname "$common_dir")" && pwd)"

  echo ""
  echo "Code merged to main."
  echo "To continue the release, run in the main repo:"
  echo "  cd \"$main_repo\""
  echo "  git pull origin main"
  echo "  make start   # choose option 6"
  exit 0
fi

./Scripts/commit-push.sh
./Scripts/prepare-release.sh

echo ""
read -rp "Build step — 4) install to /Applications or 5) build only (prod)? [4/5]: " build_choice
case "$build_choice" in
  4) exec Scripts/install-app.sh ;;
  5) exec ./Scripts/run.sh prod ;;
  *) echo "Invalid choice" >&2; exit 1 ;;
esac
