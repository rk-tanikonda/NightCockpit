import AppKit
import AVFoundation

/// A real system wallpaper under the player: startup and Spaces show our frame.
/// All backups live outside the repository and are restored only while still ours.
enum DesktopBackdrop {
    static let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/NightCockpit")
    static let poster = directory.appendingPathComponent("poster.png")
    static let record = directory.appendingPathComponent("DesktopBackup.plist")

    static func screenID(_ screen: NSScreen) -> String {
        String((screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0)
    }

    static func image(for video: URL) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        let (image, _) = try await generator.image(at: .zero)
        return image
    }

    @MainActor
    static func install(_ image: CGImage, updateSystemWallpaper: Bool = true) async throws {
        let data = try await Task.detached(priority: .utility) {
            guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw NSError(domain: "NightCockpit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot prepare the background frame."])
            }
            return png
        }.value
        try Task.checkCancellation()
        let files = FileManager.default
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        // Native registration and public desktop fallback share the first backup.
        let backup = directory.appendingPathComponent("LockScreenBackup")
        let index = files.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
        if files.fileExists(atPath: index.path), !files.fileExists(atPath: backup.appendingPathComponent("Index.plist").path) {
            try files.createDirectory(at: backup, withIntermediateDirectories: true)
            try files.copyItem(at: index, to: backup.appendingPathComponent("Index.plist"))
        }
        if !files.fileExists(atPath: record.path) {
            var entries: [String: String] = [:]
            for screen in NSScreen.screens {
                if let url = NSWorkspace.shared.desktopImageURL(for: screen), url != poster {
                    entries[screenID(screen)] = url.absoluteString
                }
            }
            try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0).write(to: record, options: .atomic)
        }
        try data.write(to: poster, options: .atomic)
        guard updateSystemWallpaper else { return }
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(poster, for: screen, options: [
                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: true
            ])
        }
    }

    static func restore() throws {
        guard let data = try? Data(contentsOf: record),
              let original = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else { return }
        for screen in NSScreen.screens where NSWorkspace.shared.desktopImageURL(for: screen) == poster {
            if let value = original[screenID(screen)], let url = URL(string: value) {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            }
        }
    }
}
