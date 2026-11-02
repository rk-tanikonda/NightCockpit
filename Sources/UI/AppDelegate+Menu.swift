import AppKit
import Darwin

extension AppDelegate {
    func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.toolTip = "Night Cockpit"
        let menu = NSMenu()
        addMenuItem(menu, title: "Settings / status…", action: #selector(showControls))
        addMenuItem(menu, title: "Change video…", action: #selector(chooseVideo), key: "o")
        if Bundle.main.url(forResource: "night-cockpit", withExtension: "mp4") == nil {
            addMenuItem(menu, title: "Use configured stream", action: #selector(useConfiguredStream))
        }
        addMenuItem(menu, title: "Reload wallpaper", action: #selector(reloadWallpaper))
        pauseItem = addMenuItem(menu, title: "Pause", action: #selector(togglePause), key: "p")
        fitItem = addMenuItem(menu, title: "Fit entire video", action: #selector(toggleFit))
        fitItem.state = settings.fit ? .on : .off
        displayItem = addMenuItem(menu, title: "Main display only", action: #selector(toggleDisplay))
        displayItem.state = settings.mainDisplayOnly ? .on : .off
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
        if let tool = Bundle.main.url(forResource: "lockscreen-tool", withExtension: nil),
           FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/NightCockpit/LockScreenBackup/Index.plist").path) {
            let restore = Process()
            restore.executableURL = tool
            restore.arguments = ["restore"]
            do { try restore.run(); restore.waitUntilExit() } catch { setStatus(error.localizedDescription) }
        }
        // Disable auto-start first, so deliberately stopping does not cause a restart.
        let job = "gui/\(getuid())/local.ramakrishna.nightcockpit.agent"
        runLaunchctl(["disable", job])
        runLaunchctl(["bootout", job])
        NSApp.terminate(nil)
    }

    private func runLaunchctl(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            setStatus("Could not update background service: \(error.localizedDescription)")
        }
    }
}
