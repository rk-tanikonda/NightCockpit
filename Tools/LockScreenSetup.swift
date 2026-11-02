import AppKit
import AVFoundation

/// macOS 26's aerial configuration is undocumented and may change with updates.
/// This tool validates schemas, backs up both settings files, and supports restore.
@main
struct LockScreenSetup {
    static let files = FileManager.default
    static let home = files.homeDirectoryForCurrentUser
    static let aerials = home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials")
    static let manifest = aerials.appendingPathComponent("manifest/entries.json")
    static let store = home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    static let backup = home.appendingPathComponent("Library/Application Support/NightCockpit/LockScreenBackup")

    static func main() async {
        do {
            guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else {
                throw LockScreenModel.failure("Native Lock Screen registration requires macOS 26+. Desktop playback still works.")
            }
            switch CommandLine.arguments.dropFirst().first ?? "status" {
            case "install":
                guard CommandLine.arguments.count == 3 else { throw LockScreenModel.failure("Pass a local video file.") }
                try await install(URL(fileURLWithPath: CommandLine.arguments[2]))
            case "restore": try restore()
            case "status":
                print("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                print("Aerial manifest: \(files.fileExists(atPath: manifest.path) ? "available" : "missing")")
                print("Restore backup: \(files.fileExists(atPath: backup.path) ? "available" : "missing")")
            default: throw LockScreenModel.failure("Use install, restore, or status.")
            }
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }

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
        let nextManifest = try LockScreenModel.register(in: currentManifest, video: video, thumbnail: thumbnail)
        let nextStore = try LockScreenModel.choose(in: currentStore)
        try files.createDirectory(at: video.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.createDirectory(at: thumbnail.deletingLastPathComponent(), withIntermediateDirectories: true)
        let asset = AVURLAsset(url: source)
        guard !(try await asset.loadTracks(withMediaType: .video)).isEmpty else {
            throw LockScreenModel.failure("The selected file has no video track.")
        }
        print("Preparing the local video for macOS's Lock Screen. HEVC conversion may take a few minutes…")
        let temporary = video.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".mov")
        defer { try? files.removeItem(at: temporary) }
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            throw LockScreenModel.failure("HEVC export is unavailable on this Mac.")
        }
        exporter.outputURL = temporary
        exporter.outputFileType = .mov
        await exporter.export()
        guard exporter.status == .completed else {
            throw exporter.error ?? LockScreenModel.failure("The Lock Screen video conversion failed.")
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let image = try generator.copyCGImage(at: .zero, actualTime: nil)
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw LockScreenModel.failure("Could not create the video thumbnail.")
        }
        try files.createDirectory(at: backup, withIntermediateDirectories: true)
        try backUpOnce(manifestData, name: "entries.json")
        try backUpOnce(storeData, name: "Index.plist")
        if files.fileExists(atPath: video.path) { _ = try files.replaceItemAt(video, withItemAt: temporary) }
        else { try files.moveItem(at: temporary, to: video) }
        try png.write(to: thumbnail, options: .atomic)
        let encodedManifest = try JSONSerialization.data(withJSONObject: nextManifest, options: [.prettyPrinted, .sortedKeys])
        let encodedStore = try PropertyListSerialization.data(fromPropertyList: nextStore, format: .binary, options: 0)
        do {
            try encodedManifest.write(to: manifest, options: .atomic)
            try encodedStore.write(to: store, options: .atomic)
        } catch {
            try? manifestData.write(to: manifest, options: .atomic)
            try? storeData.write(to: store, options: .atomic)
            throw error
        }
        reloadAgent()
        print("Registered Night Cockpit in the native Lock Screen wallpaper settings.")
        print("Lock with Control-Command-Q to verify. Audio is a separate helper and may not be frame-synchronized.")
    }

    static func restore() throws {
        let oldStore = try Data(contentsOf: backup.appendingPathComponent("Index.plist"))
        let liveStore = try Data(contentsOf: store)
        guard let original = try PropertyListSerialization.propertyList(from: oldStore, format: nil) as? [String: Any],
              let current = try PropertyListSerialization.propertyList(from: liveStore, format: nil) as? [String: Any],
              let currentManifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any] else {
            throw LockScreenModel.failure("Could not read restore data. Current settings were preserved.")
        }
        let restored = LockScreenModel.restore(current: current, original: original)
        try PropertyListSerialization.data(fromPropertyList: restored, format: .binary, options: 0).write(to: store, options: .atomic)
        try JSONSerialization.data(withJSONObject: LockScreenModel.removeOurAsset(from: currentManifest), options: [.prettyPrinted, .sortedKeys]).write(to: manifest, options: .atomic)
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
        process.arguments = ["WallpaperAgent"]
        process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit() } catch { print("Log out/in if the wallpaper has not refreshed.") }
    }
}
