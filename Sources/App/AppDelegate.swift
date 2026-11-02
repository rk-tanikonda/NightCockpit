import AppKit
import AVFoundation

/// Coordinates settings, playback engines and UI. Rendering lives in Playback/.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = WallpaperSettings()
    var statusItem: NSStatusItem!
    var pauseItem: NSMenuItem!
    var fitItem: NSMenuItem!
    var displayItem: NSMenuItem!
    var controlWindow: NSWindow?
    let statusLabel = NSTextField(wrappingLabelWithString: "Starting…")
    var playbacks: [WallpaperPlayback] = []
    var selectedURL: URL?
    var usingStream = false
    var manuallyPaused = false
    var suspended = false
    var loadTask: Task<Void, Never>?
    var generation = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        observeWorkspace()
        if !CommandLine.arguments.contains("--background") { showControls() }
        if !settings.streamMode, let path = settings.videoPath,
           FileManager.default.isReadableFile(atPath: path) {
            loadLocalVideo(URL(fileURLWithPath: path))
        } else {
            usingStream = true
            rebuildPlayback()
        }
    }

    /// Validate a new file before replacing a working wallpaper.
    func loadLocalVideo(_ url: URL) {
        loadTask?.cancel()
        generation += 1
        let expectedGeneration = generation
        setStatus("Opening \(url.lastPathComponent)…")
        loadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let asset = AVURLAsset(url: url)
                let playable = try await asset.load(.isPlayable)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                let duration = try await asset.load(.duration)
                guard !Task.isCancelled, self.generation == expectedGeneration else { return }
                guard playable, !tracks.isEmpty, duration.seconds.isFinite, duration.seconds > 0 else {
                    self.setStatus("Choose a playable MP4 or MOV with a video track.")
                    return
                }
                self.selectedURL = url
                self.usingStream = false
                self.settings.videoPath = url.path
                self.settings.streamMode = false
                self.rebuildPlayback()
            } catch {
                guard !Task.isCancelled, self.generation == expectedGeneration else { return }
                self.setStatus("Could not open video: \(error.localizedDescription)")
            }
        }
    }

    func rebuildPlayback() {
        playbacks.forEach { $0.close() }
        playbacks.removeAll()
        let screens = settings.mainDisplayOnly ? Array(NSScreen.screens.prefix(1)) : NSScreen.screens
        for screen in screens {
            if usingStream, let url = settings.streamURL {
                playbacks.append(StreamVideoPlayback(screen: screen, url: url, fit: settings.fit) { [weak self] in
                    self?.setStatus($0)
                })
            } else if !usingStream, let url = selectedURL {
                playbacks.append(LocalVideoPlayback(screen: screen, url: url, fit: settings.fit) { [weak self] in
                    self?.setStatus($0)
                })
            }
        }
        if playbacks.isEmpty {
            setStatus("No video configured. Choose a local video, or set streamURL in wallpaper.local.json and rebuild.")
        } else if usingStream {
            setStatus("Loading video stream…")
        } else {
            setStatus("Local video loaded. Desktop playback is muted.")
        }
        updatePlayback()
    }

    func updatePlayback() {
        let paused = manuallyPaused || suspended
        playbacks.forEach { $0.setPaused(paused) }
        pauseItem.title = manuallyPaused ? "Resume" : "Pause"
        statusItem.button?.image = NSImage(
            systemSymbolName: paused ? "pause.rectangle.fill" : "play.rectangle.fill",
            accessibilityDescription: "Night Cockpit"
        )
    }

    @objc func useConfiguredStream() {
        guard settings.streamURL != nil else {
            setStatus("Set an HTTPS streamURL in wallpaper.local.json and rebuild, or choose a local video.")
            return
        }
        loadTask?.cancel()
        generation += 1
        usingStream = true
        settings.streamMode = true
        rebuildPlayback()
    }

    @objc func reloadWallpaper() {
        loadTask?.cancel()
        generation += 1
        rebuildPlayback()
    }
    @objc func togglePause() { manuallyPaused.toggle(); updatePlayback() }
    @objc func toggleFit() {
        settings.fit.toggle()
        fitItem.state = settings.fit ? .on : .off
        playbacks.forEach { $0.setFit(settings.fit) }
    }
    @objc func toggleDisplay() {
        settings.mainDisplayOnly.toggle()
        displayItem.state = settings.mainDisplayOnly ? .on : .off
        rebuildPlayback()
    }
    @objc func screensChanged() { rebuildPlayback() }
    @objc func sleepPlayback() { suspended = true; updatePlayback() }
    @objc func wakePlayback() { suspended = false; updatePlayback(); refreshWindowOrder() }

    /// Reassert desktop ordering when apps or Spaces change; never raise above apps.
    @objc func refreshWindowOrder() {
        playbacks.forEach { $0.window.orderFrontRegardless() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControls()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        loadTask?.cancel()
        playbacks.forEach { $0.close() }
    }
}
