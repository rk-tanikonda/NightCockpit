/// Independent lifecycle flags prevent an unrelated wake notification from
/// resuming a locked/sleeping desktop, while unlock resumes immediately.
struct PlaybackState {
    var stopping = false
    var manuallyPaused = false
    var locked = false
    var displayAsleep = false
    var systemAsleep = false
    var sessionActive = true
    var shouldPause: Bool { stopping || manuallyPaused || locked || displayAsleep || systemAsleep || !sessionActive }
    func shouldRepairNative(_ desired: Bool) -> Bool { desired && !stopping && !locked && !displayAsleep && !systemAsleep && sessionActive }
    mutating func unlock() {
        locked = false; displayAsleep = false; systemAsleep = false; sessionActive = true
    }
}
