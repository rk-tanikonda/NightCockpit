# Architecture

Night Cockpit has one local playback path. No streaming engine, browser document, web configuration, or media downloads are part of the app.

| Module | Responsibility |
| --- | --- |
| `Sources/main.swift` | App entry and background-restore command |
| `Sources/App/` | Source validation, display reconciliation, and lifecycle coordination |
| `Sources/UI/` | Menu and explicit settings/file chooser |
| `Sources/Playback/DesktopWindow.swift` | Desktop-level, noninteractive, nonactivating windows |
| `Sources/Playback/LocalVideoPlayback.swift` | Retained AVQueuePlayer/looper, poster and video layers |
| `Sources/Support/PlaybackState.swift` | Independent pause, lock, display sleep, system sleep, and session flags |
| `Sources/Support/DesktopBackdrop.swift` | Same-video poster, original-background backup, and public desktop fallback |
| `Sources/Support/WallpaperSettings.swift` | Per-user local preferences |
| `Sources/LockScreen/NativeWallpaperController.swift` | Asynchronous helper process and native readiness |
| `Sources/LockScreen/LockAudioController.swift` | Audio-only playback gated on lock and native readiness |
| `Tools/LockScreenModel.swift` | Pure catalogue/selection edits and selective restore |
| `Tools/MovieFormat.swift` | Bounded QuickTime sample-group parsing for temporal replay support |
| `Tools/VideoPreparation.swift` | Video-only HEVC Main 10 encoding with a base temporal layer |
| `Tools/LockScreenSetup.swift` | Native files, conversion, backups, repair, verification, and restore |
| `scripts/lib/` | Shared project paths, preflight, compilation, packaging, and signing |
| Root commands | Small setup/build/service/native/check entry points |

## Desktop continuity and input

Validate and prepare the new video/poster before replacing existing windows. PNG encoding runs away from the UI thread. Every video view has its same-video poster below the player layer before decoding begins; paused players keep their last displayed frame. The system desktop underneath uses the poster or native aerial from the same video.

Display reconciliation matches windows by display ID. Existing players survive geometry changes and wake; only added/removed displays create/close players. Local playback disables network-style stall waiting and resumes with `playImmediately`. Independent lifecycle flags prevent a display wake from unpausing a still-locked session; unlock clears sleep/session suspension while respecting a manual pause.

Windows use the desktop window level, reject mouse events and hit testing, cannot become key/main, use transient behavior to hide in Mission Control/App Exposé, and opt out of full-screen spaces and window cycling. There are no global input monitors or gesture handlers, and no foreground ordering on app activation or Spaces changes.

## Native video

Aerial playback is owned by macOS. The helper encodes only the video track to native HEVC Main 10, requests a base temporal layer, and validates `tscl`/`tsas` sample groups on macOS 27. Reader/writer work runs in a separate process. Modern toolchains use asynchronous providers/receivers; older SDKs retain a bounded legacy path.

Installation validates schemas before conversion, keeps original backups once, and reads the latest live settings again before committing. Selection links wallpaper and screen saver. Refresh restarts only the wallpaper renderer/agent. A read-back checks all explicit per-Space/per-display overrides and global screen saver selection. Idle-only global nodes retain their macOS schema instead of being forced into a linked desktop choice. Repair reuses the prepared video and writes only if its own entry/selection was lost.

The app runs native repair asynchronously at startup and after unlocked Space/display transitions settle. Maintenance is debounced for 1.5 seconds and cancelled on lock, inactive session, or sleep. Locked/sleeping states never launch repair; the native renderer is not restarted during the lock animation. It does not intercept the lock UI. Lock audio is gated on successful native registration, stops on unlock/sleep, and has an independent clock. These checks cannot prove actual animation; repeated real lock cycles are required.

## Restore and packaging

Original native settings and per-display desktop URLs live under Application Support. Restore replaces only app-owned native choices and restores the public poster only while that poster remains selected. Later user choices are preserved. Stopping disables native repair before restoration.

Build resources are recreated to prevent stale assets from surviving removal. Public source contains no user video or local configuration. Installed login startup runs the app from the user's Applications folder, independently of the source checkout. Logs and compiler caches stay outside tracked source.
