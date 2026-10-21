import CoreGraphics
import CoreImage

/// Dust and the odd hair on the negative, as a lab scan picks them up: each blocks light, so it prints as a
/// small, soft white mark. Seeded, so a frame always gets the same specks. Kept faint and few.
enum Dust {
    /// - Parameter scale: the print's long edge over 1000, so marks keep their size at any resolution.
    static func apply(to image: CIImage, seed: UInt64, scale: CGFloat) -> CIImage {
        let e = image.extent
        var rng = SeededRandom(seed: seed ^ 0xD057_D057_0000_0001)
        var marks = CIImage.empty()

        // Specks: a handful, a pixel or two across at a 1000 px edge.
        for _ in 0..<(3 + Int(rng.next() % 8)) {
            let center = CIVector(x: e.minX + CGFloat(rng.unit()) * e.width, y: e.minY + CGFloat(rng.unit()) * e.height)
            let radius = (0.3 + 0.9 * CGFloat(rng.unit() * rng.unit())) * scale
            let level = 0.35 + 0.5 * rng.unit()
            let speck = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": center,
                "inputRadius0": radius * 0.35,
                "inputRadius1": radius,
                "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: level),
                "inputColor1": CIColor(red: 1, green: 1, blue: 1, alpha: 0),
            ])!.outputImage!.cropped(to: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
            marks = speck.composited(over: marks)
        }

        // Hairs: about one frame in three gets one, very faint.
        let hairs = rng.unit() < 0.35 ? 1 + (rng.unit() < 0.2 ? 1 : 0) : 0
        for _ in 0..<hairs {
            if let hair = hair(rng: &rng, scale: scale, extent: e) { marks = hair.composited(over: marks) }
        }

        // Dust is a little out of focus in the scanner.
        let soft = marks.applyingGaussianBlur(sigma: 0.25 * scale).cropped(to: e)
        return soft.composited(over: image).cropped(to: e)
    }

    /// A thin, loosely curling hair drawn into its own small patch at full resolution.
    private static func hair(rng: inout SeededRandom, scale: CGFloat, extent e: CGRect) -> CIImage? {
        let side = Int(70 * scale)
        guard side > 8, let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let s = CGFloat(side)
        func point() -> CGPoint { CGPoint(x: s * (0.1 + 0.8 * CGFloat(rng.unit())), y: s * (0.1 + 0.8 * CGFloat(rng.unit()))) }
        let start = point(), end = point()
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18 + 0.14 * rng.unit()))
        ctx.setLineWidth(max(1, 0.2 * scale))
        ctx.setLineCap(.round)
        ctx.move(to: start)
        ctx.addCurve(to: end, control1: point(), control2: point())
        // Sometimes it curls back on itself.
        if rng.unit() < 0.5 { ctx.addCurve(to: point(), control1: point(), control2: point()) }
        ctx.strokePath()
        guard let cg = ctx.makeImage() else { return nil }
        let x = e.minX + CGFloat(rng.unit()) * (e.width - s), y = e.minY + CGFloat(rng.unit()) * (e.height - s)
        return CIImage(cgImage: cg).transformed(by: CGAffineTransform(translationX: x, y: y))
    }
}
