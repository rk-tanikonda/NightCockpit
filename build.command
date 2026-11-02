#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Build this project on your Mac (macOS 13 or newer).'
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Apple Command Line Tools are required. Run: xcode-select --install'
  echo 'After installation finishes, run this file again.'
  exit 1
fi
APP="$PWD/dist/Night Cockpit.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Use the host architecture; no Swift packages or third-party dependencies.
xcrun swiftc -swift-version 5 -O -whole-module-optimization \
  -target "$(uname -m)-apple-macosx13.0" \
  -framework AppKit -framework AVFoundation -framework QuartzCore \
  -framework UniformTypeIdentifiers -framework WebKit \
  Sources/main.swift Sources/App/*.swift Sources/Playback/*.swift Sources/UI/*.swift Sources/Support/*.swift Sources/LockScreen/*.swift -o "$APP/Contents/MacOS/NightCockpit"
cp Info.plist "$APP/Contents/Info.plist"
cp Sources/Resources/stream-player.html "$APP/Contents/Resources/stream-player.html"
if [[ -f wallpaper.local.json ]]; then
  cp wallpaper.local.json "$APP/Contents/Resources/wallpaper.local.json"
else
  rm -f "$APP/Contents/Resources/wallpaper.local.json"
fi
if [[ -s Videos/night-cockpit.mp4 ]]; then
  cp Videos/night-cockpit.mp4 "$APP/Contents/Resources/night-cockpit.mp4"
fi
if [[ -x .build/lockscreen-tool ]]; then
  cp .build/lockscreen-tool "$APP/Contents/Resources/lockscreen-tool"
fi
if [[ -d LICENSES ]]; then
  /usr/bin/ditto LICENSES "$APP/Contents/Resources/LICENSES"
fi
/usr/bin/codesign --force --deep --sign - "$APP"
echo "Built: $APP"
if [[ "${1:-}" != '--build-only' ]]; then
  # An existing menu-bar instance otherwise keeps running the previous build.
  /usr/bin/killall -TERM NightCockpit 2>/dev/null || true
  open -n "$APP"
  echo 'A controls window will show preview download/playback status. The menu-bar icon also offers controls.'
fi
