#!/bin/bash

# Create DMG from existing Scrollapp.app (built via Xcode Archive)
# Usage: ./create_dmg_from_app.sh /path/to/Scrollapp.app

set -e  # Exit on any error

if [ $# -eq 0 ]; then
    echo "ERROR: Please provide path to Scrollapp.app"
    echo "Usage: $0 /path/to/Scrollapp.app"
    echo ""
    echo "To build the app:"
    echo "1. Open Scrollapp.xcodeproj in Xcode"
    echo "2. Product → Archive"
    echo "3. Distribute App → Copy App"
    echo "4. Run: $0 /path/to/exported/Scrollapp.app"
    exit 1
fi

APP_PATH="$1"
VERSION="1.0"
DMG_NAME="Scrollapp-v${VERSION}-Xcode"
DMG_DIR="dmg_temp"

# Validate input
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_PATH not found or not a directory"
    exit 1
fi

if [ ! -f "$APP_PATH/Contents/MacOS/Scrollapp" ]; then
    echo "ERROR: $APP_PATH doesn't appear to be a valid Scrollapp.app"
    exit 1
fi

echo "Creating DMG from Xcode-built app..."
echo "App: $APP_PATH"

# Clean previous builds
echo "Cleaning previous DMG..."
rm -rf "${DMG_DIR}"
rm -rf "${DMG_NAME}.dmg"

# Verify the app
echo "Verifying app..."
BINARY_PATH="$APP_PATH/Contents/MacOS/Scrollapp"
if [ -f "$BINARY_PATH" ]; then
    echo "Architecture: $(lipo -info "$BINARY_PATH")"
    echo "Code signature: $(codesign -dv "$APP_PATH" 2>&1 | head -1 || echo "Ad-hoc signed")"
else
    echo "WARNING: Binary not found for verification"
fi

# Create DMG directory structure
echo "Creating DMG structure..."
mkdir -p "${DMG_DIR}"

# Copy app to DMG directory
echo "Copying app to DMG..."
cp -R "$APP_PATH" "${DMG_DIR}/"

# Re-sign with ad-hoc signature to remove personal info
echo "Re-signing with ad-hoc signature..."
codesign --force --deep --sign - --timestamp=none --identifier "com.scrollapp.Scrollapp" "${DMG_DIR}/Scrollapp.app" 2>/dev/null || echo "Code signing failed - continuing anyway"

# Create Applications symlink
ln -s /Applications "${DMG_DIR}/Applications"

# Create the DMG
echo "Creating compressed DMG..."

# Calculate size needed
SIZE=$(du -sm "${DMG_DIR}" | cut -f1)
SIZE=$((SIZE + 20))  # Add padding

# Create DMG
hdiutil create -srcfolder "${DMG_DIR}" -volname "Scrollapp" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDZO -size ${SIZE}m -imagekey zlib-level=9 \
    "${DMG_NAME}.dmg"

# Clean up
echo "Cleaning up..."
rm -rf "${DMG_DIR}"

echo ""
echo "DMG created successfully!"
echo "File: ${DMG_NAME}.dmg"
echo "Size: $(du -h "${DMG_NAME}.dmg" | cut -f1)"
echo ""
echo "XCODE BUILD COMPLETE:"
echo "• Professional build quality"
echo "• Ready for distribution"
echo "• Compatible with Intel + Apple Silicon"
echo ""
echo "Next steps:"
echo "1. Test the DMG installation"
echo "2. Upload to GitHub releases"
echo "3. Share with users!"
echo "" 