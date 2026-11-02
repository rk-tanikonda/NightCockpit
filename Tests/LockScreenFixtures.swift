import Foundation

/// Pure fixtures: do not read or modify the real wallpaper settings.
@main
struct LockScreenFixtures {
    static func main() throws {
        let oldChoice: [String: Any] = ["Content": ["Choices": [["Provider": "example.old", "Configuration": Data()]]]]
        let original: [String: Any] = ["AllSpacesAndDisplays": ["Linked": oldChoice], "Keep": "unchanged"]
        let chosen = try LockScreenModel.choose(in: original)
        let all = chosen["AllSpacesAndDisplays"] as! [String: Any]
        precondition(LockScreenModel.isOurChoice(all["Linked"]))
        precondition(all["Desktop"] == nil && all["Idle"] == nil)
        precondition(all["Type"] as? String == "linked")
        precondition(chosen["Keep"] as? String == "unchanged")
        let selected = LockScreenModel.selection(in: chosen)
        precondition(selected.wallpaper && selected.screenSaver)
        let restored = LockScreenModel.restore(current: chosen, original: original)
        precondition(NSDictionary(dictionary: restored).isEqual(to: original))

        // Users may have independent wallpaper and screen saver choices.
        let oldIdle: [String: Any] = ["Content": ["Choices": [["Provider": "example.saver", "Configuration": Data()]]]]
        let individual: [String: Any] = ["Desktop": oldChoice, "Idle": oldIdle, "Type": "individual"]
        let individualChosen = try LockScreenModel.choose(in: individual)
        precondition(LockScreenModel.isOurChoice(individualChosen["Linked"]))
        precondition(NSDictionary(dictionary: LockScreenModel.restore(current: individualChosen, original: individual)).isEqual(to: individual))

        let ourChoice = all["Linked"]!
        let later: [String: Any] = ["Desktop": oldChoice, "Idle": ourChoice, "Type": "individual"]
        let laterRestored = LockScreenModel.restore(current: later, original: individual)
        precondition(NSDictionary(dictionary: laterRestored["Desktop"] as! [String: Any]).isEqual(to: oldChoice))
        precondition(NSDictionary(dictionary: laterRestored["Idle"] as! [String: Any]).isEqual(to: oldIdle))
        let laterIdle: [String: Any] = ["Desktop": ourChoice, "Idle": oldIdle, "Type": "individual"]
        let laterIdleRestored = LockScreenModel.restore(current: laterIdle, original: original["AllSpacesAndDisplays"] as! [String: Any])
        precondition(NSDictionary(dictionary: laterIdleRestored["Idle"] as! [String: Any]).isEqual(to: oldIdle))
        precondition(laterIdleRestored["Linked"] == nil)
        precondition(laterIdleRestored["Type"] as? String == "individual")

        var changedLater = chosen
        changedLater["AllSpacesAndDisplays"] = ["Desktop": oldChoice, "Idle": ["Later": true]]
        let selectiveRestore = LockScreenModel.restore(current: changedLater, original: original)
        precondition(NSDictionary(dictionary: selectiveRestore).isEqual(to: changedLater))
        // Upgrade from the older Desktop-only installer must remain reversible.
        let legacy: [String: Any] = ["AllSpacesAndDisplays": ["Desktop": ourChoice, "Idle": oldChoice, "Type": "individual"], "Keep": "unchanged"]
        let legacySelection = LockScreenModel.selection(in: legacy)
        precondition(legacySelection.wallpaper && !legacySelection.screenSaver)
        let upgraded = try LockScreenModel.choose(in: legacy)
        precondition(NSDictionary(dictionary: LockScreenModel.restore(current: upgraded, original: original)).isEqual(to: original))
        let nested: [String: Any] = ["Spaces": ["space": ["Displays": ["display": individual]]]]
        let nestedChosen = try LockScreenModel.choose(in: nested)
        precondition(NSDictionary(dictionary: LockScreenModel.restore(current: nestedChosen, original: nested)).isEqual(to: nested))

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
        print("Lock Screen model fixtures passed: linked wallpaper/screen saver, individual restore, selective restore, legacy upgrade, nested displays, idempotent registration, schema rejection.")
    }
}
