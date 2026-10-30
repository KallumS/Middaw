#!/bin/bash
# Build Middaw.app for Apple silicon:
#   mac/scripts/bundle.sh            -> mac/build/Middaw.app
# Release build of the Swift package, the family's engines and the composer
# as resources, the icon, and an ad-hoc signature (enough to run on the Mac
# that built it, or after right-click > Open on another).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MAC="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$MAC/.." && pwd)"
OUT="$MAC/build"
APP="$OUT/Middaw.app"
VERSION="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)"

cd "$MAC"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/Middaw"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/composer"
cp "$BIN" "$APP/Contents/MacOS/Middaw"
# The family's Lua and JSFX, the runtimes that run them, and the composer.
cp -R "$ROOT/runtime" "$ROOT/family" "$APP/Contents/Resources/"
cp -R "$ROOT/middaw" "$APP/Contents/Resources/composer/"
mkdir -p "$APP/Contents/Resources/composer/data"
cp -R "$ROOT/data/vocab" "$APP/Contents/Resources/composer/data/"
[ -d "$ROOT/data/corpus" ] && cp -R "$ROOT/data/corpus" "$APP/Contents/Resources/composer/data/" || true
find "$APP/Contents/Resources" -name "__pycache__" -type d -prune -exec rm -rf {} +

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Middaw</string>
  <key>CFBundleDisplayName</key><string>Middaw</string>
  <key>CFBundleIdentifier</key><string>com.kallums.middaw</string>
  <key>CFBundleExecutable</key><string>Middaw</string>
  <key>CFBundleIconFile</key><string>Middaw</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSArchitecturePriority</key><array><string>arm64</string></array>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Middaw Song</string>
      <key>CFBundleTypeRole</key><string>Editor</string>
      <key>LSHandlerRank</key><string>Owner</string>
      <key>LSItemContentTypes</key><array><string>com.kallums.middaw.song</string></array>
    </dict>
    <dict>
      <key>CFBundleTypeName</key><string>MIDI File</string>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>LSHandlerRank</key><string>Alternate</string>
      <key>LSItemContentTypes</key><array><string>public.midi-audio</string></array>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key><string>com.kallums.middaw.song</string>
      <key>UTTypeDescription</key><string>Middaw Song</string>
      <key>UTTypeConformsTo</key><array><string>public.json</string></array>
      <key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>middaw</string></array></dict>
    </dict>
  </array>
</dict>
</plist>
PLIST

TMP="$(mktemp -d)"
python3 "$HERE/icon.py" "$TMP/icon.png" 1024
SET="$TMP/Middaw.iconset"; mkdir "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$APP/Contents/Resources/Middaw.icns"
rm -rf "$TMP"

codesign --force --deep --sign - "$APP"
echo "Made $APP"
