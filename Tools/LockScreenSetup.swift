import AppKit
import AVFoundation
import Darwin

/// macOS 26's aerial configuration is undocumented and may change with updates.
/// This tool validates schemas, backs up both settings files, and supports restore.
@main
struct LockScreenSetup {
    static let files = FileManager.default
    static let home = files.homeDirectoryForCurrentUser
    static let aerials = home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials")
    static let manifest = aerials.appendingPathComponent("manifest/entries.json")
    static let store = home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    static let sourceRecord = DesktopBackdrop.directory.appendingPathComponent("NativeMovieSource.plist")
    static let backup = home.appendingPathComponent("Library/Application Support/NightCockpit/LockScreenBackup")

    @MainActor
    static func main() async {
        do {
            guard #available(macOS 26.0, *) else {
                throw LockScreenModel.failure("Native Lock Screen registration requires macOS 26+. Desktop playback still works.")
            }
            let command = CommandLine.arguments.dropFirst().first ?? "status"
            let descriptor = command == "status" ? -1 : try acquireWriteLock()
            defer { if descriptor >= 0 { flock(descriptor, LOCK_UN); close(descriptor) } }
            switch command {
            case "install":
                guard CommandLine.arguments.count == 3 else { throw LockScreenModel.failure("Pass a local video file.") }
                try await install(URL(fileURLWithPath: CommandLine.arguments[2]))
                try await repairAndVerify()
            case "repair": try await repairAndVerify()
            case "restore": try restore()
            case "status": try await status()
            default: throw LockScreenModel.failure("Use install, repair, restore, or status.")
            }
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }

    static func acquireWriteLock() throws -> Int32 {
        try files.createDirectory(at: DesktopBackdrop.directory, withIntermediateDirectories: true)
        let lock = DesktopBackdrop.directory.appendingPathComponent("NativeConfiguration.lock")
        let descriptor = open(lock.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw LockScreenModel.failure("Cannot open the native configuration lock.") }
        guard flock(descriptor, LOCK_EX) == 0 else {
            close(descriptor); throw LockScreenModel.failure("Cannot lock native configuration.")
        }
        return descriptor
    }

