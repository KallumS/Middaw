#!/bin/bash
# Make Middaw.app for this checkout:
#   tools/mac/make_app.sh               -> ~/Applications/Middaw.app
#   tools/mac/make_app.sh /Applications -> /Applications/Middaw.app
# The app opens Middaw from the folder it was made from, so make it again if
# that folder moves. Runs natively on Apple silicon: it is a script, and the
# work is done by Python and the browser.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
DEST="${1:-$HOME/Applications}"
APP="$DEST/Middaw.app"
PYTHON="${PYTHON:-python3}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
sed "s|__MIDDAW_ROOT__|$ROOT|" "$HERE/launcher.sh" > "$APP/Contents/MacOS/Middaw"
chmod +x "$APP/Contents/MacOS/Middaw"
VERSION="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo dev)"
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
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# The icon: drawn once at 1024, scaled by the Mac's own tools.
TMP="$(mktemp -d)"
"$PYTHON" "$HERE/icon.py" "$TMP/icon.png" 1024
if command -v iconutil >/dev/null && command -v sips >/dev/null; then
  SET="$TMP/Middaw.iconset"; mkdir "$SET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$SET" -o "$APP/Contents/Resources/Middaw.icns"
else
  cp "$TMP/icon.png" "$APP/Contents/Resources/Middaw.png"   # not on a Mac: kept for inspection
fi
rm -rf "$TMP"
touch "$APP"   # so Finder notices the new icon
echo "Made $APP"
