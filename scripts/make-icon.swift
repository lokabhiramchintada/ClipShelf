// Draws the ClipShelf app icon: a clipboard in front of a fanned stack of earlier clips,
// with a pin ribbon. Writes a 1024 px PNG to the path given as the first argument.
// Run via scripts/make-icon.sh, which also builds the .icns.
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "icon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func linearGradient(_ ctx: CGContext, _ path: CGPath, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [])
    ctx.restoreGState()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
// Work top-down (y grows downwards) like most design tools.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// Background squircle on Apple's icon grid (824 pt body inside 1024 with room for the shadow).
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = roundedRect(body, 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(bodyPath)
ctx.setFillColor(color(0x4338CA))
ctx.fillPath()
ctx.restoreGState()
linearGradient(ctx, bodyPath, [color(0x6D6AFB), color(0x4F46E5), color(0x312E81)],
               from: CGPoint(x: 200, y: 100), to: CGPoint(x: 824, y: 924))
// Soft top highlight.
linearGradient(ctx, bodyPath, [color(0xFFFFFF, 0.18), color(0xFFFFFF, 0)],
               from: CGPoint(x: 512, y: 100), to: CGPoint(x: 512, y: 520))

// Earlier clips fanned out behind the clipboard.
func sheet(angle: CGFloat, alpha: CGFloat, dx: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: 512 + dx, y: 585)
    ctx.rotate(by: angle * .pi / 180)
    ctx.addPath(roundedRect(CGRect(x: -225, y: -285, width: 450, height: 570), 48))
    ctx.setFillColor(color(0xFFFFFF, alpha))
    ctx.fillPath()
    ctx.restoreGState()
}
sheet(angle: -13, alpha: 0.28, dx: -18)
sheet(angle: 7, alpha: 0.45, dx: 14)

// The clipboard.
let board = CGRect(x: 277, y: 292, width: 470, height: 572)
let boardPath = roundedRect(board, 56)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 22), blur: 44, color: color(0x1E1B4B, 0.45))
ctx.addPath(boardPath)
ctx.setFillColor(color(0xFFFFFF))
ctx.fillPath()
ctx.restoreGState()
linearGradient(ctx, boardPath, [color(0xFFFFFF), color(0xEEF0FF)],
               from: CGPoint(x: 512, y: board.minY), to: CGPoint(x: 512, y: board.maxY))

// Text lines; the highlighted one is the "selected" clip.
let lines: [(y: CGFloat, width: CGFloat, highlighted: Bool)] = [
    (420, 250, false), (500, 340, true), (580, 300, false), (660, 360, false), (740, 220, false),
]
for line in lines {
    if line.highlighted {
        ctx.addPath(roundedRect(CGRect(x: 312, y: line.y - 24, width: 400, height: 78), 22))
        ctx.setFillColor(color(0x6366F1, 0.16))
        ctx.fillPath()
    }
    ctx.addPath(roundedRect(CGRect(x: 337, y: line.y, width: line.width, height: 30), 15))
    ctx.setFillColor(line.highlighted ? color(0x4F46E5) : color(0xC9CCE6))
    ctx.fillPath()
}

// The clip at the top.
let clip = CGRect(x: 412, y: 240, width: 200, height: 96)
let clipPath = roundedRect(clip, 30)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 8), blur: 14, color: color(0x000000, 0.3))
ctx.addPath(clipPath)
ctx.setFillColor(color(0x1E1B4B))
ctx.fillPath()
ctx.restoreGState()
linearGradient(ctx, clipPath, [color(0x3B3780), color(0x1E1B4B)],
               from: CGPoint(x: 512, y: clip.minY), to: CGPoint(x: 512, y: clip.maxY))
ctx.addPath(roundedRect(CGRect(x: 472, y: 262, width: 80, height: 26), 13))
ctx.setFillColor(color(0x6D6AFB, 0.9))
ctx.fillPath()

// Pin ribbon on the top-right corner: "pinned clips stay".
let ribbon = CGMutablePath()
ribbon.move(to: CGPoint(x: 648, y: 292))
ribbon.addLine(to: CGPoint(x: 712, y: 292))
ribbon.addLine(to: CGPoint(x: 712, y: 410))
ribbon.addLine(to: CGPoint(x: 680, y: 384))
ribbon.addLine(to: CGPoint(x: 648, y: 410))
ribbon.closeSubpath()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: color(0x9F1239, 0.35))
ctx.addPath(ribbon)
ctx.setFillColor(color(0xF43F5E))
ctx.fillPath()
ctx.restoreGState()
linearGradient(ctx, ribbon, [color(0xFB7185), color(0xE11D48)],
               from: CGPoint(x: 680, y: 292), to: CGPoint(x: 680, y: 410))

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
