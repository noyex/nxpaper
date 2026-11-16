import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: Store!
    private var desktop: DesktopController!
    private var panel: PanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        BrandFont.register()
        store = Store()
        desktop = DesktopController(store: store)
        panel = PanelController(store: store)
        if CommandLine.arguments.contains("--open-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.panel.toggleFromScript() }
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
