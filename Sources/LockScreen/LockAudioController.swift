import AppKit
import AVFoundation

/// macOS's aerial renderer is silent. This separate audio-only player runs only
/// after a real screen-lock notification, and stops immediately on unlock/sleep.
/// It cannot guarantee frame synchronization with the system's video renderer.
final class LockAudioController {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var locked = false
    private var sleeping = false
    private var sourceURL: URL?
    private var generation = 0
    var enabled = UserDefaults.standard.bool(forKey: "lockScreenAudio") {
        didSet { UserDefaults.standard.set(enabled, forKey: "lockScreenAudio"); updatePlayback() }
    }

    init() {
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked = true
            self?.updatePlayback()
        })
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked = false
            self?.updatePlayback()
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sleeping = true
                self?.updatePlayback()
            })
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sleeping = false
                self?.updatePlayback()
            })
        }
    }

    func configure(_ url: URL) {
        guard sourceURL != url else { return }
        sourceURL = url
        task?.cancel()
        generation += 1
        let expectedGeneration = generation
        player?.pause()
        looper?.disableLooping()
        player = nil
        looper = nil
        task = Task { @MainActor [weak self] in
            do {
                let asset = AVURLAsset(url: url)
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                guard let self = self, !Task.isCancelled, self.generation == expectedGeneration,
                      let audio = tracks.first else { return }
                let audioRange = try await audio.load(.timeRange)
                guard !Task.isCancelled, self.generation == expectedGeneration else { return }
                let composition = AVMutableComposition()
                guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
                try track.insertTimeRange(audioRange, of: audio, at: .zero)
                let player = AVQueuePlayer()
                player.volume = 0.5
                player.preventsDisplaySleepDuringVideoPlayback = false
                self.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: composition))
                self.player = player
                self.updatePlayback()
            } catch {
                NSLog("Lock audio could not load: %@", error.localizedDescription)
            }
        }
    }

    private func updatePlayback() {
        if enabled && locked && !sleeping {
            player?.play()
        } else {
            player?.pause()
            if !locked { player?.seek(to: .zero) }
        }
    }

    func stop() {
        task?.cancel()
        player?.pause()
        looper?.disableLooping()
        player = nil
    }
    deinit {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }
}
