import Foundation
import Darwin

/// The app stages private local media here; the sandboxed native extension has
/// read-only access to this one directory, not arbitrary user-selected paths.
enum NativePlaybackSettings {
    static let providerID = "org.nightcockpit.app.wallpaper"
    static let choiceID = "night-cockpit"
    static var directory: URL {
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/NightCockpit/NativePlayback")
    }
    static var file: URL { directory.appendingPathComponent("Configuration.plist") }
    static var movieURL: URL { directory.appendingPathComponent("movie.mp4") }
    static var posterURL: URL { directory.appendingPathComponent("poster.png") }
    static var values: [String: Any] {
        guard let data = try? Data(contentsOf: file),
              let value = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [:] }
        return value
    }
    static var enabled: Bool { values["enabled"] as? Bool ?? false }
    static var soundEnabled: Bool { values["sound"] as? Bool ?? true }
    static func setSound(_ enabled: Bool) throws {
        var config = values; config["sound"] = enabled
        try PropertyListSerialization.data(fromPropertyList: config, format: .binary, options: 0).write(to: file, options: .atomic)
        DistributedNotificationCenter.default().postNotificationName(Notification.Name("org.nightcockpit.native.settingsChanged"), object: nil, userInfo: nil, deliverImmediately: true)
    }
}
