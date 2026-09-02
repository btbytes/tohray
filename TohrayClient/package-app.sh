#!/bin/bash
# Package TohrayClient as a macOS .app bundle

set -e

echo "Building TohrayClient..."
swift build -c release

APP_NAME="TohrayClient"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Clean up old bundle
rm -rf "$APP_BUNDLE"

# Create app bundle structure
echo "Creating app bundle structure..."
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
echo "Copying binary..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS/"

# Copy icon, generating it first if it hasn't been rendered yet
ICON_SOURCE="Resources/AppIcon.icns"
if [ ! -f "$ICON_SOURCE" ]; then
    echo "Generating app icon..."
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    swift Scripts/generate-icon.swift "$ICONSET"
    mkdir -p Resources
    iconutil -c icns "$ICONSET" -o "$ICON_SOURCE"
fi
echo "Copying icon..."
cp "$ICON_SOURCE" "$RESOURCES/AppIcon.icns"

# Create Info.plist
echo "Creating Info.plist..."
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.tohray.client</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "$CONTENTS/PkgInfo"

echo ""
echo "✅ App bundle created successfully!"
echo "📦 Location: $(pwd)/$APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -r $APP_BUNDLE /Applications/"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
