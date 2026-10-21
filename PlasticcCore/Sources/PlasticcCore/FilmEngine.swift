import CoreImage
import Foundation

/// Develops one frame: a film's colour and grain, seen through a cheap f/10 plastic lens and a single-use flash.
/// Stateless apart from a LUT cache, so the same inputs always give the same print.
public final class FilmEngine: @unchecked Sendable {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    static let cubeSize = 33

    private let lock = NSLock()
    private var cubes: [String: Data] = [:]

    public init() {}

    /// - Parameters:
    ///   - frameIndex: 0 for the first frame on the roll; the first two are fogged more often while loading.
    ///   - date: the date to imprint, or nil for no stamp.
    ///   - exposure: stops away from a good exposure, from `disposableExposure`; negative is dark.
    ///   - white: the decoded linear light to print as white, set per frame (see `Developer.scanWhite`).
    public func develop(_ image: CIImage, film: FilmStock, seed: UInt64, frameIndex: Int, flash: Bool, date: Date?,
                        exposure: Double = 0, white: Double? = nil) -> CIImage {
        let framed = Self.cropToPrint(image)
        let extent = framed.extent
        // Effect sizes are tuned at a 1000 px long edge, so every resolution looks alike.
        let scale = max(extent.width, extent.height) / 1000
        var out = exposure == 0 ? framed : framed.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: exposure])
        out = applyingLUT(out, film: film, white: white)
        // A lab scanner's unsharp mask, before the grain so the grain itself stays soft, and before the lens's
        // edge softness so the centre is crisp and the edges stay soft.
        out = out.applyingFilter("CISharpenLuminance", parameters: [
            kCIInputSharpnessKey: Self.scanSharpening, kCIInputRadiusKey: 0.35 * scale,
        ])
        out = softened(out, sigma: film.softness * scale, extent: extent)
        if film.halation > 0 { out = haloed(out, source: framed, amount: film.halation, extent: extent, scale: scale) }
        if flash { out = flashed(out, extent: extent) }
        // Underexposed negatives print grainier; well-exposed, dense ones in bright light print finer.
        var grain = film.grain
        grain.rms *= 1 + grain.underexposure * min(2, max(0, -exposure))
        grain.rms *= 1 - min(0.35, max(0, exposure))
        out = grained(out, grain, extent: extent, scale: scale, seed: seed)
        if Self.leakFires(film: film, seed: seed, frameIndex: frameIndex) {
            out = applyingLightLeak(to: out, tones: film.leakTones, seed: seed)
        }
        out = vignetted(out, amount: film.vignette, extent: extent)
        out = Dust.apply(to: out, seed: seed, scale: scale)
        if let date { out = DateStamp.apply(to: out, date: date, seed: seed) }
        // Composite over black so alpha is 1 everywhere.
        return out.cropped(to: extent).composited(over: CIImage(color: .black).cropped(to: extent))
    }

    /// Whether this frame gets a light leak. Film near the leader is fogged while loading, so frames 1 and 2 leak more.
    public static func leakFires(film: FilmStock, seed: UInt64, frameIndex: Int) -> Bool {
        var rng = SeededRandom(seed: seed ^ 0xA5A5_5A5A_0F0F_F0F0)
        let chance = switch frameIndex {
        case 0: 0.55
        case 1: 0.3
        default: film.leakChance
        }
        return rng.unit() < chance
    }

    /// A single-use camera's fixed f/10 at 1/100 s on ISO 400 film suits a scene of about EV 11.3 at ISO 100.
    static let fixedEV100 = log2(10.0 * 10.0 / 0.01) - 2

    /// How many stops a scene lands from a good exposure in a fixed-exposure camera, after the minilab's scanner
    /// has rescued what it can. Bright scenes are mostly absorbed by negative film's latitude; dim ones go dark,
    /// unless the flash fired, which reaches about two metres.
    public static func disposableExposure(sceneEV100: Double, flash: Bool) -> Double {
        let delta = sceneEV100 - fixedEV100
        // Bright scenes print at normal: the scanner prints a dense negative down to it.
        let printed = delta >= 0 ? 0 : min(0, delta + 2)
        return max(-2.6, (flash ? max(printed, -0.4) : printed) + printOffset)
    }

    /// Every print sits this many stops under, so frames never look washed out next to the phone's own photos.
    static let printOffset = -0.5

    /// The largest centred 2:3 crop, portrait or landscape to match the frame, moved to the origin.
    public static func cropToPrint(_ image: CIImage) -> CIImage {
        let e = image.extent
        let portrait = e.height >= e.width
        let ratio: CGFloat = portrait ? 2.0 / 3.0 : 3.0 / 2.0
        var rect = e
        if e.width / e.height > ratio {
            rect.size.width = (e.height * ratio).rounded()
            rect.origin.x = e.minX + ((e.width - rect.width) / 2).rounded()
        } else {
            rect.size.height = (e.width / ratio).rounded()
            rect.origin.y = e.minY + ((e.height - rect.height) / 2).rounded()
        }
        return image.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
    }

    // MARK: - Steps

    private func cube(for film: FilmStock, white: Double?) -> Data {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(film.id)-\(white.map { String($0) } ?? "full")"
        if let cached = cubes[key] { return cached }
        let data = film.look.cubeData(size: Self.cubeSize, white: white)
        cubes[key] = data
        return data
    }

    private func applyingLUT(_ image: CIImage, film: FilmStock, white: Double?) -> CIImage {
        image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": Self.cubeSize,
            "inputCubeData": cube(for: film, white: white),
            "inputColorSpace": Self.sRGB,
        ])
    }

    /// How hard the lab's scanner sharpens, as `CISharpenLuminance` sharpness.
    static let scanSharpening = 0.45

    /// The lens: sharp in the middle, a touch softer toward the corners.
    private func softened(_ image: CIImage, sigma: Double, extent: CGRect) -> CIImage {
        guard sigma > 0 else { return image }
        let long = max(extent.width, extent.height)
        let mask = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: extent.midX, y: extent.midY),
            "inputRadius0": long * 0.2,
            "inputRadius1": long * 0.65,
            "inputColor0": CIColor.black,
            "inputColor1": CIColor.white,
        ])!.outputImage!
        return image.clampedToExtent()
            .applyingFilter("CIMaskedVariableBlur", parameters: ["inputMask": mask, kCIInputRadiusKey: sigma * 2])
            .cropped(to: extent)
    }

    private func haloed(_ image: CIImage, source: CIImage, amount: Double, extent: CGRect, scale: CGFloat) -> CIImage {
        let a = CGFloat(amount)
        // Luminance above 0.75 (linear) in the ungraded source becomes a 0–1 mask in every channel.
        let lumaTimes4 = CIVector(x: 0.2126 * 4, y: 0.7152 * 4, z: 0.0722 * 4, w: 0)
        let highlights = source
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": lumaTimes4, "inputGVector": lumaTimes4, "inputBVector": lumaTimes4,
                "inputBiasVector": CIVector(x: -3, y: -3, z: -3, w: 0),
            ])
            .applyingFilter("CIColorClamp")
        let tinted = highlights.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: a, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0.35 * a, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0.1 * a, y: 0, z: 0, w: 0),
        ])
        let glow = tinted.clampedToExtent().applyingGaussianBlur(sigma: 14 * scale).cropped(to: extent)
        return glow.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: image])
    }

    /// A weak fixed flash: the subject lit, a cool cast, the background falling away to dark.
    private func flashed(_ image: CIImage, extent: CGRect) -> CIImage {
        let radius = min(extent.width, extent.height) * 0.7
        let center = CIVector(x: extent.midX, y: extent.midY + extent.height * 0.04)
        let hotspot = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": center, "inputRadius0": 0, "inputRadius1": radius,
            "inputColor0": CIColor(red: 0.3, green: 0.3, blue: 0.33),
            "inputColor1": CIColor.black,
        ])!.outputImage!.cropped(to: extent)
        return hotspot
            .applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: image])
            .applyingFilter("CIVignetteEffect", parameters: [
                kCIInputCenterKey: center, kCIInputRadiusKey: radius,
                kCIInputIntensityKey: 1.0, "inputFalloff": 0.45,
            ])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.95, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1.05, w: 0),
            ])
    }

    /// Film grain as two layers of clumps, as silver and dye clouds form: fine crisp grains over coarser, fainter
    /// clusters, so it never reads as one even, blurred noise. Mostly luminance, with each colour layer adding
    /// a little of its own on colour film. Strongest in shadows and midtones, fading out of the highlights, as a
    /// Frontier scan shows it.
    private func grained(_ image: CIImage, _ grain: FilmStock.Grain, extent: CGRect, scale: CGFloat, seed: UInt64) -> CIImage {
        guard grain.rms > 0 else { return image }
        let size = grain.size * Double(scale)
        // Each layer is scaled to unit spread, so the two add up to exactly `grain.rms`.
        let fine = grainLayer(seed: seed, sigma: max(0.7, 0.32 * size), weight: 0.92, chroma: grain.chroma,
                              alpha: 1, extent: extent)
        // Alpha 0, so adding it to the fine layer doesn't double the alpha and halve the result.
        let coarse = grainLayer(seed: seed &* 0x9E37_79B9_7F4A_7C15, sigma: max(1.4, 1.1 * size), weight: 0.4,
                                chroma: grain.chroma, alpha: 0, extent: extent)
        // Soft light against mid-grey moves a midtone by about 0.45 × (blend − 0.5).
        let k = CGFloat(grain.rms / (255 * 0.45))
        let noise = fine
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: coarse])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: k, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0.5, y: 0.5, z: 0.5, w: 1),
            ])
            .applyingFilter("CIColorClamp")
            .cropped(to: extent)
        // Soft light against mid-grey noise: 0.5 leaves a pixel unchanged.
        let grained = noise.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: image])
        // Where the grain shows: full in the shadows and midtones, faint in the highlights.
        let mask = image
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: 0.7),
                "inputPoint1": CIVector(x: 0.25, y: 1),
                "inputPoint2": CIVector(x: 0.5, y: 0.9),
                "inputPoint3": CIVector(x: 0.75, y: 0.45),
                "inputPoint4": CIVector(x: 1, y: 0.15),
            ])
        return grained.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: mask,
        ]).cropped(to: extent)
    }

    /// One layer of grain centred on zero, with spread `weight`: the green channel's noise is shared by all three
    /// channels, and red and blue mix in `chroma` of their own.
    private func grainLayer(seed: UInt64, sigma: Double, weight: Double, chroma: Double, alpha: CGFloat,
                            extent: CGRect) -> CIImage {
        // Uniform noise (σ 0.289) blurred by a Gaussian of σ px keeps about 0.289 / (3.545 σ) of its spread.
        let w = CGFloat(weight / (0.289 / (3.545 * sigma)))
        let c = CGFloat(chroma)
        // Composite over black first so alpha is 1 and CIColorMatrix's unpremultiply is a no-op.
        return CIFilter(name: "CIRandomGenerator")!.outputImage!
            .composited(over: CIImage(color: .black))
            .transformed(by: CGAffineTransform(translationX: -CGFloat(seed % 8192), y: -CGFloat((seed >> 13) % 8192)))
            .cropped(to: extent.insetBy(dx: -40, dy: -40))
            .applyingGaussianBlur(sigma: sigma)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: w * c, y: w * (1 - c), z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: w, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: w * (1 - c), z: w * c, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: -w / 2, y: -w / 2, z: -w / 2, w: alpha),
            ])
            .cropped(to: extent)
    }

    private func applyingLightLeak(to image: CIImage, tones: [SIMD3<Double>], seed: UInt64) -> CIImage {
        var rng = SeededRandom(seed: seed ^ 0x1EAF_1EAF_C0DE_F11E)
        let e = image.extent
        let along = CGFloat(rng.unit())
        let center: CGPoint
        switch rng.next() % 4 {
        case 0: center = CGPoint(x: e.minX, y: e.minY + along * e.height)
        case 1: center = CGPoint(x: e.maxX, y: e.minY + along * e.height)
        case 2: center = CGPoint(x: e.minX + along * e.width, y: e.maxY)
        default: center = CGPoint(x: e.minX + along * e.width, y: e.minY)
        }
        let tone = tones[Int(rng.next() % UInt64(tones.count))]
        let strength = 0.35 + 0.3 * rng.unit()
        let radius = max(e.width, e.height) * CGFloat(0.35 + 0.3 * rng.unit())
        let leak = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: center.x, y: center.y),
            "inputRadius0": 0,
            "inputRadius1": radius,
            "inputColor0": CIColor(red: tone.x * strength, green: tone.y * strength, blue: tone.z * strength),
            "inputColor1": CIColor.black,
        ])!.outputImage!.cropped(to: e)
        return leak.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: image])
    }

    private func vignetted(_ image: CIImage, amount: Double, extent: CGRect) -> CIImage {
        guard amount > 0 else { return image }
        return image.applyingFilter("CIVignetteEffect", parameters: [
            kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            kCIInputRadiusKey: max(extent.width, extent.height) * 0.7,
            kCIInputIntensityKey: amount,
            "inputFalloff": 0.6,
        ])
    }
}
