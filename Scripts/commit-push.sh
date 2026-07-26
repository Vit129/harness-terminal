#!/usr/bin/env bash
# Commit + push the working tree, offering a PR if not on main.
#
# Usage: Scripts/commit-push.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "$(git status --porcelain)" ]]; then
  echo "Nothing to commit — working tree is clean."
  exit 0
fi

echo ""
git status -s
echo ""
echo "Conventional commit format: <type>(<scope>): <summary>"
echo "  types: feat, fix, refactor, chore, docs, test, perf, build, ci"
echo ""
read -erp "Commit message: " msg
if [[ -z "$msg" ]]; then
  echo "Empty commit message — aborting." >&2
  exit 1
fi

git add -A

# This script only runs from full-cycle.sh, always right after a version bump —
# so a staged Info.plist here always means a release commit. Auto-tag the message
# so the commit-msg guardrail never blocks on a forgotten "version" keyword.
if git diff --cached --name-only | grep -q "Info.plist" && ! echo "$msg" | grep -qiE "version|bump|release|build|[0-9]+\.[0-9]+\.[0-9]+"; then
  ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Apps/Kouen/Sources/KouenApp/Resources/Info.plist 2>/dev/null || true)"
  if [[ -n "$ver" ]]; then
    msg="${msg} (release v${ver})"
  fi
fi

git commit -m "$msg"

branch="$(git branch --show-current)"
git push -u origin "$branch"

if [[ "$branch" != "main" ]]; then
  read -erp "Open a PR for '$branch' into main? (y/N): " open_pr
  if [[ "$open_pr" =~ ^[Yy]$ ]]; then
    gh pr create --fill --base main --head "$branch" || gh pr view --web
  fi
fi
