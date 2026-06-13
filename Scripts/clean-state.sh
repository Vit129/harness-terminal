#!/usr/bin/env bash
# Remove persisted session state (layout snapshot + scrollback) for the legacy
# repo-root debug home.
#
# Scoped to ~/Library/Application Support/HarnessDebug — never touches
# ~/Library/Application Support/Harness, which holds the production app's real
# daily session state.
#
# Usage: Scripts/clean-state.sh
set -euo pipefail

sessions="$HOME/Library/Application Support/HarnessDebug/sessions"
if [[ -d "$sessions" ]]; then
  echo "Removing $sessions"
  rm -rf "$sessions"
else
  echo "Nothing to remove — $sessions does not exist."
fi
