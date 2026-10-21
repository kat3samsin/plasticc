import Foundation

/// Per-pixel colour math for one film, in sRGB-encoded 0–1 values. Baked into a 3D LUT.
public struct LookSpec: Sendable, Equatable {
    public var exposure: Double = 0
    /// 0–1. Blends toward a smoothstep S-curve.
    public var contrast: Double = 0
    /// Black lift, 0–0.2.
    public var fade: Double = 0
    /// Compresses whites, 0–0.3.
    public var highlightRolloff: Double = 0
    public var saturation: Double = 1
    public var shadowTint: SIMD3<Double> = .zero
    public var highlightTint: SIMD3<Double> = .zero
    /// White balance as per-channel gain.
    public var channelGain: SIMD3<Double> = SIMD3(1, 1, 1)
    /// Black and white: mix the channels with these weights instead of keeping colour.
    public var monoWeights: SIMD3<Double>?

    static let lumaWeights = SIMD3<Double>(0.2126, 0.7152, 0.0722)

    public init() {}

    public func apply(_ input: SIMD3<Double>) -> SIMD3<Double> {
        var c = input * channelGain * pow(2, exposure)
        c = c.clamped(lowerBound: .zero, upperBound: .one)
        if let monoWeights {
            c = SIMD3(repeating: (c * monoWeights).sum())
        }
        if contrast != 0 {
            let s = c * c * (3 - 2 * c)
            c = c + contrast * (s - c)
        }
        let luma = (c * Self.lumaWeights).sum()
        if monoWeights == nil {
            let gray = SIMD3(repeating: luma)
            c = gray + saturation * (c - gray)
        }
        c += shadowTint * ((1 - luma) * (1 - luma)) + highlightTint * (luma * luma)
        c -= highlightRolloff * c * c
        c = fade + c * (1 - fade)
        return c.clamped(lowerBound: .zero, upperBound: .one)
    }

    /// RGBA Float32 cube data for `CIColorCubeWithColorSpace`, red changing fastest.
    func cubeData(size: Int) -> Data {
        var rgba: [Float] = []
        rgba.reserveCapacity(size * size * size * 4)
        let step = Double(size - 1)
        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let out = apply(SIMD3(Double(r) / step, Double(g) / step, Double(b) / step))
                    rgba.append(contentsOf: [Float(out.x), Float(out.y), Float(out.z), 1])
                }
            }
        }
        return rgba.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
