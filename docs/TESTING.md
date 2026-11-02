# Testing

## Automated

On macOS with Command Line Tools and Node.js 18+:

```bash
bash check.command
```

The check command verifies the bundled demo checksum, decodes distinct video frames, checks video/audio metadata, and validates shell syntax, portable installer arguments/paths/failure handling, native settings selection and selective restore, QuickTime temporal-group parsing (including malformed/truncated data), lifecycle transitions, Swift compilation, resources, and signing.

Desktop fixtures construct an unshown window and verify desktop level, mouse transparency, no focus/hit testing, full-screen exclusion, stationary Mission Control behavior, and a poster present before decoding. They need a logged-in desktop and explicitly skip otherwise. No fixture changes system wallpaper or installs a service. Pure fixtures do not prove gesture delivery or native rendering.

## Desktop regression checklist

- Test a fresh source ZIP with the bundled demo: setup must select the installed app resource before launching, with native mode on macOS 26+ and desktop mode on older systems. Also test no bundled media, paths containing spaces, and relative video paths from another directory. Delete the extracted folder after installation and confirm the bundled demo still plays.
- Select a valid local MP4/MOV. Desktop playback loops silently; invalid files do not replace a working video.
- Double-click/open and drag Finder icons; drag-select empty desktop; scroll ordinary windows; use Mission Control, Show Desktop, and three/four-finger Spaces gestures.
- Switch applications and full-screen apps. The wallpaper never becomes key, covers normal apps, or repeatedly raises itself.
- Lock/unlock repeatedly. Playback resumes immediately from its retained player; before a decoded frame arrives, the same-video poster remains visible.
- Connect/disconnect a display and sleep/wake. Existing display players should not be recreated. Manual pause survives unlock.
- Keep Mission Control/App Exposé open for several seconds: the desktop background should continue moving, and clicking wallpaper after dismissal must reach macOS. Inspect Spaces thumbnails and app startup. The underlying image must come from the chosen video, not the earlier Apple wallpaper.
- Stop/uninstall and confirm original background choices return. A later user-selected wallpaper must survive restore.

## Native macOS 26/27 checklist

1. Apply the video to Lock Screen, with the Wallpaper settings pane closed.
2. Confirm status reports synchronized native playback, both native selections and a playable shared-clock movie with the expected audio track. Confirm the native process stays alive and accepts the host connection. Settings read-back alone does not establish rendering.
3. Check motion immediately after locking and through several lock/unlock cycles. Reapplying the same video must refresh the renderer even if its choices are unchanged. Lock with Control-Command-Q and observe the video for more than one complete source loop. Repeat at least three unlock/re-lock cycles.
4. Leave input idle, then interact with authentication. Distinguish macOS dismissing the screen saver from a video that never animates.
5. Confirm lock-only sound and immediate unlock/sleep silence. No independent audio helper may start if the native provider fails.
6. Test repair after removing only the app's own native selection. It should reuse the prepared movie without another conversion.
7. Restore from originally linked and separate wallpaper/screen saver choices; preserve later user changes.

Do not claim a real-device lock/gesture check based on successful compilation, metadata checks, or settings read-back alone. No test should change authentication, sleep/security settings, or place an overlay over the login UI.

Native coverage fixtures include an otherwise-correct global selection with a conflicting per-Space image, an Idle-only global fallback, and restoring app overrides in Spaces created after installation.

Display-hold regression: injected IOKit endpoints verify one acquisition per lock session, idempotent release, failure handling and teardown. State fixtures exclude unlock, disabled/native-off modes, sleep and stopping, while permitting the locked inactive session. Verify the live assertion appears only when the keep-awake option is enabled and the screen is locked; it must disappear on unlock/stop. Do not claim it overrides lid close or forced sleep.

Lock-transition regression: repair must be suppressed while locked, asleep, or in an inactive session. A pending repair is cancelled on lock; after unlock, maintenance waits for the transition to settle. Check that the native renderer PID does not change just because the screen locks. Wallpaper-click behavior uses macOS Desktop & Dock’s Always setting; the app must remain mouse-transparent.

For the internal aerial recovery path, the opt-in cadence check requires macOS 26+ and Swift 6.2+. It reads both files without changing settings and verifies every sample timestamp, duration, frame count, video-only output, native temporal groups, two HEVC temporal layers, and a base cadence of at least half the source rate (with tolerance for short clips/keyframes):

```bash
mkdir -p .build/module-cache
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" xcrun swiftc -swift-version 5 -parse-as-library \
  Tools/MovieFormat.swift Tests/NativeVideoFixtures.swift -o .build/native-video-tests
.build/native-video-tests /path/to/source.mp4 /path/to/prepared.mov
```

Native runtime regression: confirm source timestamps and sound come from one AVPlayer item. Repeated lock cycles must reuse the native player and stop sound immediately on unlock. The runtime logs frame count, source-video timestamp, player time, rate and mute state periodically; logs must show frames advancing at 1× during locked playback, with no media permission errors. Verify the staged media is owner-private and the sandbox can read only its dedicated directory. A valid signature, registration or successful compilation does not prove native playback.

Opt-in offscreen repeated-resume check (macOS 26+, logged-in desktop, always muted):

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" xcrun swiftc -swift-version 5 -parse-as-library \
  -target "$(uname -m)-apple-macosx26.0" -framework AppKit -framework AVFoundation -framework QuartzCore \
  -import-objc-header NativeExtension/NativeBridge.h Sources/Support/NativePlaybackSettings.swift \
  NativeExtension/Diagnostics.swift NativeExtension/NativePlayback.swift Tests/NativePlaybackFixtures.swift \
  -o .build/native-playback-tests
.build/native-playback-tests /path/to/movie.mp4
```

This checks actual decoded frames, 1× advance through three pause/resume cycles, and frame time within 150 ms of the owning player's clock. It creates no NSWindow and changes no system settings. It does not establish compositor visibility or audible synchronization on the real Lock Screen.

After applying a native video, verify that its staged poster survives a real XPC encode/decode round trip (requires macOS 26+):

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" xcrun swiftc -swift-version 5 -parse-as-library \
  -framework AppKit -framework IOSurface Sources/Support/NativePlaybackSettings.swift \
  NativeExtension/Snapshot.swift Tests/NativeSnapshotFixtures.swift -o .build/native-snapshot-tests
.build/native-snapshot-tests
```

The snapshot test must run without an encoder class-swapping workaround: on macOS 27 that workaround causes the receiver to reject the surface. Installer regression checks must also ensure the registered native extension resolves to the installed application, rather than a stale build from a checkout.
