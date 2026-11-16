import AppKit
import ServiceManagement

struct Wallpaper: Identifiable, Equatable {
    let id: String
    let title: String
    let url: URL
}

/// Wallpapers on disk and the user's choices. The desktop windows and the panel both follow it.
@MainActor
final class Store: ObservableObject {
    /// Shown first and full width in the panel.
    static let featured = "fala"

    @Published private(set) var wallpapers: [Wallpaper] = []
    @Published var current: String {
        didSet { UserDefaults.standard.set(current, forKey: "wallpaper") }
    }
    @Published var paused: Bool {
        didSet { UserDefaults.standard.set(paused, forKey: "paused") }
    }
    /// Off hands the desktop back to the system wallpaper.
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(!enabled, forKey: "disabled") }
    }
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    init() {
        current = UserDefaults.standard.string(forKey: "wallpaper") ?? Store.featured
        paused = UserDefaults.standard.bool(forKey: "paused")
        enabled = !UserDefaults.standard.bool(forKey: "disabled")
        reload()
    }

    var currentWallpaper: Wallpaper? { wallpapers.first { $0.id == current } ?? wallpapers.first }

    func reload() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("wallpapers"),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return }
        wallpapers = files
            .filter { $0.pathExtension == "html" }
            .map { url in
                let id = url.deletingPathExtension().lastPathComponent
                return Wallpaper(id: id, title: Self.title(of: url) ?? id.capitalized, url: url)
            }
            .sorted { a, b in
                if a.id == Store.featured || b.id == Store.featured { return a.id == Store.featured }
                return a.title.localizedCompare(b.title) == .orderedAscending
            }
        if !wallpapers.contains(where: { $0.id == current }), let first = wallpapers.first { current = first.id }
    }

    func toggleLaunchAtLogin() {
        do {
            if launchAtLogin { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Nie udało się zmienić startu przy logowaniu"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// The page's <title>, so a wallpaper names itself.
    private static func title(of url: URL) -> String? {
        guard let html = try? String(contentsOf: url, encoding: .utf8),
              let open = html.range(of: "<title>"),
              let close = html.range(of: "</title>", range: open.upperBound..<html.endIndex)
        else { return nil }
        let title = html[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
}
