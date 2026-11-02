#!/bin/bash
set -euo pipefail
source "$(dirname -- "$0")/scripts/lib/common.sh"
source "$PROJECT_ROOT/scripts/lib/build.sh"
case "${1:-}" in
    --help|-h) echo 'Usage: bash build.command [--build-only]'; exit 0 ;;
    ''|--build-only) [[ $# -le 1 ]] || fail 'Too many arguments.' ;;
    *) fail 'Usage: bash build.command [--build-only]' ;;
esac
require_macos
build_app
if [[ "${1:-}" != --build-only ]]; then
    /usr/bin/killall -TERM "$APP_EXECUTABLE" 2>/dev/null || true
    open -n "$APP"
fi
