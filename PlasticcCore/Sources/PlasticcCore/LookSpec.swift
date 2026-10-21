import Foundation

/// One film's colour, as a function from an iPhone pixel (sRGB-encoded, 0–1) to a minilab scan of the negative.
/// Baked into a 3D LUT, so none of this costs anything per pixel at develop time.
///
/// The steps, in order:
/// 1. Decode to linear light and undo part of the phone's highlight compression, so a film shoulder doesn't
///    squash highlights a second time.
/// 2. White balance (`channelGain`) and exposure.
/// 3. A characteristic curve per channel, in stops around mid-grey: a log-sigmoid whose steepness is that
///    layer's contrast. Different steepness per channel gives the colour crossover between shadows and
///    highlights that a single shared curve can't.
/// 4. Into OkLab: hue and chroma shifts for ranges of hue (greens toward teal, skin toward orange…), and
///    saturation that falls away in deep shadows and bright highlights.
/// 5. Highlight compression on lightness only, so bright colours keep their hue.
/// 6. Back to sRGB, with print-like shadow and highlight tints and a lifted black.
public struct LookSpec: Sendable, Equatable {
    /// A range of hue to push: hue angles are OkLCh degrees (red ≈ 30, skin ≈ 55, yellow ≈ 100, green ≈ 145,
    /// cyan ≈ 195, blue ≈ 265, magenta ≈ 330).
    public struct HueSector: Sendable, Equatable {
        public var center: Double
        /// Full width of the raised-cosine window, in degrees.
        public var width: Double
        /// Degrees to rotate hues in the sector; positive turns toward the next hue up (green → cyan).
        public var hueShift: Double
        /// Relative chroma change at the sector's centre: 0.1 is 10% more saturated.
        public var chroma: Double

        public init(center: Double, width: Double = 70, hueShift: Double = 0, chroma: Double = 0) {
            self.center = center
            self.width = width
            self.hueShift = hueShift
            self.chroma = chroma
        }
    }

    public var exposure: Double = 0
    /// White balance as per-channel gain in linear light.
    public var channelGain: SIMD3<Double> = SIMD3(1, 1, 1)
    /// How much highlight headroom to recover from the phone's own tone mapping, 0–0.6.
    public var shoulderRecovery: Double = 0.35
    /// Steepness of each channel's characteristic curve. 1 is a typical print's contrast; film layers that
    /// differ give crossover (a steeper blue makes shadows warmer and highlights cooler).
    public var contrast: SIMD3<Double> = SIMD3(1, 1, 1)
    /// Shifts each channel's curve along exposure, in stops; affects midtones, not black or white.
    public var curveOffset: SIMD3<Double> = .zero
    public var saturation: Double = 1
    /// How much saturation falls in deep shadows and bright highlights, 0–0.5.
    public var saturationRolloff: Double = 0.2
    public var hueSectors: [HueSector] = []
    /// Compresses lightness toward a paper white, 0–0.3.
    public var highlightRolloff: Double = 0
    /// Black lift, 0–0.2.
    public var fade: Double = 0
    public var shadowTint: SIMD3<Double> = .zero
    public var highlightTint: SIMD3<Double> = .zero
    /// Black and white: mix the linear channels with these weights instead of keeping colour.
    public var monoWeights: SIMD3<Double>?

    public init() {}

    public func apply(_ input: SIMD3<Double>) -> SIMD3<Double> {
        Prepared(self).apply(input)
    }

    /// RGBA Float32 cube data for `CIColorCubeWithColorSpace`, red changing fastest.
    func cubeData(size: Int) -> Data {
        let prepared = Prepared(self)
        var rgba: [Float] = []
        rgba.reserveCapacity(size * size * size * 4)
        let step = Double(size - 1)
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let out = prepared.apply(SIMD3(Double(r) / step, Double(g) / step, Double(b) / step))
                    rgba.append(contentsOf: [Float(out.x), Float(out.y), Float(out.z), 1])
                }
            }
        }
        return rgba.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

// MARK: - The pipeline

extension LookSpec {
    /// The spec with its curves solved, so the cube's 36,000 samples don't each re-solve them.
    struct Prepared {
        let spec: LookSpec
        let curves: [Curve]

        init(_ spec: LookSpec) {
            self.spec = spec
            let headroom = 1 + spec.shoulderRecovery
            if spec.monoWeights != nil {
                curves = [Curve(steepness: spec.contrast.x, offset: 0, headroom: headroom)]
            } else {
                curves = (0..<3).map { Curve(steepness: spec.contrast[$0], offset: spec.curveOffset[$0], headroom: headroom) }
            }
        }

