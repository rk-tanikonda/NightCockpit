import AppKit
import AVFoundation

/// Read-only validation of the media shipped in a source download.
@main
struct BundledMediaFixtures {
    static func main() async throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let playable = try await asset.load(.isPlayable)
        let videos = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        precondition(playable && videos.count == 1 && audio.count == 1, "Demo must contain playable video and audio")
        let size = try await videos[0].load(.naturalSize)
        let fps = try await videos[0].load(.nominalFrameRate)
        let audioDuration = try await audio[0].load(.timeRange).duration.seconds
        precondition(abs(duration - 12) < 0.1 && abs(audioDuration - duration) < 0.1, "Demo track durations must match")
        precondition(size == CGSize(width: 1920, height: 1080) && abs(fps - 30) < 0.01, "Unexpected demo format")
        let generator = AVAssetImageGenerator(asset: asset)
        generator.maximumSize = CGSize(width: 320, height: 180)
        let (first, _) = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600))
        let (later, _) = try await generator.image(at: CMTime(seconds: 7, preferredTimescale: 600))
        let firstPNG = NSBitmapImageRep(cgImage: first).representation(using: .png, properties: [:])
        let laterPNG = NSBitmapImageRep(cgImage: later).representation(using: .png, properties: [:])
        precondition(firstPNG != nil && laterPNG != nil && firstPNG != laterPNG, "Demo must decode distinct moving frames")
        print("Bundled media passed: 12s, 1080p/30fps, matching audio duration, distinct decoded frames.")
    }
}
