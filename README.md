# Night Cockpit

A native macOS video wallpaper player written in Swift. Play a local video behind your desktop icons, keep desktop playback muted, and optionally start it at login. Experimental macOS 26+ integration also registers your video as the native Lock Screen wallpaper and screen saver, with optional sound while locked.

No account, Homebrew, Python, package manager, or third-party runtime dependencies are required. Bring your own video; this repository does not distribute footage.

## Quick start

Requires **macOS 13+** on Apple Silicon or Intel and Apple's **Command Line Tools**. Install the tools once if needed:

```bash
xcode-select --install
```

Clone the repository, or download and extract its source ZIP. Open Terminal in the extracted folder and run:

```bash
bash setup.command
```

Setup builds the app, installs it in `~/Applications`, and enables a per-user login service. On first launch, choose an MP4 or MOV through **Change video…**. The file stays where you selected it, so keep it at that location. Use the menu-bar icon for settings, pause, fit, display selection, and **Stop wallpaper**.

You can also select a video during setup:

```bash
bash setup.command --video "$HOME/Movies/wallpaper.mp4"
```

Commands locate the project from their own script location, support paths containing spaces, and work regardless of where you download the source. Relative video paths are resolved from your current Terminal directory. No administrator access is needed.

To build and try the app without installing a login service:

```bash
bash build.command
```

## Native Lock Screen and screen saver

Requires **macOS 26+** and a toolchain with the macOS 15+ SDK (Xcode/Command Line Tools 16 or later). This feature modifies undocumented per-user wallpaper files and remains experimental.

```bash
bash setup.command --video "$HOME/Movies/wallpaper.mp4" --lock-screen
```

Setup converts the movie to HEVC, backs up the original wallpaper settings once, and selects the same native aerial for **both the wallpaper and screen saver**. Selecting only the desktop slot can leave the lock background still while the independent audio player continues. If macOS has not created an aerial manifest yet, choose/download an Apple aerial in **System Settings → Wallpaper**, then retry.

Lock with **Control-Command-Q** and leave the pointer/keyboard untouched to check animation. Moving the pointer or typing can dismiss the screen saver and show a still authentication background; macOS controls that transition. No application window is placed over authentication UI. Native rendering, looping, and compatibility with macOS updates require testing on your Mac.

Sound is a separate audio-only player at 50% player volume; it does not change system volume. It stops on unlock, display sleep, or system sleep. Toggle **Sound while locked** in the app menu. The native renderer and audio player use separate clocks, so synchronization is approximate. Nothing plays before login, after logout, or with a sleeping display.

To reapply the configuration to the currently selected video:

```bash
bash lockscreen.command install
bash service.command restart
```

Changing the desktop video in the app does not automatically replace the converted Lock Screen movie. Re-run `install` to use the new selection.

## Manage the app

Run these from the source folder:

| Command | Result |
| --- | --- |
| `bash service.command status` | Inspect login service status |
| `bash service.command stop` | Stop playback, disable startup, and restore native choices if configured |
| `bash service.command start` | Build, install, and enable startup again |
| `bash service.command restart` | Restart the installed app |
| `bash service.command uninstall` | Stop and remove the login service; preserve the app, media, and backups |
| `bash lockscreen.command status` | Inspect native wallpaper/screen saver registration |
| `bash lockscreen.command restore` | Restore our native choices without replacing later user choices |
| `bash build.command --build-only` | Compile and sign without launching |
| `bash check.command` | Run development checks and build without installing |

Every command supports `--help`. Logs live in `~/Library/Logs/NightCockpit/`; original native settings are backed up in `~/Library/Application Support/NightCockpit/LockScreenBackup/`. Desktop playback pauses while the session is locked or asleep and resumes when active. It does not keep the Mac awake.

**Upgrading from the personal/offline version:** setup detects and disables the previous Night Cockpit login service before replacing the app. The public app uses a project-owned preferences/service identifier; select your video again with `--video`. Keep the existing Lock Screen backup directory so restore can recover your original settings.

## Configuration

- **Local video:** choose a file in the app or pass `--video`. Its path stays in per-user preferences, outside the repository.
- **Optional bundled default:** place your own file at `Videos/wallpaper.mp4` before building. It is copied into the app and ignored by Git. Remove it and rebuild to remove it from the app.
- **Optional HTTPS stream:** copy `wallpaper.example.json` to `wallpaper.local.json`, set `streamURL` to a direct playable HTTPS media URL, and rebuild. Choose **Use configured stream** in the menu. This local configuration is ignored by Git. Streaming does not configure native Lock Screen playback.

## Development

```bash
bash check.command
```

Development checks require Node.js 18+ for the JavaScript/command tests; Node is not needed to install or run the app. Checks validate shell syntax, exercise playback and installer behavior, run pure native-settings fixtures, build Swift code, and verify the app signature. They never install a service or edit wallpaper settings. GitHub Actions runs the same checks on macOS.

See [Contributing](CONTRIBUTING.md), [Architecture](docs/ARCHITECTURE.md), and [Testing](docs/TESTING.md). Bugs and patches are welcome through the repository's Issues and Pull Requests. Please include the macOS version and relevant error output; redact private paths and URLs.

## License

Original source, scripts, and documentation are [MIT licensed](LICENSE). The native configuration model includes Apache-2.0 adaptations from W-Player; see [third-party notices](THIRD_PARTY_NOTICES.md) and [the Apache license](LICENSES/Apache-2.0.txt). Media is not included or licensed by this project. Use footage you own or have permission to use.
