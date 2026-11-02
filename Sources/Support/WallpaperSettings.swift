import Foundation

struct WallpaperSettings {
    static var bundledVideoURL: URL? { Bundle.main.url(forResource: "wallpaper", withExtension: "mp4") }
    private let defaults = UserDefaults.standard
    var fit: Bool {
        get { defaults.bool(forKey: "fit") }
        nonmutating set { defaults.set(newValue, forKey: "fit") }
    }
    var mainDisplayOnly: Bool {
        get { defaults.bool(forKey: "mainOnly") }
        nonmutating set { defaults.set(newValue, forKey: "mainOnly") }
    }
    var videoPath: String? {
        get { defaults.string(forKey: "videoPath") }
        nonmutating set { defaults.set(newValue, forKey: "videoPath") }
    }
    var nativeEnabled: Bool {
        get { defaults.bool(forKey: "nativeWallpaper") }
        nonmutating set { defaults.set(newValue, forKey: "nativeWallpaper") }
    }
}
