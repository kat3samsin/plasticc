import CoreImage
import Foundation
import ImageIO

/// The lab: turns a shot's original JPEG into a print, scanned at a minilab's resolution.
public final class Developer: @unchecked Sendable {
    public enum DevelopError: Error { case unreadable, unencodable }

    /// A Frontier scan's long edge, in pixels.
    public static let scanLongEdge: CGFloat = 3088

    private let engine = FilmEngine()
    private let context = CIContext(options: [.cacheIntermediates: false])

    public init() {}

    public func develop(original: URL, film: FilmStock, shot: Roll.Shot, frameIndex: Int, dateStamp: Bool) throws -> Data {
        guard let source = CIImage(contentsOf: original, options: [.applyOrientationProperty: true]) else {
            throw DevelopError.unreadable
        }
        let long = max(source.extent.width, source.extent.height)
        let scaled = long > Self.scanLongEdge
            ? source.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: Self.scanLongEdge / long, kCIInputAspectRatioKey: 1])
            : source
        let origin = scaled.transformed(by: CGAffineTransform(translationX: -scaled.extent.minX, y: -scaled.extent.minY))
        let exposure = Self.sceneEV100(of: original).map { FilmEngine.disposableExposure(sceneEV100: $0, flash: shot.flash) } ?? 0
        let print = engine.develop(origin, film: film, seed: shot.seed, frameIndex: frameIndex, flash: shot.flash,
                                   date: dateStamp ? shot.takenAt : nil, exposure: exposure)
        guard let data = context.jpegRepresentation(of: print, colorSpace: FilmEngine.sRGB, options: [
            CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.9,
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
