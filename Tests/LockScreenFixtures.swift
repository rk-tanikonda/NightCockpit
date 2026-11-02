import Foundation

/// Pure fixtures: do not read or modify the real wallpaper settings.
@main
struct LockScreenFixtures {
    static func main() throws {
        let oldChoice: [String: Any] = ["Content": ["Choices": [["Provider": "example.old", "Configuration": Data()]]]]
        let original: [String: Any] = ["AllSpacesAndDisplays": ["Linked": oldChoice], "Keep": "unchanged"]
        let chosen = try LockScreenModel.choose(in: original)
        let all = chosen["AllSpacesAndDisplays"] as! [String: Any]
        precondition(LockScreenModel.isOurChoice(all["Desktop"]))
        precondition(all["Linked"] == nil)
        precondition(NSDictionary(dictionary: all["Idle"] as! [String: Any]).isEqual(to: oldChoice))
        precondition(chosen["Keep"] as? String == "unchanged")
        let restored = LockScreenModel.restore(current: chosen, original: original)
        let restoredAll = restored["AllSpacesAndDisplays"] as! [String: Any]
        precondition(!LockScreenModel.isOurChoice(restoredAll["Desktop"]))
        precondition(NSDictionary(dictionary: restoredAll["Desktop"] as! [String: Any]).isEqual(to: oldChoice))
        var changedLater = chosen
        changedLater["AllSpacesAndDisplays"] = ["Desktop": oldChoice, "Idle": ["Later": true]]
        let selectiveRestore = LockScreenModel.restore(current: changedLater, original: original)
        precondition(NSDictionary(dictionary: selectiveRestore).isEqual(to: changedLater))

        let manifest: [String: Any] = ["assets": [["id": "other"]], "categories": [["id": "other-category"]], "FutureKey": "preserved"]
        let url = URL(fileURLWithPath: "/tmp/test.mov")
        let added = try LockScreenModel.register(in: manifest, video: url, thumbnail: url)
        let repeated = try LockScreenModel.register(in: added, video: url, thumbnail: url)
        precondition((repeated["assets"] as! [[String: Any]]).count == 2)
        precondition((repeated["categories"] as! [[String: Any]]).count == 2)
        precondition(repeated["FutureKey"] as? String == "preserved")
        let removed = LockScreenModel.removeOurAsset(from: repeated)
        precondition(NSDictionary(dictionary: removed).isEqual(to: manifest))
        do {
            _ = try LockScreenModel.choose(in: ["unknown": true])
            fatalError("Unsupported store should be rejected")
        } catch {}
        do {
            _ = try LockScreenModel.register(in: [:], video: url, thumbnail: url)
            fatalError("Unsupported manifest should be rejected")
        } catch {}
        print("Lock Screen model fixtures passed: choice selection, linked preservation, selective restore, idempotent registration, schema rejection.")
    }
}
