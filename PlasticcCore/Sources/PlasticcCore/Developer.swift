import CoreImage
import Foundation
import ImageIO

/// The lab: turns a shot's original JPEG into a print, scanned at a minilab's resolution.
public final class Developer: @unchecked Sendable {
    public enum DevelopError: Error { case unreadable, unencodable }

    /// The print's long edge, in pixels: 24 MP, downsampled from a 48 MP capture so it stays crisp.
    public static let scanLongEdge: CGFloat = 6048

    private let engine = FilmEngine()
    private let context = CIContext(options: [.cacheIntermediates: false])

    public init() {}

    public func develop(original: URL, film: FilmStock, shot: Roll.Shot, frameIndex: Int, dateStamp: Bool) throws -> Data {
        guard let source = CIImage(contentsOf: original, options: [.applyOrientationProperty: true]) else {
            throw DevelopError.unreadable
        }
        let long = max(source.extent.width, source.extent.height)
        // Scan at full size: smaller originals are enlarged first, so the lab's sharpening and the grain work at
        // print resolution, as on a real scan, rather than being enlarged afterwards with the picture.
        let scaled = long == Self.scanLongEdge
            ? source
            : source.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: Self.scanLongEdge / long, kCIInputAspectRatioKey: 1])
        let origin = scaled.transformed(by: CGAffineTransform(translationX: -scaled.extent.minX, y: -scaled.extent.minY))
        let ev = shot.sceneEV100 ?? Self.sceneEV100(of: original)
        let exposure = ev.map { FilmEngine.disposableExposure(sceneEV100: $0, flash: shot.flash) } ?? 0
        let capture = shot.source ?? .phone
        let white = Self.scanWhite(of: origin, film: film, source: capture, context: context)
        let print = engine.develop(origin, film: film, seed: shot.seed, frameIndex: frameIndex, flash: shot.flash,
                                   date: dateStamp ? shot.takenAt : nil, exposure: exposure, source: capture, white: white)
        guard let data = context.jpegRepresentation(of: print, colorSpace: FilmEngine.sRGB, options: [
            CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.95,
        ]) else { throw DevelopError.unencodable }
        return data
    }

    /// A frame with nothing on it, like a lab hands back for a blank or lost exposure: near-black, fogged, grainy.
    public func blankPrint(film: FilmStock, shot: Roll.Shot, frameIndex: Int) throws -> Data {
        let size = CGRect(x: 0, y: 0, width: Self.scanLongEdge * 2 / 3, height: Self.scanLongEdge)
        let base = CIImage(color: CIColor(red: 0.03, green: 0.03, blue: 0.03)).cropped(to: size)
        let print = engine.develop(base, film: film, seed: shot.seed, frameIndex: frameIndex, flash: false, date: nil)
        guard let data = context.jpegRepresentation(of: print, colorSpace: FilmEngine.sRGB, options: [:]) else {
            throw DevelopError.unencodable
        }
        return data
    }

    /// The white point a minilab scanner would set for a frame, as decoded linear light: from its brightest
    /// 0.5%, so a frame with no bright highlights prints its whites as white, and one with lamps or sky keeps
    /// them in the shoulder. Kept between 0.3 (about a stop and a half of stretch, as a minilab gives a thin
    /// negative) and the source's full range, in steps of 0.05 so a film's colour
    /// cube can be reused.
    public static func scanWhite(of image: CIImage, film: FilmStock, source: CaptureSource, context: CIContext) -> Double {
        let full = film.look.fullWhite(for: source)
        let s = 128 / max(image.extent.width, image.extent.height)
        let small = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
        let e = small.extent.integral
        var px = [Float](repeating: 0, count: Int(e.width * e.height) * 4)
        context.render(small, toBitmap: &px, rowBytes: Int(e.width) * 16, bounds: e, format: .RGBAf,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        // The brightest channel, so a saturated highlight counts too.
        let peaks = stride(from: 0, to: px.count, by: 4).map { Double(max(px[$0], px[$0 + 1], px[$0 + 2])) }.sorted()
        guard !peaks.isEmpty else { return full }
        let white = film.look.decoded(peaks[min(peaks.count - 1, Int(Double(peaks.count) * 0.995))], source: source)
        return (min(full, max(0.3, white)) * 20).rounded() / 20
    }

    /// How bright the scene was, as EV at ISO 100, from the phone's own exposure. Nil without EXIF.
    static func sceneEV100(of url: URL) -> Double? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let time = exif[kCGImagePropertyExifExposureTime] as? Double, time > 0,
              let aperture = exif[kCGImagePropertyExifFNumber] as? Double, aperture > 0,
              let iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [Double])?.first, iso > 0 else { return nil }
        return log2(aperture * aperture / time) - log2(iso / 100)
    }
}
