import CoreImage
import Foundation

/// A camera date-back imprint: slanted 7-segment digits exposed onto the film as light, with a soft halo.
/// Screen-blended, so it shows on dark areas and fades on bright ones.
public enum DateStamp {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        // The classic single-use date back: month, day, then year with an apostrophe.
        f.dateFormat = "MM dd ''yy"
        return f
    }()

    /// Lit segments per digit: a top, b upper right, c lower right, d bottom, e lower left, f upper left, g middle.
    private static let segments: [Character: String] = [
        "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
        "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
    ]

    public static func apply(to image: CIImage, date: Date, seed: UInt64) -> CIImage {
        let e = image.extent
        let short = min(e.width, e.height)
        let h = short * 0.027            // digit height
        let w = h * 0.55                 // digit width
        let t = h * 0.12                 // segment thickness
        let advance = w + h * 0.3        // digit pitch
        var rng = SeededRandom(seed: seed ^ 0x5EED_DA7E)

        var digits = CIImage.empty()
        var x: CGFloat = 0
        for ch in formatter.string(from: date) {
            // Per-digit brightness varies ±10%; the core is about half of v2's intensity.
            let level = CGFloat(0.72 * (0.9 + 0.2 * rng.unit()))
            // The date back's red-orange LEDs, as they print.
            let color = CIColor(red: 1.0 * level, green: 0.42 * level, blue: 0.26 * level, alpha: 1, colorSpace: sRGB)!
            if ch == "'" {
                digits = segment(CGRect(x: x, y: h * 0.7, width: t, height: h * 0.3), color: color).composited(over: digits)
                x += t + h * 0.25
            } else if ch == " " {
                x += h * 0.45
            } else if let lit = segments[ch] {
                for s in lit { digits = segment(rect(s, x: x, w: w, h: h, t: t), color: color).composited(over: digits) }
                x += advance
            }
        }

        // 10° italic slant, like an LCD date back.
        let slanted = digits.transformed(by: CGAffineTransform(a: 1, b: 0, c: tan(10 * .pi / 180), d: 1, tx: 0, ty: 0))
        // Pad with transparent margin before clamping, or edge-touching segments smear into streaks.
        let padded = slanted.composited(over: CIImage(color: .clear).cropped(to: slanted.extent.insetBy(dx: -h * 3, dy: -h * 3)))
        let bleed = padded.clampedToExtent().applyingGaussianBlur(sigma: h * 0.025).cropped(to: slanted.extent.insetBy(dx: -h, dy: -h))
        let halo = padded.clampedToExtent().applyingGaussianBlur(sigma: h * 0.22).cropped(to: slanted.extent.insetBy(dx: -h * 2, dy: -h * 2))
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.6, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0.3, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.13, w: 0),
            ])
        let light = bleed.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: halo])

        let jitterX = CGFloat(rng.unit() - 0.5) * 2 * short * 0.003
        let jitterY = CGFloat(rng.unit() - 0.5) * 2 * short * 0.003
        let placed: CIImage
        if e.height > e.width {
            // A portrait frame is the camera turned on its side: the stamp from the film's bottom-right corner
            // runs top to bottom close to the lower-left corner.
            let turned = light.transformed(by: CGAffineTransform(rotationAngle: -.pi / 2))
            let box = turned.extent
            placed = turned.transformed(by: CGAffineTransform(
                translationX: e.minX + e.width * 0.045 - box.minX + jitterX,
                y: e.minY + e.height * 0.06 - box.minY + jitterY))
        } else {
            // Bottom right, inset 5% of the short side.
            let inset = short * 0.05
            placed = light.transformed(by: CGAffineTransform(
                translationX: e.maxX - inset - slanted.extent.maxX + jitterX,
                y: e.minY + inset - slanted.extent.minY + jitterY))
        }
        let lightLayer = placed.composited(over: CIImage(color: .black)).cropped(to: e)
        let screened = lightLayer.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: image])
        // The LEDs burn the red layer of the negative, so even on a bright wall the digits print red-orange
        // rather than vanishing: tint toward the LED colour wherever the digits are lit.
        let tinted = screened.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0.5, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0.34, w: 0),
        ])
        let mask = lightLayer.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 2.6, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 2.6, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 2.6, y: 0, z: 0, w: 0),
        ]).applyingFilter("CIColorClamp")
        return tinted.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: screened, kCIInputMaskImageKey: mask,
        ]).cropped(to: e)
    }

    private static func rect(_ s: Character, x: CGFloat, w: CGFloat, h: CGFloat, t: CGFloat) -> CGRect {
        let gap = t * 0.15
        switch s {
        case "a": return CGRect(x: x + t, y: h - t, width: w - 2 * t, height: t).insetBy(dx: gap, dy: 0)
        case "g": return CGRect(x: x + t, y: (h - t) / 2, width: w - 2 * t, height: t).insetBy(dx: gap, dy: 0)
        case "d": return CGRect(x: x + t, y: 0, width: w - 2 * t, height: t).insetBy(dx: gap, dy: 0)
        case "f": return CGRect(x: x, y: h / 2 + t / 2, width: t, height: h / 2 - t).insetBy(dx: 0, dy: gap)
        case "b": return CGRect(x: x + w - t, y: h / 2 + t / 2, width: t, height: h / 2 - t).insetBy(dx: 0, dy: gap)
        case "e": return CGRect(x: x, y: t / 2, width: t, height: h / 2 - t).insetBy(dx: 0, dy: gap)
        default: return CGRect(x: x + w - t, y: t / 2, width: t, height: h / 2 - t).insetBy(dx: 0, dy: gap) // "c"
        }
    }

    private static func segment(_ r: CGRect, color: CIColor) -> CIImage {
        CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: r),
            "inputRadius": min(r.width, r.height) * 0.4,
            "inputColor": color,
        ])!.outputImage!
    }
}
