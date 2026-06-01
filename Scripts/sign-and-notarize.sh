#!/usr/bin/env bash
set -euo pipefail
# Sign and notarize Harness.app for distribution.
#
# Required:
#   SIGNING_IDENTITY  — e.g. "Developer ID Application: Your Name (TEAMID)"
#
# Notarization (required for distribution — omit ONLY with --sign-only / SIGN_ONLY=1):
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD (app-specific password)
#
# Usage: make sign   or   ./Scripts/sign-and-notarize.sh [--sign-only]
#   --sign-only / SIGN_ONLY=1 : sign locally and skip notarization without failing.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Harness.app"
# Require an explicit identity so a release is never signed with the wrong or
# ambiguous one. Use SIGNING_IDENTITY=- for an ad-hoc (unsigned) local build.
IDENTITY="${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID (or '-' for an ad-hoc local build).}"

SIGN_ONLY="${SIGN_ONLY:-0}"
if [[ "${1:-}" == "--sign-only" ]]; then SIGN_ONLY=1; fi
# An ad-hoc identity ('-') can't be notarized, so treat it as an implicit sign-only build.
if [[ "$IDENTITY" == "-" ]]; then SIGN_ONLY=1; fi

if [[ ! -d "$APP" ]]; then
  echo "Run Scripts/build-release.sh first." >&2
  exit 1
fi

echo "Signing $APP..."
# Sign inside-out (NOT --deep). Sparkle ships nested helpers — XPC services, Updater.app,
# and the Autoupdate tool — that each need their own hardened-runtime signature. `--deep`
# signs them with the app's identity but not correctly (Sparkle explicitly forbids it), so
# the updater is rejected at runtime. Sign the deepest components first, then the framework,
# then the embedded tools, then the app bundle.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE" ]]; then
  echo "  Signing Sparkle.framework components..."
  # XPC services and helper apps/tools live under Versions/<letter>; glob so a version
  # bump (B -> C ...) keeps working.
  for component in \
    "$SPARKLE"/Versions/*/XPCServices/*.xpc \
    "$SPARKLE"/Versions/*/Updater.app \
    "$SPARKLE"/Versions/*/Autoupdate; do
    [[ -e "$component" ]] || continue
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$component"
  done
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$SPARKLE"
fi

codesign --force --options runtime --timestamp --sign "$IDENTITY" \
  "$APP/Contents/MacOS/HarnessDaemon" \
  "$APP/Contents/MacOS/harness-cli" \
  "$APP/Contents/MacOS/Harness"
# Seal the app bundle last (no --deep — nested code is already signed above).
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"

# Verify the whole bundle (nested helpers + app) before we go any further — a broken nested
# signature can pass signing yet fail notarization/Gatekeeper later, so catch it here.
echo "Verifying signatures..."
codesign --verify --deep --strict --verbose=2 "$APP"

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
  if [[ "$SIGN_ONLY" == "1" ]]; then
    echo "Signed only (notarization skipped via --sign-only / ad-hoc identity)."
    exit 0
  fi
  echo "ERROR: notarization credentials missing (APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD)." >&2
  echo "       A distributed build MUST be notarized. Re-run with --sign-only to sign without notarizing." >&2
  exit 1
fi

ZIP="$ROOT/Harness-notarize.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait
xcrun stapler staple "$APP"
# Re-verify after stapling so a corrupt ticket can't slip through.
codesign --verify --deep --strict --verbose=2 "$APP"
rm -f "$ZIP"
echo "Notarized and stapled."
