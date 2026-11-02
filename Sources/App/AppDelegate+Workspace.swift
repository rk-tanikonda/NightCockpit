import AppKit

extension AppDelegate {
    /// Pause only for sleep or an inactive login session, never for app focus changes.
    func observeWorkspace() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        let center = NSWorkspace.shared.notificationCenter
        for event in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification,
                      NSWorkspace.sessionDidResignActiveNotification] {
            center.addObserver(self, selector: #selector(sleepPlayback), name: event, object: nil)
        }
        for event in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification,
                      NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(self, selector: #selector(wakePlayback), name: event, object: nil)
        }
        for event in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            center.addObserver(self, selector: #selector(refreshWindowOrder), name: event, object: nil)
        }
    }
}
