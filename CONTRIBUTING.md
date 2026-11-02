# Contributing

Start with [the architecture guide](docs/ARCHITECTURE.md). Keep changes small and explain the user-visible problem in the pull request.

## Development loop

1. Use macOS 13+ with Apple's Command Line Tools (`xcode-select --install`).
2. Run `bash build.command` to build and launch a development copy.
3. Run `node --test Tests/*.test.cjs` for the video-player behavior tests. Node is a development tool, not an application dependency.
4. Run `bash -n build.command` and `bash -n service.command` to check shell syntax.
5. Follow [the Mac playback checklist](docs/TESTING.md) before reporting a fix as verified.

Use four spaces in Swift and shell files, two in HTML/JavaScript/JSON/YAML. Keep source files focused on one responsibility. Add comments for platform constraints and decisions; avoid comments that merely repeat each statement.

Use a local video you own for development. Personal source URLs belong in `wallpaper.local.json`, which Git ignores. Do not commit media, credentials, application bundles or another project's code without the appropriate rights and attribution.

Desktop playback must remain muted. Do not disable system sleep, change security settings or cover authentication UI. The experimental native Lock Screen path uses backed-up user wallpaper settings; changes require pure fixture checks and actual macOS 26 rendering/audio/restore verification before claiming device support.

Before committing, inspect `git diff --cached` and `git status --short`. Open a pull request with the trigger, resulting behavior and checks performed, and distinguish automated tests from manual Mac testing.
