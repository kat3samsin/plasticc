// Draws the app icon: a chunky single-use camera on a clean white ground.
// Usage: swift tools/make_icon.swift App/Assets.xcassets/AppIcon.appiconset/icon.png [dark|tinted]
// "dark" and "tinted" draw the camera on a transparent ground, so iOS can lay it on its own dark, tinted or clear
// backgrounds; "tinted" is in greys, which iOS colours itself.
import CoreGraphics
import Foundation
import ImageIO

let size: CGFloat = 1024
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let variant = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "default"
let transparent = variant != "default"
// The main icon must be opaque; all are exactly 1024 px.
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: transparent ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
func rounded(_ rect: CGRect, _ r: CGFloat) -> CGPath { CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil) }

// Ground: plain white, like Slack's or Gmail's; none for the dark and tinted variants.
if !transparent {
    ctx.setFillColor(color(1, 1, 1))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
}

// Camera body, tilted a touch.
ctx.saveGState()
ctx.translateBy(x: 512, y: 500)
ctx.rotate(by: -0.08)
let body = CGRect(x: -380, y: -250, width: 760, height: 500)
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: color(0, 0, 0, 0.18))
ctx.addPath(rounded(body, 90)); ctx.setFillColor(color(0.99, 0.74, 0.04)); ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Red band along the bottom, clipped to the body.
ctx.saveGState()
ctx.addPath(rounded(body, 90)); ctx.clip()
ctx.setFillColor(color(0.84, 0.13, 0.10)); ctx.fill(CGRect(x: -380, y: -190, width: 760, height: 92))
// Sheen.
let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(1, 1, 1, 0.35), color(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: -380, y: 250), end: CGPoint(x: 0, y: -50), options: [])
ctx.restoreGState()

// Flash window.
ctx.addPath(rounded(CGRect(x: -320, y: 110, width: 230, height: 100), 22)); ctx.setFillColor(color(0.08, 0.08, 0.09)); ctx.fillPath()
let reflector = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0.98, 0.98, 0.98), color(0.72, 0.72, 0.74)] as CFArray, locations: [0, 1])!
ctx.saveGState(); ctx.addPath(rounded(CGRect(x: -306, y: 124, width: 202, height: 72), 14)); ctx.clip()
ctx.drawLinearGradient(reflector, start: CGPoint(x: 0, y: 196), end: CGPoint(x: 0, y: 124), options: [])
ctx.setFillColor(color(0, 0, 0, 0.12)); for i in 0..<9 { ctx.fill(CGRect(x: -296 + CGFloat(i) * 22, y: 124, width: 6, height: 72)) }
ctx.restoreGState()

// Finder window.
ctx.addPath(rounded(CGRect(x: 200, y: 130, width: 120, height: 80), 18)); ctx.setFillColor(color(0.08, 0.08, 0.09)); ctx.fillPath()
ctx.addPath(rounded(CGRect(x: 212, y: 142, width: 96, height: 56), 10)); ctx.setFillColor(color(0.2, 0.26, 0.32)); ctx.fillPath()

// Lens.
let lensCenter = CGPoint(x: 0, y: 10)
ctx.setFillColor(color(0.07, 0.07, 0.08)); ctx.fillEllipse(in: CGRect(x: lensCenter.x - 185, y: lensCenter.y - 185, width: 370, height: 370))
let barrel = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0.36, 0.36, 0.38), color(0.1, 0.1, 0.11)] as CFArray, locations: [0, 1])!
ctx.saveGState(); ctx.addEllipse(in: CGRect(x: -150, y: -140, width: 300, height: 300)); ctx.clip()
ctx.drawRadialGradient(barrel, startCenter: CGPoint(x: -40, y: 60), startRadius: 10, endCenter: lensCenter, endRadius: 170, options: [])
ctx.restoreGState()
let glass = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0.2, 0.25, 0.5), color(0.02, 0.02, 0.05)] as CFArray, locations: [0, 1])!
ctx.saveGState(); ctx.addEllipse(in: CGRect(x: -88, y: -78, width: 176, height: 176)); ctx.clip()
ctx.drawRadialGradient(glass, startCenter: CGPoint(x: -20, y: 30), startRadius: 4, endCenter: lensCenter, endRadius: 100, options: [])
ctx.restoreGState()
ctx.setStrokeColor(color(0.65, 0.35, 0.95, 0.55)); ctx.setLineWidth(12)
ctx.addArc(center: lensCenter, radius: 62, startAngle: -0.6, endAngle: 0.3, clockwise: false); ctx.strokePath()
ctx.setFillColor(color(1, 1, 1, 0.9)); ctx.fillEllipse(in: CGRect(x: -48, y: 34, width: 30, height: 30))

ctx.restoreGState()

var image = ctx.makeImage()!
// Tinted: the same drawing in greys, keeping its transparency.
if variant == "tinted" {
    let grey = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    if let grey {
        grey.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        image = grey.makeImage()!
    }
}
let dest = CGImageDestinationCreateWithURL(out as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out.path)")
