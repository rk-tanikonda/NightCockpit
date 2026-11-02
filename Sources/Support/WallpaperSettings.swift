import Foundation

/// Small preferences stay in UserDefaults. Videos are never copied into Git.
struct WallpaperSettings {
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
    var streamMode: Bool {
        get { defaults.bool(forKey: "websiteMode") }
        nonmutating set { defaults.set(newValue, forKey: "websiteMode") }
    }

    /// Personal source URLs live in an ignored file, not in the public source.
    var streamURL: URL? {
        guard let file = Bundle.main.url(forResource: "wallpaper.local", withExtension: "json"),
              let data = try? Data(contentsOf: file),
              let config = try? JSONDecoder().decode(StreamConfiguration.self, from: data),
              let text = config.streamURL,
              let url = URL(string: text),
              url.scheme == "https" else { return nil }
        return url
    }
}

private struct StreamConfiguration: Decodable {
    let streamURL: String?
}
