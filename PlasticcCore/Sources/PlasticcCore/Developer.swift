import CoreImage
import Foundation
import ImageIO

/// The lab: turns a shot's original JPEG into a print, scanned at a minilab's resolution.
public final class Developer: @unchecked Sendable {
    public enum DevelopError: Error { case unreadable, unencodable }

    /// The print's long edge, in pixels: about 10 MP, like a lab scan, so it reads as a print rather than a
    /// crisp digital photo. Downsampled from a 48 MP capture.
    public static let scanLongEdge: CGFloat = 3870

    private let engine = FilmEngine()
    private let context = CIContext(options: [.cacheIntermediates: false])

    public init() {}

    public func develop(original: URL, film: FilmStock, shot: Roll.Shot, frameIndex: Int, dateStamp: Bool,
                        glow: Bool = false, leaks: Bool = true, format: PrintFormat = .classic) throws -> Data {
        guard let source = CIImage(contentsOf: original, options: [.applyOrientationProperty: true]) else {
            throw DevelopError.unreadable
        }
        let first = Self.scanned(source)
        let ev = shot.sceneEV100 ?? Self.sceneEV100(of: original)
        var exposure = ev.map { FilmEngine.disposableExposure(sceneEV100: $0, flash: shot.flash) } ?? 0
        var origin = first
        if let second = shot.second {
            // A second exposure adds its light to the first's, in linear light. Each is weighted by its own
            // exposure and the pair is developed at their mean, so a double doesn't burn out.
            let file = original.deletingLastPathComponent().appendingPathComponent(second.file)
            guard let other = CIImage(contentsOf: file, options: [.applyOrientationProperty: true]) else {
                throw DevelopError.unreadable
            }
            let ev2 = second.sceneEV100 ?? Self.sceneEV100(of: file)
            let e2 = ev2.map { FilmEngine.disposableExposure(sceneEV100: $0, flash: second.flash) } ?? 0
            let light1 = pow(2, exposure), light2 = pow(2, e2)
            origin = Self.blended(first, weight: light1 / (light1 + light2),
                                  with: Self.scanned(other, to: first.extent.size), weight: light2 / (light1 + light2))
            exposure = log2((light1 + light2) / 2)
        }
        let white = Self.scanWhite(of: origin, film: film, context: context)
        // The scanner sets each frame's black and white points, so whites print clean and blacks print black.
        let levels = scanLevels(of: engine.graded(origin, film: film, exposure: exposure, white: white), film: film)
        let print = engine.develop(origin, film: film, seed: shot.seed, frameIndex: frameIndex, flash: shot.flash,
                                   date: dateStamp ? shot.takenAt : nil, exposure: exposure, white: white, levels: levels,
                                   glow: glow, leaks: leaks, sunlight: FilmEngine.sunlight(sceneEV100: ev), format: format)
        guard let data = context.jpegRepresentation(of: Self.tagged(print, film: film, original: source.properties), colorSpace: FilmEngine.sRGB, options: [
            CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.95,
        ]) else { throw DevelopError.unencodable }
        return data
    }

