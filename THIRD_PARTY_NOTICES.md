# Third-party notices

The root MIT license covers Night Cockpit's original source code, build scripts,
and documentation. The adaptations below retain their respective licenses.
Original bundled video and audio are separately dedicated under CC0 1.0 in
[MEDIA_LICENSE.md](MEDIA_LICENSE.md). No project license grants rights to
users' third-party footage, music, or trademarks.

`Tools/LockScreenModel.swift` adapts the macOS aerial manifest and wallpaper-choice editing approach from [W-Player](https://github.com/RiperYT/w-player).

Copyright 2026 W-Player contributors. Licensed under the Apache License, Version 2.0; the complete license is in `LICENSES/Apache-2.0.txt`.

Reference source revisions: `AerialsManifest.swift` 96308adfd2e77ec46e8a7c7c1f2af91adcd1d897; `WallpaperChoice.swift` af7529f5ce3c35d6e225d543e5a29883fdfe9946. Changes include a Night Cockpit namespace, a single asset, strict preflight validation, and linking wallpaper/screen saver selection and selectively restoring this app's choices.

W-Player's app, updater and Sparkle framework are not included.

`NativeExtension/NativeBridge.h`, `Configuration.swift`, `SettingsModels.swift`,
`SettingsProvider.swift`, and `Handler+Choices.swift` adapt the native wallpaper
extension protocol and settings serialization from
[Aerial](https://github.com/AerialScreensaver/Aerial). The remote-context format
in `Handler.swift` and snapshot encoding in `Snapshot.swift` also follow Aerial's implementation.

Copyright (c) 2015–present Guillaume Louel and contributors. Licensed under MIT;
the complete license is in `LICENSES/Aerial-MIT.txt`. Changes reduce the extension
to one user-selected local movie and a single AVPlayer timeline. Aerial's media,
networking, playlists, overlays, and app are not included. The wallpaper extension
protocol is undocumented and can change with macOS updates.

The bundled original `Videos/wallpaper.mp4` and its synthesized audio are dedicated to the public domain under CC0 1.0; see [MEDIA_LICENSE.md](MEDIA_LICENSE.md) and [media provenance](Videos/SOURCE.md). User-supplied media, including the third-party Formula One clip used during local development, is not distributed or covered by these licenses. Users need the required permissions when distributing their own media.
