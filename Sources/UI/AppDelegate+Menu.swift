import AppKit
import Darwin

extension AppDelegate {
    func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.toolTip = "Night Cockpit"
        let menu = NSMenu()
        addMenuItem(menu, title: "Settings / status…", action: #selector(showControls))
        addMenuItem(menu, title: "Change video…", action: #selector(chooseVideo), key: "o")
        addMenuItem(menu, title: "Reload wallpaper", action: #selector(reloadWallpaper))
        pauseItem = addMenuItem(menu, title: "Pause", action: #selector(togglePause), key: "p")
        fitItem = addMenuItem(menu, title: "Fit entire video", action: #selector(toggleFit))
        fitItem.state = settings.fit ? .on : .off
        displayItem = addMenuItem(menu, title: "Main display only", action: #selector(toggleDisplay))
        displayItem.state = settings.mainDisplayOnly ? .on : .off
        if #available(macOS 26.0, *) {
            addMenuItem(menu, title: "Apply video to Lock Screen", action: #selector(applyNativeWallpaper))
        }
        menu.addItem(.separator())
        let sound = addMenuItem(menu, title: "Sound while locked", action: #selector(toggleLockSound(_:)))
        sound.state = lockAudio.enabled ? .on : .off
        addMenuItem(menu, title: "Stop wallpaper", action: #selector(stopWallpaper), key: "q")
        statusItem.menu = menu
        updatePlayback()
    }

    @discardableResult
    func addMenuItem(_ menu: NSMenu, title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc func toggleLockSound(_ sender: NSMenuItem) {
        lockAudio.enabled.toggle()
        sender.state = lockAudio.enabled ? .on : .off
    }

    @objc func stopWallpaper() {
        // Disable lock repair before restoration and keep the UI responsive.
        state.stopping = true
        lockAudio.nativeReady = false
        updatePlayback()
        loadTask?.cancel()
        nativeWallpaper.cancel()
        nativeWallpaper.run("restore") { [weak self] result in
            if case .failure(let error) = result { self?.setStatus(error.localizedDescription); return }
            self?.finishStopping()
        }
        if Bundle.main.url(forResource: "lockscreen-tool", withExtension: nil) == nil { finishStopping() }
    }

    private func finishStopping() {
        do { try DesktopBackdrop.restore() } catch { setStatus(error.localizedDescription); return }
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        runLaunchctl(["disable", "gui/\(getuid())/\(bundleID).agent"]) { [weak self] in
            self?.runLaunchctl(["bootout", "gui/\(getuid())/\(bundleID).agent"]) {
                NSApp.terminate(nil)
            }
        }
    }

    private func runLaunchctl(_ arguments: [String], completion: @escaping () -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in DispatchQueue.main.async { completion() } }
        do { try process.run() } catch { setStatus(error.localizedDescription); completion() }
    }
}
