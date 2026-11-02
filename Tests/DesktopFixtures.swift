import AppKit
import AVFoundation

/// Create an unshown wallpaper window; never activate it or alter system settings.
@main struct DesktopFixtures {
    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        guard let screen = NSScreen.screens.first else { print("No desktop session; window fixtures skipped."); return }
        let window = DesktopWindow.make(on: screen)
        precondition(window.ignoresMouseEvents && !window.acceptsMouseMovedEvents)
        precondition(!window.canBecomeKey && !window.canBecomeMain)
        precondition(window.level.rawValue == Int(CGWindowLevelForKey(.desktopWindow)))
        precondition(window.collectionBehavior.contains(.fullScreenNone))
        precondition(window.collectionBehavior.contains(.ignoresCycle))
        precondition(window.collectionBehavior.contains(.transient))
        precondition(!window.collectionBehavior.contains(.stationary))
        precondition(!window.isVisible)
        let pixels = CGContext(data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 8,
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let view = VideoView(frame: NSRect(x: 0, y: 0, width: 100, height: 100), poster: pixels.makeImage()!)
        precondition(view.hitTest(NSPoint(x: 1, y: 1)) == nil)
        precondition(!view.acceptsFirstResponder)
        precondition(view.layer!.sublayers!.first!.contents != nil) // frame exists before any decoding
        window.close()
        print("Desktop fixtures passed: background level, no focus/input, full-screen exclusion, and immediate poster.")
    }
}
