#!/bin/bash
set -e

APP_DIR="$HOME/Applications/Pulse.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Installing Pulse.app..."

# Ensure release binary exists
if [ ! -f ".build/release/Pulse" ]; then
    echo "No release binary found. Building..."
    swift build -c release
fi

# Create app bundle structure
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp .build/release/Pulse "$MACOS/Pulse"

# Copy icon if available
if [ -f "assets/AppIcon.icns" ]; then
    cp assets/AppIcon.icns "$RESOURCES/AppIcon.icns"
fi

# Write Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Pulse</string>
    <key>CFBundleIdentifier</key>
    <string>com.silas-maven.pulse</string>
    <key>CFBundleName</key>
    <string>Pulse</string>
    <key>CFBundleDisplayName</key>
    <string>Pulse</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_DIR" 2>/dev/null || true

echo ""
echo "Installed to $APP_DIR"
echo "Launch from Spotlight (Cmd+Space → 'Pulse') or:"
echo "  open ~/Applications/Pulse.app"
