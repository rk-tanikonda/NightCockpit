import AppKit
import AVFoundation
import VideoToolbox

/// Video-only native HEVC, including the temporal layers required by macOS 27.
/// Encoding runs in a separate command process, never on the application's UI loop.
@available(macOS 15.0, *)
enum VideoPreparation {
    static func prepare(source: URL, destination: URL) async throws -> Data {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration)
        guard try await asset.load(.isPlayable), duration.seconds.isFinite, duration.seconds > 0,
              let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw LockScreenModel.failure("Choose a playable video with a finite duration.")
        }
        let size = try await track.load(.naturalSize)
        let fps = max(1, min(60, try await track.load(.nominalFrameRate)))
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel,
                AVVideoAverageBitRateKey: 16_000_000,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalKey: Int(fps * 2),
                kVTCompressionPropertyKey_BaseLayerFrameRate as String: Double(fps) / 8
            ]
        ]
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else {
            throw LockScreenModel.failure("This Mac cannot encode the required native HEVC format.")
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        input.transform = try await track.load(.preferredTransform)
        let reader = try AVAssetReader(asset: asset)
        let range = try await track.load(.timeRange)
        reader.timeRange = range
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        ])
        output.alwaysCopiesSampleData = false
        do {
#if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                let receiver = writer.inputReceiver(for: input)
                let provider = reader.outputProvider(for: output)
                try writer.start()
                writer.startSession(atSourceTime: range.start)
                try reader.start()
                while let sample = try await provider.next() {
                    try Task.checkCancellation()
                    try await receiver.append(sample)
                }
                receiver.finish()
            } else {
                try await transferLegacy(reader, output, writer, input, start: range.start)
            }
#else
            try await transferLegacy(reader, output, writer, input, start: range.start)
#endif
            await writer.finishWriting()
            guard writer.status == .completed else { throw writer.error ?? LockScreenModel.failure("Native video conversion failed.") }
        } catch {
            reader.cancelReading(); writer.cancelWriting()
            throw error
        }
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            guard try MovieFormat.supportsNativeReplay(destination) else {
                throw LockScreenModel.failure("The encoder did not produce temporal layers required by macOS 27. Current settings were preserved.")
            }
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: destination))
        generator.appliesPreferredTrackTransform = true
        let (image, _) = try await generator.image(at: range.start)
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw LockScreenModel.failure("Cannot create the native video thumbnail.")
        }
        return png
    }

    @available(macOS, introduced: 15.0, deprecated: 27.0)
    private static func transferLegacy(_ reader: AVAssetReader, _ output: AVAssetReaderTrackOutput,
                                       _ writer: AVAssetWriter, _ input: AVAssetWriterInput, start: CMTime) async throws {
        reader.add(output); writer.add(input)
        guard writer.startWriting(), reader.startReading() else {
            throw writer.error ?? reader.error ?? LockScreenModel.failure("Cannot start native video conversion.")
        }
        writer.startSession(atSourceTime: start)
        while let sample = output.copyNextSampleBuffer() {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw writer.error ?? LockScreenModel.failure("Native encoder stopped.") }
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            guard input.append(sample) else { throw writer.error ?? LockScreenModel.failure("Cannot encode video sample.") }
        }
        if reader.status == .failed { throw reader.error ?? LockScreenModel.failure("Cannot decode source movie.") }
        input.markAsFinished()
    }
}
