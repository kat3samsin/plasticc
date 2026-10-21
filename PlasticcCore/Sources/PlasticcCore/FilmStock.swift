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
    /// Corner softness of the lens, as a blur sigma in pixels at a 1000 px long edge. The centre stays sharp.
    public let softness: Double

    public static let superia400 = FilmStock(
        id: "superia400", name: "Fujifilm Superia X-TRA 400",
        look: {
            var l = LookSpec()
            l.channelGain = SIMD3(0.98, 1.01, 1.0)
            // Datasheet layer gammas are about 0.59 / 0.59 / 0.77: a contrastier blue layer.
            l.contrast = SIMD3(1.16, 1.16, 1.25)
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
            l.highlightRolloff = 0.05
            l.fade = 0
            l.shadowTint = SIMD3(-0.015, 0.02, 0.02)
            l.highlightTint = SIMD3(0.015, -0.005, 0.015)
            return l
        }(),
        // Weak antihalation layer: more glow than Portra.
        grain: Grain(rms: 2.8, size: 0.85, chroma: 0.12, underexposure: 0.15), halation: 0.15,
        leakTones: [SIMD3(1.0, 0.45, 0.2), SIMD3(1.0, 0.3, 0.5)], leakChance: 0.12,
        vignette: 0.25, softness: 0.15
    )

    public static let portra400 = FilmStock(
        id: "portra400", name: "Kodak Portra 400",
        look: {
            var l = LookSpec()
            l.channelGain = SIMD3(1.05, 1.0, 0.92)
            // Low, nearly balanced contrast, like Portra 800's layer gammas (about 0.52 / 0.49 / 0.53).
            l.contrast = SIMD3(1.1, 1.08, 1.1)
            // Mid-grey a touch under, so sunny frames don't wash out.
            l.curveOffset = SIMD3(-0.05, -0.12, -0.18)
            // Natural but with life in it: scans of real rolls average a little more colour than the phone.
            l.saturation = 1.06
            l.saturationRolloff = 0.2
            l.hueSectors = [
                // Reds and skin toward orange, gently.
                .init(center: 45, width: 60, hueShift: 2, chroma: -0.08),
                // Muted greens and blues.
                .init(center: 145, width: 80, chroma: -0.03),
                .init(center: 262, width: 70, chroma: 0.05),
            ]
            l.highlightRolloff = 0.05
            l.fade = 0
            l.shadowTint = SIMD3(0.005, 0.005, 0.015)
            l.highlightTint = SIMD3(0.035, 0.02, -0.005)
            return l
        }(),
        // Strong antihalation layer: a softer glow than Superia.
        // Print Grain Index 37 against Portra 800's 48: well below the colour films' usual grain.
        grain: Grain(rms: 2.3, size: 0.8, chroma: 0.08, underexposure: 0.10), halation: 0.04,
        leakTones: [SIMD3(1.0, 0.55, 0.25), SIMD3(1.0, 0.75, 0.4)], leakChance: 0.12,
        vignette: 0.2, softness: 0.15
    )

    public static let hp5 = FilmStock(
        id: "hp5", name: "Ilford HP5 Plus 400",
        look: {
            var l = LookSpec()
            // Panchromatic, a little dark in the reds and light in the blues.
            l.monoWeights = SIMD3(0.21, 0.60, 0.19)
            l.contrast = SIMD3(repeating: 1.22)
            // Holds highlights better than shadows: a long shoulder.
            l.shoulderRecovery = 0.5
            l.highlightRolloff = 0.04
            l.fade = 0
            return l
        }(),
        grain: Grain(rms: 3.6, size: 0.95, chroma: 0, underexposure: 0.12), halation: 0,
        leakTones: [SIMD3(0.8, 0.8, 0.8)], leakChance: 0.12,
        vignette: 0.3, softness: 0.15
    )

    public static let ektar100 = FilmStock(
        id: "ektar100", name: "Kodak Ektar 100",
        look: {
            var l = LookSpec()
            l.channelGain = SIMD3(1.02, 1.0, 0.97)
            // The world's finest-grain colour negative, and its punchiest: steep, slightly cool-shadowed curves.
            l.contrast = SIMD3(1.3, 1.28, 1.34)
            l.curveOffset = SIMD3(0, 0, -0.04)
            l.saturation = 1.3
            l.saturationRolloff = 0.18
            l.hueSectors = [
                // Deep, glowing reds and oranges.
                .init(center: 35, width: 60, chroma: 0.1),
                // Skin leans red, as Ektar is known for.
                .init(center: 58, width: 40, hueShift: -4, chroma: -0.06),
                // Rich blues and skies.
                .init(center: 260, width: 80, hueShift: -3, chroma: 0.12),
                // Vivid greens.
                .init(center: 140, width: 80, chroma: 0.06),
            ]
            l.highlightRolloff = 0.04
            l.fade = 0
            l.shadowTint = SIMD3(-0.005, 0, 0.012)
            l.highlightTint = SIMD3(0.01, 0.005, 0)
            return l
        }(),
        // Print Grain Index 25, the visibility threshold: grain only shows if you look hard.
        grain: Grain(rms: 1.5, size: 0.7, chroma: 0.08, underexposure: 0.15), halation: 0.05,
        leakTones: [SIMD3(1.0, 0.4, 0.15), SIMD3(1.0, 0.25, 0.3)], leakChance: 0.12,
        vignette: 0.22, softness: 0.12
    )

    public static let all = [superia400, portra400, ektar100, hp5]

    public static func with(id: String) -> FilmStock? {
        // Rolls loaded before Portra 400 replaced Portra 800 develop as Portra 400.
        let id = id == "portra800" ? portra400.id : id
        return all.first { $0.id == id }
    }

    public static func == (a: FilmStock, b: FilmStock) -> Bool { a.id == b.id }
}
