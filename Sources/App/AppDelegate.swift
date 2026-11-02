import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = WallpaperSettings()
    let lockAudio = LockAudioController()
    let lockDisplay = LockDisplayController()
    let nativeWallpaper = NativeWallpaperController()
    var statusItem: NSStatusItem!
    var pauseItem: NSMenuItem!
    var fitItem: NSMenuItem!
    var displayItem: NSMenuItem!
    var controlWindow: NSWindow?
    let statusLabel = NSTextField(wrappingLabelWithString: "Starting…")
    var playbacks: [LocalVideoPlayback] = []
    var selectedURL: URL?
    var poster: CGImage?
    var state = PlaybackState()
    var loadTask: Task<Void, Never>?
    var maintenanceTask: Task<Void, Never>?
    var generation = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        observeWorkspace()
        if !CommandLine.arguments.contains("--background") { showControls() }
        if let path = settings.videoPath, FileManager.default.isReadableFile(atPath: path) {
            loadLocalVideo(URL(fileURLWithPath: path))
        } else if let bundled = WallpaperSettings.bundledVideoURL { loadLocalVideo(bundled) }
        else { setStatus("Choose a local video to start your wallpaper."); showControls() }
    }

    func loadLocalVideo(_ url: URL) {
        loadTask?.cancel()
        generation += 1
        let expected = generation
        setStatus("Preparing \(url.lastPathComponent)…")
        loadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration)
                guard try await asset.load(.isPlayable), duration.seconds.isFinite, duration.seconds > 0,
                      !(try await asset.loadTracks(withMediaType: .video)).isEmpty else {
                    self.setStatus("Choose a playable MP4 or MOV."); return
                }
                let image = try await DesktopBackdrop.image(for: url)
                guard !Task.isCancelled, self.generation == expected else { return }
                // Keep old windows until the replacement video and poster are ready.
                let old = self.playbacks
                self.playbacks = []
                self.selectedURL = url
                self.poster = image
                self.settings.videoPath = url.path
                self.reconcileScreens()
                old.forEach { $0.close() }
                self.lockAudio.configure(url)
                // The poster setter must never replace a configured native aerial.
                // Native repair owns every Space/display in this mode.
                try await DesktopBackdrop.install(image, updateSystemWallpaper: !self.settings.nativeEnabled)
                self.repairNativeWallpaper()
                self.setStatus("Local video loaded. Desktop playback is muted.")
            } catch {
                guard !Task.isCancelled, self.generation == expected else { return }
                self.setStatus("Could not prepare wallpaper: \(error.localizedDescription)")
                self.showControls()
            }
        }
    }

    func reconcileScreens() {
        guard let url = selectedURL, let poster else { return }
        let screens = settings.mainDisplayOnly ? Array(NSScreen.screens.prefix(1)) : NSScreen.screens
        let wanted = Set(screens.map(DesktopBackdrop.screenID))
        let removed = playbacks.filter { !wanted.contains($0.screenID) }
        playbacks.removeAll { !wanted.contains($0.screenID) }
        removed.forEach { $0.close() }
        for screen in screens {
            if let current = playbacks.first(where: { $0.screenID == DesktopBackdrop.screenID(screen) }) {
                current.updateScreen(screen)
            } else {
                playbacks.append(LocalVideoPlayback(screen: screen, url: url, poster: poster, fit: settings.fit) { [weak self] in self?.setStatus($0) })
            }
        }
        updatePlayback()
    }

    @objc func applyNativeWallpaper() {
        guard let url = selectedURL else { return }
        settings.nativeEnabled = true
        lockAudio.nativeReady = false
        setStatus("Preparing the Lock Screen video…")
        nativeWallpaper.run("synchronize", video: url) { [weak self] result in
            switch result {
            case .success:
                self?.lockAudio.nativeReady = true
                self?.setStatus("Desktop and native Lock Screen are ready.")
            case .failure(let error): self?.setStatus(error.localizedDescription)
            }
        }
    }

    func repairNativeWallpaper() {
        guard state.shouldRepairNative(settings.nativeEnabled) else { return }
        if let url = selectedURL,
           let data = try? Data(contentsOf: DesktopBackdrop.directory.appendingPathComponent("NativeMovieSource.plist")),
           let record = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           record["path"] as? String != url.path {
            applyNativeWallpaper(); return
        }
        nativeWallpaper.run("repair") { [weak self] result in
            if case .failure(let error) = result {
                self?.lockAudio.nativeReady = false
                self?.setStatus(error.localizedDescription)
            } else { self?.lockAudio.nativeReady = true }
        }
    }

    func updatePlayback() {
        lockDisplay.setActive(state.shouldHoldLockDisplay(settings.keepLockDisplayAwake, nativeEnabled: settings.nativeEnabled) && selectedURL != nil)
        playbacks.forEach { $0.setPaused(state.shouldPause) }
        pauseItem.title = state.manuallyPaused ? "Resume" : "Pause"
        statusItem.button?.image = NSImage(systemSymbolName: state.manuallyPaused ? "pause.rectangle.fill" : "play.rectangle.fill", accessibilityDescription: "Night Cockpit")
    }
    @objc func reloadWallpaper() { if let url = selectedURL { loadLocalVideo(url) } }
    @objc func togglePause() { state.manuallyPaused.toggle(); updatePlayback() }
    @objc func toggleFit() {
        settings.fit.toggle(); fitItem.state = settings.fit ? .on : .off
        playbacks.forEach { $0.setFit(settings.fit) }
    }
    @objc func toggleDisplay() {
        settings.mainDisplayOnly.toggle(); displayItem.state = settings.mainDisplayOnly ? .on : .off
        reconcileScreens()
    }
    @objc func screensChanged() { reconcileScreens(); checkNativeSelection() }
    @objc func checkNativeSelection() {
        maintenanceTask?.cancel()
        guard state.shouldRepairNative(settings.nativeEnabled) else { return }
        // Wait for the Space/unlock transition to finish before any native I/O.
        maintenanceTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 1_500_000_000) }
            catch { return }
            guard let self, !Task.isCancelled, self.state.shouldRepairNative(self.settings.nativeEnabled) else { return }
            if !WallpaperIdentity.nativeDesktopSelected { self.repairNativeWallpaper() }
            self.maintenanceTask = nil
        }
    }

    func suspendNativeMaintenance() {
        maintenanceTask?.cancel(); maintenanceTask = nil
        nativeWallpaper.cancelRepair()
    }
    @objc func displaySlept() { state.displayAsleep = true; updatePlayback(); suspendNativeMaintenance() }
    @objc func displayWoke() { state.displayAsleep = false; reconcileScreens(); checkNativeSelection() }
    @objc func systemSlept() { state.systemAsleep = true; updatePlayback(); suspendNativeMaintenance() }
    @objc func systemWoke() { state.systemAsleep = false; reconcileScreens(); checkNativeSelection() }
    @objc func sessionResigned() { state.sessionActive = false; updatePlayback(); suspendNativeMaintenance() }
    @objc func sessionActivated() { state.sessionActive = true; updatePlayback(); checkNativeSelection() }
    @objc func screenLocked() {
        state.locked = true
        updatePlayback()
        suspendNativeMaintenance()
    }
    @objc func screenUnlocked() { state.unlock(); updatePlayback(); checkNativeSelection() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showControls(); return true }
    func applicationWillTerminate(_ notification: Notification) {
        lockDisplay.stop()
        loadTask?.cancel(); maintenanceTask?.cancel(); nativeWallpaper.cancel(); lockAudio.stop()
        playbacks.forEach { $0.close() }
    }
}
