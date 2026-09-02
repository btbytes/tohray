#!/usr/bin/env swift

// Draws the Tohray app icon: a sun rising from behind a hill, with a bright
// rivulet running down toward the viewer.
//
// Usage: swift Scripts/generate-icon.swift <output-iconset-directory>
// Then:  iconutil -c icns <output-iconset-directory> -o Resources/AppIcon.icns

import AppKit

// All drawing happens in a 1024x1024 design space and is scaled per output size.
let canvas: CGFloat = 1024
let inset: CGFloat = 100
let shapeRect = CGRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
let cornerRadius: CGFloat = 185
let horizon = shapeRect.minY + shapeRect.height * 0.44

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawSky() {
    let gradient = NSGradient(
        colors: [
            color(0xFFF3C4),
            color(0xFFC65C),
            color(0x7FD7FF),
            color(0x1E8FE0)
        ],
        atLocations: [0.0, 0.34, 0.62, 1.0],
        colorSpace: .sRGB
    )
    gradient?.draw(in: shapeRect, angle: 90)
}

func drawSun() {
    let center = CGPoint(x: shapeRect.midX, y: horizon + 40)

    let glow = NSGradient(
        colors: [color(0xFFE9A8, alpha: 0.85), color(0xFFD166, alpha: 0.0)],
        atLocations: [0.0, 1.0],
        colorSpace: .sRGB
    )
    glow?.draw(
        in: NSBezierPath(ovalIn: CGRect(x: center.x - 330, y: center.y - 330, width: 660, height: 660)),
        relativeCenterPosition: .zero
    )

    for index in 0..<12 {
        let angle = CGFloat(index) * .pi / 6 + .pi / 12
        let ray = NSBezierPath()
        ray.move(to: center)
        ray.line(to: CGPoint(x: center.x + cos(angle - 0.045) * 400, y: center.y + sin(angle - 0.045) * 400))
        ray.line(to: CGPoint(x: center.x + cos(angle + 0.045) * 400, y: center.y + sin(angle + 0.045) * 400))
        ray.close()
        color(0xFFF6D8, alpha: 0.32).setFill()
        ray.fill()
    }

    let disc = NSBezierPath(ovalIn: CGRect(x: center.x - 152, y: center.y - 152, width: 304, height: 304))
    let discGradient = NSGradient(
        colors: [color(0xFFB443), color(0xFFDE73), color(0xFFFBEA)],
        atLocations: [0.0, 0.55, 1.0],
        colorSpace: .sRGB
    )
    discGradient?.draw(in: disc, relativeCenterPosition: NSPoint(x: 0, y: 0.15))
}

/// A hill silhouette: a smooth crest spanning the full width, filled downward.
func hillPath(crest: CGPoint, leftEdgeY: CGFloat, rightEdgeY: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: shapeRect.minX - 20, y: shapeRect.minY - 20))
    path.line(to: CGPoint(x: shapeRect.minX - 20, y: leftEdgeY))
    path.curve(
        to: crest,
        controlPoint1: CGPoint(x: shapeRect.minX + shapeRect.width * 0.16, y: leftEdgeY + 30),
        controlPoint2: CGPoint(x: crest.x - shapeRect.width * 0.24, y: crest.y)
    )
    path.curve(
        to: CGPoint(x: shapeRect.maxX + 20, y: rightEdgeY),
        controlPoint1: CGPoint(x: crest.x + shapeRect.width * 0.26, y: crest.y),
        controlPoint2: CGPoint(x: shapeRect.maxX - shapeRect.width * 0.1, y: rightEdgeY + 20)
    )
    path.line(to: CGPoint(x: shapeRect.maxX + 20, y: shapeRect.minY - 20))
    path.close()
    return path
}

func drawHills() {
    let backHill = hillPath(
        crest: CGPoint(x: shapeRect.minX + shapeRect.width * 0.30, y: horizon + 96),
        leftEdgeY: horizon + 26,
        rightEdgeY: horizon + 4
    )
    NSGradient(colors: [color(0x2FA36B), color(0x53C48A)], atLocations: [0.0, 1.0], colorSpace: .sRGB)?
        .draw(in: backHill, angle: 90)

    let frontHill = hillPath(
        crest: CGPoint(x: shapeRect.minX + shapeRect.width * 0.74, y: horizon + 34),
        leftEdgeY: horizon - 40,
        rightEdgeY: horizon - 10
    )
    NSGradient(colors: [color(0x146B4A), color(0x21895D)], atLocations: [0.0, 1.0], colorSpace: .sRGB)?
        .draw(in: frontHill, angle: 90)
}

/// The rivulet: a winding ribbon that starts narrow at the hill gap and widens
/// as it reaches the bottom edge.
func rivuletPath(widthScale: CGFloat = 1) -> NSBezierPath {
    let top = horizon - 6
    let bottom = shapeRect.minY - 20
    let samples = 60

    func centerX(_ t: CGFloat) -> CGFloat {
        shapeRect.midX - 4 + sin(t * 2.7 + 0.35) * 74 * t
    }
    func halfWidth(_ t: CGFloat) -> CGFloat {
        (14 + pow(t, 1.35) * 168) * widthScale
    }

    var leftEdge: [CGPoint] = []
    var rightEdge: [CGPoint] = []
    for index in 0...samples {
        let t = CGFloat(index) / CGFloat(samples)
        let y = top + (bottom - top) * t
        let x = centerX(t)
        let half = halfWidth(t)
        leftEdge.append(CGPoint(x: x - half, y: y))
        rightEdge.append(CGPoint(x: x + half, y: y))
    }

    let path = NSBezierPath()
    path.move(to: leftEdge[0])
    for point in leftEdge.dropFirst() { path.line(to: point) }
    for point in rightEdge.reversed() { path.line(to: point) }
    path.close()
    return path
}

func drawRivulet() {
    // A darker bank keeps the water legible against the hill.
    color(0x0C5238).setFill()
    rivuletPath(widthScale: 1.1).fill()

    let path = rivuletPath()
    NSGradient(
        colors: [color(0x179FD8), color(0x5CCDF5), color(0xB8E9FF), color(0xFFE7AE)],
        atLocations: [0.0, 0.46, 0.80, 1.0],
        colorSpace: .sRGB
    )?.draw(in: path, angle: 90)

    // Sun reflection running down the middle of the water.
    let highlight = rivuletPath(widthScale: 0.24)
    NSGradient(
        colors: [color(0xFFFFFF, alpha: 0.22), color(0xFFFFFF, alpha: 0.72)],
        atLocations: [0.0, 1.0],
        colorSpace: .sRGB
    )?.draw(in: highlight, angle: 90)
}

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let pixels = Int(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap of size \(size)")
    }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create drawing context")
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.scaleBy(x: size / canvas, y: size / canvas)

    let shape = NSBezierPath(roundedRect: shapeRect, xRadius: cornerRadius, yRadius: cornerRadius)
    shape.addClip()

    drawSky()
    drawSun()
    drawHills()
    drawRivulet()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("usage: swift Scripts/generate-icon.swift <output-iconset-directory>")
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1])
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let variants: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

for variant in variants {
    let rep = drawIcon(size: variant.size)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(variant.name)")
    }
    let url = outputDirectory.appendingPathComponent("\(variant.name).png")
    try data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(Int(variant.size))px)")
}
