import CoreImage

enum PixelReader {
    static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
    ])

    /// RGBA8 sRGB bytes of the image's extent.
    static func rgba(_ image: CIImage) -> [UInt8] {
        let bounds = image.extent.integral
        let width = Int(bounds.width)
        var data = [UInt8](repeating: 0, count: width * Int(bounds.height) * 4)
        context.render(image, toBitmap: &data, rowBytes: width * 4, bounds: bounds,
                       format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        return data
    }

    /// Average sRGB 0–255 color of `rect` (Core Image coordinates, origin bottom-left).
    static func average(_ image: CIImage, in rect: CGRect) -> (r: Double, g: Double, b: Double) {
        let px = rgba(image.cropped(to: rect))
        var r = 0.0, g = 0.0, b = 0.0
        for i in stride(from: 0, to: px.count, by: 4) {
            r += Double(px[i]); g += Double(px[i + 1]); b += Double(px[i + 2])
        }
        let n = Double(px.count / 4)
        return (r / n, g / n, b / n)
    }
}

enum TestImages {
    /// Orange-to-blue horizontally, dark-to-light vertically.
    static func scene(width: CGFloat = 240, height: CGFloat = 320) -> CIImage {
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let horizontal = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: width, y: 0),
            "inputColor0": CIColor(red: 0.9, green: 0.3, blue: 0.1),
            "inputColor1": CIColor(red: 0.1, green: 0.4, blue: 0.9),
        ])!.outputImage!
        let vertical = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 0, y: height),
            "inputColor0": CIColor(red: 0.05, green: 0.05, blue: 0.05),
            "inputColor1": CIColor(red: 1, green: 1, blue: 1),
        ])!.outputImage!
        return horizontal
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: vertical])
            .cropped(to: rect)
    }

    static func solid(_ color: CIColor, width: CGFloat = 240, height: CGFloat = 320) -> CIImage {
        CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }
}
