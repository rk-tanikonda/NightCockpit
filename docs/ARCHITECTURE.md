# Architecture

Night Cockpit has one local playback path. No streaming engine, browser document, web configuration, or media downloads are part of the app.

| Module | Responsibility |
| --- | --- |
| `Sources/main.swift` | App entry and background-restore command |
| `Sources/App/` | Source validation, display reconciliation, and lifecycle coordination |
| `Sources/UI/` | Menu and explicit settings/file chooser |
| `Sources/Playback/DesktopWindow.swift` | Desktop-level, noninteractive, nonactivating windows |
| `Sources/Playback/LocalVideoPlayback.swift` | Retained AVQueuePlayer/looper, poster and video layers |
| `Sources/Support/LockDisplayController.swift` | Opt-in, process-owned idle-display assertion with lifecycle release |
| `Sources/Support/PlaybackState.swift` | Independent pause, lock, display sleep, system sleep, and session flags |
| `Sources/Support/DesktopBackdrop.swift` | Same-video poster, original-background backup, and public desktop fallback |
| `Sources/Support/WallpaperSettings.swift` | Per-user local preferences |
| `Sources/LockScreen/NativeWallpaperController.swift` | Asynchronous helper process and native readiness |
| `Sources/Support/NativePlaybackSettings.swift` | Private staged media and native sound configuration |
| `NativeExtension/` | System-hosted, shared-clock audio/video and snapshots |
| `Tools/LockScreenModel.swift` | Pure catalogue/selection edits and selective restore |
| `Tools/MovieFormat.swift` | Bounded QuickTime sample-group parsing for temporal replay support |
| `Tools/VideoPreparation.swift` | Video-only HEVC Main 10 encoding with a base temporal layer |
| `Tools/LockScreenSetup.swift` | Native files, conversion, backups, repair, verification, and restore |
| `scripts/lib/` | Shared project paths, preflight, compilation, packaging, and signing |
| Root commands | Small setup/build/service/native/check entry points |

## Desktop continuity and input

Validate and prepare the new video/poster before replacing existing windows. PNG encoding runs away from the UI thread. Every video view has its same-video poster below the player layer before decoding begins; paused players keep their last displayed frame. The system desktop underneath uses the poster or native aerial from the same video.

Display reconciliation matches windows by display ID. Existing players survive geometry changes and wake; only added/removed displays create/close players. Local playback disables network-style stall waiting and resumes with `playImmediately`. Independent lifecycle flags prevent a display wake from unpausing a still-locked session; unlock clears sleep/session suspension while respecting a manual pause.

Windows use the desktop window level, reject mouse events and hit testing, cannot become key/main, use stationary behavior to keep the live background visible in Mission Control/App Exposé, and opt out of full-screen spaces and window cycling. There are no global input monitors or gesture handlers, and no foreground ordering on app activation or Spaces changes.

## Native video

The native extension in `NativeExtension/` is hosted by WallpaperAgent, behind the system authentication UI. It creates remote CALayer contexts and presents AVPlayerItemVideoOutput frames in AVSampleBufferDisplayLayers. One AVQueuePlayer owns the source audio and video clock, and one player/output is shared across hosted surfaces. It runs at 1× while locked/idle, pauses while unlocked, and mutes immediately on unlock. A separate audio player is deliberately absent.

The app stages an owner-private local movie and poster under `NativePlayback/` in Application Support. The sandboxed extension has read-only access to that directory; its entitlement uses the required leading and trailing slashes. It has no network entitlement. Settings changes are signalled to the extension. This is not a public wallpaper SDK: protocol classes/settings serialization follow Aerial, with attribution in the license notices. Extension bootstrap uses NSExtensionMain and retains Swift main; both are required with the macOS 27 toolchain. Snapshots use the same-video poster so host transitions have a matching image.

The older video-only aerial encoder remains an internal recovery tool. Its HEVC Main 10 temporal layers preserve source timing and are covered by a separate cadence verifier; it is not used for synchronized sound.

Installation validates schemas before selecting the provider, keeps original backups once, and reads the latest live settings again before committing. Selection links wallpaper and screen saver. Refresh restarts only the wallpaper renderer/agent. A read-back checks all explicit per-Space/per-display overrides and global screen saver selection. Idle-only global nodes retain their macOS schema instead of being forced into a linked desktop choice. Repair reuses the prepared video and writes only if its own entry/selection was lost.

The app runs native repair asynchronously at startup and after unlocked Space/display transitions settle. Maintenance is debounced for 1.5 seconds and cancelled on lock, inactive session, or sleep. Locked/sleeping states never launch repair; the native renderer is not restarted during the lock animation. It does not intercept the lock UI. An optional `PreventUserIdleDisplaySleep` assertion keeps the display on only while locked native playback is requested. It is released on unlock, display/system sleep, stopping, or termination; no global power preferences are written. Sound belongs to the native player and shares its video timeline. No alternate independent soundtrack starts if the provider fails. These checks cannot prove actual animation; repeated real lock cycles are required.

## Restore and packaging

Original native settings and per-display desktop URLs live under Application Support. Restore replaces only app-owned native choices and restores the public poster only while that poster remains selected. Later user choices are preserved. Stopping disables native repair before restoration.

Build resources are recreated to prevent stale assets from surviving removal. Public source contains no user video or local configuration. Installed login startup runs the app from the user's Applications folder, independently of the source checkout. Logs and compiler caches stay outside tracked source.
