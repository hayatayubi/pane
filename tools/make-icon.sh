#!/bin/bash
# Regenerates Resources/Pane.icns from scratch using IconGen.swift.
# Run from repo root or from tools/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PNG="/tmp/pane-icon-1024.png"
ICONSET="/tmp/Pane.iconset"
OUT="$ROOT/Resources/Pane.icns"

mkdir -p "$ROOT/Resources"

echo "→ Rendering icon PNG…"
swift "$ROOT/tools/IconGen.swift" "$PNG"

echo "→ Building iconset…"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -z 16 16     "$PNG" --out "$ICONSET/icon_16x16.png"     >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_16x16@2x.png"  >/dev/null
sips -z 32 32     "$PNG" --out "$ICONSET/icon_32x32.png"     >/dev/null
sips -z 64 64     "$PNG" --out "$ICONSET/icon_32x32@2x.png"  >/dev/null
sips -z 128 128   "$PNG" --out "$ICONSET/icon_128x128.png"   >/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_128x128@2x.png">/dev/null
sips -z 256 256   "$PNG" --out "$ICONSET/icon_256x256.png"   >/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_256x256@2x.png">/dev/null
sips -z 512 512   "$PNG" --out "$ICONSET/icon_512x512.png"   >/dev/null
cp "$PNG" "$ICONSET/icon_512x512@2x.png"

echo "→ Generating .icns…"
iconutil -c icns "$ICONSET" -o "$OUT"

echo "✓ Wrote $OUT"
