# Build Scripts

This directory contains the build automation scripts for Scrollapp.

## Scripts

### `build_universal.sh`
Builds a universal binary that works on both Intel and Apple Silicon Macs.

**Usage:**
```bash
./scripts/build_universal.sh
```

**Output:** `build/universal/Scrollapp.app`

### `create_dmg_from_app.sh`
Creates a distributable DMG file from a built Scrollapp.app.

**Usage:**
```bash
./scripts/create_dmg_from_app.sh /path/to/Scrollapp.app
```

**Output:** `Scrollapp-v1.0-Xcode.dmg`

## Quick Start

```bash
# Build universal app
./scripts/build_universal.sh

# Create DMG for distribution
./scripts/create_dmg_from_app.sh build/universal/Scrollapp.app
```

See the main [BUILD.md](../BUILD.md) for detailed instructions. 