#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    printf 'Usage: %s /path/to/Scrollapp.app\n' "$0" >&2
    exit 1
fi

app="$1"
if [ ! -f "$app/Contents/MacOS/Scrollapp" ]; then
    printf 'Scrollapp executable not found in %s\n' "$app" >&2
    exit 1
fi

version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    printf 'Invalid app version: %s\n' "$version" >&2
    exit 1
fi

filename="Scrollapp-v${version}-Xcode.dmg"
work_dir=$(mktemp -d "$PWD/.scrollapp-dmg.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT
payload="$work_dir/payload"
mkdir "$payload"

staged_app="$payload/Scrollapp.app"
cp -R "$app" "$staged_app"

# Sign nested code first so the login helper retains its own bundle identifier.
login_helper="$staged_app/Contents/Library/LoginItems/ScrollappLoginHelper.app"
if [ -d "$login_helper" ]; then
    codesign --force --sign - --timestamp=none "$login_helper"
fi
codesign --force --sign - --timestamp=none "$staged_app"
codesign --verify --strict --deep "$staged_app"
ln -s /Applications "$payload/Applications"

size=$(du -sm "$payload" | cut -f1)
hdiutil create -srcfolder "$payload" -volname "Scrollapp" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDZO -size "$((size + 20))m" -imagekey zlib-level=9 \
    "$work_dir/$filename"

mv -f "$work_dir/$filename" "$PWD/$filename"
printf 'Created %s\n' "$filename"
