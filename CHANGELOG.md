# Changelog

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