    /// An original at scan size, with its extent at the origin. Smaller originals are enlarged first, so the lab's
    /// sharpening and the grain work at print resolution, as on a real scan, rather than being enlarged afterwards
    /// with the picture.
    static func scanned(_ source: CIImage) -> CIImage {
        let long = max(source.extent.width, source.extent.height)
        let scaled = long == scanLongEdge
            ? source
            : source.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scanLongEdge / long, kCIInputAspectRatioKey: 1])
        return scaled.transformed(by: CGAffineTransform(translationX: -scaled.extent.minX, y: -scaled.extent.minY))
    }

    /// A second exposure scaled to cover `size` (aspect fill) and cropped to the centre, at the origin.
    static func scanned(_ source: CIImage, to size: CGSize) -> CIImage {
        let extent = source.extent
        // A hair over, so rounding can't leave the crop a pixel short.
        let scale = max(size.width / extent.width, size.height / extent.height) * 1.001
        let scaled = source.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
        let dx = (scaled.extent.width - size.width) / 2, dy = (scaled.extent.height - size.height) / 2
        return scaled
            .cropped(to: CGRect(x: scaled.extent.minX + dx, y: scaled.extent.minY + dy, width: size.width, height: size.height))
            .transformed(by: CGAffineTransform(translationX: -scaled.extent.minX - dx, y: -scaled.extent.minY - dy))
    }

    /// Two frames' light mixed in linear light, `wa` of the first and `wb` of the second (the weights sum to 1). A
    /// dissolve keeps alpha at 1; adding the frames would double it and the grade would halve the colour.
    static func blended(_ a: CIImage, weight wa: Double, with b: CIImage, weight wb: Double) -> CIImage {
        a.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: b, kCIInputTimeKey: wb / (wa + wb),
        ])
    }

    /// Names the camera and the film in the print's info, so Photos shows "Plasticc Snappy 35" with the film as
    /// the lens, and keeps the phone's exposure (shutter, aperture, ISO, focal length) and capture time.
    static func tagged(_ print: CIImage, film: FilmStock, original: [String: Any]) -> CIImage {
        let phone = original[kCGImagePropertyExifDictionary as String] as? [CFString: Any] ?? [:]
        var exif = phone.filter { [kCGImagePropertyExifExposureTime, kCGImagePropertyExifFNumber,
                                   kCGImagePropertyExifISOSpeedRatings, kCGImagePropertyExifFocalLength,
                                   kCGImagePropertyExifFocalLenIn35mmFilm, kCGImagePropertyExifDateTimeOriginal,
                                   kCGImagePropertyExifOffsetTimeOriginal].contains($0.key) }
        exif[kCGImagePropertyExifLensModel] = film.name
        return print.settingProperties([
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Plasticc", kCGImagePropertyTIFFModel: "Snappy 35"],
            kCGImagePropertyExifDictionary: exif,
        ] as [CFString: Any])
    }

    /// A frame with nothing on it, like a lab hands back for a blank or lost exposure: near-black, fogged, grainy.
    public func blankPrint(film: FilmStock, shot: Roll.Shot, frameIndex: Int, format: PrintFormat = .classic) throws -> Data {
        let size = CGRect(x: 0, y: 0, width: (Self.scanLongEdge / format.ratio).rounded(), height: Self.scanLongEdge)
        let base = CIImage(color: CIColor(red: 0.03, green: 0.03, blue: 0.03)).cropped(to: size)
        let print = engine.develop(base, film: film, seed: shot.seed, frameIndex: frameIndex, flash: false, date: nil,
                                   format: format)
        guard let data = context.jpegRepresentation(of: print, colorSpace: FilmEngine.sRGB, options: [:]) else {
            throw DevelopError.unencodable
        }
        return data
    }

    /// The white point a minilab scanner would set for a frame, as decoded linear light: from its brightest
    /// 0.5%, so a frame with no bright highlights prints its whites as white, and one with lamps or sky keeps
    /// them in the shoulder. Kept between 0.3 (about a stop and a half of stretch, as a minilab gives a thin
    /// negative) and the photo's full range, in steps of 0.05 so a film's colour
    /// cube can be reused.
    public static func scanWhite(of image: CIImage, film: FilmStock, context: CIContext) -> Double {
        let full = film.look.fullWhite
        let s = 128 / max(image.extent.width, image.extent.height)
        let small = image.transformed(by: CGAffineTransform(scaleX: s, y: s))
        let e = small.extent.integral
        var px = [Float](repeating: 0, count: Int(e.width * e.height) * 4)
        context.render(small, toBitmap: &px, rowBytes: Int(e.width) * 16, bounds: e, format: .RGBAf,
                       colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        // The brightest channel, so a saturated highlight counts too.
        let peaks = stride(from: 0, to: px.count, by: 4).map { Double(max(px[$0], px[$0 + 1], px[$0 + 2])) }.sorted()
        guard !peaks.isEmpty else { return full }
        let white = film.look.decoded(peaks[min(peaks.count - 1, Int(Double(peaks.count) * 0.995))])
        return (min(full, max(0.3, white)) * 20).rounded() / 20
    }

    /// The scanner's black and white points for a graded frame: from its darkest and brightest 0.5% of luminance.
    func scanLevels(of graded: CIImage, film: FilmStock) -> ScanLevels {
        let s = 128 / max(graded.extent.width, graded.extent.height)
        let small = graded.transformed(by: CGAffineTransform(scaleX: s, y: s))
        let e = small.extent.integral
        var px = [Float](repeating: 0, count: Int(e.width * e.height) * 4)
        context.render(small, toBitmap: &px, rowBytes: Int(e.width) * 16, bounds: e, format: .RGBAf,
                       colorSpace: FilmEngine.sRGB)
        let luma = stride(from: 0, to: px.count, by: 4)
            .map { 0.2126 * Double(px[$0]) + 0.7152 * Double(px[$0 + 1]) + 0.0722 * Double(px[$0 + 2]) }
            .sorted()
        guard luma.count > 1 else { return ScanLevels(darkest: 0, brightest: 1) }
        return ScanLevels(darkest: luma[Int(Double(luma.count) * 0.005)],
                          brightest: luma[min(luma.count - 1, Int(Double(luma.count) * 0.995))],
                          blackTarget: film.printBlack, whiteTarget: film.printWhite)
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
