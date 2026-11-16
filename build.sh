#!/bin/zsh
# Builds nxpaper.app and installs it to ~/Applications.
set -euo pipefail
cd "${0:A:h}"

APP=build/nxpaper.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -target arm64-apple-macos14 -o "$APP/Contents/MacOS/nxpaper" Sources/*.swift
cp -R Resources/wallpapers Resources/Fonts "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>nxpaper</string>
  <key>CFBundleIdentifier</key><string>com.noyex.nxpaper</string>
  <key>CFBundleExecutable</key><string>nxpaper</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

if pkill -x nxpaper 2>/dev/null; then
  for _ in {1..50}; do pgrep -x nxpaper >/dev/null || break; sleep 0.1; done
fi
mkdir -p ~/Applications
rm -rf ~/Applications/nxpaper.app
cp -R "$APP" ~/Applications/
open ~/Applications/nxpaper.app
echo "Installed ~/Applications/nxpaper.app"
