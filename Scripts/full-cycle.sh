#!/usr/bin/env bash
# Full cycle: bump version -> commit+push (merging into main first if run from
# a worktree) -> repo-root prod build.
#
# Usage:
#   Scripts/full-cycle.sh [patch|minor|major] [--version X.Y.Z] [--build N]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  cat <<'USAGE'
Usage:
  Scripts/full-cycle.sh [patch|minor|major] [--version X.Y.Z] [--build N]

Runs:
  1. Bump release metadata.
  2. Commit and push changes.
  3. Merge to main first when launched from a worktree.
  4. Build and open the repo-root production app.
USAGE
}

case "${1:-}" in
  -h|--help|help)
    usage
    exit 0
    ;;
esac

git_dir="$(git rev-parse --git-dir)"
merged_from_worktree=0

./Scripts/prepare-release.sh "$@"

if [[ "$git_dir" == *"worktrees"* ]]; then
  echo "Detected: running in a worktree — merging into main first."
  ./Scripts/commit-push-merge.sh

  common_dir="$(git rev-parse --git-common-dir)"
  main_repo="$(cd "$(dirname "$common_dir")" && pwd)"

  echo ""
  echo "Code merged to main. Continuing build from:"
  echo "  $main_repo"
  cd "$main_repo"
  git pull --ff-only origin main
  merged_from_worktree=1
fi

if [[ "$merged_from_worktree" == "0" ]]; then
  ./Scripts/commit-push.sh
fi

echo ""
echo "Building repo-root production app..."
exec ./Scripts/run.sh prod
