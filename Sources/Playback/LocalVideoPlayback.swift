import AppKit
import AVFoundation
import QuartzCore

final class VideoView: NSView {
    let videoLayer = AVPlayerLayer()
    private let posterLayer = CALayer()
    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    init(frame: NSRect, poster: CGImage) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        posterLayer.contents = poster
        layer?.addSublayer(posterLayer)
        layer?.addSublayer(videoLayer)
        setAccessibilityElement(false)
        layout()
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = bounds
        posterLayer.frame = bounds
        CATransaction.commit()
    }
    func setFit(_ fit: Bool) {
        videoLayer.videoGravity = fit ? .resizeAspect : .resizeAspectFill
        posterLayer.contentsGravity = fit ? .resizeAspect : .resizeAspectFill
    }
}

/// The player and its last displayed frame survive lock, wake and screen changes.
final class LocalVideoPlayback {
    let window: DesktopWindow
    let screenID: String
    let player = AVQueuePlayer()
    private let looper: AVPlayerLooper
    private let view: VideoView
    private var displayObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var loopObserver: NSKeyValueObservation?

    init(screen: NSScreen, url: URL, poster: CGImage, fit: Bool, onError: @escaping (String) -> Void) {
        screenID = DesktopBackdrop.screenID(screen)
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .advance
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 1
        looper = AVPlayerLooper(player: player, templateItem: item)
        view = VideoView(frame: NSRect(origin: .zero, size: screen.frame.size), poster: poster)
        view.videoLayer.player = player
        view.videoLayer.isHidden = true
        view.setFit(fit)
        window = DesktopWindow.make(on: screen)
        window.contentView = view
        displayObserver = view.videoLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak view] layer, _ in
            let ready = layer.isReadyForDisplay
            DispatchQueue.main.async { view?.videoLayer.isHidden = !ready }
        }
        statusObserver = player.observe(\.status, options: [.new]) { player, _ in
            if player.status == .failed {
                DispatchQueue.main.async { onError(player.error?.localizedDescription ?? "Video playback failed.") }
            }
        }
        loopObserver = looper.observe(\.status, options: [.new]) { looper, _ in
            if looper.status == .failed {
                DispatchQueue.main.async { onError(looper.error?.localizedDescription ?? "Could not loop video.") }
            }
        }
        window.orderFront(nil)
    }
    func updateScreen(_ screen: NSScreen) { window.setFrame(screen.frame, display: false) }
    func setPaused(_ paused: Bool) {
        if paused { player.pause() }
        else { player.playImmediately(atRate: 1) }
    }
    func setFit(_ fit: Bool) { view.setFit(fit) }
    func close() {
        displayObserver = nil
        statusObserver = nil
        loopObserver = nil
        player.pause()
        looper.disableLooping()
        player.removeAllItems()
        view.videoLayer.player = nil
        window.orderOut(nil)
        window.close()
    }
}
