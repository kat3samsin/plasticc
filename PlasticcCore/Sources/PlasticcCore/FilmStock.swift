/// A film you can load into the camera, and how it develops through the Snappy 35's plastic lens.
/// Values come from published reviews of each stock and of single-use camera scans (see docs/film-looks.md).
public struct FilmStock: Identifiable, Equatable, Sendable {
    /// Grain as a minilab scan shows it. See docs/film-looks.md for where the numbers come from.
    public struct Grain: Equatable, Sendable {
        /// Strength in midtones, as RMS deviation in 8-bit sRGB levels on a 3088 px scan. Highlights get less.
        public var rms: Double
        /// Clump size in pixels at a 1000 px long edge; scales with resolution.
        public var size: Double
        /// Share of independent colour noise in each channel. Zero for black and white.
        public var chroma: Double
        /// Extra strength per stop underexposed, up to two stops.
        public var underexposure: Double
    }

    public let id: String
    public let name: String
    public let look: LookSpec
    public let grain: Grain
    /// Red-orange bloom around highlights, 0–1. Mostly the plastic lens; none on black and white.
    public let halation: Double
    /// Screen-blended light leak colours; neutral grey fog for black and white.
    public let leakTones: [SIMD3<Double>]
    /// Chance a frame past the first two gets a leak.
    public let leakChance: Double
    /// Corner darkening from the f/10 plastic lens, 0–1.
    public let vignette: Double
    /// Overall softness, as a blur sigma in pixels at a 1000 px long edge. Corners get more.
    public let softness: Double

    public static let superia400 = FilmStock(
        id: "superia400", name: "Fujifilm Superia X-TRA 400",
        look: {
            var l = LookSpec()
            l.channelGain = SIMD3(0.98, 1.01, 1.0)
            // Datasheet layer gammas are about 0.59 / 0.59 / 0.77: a contrastier blue layer.
            l.contrast = SIMD3(1.06, 1.06, 1.14)
            l.curveOffset = SIMD3(0, 0.04, -0.03)
            l.saturation = 1.06
            l.saturationRolloff = 0.22
            l.hueSectors = [
                // Fuji greens: leaning teal and a bit richer.
                .init(center: 145, width: 90, hueShift: 9, chroma: 0.02),
                // Skin a touch pinker than Kodak.
                .init(center: 55, width: 50, hueShift: -3),
                // Bright, clean blues.
                .init(center: 255, width: 70, chroma: -0.06),
            ]
            l.highlightRolloff = 0.08
            l.fade = 0.03
            l.shadowTint = SIMD3(-0.015, 0.02, 0.02)
            l.highlightTint = SIMD3(0.015, -0.005, 0.015)
            return l
        }(),
        // Weak antihalation layer: more glow than Portra.
        grain: Grain(rms: 2.0, size: 0.9, chroma: 0.15, underexposure: 0.15), halation: 0.15,
        leakTones: [SIMD3(1.0, 0.45, 0.2), SIMD3(1.0, 0.3, 0.5)], leakChance: 0.12,
        vignette: 0.45, softness: 0.55
    )

    public static let portra800 = FilmStock(
        id: "portra800", name: "Kodak Portra 800",
        look: {
            var l = LookSpec()
            l.channelGain = SIMD3(1.06, 1.0, 0.9)
            // Layer gammas about 0.52 / 0.49 / 0.53: low, nearly balanced contrast.
            l.contrast = SIMD3(0.92, 0.9, 0.92)
            l.curveOffset = SIMD3(0.05, 0, -0.05)
            l.saturation = 1.0
            l.saturationRolloff = 0.2
            l.hueSectors = [
                // Reds and skin toward orange, gently.
                .init(center: 45, width: 60, hueShift: 2, chroma: -0.08),
                // Muted greens and blues.
                .init(center: 145, width: 80, chroma: -0.08),
                .init(center: 262, width: 70, chroma: 0.05),
            ]
            l.highlightRolloff = 0.14
            l.fade = 0.04
            l.shadowTint = SIMD3(0.005, 0.005, 0.015)
            l.highlightTint = SIMD3(0.035, 0.02, -0.005)
            return l
        }(),
        // Strong antihalation layer: a softer glow than Superia.
        grain: Grain(rms: 2.2, size: 0.8, chroma: 0.12, underexposure: 0.10), halation: 0.08,
        leakTones: [SIMD3(1.0, 0.55, 0.25), SIMD3(1.0, 0.75, 0.4)], leakChance: 0.12,
        vignette: 0.4, softness: 0.5
    )

    public static let hp5 = FilmStock(
        id: "hp5", name: "Ilford HP5 Plus 400",
        look: {
            var l = LookSpec()
            // Panchromatic, a little dark in the reds and light in the blues.
            l.monoWeights = SIMD3(0.21, 0.60, 0.19)
            l.contrast = SIMD3(repeating: 1.1)
            // Holds highlights better than shadows: a long shoulder.
            l.shoulderRecovery = 0.5
            l.highlightRolloff = 0.06
            l.fade = 0.025
            return l
        }(),
        grain: Grain(rms: 2.8, size: 1.0, chroma: 0, underexposure: 0.12), halation: 0,
        leakTones: [SIMD3(0.8, 0.8, 0.8)], leakChance: 0.12,
        vignette: 0.5, softness: 0.6
    )

    public static let all = [superia400, portra800, hp5]

    public static func with(id: String) -> FilmStock? {
        all.first { $0.id == id }
    }

    public static func == (a: FilmStock, b: FilmStock) -> Bool { a.id == b.id }
}
