import AppKit
import Foundation

@objc protocol NativeSnapshotTestProtocol {
    func snapshot(reply: @escaping (Any?, Error?) -> Void)
}

private func snapshotInterface() -> NSXPCInterface {
    let interface = NSXPCInterface(with: NativeSnapshotTestProtocol.self)
    let classes = NSMutableSet()
    classes.add(NSClassFromString("WallpaperSnapshotXPC")!)
    interface.setClasses(Set(classes.compactMap { $0 as? AnyHashable }),
                         for: #selector(NativeSnapshotTestProtocol.snapshot(reply:)), argumentIndex: 0, ofReply: true)
    return interface
}

private final class SnapshotExporter: NSObject, NativeSnapshotTestProtocol {
    func snapshot(reply: @escaping (Any?, Error?) -> Void) { reply(NativeSnapshot.image(), nil) }
}

private final class SnapshotListener: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = snapshotInterface()
        connection.exportedObject = SnapshotExporter()
        connection.resume()
        return true
    }
}

// Completion is installed before sending and consumed under the lock exactly once.
private final class SnapshotResult: @unchecked Sendable {
    let lock = NSLock()
    var completion: ((Bool) -> Void)?
    func finish(_ success: Bool) {
        lock.lock(); let callback = completion; completion = nil; lock.unlock()
        callback?(success)
    }
}

/// Actual XPC encoding/decoding, not just object layout or metadata. This does
/// not select wallpaper, lock the display, create windows, or play audio.
@main struct NativeSnapshotFixtures {
    @MainActor static func main() async throws {
        guard FileManager.default.isReadableFile(atPath: NativePlaybackSettings.posterURL.path) else {
            print("No staged native poster; snapshot round trip skipped. Apply a video first."); return
        }
        _ = dlopen("/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit", RTLD_LAZY)
        guard NSClassFromString("WallpaperSnapshotXPC") != nil else {
            throw NSError(domain: "NativeSnapshotFixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: "Native snapshot ABI is unavailable."])
        }
        let listener = NSXPCListener.anonymous(), delegate = SnapshotListener()
        listener.delegate = delegate; listener.resume()
        let client = NSXPCConnection(listenerEndpoint: listener.endpoint)
        client.remoteObjectInterface = snapshotInterface(); client.resume()
        let result = SnapshotResult()
        let passed = await withCheckedContinuation { continuation in
            result.completion = { continuation.resume(returning: $0) }
            let remote = client.remoteObjectProxyWithErrorHandler { _ in result.finish(false) } as! NativeSnapshotTestProtocol
            remote.snapshot { object, error in result.finish(object != nil && error == nil) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) { result.finish(false) }
        }
        client.invalidate(); listener.invalidate(); withExtendedLifetime(delegate) {}
        guard passed else {
            throw NSError(domain: "NativeSnapshotFixtures", code: 2, userInfo: [NSLocalizedDescriptionKey: "Native poster failed its XPC round trip."])
        }
        print("Native snapshot passed a real XPC round trip using the staged video poster.")
    }
}
