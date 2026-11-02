# Architecture

Read the files in this order. The app uses Apple's frameworks directly and has no third-party runtime dependencies.

| File | Responsibility | Typical change |
| --- | --- | --- |
| `Sources/main.swift` | Create NSApplication and retain its delegate | Rarely edited |
| `Sources/App/AppDelegate.swift` | Choose a source, validate local video, coordinate engines | Source-selection behavior |
| `Sources/App/AppDelegate+Workspace.swift` | Observe sleep, wake, displays, app activation and Spaces | Desktop lifecycle |
| `Sources/UI/AppDelegate+Menu.swift` | Menu items and deliberate service stop | Rename or add a control |
| `Sources/UI/AppDelegate+Controls.swift` | Settings window and local-file picker | Settings presentation |
| `Sources/Support/WallpaperSettings.swift` | UserDefaults and private stream configuration | A new preference |
| `Sources/Playback/WallpaperPlayback.swift` | Common play/pause/fit/close interface | A new engine |
| `Sources/Playback/DesktopWindow.swift` | Noninteractive windows below Finder icons | Window placement |
| `Sources/Playback/LocalVideoPlayback.swift` | AVQueuePlayer + AVPlayerLooper | Native local playback |
| `Sources/Playback/StreamVideoPlayback.swift` | WKWebView containing our own player, retry lifecycle | Streaming behavior |
| `Sources/Resources/stream-player.html` | One video element, muted looping and stall detection | Browser media behavior |
| `build.command` | Compile Swift, copy resources and ad-hoc sign an app | Build/package changes |
| `service.command` | Per-user launch agent start/stop/status | Startup/recovery behavior |

`AppDelegate` owns an array of `WallpaperPlayback` objects, normally one per screen. It passes pause/fit commands through that protocol, so UI code does not need to know which engine is active. Sleep and inactive login sessions suspend playback. Changing the foreground application does not pause it.

Local playback is the most predictable mode. Stream playback has our own HTML document; it never navigates to a third-party wallpaper page, queries that page's DOM or clicks its controls. JavaScript sends `{kind, message}` status events to Swift. Swift accepts those messages as data, shows progress/errors, and reconnects with a bounded delay after failures. The native cover is removed after a `playing` event.

`wallpaper.local.json` configures a personal stream URL and is copied into the built app. Git ignores it. The public example starts empty. The selected local file path stays in UserDefaults and the file itself stays where the user put it.

Window ordering, WebKit media behavior and launchd must be checked on macOS. The Lock Screen uses a separate experimental macOS 26 path: Tools/LockScreenModel.swift edits only our native aerial entry/selection after schema checks; Tools/LockScreenSetup.swift converts the local file and backs up/writes settings. Sources/LockScreen/LockAudioController.swift plays an audio-only composition only after lock events, stopping on unlock/sleep. The original local 4K file has AAC audio; the web preview was silent. Native video and audio have separate clocks.

The personal offline package defaults to the bundled local video. Streaming remains optional and is not used for its default playback. Native AVPlayerLayer dimensions are initialized before the first layout pass.
