# Night Cockpit

A readable Swift macOS video wallpaper player. The personal offline package now contains the **actual downloaded 3840×2160 video with AAC audio**, rather than depending on its silent web preview.

## Install this personal offline package

Download `NightCockpit-offline.zip` into Downloads and run:

```bash
unzip -o ~/Downloads/NightCockpit-offline.zip -d ~/Dev/rk
cd ~/Dev/rk/NightCockpit
bash setup.command
```

Setup uses `Videos/night-cockpit.mp4` locally, prepares a native Lock Screen movie, backs up your wallpaper settings, selects that movie on macOS 26+, enables lock-only audio, then installs the login service. HEVC conversion can take a few minutes. It requires Apple's Command Line Tools (`xcode-select --install` if absent), no Homebrew, Python or administrator access.

If setup says the aerial manifest is missing, open System Settings → Wallpaper and choose/download an Apple aerial once, then run setup again. If native Lock Screen setup fails, setup still starts the desktop and explicitly returns an error for the incomplete Lock Screen part.

**macOS 13–25:** desktop playback works, but this native Lock Screen registration requires macOS 26+. Run `bash service.command start` for desktop only. It will use the bundled video.

## What should happen

- **Desktop:** the local video loops silently below Finder icons. No website, download, browser session or internet connection is used for the default local file.
- **Lock Screen on macOS 26+:** macOS's own aerial renderer displays the converted local movie. It is selected through the user's wallpaper manifest/store, not a fake lock-screen overlay.
- **Sound while locked:** a separate audio-only player loops this same file's audio after the system's lock notification. It stops on unlock or display/system sleep. Audio starts at 50% player volume; it does not alter system volume. Toggle it from **Sound while locked** in the menu.
- **After login:** the per-user launch agent starts the app silently and restarts it after exit/crash. It resumes after sleep without keeping the Mac awake.

Press Control-Command-Q to check the real Lock Screen. This integration is **experimental and unverified on your Mac**. It uses undocumented macOS 26 wallpaper files, which Apple may change. The system video renderer and the audio helper have separate clocks, so exact video/audio synchronization is not guaranteed. The app does not play audio before login or after logout, and cannot animate a sleeping or powered-off display.

## Stop, restore and inspect

```bash
bash service.command status
bash service.command stop
bash lockscreen.command status
bash lockscreen.command restore
```

`stop` disables/unloads the launch agent, closes the app/audio, and tries to restore this app's native wallpaper choices. It stays stopped after reboot. `restore` selectively restores our Desktop choices and removes our asset/category while preserving other current wallpaper assets and screen-saver choices. Original files are backed up at `~/Library/Application Support/NightCockpit/LockScreenBackup/`.

Run `bash setup.command` to enable the full setup again. Use `bash service.command start` for desktop startup without reinstalling Lock Screen settings. The menu's **Stop wallpaper** also attempts restore before stopping. Closing Terminal does not stop playback.

## Source and development

Entry point: `Sources/main.swift`. App coordination, workspace events, UI, settings, native/stream playback and lock audio are separate files. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [docs/TESTING.md](docs/TESTING.md).

```bash
bash build.command                     # desktop build / launch
node --test Tests/*.test.cjs            # optional stream-player tests
bash -n build.command
bash -n service.command
bash -n setup.command
bash -n lockscreen.command
```

The Lock Screen command compiles and runs pure configuration fixtures before it can edit real settings. The bundled macOS CI workflow also compiles the app/helper and runs those fixtures; it does not change the runner's wallpaper. This update was authored in Linux: actual macOS compilation, lock events, native aerial rendering and lock-only audio have not been verified here.

The original video was downloaded and independently checked with ffprobe: H.264, 3840×2160, 30.8 seconds, AAC audio, 149,479,463 bytes. Audio signal detection confirmed it is not silent. `Videos/SOURCE.md` records the checksum and origin.

## Open source and Git

The app's original source is MIT-licensed. `Tools/LockScreenModel.swift` includes Apache-2.0 adaptations from W-Player; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and `LICENSES/Apache-2.0.txt`. No Sparkle/updater framework is included.

**The personal offline ZIP includes third-party footage; the public Git repository must not include it.** The video is excluded by `.gitignore` and is not covered by the source-code licenses. Use media you own or have permission to use. MacWall's published terms restrict its catalog media to use in its app; this code grants no rights in that footage.

```bash
git init
git branch -M main
git add .
git status --short
git diff --cached --stat
git commit -m "Initial open-source release"
git remote add origin https://github.com/YOUR_USERNAME/NightCockpit.git
git push -u origin main
```

Review the staged files. Video/audio files, local source URLs, builds, app bundles, archives, logs, secrets and editor state are ignored. Git author details and repository destination must be yours. A public clone without personal footage can use **Change video…** for any local MP4/MOV; online stream mode remains optional and is not used by the offline default.
