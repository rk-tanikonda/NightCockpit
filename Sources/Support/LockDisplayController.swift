import Foundation
import IOKit.pwr_mgt

/// A process-owned idle-display hold, used only for an explicitly enabled lock
/// session. It changes no power preferences and cannot override lid/forced sleep.
final class LockDisplayController {
    private let acquire: () -> IOPMAssertionID?
    private let release: (IOPMAssertionID) -> Void
    private var assertion: IOPMAssertionID?

    init(acquire: @escaping () -> IOPMAssertionID? = LockDisplayController.acquireAssertion,
         release: @escaping (IOPMAssertionID) -> Void = { _ = IOPMAssertionRelease($0) }) {
        self.acquire = acquire
        self.release = release
    }

    func setActive(_ active: Bool) {
        if active {
            if assertion == nil { assertion = acquire() }
        } else { stop() }
    }

    func stop() {
        guard let current = assertion else { return }
        assertion = nil
        release(current)
    }

    private static func acquireAssertion() -> IOPMAssertionID? {
        var identifier: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                               IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                               "Night Cockpit: keep locked video visible" as CFString, &identifier)
        guard result == kIOReturnSuccess else {
            NSLog("Could not keep the Lock Screen display awake: %d", result)
            return nil
        }
        return identifier
    }

    deinit { stop() }
}
