#!/bin/zsh
# Builds build/nxpaper.app (native arm64 by default).
#   --universal  arm64 + x86_64 binary (used for releases)
#   --install    copies it to /Applications (or ~/Applications) and (re)launches it
set -euo pipefail
cd "${0:A:h}/.."

UNIVERSAL=0
INSTALL=0
for arg in "$@"; do
  case $arg in
    --universal) UNIVERSAL=1 ;;
    --install) INSTALL=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

APP=build/nxpaper.app
rm -rf "$APP" build/slices
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/slices

if (( UNIVERSAL )); then
  for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macos14" -o "build/slices/nxpaper-$arch" Sources/*.swift
  done
  lipo -create build/slices/nxpaper-arm64 build/slices/nxpaper-x86_64 -output "$APP/Contents/MacOS/nxpaper"
else
  swiftc -O -target arm64-apple-macos14 -o "$APP/Contents/MacOS/nxpaper" Sources/*.swift
fi
rm -rf build/slices

cp -R Resources/wallpapers Resources/Fonts "$APP/Contents/Resources/"

# Liquid Glass icon (Assets.car) for macOS 26+, plus the AppIcon.icns fallback for older systems.
xcrun actool Resources/AppIcon.icon --compile "$APP/Contents/Resources" --platform macosx \
  --minimum-deployment-target 14.0 --app-icon AppIcon \
  --output-partial-info-plist "$(mktemp)" --output-format human-readable-text --errors --warnings >/dev/null

# 1.2.0 from the latest v1.2.0 tag; the build number is the commit count.
VERSION="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || echo v0.0.0)"
VERSION="${VERSION#v}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.noyex.nxpaper</string>
  <key>CFBundleName</key><string>nxpaper</string>
  <key>CFBundleDisplayName</key><string>nxpaper</string>
  <key>CFBundleExecutable</key><string>nxpaper</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if (( INSTALL )); then
  if pgrep -x nxpaper >/dev/null; then
    osascript -e 'quit app "nxpaper"' 2>/dev/null || pkill -x nxpaper || true
    for _ in {1..30}; do pgrep -x nxpaper >/dev/null || break; sleep 0.1; done
  fi
  # /Applications when we can write to it, otherwise ~/Applications.
  DEST=/Applications
  if [[ -e "$DEST/nxpaper.app" && ! -w "$DEST/nxpaper.app" ]] || [[ ! -w "$DEST" ]]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
  fi
  rm -rf "$DEST/nxpaper.app"
  cp -R "$APP" "$DEST/nxpaper.app"
  open "$DEST/nxpaper.app"
  echo "Installed $DEST/nxpaper.app"
fi
