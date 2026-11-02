#!/bin/bash
set -euo pipefail
source "$(dirname -- "$0")/scripts/lib/common.sh"
source "$PROJECT_ROOT/scripts/lib/build.sh"
usage() { echo 'Usage: bash lockscreen.command install [local-video]|repair|restore|status'; }
case "${1:-status}" in
    --help|-h) usage; exit 0 ;;
    install) [[ $# -le 3 && ( $# -lt 3 || "$3" == --prepared ) ]] || fail 'Usage: bash lockscreen.command install [local-video]' ;;
    repair|restore|status) [[ $# -le 1 ]] || fail 'Too many arguments.' ;;
    *) usage >&2; exit 2 ;;
esac
require_macos
require_lock_screen
if [[ "${1:-status}" == install && "${3:-}" != --prepared ]]; then
    args=(--lock-screen)
    if [[ -n "${2:-}" ]]; then args+=(--video "$2"); fi
    exec bash "$PROJECT_ROOT/setup.command" "${args[@]}"
fi
case "${1:-status}" in
    install)
        resolve_video "${2:-}"
        "$SERVICE_APP/Contents/Resources/lockscreen-tool" synchronize "$VIDEO_PATH"
        defaults write "$BUNDLE_ID" nativeWallpaper -bool true
        ;;
    repair) build_lock_tool; "$BUILD_DIR/lockscreen-tool" repair ;;
    restore)
        build_lock_tool
        "$BUILD_DIR/lockscreen-tool" restore
        defaults write "$BUNDLE_ID" nativeWallpaper -bool false
        /bin/launchctl kickstart -k "$SERVICE_DOMAIN/$SERVICE_LABEL" 2>/dev/null || true
        ;;
    status) build_lock_tool; "$BUILD_DIR/lockscreen-tool" status ;;
esac
