import AppKit

/// No focus, hit testing, gesture monitors, or foreground window ordering.
final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func make(on screen: NSScreen) -> DesktopWindow {
        let window = DesktopWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        // Stay behind the overview as a live background. Transient windows are
        // hidden there, exposing the still poster and appearing to pause playback.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.ignoresMouseEvents = true
        window.acceptsMouseMovedEvents = false
        window.isExcludedFromWindowsMenu = true
        window.animationBehavior = .none
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = .black
        return window
    }
}
