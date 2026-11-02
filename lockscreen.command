#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if [[ "$(uname -s)" != Darwin ]]; then echo 'This tool requires macOS.' >&2; exit 1; fi
mkdir -p .build
xcrun swiftc -swift-version 5 -parse-as-library Tools/LockScreenModel.swift Tests/LockScreenFixtures.swift -o .build/lockscreen-model-tests
.build/lockscreen-model-tests
xcrun swiftc -swift-version 5 -parse-as-library -framework AppKit -framework AVFoundation \
  Tools/LockScreenModel.swift Tools/LockScreenSetup.swift -o .build/lockscreen-tool
case "${1:-status}" in
  install)
    .build/lockscreen-tool install "${2:-$PWD/Videos/night-cockpit.mp4}"
    defaults write local.ramakrishna.nightcockpit lockScreenAudio -bool true
    ;;
  restore)
    .build/lockscreen-tool restore
    defaults write local.ramakrishna.nightcockpit lockScreenAudio -bool false
    /bin/launchctl kickstart -k "gui/$(id -u)/local.ramakrishna.nightcockpit.agent" 2>/dev/null || true
    ;;
  status) .build/lockscreen-tool status ;;
  *) echo 'Usage: bash lockscreen.command install [local-video]|restore|status' >&2; exit 2 ;;
esac
