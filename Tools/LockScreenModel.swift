// Portions adapted from W-Player's AerialsManifest and WallpaperChoice.
// Copyright 2026 W-Player contributors. Apache-2.0; see LICENSES/Apache-2.0.txt.
// Changed: one Night Cockpit asset, strict schema validation and selective restore.
import Foundation

enum LockScreenModel {
    static let categoryID = "8B5C4200-0000-4000-8000-000000000001"
    static let subcategoryID = "8B5C4200-0000-4000-8000-000000000002"
    static let assetID = WallpaperIdentity.assetID
    static let provider = WallpaperIdentity.aerialProvider

    static func register(in manifest: [String: Any], video: URL, thumbnail: URL) throws -> [String: Any] {
        guard var assets = manifest["assets"] as? [[String: Any]],
              var categories = manifest["categories"] as? [[String: Any]] else {
            throw failure("Unsupported aerial manifest. No settings were changed.")
        }
        assets.removeAll { ($0["id"] as? String) == assetID }
        categories.removeAll { ($0["id"] as? String) == categoryID }
        let cover: [String: Any] = ["previewImage": thumbnail.absoluteString, "representativeAssetID": assetID]
        var subcategory: [String: Any] = ["id": subcategoryID, "localizedNameKey": "Night Cockpit", "localizedDescriptionKey": "Night Cockpit", "preferredOrder": 0]
        subcategory.merge(cover) { _, new in new }
        var category: [String: Any] = ["id": categoryID, "localizedNameKey": "Night Cockpit", "localizedDescriptionKey": "Night Cockpit", "preferredOrder": 0, "subcategories": [subcategory]]
        category.merge(cover) { _, new in new }
        categories.append(category)
        assets.append([
            "id": assetID, "accessibilityLabel": "Night Cockpit", "localizedNameKey": "Night Cockpit",
            "categories": [categoryID], "subcategories": [subcategoryID], "includeInShuffle": false,
            "showInTopLevel": true, "pointsOfInterest": [String: Any](), "preferredOrder": 0,
            "previewImage": thumbnail.absoluteString, "shotID": "NIGHTCOCKPIT",
            "url-4K-SDR-240FPS": video.absoluteString
        ])
        var result = manifest
        result["assets"] = assets
        result["categories"] = categories
        return result
    }

    static func choose(in store: [String: Any]) throws -> [String: Any] {
        let config = try PropertyListSerialization.data(fromPropertyList: ["assetID": assetID], format: .binary, options: 0)
        let choice: [String: Any] = [
            "Content": ["Choices": [["Provider": provider, "Configuration": config, "Files": [Any]()]],
                        "Shuffle": "$null", "EncodedOptionValues": "$null"],
            "LastSet": Date(), "LastUse": Date()
        ]
        var count = 0
        func walk(_ value: Any) -> Any {
            guard var dictionary = value as? [String: Any] else { return value }
            if dictionary["Desktop"] != nil || dictionary["Idle"] != nil || dictionary["Linked"] != nil {
                count += 1
                if dictionary["Type"] as? String == "idle", dictionary["Desktop"] == nil, dictionary["Linked"] == nil {
                    // macOS retains a global Idle-only node with separate Spaces.
                    dictionary["Idle"] = choice
                } else {
                    dictionary.removeValue(forKey: "Desktop")
                    dictionary.removeValue(forKey: "Idle")
                    dictionary["Linked"] = choice
                    dictionary["Type"] = "linked"
                }
            } else {
                for (key, child) in dictionary { dictionary[key] = walk(child) }
            }
            return dictionary
        }
        let result = walk(store) as! [String: Any]
        guard count > 0 else { throw failure("Unsupported wallpaper store. No settings were changed.") }
        return result
    }

    static func isOurChoice(_ choice: Any?) -> Bool { WallpaperIdentity.isOurChoice(choice) }

    static func selection(in store: [String: Any]) -> (wallpaper: Bool, screenSaver: Bool) {
        let current = WallpaperIdentity.coverage(in: store)
        return (current.wallpaper, current.screenSaver)
    }

    /// New Spaces may appear after installation. Restore our new overrides from
    /// the original global choice while preserving later, non-app choices.
    static func restore(current: [String: Any], original: [String: Any]) -> [String: Any] {
        let fallback = original["SystemDefault"] as? [String: Any] ?? original["AllSpacesAndDisplays"] as? [String: Any] ?? [:]
        func walk(_ node: [String: Any], old: [String: Any]) -> [String: Any] {
            var result = node
            let prior = ["Desktop", "Idle", "Linked"].contains(where: { old[$0] != nil }) ? old : fallback
            let linked = isOurChoice(node["Linked"])
            let desktop = isOurChoice(node["Desktop"])
            let idle = isOurChoice(node["Idle"])
            if linked || (desktop && idle && prior["Linked"] != nil) {
                for key in ["Desktop", "Idle", "Linked", "Type"] { result[key] = prior[key] }
            } else {
                if desktop { result["Desktop"] = prior["Desktop"] ?? prior["Linked"] }
                if idle { result["Idle"] = prior["Idle"] ?? prior["Linked"] }
            }
            for (key, child) in node where !["Desktop", "Idle", "Linked", "Type"].contains(key) {
                if let dictionary = child as? [String: Any] { result[key] = walk(dictionary, old: old[key] as? [String: Any] ?? [:]) }
            }
            return result
        }
        return walk(current, old: original)
    }

    static func removeOurAsset(from manifest: [String: Any]) -> [String: Any] {
        var result = manifest
        result["assets"] = (manifest["assets"] as? [[String: Any]] ?? []).filter { $0["id"] as? String != assetID }
        result["categories"] = (manifest["categories"] as? [[String: Any]] ?? []).filter { $0["id"] as? String != categoryID }
        return result
    }

    static func failure(_ message: String) -> NSError {
        NSError(domain: "NightCockpit.LockScreen", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
