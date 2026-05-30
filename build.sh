#!/bin/bash
set -euo pipefail

APP_NAME="Pane"
BUNDLE_ID="com.local.pane"
CONFIG="release"

# Parse flags. `--release` switches to ad-hoc signing and produces a
# distributable .zip in dist/ for uploading to GitHub Releases.
RELEASE_MODE=0
for arg in "$@"; do
    case "$arg" in
        --release|-r) RELEASE_MODE=1 ;;
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done

# Code-signing identity.
#
# Local dev build (default): use a real Apple Development / Developer ID cert
# if one is in the keychain. macOS keys the Accessibility grant off the
# certificate, so the grant survives every rebuild.
#
# Release build (--release): always ad-hoc ("-"). An Apple Development cert
# is *scoped to your dev team's machines* — using it on a release that other
# users download makes Gatekeeper reject the app harder ("damaged"). Ad-hoc
# signing gives them the normal "unidentified developer" prompt that they
# can bypass once with a right-click → Open or `xattr -dr com.apple.quarantine`.
if [ "$RELEASE_MODE" = "1" ]; then
    SIGN_IDENTITY="-"
else
    if [ -z "${SIGN_IDENTITY:-}" ]; then
        # Match by SHA-1 hash, not display name — Apple Development certs from
        # Xcode often appear twice with identical names and would be ambiguous.
        SIGN_IDENTITY=$(security find-identity -p codesigning -v 2>/dev/null \
            | awk '/Apple Development|Developer ID Application|Pane Local/ {print $2; exit}')
    fi
    SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi

cd "$(dirname "$0")"

# Release builds produce a universal binary (arm64 + x86_64) so the same
# downloaded zip runs on both Apple Silicon and Intel Macs. Local dev builds
# stay single-arch for faster iteration.
if [ "$RELEASE_MODE" = "1" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
    echo "→ Building $APP_NAME ($CONFIG, universal arm64 + x86_64)…"
else
    ARCH_FLAGS=()
    echo "→ Building $APP_NAME ($CONFIG)…"
fi

swift build -c "$CONFIG" "${ARCH_FLAGS[@]}"

BIN_PATH=$(swift build -c "$CONFIG" "${ARCH_FLAGS[@]}" --show-bin-path)
APP_DIR="$BIN_PATH/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN_PATH/$APP_NAME" "$MACOS/$APP_NAME"

# Bundle the app icon if it's been generated.
if [ -f "Resources/$APP_NAME.icns" ]; then
    cp "Resources/$APP_NAME.icns" "$RESOURCES/$APP_NAME.icns"
fi

# Read version from VERSION file if present; otherwise default.
VERSION="0.1.0"
if [ -f "VERSION" ]; then
    VERSION=$(cat VERSION | tr -d '[:space:]')
fi

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Pane needs Accessibility access to move and resize windows from other apps.</string>
    <key>NSHumanReadableCopyright</key><string>Pane</string>
</dict>
</plist>
EOF

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
echo "✓ Built $APP_DIR  (signed: $SIGN_IDENTITY)"

if [ "$RELEASE_MODE" = "1" ]; then
    # Produce a distributable zip. Use `ditto` (not `zip`) so macOS metadata
    # — including the code signature — is preserved.
    DIST_DIR="dist"
    ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION.zip"
    mkdir -p "$DIST_DIR"
    rm -f "$ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
    echo "✓ Packaged $ZIP_PATH"
    echo ""
    echo "Next: gh release create v$VERSION \"$ZIP_PATH\" --title \"Pane v$VERSION\" --notes \"…\""
else
    # If the user has already installed Pane to /Applications, refresh that
    # copy so they can keep launching from Launchpad / Spotlight with the
    # latest build. First-time install must be done manually so we don't
    # surprise anyone by writing into /Applications behind their back.
    INSTALLED="/Applications/$APP_NAME.app"
    if [ -e "$INSTALLED" ]; then
        rm -rf "$INSTALLED"
        cp -R "$APP_DIR" "$INSTALLED"
        codesign --force --deep --sign "$SIGN_IDENTITY" "$INSTALLED" >/dev/null
        echo "✓ Refreshed $INSTALLED"
    fi
    echo "Run:    open \"$APP_DIR\""
fi
