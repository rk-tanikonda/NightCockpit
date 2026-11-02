import AVFoundation
import Foundation

/// Opt-in, read-only integration check against an actual prepared movie.
/// Metadata alone does not establish native rendering or gesture behavior.
@main struct NativeVideoFixtures {
    static func main() async throws {
#if compiler(>=6.2)
        guard #available(macOS 26.0, *) else { print("Native cadence check requires macOS 26+."); return }
        guard CommandLine.arguments.count == 3 else {
            throw NSError(domain: "NativeVideoFixtures", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Pass the source video and prepared native movie."])
        }
        let source = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
        let movieURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let movie = AVURLAsset(url: movieURL)
        let sourceTrack = try await source.loadTracks(withMediaType: .video)[0]
        let movieTrack = try await movie.loadTracks(withMediaType: .video)[0]
        let fps = try await sourceTrack.load(.nominalFrameRate)
        let range = try await sourceTrack.load(.timeRange)
        let movieRange = try await movieTrack.load(.timeRange)
        let audioTracks = try await movie.loadTracks(withMediaType: .audio)
        precondition(audioTracks.isEmpty, "Native movie must be video-only")
        precondition(abs(movieRange.duration.seconds - range.duration.seconds) < 1 / Double(fps), "Duration changed")
        let hasTemporalGroups = try MovieFormat.supportsNativeReplay(movieURL)
        precondition(hasTemporalGroups, "Missing native temporal groups")
        let original = try await inspect(source, track: sourceTrack, inspectLayers: false)
        let encoded = try await inspect(movie, track: movieTrack, inspectLayers: true)
        precondition(original.times.count == encoded.times.count, "Frame count changed")
        let offset = encoded.times[0] - original.times[0]
        precondition(zip(original.times, encoded.times).allSatisfy { abs($1 - $0 - offset) < 0.001 }, "Source timing changed")
        precondition(Set(encoded.layers.keys) == [0, 1], "Expected two temporal layers")
        let baseFPS = Double(encoded.layers[0, default: 0]) / movieRange.duration.seconds
        precondition(baseFPS >= Double(fps) * 0.45, "Base layer is too sparse for the native ramp")
        print(String(format: "Native cadence passed: %d timed samples, %.2f seconds, %.2f fps source, %.2f fps base layer; timestamps preserved, two temporal layers, no audio.", encoded.times.count, movieRange.duration.seconds, fps, baseFPS))
#else
        print("Native cadence check requires Swift 6.2+.")
#endif
    }

#if compiler(>=6.2)
    @available(macOS 26.0, *)
    static func inspect(_ asset: AVAsset, track: AVAssetTrack, inspectLayers: Bool) async throws -> (times: [Double], layers: [Int: Int]) {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        let provider = reader.outputProvider(for: output)
        try reader.start()
        var times: [Double] = [], layers: [Int: Int] = [:]
        while let sample = try await provider.next() {
            // Provider streams also contain control markers with indefinite
            // timestamps. They are not displayed frames and NaN cannot compare.
            let time = sample.presentationTimeStamp.seconds
            if time.isFinite { times.append(time) }
            if inspectLayers, let id = sample.withUnsafeSampleBuffer({ temporalID($0) }) {
                layers[id, default: 0] += 1
            }
        }
        precondition(!times.isEmpty, "Movie has no samples")
        return (times.sorted(), layers)
    }

    /// AVAssetWriter's HEVC samples use four-byte big-endian NAL lengths.
    static func temporalID(_ sample: CMSampleBuffer) -> Int? {
        guard let block = CMSampleBufferGetDataBuffer(sample) else { return nil }
        let count = CMBlockBufferGetDataLength(block)
        guard count > 0 else { return nil }
        var data = Data(count: count)
        let result = data.withUnsafeMutableBytes {
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count, destination: $0.baseAddress!)
        }
        precondition(result == kCMBlockBufferNoErr)
        var offset = 0
        while offset + 6 <= count {
            let length = data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
            guard length >= 2, length <= count - offset - 4 else { return nil }
            if (data[offset + 4] >> 1) & 63 <= 31 { return Int(data[offset + 5] & 7) - 1 }
            offset += 4 + length
        }
        return nil
    }
#endif
}
