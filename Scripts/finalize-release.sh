#!/usr/bin/env bash
set -euo pipefail
# Finalize a Harness release: notarize the (already Developer-ID-signed) DMG, staple it,
# re-upload to the GitHub release, generate the Sparkle appcast, and (optionally) deploy it to
# the website. This is the one step that needs an Apple credential and a Sparkle keychain key —
# secrets that intentionally live with the human, not in the repo or CI image.
#
# Prereq: ./Scripts/build-release.sh && SIGNING_IDENTITY=… ./Scripts/sign-and-notarize.sh && \
#         ./Scripts/create-dmg.sh   (or `make dmg` + `make sign`) so Harness.app + Harness.dmg exist.
#
# Auth — provide ONE of:
#   App Store Connect API key (recommended):
#     ASC_ISSUER_ID=<issuer-uuid>            # App Store Connect → Users and Access → Integrations → Keys
#     ASC_KEY_ID=53WA44Z689                  # defaults to 53WA44Z689
#     ASC_KEY=~/Downloads/AuthKey_53WA44Z689.p8   # defaults to ~/Downloads/AuthKey_<ASC_KEY_ID>.p8
#   …or an Apple ID app-specific password:
#     APPLE_ID=you@example.com APPLE_TEAM_ID=9F2JXY8TCK APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
#
# Optional:
#   TAG=v1.0.0                               # GitHub release tag to re-upload the stapled DMG to
#   DEPLOY_WEBSITE=1 WEBSITE_DIR=~/Code/harness-website   # copy appcast.xml into public/ and `vercel --prod`
#
# Usage:  ASC_ISSUER_ID=<uuid> ./Scripts/finalize-release.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/Harness.app"
DMG="$ROOT/Harness.dmg"
TAG="${TAG:-v1.0.0}"
REPO="${REPO:-robzilla1738/harness-cli}"

[[ -d "$APP" ]] || { echo "Harness.app missing — run build-release.sh + sign-and-notarize.sh + create-dmg.sh first." >&2; exit 1; }
[[ -f "$DMG" ]] || { echo "Harness.dmg missing — run create-dmg.sh first." >&2; exit 1; }

# Build the notarytool auth args from whichever credential set is present.
NOTARY_AUTH=()
if [[ -n "${ASC_ISSUER_ID:-}" ]]; then
  KEY_ID="${ASC_KEY_ID:-53WA44Z689}"
  KEY="${ASC_KEY:-$HOME/Downloads/AuthKey_${KEY_ID}.p8}"
  [[ -f "$KEY" ]] || { echo "API key not found: $KEY" >&2; exit 1; }
  NOTARY_AUTH=(--key "$KEY" --key-id "$KEY_ID" --issuer "$ASC_ISSUER_ID")
  echo "Notarizing with App Store Connect API key $KEY_ID (issuer $ASC_ISSUER_ID)."
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  NOTARY_AUTH=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD")
  echo "Notarizing with Apple ID $APPLE_ID (team $APPLE_TEAM_ID)."
else
  cat >&2 <<'MSG'
No notarization credentials. Set EITHER:
  ASC_ISSUER_ID=<issuer-uuid>  [ASC_KEY_ID=…] [ASC_KEY=…]      (App Store Connect API key)
or:
  APPLE_ID=…  APPLE_TEAM_ID=9F2JXY8TCK  APPLE_APP_PASSWORD=…   (Apple ID app-specific password)
MSG
  exit 1
fi

echo "==> Submitting $DMG to the notary service (this can take a few minutes)…"
xcrun notarytool submit "$DMG" "${NOTARY_AUTH[@]}" --wait

echo "==> Stapling the ticket onto the app and the DMG…"
xcrun stapler staple "$APP"
# Rebuild the DMG so it carries the freshly-stapled app, then staple the DMG itself.
"$ROOT/Scripts/create-dmg.sh"
codesign --force --sign "Developer ID Application: Robert Courson (9F2JXY8TCK)" --timestamp "$DMG"
xcrun stapler staple "$DMG"
echo "==> Verifying Gatekeeper acceptance…"
spctl -a -t open --context context:primary-signature -v "$DMG" 2>&1 | sed 's/^/    /' || true
xcrun stapler validate "$DMG" && echo "    DMG ticket stapled + valid."

echo "==> Re-uploading the notarized DMG to GitHub release $TAG…"
gh release upload "$TAG" "$DMG" --clobber --repo "$REPO"

echo "==> Generating the Sparkle appcast (a keychain 'Allow' prompt may appear — approve it)…"
mkdir -p "$ROOT/dist"
cp "$DMG" "$ROOT/dist/Harness.dmg"
"$ROOT/Scripts/generate-appcast.sh" "$ROOT/dist"

if [[ "${DEPLOY_WEBSITE:-0}" == "1" ]]; then
  WEBSITE_DIR="${WEBSITE_DIR:-$HOME/Code/harness-website}"
  if [[ -d "$WEBSITE_DIR" && -f "$ROOT/dist/appcast.xml" ]]; then
    echo "==> Deploying appcast.xml to the website ($WEBSITE_DIR)…"
    mkdir -p "$WEBSITE_DIR/public"
    cp "$ROOT/dist/appcast.xml" "$WEBSITE_DIR/public/appcast.xml"
    ( cd "$WEBSITE_DIR" && vercel --prod --yes )
    echo "    appcast live at https://harnesscli.dev/appcast.xml — Sparkle auto-update is now wired."
  else
    echo "    Skipped website deploy (set WEBSITE_DIR and ensure dist/appcast.xml exists)." >&2
  fi
else
  echo "==> appcast at dist/appcast.xml. Deploy it: copy to the website's public/appcast.xml and \`vercel --prod\`,"
  echo "    or re-run with DEPLOY_WEBSITE=1. SUFeedURL (https://harnesscli.dev/appcast.xml) then resolves."
fi

echo "Done. Notarized DMG on release $TAG; appcast generated."
