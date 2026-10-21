import CoreImage
import ImageIO
import XCTest
@testable import PlasticcCore

final class DeveloperTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// Writes a sensor-shaped landscape JPEG tagged with an EXIF orientation.
    func original(width: CGFloat, height: CGFloat, orientation: CGImagePropertyOrientation) throws -> URL {
        let url = dir.appendingPathComponent("\(UUID().uuidString).jpg")
        let image = TestImages.scene(width: width, height: height)
        let context = CIContext()
        let cg = try XCTUnwrap(context.createCGImage(image, from: image.extent))
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, cg, [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    func size(of data: Data) throws -> CGSize {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return CGSize(width: props[kCGImagePropertyPixelWidth] as! Int, height: props[kCGImagePropertyPixelHeight] as! Int)
    }

    func shot(flash: Bool = false) -> Roll.Shot {
        Roll.Shot(file: "x.jpg", takenAt: Date(timeIntervalSince1970: 1_790_000_000), flash: flash, seed: 99)
    }

    func testPortraitShotBecomesAPortraitPrintAtScanSize() throws {
        // A phone held upright: landscape sensor pixels tagged "rotate 90".
        let url = try original(width: 8064, height: 6048, orientation: .right)
        let data = try Developer().develop(original: url, film: .superia400, shot: shot(), frameIndex: 3, dateStamp: true)
        let s = try size(of: data)
        XCTAssertEqual(s.height, Developer.scanLongEdge)
        XCTAssertEqual(s.width / s.height, 2.0 / 3.0, accuracy: 0.002)
    }

    func testSidewaysShotBecomesALandscapePrint() throws {
        let url = try original(width: 8064, height: 6048, orientation: .up)
        let data = try Developer().develop(original: url, film: .hp5, shot: shot(flash: true), frameIndex: 0, dateStamp: false)
        let s = try size(of: data)
        XCTAssertEqual(s.width, Developer.scanLongEdge)
        XCTAssertEqual(s.width / s.height, 3.0 / 2.0, accuracy: 0.002)
    }

    func testSmallerOriginalsAreScannedAtPrintSize() throws {
        let url = try original(width: 900, height: 600, orientation: .up)
        let data = try Developer().develop(original: url, film: .portra400, shot: shot(), frameIndex: 5, dateStamp: true)
        XCTAssertEqual(try size(of: data), CGSize(width: Developer.scanLongEdge, height: Developer.scanLongEdge * 2 / 3))
    }

    func testBlankPrintIsADarkPortraitFrame() throws {
        let data = try Developer().blankPrint(film: .superia400, shot: shot(), frameIndex: 4)
        let s = try size(of: data)
        XCTAssertEqual(s.height, Developer.scanLongEdge)
        let image = try XCTUnwrap(CIImage(data: data))
        XCTAssertLessThan(PixelReader.average(image, in: CGRect(x: s.width / 2 - 50, y: s.height / 2 - 50, width: 100, height: 100)).g, 40)
    }

    func testUnreadableOriginalThrows() {
        let url = dir.appendingPathComponent("missing.jpg")
        XCTAssertThrowsError(try Developer().develop(original: url, film: .hp5, shot: shot(), frameIndex: 0, dateStamp: true))
    }
}

final class RawOriginalTests: XCTestCase {
    /// A scene with three patches: mid-grey, diffuse white, and a highlight a stop above white.
    func scene() -> CIImage {
        let w: CGFloat = 600, h: CGFloat = 900
        func patch(_ v: CGFloat, _ x: CGFloat) -> CIImage {
            CIImage(color: CIColor(red: v, green: v, blue: v, alpha: 1, colorSpace: RawOriginal.linearSRGB)!)
                .cropped(to: CGRect(x: x, y: 0, width: w / 3, height: h))
        }
        return patch(0.18, 0).composited(over: patch(1.0, w / 3)).composited(over: patch(2.0, 2 * w / 3))
    }

    func testRawKeepsHighlightsThatAPhonePhotoClips() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("raw.heic")
        try XCTUnwrap(RawOriginal.encode(scene(), context: CIContext())).write(to: url)

        var film = FilmStock.portra400
        film = FilmStock(id: film.id, name: film.name, look: film.look, grain: .init(rms: 0, size: 1, chroma: 0, underexposure: 0),
                         halation: 0, leakTones: film.leakTones, leakChance: 0, vignette: 0, softness: 0)
        let shot = Roll.Shot(file: "raw.heic", takenAt: Date(), flash: false, seed: 1, source: .raw, sceneEV100: 11.3)
        let data = try Developer().develop(original: url, film: film, shot: shot, frameIndex: 9, dateStamp: false)
        let print = try XCTUnwrap(CIImage(data: data))
        let w = print.extent.width, h = print.extent.height
        func level(_ third: CGFloat) -> Double {
            PixelReader.average(print, in: CGRect(x: w * (third + 0.1) / 3, y: h * 0.4, width: w * 0.08, height: h * 0.2)).g
        }
        let mid = level(0), white = level(1), over = level(2)
        XCTAssertEqual(mid, 0.47 * 255, accuracy: 25, "mid-grey prints near mid-grey")
        XCTAssertGreaterThan(over, white + 4, "a highlight above white still has detail")
        XCTAssertLessThan(white, 250, "diffuse white is not clipped")
    }
}
