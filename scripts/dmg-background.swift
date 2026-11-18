// Draws the DMG window background (660x400 pt) as background.png and background@2x.png.
//   swift scripts/dmg-background.swift <output-dir>
// Icon positions in package.sh must match the layout here: nxpaper at (180, 196), Applications at (480, 196).
import AppKit

let size = CGSize(width: 660, height: 400)
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let fonts = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../Resources/Fonts")

func font(_ file: String, _ size: CGFloat) -> NSFont {
    let url = fonts.appendingPathComponent(file) as CFURL
    guard let desc = (CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor])?.first else {
        fatalError("Missing font \(file)")
    }
    return CTFontCreateWithFontDescriptor(desc, size, nil) as NSFont
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let ink = color(0x1C1A17)

func draw(in ctx: CGContext) {
    color(0xF7F5F2).setFill()
    ctx.fill(CGRect(origin: .zero, size: size))

    // A faint dot field along the bottom edge, a nod to the Fala wallpaper: rows get denser and
    // smaller toward the horizon and ride a slow wave. Fades out well below the icon labels.
    let top: CGFloat = 308
    for row in 0..<14 {
        let p = CGFloat(row) / 13                     // 0 at the horizon, 1 at the bottom edge
        let y0 = top + (size.height + 6 - top) * p * p
        let spacing = 9 + 17 * p
        let radius = 0.55 + 1.15 * p
        let amp = 1.5 + 6 * p
        let alpha = 0.05 * (1 - p) + 0.17 * p
        let fade = min(1, p * 6)                      // soft start at the horizon
        var x = size.width / 2 - spacing * CGFloat(Int(size.width / 2 / spacing) + 1)
        var col = 0
        while x < size.width + spacing {
            let h = sin(Double(col) * 0.33 + Double(row) * 0.5) * cos(Double(row) * 0.3 + Double(col) * 0.05)
            let y = y0 - CGFloat(h) * amp
            color(0x7A746C, alpha * fade).setFill()
            ctx.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            x += spacing
            col += 1
        }
    }

    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 262, y: 198))
    arrow.curve(to: CGPoint(x: 392, y: 190), controlPoint1: CGPoint(x: 296, y: 156), controlPoint2: CGPoint(x: 360, y: 152))
    arrow.move(to: CGPoint(x: 376, y: 188))
    arrow.line(to: CGPoint(x: 393, y: 192))
    arrow.line(to: CGPoint(x: 395, y: 174))
    arrow.lineWidth = 3.2
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    ink.setStroke()
    arrow.stroke()

    let caption = NSMutableAttributedString(string: "Drag nxpaper", attributes: [
        .font: font("BricolageGrotesque12pt-Bold.ttf", 15), .foregroundColor: color(0x1C1A17), .kern: -0.15,
    ])
    caption.append(NSAttributedString(string: " to Applications", attributes: [
        .font: font("BricolageGrotesque12pt-Medium.ttf", 15), .foregroundColor: color(0x7A746C), .kern: -0.15,
    ]))
    let textSize = caption.size()
    caption.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: size.height - 34 - textSize.height))
}

for scale in [1, 2] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    cg.translateBy(x: 0, y: size.height)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    draw(in: cg)
    NSGraphicsContext.current = nil
    let name = scale == 1 ? "background.png" : "background@2x.png"
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
}
