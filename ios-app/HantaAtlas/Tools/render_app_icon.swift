// render_app_icon.swift
//
// One-shot CoreGraphics generator for the HantaAtlas app icon. Produces a
// flat 1024×1024 PNG that drops into Assets.xcassets/AppIcon.appiconset/.
// Apple's iOS 26 Liquid Glass system handles masking, rounded corners,
// shadow, highlight, and the dark/clear/tinted variants automatically as
// long as the source is flat artwork with no built-in chrome.
//
// Run:
//   swift ios-app/HantaAtlas/Tools/render_app_icon.swift \
//        ios-app/HantaAtlas/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// Design: a single terracotta pulse — solid centre dot + one bold ring —
// over a warm bone field, with a near-invisible equator hairline behind
// it. Reads as "signal at a point on the world." No stars, no sparkles,
// no medical clichés. Geometric, scales cleanly to 60×60 in App Library.

import AppKit
import CoreGraphics
import Foundation

let size: CGFloat = 1024.0

// Theme palette (mirrors Theme.swift exactly)
let bone       = NSColor(srgbRed: 0.945, green: 0.918, blue: 0.866, alpha: 1.0)
let paper      = NSColor(srgbRed: 0.988, green: 0.972, blue: 0.940, alpha: 1.0)
let oat        = NSColor(srgbRed: 0.918, green: 0.886, blue: 0.824, alpha: 1.0)
let terracotta = NSColor(srgbRed: 0.760, green: 0.380, blue: 0.270, alpha: 1.0)
let graphite   = NSColor(srgbRed: 0.140, green: 0.130, blue: 0.115, alpha: 1.0)

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: render_app_icon.swift <output.png>\n", stderr)
    exit(64)
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

// Bitmap canvas
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 32
) else {
    fputs("failed to allocate bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// 1. Background — bone fill, then a soft top-left → bottom-right paper-grain
ctx.setFillColor(bone.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let cs = CGColorSpaceCreateDeviceRGB()
let gradColors: [CGColor] = [
    paper.cgColor,
    bone.cgColor,
    oat.cgColor
]
let gradLocs: [CGFloat] = [0.0, 0.55, 1.0]
if let grad = CGGradient(colorsSpace: cs, colors: gradColors as CFArray, locations: gradLocs) {
    ctx.drawLinearGradient(
        grad,
        start: CGPoint(x: size * 0.10, y: size * 0.90),
        end:   CGPoint(x: size * 0.92, y: size * 0.08),
        options: []
    )
}

// 2. Equator hairline — extremely subtle, anchors the centre as "on a map"
ctx.setStrokeColor(graphite.withAlphaComponent(0.07).cgColor)
ctx.setLineWidth(2.0)
ctx.move(to:    CGPoint(x: size * 0.08, y: size * 0.50))
ctx.addLine(to: CGPoint(x: size * 0.92, y: size * 0.50))
ctx.strokePath()

// 3. Outer pulse ring — terracotta, 30% opacity (the wave)
let centre = CGPoint(x: size / 2.0, y: size / 2.0)
ctx.setStrokeColor(terracotta.withAlphaComponent(0.32).cgColor)
ctx.setLineWidth(14.0)
let outerR = size * 0.345
ctx.strokeEllipse(in: CGRect(
    x: centre.x - outerR, y: centre.y - outerR,
    width: outerR * 2,    height: outerR * 2
))

// 4. Mid pulse ring — terracotta, 100% opacity (the signal)
ctx.setStrokeColor(terracotta.cgColor)
ctx.setLineWidth(20.0)
let midR = size * 0.225
ctx.strokeEllipse(in: CGRect(
    x: centre.x - midR, y: centre.y - midR,
    width: midR * 2,    height: midR * 2
))

// 5. Centre dot — solid terracotta (the point)
ctx.setFillColor(terracotta.cgColor)
let dotR = size * 0.115
ctx.fillEllipse(in: CGRect(
    x: centre.x - dotR, y: centre.y - dotR,
    width: dotR * 2,    height: dotR * 2
))

NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode PNG\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
print("wrote \(outputURL.path) (\(pngData.count) bytes, \(Int(size))x\(Int(size)))")
