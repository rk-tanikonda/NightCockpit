// Adapted from Aerial. Copyright (c) 2015–present Guillaume Louel and contributors.
// MIT; see LICENSES/Aerial-MIT.txt. Reduced to one local Night Cockpit video.
// XPC connection configuration for the wallpaper extension.
//
// Accepts incoming connections from WallpaperAgent, sets up class whitelists
// for all XPC type parameters, and wires up the handler.

import ExtensionFoundation
import Foundation

struct NativeExtensionConfiguration: AppExtensionConfiguration {
    func accept(connection: NSXPCConnection) -> Bool {
        debugLog("XPC accept from PID=\(connection.processIdentifier)")

        let exported = NSXPCInterface(with: (any WallpaperExtensionXPCProtocol).self)

        let typeNames = [
            "WallpaperIDXPC",
            "WallpaperCreationRequestXPC",
            "WallpaperUpdateRequestXPC",
            "WallpaperRemoteContextXPC",
            "WallpaperSnapshotXPC",
            "WallpaperContentTypeSetXPC",
            "WallpaperChoiceIDXPC",
            "WallpaperChoiceIDsXPC",
            "WallpaperExtensionChoiceRequestXPC",
            "WallpaperChoiceRequestAdditionResultXPC",
            "WallpaperDebugRequestXPC",
            "WallpaperDebugResponseXPC",
            "WallpaperMigrationVersionXPC",
            "WallpaperSettingsViewModelsXPC",
            "AuditTokenXPC",
        ]

        let allTypes = NSMutableSet()
        var missing: [String] = []
        for name in typeNames {
            if let cls = objc_getClass(name) {
                allTypes.add(cls)
            } else {
                missing.append(name)
            }
        }
        if !missing.isEmpty {
            debugLog("  MISSING runtime types: \(missing.joined(separator: ", "))")
        }
        allTypes.add(NSString.self)
        allTypes.add(NSNumber.self)
        allTypes.add(NSData.self)
        allTypes.add(NSArray.self)
        allTypes.add(NSDictionary.self)
        allTypes.add(NSURL.self)
        allTypes.add(NSError.self)

        // Element-wise bridge (verified identical to the NSSet force-bridge
        // for ObjC class objects); an `as!` here would abort the extension
        // on the very first XPC accept.
        let classes = Set(allTypes.compactMap { $0 as? AnyHashable })
        if classes.count != allTypes.count {
            debugLog("  WARNING: class whitelist bridge dropped \(allTypes.count - classes.count) entries")
        }

        let selectors: [(Selector, Int, Bool)] = [
            (#selector(NativeWallpaperHandler.acquire(withId:request:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.acquire(withId:request:reply:)), 1, false),
            (#selector(NativeWallpaperHandler.acquire(withId:request:reply:)), 0, true),
            (#selector(NativeWallpaperHandler.update(withId:request:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.update(withId:request:reply:)), 1, false),
            (#selector(NativeWallpaperHandler.invalidate(withId:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.snapshot(withId:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.snapshot(withId:reply:)), 0, true),
            (#selector(NativeWallpaperHandler.provideSettingsViewModels(withContentTypes:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.provideSettingsViewModels(withContentTypes:reply:)), 0, true),
            (#selector(NativeWallpaperHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 1, false),
            (#selector(NativeWallpaperHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, true),
            (#selector(NativeWallpaperHandler.removeChoiceRequest(withChoiceRequest:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.selectedChoicesDidChange(for:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 1, false),
            (#selector(NativeWallpaperHandler.isChoiceDownloaded(with:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.download(withChoiceID:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.pauseDownload(for:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.cancelDownload(for:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.resumeDownload(for:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.removeDownload(for:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.migrateSelectedChoice(for:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.migrateSelectedChoice(for:reply:)), 0, true),
            (#selector(NativeWallpaperHandler.migrate(from:to:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.migrate(from:to:reply:)), 1, false),
            (#selector(NativeWallpaperHandler.skipShuffledContent(withId:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.canSkipShuffledContent(withId:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.handleDebugRequest(for:reply:)), 0, false),
            (#selector(NativeWallpaperHandler.handleDebugRequest(for:reply:)), 0, true),
            (#selector(NativeWallpaperHandler.handleNotification(withNamed:reply:)), 0, false),
        ]

        for (sel, idx, isReply) in selectors {
            exported.setClasses(classes, for: sel, argumentIndex: idx, ofReply: isReply)
        }

        connection.exportedInterface = exported
        connection.remoteObjectInterface = NSXPCInterface(with: (any WallpaperExtensionProxyXPCProtocol).self)

        let handler = NativeWallpaperHandler()
        connection.exportedObject = handler

        connection.interruptionHandler = { debugLog("XPC interrupted") }
        connection.invalidationHandler = { [weak handler] in
            handler?.agentProxy = nil
            debugLog("XPC invalidated")

        }

        connection.resume()

        handler.agentProxy = connection.remoteObjectProxy as? (any WallpaperExtensionProxyXPCProtocol)

        debugLog("XPC accepted")
        return true
    }
}

