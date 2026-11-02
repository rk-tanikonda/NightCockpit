#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if [[ ! -s Videos/night-cockpit.mp4 ]]; then
  echo 'The local 4K video is missing. Extract the complete offline ZIP before running setup.' >&2
  exit 1
fi
# The desktop always uses the bundled local file. No web page is required.
defaults delete local.ramakrishna.nightcockpit videoPath 2>/dev/null || true
defaults write local.ramakrishna.nightcockpit websiteMode -bool false
lock_status=0
bash lockscreen.command install || lock_status=$?
bash service.command start
if [[ "$lock_status" != 0 ]]; then
  echo 'Desktop started with the local video. Lock Screen setup did not succeed; see the error above.' >&2
  exit "$lock_status"
fi
echo 'Local desktop playback started. Native Lock Screen configuration and lock-only audio are enabled.'
echo 'Verify Lock Screen video and audio with Control-Command-Q. This integration is experimental.'
