# Architecture

Night Cockpit uses Apple's frameworks directly, with no third-party runtime dependencies. Application components communicate through small interfaces; shell entry points share configuration and build functions.

| Module | Responsibility |
| --- | --- |
| `Sources/main.swift` | Create NSApplication and retain its delegate |
| `Sources/App/` | Coordinate source selection, playback, and workspace lifecycle |
| `Sources/UI/` | Menu-bar controls, settings window, and local-file picker |
| `Sources/Support/WallpaperSettings.swift` | Preferences, optional bundled media, and private HTTPS stream configuration |
| `Sources/Playback/WallpaperPlayback.swift` | Common pause/fit/close interface for playback engines |
| `Sources/Playback/LocalVideoPlayback.swift` | Native AVQueuePlayer/AVPlayerLooper playback |
| `Sources/Playback/StreamVideoPlayback.swift` | WKWebView playback and reconnect lifecycle |
| `Sources/Playback/DesktopWindow.swift` | Noninteractive windows below Finder icons |
| `Sources/Resources/stream-player.html` | Muted looping video and stall detection |
| `Sources/LockScreen/LockAudioController.swift` | Independent audio-only loop during lock, stopped on unlock/sleep |
| `Tools/LockScreenModel.swift` | Pure native settings validation, registration, linked selection, and selective restore |
| `Tools/VideoPreparation.swift` | Validate/convert local media and generate a thumbnail using async AVFoundation APIs |
| `Tools/LockScreenSetup.swift` | Native file access, original-settings backups, registration, and restore |
| `scripts/lib/common.sh` | Project paths, metadata, platform/tool checks, and video path resolution |
| `scripts/lib/build.sh` | Compile the app, helper, and pure fixtures; package and sign |
| Root `*.command` files | User-facing setup, build, service, native configuration, and checks |

## Application lifecycle

`AppDelegate` owns one `WallpaperPlayback` per display, passing pause/fit commands through that protocol. UI code does not depend on the engine. Sleep and inactive login sessions suspend playback; changing the foreground app does not pause it.

Source selection honors an explicitly enabled stream, then a readable saved local path, then an optional bundled `wallpaper.mp4`. With no source, the app opens settings even when launched as a background service. Local paths stay in UserDefaults. Media stays in place unless the user deliberately bundles a default. Optional `wallpaper.local.json` is copied at build time and ignored by Git.

Stream playback loads the app's own video-only HTML, which reports status to Swift. It does not embed or navigate to a third-party wallpaper page. The app displays errors and retries with bounded delay.

## Commands and installation

`common.sh` resolves the project relative to itself, independently of the caller's directory. The bundle identifier in `Info.plist` determines the preferences domain and launch-agent label; Swift reads that identifier from its bundle. No username or checkout path is embedded in source.

`setup.command` parses and validates arguments, builds before changing preferences, optionally configures native playback, then installs the already built app. `service.command` manages a per-user launch agent and an app copy under the current user's Applications folder. The installed service does not depend on the original checkout remaining in place. Externally selected video files must remain accessible.

Build resources are recreated each time to prevent removed media/configuration from lingering in a new build. Compilation uses the host architecture with a macOS 13 deployment target. Native integration runs only on macOS 26+; ordinary desktop builds on older systems do not require compiling the native helper.

## Native wallpaper and screen saver

Native registration validates Apple's undocumented aerial manifest/store, converts the movie to HEVC, backs up originals once, and writes our single namespaced asset. The same aerial is selected as a **Linked** wallpaper/screen saver choice. The older Desktop-only path left the Idle slot on its prior provider, which can produce still wallpaper with independent audio.

Restore replaces only choices still owned by Night Cockpit. It recovers original linked or independent slots, while preserving later user changes. The model has no filesystem access and is covered by fixtures for these cases. The helper owns filesystem operations and refreshes WallpaperAgent. The original backup stays outside the repository.

macOS owns animation, the screen saver/authentication transition, and display sleep. The application never overlays authentication UI or changes security settings. Native video and lock audio have separate clocks. Compilation and pure fixtures cannot prove native rendering; use the manual checklist.
