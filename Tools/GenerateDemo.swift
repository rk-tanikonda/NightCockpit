import AppKit
import AVFoundation

/// Original procedural artwork and synthesized sound. No downloaded footage,
/// samples, textures or third-party marks. Generated media is CC0; see MEDIA_LICENSE.md.
@main struct GenerateDemo {
    static let width = 1920, height = 1080, fps: Int32 = 30, seconds = 12
    static let cyan = NSColor(calibratedRed: 0.22, green: 0.84, blue: 0.94, alpha: 1)

    @MainActor static func main() async throws {
        guard #available(macOS 26.0, *), CommandLine.arguments.count == 2 else {
            throw NSError(domain: "GenerateDemo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Requires macOS 26+ SDK. Pass an output MP4 path."])
        }
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let video = temporary.appendingPathComponent("video.mov"), audio = temporary.appendingPathComponent("audio.m4a")
        try await renderVideo(video)
        try renderAudio(audio)
        let composition = AVMutableComposition()
        let range = CMTimeRange(start: .zero, duration: CMTime(value: Int64(seconds), timescale: 1))
        for (url, type) in [(video, AVMediaType.video), (audio, .audio)] {
            let asset = AVURLAsset(url: url)
            let track = try await asset.loadTracks(withMediaType: type)[0]
            try composition.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid)!.insertTimeRange(range, of: track, at: .zero)
        }
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else { return }
        let output = temporary.appendingPathComponent("wallpaper.mp4")
        try await exporter.export(to: output, as: .mp4)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw NSError(domain: "GenerateDemo", code: 2, userInfo: [NSLocalizedDescriptionKey: "Output already exists; choose another path."])
        }
        try FileManager.default.copyItem(at: output, to: destination)
        print("Generated original 1080p/30 fps, 12-second looping video with synthesized stereo audio: \(destination.path)")
    }

    @available(macOS 26.0, *)
    @MainActor static func renderVideo(_ url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_000_000, AVVideoExpectedSourceFrameRateKey: fps, AVVideoMaxKeyFrameIntervalKey: 60]
        ])
        let raw: [String: any Sendable] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        let attributes = CVPixelBufferCreationAttributes(CVPixelBufferAttributes(rawAttributes: raw))!
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try writer.start(); writer.startSession(atSourceTime: .zero)
        for frame in 0..<(seconds * Int(fps)) {
            let buffer = try receiver.pixelBufferPool!.makeMutablePixelBuffer()
            buffer.withUnsafeBuffer { rawBuffer in
                CVPixelBufferLockBaseAddress(rawBuffer, []); defer { CVPixelBufferUnlockBaseAddress(rawBuffer, []) }
                let context = CGContext(data: CVPixelBufferGetBaseAddress(rawBuffer), width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(rawBuffer), space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
                context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
                draw(context, time: Double(frame) / Double(fps))
            }
            try await receiver.append(CVReadOnlyPixelBuffer(buffer), with: CMTime(value: Int64(frame), timescale: fps))
        }
        writer.endSession(atSourceTime: CMTime(value: Int64(seconds), timescale: 1))
        receiver.finish(); await writer.finishWriting()
        if let error = writer.error { throw error }
    }

    static func renderAudio(_ url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let count = AVAudioFrameCount(seconds * 48_000)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buffer.frameLength = count
        for index in 0..<Int(count) {
            let t = Double(index) / 48_000
            let phase = 2 * Double.pi * 60 * t - 96 * (cos(2 * Double.pi * t / 12) - 1)
            let engine = 0.075 * sin(phase) + 0.028 * sin(2 * phase) + 0.009 * sin(3 * phase)
            let air = 0.007 * sin(2 * Double.pi * 480 * t) * (0.5 + 0.5 * sin(2 * Double.pi * t / 3))
            buffer.floatChannelData![0][index] = Float(engine + air)
            buffer.floatChannelData![1][index] = Float(engine - air)
        }
        let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 128_000], commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }

    @MainActor static func draw(_ c: CGContext, time t: Double) {
        let wave = sin(2 * Double.pi * t / 12), sway = 60 * wave
        func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
        func line(_ from: CGPoint, _ to: CGPoint, _ color: CGColor, _ width: CGFloat) {
            c.setStrokeColor(color); c.setLineWidth(width); c.move(to: from); c.addLine(to: to); c.strokePath()
        }
        func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ tint: NSColor) {
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: true)
            (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: size, weight: .medium), .foregroundColor: tint])
            NSGraphicsContext.restoreGraphicsState()
        }
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0.005,0.012,0.033), color(0.025,0.07,0.12)] as CFArray, locations: [0,1])!
        c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x:0,y:800), options: [.drawsAfterEndLocation])
        for i in 0..<90 {
            let x = CGFloat((i * 277 + 53) % 1920), y = CGFloat((i * 137 + 31) % 420)
            c.setFillColor(color(0.65,0.84,0.95,0.12 + CGFloat(i % 4) * 0.05)); c.fillEllipse(in: CGRect(x:x,y:y,width:2,height:2))
        }
        let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0.05,0.4,0.55,0.28),color(0,0,0,0)] as CFArray, locations:[0,1])!
        c.drawRadialGradient(glow, startCenter: CGPoint(x:960+sway,y:465), startRadius:0,endCenter:CGPoint(x:960+sway,y:465),endRadius:800,options:[])
        for i in 0..<50 {
            let x = CGFloat(i * 40), h = CGFloat(35 + (i * 71) % 150)
            c.setFillColor(color(0.012,0.029,0.05)); c.fill(CGRect(x:x,y:455-h,width:32,height:h))
            for row in 0..<Int(h/18) {
                c.setFillColor(color(0.2,0.64,0.74,CGFloat((i+row)%3 == 0 ? 0.5 : 0.1)))
                c.fill(CGRect(x:x+8,y:455-h+CGFloat(row*18)+8,width:3,height:5))
            }
        }
        c.setFillColor(color(0.012,0.018,0.03)); c.move(to:CGPoint(x:960+sway,y:450));c.addLine(to:CGPoint(x:1880,y:850));c.addLine(to:CGPoint(x:40,y:850));c.closePath();c.fillPath()
        line(CGPoint(x:960+sway,y:450),CGPoint(x:80,y:850),color(0.15,0.65,0.8,0.7),3)
        line(CGPoint(x:960+sway,y:450),CGPoint(x:1840,y:850),color(0.15,0.65,0.8,0.7),3)
        for i in 0..<20 {
            let z = (Double(i)/20 + t/2).truncatingRemainder(dividingBy:1), q = z*z
            let y = 455+390*q, center = 960+sway*(1-q)
            line(CGPoint(x:center,y:y),CGPoint(x:center,y:y+4+35*q),color(0.55,0.86,0.92,0.35+0.45*q),CGFloat(1+5*q))
            for side in [-1.0,1.0] {
                let x = center+side*(70+1120*q)
                line(CGPoint(x:x,y:y-22-90*q),CGPoint(x:x,y:y),color(0.2,0.8,0.95,0.12+0.5*q),CGFloat(1+8*q))
                line(CGPoint(x:x-30*q,y:y+8),CGPoint(x:x+30*q,y:y+8),color(0.08,0.4,0.65,0.15),CGFloat(1+5*q))
            }
        }
        // Windshield pillars and a quiet illuminated instrument panel.
        c.setFillColor(color(0.004,0.008,0.014));c.fill(CGRect(x:0,y:0,width:1920,height:44))
        line(CGPoint(x:100,y:0),CGPoint(x:275,y:845),color(0.005,0.01,0.018),65)
        line(CGPoint(x:1820,y:0),CGPoint(x:1645,y:845),color(0.005,0.01,0.018),65)
        c.addPath(CGPath(roundedRect:CGRect(x:120,y:790,width:1680,height:320),cornerWidth:100,cornerHeight:100,transform:nil));c.fillPath()
        line(CGPoint(x:240,y:817),CGPoint(x:1680,y:817),color(0.12,0.5,0.65,0.45),2)
        for i in 0..<48 {
            let a = 2.4+Double(i)/47*4.6, r = 128.0
            let active = Double(i) < 31+7*wave
            line(CGPoint(x:960+cos(a)*r,y:965+sin(a)*r),CGPoint(x:960+cos(a)*(r-10),y:965+sin(a)*(r-10)),active ? cyan.cgColor : color(0.1,0.2,0.25),3)
        }
        text(String(format:"%03d",110+Int(8*wave)),891,900,72,.white)
        text("KM / H",916,984,15,cyan)
        text("NIGHT COCKPIT",285,866,23,cyan)
        text("AFTER HOURS",285,905,14,NSColor(calibratedWhite:0.47,alpha:1))
        text("MIDNIGHT DRIVE",1290,866,20,cyan)
        text(String(format:"%04d  RPM",4200+Int(800*wave)),1290,910,24,.white)
        for i in 0..<28 {
            c.setFillColor(color(0.18,0.65,0.75, i < 18+Int(4*wave) ? 0.65:0.1))
            c.fill(CGRect(x:1290+CGFloat(i*9),y:966,width:5,height:12))
        }
    }
}
