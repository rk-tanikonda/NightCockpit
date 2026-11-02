#!/bin/bash
set -euo pipefail
source "$(dirname -- "$0")/scripts/lib/common.sh"
source "$PROJECT_ROOT/scripts/lib/build.sh"
usage() { echo 'Usage: bash lockscreen.command install [local-video]|restore|status'; }
case "${1:-status}" in
    --help|-h) usage; exit 0 ;;
    install) [[ $# -le 2 ]] || fail 'Too many arguments.' ;;
    restore|status) [[ $# -le 1 ]] || fail 'Too many arguments.' ;;
    *) usage >&2; exit 2 ;;
esac
require_macos
require_lock_screen
if [[ "${1:-status}" == install ]]; then resolve_video "${2:-}"; fi
build_model_tests
build_lock_tool
case "${1:-status}" in
    install)
        "$BUILD_DIR/lockscreen-tool" install "$VIDEO_PATH"
        defaults write "$BUNDLE_ID" videoPath -string "$VIDEO_PATH"
        defaults write "$BUNDLE_ID" websiteMode -bool false
        defaults write "$BUNDLE_ID" lockScreenAudio -bool true
        ;;
    restore)
        "$BUILD_DIR/lockscreen-tool" restore
        defaults write "$BUNDLE_ID" lockScreenAudio -bool false
        /bin/launchctl kickstart -k "$SERVICE_DOMAIN/$SERVICE_LABEL" 2>/dev/null || true
        ;;
    status) "$BUILD_DIR/lockscreen-tool" status ;;
esac
