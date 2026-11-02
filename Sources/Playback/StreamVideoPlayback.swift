import AppKit
import WebKit

/// Renders our own video-only HTML. It never navigates to a wallpaper website.
/// A local file is still preferred for offline playback and predictable decoding.
final class StreamVideoPlayback: NSObject, WallpaperPlayback, WKScriptMessageHandler, WKNavigationDelegate {
    let window: DesktopWindow
    private let webView: WKWebView
    private let url: URL
    private let onStatus: (String) -> Void
    private var paused = false
    private var fit: Bool
    private var closed = false
    private var needsReload = false
    private var retryCount = 0
    private var retryWork: DispatchWorkItem?
    private let cover = NSView()

    init(screen: NSScreen, url: URL, fit: Bool, onStatus: @escaping (String) -> Void) {
        self.url = url
        self.fit = fit
        self.onStatus = onStatus
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: NSRect(origin: .zero, size: screen.frame.size), configuration: config)
        window = DesktopWindow.make(on: screen)
        super.init()
        config.userContentController.add(self, name: "wallpaperStatus")
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView
        // A native cover stays above WebKit until the first playing event.
        cover.frame = webView.bounds
        cover.autoresizingMask = [.width, .height]
        cover.wantsLayer = true
        cover.layer?.backgroundColor = NSColor.black.cgColor
        webView.addSubview(cover)
        window.orderFrontRegardless()
        loadPlayer()
    }

    private func loadPlayer() {
        guard !closed else { return }
        retryWork?.cancel()
        retryWork = nil
        guard !paused else { needsReload = true; return }
        needsReload = false
        cover.isHidden = false
        guard let file = Bundle.main.url(forResource: "stream-player", withExtension: "html"),
              let template = try? String(contentsOf: file, encoding: .utf8),
              let data = try? JSONSerialization.data(withJSONObject: ["url": url.absoluteString, "fit": fit, "paused": paused]),
              let json = String(data: data, encoding: .utf8) else {
            onStatus("Missing stream-player.html. Rebuild the application.")
            return
        }
        // JSON is escaped for an inline script, including hostile </script> URLs.
        let safeJSON = json.replacingOccurrences(of: "<", with: "\\u003c")
        let html = template.replacingOccurrences(of: "__CONFIG_JSON__", with: safeJSON)
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !closed, message.frameInfo.isMainFrame,
              let body = message.body as? [String: String],
              let kind = body["kind"], let text = body["message"] else { return }
        onStatus(String(text.prefix(500)))
        switch kind {
        case "playing":
            cover.isHidden = true
            retryWork?.cancel()
            retryWork = nil
            retryCount = 0
            needsReload = false
            if paused { setPaused(true) }
        case "error": scheduleRetry()
        default: break
        }
    }

    private func scheduleRetry() {
        guard !closed else { return }
        needsReload = true
        guard !paused, retryWork == nil else { return }
        let delay = min(300.0, 10.0 * pow(2, Double(min(retryCount, 5))))
        retryCount += 1
        onStatus("Video unavailable. Retrying in \(Int(delay)) seconds. Local files work offline.")
        let work = DispatchWorkItem { [weak self] in self?.loadPlayer() }
        retryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func setPaused(_ value: Bool) {
        paused = value
        if value { retryWork?.cancel(); retryWork = nil }
        else if needsReload { loadPlayer() }
        webView.setAllMediaPlaybackSuspended(value, completionHandler: nil)
        webView.evaluateJavaScript("window.wallpaper?.setPaused(\(value));", completionHandler: nil)
    }

    func setFit(_ value: Bool) {
        fit = value
        webView.evaluateJavaScript("window.wallpaper?.setFit(\(value));", completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { scheduleRetry() }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { scheduleRetry() }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { scheduleRetry() }

    func close() {
        closed = true
        retryWork?.cancel()
        retryWork = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "wallpaperStatus")
        webView.navigationDelegate = nil
        webView.setAllMediaPlaybackSuspended(true, completionHandler: nil)
        webView.stopLoading()
        window.close()
    }
}
