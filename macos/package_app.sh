#!/bin/bash

APP_NAME="QuickNotes"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
EXECUTABLE="$APP_NAME"

# 1. Clean and Build
echo "Cleaning..."
swift package clean

echo "Building Release..."
swift build -c release

# 2. Create App Bundle Structure
echo "Creating App Bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy Executable
cp "$BUILD_DIR/$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/"

# 4. Copy Icon (if exists)
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# 5. Copy Info.plist (Preserve usage keys)
echo "Copying Info.plist..."
if [ -f "Info.plist" ]; then
    cp "Info.plist" "$APP_BUNDLE/Contents/Info.plist"
else
    echo "Error: Info.plist not found! Please create it first."
    exit 1
fi

# 6. Apply Entitlements & Sign
echo "Signing with Entitlements..."
# Self-sign with entitlements
codesign --force --deep --sign - --entitlements QuickNotes.entitlements "$APP_BUNDLE"

# 7. Prepare DMG Content (App + /Applications Link)
echo "Preparing DMG Content..."
rm -rf "Packaging"
mkdir -p "Packaging"
cp -R "$APP_BUNDLE" "Packaging/"
ln -s /Applications "Packaging/Applications"

# 8. Create DMG
echo "Creating DMG..."
rm -f "$APP_NAME.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "Packaging" -ov -format UDZO "$APP_NAME.dmg"

# 9. Move to Output
echo "Moving to Output..."
mkdir -p "Output"
mv "$APP_NAME.dmg" "Output/"

# Cleanup
rm -rf "Packaging"

echo "App Bundle created: $APP_BUNDLE"
echo "DMG created: Output/$APP_NAME.dmg"
echo "To install: Open output DMG and drag to Applications."
