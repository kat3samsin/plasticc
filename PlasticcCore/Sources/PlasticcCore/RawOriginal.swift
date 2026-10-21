import CoreImage

/// Writing and reading the originals made from RAW: scene-linear light scaled into 0–1 by `rawHeadroom` and
/// saved as 10-bit HEIF, so highlights above white survive and shadows don't band.
public enum RawOriginal {
    static let linearSRGB = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// `linear` is scene light in Core Image's linear working space, with diffuse white near 1.
    public static func encode(_ linear: CIImage, context: CIContext) -> Data? {
        let scaled = linear
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1 / CaptureSource.rawHeadroom, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1 / CaptureSource.rawHeadroom, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1 / CaptureSource.rawHeadroom, w: 0),
            ])
            .applyingFilter("CIColorClamp")
        return try? context.heif10Representation(of: scaled, colorSpace: sRGB, options: [
            CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.95,
        ])
    }
}
