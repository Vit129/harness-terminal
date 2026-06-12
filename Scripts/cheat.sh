#!/usr/bin/env bash
# Terminal power-user cheat sheet: Linux commands + Vi/Vim commands.
# Usage: Scripts/cheat.sh [linux|vi|all] [--dump]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/cheatsheets"

usage() {
  cat <<'EOF'
Usage: cheat.sh [linux|vi|all] [--dump]

  linux|vi|all   restrict to one cheat sheet (default: all)
  --dump         print the full cheat sheet instead of opening fzf
  -h, --help     show this help
EOF
}

topic="all"
dump=false
for arg in "$@"; do
  case "$arg" in
    linux|vi|all) topic="$arg" ;;
    --dump) dump=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage; exit 1 ;;
  esac
done

files=()
case "$topic" in
  linux) files=("$DATA_DIR/linux.txt") ;;
  vi) files=("$DATA_DIR/vi.txt") ;;
  all) files=("$DATA_DIR/linux.txt" "$DATA_DIR/vi.txt") ;;
esac

entries() {
  for f in "${files[@]}"; do
    grep -vE '^(#|\s*$)' "$f"
  done
}

if $dump; then
  entries | column -t -s $'\t'
  exit 0
fi

if ! command -v fzf >/dev/null 2>&1; then
  echo "fzf not found - showing full cheat sheet instead" >&2
  entries | column -t -s $'\t'
  exit 0
fi

entries | column -t -s $'\t' \
  | fzf --height=80% --reverse --header="Terminal cheat sheet (${topic}) - type to search"
