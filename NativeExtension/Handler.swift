// Protocol and remote-context format adapted from Aerial; see Aerial-MIT.txt.
import AppKit
import Foundation

final class NativeWallpaperHandler: NSObject, WallpaperExtensionXPCProtocol {
    weak var agentProxy: WallpaperExtensionProxyXPCProtocol?

    func acquire(withId id: Any?, request: Any?, reply: @escaping @Sendable (Any?, Error?) -> Void) {
        let key = Self.key(id)
        let context = Self.requestContext(request)
        DispatchQueue.main.async {
            let options: [String: Any] = ["contentsScale": context.scale]
            let selector = NSSelectorFromString("remoteContextWithOptions:")
            guard CAContext.responds(to: selector),
                  let remote = CAContext.perform(selector, with: options)?.takeUnretainedValue() as? CAContext,
                  remote.contextId != 0, let wrapped = Self.wrap(remote.contextId) else {
                reply(nil, NSError(domain: "NightCockpit.Native", code: 1, userInfo: [NSLocalizedDescriptionKey: "macOS cannot host the native video layer."])); return
            }
            let hosted = HostedWallpaper(context: remote, size: context.size, scale: context.scale, mode: context.mode, preview: context.preview)
            NativePlayback.shared.hosted[key] = hosted
            NativePlayback.shared.reconcile()
            debugLog("acquire \(key) size=\(context.size) mode=\(context.mode)")
            reply(wrapped, nil)
        }
    }

    func update(withId id: Any?, request: Any?, reply: @escaping @Sendable (Error?) -> Void) {
        let key = Self.key(id), context = Self.requestContext(request)
        DispatchQueue.main.async {
            if let host = NativePlayback.shared.hosted[key] {
                host.mode = context.mode
                CATransaction.begin(); CATransaction.setDisableActions(true)
                host.root.frame = CGRect(origin: .zero, size: context.size)
                host.video.frame = host.root.bounds
                CATransaction.commit()
                NativePlayback.shared.reconcile()
            }
            reply(nil)
        }
    }

    func invalidate(withId id: Any?, reply: @escaping @Sendable (Error?) -> Void) {
        let key = Self.key(id)
        DispatchQueue.main.async {
            NativePlayback.shared.hosted.removeValue(forKey: key)
            NativePlayback.shared.reconcile(); reply(nil)
        }
    }
    func snapshot(withId id: Any?, reply: @escaping @Sendable (Any?, Error?) -> Void) {
        DispatchQueue.main.async { reply(NativeSnapshot.image(), nil) }
    }
    func handleDebugRequest(for request: Any?, reply: @escaping @Sendable (Any?, Error?) -> Void) { reply(nil, nil) }
    func handleNotification(withNamed name: Any?, reply: @escaping @Sendable (Error?) -> Void) {
        DispatchQueue.main.async { NativePlayback.shared.reconcile(); reply(nil) }
    }

    private static func key(_ value: Any?) -> String {
        guard let value else { return "unknown" }
        let inner = Mirror(reflecting: value).children.first?.value ?? value
        let text = String(describing: inner)
        if let range = text.range(of: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}", options: .regularExpression) { return String(text[range]) }
        return text
    }

    private static func requestContext(_ request: Any?) -> (size: CGSize, scale: CGFloat, mode: String, preview: Bool) {
        var size = CGSize(width: 1920, height: 1080), scale: CGFloat = 1
        var mode = "default", preview = false
        guard let request, let value = Mirror(reflecting: request).children.first?.value else { return (size, scale, mode, preview) }
        for property in Mirror(reflecting: value).children {
            if property.label == "isPreview" { preview = property.value as? Bool ?? false }
            if property.label == "destination" {
                for field in Mirror(reflecting: property.value).children {
                    if field.label == "size", let s = field.value as? CGSize, s.width > 0, s.height > 0 { size = s }
                    if field.label == "scaleFactor", let s = field.value as? CGFloat, s > 0 { scale = s }
                }
            }
        }
        let text = String(describing: value)
        if let start = text.range(of: "presentationMode: ") {
            mode = String(text[start.upperBound...].prefix { $0 != "," && $0 != ")" })
        }
        return (size, scale, mode, preview)
    }

    private static func wrap(_ identifier: UInt32) -> AnyObject? {
        guard let cls = objc_getClass("WallpaperRemoteContextXPC") as? AnyClass,
              let ivar = class_getInstanceVariable(cls, "box"),
              ivar_getOffset(ivar) >= 8, class_getInstanceSize(cls) >= ivar_getOffset(ivar) + 4,
              let object = class_createInstance(cls, 0) else { return nil }
        Unmanaged.passUnretained(object as AnyObject).toOpaque().advanced(by: ivar_getOffset(ivar)).storeBytes(of: identifier, as: UInt32.self)
        return object as AnyObject
    }
}