    static func repairAndVerify() async throws {
        // NSWorkspace's poster update can commit after its public API returns.
        // Re-read the live store between bounded attempts, never write a stale snapshot.
        for attempt in 0..<3 {
            try repair()
            try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 500_000_000)
            guard let settings = try PropertyListSerialization.propertyList(from: Data(contentsOf: store), format: nil) as? [String: Any] else {
                throw LockScreenModel.failure("Cannot verify native wallpaper selection.")
            }
            let chosen = LockScreenModel.selection(in: settings)
            if chosen.wallpaper && chosen.screenSaver { return }
        }
        throw LockScreenModel.failure("macOS did not retain the native selection. Close the Wallpaper settings pane and apply again.")
    }

    static func status() async throws {
        print("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Aerial manifest: \(files.fileExists(atPath: manifest.path) ? "available" : "missing")")
        print("Restore backup: \(files.fileExists(atPath: backup.appendingPathComponent("Index.plist").path) ? "available" : "missing")")
        if files.fileExists(atPath: store.path) {
            guard let settings = try PropertyListSerialization.propertyList(from: Data(contentsOf: store), format: nil) as? [String: Any] else {
                throw LockScreenModel.failure("Cannot read native wallpaper settings.")
            }
            let coverage = WallpaperIdentity.coverage(in: settings)
            let selected = LockScreenModel.selection(in: settings)
            print("Verified desktop choices: \(coverage.desktopCount - coverage.wrongDesktops.count)/\(coverage.desktopCount)")
            print("Verified screen saver choices: \(coverage.saverCount - coverage.wrongSavers.count)/\(coverage.saverCount)")
            print("Native wallpaper selected: \(selected.wallpaper ? "yes" : "no")")
            print("Native screen saver selected: \(selected.screenSaver ? "yes" : "no")")
            if selected.wallpaper && !selected.screenSaver {
                print("Desktop-only configuration detected. Run lockscreen.command install to configure animation for both slots.")
            }
        }
        let movie = aerials.appendingPathComponent("videos/\(LockScreenModel.assetID).mov")
        if files.fileExists(atPath: movie.path) {
            let asset = AVURLAsset(url: movie)
            let playable = try await asset.load(.isPlayable)
            let duration = try await asset.load(.duration)
            print("Native movie: \(playable ? "playable" : "not playable"), \(String(format: "%.1f", duration.seconds)) seconds")
            print("Temporal replay layers: \(try MovieFormat.supportsNativeReplay(movie) ? "present" : "missing")")
        } else {
            print("Native movie: missing")
        }
    }

    @available(macOS 26.0, *)
    static func install(_ source: URL) async throws {
        guard files.fileExists(atPath: manifest.path), files.fileExists(atPath: store.path) else {
            throw LockScreenModel.failure("Open System Settings > Wallpaper and select/download an Apple aerial once, then run setup again. No wallpaper settings were changed.")
        }
        let manifestData = try Data(contentsOf: manifest)
        let storeData = try Data(contentsOf: store)
        guard let currentManifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              let currentStore = try PropertyListSerialization.propertyList(from: storeData, format: nil) as? [String: Any] else {
            throw LockScreenModel.failure("Cannot read the current wallpaper settings.")
        }
        let video = aerials.appendingPathComponent("videos/\(LockScreenModel.assetID).mov")
        let thumbnail = aerials.appendingPathComponent("thumbnails/\(LockScreenModel.assetID).png")
        // Validate both configuration structures before conversion or any settings write.
        _ = try LockScreenModel.register(in: currentManifest, video: video, thumbnail: thumbnail)
        _ = try LockScreenModel.choose(in: currentStore)
        try files.createDirectory(at: video.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.createDirectory(at: thumbnail.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = video.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".mov")
        defer { try? files.removeItem(at: temporary) }
        print("Preparing the local video for macOS's Lock Screen. HEVC conversion may take a few minutes…")
        let png = try await VideoPreparation.prepare(source: source, destination: temporary)
        try files.createDirectory(at: backup, withIntermediateDirectories: true)
        try backUpOnce(manifestData, name: "entries.json")
        try backUpOnce(storeData, name: "Index.plist")
        if files.fileExists(atPath: video.path) { _ = try files.replaceItemAt(video, withItemAt: temporary) }
        else { try files.moveItem(at: temporary, to: video) }
        try png.write(to: thumbnail, options: .atomic)
        let attributes = try files.attributesOfItem(atPath: source.path)
        let metadata: [String: Any] = ["path": source.path, "size": attributes[.size] ?? 0, "modified": attributes[.modificationDate] ?? Date()]
        try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0).write(to: sourceRecord, options: .atomic)
        // Replacing a movie at the same URL must invalidate the renderer's
        // cached player even when the catalogue and selections are unchanged.
        if !(try repair()) { reloadAgent() }
        print("Registered Night Cockpit as the native wallpaper and screen saver.")
        print("Lock with Control-Command-Q to verify. Audio is a separate helper and may not be frame-synchronized.")
    }

    /// Restore a lost catalogue/selection using the prepared movie, without re-encoding.
    @discardableResult
    static func repair() throws -> Bool {
        let video = aerials.appendingPathComponent("videos/\(LockScreenModel.assetID).mov")
        let thumbnail = aerials.appendingPathComponent("thumbnails/\(LockScreenModel.assetID).png")
        guard files.fileExists(atPath: video.path), files.fileExists(atPath: thumbnail.path), files.fileExists(atPath: sourceRecord.path) else {
            throw LockScreenModel.failure("Apply your video to the Lock Screen once before repairing it.")
        }
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27,
           !(try MovieFormat.supportsNativeReplay(video)) {
            throw LockScreenModel.failure("The old movie lacks macOS 27 temporal layers. Apply the video to the Lock Screen again.")
        }
        let manifestData = try Data(contentsOf: manifest)
        let storeData = try Data(contentsOf: store)
        guard let liveManifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              let liveStore = try PropertyListSerialization.propertyList(from: storeData, format: nil) as? [String: Any] else {
            throw LockScreenModel.failure("Cannot read current native wallpaper settings.")
        }
        let nextManifest = try LockScreenModel.register(in: liveManifest, video: video, thumbnail: thumbnail)
        let selected = LockScreenModel.selection(in: liveStore)
        let manifestChanged = !NSDictionary(dictionary: liveManifest).isEqual(to: nextManifest)
        guard manifestChanged || !selected.wallpaper || !selected.screenSaver else { return false }
        let nextStore = try LockScreenModel.choose(in: liveStore)
        // Poster fallback may already have backed up the native store.
        try files.createDirectory(at: backup, withIntermediateDirectories: true)
        try backUpOnce(manifestData, name: "entries.json")
        try backUpOnce(storeData, name: "Index.plist")
        do {
            try JSONSerialization.data(withJSONObject: nextManifest, options: [.prettyPrinted, .sortedKeys]).write(to: manifest, options: .atomic)
            try PropertyListSerialization.data(fromPropertyList: nextStore, format: .binary, options: 0).write(to: store, options: .atomic)
        } catch {
            try? manifestData.write(to: manifest, options: .atomic)
            try? storeData.write(to: store, options: .atomic)
            throw error
        }
        reloadAgent()
        return true
    }

    static func restore() throws {
        guard files.fileExists(atPath: backup.appendingPathComponent("Index.plist").path) else {
            try DesktopBackdrop.restore(); return
        }
        let oldStore = try Data(contentsOf: backup.appendingPathComponent("Index.plist"))
        let liveStore = try Data(contentsOf: store)
        let liveManifest = try Data(contentsOf: manifest)
        guard let original = try PropertyListSerialization.propertyList(from: oldStore, format: nil) as? [String: Any],
              let current = try PropertyListSerialization.propertyList(from: liveStore, format: nil) as? [String: Any],
              let currentManifest = try JSONSerialization.jsonObject(with: liveManifest) as? [String: Any] else {
            throw LockScreenModel.failure("Could not read restore data. Current settings were preserved.")
        }
        let restored = LockScreenModel.restore(current: current, original: original)
        let encodedStore = try PropertyListSerialization.data(fromPropertyList: restored, format: .binary, options: 0)
        let encodedManifest = try JSONSerialization.data(withJSONObject: LockScreenModel.removeOurAsset(from: currentManifest), options: [.prettyPrinted, .sortedKeys])
        do {
            try encodedStore.write(to: store, options: .atomic)
            try encodedManifest.write(to: manifest, options: .atomic)
        } catch {
            try? liveStore.write(to: store, options: .atomic)
            try? liveManifest.write(to: manifest, options: .atomic)
            throw error
        }
        reloadAgent()
        print("Restored our wallpaper choices. Other current wallpaper assets were preserved.")
    }

    static func backUpOnce(_ data: Data, name: String) throws {
        let destination = backup.appendingPathComponent(name)
        if !files.fileExists(atPath: destination.path) { try data.write(to: destination, options: .atomic) }
    }

    static func reloadAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        // The aerial renderer can outlive WallpaperAgent and retain a stale player.
        process.arguments = ["WallpaperAerialsExtension", "WallpaperAgent"]
        process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit() } catch { print("Log out/in if the wallpaper has not refreshed.") }
    }
}
