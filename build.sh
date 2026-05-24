#!/bin/bash
set -e
cd "$(dirname "$0")"

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then TARGET="arm64-apple-macos13.0"
else TARGET="x86_64-apple-macos13.0"; fi

APP="Maximize.app"
RESOURCES="$APP/Contents/Resources"
ICONSET="Maximize.iconset"

echo "→ Building Maximize ($ARCH)..."
pkill -x Maximize 2>/dev/null || true
sleep 0.3
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$RESOURCES"
cp Info.plist "$APP/Contents/"

# ── Compile app ───────────────────────────────────────────────────────────────
xcrun swiftc -target "$TARGET" \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework ServiceManagement \
    -O \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/WindowManager.swift \
    -o "$APP/Contents/MacOS/Maximize"

# ── Generate icon ─────────────────────────────────────────────────────────────
echo "→ Generating icon..."
xcrun swift generate_icon.swift icon_1024.png

# Build iconset at all required sizes
rm -rf "$ICONSET"
mkdir "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size icon_1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
done
sips -z 32   32  icon_1024.png --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 64   64  icon_1024.png --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 256  256 icon_1024.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 512  512 icon_1024.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
cp icon_1024.png "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$RESOURCES/Maximize.icns"
rm -rf "$ICONSET" icon_1024.png

# ── Sign & launch ─────────────────────────────────────────────────────────────
codesign --sign - --force --deep "$APP"
echo "→ Build complete: $APP"
echo "→ Launching..."
open "$APP"
