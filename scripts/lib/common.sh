#!/bin/bash
# Shared paths and preflight checks. Sourcing this file never changes the system.
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
APP_NAME='Night Cockpit'
APP_EXECUTABLE='NightCockpit'
BUILD_DIR="$PROJECT_ROOT/.build"
APP="$PROJECT_ROOT/dist/$APP_NAME.app"
SERVICE_APP="$HOME/Applications/$APP_NAME.app"
SERVICE_LOGS="$HOME/Library/Logs/NightCockpit"
LOCK_BACKUP="$HOME/Library/Application Support/NightCockpit/LockScreenBackup"

fail() { echo "Error: $*" >&2; exit 1; }

require_macos() {
    [[ "$(uname -s)" == Darwin ]] || fail 'Night Cockpit requires macOS 13 or newer.'
    [[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ]] || fail 'macOS 13 or newer is required.'
    BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PROJECT_ROOT/Info.plist")"
    SERVICE_LABEL="$BUNDLE_ID.agent"
    SERVICE_DOMAIN="gui/$(id -u)"
    SERVICE_PLIST="$HOME/Library/LaunchAgents/$SERVICE_LABEL.plist"
}

require_swift() {
    xcrun --find swiftc >/dev/null 2>&1 || fail 'Install Apple Command Line Tools with: xcode-select --install. Then run this command again.'
    mkdir -p "$BUILD_DIR/module-cache"
    # Keep compiler caches with build output, including in sandboxed/CI builds.
    export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"
}

require_lock_screen() {
    [[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 26 ]] || fail 'Native Lock Screen setup requires macOS 26+. Use bash setup.command for desktop playback.'
}

# Resolve relative input against the caller's directory, before any script cd.
resolve_video() {
    local candidate="${1:-}"
    if [[ -z "$candidate" ]]; then
        candidate="$(defaults read "$BUNDLE_ID" videoPath 2>/dev/null || true)"
    fi
    if [[ -z "$candidate" && -s "$PROJECT_ROOT/Videos/wallpaper.mp4" ]]; then
        candidate="$PROJECT_ROOT/Videos/wallpaper.mp4"
    fi
    [[ -n "$candidate" ]] || fail 'Choose a video in the app first, or pass --video /path/to/video.mp4.'
    [[ -f "$candidate" && -r "$candidate" && -s "$candidate" ]] || fail "Video is missing, empty, or unreadable: $candidate"
    VIDEO_PATH="$(cd -- "$(dirname -- "$candidate")" && pwd -P)/$(basename -- "$candidate")"
}
