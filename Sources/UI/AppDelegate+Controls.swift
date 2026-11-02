import AppKit
import UniformTypeIdentifiers

extension AppDelegate {
    func setStatus(_ message: String) {
        statusLabel.stringValue = message
        statusItem?.button?.toolTip = message
    }

    @objc func chooseVideo() {
        let panel = NSOpenPanel()
        panel.title = "Choose a wallpaper video"
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { loadLocalVideo(url) }
    }

    @objc func showControls() {
        if controlWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 250),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false
            )
            window.title = "Night Cockpit"
            window.isReleasedWhenClosed = false
            let heading = NSTextField(labelWithString: "Wallpaper settings")
            heading.font = .boldSystemFont(ofSize: 22)
            statusLabel.font = .systemFont(ofSize: 14)
            statusLabel.isSelectable = true
            statusLabel.maximumNumberOfLines = 0
            let choose = NSButton(title: "Change video…", target: self, action: #selector(chooseVideo))
            let hide = NSButton(title: "Close settings", target: self, action: #selector(hideControls))
            let row = NSStackView(views: [choose, hide])
            row.spacing = 12
            let stack = NSStackView(views: [heading, statusLabel, row])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 22
            stack.translatesAutoresizingMaskIntoConstraints = false
            window.contentView!.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
                stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
                stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -24)
            ])
            window.center()
            controlWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        controlWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func hideControls() { controlWindow?.orderOut(nil) }
}
