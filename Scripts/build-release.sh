#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Resolving dependencies..."
swift package resolve

# SwiftPM does not reliably remove resource bundles left in a restored .build cache after a
# target stops declaring resources. Clear them before building so package-app.sh can only copy
# bundles produced by the current package graph.
rm -rf "$ROOT/.build/release"/*.bundle

echo "Building release binaries..."
swift build -c release --product Harness
swift build -c release --product HarnessDaemon
swift build -c release --product harness-cli

echo "Packaging Harness.app..."
"$ROOT/Scripts/package-app.sh" release

echo "Done. App bundle: $ROOT/Harness.app"
