import AppKit
import AVFoundation
import QuartzCore

final class VideoView: NSView {
    let videoLayer = AVPlayerLayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(videoLayer)
    }
    required init?(coder: NSCoder) { fatalError("Not used") }
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = bounds
        CATransaction.commit()
    }
}

/// Native, offline playback for a local video file.
final class LocalVideoPlayback: WallpaperPlayback {
    let window: DesktopWindow
    let player: AVQueuePlayer
    let looper: AVPlayerLooper
    let view: VideoView
    private var statusObserver: NSKeyValueObservation?
    private var loopObserver: NSKeyValueObservation?

    init(screen: NSScreen, url: URL, fit: Bool, onError: @escaping (String) -> Void) {
        player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.actionAtItemEnd = .advance
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        view = VideoView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.videoLayer.player = player
        view.videoLayer.videoGravity = fit ? .resizeAspect : .resizeAspectFill
        window = DesktopWindow.make(on: screen)
        window.contentView = view
        statusObserver = player.observe(\.status, options: [.new]) { player, _ in
            if player.status == .failed {
                DispatchQueue.main.async { onError(player.error?.localizedDescription ?? "Video playback failed.") }
            }
        }
        loopObserver = looper.observe(\.status, options: [.new]) { looper, _ in
            if looper.status == .failed {
                DispatchQueue.main.async { onError(looper.error?.localizedDescription ?? "The video could not be looped.") }
            }
        }
        window.orderFrontRegardless()
    }
    func setPaused(_ paused: Bool) {
        paused ? player.pause() : player.play()
    }

    func setFit(_ fit: Bool) {
        view.videoLayer.videoGravity = fit ? .resizeAspect : .resizeAspectFill
    }

    func close() {
        statusObserver = nil
        loopObserver = nil
        player.pause()
        looper.disableLooping()
        player.removeAllItems()
        view.videoLayer.player = nil
        window.close()
    }
}
