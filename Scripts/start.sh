#!/usr/bin/env bash
# Interactive build & release menu for Harness.app (delegates to Node.js).
#
# Usage:
#   Scripts/start.sh        # interactive menu
#   make start              # same, via Makefile
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec node Scripts/start.js "$@"
