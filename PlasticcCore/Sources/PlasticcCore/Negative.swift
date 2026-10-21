import CoreImage

/// How a frame looks on the processed negative: tones inverted, colour film on its orange mask, black and white on a clear grey base.
public enum Negative {
    public static func make(from print: CIImage, film: FilmStock) -> CIImage {
        // Work in display values, not linear light, or the strip comes out pale and thin.
        let inverted = print.applyingFilter("CILinearToSRGBToneCurve").applyingFilter("CIColorInvert")
        // Colour negative's orange mask: the base passes red, holds back blue. Silver film is near-neutral, a touch cool.
        let (gain, base): (SIMD3<Double>, SIMD3<Double>) = film.look.monoWeights == nil
            ? (SIMD3(0.70, 0.46, 0.28), SIMD3(0.24, 0.10, 0.03))
            : (SIMD3(0.72, 0.74, 0.76), SIMD3(0.10, 0.10, 0.11))
        return inverted.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: gain.x, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: gain.y, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: gain.z, w: 0),
            "inputBiasVector": CIVector(x: base.x, y: base.y, z: base.z, w: 0),
        ])
        .applyingFilter("CISRGBToneCurveToLinear")
    }
}
