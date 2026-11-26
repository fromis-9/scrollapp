#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="${SCROLLAPP_BUILD_DIR:-$project_dir/build/universal}"
mkdir -p "$build_dir"
build_dir="$(cd "$build_dir" && pwd)"

# Build every executable in the app bundle for both architectures.
xcodebuild -project "$project_dir/Scrollapp.xcodeproj" -scheme Scrollapp -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$build_dir/DerivedData" \
    "CONFIGURATION_BUILD_DIR=$build_dir" 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO "$@" build

app="$build_dir/Scrollapp.app"
for executable in \
    "$app/Contents/MacOS/Scrollapp" \
    "$app/Contents/Library/LoginItems/ScrollappLoginHelper.app/Contents/MacOS/ScrollappLoginHelper"; do
    lipo "$executable" -verify_arch arm64 x86_64
    # Inspect the full binary, including the symbol table, without printing any matched paths.
    if LC_ALL=C /usr/bin/grep -aEq '/Users/[^/[:cntrl:]]+/' "$executable"; then
        printf 'Local home-folder path found in %s. Check the Release stripping settings.\n' "${executable##*/}" >&2
        exit 1
    fi
done
printf 'Universal app: %s\n' "$app"
