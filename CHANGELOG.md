# Changelog

## 1.4.0

- Split startup, app coordination, workspace events, menu, settings, native playback and stream playback into focused files.
- Replace third-party website embedding and DOM modification with a video-only HTML document owned by the application.
- Remove website-preview and download actions from the menu; add Change video, Reload wallpaper and Stop wallpaper.
- Place playback windows immediately below Finder's icon level and refresh their ordering when applications or Spaces change.
- Keep desktop playback muted; retain sleep handling, reconnection and the optional login service.
- Add Git ignore rules, MIT source license, architecture and contributor guides, behavior tests, and macOS build CI.

Lock Screen video and Lock Screen audio are not implemented. Version 1.4.0 needs macOS playback verification; browser tests alone do not establish desktop behavior.
