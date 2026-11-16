import AppKit
import Combine
import WebKit

/// A WKWebView that never takes clicks, so whatever sits on top of it gets them.
final class PassiveWebView: WKWebView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var acceptsFirstResponder: Bool { false }

    convenience init(url: URL) {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        self.init(frame: .zero, configuration: config)
        setValue(false, forKey: "drawsBackground")
        loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func setPaused(_ paused: Bool) {
        evaluateJavaScript("window.setPaused && window.setPaused(\(paused))")
    }
}

/// One borderless window per screen, pinned to the desktop level (below Finder's icons).
final class WallpaperWindow: NSWindow {
    let webView: PassiveWebView

    init(screen: NSScreen, url: URL) {
        webView = PassiveWebView(url: url)
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        ignoresMouseEvents = true
        isOpaque = true
        hasShadow = false
        backgroundColor = .black
        isReleasedWhenClosed = false
        webView.autoresizingMask = [.width, .height]
        contentView = webView
    }

    /// Fully covered by other windows or a full-screen app.
    var isCovered: Bool { !occlusionState.contains(.visible) }
}

/// Keeps a wallpaper window on every screen and pauses them when nobody can see them.
@MainActor
final class DesktopController: NSObject {
    private let store: Store
    private var windows: [WallpaperWindow] = []
    private var shown: String?
    private var screensAsleep = false
    private var subscriptions: Set<AnyCancellable> = []

    init(store: Store) {
        self.store = store
        super.init()
        rebuild()

        store.$current.dropFirst().removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild() }.store(in: &subscriptions)
        store.$paused.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updatePause() }.store(in: &subscriptions)

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        nc.addObserver(self, selector: #selector(updatePause), name: NSWindow.didChangeOcclusionStateNotification, object: nil)

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensSlept), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensWoke), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }

    private func rebuild() {
        guard let wallpaper = store.currentWallpaper else { return }
        let old = windows
        windows = NSScreen.screens.map { WallpaperWindow(screen: $0, url: wallpaper.url) }
        // New windows come in above the old ones, so the switch never flashes the system wallpaper.
        for w in windows { w.alphaValue = 0; w.orderFront(nil) }
        shown = wallpaper.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                for w in self?.windows ?? [] { w.animator().alphaValue = 1 }
            } completionHandler: {
                old.forEach { $0.close() }
            }
            self?.updatePause()
        }
    }

    @objc private func screensChanged() {
        // Display changes arrive in bursts; rebuild once they settle.
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(rebuildAfterScreenChange), object: nil)
        perform(#selector(rebuildAfterScreenChange), with: nil, afterDelay: 0.5)
    }

    @objc private func rebuildAfterScreenChange() { rebuild() }
    @objc private func screensSlept() { screensAsleep = true; updatePause() }
    @objc private func screensWoke() { screensAsleep = false; updatePause() }

    @objc private func updatePause() {
        for w in windows { w.webView.setPaused(store.paused || screensAsleep || w.isCovered) }
    }
}
