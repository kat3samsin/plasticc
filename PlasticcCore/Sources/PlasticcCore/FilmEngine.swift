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
    public func develop(_ image: CIImage, film: FilmStock, seed: UInt64, frameIndex: Int, flash: Bool, date: Date?,
                        exposure: Double = 0) -> CIImage {
        let framed = Self.cropToPrint(image)
        let extent = framed.extent
        // Effect sizes are tuned at a 1000 px long edge, so every resolution looks alike.
        let scale = max(extent.width, extent.height) / 1000
        var out = exposure == 0 ? framed : framed.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: exposure])
        out = applyingLUT(out, film: film)
        out = softened(out, sigma: film.softness * scale, extent: extent)
        if film.halation > 0 { out = haloed(out, source: framed, amount: film.halation, extent: extent, scale: scale) }
        if flash { out = flashed(out, extent: extent) }
        // Underexposed negatives print grainier.
        var grain = film.grain
        grain.rms *= 1 + grain.underexposure * min(2, max(0, -exposure))
        out = grained(out, grain, extent: extent, scale: scale, seed: seed)
        if Self.leakFires(film: film, seed: seed, frameIndex: frameIndex) {
            out = applyingLightLeak(to: out, tones: film.leakTones, seed: seed)
        }
        out = vignetted(out, amount: film.vignette, extent: extent)
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
        let printed = delta >= 0 ? min(0.6, delta * 0.15) : min(0, delta + 2)
        return max(-2.6, flash ? max(printed, -0.4) : printed)
    }

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

    private func cube(for film: FilmStock) -> Data {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cubes[film.id] { return cached }
        let data = film.look.cubeData(size: Self.cubeSize)
        cubes[film.id] = data
        return data
    }

    private func applyingLUT(_ image: CIImage, film: FilmStock) -> CIImage {
        image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": Self.cubeSize,
            "inputCubeData": cube(for: film),
            "inputColorSpace": Self.sRGB,
        ])
    }

    /// A plastic lens: soft all over, softer toward the corners.
    private func softened(_ image: CIImage, sigma: Double, extent: CGRect) -> CIImage {
        guard sigma > 0 else { return image }
        let base = image.clampedToExtent().applyingGaussianBlur(sigma: sigma)
        let long = max(extent.width, extent.height)
        let mask = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(x: extent.midX, y: extent.midY),
            "inputRadius0": long * 0.3,
            "inputRadius1": long * 0.75,
            "inputColor0": CIColor.black,
            "inputColor1": CIColor.white,
        ])!.outputImage!
        return base
            .applyingFilter("CIMaskedVariableBlur", parameters: ["inputMask": mask, kCIInputRadiusKey: sigma * 3.5])
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

    /// Film grain: soft clumps rather than pixel noise, mostly luminance with a little colour on colour film,
    /// strongest in shadows and midtones and fading out of the highlights, as a Frontier scan shows it.
    private func grained(_ image: CIImage, _ grain: FilmStock.Grain, extent: CGRect, scale: CGFloat, seed: UInt64) -> CIImage {
        guard grain.rms > 0 else { return image }
        let sigma = max(0.6, 0.5 * grain.size * Double(scale))
        // Uniform noise (σ 0.289) blurred by a Gaussian of σ px keeps about 0.289 / (3.545 σ) of its spread.
        let noiseSpread = 0.289 / (3.545 * sigma)
        // Soft light against mid-grey moves a midtone by about 0.45 × (blend − 0.5).
        let k = CGFloat(grain.rms / (255 * 0.45 * noiseSpread))
        let c = CGFloat(grain.chroma)
        // Composite over black first so alpha is 1 and CIColorMatrix's unpremultiply is a no-op.
        let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!
            .composited(over: CIImage(color: .black))
            .transformed(by: CGAffineTransform(translationX: -CGFloat(seed % 8192), y: -CGFloat((seed >> 13) % 8192)))
            .cropped(to: extent.insetBy(dx: -20, dy: -20))
            .applyingGaussianBlur(sigma: sigma)
            .applyingFilter("CIColorMatrix", parameters: [
                // One shared luminance grain, with a little of each channel's own noise mixed in.
                "inputRVector": CIVector(x: k * c, y: k * (1 - c), z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: k * (1 - c), z: k * c, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0.5 - k / 2, y: 0.5 - k / 2, z: 0.5 - k / 2, w: 1),
            ])
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
