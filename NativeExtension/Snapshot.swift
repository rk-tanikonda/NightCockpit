// Remote snapshot representation/encoder compatibility adapted from Aerial.
// Copyright (c) 2015–present Guillaume Louel and contributors. MIT; see Aerial-MIT.txt.
import AppKit
import CoreVideo
import IOSurface

enum NativeSnapshot {
    private static var cached: AnyObject?

    static func image() -> AnyObject? {
        if let cached { return cached }
        guard let image = NSImage(contentsOf: NativePlaybackSettings.posterURL)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        // WallpaperSnapshot stores the Objective-C IOSurface wrapper, not the
        // CF IOSurfaceRef returned by CVPixelBufferGetIOSurface.
        let properties: [IOSurfacePropertyKey: any Sendable] = [.width: image.width, .height: image.height,
                                                               .bytesPerElement: 4, .pixelFormat: 0x42475241]
        guard let surface = IOSurface(properties: properties) else { return nil }
        surface.lock(options: [], seed: nil)
        defer { surface.unlock(options: [], seed: nil) }
        guard let context = CGContext(data: surface.baseAddress, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: surface.bytesPerRow,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let cls = objc_getClass("WallpaperSnapshotXPC") as? AnyClass,
              let ivar = class_getInstanceVariable(cls, "rawValue"), ivar_getOffset(ivar) >= 8,
              class_getInstanceSize(cls) >= ivar_getOffset(ivar) + MemoryLayout<UnsafeRawPointer>.size,
              let object = class_createInstance(cls, 0) else { return nil }
        let retained = Unmanaged.passRetained(surface).toOpaque()
        Unmanaged.passUnretained(object as AnyObject).toOpaque().advanced(by: ivar_getOffset(ivar)).storeBytes(of: retained, as: UnsafeMutableRawPointer.self)
        cached = object as AnyObject
        return cached
    }

}
