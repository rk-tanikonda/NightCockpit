# Testing

## Automated

```bash
node --test Tests/*.test.cjs
bash -n build.command
bash -n service.command
bash build.command --build-only  # macOS only
```

The GitHub Actions workflow runs these on a macOS runner when the source is pushed. It validates compilation and app resources; it does not test a logged-in desktop, Secure Lock Screen, real upstream video availability, or overnight reliability.

## Manual macOS acceptance checks

- Launch a local test video and confirm it loops with no sound.
- Place a normal application window over half the screen. Confirm the visible wallpaper area continues moving without clicking Finder.
- Switch apps and Spaces, and enter/leave Mission Control. Icons must stay clickable and normal windows must stay above the wallpaper.
- Reload a configured stream. Only black/video may appear; no website text or controls may appear.
- Disconnect/reconnect the network. Verify retry messages and recovery; local playback must remain independent of network availability.
- Pause/resume and change Fit. Test multiple displays and connect/disconnect a monitor.
- Start the service, close Terminal, and log out/in. Verify startup without a settings window.
- Kill only NightCockpit to verify service restart. Then use `service.command stop` and verify it stays stopped after login.
- Sleep/wake the Mac. Verify playback resumes without audio.
- Confirm the source URL host is allowed to serve the configured media. A successful regular-browser preview does not guarantee a standalone video stream will be accepted.

Lock Screen support is experimental and must not be described as verified until it passes a real macOS 26 check. Run setup, lock using Control-Command-Q, confirm the local video and lock-only audio, unlock and confirm silence, then test display sleep/wake. Stop/restore must restore the prior wallpaper. The helper runs pure configuration fixtures before installation; those tests do not prove system rendering or lock-event delivery.
