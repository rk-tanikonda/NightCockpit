# Contributing

Start with [the architecture guide](docs/ARCHITECTURE.md). Keep changes focused and describe the user-visible problem in your pull request.

## Development loop

1. Use macOS 13+ with Apple's Command Line Tools. Native Lock Screen development needs macOS 26+ and the macOS 15+ SDK.
2. Run `bash build.command` to build and launch a development copy, without installing a service.
3. Run `bash check.command` before submitting changes. Install Node.js 18+ for the development tests; the app itself does not need Node.
4. Follow the [manual Mac checklist](docs/TESTING.md) for playback or system-integration changes.

Use four spaces in Swift and shell files, two in HTML/JavaScript/JSON/YAML. Keep files focused on one responsibility. Share shell paths/preflight in `scripts/lib/common.sh` and compilation in `scripts/lib/build.sh`; keep root commands as small entry points.

Use media you own. Do not commit media, credentials, application bundles, or machine-specific paths. Preserve third-party copyright and license notices when adapting code.

Desktop playback must remain muted. Preserve system sleep, security settings, and authentication UI. Native wallpaper changes require schema validation, backups, pure fixture coverage, and selective restore. Test linked and independent wallpaper/screen saver choices, including changes the user made after installation.

Before opening a pull request, inspect `git diff` and `git status --short`. Include the trigger, resulting behavior, and checks performed. Distinguish automated checks from manual playback/lock-screen testing. Do not claim system rendering or audio synchronization based on compilation alone.

Keep playback local-only. Wallpaper windows must stay at desktop level, reject focus/input, and never be repeatedly raised on app/Spaces changes. Retain players across wake and screen geometry changes. Keep conversion, PNG compression, and helper waits off the UI thread.
