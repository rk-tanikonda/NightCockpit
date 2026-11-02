# Changelog

## Unreleased

- Include an original CC0 demo video with synthesized audio for fresh source downloads.
- Make one-command setup choose compatible desktop/native defaults, preserve existing media, and install/configure/start only once.
- Check builds on Intel and Apple Silicon and document platform limits.

- Replace the independent lock audio sidecar with a native extension using one AVPlayer for synchronized audio/video, private local media staging, and matching snapshots.

- Add an opt-in display hold for locked native video, released on unlock, sleep, stop and process exit without changing power preferences.

- Keep the animated background visible during Mission Control/App Exposé without taking focus or input.
- Raise the native HEVC base layer from one-eighth to one-half of the source frame rate to improve lock/unlock transition cadence; preserve source timestamps.
- Reload the native renderer after replacing the movie even when its catalogue and selections already match.

- Defer native maintenance until unlock/Space transitions settle; cancel pending repair during locking and sleep to avoid renderer restarts during the lock animation.

- Remove streaming, WebKit, browser resources, and private stream configuration.
- Retain desktop players across lock/wake and display geometry changes.
- Keep a same-video poster underneath playback and as the system fallback.
- Use nonactivating desktop-level windows without foreground reordering or input hit testing.
- Encode video-only native HEVC Main 10 with temporal replay groups for macOS 27.
- Repair lost native registration asynchronously and gate lock audio on native readiness.
- Add lifecycle, temporal-format, and noninteractive-window fixtures.

- Replace private-bundle installation with portable setup and user-selected media.
- Share shell configuration and build operations across command entry points.
- Use a project-owned app/service identifier and add a first-run video chooser.
- Configure native wallpaper and screen saver together; restore both slots selectively.
- Separate media conversion from native registration and use async AVFoundation export/thumbnail APIs.
- Add portable installer regression tests and a single local/CI check command.
- Remove personal asset URLs and machine-specific instructions from public documentation.

## 1.5.0

- Default to the verified local 4K H.264/AAC file; no website/network requests for local playback.
- Initialize the native video layer frame immediately.
- Add experimental macOS 26 native aerial registration, HEVC conversion, one-time settings backups and selective restore.
- Add separate lock-only audio playback, muted desktop playback, and restore on stop.
- Add pure Lock Screen configuration fixtures and third-party license attribution.
- Real macOS Lock Screen/video/audio behavior remains unverified.


## 1.4.0

- Split startup, app coordination, workspace events, menu, settings, native playback and stream playback into focused files.
- Replace third-party website embedding and DOM modification with a video-only HTML document owned by the application.
- Remove website-preview and download actions from the menu; add Change video, Reload wallpaper and Stop wallpaper.
- Place playback windows immediately below Finder's icon level and refresh their ordering when applications or Spaces change.
- Keep desktop playback muted; retain sleep handling, reconnection and the optional login service.
- Add Git ignore rules, MIT source license, architecture and contributor guides, behavior tests, and macOS build CI.

Lock Screen video and Lock Screen audio are not implemented. Version 1.4.0 needs macOS playback verification; browser tests alone do not establish desktop behavior.
