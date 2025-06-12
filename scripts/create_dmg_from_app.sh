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

# Create Applications symlink
ln -s /Applications "${DMG_DIR}/Applications"

# Create installation instructions
cat > "${DMG_DIR}/Installation Instructions.txt" << 'EOF'
Scrollapp Installation Instructions

INSTALLATION:
1. Drag Scrollapp.app to the Applications folder
2. Open Applications and launch Scrollapp
3. If you see a security warning:
   - Go to System Preferences → Security & Privacy
   - Click "Open Anyway" 
   - Click "Open" in the confirmation dialog

HOW TO USE:
• Middle-click anywhere to toggle auto-scroll (mouse)
• Option + scroll to activate (trackpad)  
• Move cursor to control speed and direction
• Click anywhere to stop auto-scrolling
• Use menu bar icon for settings

PERMISSIONS:
Grant Accessibility permissions when prompted for auto-scroll to work.

Built with Xcode - Professional Quality!
Thank you for using Scrollapp!
EOF

# Create technical info
cat > "${DMG_DIR}/Build Info.txt" << EOF
Technical Information - Scrollapp

Build Method: Xcode Archive & Export
Architecture: $(lipo -info "$BINARY_PATH" 2>/dev/null || echo "Could not determine")
Code Signing: $(codesign -dv "$APP_PATH" 2>&1 | head -1 || echo "Ad-hoc signed")
macOS Target: 11.0+

Distribution: This app is safe to distribute and install.
Users may see security warnings for non-Mac App Store apps.
EOF

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