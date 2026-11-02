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
        let synchronized = try LockScreenModel.choose(in: original, synchronized: true)
        let synchronizedCoverage = WallpaperIdentity.coverage(in: synchronized, requiredProvider: WallpaperIdentity.nativeProvider)
        precondition(synchronizedCoverage.wallpaper && synchronizedCoverage.screenSaver)
        precondition(!WallpaperIdentity.coverage(in: chosen, requiredProvider: WallpaperIdentity.nativeProvider).wallpaper)
        precondition(!WallpaperIdentity.coverage(in: synchronized, requiredProvider: WallpaperIdentity.aerialProvider).wallpaper)
        precondition(NSDictionary(dictionary: LockScreenModel.restore(current: synchronized, original: original)).isEqual(to: original))

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
        // Global success must not hide a conflicting per-Space desktop override.
        var perSpace = chosen
        perSpace["Spaces"] = ["active": ["Default": ["Desktop": oldChoice, "Idle": ourChoice, "Type": "individual"]]]
        let conflict = LockScreenModel.selection(in: perSpace)
        precondition(!conflict.wallpaper && conflict.screenSaver)
        perSpace["AllSpacesAndDisplays"] = ["Idle": oldChoice, "Type": "idle"]
        precondition(!LockScreenModel.selection(in: perSpace).screenSaver)
        let fixedSpaces = try LockScreenModel.choose(in: perSpace)
        let globalIdle = fixedSpaces["AllSpacesAndDisplays"] as! [String: Any]
        precondition(globalIdle["Type"] as? String == "idle" && globalIdle["Linked"] == nil)
        precondition(LockScreenModel.selection(in: fixedSpaces).wallpaper)
        precondition(LockScreenModel.selection(in: fixedSpaces).screenSaver)
        let restoredNewSpace = LockScreenModel.restore(current: fixedSpaces, original: original)
        let restoredSpaces = restoredNewSpace["Spaces"] as! [String: Any]
        let restoredDefault = (restoredSpaces["active"] as! [String: Any])["Default"] as! [String: Any]
        precondition(!LockScreenModel.isOurChoice(restoredDefault["Linked"]))
        precondition(NSDictionary(dictionary: restoredDefault["Linked"] as! [String: Any]).isEqual(to: oldChoice))
        var playback = PlaybackState()
        precondition(!playback.shouldPause)
        playback.locked = true; playback.displayAsleep = true
        precondition(!playback.shouldRepairNative(true))
        playback.systemAsleep = false // waking the CPU cannot resume the locked display
        precondition(playback.shouldPause)
        playback.displayAsleep = false
        precondition(playback.shouldPause)
        playback.unlock()
        precondition(!playback.shouldPause)
        playback.manuallyPaused = true; playback.locked = true; playback.unlock()
        precondition(playback.shouldPause) // an explicit pause survives unlock
        playback.stopping = true
        playback.unlock()
        precondition(playback.shouldPause && !playback.shouldRepairNative(true))
        var transition = PlaybackState()
        transition.sessionActive = false
        precondition(!transition.shouldRepairNative(true))
        transition.sessionActive = true; transition.systemAsleep = true
        precondition(!transition.shouldRepairNative(true))
        transition.systemAsleep = false; transition.displayAsleep = true
        precondition(!transition.shouldRepairNative(true))
        transition.unlock()
        precondition(transition.shouldRepairNative(true))
        let restarted = PlaybackState()
        // Opt-in display hold applies to the real locked session, including
        // session resignation, and releases on every stop/sleep/unlock path.
        var lockDisplayState = PlaybackState()
        precondition(!lockDisplayState.shouldHoldLockDisplay(true, nativeEnabled: true))
        lockDisplayState.locked = true; lockDisplayState.sessionActive = false
        precondition(lockDisplayState.shouldHoldLockDisplay(true, nativeEnabled: true))
        precondition(!lockDisplayState.shouldHoldLockDisplay(false, nativeEnabled: true))
        precondition(!lockDisplayState.shouldHoldLockDisplay(true, nativeEnabled: false))
        lockDisplayState.displayAsleep = true
        precondition(!lockDisplayState.shouldHoldLockDisplay(true, nativeEnabled: true))
        lockDisplayState.displayAsleep = false; lockDisplayState.systemAsleep = true
        precondition(!lockDisplayState.shouldHoldLockDisplay(true, nativeEnabled: true))
        lockDisplayState.systemAsleep = false; lockDisplayState.stopping = true
        precondition(!lockDisplayState.shouldHoldLockDisplay(true, nativeEnabled: true))
        lockDisplayState.stopping = false; lockDisplayState.unlock()
        precondition(!lockDisplayState.shouldHoldLockDisplay(true, nativeEnabled: true))
        // Inject assertion endpoints so fixtures never hold a real display on.
        var acquired = 0, released: [UInt32] = []
        var hold: LockDisplayController? = LockDisplayController(acquire: { acquired += 1; return 42 }, release: { released.append($0) })
        hold?.setActive(false)
        precondition(acquired == 0 && released.isEmpty)
        hold?.setActive(true); hold?.setActive(true)
        precondition(acquired == 1 && released.isEmpty)
        hold?.setActive(false); hold?.stop()
        precondition(released == [42])
        hold?.setActive(true); hold = nil
        precondition(acquired == 2 && released == [42, 42])
        var attempts = 0
        let failedHold = LockDisplayController(acquire: { attempts += 1; return nil }, release: { _ in fatalError("No assertion to release") })
        failedHold.setActive(true); failedHold.setActive(false)
        precondition(attempts == 1)
        precondition(restarted.shouldRepairNative(true) && !restarted.shouldRepairNative(false))
        func box(_ type: String, _ payload: Data) -> Data {
            let size = UInt32(payload.count + 8)
            var output = withUnsafeBytes(of: size.bigEndian) { Data($0) }
            output.append(Data(type.utf8)); output.append(payload)
            return output
        }
        let groups = box("sgpd", Data([0, 0, 0, 0]) + Data("tscl".utf8)) + box("sbgp", Data([0, 0, 0, 0]) + Data("tsas".utf8))
        let movie = box("moov", box("trak", box("mdia", box("minf", box("stbl", groups)))))
        precondition(MovieFormat.temporalGroups(in: movie) == Set(["tscl", "tsas"]))
        precondition(MovieFormat.temporalGroups(in: box("mdat", Data("sgpdtscltsas".utf8))).isEmpty)
        precondition(MovieFormat.temporalGroups(in: Data(movie.prefix(10))).isEmpty)
        precondition(MovieFormat.temporalGroups(in: Data([255, 255, 255, 255]) + Data("moov".utf8)).isEmpty)
        print("Lock Screen model fixtures passed: linked wallpaper/screen saver, individual restore, selective restore, legacy upgrade, nested displays, idempotent registration, schema rejection.")
    }
}
