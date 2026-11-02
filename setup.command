#!/bin/bash
set -euo pipefail
source "$(dirname -- "$0")/scripts/lib/common.sh"
usage() {
    echo 'Usage: bash setup.command [--video FILE] [--desktop-only|--lock-screen] [--allow-display-sleep]'
    echo 'Uses your chosen video, a saved video, or the bundled original demo.'
    echo 'macOS 26+: desktop + synchronized Lock Screen sound/video; macOS 13–15: desktop only.'
}
video=''
native_mode=auto
keep_awake=true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --video)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fail '--video requires a file path.'
            video="$2"; shift 2 ;;
        --lock-screen)
            [[ "$native_mode" != off ]] || fail '--desktop-only conflicts with --lock-screen.'
            native_mode=on; shift ;;
        --desktop-only)
            [[ "$native_mode" != on ]] || fail '--desktop-only conflicts with --lock-screen.'
            native_mode=off; shift ;;
        --allow-display-sleep) keep_awake=false; shift ;;
        *) usage >&2; fail "Unknown option: $1" ;;
    esac
done
require_macos
native=false
if [[ "$native_mode" == on ]]; then require_lock_screen; native=true
elif [[ "$native_mode" == auto && "$(sw_vers -productVersion | cut -d. -f1)" -ge 26 ]]; then native=true
fi
VIDEO_PATH=''
bundled=false
if [[ -n "$video" ]]; then
    resolve_video "$video"
else
    saved="$(defaults read "$BUNDLE_ID" videoPath 2>/dev/null || true)"
    if [[ -n "$saved" && -r "$saved" && -s "$saved" ]]; then
        resolve_video "$saved"
    elif [[ -s "$PROJECT_ROOT/Videos/wallpaper.mp4" ]]; then
        resolve_video "$PROJECT_ROOT/Videos/wallpaper.mp4"
        bundled=true
    fi
fi
if [[ -z "$VIDEO_PATH" ]]; then
    [[ "$native_mode" != on ]] || fail 'Pass --video FILE or restore the bundled Videos/wallpaper.mp4.'
    native=false
fi
# Build/install once, configure before the app starts repairing native settings,
# then launch. Fresh users never get a premature video chooser.
bash "$PROJECT_ROOT/build.command" --build-only
bash "$PROJECT_ROOT/service.command" prepare --use-build
if [[ "$bundled" == true ]]; then VIDEO_PATH="$SERVICE_APP/Contents/Resources/wallpaper.mp4"; fi
if [[ -n "$VIDEO_PATH" ]]; then defaults write "$BUNDLE_ID" videoPath -string "$VIDEO_PATH"; fi
lock_status=0
if [[ "$native" == true ]]; then
    bash "$PROJECT_ROOT/lockscreen.command" install "$VIDEO_PATH" --prepared || lock_status=$?
    if [[ "$lock_status" != 0 ]]; then defaults write "$BUNDLE_ID" nativeWallpaper -bool false; fi
else
    if [[ -f "$LOCK_BACKUP/Index.plist" && -x "$SERVICE_APP/Contents/Resources/lockscreen-tool" ]]; then
        "$SERVICE_APP/Contents/Resources/lockscreen-tool" restore
    fi
    defaults write "$BUNDLE_ID" nativeWallpaper -bool false
fi
if [[ "$native" == true && "$lock_status" == 0 ]]; then
    defaults write "$BUNDLE_ID" keepLockDisplayAwake -bool "$keep_awake"
fi
bash "$PROJECT_ROOT/service.command" activate
echo 'Night Cockpit installed. Desktop playback is muted. Use the menu-bar controls to change video or stop.'
if [[ "$lock_status" -ne 0 ]]; then
    echo 'Desktop started. Native Lock Screen setup failed; see the error above.' >&2
    exit "$lock_status"
fi
if [[ "$native" == true ]]; then
    echo 'Native Lock Screen video and synchronized sound configured. Test with Control-Command-Q.'
    if [[ "$keep_awake" == true ]]; then echo 'The display stays on while locked. Turn this off in the menu to save battery.'; fi
fi
