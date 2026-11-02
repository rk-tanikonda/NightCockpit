#!/bin/bash
# Per-user service: no sudo, no system daemons, no sleep-setting changes.
set -euo pipefail
source "$(dirname -- "$0")/scripts/lib/common.sh"
source "$PROJECT_ROOT/scripts/lib/build.sh"
case "${1:-status}" in
  --help|-h) echo 'Usage: bash service.command start|stop|status|restart|uninstall'; exit 0 ;;
  start) [[ $# -le 2 && "${2:---use-build}" == --use-build ]] || fail 'Usage: bash service.command start [--use-build]' ;;
  stop|status|restart|uninstall) [[ $# -le 1 ]] || fail 'Too many arguments.' ;;
  *) fail 'Usage: bash service.command start|stop|status|restart|uninstall' ;;
esac
require_macos

stop_job() {
  if /bin/launchctl print "$SERVICE_DOMAIN/$SERVICE_LABEL" >/dev/null 2>&1; then
    /bin/launchctl bootout "$SERVICE_DOMAIN/$SERVICE_LABEL"
  fi
}

retire_previous_service() {
  local info="$SERVICE_APP/Contents/Info.plist"
  [[ -f "$info" ]] || return 0
  local old_id old_executable
  old_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info" 2>/dev/null || true)"
  old_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info" 2>/dev/null || true)"
  # Derive migration from the installed app; no developer's old identifier is embedded.
  if [[ "$old_executable" == "$APP_EXECUTABLE" && -n "$old_id" && "$old_id" != "$BUNDLE_ID" ]]; then
    /bin/launchctl disable "$SERVICE_DOMAIN/$old_id.agent"
    if /bin/launchctl print "$SERVICE_DOMAIN/$old_id.agent" >/dev/null 2>&1; then
      /bin/launchctl bootout "$SERVICE_DOMAIN/$old_id.agent"
    fi
    echo 'Disabled the previous Night Cockpit login service. Original preferences and backups were preserved.'
  fi
}

restore_lock_screen() {
  local backup_file="$LOCK_BACKUP/Index.plist"
  local restore_tool="$SERVICE_APP/Contents/Resources/lockscreen-tool"
  if [[ -f "$backup_file" && -x "$restore_tool" ]]; then
    "$restore_tool" restore || echo 'Automatic wallpaper restore failed. Run bash lockscreen.command restore for details.' >&2
  fi
  if [[ -x "$SERVICE_APP/Contents/MacOS/$APP_EXECUTABLE" ]]; then
    "$SERVICE_APP/Contents/MacOS/$APP_EXECUTABLE" --restore-background
  fi
}

case "${1:-status}" in
  start)
    if [[ "${2:-}" == --use-build ]]; then
      [[ -x "$APP/Contents/MacOS/$APP_EXECUTABLE" ]] || fail 'Build the app first.'
    else
      build_app
    fi
    mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$SERVICE_LOGS"
    # Stop a registered service before replacing its executable.
    stop_job
    retire_previous_service
    /usr/bin/killall -TERM "$APP_EXECUTABLE" 2>/dev/null || true
    # Replace the installed bundle rather than merging stale resources.
    rm -rf "$SERVICE_APP"
    /usr/bin/ditto "$APP" "$SERVICE_APP"
    if [[ -d "$SERVICE_APP/Contents/Extensions/NightCockpitNative.appex" ]]; then
      /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$SERVICE_APP"
      /usr/bin/pluginkit -a "$SERVICE_APP/Contents/Extensions/NightCockpitNative.appex"
    fi
    # Apple ships plutil; no Homebrew Python dependency is required.
    if [[ -f "$SERVICE_PLIST" ]]; then rm "$SERVICE_PLIST"; fi
    /usr/bin/plutil -create xml1 "$SERVICE_PLIST"
    /usr/bin/plutil -insert Label -string "$SERVICE_LABEL" "$SERVICE_PLIST"
    /usr/bin/plutil -insert ProgramArguments -json '[]' "$SERVICE_PLIST"
    /usr/bin/plutil -insert ProgramArguments.0 -string "$SERVICE_APP/Contents/MacOS/$APP_EXECUTABLE" "$SERVICE_PLIST"
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
    echo 'Stop: choose Stop wallpaper in the menu, or run bash service.command stop from the source folder.'
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
