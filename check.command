#!/bin/bash
# All checks are read-only with respect to wallpaper, preferences and launchd.
set -euo pipefail
source "$(dirname -- "$0")/scripts/lib/common.sh"
source "$PROJECT_ROOT/scripts/lib/build.sh"
case "${1:-}" in
    --help|-h) echo 'Usage: bash check.command'; exit 0 ;;
    '') ;;
    *) fail 'Usage: bash check.command' ;;
esac
cd "$PROJECT_ROOT"
for script in ./*.command scripts/lib/*.sh; do bash -n "$script"; done
if command -v node >/dev/null 2>&1; then
    node --test Tests/*.test.cjs
else
    echo 'Node.js 18+ is needed only to run the development tests.' >&2
    exit 1
fi
require_macos
build_model_tests
build_app
/usr/bin/codesign --verify --deep --strict "$APP"
test -f "$APP/Contents/Resources/stream-player.html"
echo 'Checks passed. The app was built without launching or changing system settings.'
