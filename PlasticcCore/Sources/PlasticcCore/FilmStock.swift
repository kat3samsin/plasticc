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
        /// How much of the grain stays in the highlights, 0–1: 0 fades it out of bright tones as a Frontier scan
        /// does; 1 keeps it in a bright sky, as a Noritsu's sharpening leaves it.
        public var highlights: Double = 0
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
    /// Extra corner darkening in sunlight, 0–1, on top of `vignette`: an LC-A's lens vignettes hardest stopped
    /// down on a bright day and hardly at all wide open indoors. Scaled by `FilmEngine.sunlight`.
    public var sunVignette = 0.0
    /// Corner softness of the lens, as a blur sigma in pixels at a 1000 px long edge. The centre stays sharp.
    public let softness: Double
    /// Whether the lab's scan picks up dust and the odd hair on the negative.
    public let dust: Bool
    /// How much dust and hair the scan picks up: 1 is a typical lab, 2 a dusty one.
    public var dustAmount = 1.0
    /// Where the print's darkest and brightest tones land (display values), set per film by the scanner.
    public var printBlack = ScanLevels.blackTarget
    public var printWhite = ScanLevels.whiteTarget

    public static let superia400 = FilmStock(
        id: "superia400", name: "Verde 400",
        look: {
            var l = LookSpec()
            // White balance leans green, as a Frontier scan of this film does.
            l.channelGain = SIMD3(0.955, 1.045, 0.98)
            // Datasheet layer gammas are about 0.59 / 0.59 / 0.77: a contrastier blue layer.
            l.contrast = SIMD3(1.26, 1.26, 1.36)
            l.curveOffset = SIMD3(-0.02, 0.07, -0.03)
            l.saturation = 1.12
            l.saturationRolloff = 0.22
            l.hueSectors = [
                // Fuji greens: leaning teal and a bit richer.
                .init(center: 145, width: 90, hueShift: 12, chroma: 0.12),
                // Skin kept clear of the green lean, a touch pinker than Kodak.
                .init(center: 55, width: 60, hueShift: -15),
                // Bright, clean blues.
                .init(center: 255, width: 70, hueShift: 6, chroma: -0.06),
            ]
            l.highlightRolloff = 0.05
            l.fade = 0
            l.shadowTint = SIMD3(-0.04, 0.055, 0.01)
            l.highlightTint = SIMD3(0.015, -0.005, 0.015)
            return l
        }(),
        // Weak antihalation layer: more glow than Portra.
        grain: Grain(rms: 9, size: 0.55, chroma: 0.25, underexposure: 0.15, highlights: 1), halation: 0.15,
        leakTones: [SIMD3(1.0, 0.45, 0.2), SIMD3(1.0, 0.3, 0.5)], leakChance: 0.25,
        vignette: 0.56, softness: 0.45, dust: true
    )

    public static let portra400: FilmStock = {
        var film = FilmStock(
            id: "portra400", name: "Honey 400",
            look: {
                // Matched to eight lab scans of Portra 400 shot on a Lomo LC-A (see docs/film-looks.md): neutral
                // greys, deep cyan-leaning skies, soft greens and yellows, warm skin, teal shadows under warm highlights.
                var l = LookSpec()
                // The scans' greys sit within a couple of levels of neutral; the warmth is in skin and highlights.
                l.channelGain = SIMD3(1.01, 1.0, 0.985)
                // A bright print, as the lab scans are: their midtones sit a stop or so above a phone's.
                l.exposure = 0.5
                // Gentle contrast, with the red layer a little steeper than blue so shadows cool and highlights warm.
                l.contrast = SIMD3(1.12, 1.11, 1.08)
                l.curveOffset = .zero
                l.saturation = 1.04
                // Pale skies in the scans keep their blue, so saturation holds further into the highlights.
                l.saturationRolloff = 0.12
                l.hueSectors = [
                    // Skin and sand toward orange, a touch richer.
                    .init(center: 45, width: 70, hueShift: 3, chroma: 0.04),
                    // Yellows soft, as on the scans.
                    .init(center: 95, width: 50, chroma: -0.05),
                    // Greens muted, sage rather than lime: the scans' greens sit around hue 130 at low chroma.
                    .init(center: 130, width: 90, hueShift: 3, chroma: -0.25),
                    // The scans' skies lean cyan, hue about 240 in OkLCh. Their depth is the hue, not extra
                    // chroma: more than this clips a deep sky out of the sRGB gamut.
                    // Keep the rotation gentle: the channel curves already move phone skies toward cyan.
                    .init(center: 255, width: 80, hueShift: -4, chroma: 0.08),
                ]
                l.highlightRolloff = 0.15
                l.fade = 0
                // Teal shadows under warm highlights, as the scans show.
                l.shadowTint = SIMD3(-0.01, 0.008, 0.012)
                l.highlightTint = SIMD3(0.012, 0.004, -0.008)
                return l
            }(),
            // Strong antihalation layer: a softer glow than Superia.
            // Grain as the lab scans show it: strong, crisp and almost all luminance. Kodak's Print Grain Index puts
            // Portra below the other colour films, but a Noritsu's sharpening makes it the most visible on a scan.
            grain: Grain(rms: 12, size: 0.3, chroma: 0.12, underexposure: 0.10, highlights: 1), halation: 0.04,
            leakTones: [SIMD3(1.0, 0.55, 0.25), SIMD3(1.0, 0.75, 0.4)], leakChance: 0.25,
            vignette: 0.56, softness: 0.45, dust: true
        )
        // Near-black shadows, with brighter scanner whites supported by the LC-A+ reference scans.
        film.printBlack = 0.015
        film.printWhite = 0.94
        // The LC-A's lens darkens the corners on a bright day and barely at all indoors.
        film.sunVignette = 0.15
        return film
    }()

    public static let hp5 = FilmStock(
        id: "hp5", name: "Mono 400",
        look: {
            var l = LookSpec()
            // Panchromatic, a little dark in the reds and light in the blues.
            l.monoWeights = SIMD3(0.21, 0.60, 0.19)
            // Punchy, with deep blacks.
            l.contrast = SIMD3(repeating: 1.5)
            // Holds highlights better than shadows: a long shoulder.
            l.shoulderRecovery = 0.5
            l.highlightRolloff = 0.04
            l.fade = 0
            return l
        }(),
        grain: Grain(rms: 16, size: 0.6, chroma: 0, underexposure: 0.12, highlights: 1), halation: 0,
        leakTones: [SIMD3(0.8, 0.8, 0.8)], leakChance: 0.25,
        // Grittier than the colour films: grainier, and a dustier scan.
        vignette: 0.56, softness: 0.45, dust: true, dustAmount: 2,
        // Blacks print near true black; HP5 reference scans retain bright whites above the colour-print ceiling.
        printBlack: 0.008, printWhite: 0.94
    )

    public static let ektar100 = FilmStock(
        id: "ektar100", name: "Vivid 100",
        look: {
            var l = LookSpec()
            l.channelGain = SIMD3(1.02, 1.0, 0.97)
            // The world's finest-grain colour negative, and its punchiest: steep, slightly cool-shadowed curves.
            l.contrast = SIMD3(1.3, 1.28, 1.34)
            l.curveOffset = SIMD3(0, 0, -0.04)
            l.saturation = 1.2
            l.saturationRolloff = 0.18
            l.hueSectors = [
                // Deep, glowing reds and oranges.
                .init(center: 35, width: 60, chroma: 0.05),
                // Keep the red lean, but restrain warm skin before the overall saturation boost.
                .init(center: 45, width: 60, hueShift: -4, chroma: -0.16),
                // Rich blues and skies.
                .init(center: 260, width: 80, hueShift: -3, chroma: 0.08),
                // Vivid greens.
                .init(center: 140, width: 80, chroma: 0.06),
            ]
            l.highlightRolloff = 0.04
            l.fade = 0
            l.shadowTint = SIMD3(-0.005, 0, 0.012)
            l.highlightTint = SIMD3(0.01, 0.005, 0)
            return l
        }(),
        // Real Ektar is near grainless (Print Grain Index 25); this one carries the same grain as Verde.
        grain: Grain(rms: 9, size: 0.45, chroma: 0.25, underexposure: 0.15, highlights: 1), halation: 0.05,
        leakTones: [SIMD3(1.0, 0.4, 0.15), SIMD3(1.0, 0.25, 0.3)], leakChance: 0.25,
        vignette: 0.56, softness: 0.45, dust: true
    )

    public static let all = [superia400, portra400, ektar100, hp5]

    public static func with(id: String) -> FilmStock? {
        // Rolls loaded before Portra 400 replaced Portra 800 develop as Portra 400.
        let id = id == "portra800" ? portra400.id : id
        return all.first { $0.id == id }
    }

    public static func == (a: FilmStock, b: FilmStock) -> Bool { a.id == b.id }
}
