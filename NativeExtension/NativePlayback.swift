import AppKit
import AVFoundation
import QuartzCore

/// One AVPlayer owns the original multiplexed audio/video timeline. Video
/// output is presented in macOS-hosted layers; there are no application windows
/// above the login UI and no independent audio timer or rate correction.
final class NativePlayback {
    static let shared = NativePlayback()
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var itemObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var output: AVPlayerItemVideoOutput?
    private var outputItem: AVPlayerItem?
    private var timer: DispatchSourceTimer?
    private var observers: [NSObjectProtocol] = []
    private var locked = false
    private var receivedLockState = false
    private var sleeping = false
    private var settings = NativePlaybackSettings.values
    private(set) var presentedFrames = 0
    private(set) var lastVideoTime: Double?
    private let allowAudio: Bool
    var hosted: [String: HostedWallpaper] = [:]

    init(url: URL = NativePlaybackSettings.movieURL, allowAudio: Bool = true) {
        self.allowAudio = allowAudio
        player.isMuted = true
        player.volume = 0.5
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 1
        itemObserver = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.attachOutput() }
        }
        looper = AVPlayerLooper(player: player, templateItem: item)
        statusObserver = player.observe(\.status, options: [.new]) { player, _ in
            debugLog("media status=\(player.status.rawValue) error=\(player.error?.localizedDescription ?? "none")")
        }
        let distributed = DistributedNotificationCenter.default()
        for (name, value) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            observers.append(distributed.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                self?.locked = value; self?.receivedLockState = true; self?.reconcile()
            })
        }
        observers.append(distributed.addObserver(forName: Notification.Name("org.nightcockpit.native.settingsChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.settings = NativePlaybackSettings.values; self?.reconcile()
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for (name, value) in [(NSWorkspace.screensDidSleepNotification, true), (NSWorkspace.screensDidWakeNotification, false),
                              (NSWorkspace.willSleepNotification, true), (NSWorkspace.didWakeNotification, false)] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sleeping = value; self?.reconcile()
            })
        }
    }

    private func attachOutput() {
        if let output, let outputItem { outputItem.remove(output) }
        outputItem = player.currentItem
        let next = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: String]()
        ])
        output = next
        outputItem?.add(next)
    }

    func reconcile() {
        let visible = hosted.values.filter { !$0.preview && $0.mode != "default" }
        let active = !sleeping && (locked || !visible.isEmpty) && !hosted.isEmpty
        let audioLocked = receivedLockState ? locked : visible.contains { $0.mode == "locked" }
        player.isMuted = !(allowAudio && active && audioLocked && (settings["sound"] as? Bool ?? true))
        if active {
            player.playImmediately(atRate: 1)
            if timer == nil {
                let clock = DispatchSource.makeTimerSource(queue: .main)
                clock.schedule(deadline: .now(), repeating: 1.0 / 60, leeway: .milliseconds(2))
                clock.setEventHandler { [weak self] in self?.presentFrame() }
                timer = clock; clock.resume()
            }
        } else {
            player.pause(); player.isMuted = true
            timer?.cancel(); timer = nil
        }
        debugLog("state active=\(active) muted=\(player.isMuted) locked=\(locked) hosts=\(hosted.count)")
    }

    private func presentFrame() {
        guard let output else { return }
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        var displayedTime = CMTime.invalid
        guard output.hasNewPixelBuffer(forItemTime: itemTime),
              let image = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: &displayedTime) else { return }
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: image, formatDescriptionOut: &format) == noErr,
              let format else { return }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: image, formatDescription: format,
                                                      sampleTiming: &timing, sampleBufferOut: &sample) == noErr, let sample else { return }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) as? [NSMutableDictionary] {
            attachments.first?[kCMSampleAttachmentKey_DisplayImmediately] = true
        }
        for host in hosted.values {
            if host.video.sampleBufferRenderer.status == .failed { host.video.sampleBufferRenderer.flush() }
            host.video.sampleBufferRenderer.enqueue(sample)
        }
        presentedFrames += 1
        lastVideoTime = displayedTime.seconds
        if presentedFrames == 1 || presentedFrames % 300 == 0 {
            debugLog("frame count=\(presentedFrames) player=\(player.currentTime().seconds) video=\(displayedTime.seconds) rate=\(player.rate) muted=\(player.isMuted)")
        }
    }
}

final class HostedWallpaper {
    let context: CAContext
    let root = CALayer()
    let video = AVSampleBufferDisplayLayer()
    var mode: String
    let preview: Bool
    init(context: CAContext, size: CGSize, scale: CGFloat, mode: String, preview: Bool) {
        self.context = context; self.mode = mode; self.preview = preview
        root.frame = CGRect(origin: .zero, size: size); root.contentsScale = scale
        root.backgroundColor = NSColor.black.cgColor
        if let image = NSImage(contentsOf: NativePlaybackSettings.posterURL) {
            root.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            root.contentsGravity = .resizeAspectFill
        }
        video.frame = root.bounds; video.videoGravity = .resizeAspectFill
        video.contentsScale = scale
        root.addSublayer(video); context.layer = root
    }
}
