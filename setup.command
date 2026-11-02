#!/bin/bash
set -euo pipefail
source "$(dirname -- "$0")/scripts/lib/common.sh"
usage() {
    echo 'Usage: bash setup.command [--video FILE] [--lock-screen]'
    echo 'Installs desktop playback and login startup. With no video, choose one in the app.'
    echo '--lock-screen also configures native wallpaper/screen saver and lock audio (macOS 26+).'
}
video=''
lock_screen=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --video)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fail '--video requires a file path.'
            video="$2"; shift 2 ;;
        --lock-screen) lock_screen=true; shift ;;
        *) usage >&2; fail "Unknown option: $1" ;;
    esac
done
require_macos
if [[ -n "$video" || "$lock_screen" == true ]]; then resolve_video "$video"; fi
if [[ "$lock_screen" == true ]]; then require_lock_screen; fi
# Build before changing preferences or wallpaper settings.
bash "$PROJECT_ROOT/build.command" --build-only
lock_status=0
if [[ "$lock_screen" == true ]]; then
    bash "$PROJECT_ROOT/lockscreen.command" install "$VIDEO_PATH" || lock_status=$?
fi
if [[ -n "$video" || "$lock_screen" == true ]]; then
    defaults write "$BUNDLE_ID" videoPath -string "$VIDEO_PATH"
fi
bash "$PROJECT_ROOT/service.command" start --use-build
if [[ "$lock_status" -ne 0 ]]; then
    echo 'Desktop started. Native Lock Screen setup failed; see the error above.' >&2
    exit "$lock_status"
fi
echo 'Night Cockpit installed. Use the menu-bar controls to choose a video or stop playback.'
if [[ "$lock_screen" == true ]]; then
    echo 'Native wallpaper and screen saver configured. Test with Control-Command-Q without moving the pointer.'
fi
