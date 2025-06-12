# Scrollapp Build Instructions

## Quick Build & Release

### Option 1: Command Line Build (Recommended)
```bash
# 1. Build universal binary
./scripts/build_universal.sh

# 2. Create distribution DMG  
./scripts/create_dmg_from_app.sh build/universal/Scrollapp.app
```

### Option 2: Xcode Archive Build
```bash
# 1. In Xcode: Product → Archive → Distribute App → Copy App
# 2. Create DMG from exported app
./scripts/create_dmg_from_app.sh /path/to/exported/Scrollapp.app
```

## Build Scripts

### scripts/build_universal.sh
- **Purpose**: Builds universal binary supporting Intel + Apple Silicon
- **Output**: `build/universal/Scrollapp.app`
- **Features**: Clean build, architecture verification, native performance

### scripts/create_dmg_from_app.sh
- **Purpose**: Creates professional DMG from any Scrollapp.app
- **Input**: Path to `.app` bundle
- **Output**: `Scrollapp-v1.0-Xcode.dmg`
- **Features**: Installation instructions, technical info, proper compression

## Testing Intel Compatibility

```bash
# Test Intel slice on Apple Silicon Mac
arch -x86_64 open build/universal/Scrollapp.app

# Verify universal binary
file build/universal/Scrollapp.app/Contents/MacOS/Scrollapp
```

## Release Workflow

1. **Build**: `./scripts/build_universal.sh`
2. **Package**: `./scripts/create_dmg_from_app.sh build/universal/Scrollapp.app`  
3. **Test**: Install DMG and verify functionality
4. **Distribute**: Upload DMG to GitHub releases

## Why Universal Binary?

- **Single download** for all Mac users
- **Native performance** on both Intel and Apple Silicon
- **Future-proof** architecture support
- **Industry standard** approach

## Requirements

- **Xcode 12.2+** for universal binary support
- **macOS 11.0+** deployment target  
- **Code signing** (development certificate sufficient) 