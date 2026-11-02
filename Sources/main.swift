import AppKit

if CommandLine.arguments.contains("--restore-background") {
    do { try DesktopBackdrop.restore(); exit(0) }
    catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
}
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
