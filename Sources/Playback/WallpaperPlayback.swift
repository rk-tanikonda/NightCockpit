import AppKit

/// Both playback engines expose the same controls to the app coordinator.
protocol WallpaperPlayback: AnyObject {
    var window: DesktopWindow { get }
    func setPaused(_ paused: Bool)
    func setFit(_ fit: Bool)
    func close()
}
