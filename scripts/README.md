# Build Scripts

This directory contains the build automation scripts for Scrollapp.

## Scripts

### `build_universal.sh`
Builds a universal binary that works on both Intel and Apple Silicon Macs.
The build fails if Scrollapp or its login helper contains a local home-folder path.

**Usage:**
```bash
./scripts/build_universal.sh CODE_SIGNING_ALLOWED=NO
```

**Output:** `build/universal/Scrollapp.app`

For an Xcode-managed signed build, pass your team as `DEVELOPMENT_TEAM=YOUR_TEAM_ID` in place of `CODE_SIGNING_ALLOWED=NO`.

### `create_dmg_from_app.sh`
Creates an ad hoc signed DMG for local testing from a built Scrollapp.app.

**Usage:**
```bash
./scripts/create_dmg_from_app.sh /path/to/Scrollapp.app
```

**Output** uses the built app’s version, for example `Scrollapp-v1.3-Xcode.dmg`.

## Quick Start

```bash
# Build universal app
./scripts/build_universal.sh CODE_SIGNING_ALLOWED=NO

# Create a DMG for local testing
./scripts/create_dmg_from_app.sh build/universal/Scrollapp.app
```

For a public release, package the Developer ID-signed app with its signature intact, then notarize and staple the final DMG.
