#!/bin/bash
set -e

APP_NAME="Lookout"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."

# Clean previous build
rm -rf "$APP_BUNDLE"
rm -f "$BUILD_DIR/LookoutBinary"

# Compile
swiftc \
    -parse-as-library \
    -swift-version 5 \
    -framework AppKit \
    -framework SwiftUI \
    -framework ScreenCaptureKit \
    -target arm64-apple-macosx14.0 \
    -O \
    -o "$BUILD_DIR/LookoutBinary" \
    $(find "$BUILD_DIR/Lookout" -name "*.swift" -type f)

# Create .app bundle
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

mv "$BUILD_DIR/LookoutBinary" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
# Write resolved Info.plist (no Xcode variables)
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Lookout</string>
    <key>CFBundleIdentifier</key>
    <string>com.175g.lookout</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Lookout</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Lookout needs to see your screen so the AI can help you navigate your computer.</string>
</dict>
</plist>
PLIST

# Ad-hoc code sign
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Build successful!"
echo ""
echo "  $APP_BUNDLE"
echo ""
echo "To run:  open $APP_BUNDLE"
echo ""
echo "First time: macOS will ask for Screen Recording permission."
echo "Grant it in System Settings → Privacy & Security → Screen Recording."
echo ""
