import AppKit
import AVFoundation
import QuartzCore

/// Opt-in decoder/clock regression: never creates an NSWindow, changes native
/// choices, locks the screen, or enables sound. Real host rendering is separate.
@main struct NativePlaybackFixtures {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "NativePlaybackFixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pass a local movie."])
        }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        guard let context = CAContext.perform(NSSelectorFromString("remoteContextWithOptions:"), with: ["contentsScale": 1])?.takeUnretainedValue() as? CAContext else {
            throw NSError(domain: "NativePlaybackFixtures", code: 2, userInfo: [NSLocalizedDescriptionKey: "A logged-in desktop is required."])
        }
        let renderer = NativePlayback(url: URL(fileURLWithPath: CommandLine.arguments[1]), allowAudio: false)
        let host = HostedWallpaper(context: context, size: CGSize(width: 320, height: 180), scale: 1, mode: "idle", preview: false)
        renderer.hosted["fixture"] = host
        renderer.reconcile()
        try await Task.sleep(nanoseconds: 1_500_000_000)
        precondition(renderer.presentedFrames > 20, "Decoder did not present frames")
        for _ in 0..<3 {
            host.mode = "default"; renderer.reconcile()
            let paused = renderer.player.currentTime().seconds
            try await Task.sleep(nanoseconds: 200_000_000)
            precondition(abs(renderer.player.currentTime().seconds - paused) < 0.05, "Pause clock drift")
            let frames = renderer.presentedFrames
            host.mode = "idle"; renderer.reconcile()
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let advance = renderer.player.currentTime().seconds - paused
            precondition(advance > 0.8 && advance < 1.2, "Resume is not at normal speed")
            precondition(renderer.presentedFrames - frames > 20, "Frames stalled on repeat resume")
            precondition(renderer.player.isMuted, "Fixture must never enable sound")
            if let video = renderer.lastVideoTime {
                precondition(abs(renderer.player.currentTime().seconds - video) < 0.15, "Video frames lag the shared player clock")
            }
        }
        host.mode = "default"; renderer.reconcile()
        print("Native playback fixtures passed: frames advance at 1x through three pause/resume cycles, within 150 ms of the shared player clock; no windows or sound.")
    }
}
