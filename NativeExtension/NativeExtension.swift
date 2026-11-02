import AppKit
import ExtensionFoundation
import os

private let logger = Logger(subsystem: "org.nightcockpit.native", category: "runtime")
func debugLog(_ text: String) { logger.notice("\(text, privacy: .public)") }

@main struct NativeExtensionEntry {
    @MainActor static func main() throws {
        // The extension point's runtime types must exist before ExtensionKit
        // resolves its running-extension class, not just inside our init.
        let handle = dlopen("/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit", RTLD_LAZY)
        debugLog("bootstrap framework=\(handle != nil) bundle=\(Bundle.main.bundleIdentifier ?? "missing")")
        try NativeVideoExtension.main()
    }
}

final class NativeVideoExtension: NSObject, AppExtension {
    override required init() {
        super.init()
        // Native wallpaper extensions are not a public SDK. Fail to connect if
        // the OS no longer supplies these types; never alter authentication.
        _ = dlopen("/System/Library/PrivateFrameworks/WallpaperExtensionKit.framework/WallpaperExtensionKit", RTLD_NOW)
        debugLog("extension started, pid \(getpid())")
    }
    var configuration: some AppExtensionConfiguration { NativeExtensionConfiguration() }
}
