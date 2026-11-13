import CoreGraphics
import CoreImage

/// Dust and the odd hair, as a lab scan picks them up. Dust on the negative blocks light, so it prints as a soft
/// white mark; dust on the scanner glass or the print prints dark, so marks show on light walls and skies too.
/// Seeded, so a frame always gets the same specks. Most frames also get a hair or two.
enum Dust {
    /// - Parameters:
    ///   - scale: the print's long edge over 1000, so marks keep their size at any resolution.
    ///   - amount: how dusty the scan is; 2 doubles the specks and adds a hair.
    static func apply(to image: CIImage, seed: UInt64, scale: CGFloat, amount: Double = 1) -> CIImage {
        let e = image.extent
        var rng = SeededRandom(seed: seed ^ 0xD057_D057_0000_0001)
        var marks = CIImage.empty()

        // Specks: about a dozen, a pixel or two across at a 1000 px edge; one in three is dark.
        for _ in 0..<Int(Double(6 + Int(rng.next() % 10)) * amount) {
            let center = CIVector(x: e.minX + CGFloat(rng.unit()) * e.width, y: e.minY + CGFloat(rng.unit()) * e.height)
            let radius = (0.3 + 0.9 * CGFloat(rng.unit() * rng.unit())) * scale
            let level = 0.35 + 0.5 * rng.unit()
            let tone: CGFloat = rng.unit() < 0.35 ? 0.12 : 1
            let speck = CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter": center,
                "inputRadius0": radius * 0.35,
                "inputRadius1": radius,
                "inputColor0": CIColor(red: tone, green: tone, blue: tone, alpha: level),
                "inputColor1": CIColor(red: tone, green: tone, blue: tone, alpha: 0),
            ])!.outputImage!.cropped(to: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
            marks = speck.composited(over: marks)
        }

        // Hairs and fibres: most frames get one, some two or three, each short and shaped its own way.
        let hairs = (rng.unit() < 0.85 ? 1 + (rng.unit() < 0.35 ? 1 : 0) + (rng.unit() < 0.12 ? 1 : 0) : 0)
            + (amount > 1 ? 1 : 0)
        for _ in 0..<hairs {
            if let hair = hair(rng: &rng, scale: scale, extent: e) { marks = hair.composited(over: marks) }
        }

        // Dust is a little out of focus in the scanner.
        let soft = marks.applyingGaussianBlur(sigma: 0.25 * scale).cropped(to: e)
        return soft.composited(over: image).cropped(to: e)
    }

    /// A fine hair or fibre drawn into its own small patch at full resolution. It wanders as it goes: the bend
    /// drifts and sometimes flips, so one comes out a nearly straight fibre, another a soft arc, another a tight curl.
    private static func hair(rng: inout SeededRandom, scale: CGFloat, extent e: CGRect) -> CIImage? {
        // Mostly short: 5 to 24 px at a 1000 px edge, the odd one longer.
        let length = (5 + 19 * CGFloat(rng.unit() * rng.unit())) * scale
        let side = Int(length * 1.2) + 4
        guard length > 3, let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let s = CGFloat(side)
        // Light on the negative, or dark on the glass.
        let tone: CGFloat = rng.unit() < 0.4 ? 0.1 : 1
        ctx.setStrokeColor(CGColor(red: tone, green: tone, blue: tone, alpha: 0.2 + 0.18 * rng.unit()))
        ctx.setLineWidth(max(0.8, (0.08 + 0.08 * CGFloat(rng.unit())) * scale))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        // Walk from the centre, so the hair fits its patch whichever way it heads.
        let steps = 24
        let step = length / CGFloat(steps)
        var heading = CGFloat(rng.unit()) * 2 * .pi
        var bend = CGFloat(rng.unit() - 0.5) * (rng.unit() < 0.25 ? 0.55 : 0.25)
        var p = CGPoint(x: s / 2 - cos(heading) * length / 2, y: s / 2 - sin(heading) * length / 2)
        ctx.move(to: p)
        for _ in 0..<steps {
            bend += CGFloat(rng.unit() - 0.5) * 0.12
            if rng.unit() < 0.04 { bend = -bend }
            heading += bend
            p = CGPoint(x: min(s - 1, max(1, p.x + cos(heading) * step)), y: min(s - 1, max(1, p.y + sin(heading) * step)))
            ctx.addLine(to: p)
        }
        ctx.strokePath()
        guard let cg = ctx.makeImage() else { return nil }
        let x = e.minX + CGFloat(rng.unit()) * (e.width - s), y = e.minY + CGFloat(rng.unit()) * (e.height - s)
        return CIImage(cgImage: cg).transformed(by: CGAffineTransform(translationX: x, y: y))
    }
}
