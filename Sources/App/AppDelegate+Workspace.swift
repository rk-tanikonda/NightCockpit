import AppKit

extension AppDelegate {
    func observeWorkspace() {
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        let events: [(Notification.Name, Selector)] = [
            (NSWorkspace.screensDidSleepNotification, #selector(displaySlept)),
            (NSWorkspace.screensDidWakeNotification, #selector(displayWoke)),
            (NSWorkspace.willSleepNotification, #selector(systemSlept)),
            (NSWorkspace.didWakeNotification, #selector(systemWoke)),
            (NSWorkspace.sessionDidResignActiveNotification, #selector(sessionResigned)),
            (NSWorkspace.sessionDidBecomeActiveNotification, #selector(sessionActivated)),
            (NSWorkspace.activeSpaceDidChangeNotification, #selector(checkNativeSelection))
        ]
        for (event, selector) in events { workspace.addObserver(self, selector: selector, name: event, object: nil) }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }
}
