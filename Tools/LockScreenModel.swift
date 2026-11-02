// Portions adapted from W-Player's AerialsManifest and WallpaperChoice.
// Copyright 2026 W-Player contributors. Apache-2.0; see LICENSES/Apache-2.0.txt.
// Changed: one Night Cockpit asset, strict schema validation and selective restore.
import Foundation

enum LockScreenModel {
    static let categoryID = "8B5C4200-0000-4000-8000-000000000001"
    static let subcategoryID = "8B5C4200-0000-4000-8000-000000000002"
    static let assetID = "8B5C4200-0000-4000-8000-000000000003"
    static let provider = "com.apple.wallpaper.choice.aerials"

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
            "id": assetID, "accessibilityLabel": "Night Cockpit 4K", "localizedNameKey": "Night Cockpit 4K",
            "categories": [categoryID], "subcategories": [subcategoryID], "includeInShuffle": false,
            "showInTopLevel": true, "pointsOfInterest": [String: Any](), "preferredOrder": 0,
            "previewImage": thumbnail.absoluteString, "shotID": "NIGHTCOCKPIT_4K",
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
                if let linked = dictionary.removeValue(forKey: "Linked") {
                    dictionary["Idle"] = linked
                    dictionary["Type"] = "individual"
                }
                dictionary["Desktop"] = choice
            } else {
                for (key, child) in dictionary { dictionary[key] = walk(child) }
            }
            return dictionary
        }
        let result = walk(store) as! [String: Any]
        guard count > 0 else { throw failure("Unsupported wallpaper store. No settings were changed.") }
        return result
    }

    static func isOurChoice(_ choice: Any?) -> Bool {
        guard let dictionary = choice as? [String: Any], let content = dictionary["Content"] as? [String: Any],
              let first = (content["Choices"] as? [[String: Any]])?.first,
              first["Provider"] as? String == provider, let data = first["Configuration"] as? Data,
              let config = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
        return config["assetID"] as? String == assetID
    }

    /// Restore only our Desktop choices. Preserve later changes to other slots.
    static func restore(current: [String: Any], original: [String: Any]) -> [String: Any] {
        var result = current
        if isOurChoice(current["Desktop"]) {
            result["Desktop"] = original["Desktop"] ?? original["Linked"]
        }
        for (key, value) in current where key != "Desktop" && key != "Idle" {
            if let child = value as? [String: Any], let old = original[key] as? [String: Any] {
                result[key] = restore(current: child, original: old)
            }
        }
        return result
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
