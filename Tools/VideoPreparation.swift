import AppKit
import AVFoundation

/// Media conversion is separate from registration and never changes preferences.
@available(macOS 15.0, *)
enum VideoPreparation {
    static func prepare(source: URL, destination: URL) async throws -> Data {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration)
        guard try await asset.load(.isPlayable), duration.seconds.isFinite, duration.seconds > 0,
              !(try await asset.loadTracks(withMediaType: .video)).isEmpty else {
            throw LockScreenModel.failure("Choose a playable local video with a video track and a finite duration.")
        }
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            throw LockScreenModel.failure("HEVC export is unavailable on this Mac.")
        }
        try await exporter.export(to: destination, as: .mov)
        let converted = AVURLAsset(url: destination)
        guard try await converted.load(.isPlayable),
              !(try await converted.loadTracks(withMediaType: .video)).isEmpty else {
            throw LockScreenModel.failure("The converted Lock Screen movie is not playable.")
        }
        let generator = AVAssetImageGenerator(asset: converted)
        generator.appliesPreferredTrackTransform = true
        let (image, _) = try await generator.image(at: .zero)
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw LockScreenModel.failure("Could not create the video thumbnail.")
        }
        return png
    }
}
