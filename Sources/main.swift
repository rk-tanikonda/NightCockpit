import AppKit

// The entry point creates the app once and keeps its delegate alive.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
