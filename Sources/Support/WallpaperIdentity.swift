import Foundation

/// Shared identity for the app, pure settings model, and native helper.
enum WallpaperIdentity {
    static let assetID = "8B5C4200-0000-4000-8000-000000000003"
    static let aerialProvider = "com.apple.wallpaper.choice.aerials"
    static let nativeProvider = "org.nightcockpit.app.wallpaper"
    static let nativeChoice = "night-cockpit"
    static func isOurChoice(_ value: Any?) -> Bool {
        guard let choice = value as? [String: Any], let content = choice["Content"] as? [String: Any],
              let item = (content["Choices"] as? [[String: Any]])?.first,
              let data = item["Configuration"] as? Data else { return false }
        if item["Provider"] as? String == nativeProvider { return data == Data(nativeChoice.utf8) }
        guard item["Provider"] as? String == aerialProvider,
              let config = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
        return config["assetID"] as? String == assetID
    }
    struct Coverage {
        var desktopCount = 0
        var saverCount = 0
        var wrongDesktops: [String] = []
        var wrongSavers: [String] = []
        var wallpaper: Bool { desktopCount > 0 && wrongDesktops.isEmpty }
        var screenSaver: Bool { saverCount > 0 && wrongSavers.isEmpty }
    }

    /// Every explicit override matters, including per-Space and per-display nodes.
    static func coverage(in store: [String: Any], requiredProvider: String? = nil) -> Coverage {
        var result = Coverage()
        func matches(_ value: Any?) -> Bool {
            guard isOurChoice(value) else { return false }
            guard let requiredProvider else { return true }
            let choice = value as? [String: Any]
            let content = choice?["Content"] as? [String: Any]
            return (content?["Choices"] as? [[String: Any]])?.first?["Provider"] as? String == requiredProvider
        }
        func walk(_ value: [String: Any], path: String) {
            if let linked = value["Linked"] {
                result.desktopCount += 1; result.saverCount += 1
                if !matches(linked) { result.wrongDesktops.append(path); result.wrongSavers.append(path) }
            } else {
                if let desktop = value["Desktop"] {
                    result.desktopCount += 1
                    if !matches(desktop) { result.wrongDesktops.append(path) }
                }
                if let idle = value["Idle"] {
                    result.saverCount += 1
                    if !matches(idle) { result.wrongSavers.append(path) }
                }
            }
            for (key, child) in value where !["Desktop", "Idle", "Linked"].contains(key) {
                if let dictionary = child as? [String: Any] { walk(dictionary, path: path + "/" + key) }
            }
        }
        walk(store, path: "")
        return result
    }

    static var nativeDesktopSelected: Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
        guard let data = try? Data(contentsOf: url),
              let store = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
        let current = coverage(in: store)
        return current.wallpaper && current.screenSaver
    }
}
