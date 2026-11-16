import AppKit
import CoreText
import SwiftUI
import WebKit

// MARK: - Look (Burn's dark bento palette)

enum Look {
    static let width: CGFloat = 344
    static let gap: CGFloat = 8
    static let radius: CGFloat = 18
    static let shadowInset = EdgeInsets(top: 6, leading: 14, bottom: 18, trailing: 14)

    static let text = Color(hex: 0xF2EFEA)
    static let secondary = Color(hex: 0x9C958C)
    static let surface = Color(hex: 0x1F1D1B)
    static let neutral = Color(hex: 0x2A2826)
    static let neutralHover = Color(hex: 0x35322F)
    static let hairline = Color.white.opacity(0.08)
    static let shadow = Color.black.opacity(0.4)
    static let accent = Color(hex: 0xDFF26B)

    static var block: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

/// Bricolage Grotesque, bundled in Resources/Fonts. Falls back to SF Pro.
enum BrandFont: String {
    case medium = "BricolageGrotesque12pt-Medium"
    case bold = "BricolageGrotesque12pt-Bold"
    case display = "BricolageGrotesque96pt-ExtraBold"

    private var fallback: Font.Weight {
        switch self {
        case .medium: .medium
        case .bold: .bold
        case .display: .heavy
        }
    }

    @MainActor private static var available = false

    @MainActor static func register() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
              let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                  .filter({ $0.pathExtension == "ttf" }),
              !urls.isEmpty else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
        available = NSFont(name: BrandFont.display.rawValue, size: 12) != nil
    }

    @MainActor func font(_ size: CGFloat) -> Font {
        Self.available ? .custom(rawValue, fixedSize: size) : .system(size: size, weight: fallback)
    }
}

// MARK: - Panel

struct PanelView: View {
    @ObservedObject var store: Store
    @ObservedObject var state: PanelState

    var body: some View {
        VStack(spacing: Look.gap) {
            if let featured = store.wallpapers.first {
                WallpaperTile(wallpaper: featured, large: true, store: store, state: state)
                    .reveal(state.visible, index: 0)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Look.gap), GridItem(.flexible(), spacing: Look.gap)],
                      spacing: Look.gap) {
                ForEach(Array(store.wallpapers.dropFirst().enumerated()), id: \.element.id) { index, wallpaper in
                    WallpaperTile(wallpaper: wallpaper, large: false, store: store, state: state)
                        .reveal(state.visible, index: index + 1)
                }
            }
            Footer(store: store)
                .reveal(state.visible, index: store.wallpapers.count)
        }
        .frame(width: Look.width)
        .padding(Look.shadowInset)
        .environment(\.colorScheme, .dark)
    }
}

/// A live preview of a wallpaper. Click to put it on the desktop.
struct WallpaperTile: View {
    let wallpaper: Wallpaper
    let large: Bool
    @ObservedObject var store: Store
    @ObservedObject var state: PanelState
    @State private var hovering = false

    private var selected: Bool { store.current == wallpaper.id }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { store.current = wallpaper.id }
        } label: {
            ZStack(alignment: .bottomLeading) {
                Color.black
                if state.visible {
                    LivePreview(url: wallpaper.url, paused: store.paused)
                        .transition(.opacity.animation(.easeOut(duration: 0.3)))
                }
                // Keeps the name readable over bright parts of the preview.
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                HStack(alignment: .lastTextBaseline) {
                    Text(wallpaper.title)
                        .font(large ? BrandFont.display.font(26) : BrandFont.bold.font(13))
                        .foregroundStyle(Look.text)
                    Spacer(minLength: 0)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: large ? 11 : 9, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(width: large ? 22 : 18, height: large ? 22 : 18)
                            .background(Look.accent, in: Circle())
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .padding(large ? 14 : 10)
            }
            .aspectRatio(16 / (large ? 9 : 10), contentMode: .fit)
            .clipShape(Look.block)
            .overlay {
                Look.block.strokeBorder(selected ? Look.accent : hovering ? Color.white.opacity(0.22) : Look.hairline,
                                        lineWidth: selected ? 1.5 : 0.5)
            }
            .shadow(color: Look.shadow, radius: 10, y: 4)
            .contentShape(Look.block)
        }
        .buttonStyle(PressStyle())
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .accessibilityLabel(wallpaper.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Status, pause and the app menu, on one floating pill like Burn's footer.
struct Footer: View {
    @ObservedObject var store: Store

    var body: some View {
        HStack(spacing: 6) {
            Text(store.paused ? "Animacja wstrzymana" : "Animacja włączona")
                .font(BrandFont.medium.font(13))
                .foregroundStyle(Look.secondary)
                .contentTransition(.opacity)
                .padding(.leading, 10)
            Spacer(minLength: 0)
            RoundButton(systemName: store.paused ? "play.fill" : "pause.fill",
                        label: store.paused ? "Wznów animację" : "Wstrzymaj animację") {
                withAnimation(.easeOut(duration: 0.15)) { store.paused.toggle() }
            }
            Menu {
                Toggle("Uruchamiaj przy logowaniu", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { _ in store.toggleLaunchAtLogin() }))
                Divider()
                Button("Zakończ nxpaper") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Look.secondary)
                    .frame(width: 32, height: 32)
                    .background(Look.neutral, in: Circle())
                    .contentShape(Circle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Ustawienia")
        }
        .padding(6)
        .background {
            Capsule().fill(Look.surface)
                .overlay { Capsule().strokeBorder(Look.hairline, lineWidth: 0.5) }
                .shadow(color: Look.shadow, radius: 10, y: 4)
        }
    }
}

struct RoundButton: View {
    let systemName: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hovering ? Look.text : Look.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 32)
                .background(hovering ? Look.neutralHover : Look.neutral, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        .help(label)
        .accessibilityLabel(label)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct Reveal: ViewModifier {
    let visible: Bool
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 6)
            // Only animate in; hiding happens after the panel is gone.
            .animation(visible ? .easeOut(duration: 0.22).delay(Double(index) * 0.03) : nil, value: visible)
    }
}

extension View {
    func reveal(_ visible: Bool, index: Int) -> some View { modifier(Reveal(visible: visible, index: index)) }
}

// MARK: - Live preview

/// The wallpaper itself, running small. Fades in once the page has drawn.
struct LivePreview: NSViewRepresentable {
    let url: URL
    let paused: Bool

    func makeNSView(context: Context) -> PassiveWebView {
        let view = PassiveWebView(url: url)
        view.alphaValue = 0
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateNSView(_ view: PassiveWebView, context: Context) {
        context.coordinator.paused = paused
        view.setPaused(paused)
    }

    func makeCoordinator() -> Coordinator { Coordinator(paused: paused) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var paused: Bool
        init(paused: Bool) { self.paused = paused }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            (webView as? PassiveWebView)?.setPaused(paused)
            // Give WebGL a frame before showing it, so the tile never blinks.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    webView.animator().alphaValue = 1
                }
            }
        }
    }
}
