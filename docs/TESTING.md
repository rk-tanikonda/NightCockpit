# Testing

## Automated

On macOS with Command Line Tools and Node.js 18+:

```bash
bash check.command
```

The check command validates shell syntax, portable installer arguments/paths/failure handling, native settings selection and selective restore, QuickTime temporal-group parsing (including malformed/truncated data), lifecycle transitions, Swift compilation, resources, and signing.

Desktop fixtures construct an unshown window and verify desktop level, mouse transparency, no focus/hit testing, full-screen exclusion, transient Mission Control behavior, and a poster present before decoding. They need a logged-in desktop and explicitly skip otherwise. No fixture changes system wallpaper or installs a service. Pure fixtures do not prove gesture delivery or native rendering.

## Desktop regression checklist

- Test source installation with no bundled media, paths containing spaces, and relative video paths from another directory.
- Select a valid local MP4/MOV. Desktop playback loops silently; invalid files do not replace a working video.
- Double-click/open and drag Finder icons; drag-select empty desktop; scroll ordinary windows; use Mission Control, Show Desktop, and three/four-finger Spaces gestures.
- Switch applications and full-screen apps. The wallpaper never becomes key, covers normal apps, or repeatedly raises itself.
- Lock/unlock repeatedly. Playback resumes immediately from its retained player; before a decoded frame arrives, the same-video poster remains visible.
- Connect/disconnect a display and sleep/wake. Existing display players should not be recreated. Manual pause survives unlock.
- Inspect Mission Control/Spaces thumbnails and app startup. The underlying image must come from the chosen video, not the earlier Apple wallpaper.
- Stop/uninstall and confirm original background choices return. A later user-selected wallpaper must survive restore.

## Native macOS 26/27 checklist

1. Apply the video to Lock Screen, with the Wallpaper settings pane closed.
2. Confirm status reports both native selections and a playable movie. On macOS 27, temporal replay layers must be present; a generic HEVC export is insufficient.
3. Lock with Control-Command-Q and observe the video for more than one complete source loop. Repeat at least three unlock/re-lock cycles.
4. Leave input idle, then interact with authentication. Distinguish macOS dismissing the screen saver from a video that never animates.
5. Confirm lock-only sound and immediate unlock/sleep silence. Failed native preparation must not enable audio by itself.
6. Test repair after removing only the app's own native selection. It should reuse the prepared movie without another conversion.
7. Restore from originally linked and separate wallpaper/screen saver choices; preserve later user changes.

Do not claim a real-device lock/gesture check based on successful compilation, metadata checks, or settings read-back alone. No test should change authentication, sleep/security settings, or place an overlay over the login UI.

Native coverage fixtures include an otherwise-correct global selection with a conflicting per-Space image, an Idle-only global fallback, and restoring app overrides in Spaces created after installation.

Lock-transition regression: repair must be suppressed while locked, asleep, or in an inactive session. A pending repair is cancelled on lock; after unlock, maintenance waits for the transition to settle. Check that the native renderer PID does not change just because the screen locks. Wallpaper-click behavior uses macOS Desktop & Dock’s Always setting; the app must remain mouse-transparent.
