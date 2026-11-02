import Foundation

/// Native configuration runs off the UI thread and never installs an overlay.
final class NativeWallpaperController {
    private var process: Process?

    func run(_ command: String, video: URL? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        guard process == nil else { return }
        guard let tool = Bundle.main.url(forResource: "lockscreen-tool", withExtension: nil) else { return }
        let child = Process()
        child.executableURL = tool
        child.arguments = [command] + (video.map { [$0.path] } ?? [])
        child.standardOutput = FileHandle.nullDevice
        // Inherit stderr so errors appear in the per-user service log.
        child.terminationHandler = { [weak self] child in
            DispatchQueue.main.async {
                guard self?.process === child else { return }
                self?.process = nil
                if child.terminationStatus == 0 { completion(.success(())) }
                else { completion(.failure(NSError(domain: "NightCockpit.Native", code: Int(child.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Native wallpaper needs repair. Run setup with --lock-screen; see the service error log."]))) }
            }
        }
        process = child
        do { try child.run() }
        catch { process = nil; completion(.failure(error)) }
    }
    func cancel() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
    }
}
