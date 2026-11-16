import AppKit
import SwiftUI

/// Whether the panel is on screen. Previews only exist while it is, so a closed panel costs nothing.
@MainActor
final class PanelState: ObservableObject {
    @Published var visible = false
}

/// Menu bar icon that opens a floating, see-through panel underneath it, like Burn's.
@MainActor
final class PanelController: NSObject {
    private let store: Store
    private let state = PanelState()
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panel = FloatingPanel()
    private let host: NSHostingView<AnyView>
    private var outsideClicks: Any?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isOpen = false
    /// Bumped on every open so a fade-out that finishes late doesn't hide a reopened panel.
    private var generation = 0

    init(store: Store) {
        self.store = store
        host = NSHostingView(rootView: AnyView(PanelView(store: store, state: state)))
        super.init()
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        panel.contentView = host
        panel.onCancel = { [weak self] in self?.close() }

        let image = NSImage(systemSymbolName: "water.waves", accessibilityDescription: "nxpaper")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.target = self
        item.button?.action = #selector(toggle)
    }

    @objc private func toggle() { isOpen ? close() : open() }

    /// Opens the panel without a click, for screenshots (`--open-panel`).
    func toggleFromScript() { toggle() }

    private func open() {
        isOpen = true
        generation += 1
        store.reload()
        place()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0
            panel.animator().alphaValue = 1
        }
        panel.makeKeyAndOrderFront(nil)
        // Next turn of the run loop, so the content is laid out hidden and animates in.
        DispatchQueue.main.async { [weak self] in self?.state.visible = true }

        removeMonitors()
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) {
            [weak self] _ in MainActor.assumeIsolated { self?.close() }
        }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification]
            .map { name in
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.close() }
                }
            }
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        removeMonitors()
        let current = generation
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == current else { return }
                self.panel.orderOut(nil)
                self.state.visible = false
            }
        }
    }

    private func removeMonitors() {
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        outsideClicks = nil
        workspaceObservers = []
    }

    /// Hangs the panel under the menu bar icon, centered on it and kept on screen.
    private func place() {
        guard let button = item.button, let window = button.window,
              let screen = window.screen ?? NSScreen.main else { return }
        let icon = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = screen.visibleFrame
        let size = host.fittingSize
        let top = icon.minY - 2
        let x = max(min(icon.midX - size.width / 2, visible.maxX - size.width), visible.minX).rounded()
        panel.setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)
    }
}

/// Borderless, see-through panel: the blocks float over the desktop with nothing behind them.
private final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
