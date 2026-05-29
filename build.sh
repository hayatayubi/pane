#!/bin/bash
set -euo pipefail

APP_NAME="Pane"
BUNDLE_ID="com.local.pane"
CONFIG="release"

cd "$(dirname "$0")"

echo "→ Building $APP_NAME ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH=$(swift build -c "$CONFIG" --show-bin-path)
APP_DIR="$BIN_PATH/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS"
cp "$BIN_PATH/$APP_NAME" "$MACOS/$APP_NAME"

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Pane needs Accessibility access to move and resize windows from other apps.</string>
    <key>NSHumanReadableCopyright</key><string>Pane</string>
</dict>
</plist>
EOF

# Ad-hoc codesign so the Accessibility grant persists across rebuilds
# (without a stable signature, macOS re-prompts every run).
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "✓ Built $APP_DIR"
echo "Run:    open \"$APP_DIR\""
