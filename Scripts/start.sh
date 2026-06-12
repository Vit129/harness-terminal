#!/usr/bin/env bash
# Interactive build & release menu for Harness.app.
#
# Usage:
#   Scripts/start.sh        # interactive menu
#   make start               # same, via Makefile
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo ""
echo "Harness build & release"
echo ""
echo "  1) Commit + push changes"
echo "  2) Preview build, isolated (make preview)"
echo "  3) Run dev build (make debug)"
echo "  4) Build app and install to /Applications (make install)"
echo "  5) Build app only, no copy (make prod)"
echo "  6) Full cycle: commit+push -> prepare release -> build (4 or 5)"
echo ""
read -rp "Enter choice (1-6): " choice

case "$choice" in
  1) exec Scripts/commit-push.sh ;;
  2) exec ./Scripts/run.sh preview ;;
  3) exec ./Scripts/run.sh debug ;;
  4) exec Scripts/install-app.sh ;;
  5) exec ./Scripts/run.sh prod ;;
  6) exec Scripts/full-cycle.sh ;;
  *)
    echo "Invalid choice" >&2
    exit 1
    ;;
esac
