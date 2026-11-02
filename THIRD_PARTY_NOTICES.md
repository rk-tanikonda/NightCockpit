# Third-party notices

`Tools/LockScreenModel.swift` adapts the macOS aerial manifest and wallpaper-choice editing approach from [W-Player](https://github.com/RiperYT/w-player).

Copyright 2026 W-Player contributors. Licensed under the Apache License, Version 2.0; the complete license is in `LICENSES/Apache-2.0.txt`.

Reference source revisions: `AerialsManifest.swift` 96308adfd2e77ec46e8a7c7c1f2af91adcd1d897; `WallpaperChoice.swift` af7529f5ce3c35d6e225d543e5a29883fdfe9946. Changes include a Night Cockpit namespace, a single asset, strict preflight validation, and linking wallpaper/screen saver selection and selectively restoring this app's choices.

W-Player's app, updater and Sparkle framework are not included.

`NativeExtension/NativeBridge.h`, `Configuration.swift`, `SettingsModels.swift`,
`SettingsProvider.swift`, and `Handler+Choices.swift` adapt the native wallpaper
extension protocol and settings serialization from
[Aerial](https://github.com/AerialScreensaver/Aerial). The remote-context format
in `Handler.swift` also follows Aerial's implementation.

Copyright (c) 2015–present Guillaume Louel and contributors. Licensed under MIT;
the complete license is in `LICENSES/Aerial-MIT.txt`. Changes reduce the extension
to one user-selected local movie and a single AVPlayer timeline. Aerial's media,
networking, playlists, overlays, and app are not included. The wallpaper extension
protocol is undocumented and can change with macOS updates.

No video or audio is distributed in this source repository. Media supplied by users is not covered by the source-code licenses. Users are responsible for the required permissions and attribution when distributing media with their builds.
