#!/usr/bin/env bash
# Workaround for an Xcode 27 beta SwiftPM bug: XCTest bundles built via
# `DEVELOPER_DIR=/Applications/Xcode-beta.app/... swift test` fail to launch with
#   dlopen: Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle
# even though swift build/swift test itself succeeds.
#
# Root cause: the built xctest binaries carry an LC_RPATH entry pointing at
# `.build/out/Products/Debug/PackageFrameworks`, but SwiftPM's newer
# XCBuild-integrated layout (the `.build/out/Products/...` tree Xcode 27 beta
# uses, vs. the classic `.build/<triple>/debug/` layout) never copies or
# symlinks the Sparkle.xcframework binary into that directory — it only lands
# one level up, directly in `.build/out/Products/Debug/Sparkle.framework`.
# `otool -l` on the KouenAppTests binary confirms none of its baked-in rpaths
# (`/usr/lib/swift`, `@loader_path`, `@loader_path/Frameworks`,
# `@loader_path/../Frameworks`, the toolchain lib dir) resolve to where the
# framework actually sits either.
#
# Fix: symlink it into the directory the rpath already expects. Re-run this
# after any `swift build`/`swift test` under the beta toolchain that recreates
# `.build/out/` from scratch — the directory (and this symlink) don't survive
# a clean build. Tracked in agent-memory/plans/p8-macos27-adoption.md Phase 1;
# drop this script once Xcode 27 ships a fixed SwiftPM/XCBuild integration.
#
# Usage: Scripts/fix-xcode27beta-test-rpath.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/.build/out/Products/Debug/PackageFrameworks"
TARGET="../Sparkle.framework"

if [[ ! -d "$ROOT/.build/out/Products/Debug/Sparkle.framework" ]]; then
  echo "Sparkle.framework not found under .build/out/Products/Debug — build with" >&2
  echo "the Xcode 27 beta toolchain first (DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build)." >&2
  exit 1
fi

mkdir -p "$DIR"
ln -sfn "$TARGET" "$DIR/Sparkle.framework"
echo "✅ Symlinked $DIR/Sparkle.framework -> $TARGET"