        func apply(_ input: SIMD3<Double>) -> SIMD3<Double> {
            // 1–2. Scene-ish linear light.
            var linear = Color.decode(input.clamped(lowerBound: .zero, upperBound: .one))
            linear = Color.recoverShoulder(linear, amount: spec.shoulderRecovery)
            linear *= spec.channelGain * pow(2, spec.exposure)

            // 3. Characteristic curves; their output is display-encoded.
            var display: SIMD3<Double>
            if let weights = spec.monoWeights {
                let y = curves[0].apply((linear * weights).sum())
                display = SIMD3(repeating: y)
            } else {
                display = SIMD3(curves[0].apply(linear.x), curves[1].apply(linear.y), curves[2].apply(linear.z))
            }

            // 4–5. Hue, chroma and lightness in OkLab.
            if spec.monoWeights == nil {
                var lch = Color.oklch(fromLinear: Color.decode(display))
                for sector in spec.hueSectors {
                    let w = sector.weight(at: lch.z)
                    lch.z += sector.hueShift * w
                    lch.y *= 1 + sector.chroma * w
                }
                let fromMid = 2 * lch.x - 1
                lch.y *= spec.saturation * max(0, 1 - spec.saturationRolloff * fromMid * fromMid)
                lch.x = rolledOff(lch.x)
                display = Color.encode(Color.linear(fromOklch: lch).clamped(lowerBound: .zero, upperBound: .one))
            } else {
                display = SIMD3(repeating: rolledOff(display.x))
            }

            // 6. Print-like tints and lifted blacks, in display values.
            let luma = (display * SIMD3(0.2126, 0.7152, 0.0722)).sum()
            display += spec.shadowTint * ((1 - luma) * (1 - luma)) + spec.highlightTint * (luma * luma)
            display = spec.fade + display * (1 - spec.fade)
            return display.clamped(lowerBound: .zero, upperBound: .one)
        }

        /// Eases lightness above 0.65 down toward a paper white of 1 − rolloff/3.
        private func rolledOff(_ l: Double) -> Double {
            guard spec.highlightRolloff > 0, l > 0.65 else { return l }
            let t = (l - 0.65) / 0.35
            return l - spec.highlightRolloff * t * t * 0.35
        }
    }

    /// A film layer's characteristic curve: a straight line in log exposure through mid-grey (its slope is the
    /// layer's gamma, relative to a normal print), then a smooth shoulder that eases the brightest input into
    /// white. Shadows keep their detail, as film's long toe does. Output is display-encoded.
    struct Curve {
        static let midGrey = 0.18
        /// Where the shoulder starts, in linear light (display ≈ 0.63).
        static let knee = 0.34

        let gamma: Double
        let offset: Double
        /// The brightest input after the gamma, which the shoulder maps to 1.
        let white: Double
        /// Shoulder exponent, chosen so the curve's slope is continuous at the knee.
        let power: Double

        init(steepness: Double, offset: Double, headroom: Double) {
            gamma = max(0.3, steepness)
            self.offset = offset
            white = Self.midGrey * pow(2, gamma * log2(headroom / Self.midGrey) + offset)
            power = white > 1 ? (white - Self.knee) / (1 - Self.knee) : 1
        }

        func apply(_ linear: Double) -> Double {
            guard linear > 0 else { return 0 }
            var x = Self.midGrey * pow(2, gamma * log2(linear / Self.midGrey) + offset)
            if white <= 1 {
                // Not enough range to need a shoulder: stretch so the brightest input still reaches white.
                x /= white
            } else if x > Self.knee {
                let t = min(1, (x - Self.knee) / (white - Self.knee))
                x = Self.knee + (1 - Self.knee) * (1 - pow(1 - t, power))
            }
            return Color.encode(min(1, x))
        }
    }
}

extension LookSpec.HueSector {
    /// Raised-cosine weight of a hue (degrees) in this sector: 1 at the centre, 0 at the edges.
    func weight(at hue: Double) -> Double {
        var delta = (hue - center).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let half = width / 2
        guard abs(delta) < half else { return 0 }
        return 0.5 * (1 + cos(.pi * delta / half))
    }
}

// MARK: - Colour maths

/// sRGB transfer functions and OkLab (Björn Ottosson, 2020).
enum Color {
    static func decode(_ c: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(decode(c.x), decode(c.y), decode(c.z))
    }

    static func encode(_ c: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(encode(c.x), encode(c.y), encode(c.z))
    }

    static func decode(_ v: Double) -> Double {
        v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    static func encode(_ v: Double) -> Double {
        let v = max(0, v)
        return v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055
    }

    /// Undoes a Reinhard-style shoulder: 1.0 opens up to 1 + amount, mid-grey barely moves.
    static func recoverShoulder(_ c: SIMD3<Double>, amount h: Double) -> SIMD3<Double> {
        guard h > 0 else { return c }
        return c * (1 + h) / (SIMD3(repeating: 1 + h) - h * c)
    }

    /// Lightness, chroma, hue in degrees.
    static func oklch(fromLinear c: SIMD3<Double>) -> SIMD3<Double> {
        let l = cbrt(0.4122214708 * c.x + 0.5363325363 * c.y + 0.0514459929 * c.z)
        let m = cbrt(0.2119034982 * c.x + 0.6806995451 * c.y + 0.1073969566 * c.z)
        let s = cbrt(0.0883024619 * c.x + 0.2817188376 * c.y + 0.6299787005 * c.z)
        let L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        var h = atan2(b, a) * 180 / .pi
        if h < 0 { h += 360 }
        return SIMD3(L, (a * a + b * b).squareRoot(), h)
    }

    static func linear(fromOklch lch: SIMD3<Double>) -> SIMD3<Double> {
        let a = lch.y * cos(lch.z * .pi / 180)
        let b = lch.y * sin(lch.z * .pi / 180)
        let l = pow(lch.x + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lch.x - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lch.x - 0.0894841775 * a - 1.2914855480 * b, 3)
        return SIMD3(
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
    }
}
