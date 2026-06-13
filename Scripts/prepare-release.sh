#!/usr/bin/env bash
# Bump local release metadata only. This intentionally does not build, commit,
# push, tag, or dispatch the signed GitHub release workflow.
#
# Usage:
#   Scripts/prepare-release.sh
#   Scripts/prepare-release.sh patch|minor|major
#   Scripts/prepare-release.sh --version X.Y.Z [--build N]
#   Scripts/prepare-release.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

INFO_PLIST="Apps/Harness/Sources/HarnessApp/Resources/Info.plist"
HARNESS_VERSION_SWIFT="Packages/HarnessCore/Sources/HarnessCore/HarnessVersion.swift"
RELEASE_NOTES_SWIFT="Packages/HarnessCore/Sources/HarnessCore/ReleaseNotes/GeneratedReleaseNotes.swift"

plist_version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
plist_build="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
cl_version="$(grep -m1 -oE '^## \[[^]]+\]' CHANGELOG.md | sed -E 's/^## \[(.+)\]$/\1/')"
version=""
build=""
dry_run=0

usage() {
  cat <<'USAGE'
Usage:
  Scripts/prepare-release.sh [patch|minor|major] [options]

Options:
  --version X.Y.Z  Set an explicit marketing version.
  --build N        Set an explicit build number. Defaults to current build + 1.
  --dry-run        Print the planned metadata changes without editing files.
  -h, --help       Show this help.
USAGE
}

next_semver() {
  local kind="$1"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$plist_version"
  case "$kind" in
    patch) printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))" ;;
    minor) printf '%s.%s.0\n' "$major" "$((minor + 1))" ;;
    major) printf '%s.0.0\n' "$((major + 1))" ;;
    *) echo "Unknown version bump: $kind" >&2; exit 2 ;;
  esac
}

while (($#)); do
  case "$1" in
    patch|minor|major)
      version="$(next_semver "$1")"
      shift
      ;;
    --version)
      version="${2:?Missing value for --version}"
      shift 2
      ;;
    --build)
      build="${2:?Missing value for --build}"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

echo ""
echo "Info.plist version/build: $plist_version ($plist_build)"
echo "CHANGELOG.md top version:  $cl_version"
echo ""

if [[ -z "$version" ]]; then
  if [[ "$cl_version" != "Unreleased" && "$cl_version" != "$plist_version" ]]; then
    version="$cl_version"
  else
    IFS='.' read -r major minor patch <<< "$plist_version"
    next_patch="$major.$minor.$((patch + 1))"
    next_minor="$major.$((minor + 1)).0"
    next_major="$((major + 1)).0.0"
    if [[ ! -t 0 ]]; then
      version="$next_patch"
      echo "No TTY available; defaulting to patch bump ($plist_version -> $version)."
    else
      echo "Select version bump:"
      echo "  1) patch ($plist_version -> $next_patch)"
      echo "  2) minor ($plist_version -> $next_minor)"
      echo "  3) major ($plist_version -> $next_major)"
      read -rp "Enter choice [1]: " version_choice
      case "${version_choice:-1}" in
        1) version="$next_patch" ;;
        2) version="$next_minor" ;;
        3) version="$next_major" ;;
        *) echo "Invalid version choice" >&2; exit 1 ;;
      esac
    fi
  fi
fi

if [[ ! "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
  echo "Version must look like X.Y.Z: $version" >&2
  exit 2
fi

if [[ -z "$build" ]]; then
  next_build=$((plist_build + 1))
  if [[ -t 0 ]]; then
    read -rp "Build number for $version [$next_build]: " build_input
    build="${build_input:-$next_build}"
  else
    build="$next_build"
    echo "No TTY available; defaulting build number to $build."
  fi
fi

if [[ ! "$build" =~ ^[0-9]+$ ]]; then
  echo "Build must be numeric: $build" >&2
  exit 2
fi

echo ""
echo "Release metadata plan:"
echo "  version: $plist_version -> $version"
echo "  build:   $plist_build -> $build"
echo ""

run() {
  echo "+ $*"
  if [[ "$dry_run" == "0" ]]; then
    "$@"
  fi
}

run /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$INFO_PLIST"
run /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$INFO_PLIST"

if [[ "$dry_run" == "0" ]]; then
  tmp="$(mktemp)"
  sed -E \
    -e "s/public static let short = \"[^\"]+\"/public static let short = \"$version\"/" \
    -e "s/public static let build = [0-9]+/public static let build = $build/" \
    "$HARNESS_VERSION_SWIFT" > "$tmp"
  mv "$tmp" "$HARNESS_VERSION_SWIFT"
else
  echo "+ update $HARNESS_VERSION_SWIFT short=$version build=$build"
fi

if [[ "$cl_version" != "$version" ]]; then
  echo ""
  echo "CHANGELOG.md top entry is [$cl_version], not [$version]."
  if [[ "$dry_run" == "0" ]]; then
    echo "Prepending new release block to CHANGELOG.md..."
    date_str="$(date +%Y-%m-%d)"
    tmp_block="$(mktemp)"
    cat <<EOF > "$tmp_block"
## [$version] - $date_str

### Added
- Release version bump to v$version.
EOF
    tmp_cl="$(mktemp)"
    awk -v block_file="$tmp_block" '
      BEGIN { inserted = 0 }
      /^## \[/ && !inserted {
        while ((getline line < block_file) > 0) {
          print line
        }
        close(block_file)
        print ""
        inserted = 1
      }
      { print }
    ' CHANGELOG.md > "$tmp_cl"
    mv "$tmp_cl" CHANGELOG.md
    rm "$tmp_block"
    cl_version="$version"
  else
    echo "+ would prepend new release block to CHANGELOG.md for $version"
  fi
fi

echo ""
echo "Regenerating release notes from CHANGELOG.md [$version]..."
run make release-notes

echo ""
echo "Changed release files:"
git diff -- "$INFO_PLIST" "$HARNESS_VERSION_SWIFT" "$RELEASE_NOTES_SWIFT" CHANGELOG.md || true

echo ""
echo "Release metadata prepared. Next:"
echo "  Scripts/commit-push.sh"
echo "  make prod      # repo-root production build"
echo "  make install   # manual /Applications install only"
