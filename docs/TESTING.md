# Testing

## Automated checks

On macOS with Command Line Tools and Node.js 18+:

```bash
bash check.command
```

The same command runs in GitHub Actions. It checks shell syntax, browser player behavior, portable command interfaces, pure native-settings fixtures, compilation, resources, and signing. It builds without launching, installing a launch agent, or writing wallpaper preferences. The native helper also compiles in CI on systems older than macOS 26, without running installation.

For quick development loops:

```bash
node --test Tests/*.test.cjs
bash build.command --build-only
```

Native fixtures verify linked wallpaper/screen saver selection, restoration of linked and independent choices, preservation of later user edits, upgrade from Desktop-only choices, nested display/Space settings, idempotent manifest registration, and unsupported schema rejection.

## Portable installation checks

- Extract source into a directory with spaces; run `setup.command` without any bundled video. Settings should offer **Change video…**.
- Run the script from outside its source directory, passing a relative path containing spaces. Confirm it opens the intended movie.
- Pass missing/empty/unreadable media or invalid options. Confirm errors occur before preference/service changes.
- On macOS 13–25, default setup should work; `--lock-screen` should explain the version requirement before making changes.
- Build with optional `Videos/wallpaper.mp4` and `wallpaper.local.json`; delete both and rebuild. Confirm stale resources are absent.

## Manual macOS playback checks

- Play your own local video; confirm it loops silently below clickable Finder icons.
- Cover part of the desktop with a normal window. Confirm the exposed video continues playing.
- Switch apps/Spaces and enter/leave Mission Control; normal windows remain above the wallpaper.
- Test pause/resume, fit, multiple displays, and connecting/disconnecting a monitor.
- Enable a configured stream and test disconnect/reconnect recovery. Local playback remains independent of network access.
- Start the service, close Terminal, and log out/in. Confirm background startup without a settings window when a video is configured.
- Terminate only NightCockpit to check launchd recovery, then stop the service and confirm it remains stopped after login.
- Sleep/wake the Mac. Confirm silent desktop playback resumes without preventing sleep.

## Native Lock Screen regression

Use macOS 26+ and media you own. Keep the original backup. Do not describe this feature as device-verified until these checks pass:

1. Run setup with `--video` and `--lock-screen`. Confirm registration selects both wallpaper and screen saver.
2. Lock with Control-Command-Q and leave input idle. Observe motion for longer than the source clip and check the loop boundary.
3. Move the pointer/type. macOS may switch to a still authentication background; distinguish that transition from a movie that never animates while idle.
4. Check lock-only audio, unlock silence, and display/system sleep. Sound and video need not be frame-synchronized.
5. Test stop/restore from an originally linked choice and from distinct wallpaper/screen saver choices. Both original choices must return.
6. After install, choose a different wallpaper or screen saver in System Settings. Restore must preserve that later choice.
7. Reinstall over the older Desktop-only configuration and confirm native animation and selective restore.

A passed Swift build or fixture run establishes neither rendering nor overnight reliability. macOS controls native animation and may change its undocumented configuration format.
