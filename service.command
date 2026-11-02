#!/bin/bash
# Per-user service: no sudo, no system daemons, no sleep-setting changes.
set -euo pipefail
cd -- "$(dirname -- "$0")"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This service is for macOS only.' >&2
  exit 1
fi
SERVICE_LABEL='local.ramakrishna.nightcockpit.agent'
SERVICE_DOMAIN="gui/$(id -u)"
SERVICE_PLIST="$HOME/Library/LaunchAgents/$SERVICE_LABEL.plist"
SERVICE_APP="$HOME/Applications/Night Cockpit.app"
SERVICE_LOGS="$HOME/Library/Logs/NightCockpit"

stop_job() {
  if /bin/launchctl print "$SERVICE_DOMAIN/$SERVICE_LABEL" >/dev/null 2>&1; then
    /bin/launchctl bootout "$SERVICE_DOMAIN/$SERVICE_LABEL"
  fi
}

restore_lock_screen() {
  local backup_file="$HOME/Library/Application Support/NightCockpit/LockScreenBackup/Index.plist"
  local restore_tool="$SERVICE_APP/Contents/Resources/lockscreen-tool"
  if [[ -f "$backup_file" && -x "$restore_tool" ]]; then
    "$restore_tool" restore || echo 'Automatic wallpaper restore failed. Run bash lockscreen.command restore for details.' >&2
    defaults write local.ramakrishna.nightcockpit lockScreenAudio -bool false
  fi
}

case "${1:-status}" in
  start)
    bash build.command --build-only
    mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$SERVICE_LOGS"
    # Stop a registered service before replacing its executable.
    stop_job
    /usr/bin/killall -TERM NightCockpit 2>/dev/null || true
    /usr/bin/ditto "$PWD/dist/Night Cockpit.app" "$SERVICE_APP"
    # Apple ships plutil; no Homebrew Python dependency is required.
    if [[ -f "$SERVICE_PLIST" ]]; then rm "$SERVICE_PLIST"; fi
    /usr/bin/plutil -create xml1 "$SERVICE_PLIST"
    /usr/bin/plutil -insert Label -string "$SERVICE_LABEL" "$SERVICE_PLIST"
    /usr/bin/plutil -insert ProgramArguments -json '[]' "$SERVICE_PLIST"
    /usr/bin/plutil -insert ProgramArguments.0 -string "$SERVICE_APP/Contents/MacOS/NightCockpit" "$SERVICE_PLIST"
    /usr/bin/plutil -insert ProgramArguments.1 -string '--background' "$SERVICE_PLIST"
    /usr/bin/plutil -insert RunAtLoad -bool YES "$SERVICE_PLIST"
    /usr/bin/plutil -insert KeepAlive -bool YES "$SERVICE_PLIST"
    /usr/bin/plutil -insert ThrottleInterval -integer 15 "$SERVICE_PLIST"
    /usr/bin/plutil -insert LimitLoadToSessionType -string Aqua "$SERVICE_PLIST"
    /usr/bin/plutil -insert ProcessType -string Interactive "$SERVICE_PLIST"
    /usr/bin/plutil -insert StandardOutPath -string "$SERVICE_LOGS/output.log" "$SERVICE_PLIST"
    /usr/bin/plutil -insert StandardErrorPath -string "$SERVICE_LOGS/error.log" "$SERVICE_PLIST"
    /usr/bin/plutil -lint "$SERVICE_PLIST"
    /bin/launchctl enable "$SERVICE_DOMAIN/$SERVICE_LABEL"
    /bin/launchctl bootstrap "$SERVICE_DOMAIN" "$SERVICE_PLIST"
    echo 'Started. Launches at login, restarts after exit/crash, and keeps the desktop muted.'
    echo 'Pauses during sleep/lock; resumes when your desktop session is active.'
    echo "Stop: bash \"$PWD/service.command\" stop"
    ;;
  stop)
    stop_job
    restore_lock_screen
    /bin/launchctl disable "$SERVICE_DOMAIN/$SERVICE_LABEL"
    /usr/bin/killall -TERM NightCockpit 2>/dev/null || true
    echo 'Stopped. Will stay stopped after login/reboot until you run start again.'
    ;;
  status)
    if /bin/launchctl print "$SERVICE_DOMAIN/$SERVICE_LABEL" >/dev/null 2>&1; then
      /bin/launchctl print "$SERVICE_DOMAIN/$SERVICE_LABEL"
    else
      echo 'Night Cockpit service is stopped.'
    fi
    ;;
  restart)
    /bin/launchctl kickstart -k "$SERVICE_DOMAIN/$SERVICE_LABEL"
    ;;
  uninstall)
    stop_job
    restore_lock_screen
    /bin/launchctl disable "$SERVICE_DOMAIN/$SERVICE_LABEL"
    /usr/bin/killall -TERM NightCockpit 2>/dev/null || true
    # Remove only this service definition; preserve the app, source and media.
    if [[ -f "$SERVICE_PLIST" ]]; then rm "$SERVICE_PLIST"; fi
    echo 'Auto-start service removed. Your app, source and videos were preserved.'
    ;;
  *) echo 'Usage: bash service.command start|stop|status|restart|uninstall' >&2; exit 2 ;;
esac
