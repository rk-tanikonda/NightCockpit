# Night Cockpit

A small, readable macOS video wallpaper player written in Swift. MIT-licensed source with no third-party runtime dependencies.

**Version 1.4.0:** the code is split into focused files, the menu has ordinary wallpaper controls, and streaming uses our own video-only document. The app no longer loads a wallpaper website or modifies its page.

## Build and run

Requires macOS 13+ and Apple's Command Line Tools. Install them with `xcode-select --install` if needed, then:

```bash
bash build.command
```

Choose **Change video…** from the menu-bar icon to select an MP4 or MOV that you own. Keep the file at its selected location. Local playback loops offline and remains muted. The wallpaper is drawn below Finder's desktop icons and normal application windows.

For an HTTPS stream, copy `wallpaper.example.json` to `wallpaper.local.json`, set `streamURL` to a direct video URL you are allowed to use, and rebuild. A website page URL is not a video URL. The local configuration is ignored by Git; the public example is empty. This conversation's personal download includes a local configuration for the requested preview, but no video file or rights to third-party footage.

A media server may reject standalone streaming even when its surrounding web page works. This build does not show that website as a fallback. If the stream fails, use a local video; it does not claim to remove an upstream HTTP 429. A black cover can appear while an online video first buffers, but website navigation, banners and buttons cannot appear because that page is never loaded.

## Update the existing personal project

Download `NightCockpit-source.zip` into Downloads:

```bash
unzip -o ~/Downloads/NightCockpit-source.zip -d ~/Dev/rk
cd ~/Dev/rk/NightCockpit
bash service.command start
```

This rebuilds and installs the app, and restarts its background service. Existing local media and preferences are preserved. No root access is needed.

## Continuous startup and stopping

```bash
bash service.command start       # build, install, start now and after future logins
bash service.command status      # inspect the launch agent
bash service.command restart     # restart installed app, without rebuilding
bash service.command stop        # stop now and disable future auto-start
bash service.command uninstall   # remove service; preserve app/source/media
```

The service runs in your logged-in GUI session, starts without a settings window, and restarts an exited process. Video playback pauses for sleep or an inactive login session, then resumes. It does not prevent sleep, work while powered off, or change battery settings. Website availability and internet access still affect stream mode. Retries use increasing delays up to five minutes.

**Stop wallpaper** in the menu also disables and unloads the service, so it does not immediately restart. **Reload wallpaper** reloads the selected source without opening any website. Other controls: Pause/Resume, Fit entire video, Main display only, Settings/status, and Change video.

## Current limitations

- **Lock Screen video and sound are not implemented.** Desktop windows do not constitute Lock Screen integration. That needs a separate OS-specific implementation and a suitable local video with an audio track. The originally requested public preview is documented as silent.
- The revised desktop window level and stream renderer need manual macOS verification. They are intended to address visibility behind partially covering apps and page flashes, but passing JavaScript tests does not establish those Mac behaviors.
- The project was edited in Linux. This version has not been compiled or run on macOS here. The bundled GitHub Actions workflow compiles it on a macOS runner after you push.
- Third-party media and trademarks are not included in the MIT source-code license. Use media you own or have permission to use. Do not commit personal media, source URLs or credentials.

## Understand and contribute

Start with [the architecture guide](docs/ARCHITECTURE.md), then [CONTRIBUTING.md](CONTRIBUTING.md). Each file has one clear responsibility. Tests and manual acceptance checks are in [docs/TESTING.md](docs/TESTING.md).

```bash
node --test Tests/*.test.cjs
bash -n build.command
bash -n service.command
```

Node is needed only for development tests. Building/running the application does not need Node, Homebrew, npm packages or full Xcode.

## Publish your source

```bash
git init
git branch -M main
git add .
git status --short
git diff --cached --stat
git commit -m "Initial open-source release"
# Create an empty public repository, then use its real URL:
git remote add origin https://github.com/YOUR_USERNAME/NightCockpit.git
git push -u origin main
```

Configure your own Git author name/email if Git requests them. Review staged files before committing. `.gitignore` excludes local configuration, videos/audio, builds, app bundles, archives, logs, credentials and editor state. Only the source, tests, empty example configuration and project documentation should be published. Repository creation and pushing are not performed by the build or service scripts.

The MIT [LICENSE](LICENSE) covers original project source only. See [SECURITY.md](SECURITY.md) for security reporting guidance.
