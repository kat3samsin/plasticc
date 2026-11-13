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
    func original(width: CGFloat, height: CGFloat, orientation: CGImagePropertyOrientation,
                  exif: [CFString: Any] = [:]) throws -> URL {
        let url = dir.appendingPathComponent("\(UUID().uuidString).jpg")
        let image = TestImages.scene(width: width, height: height)
        let context = CIContext()
        let cg = try XCTUnwrap(context.createCGImage(image, from: image.extent))
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, cg, [kCGImagePropertyOrientation: orientation.rawValue,
                                              kCGImagePropertyExifDictionary: exif] as CFDictionary)
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

    /// Writes an upright black JPEG, a frame with nothing on it.
    func blackOriginal(width: CGFloat, height: CGFloat) throws -> URL {
        let url = dir.appendingPathComponent("\(UUID().uuidString).jpg")
        let image = TestImages.solid(CIColor(red: 0, green: 0, blue: 0), width: width, height: height)
        let cg = try XCTUnwrap(CIContext().createCGImage(image, from: image.extent))
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, cg, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    /// A shot whose second exposure is the file at `second`, in the same folder as its original.
    func doubleShot(second: URL) -> Roll.Shot {
        var shot = shot()
        shot.second = Roll.Shot.Second(file: second.lastPathComponent, flash: false, sceneEV100: nil)
        return shot
    }

    func testDoubleExposurePrintsAtTheFirstFramesShape() throws {
        let first = try original(width: 8064, height: 6048, orientation: .right)
        let second = try original(width: 8064, height: 6048, orientation: .up)
        let single = try Developer().develop(original: first, film: .superia400, shot: shot(), frameIndex: 0, dateStamp: false)
        let double = try Developer().develop(original: first, film: .superia400, shot: doubleShot(second: second),
                                             frameIndex: 0, dateStamp: false)
        XCTAssertEqual(try size(of: double), try size(of: single))
    }

    func testDoubleExposureShowsBoth() throws {
        let first = try blackOriginal(width: 900, height: 600)
        let second = try original(width: 900, height: 600, orientation: .up)
        let data = try Developer().develop(original: first, film: .portra400, shot: doubleShot(second: second),
                                           frameIndex: 0, dateStamp: false)
        let print = try XCTUnwrap(CIImage(data: data))
        let centre = print.extent.insetBy(dx: print.extent.width * 0.4, dy: print.extent.height * 0.4)
        let c = PixelReader.average(print, in: centre)
        XCTAssertGreaterThan(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b, 255 * 0.15)
    }

    func testDoubleOfTheSameFramePrintsLikeTheSingleExposure() throws {
        let url = try original(width: 900, height: 600, orientation: .up)
        var single = shot()
        single.sceneEV100 = 12
        var double = single
        double.second = Roll.Shot.Second(file: url.lastPathComponent, flash: false, sceneEV100: 12)
        let developer = Developer()
        let one = try XCTUnwrap(CIImage(data: developer.develop(original: url, film: .portra400, shot: single, frameIndex: 0, dateStamp: false)))
        let two = try XCTUnwrap(CIImage(data: developer.develop(original: url, film: .portra400, shot: double, frameIndex: 0, dateStamp: false)))
        let area = one.extent.insetBy(dx: one.extent.width * 0.3, dy: one.extent.height * 0.3)
        let a = PixelReader.average(one, in: area), b = PixelReader.average(two, in: area)
        XCTAssertEqual(a.r, b.r, accuracy: 3)
        XCTAssertEqual(a.g, b.g, accuracy: 3)
        XCTAssertEqual(a.b, b.b, accuracy: 3)
    }

    func testPrintNamesTheCameraAndFilm() throws {
        let url = try original(width: 900, height: 600, orientation: .up,
                                exif: [kCGImagePropertyExifISOSpeedRatings: [200], kCGImagePropertyExifFNumber: 1.6,
                                       kCGImagePropertyExifExposureTime: 1.0 / 120])
        let data = try Developer().develop(original: url, film: .portra400, shot: shot(), frameIndex: 0, dateStamp: false)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let tiff = try XCTUnwrap(props[kCGImagePropertyTIFFDictionary] as? [CFString: Any])
        let exif = try XCTUnwrap(props[kCGImagePropertyExifDictionary] as? [CFString: Any])
        XCTAssertEqual(tiff[kCGImagePropertyTIFFMake] as? String, "Plasticc")
        XCTAssertEqual(tiff[kCGImagePropertyTIFFModel] as? String, "Snappy 35")
        XCTAssertEqual(exif[kCGImagePropertyExifLensModel] as? String, "Honey 400")
        XCTAssertEqual(exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], [200])
        XCTAssertEqual(exif[kCGImagePropertyExifFNumber] as? Double, 1.6)
    }

    func testEachFormatPrintsInItsShape() throws {
        // A phone held upright: a 4:3 sensor frame tagged "rotate 90".
        let url = try original(width: 8064, height: 6048, orientation: .right)
        for (format, ratio) in [(PrintFormat.classic, 2.0 / 3.0), (.phone, 3.0 / 4.0), (.square, 1.0)] {
            let data = try Developer().develop(original: url, film: .superia400, shot: shot(), frameIndex: 1, dateStamp: true,
                                               format: format)
            let s = try size(of: data)
            XCTAssertEqual(s.width / s.height, ratio, accuracy: 0.002, format.rawValue)
        }
        let blank = try Developer().blankPrint(film: .hp5, shot: shot(), frameIndex: 0, format: .square)
        let b = try size(of: blank)
        XCTAssertEqual(b.width, b.height)
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

final class ScanLevelsTests: XCTestCase {
    func testAFlatFrameIsStretchedButNotPastTheLimit() {
        let flat = ScanLevels(darkest: 0.25, brightest: 0.75)
        XCTAssertEqual(flat.black, 0.22, accuracy: 0.001)
        XCTAssertEqual(flat.gain, 1.5, accuracy: 0.001, "a scanner stretches at most one and a half times")
    }

    func testAFullRangeFrameGetsSoftPaperWhitesAndBlacks() {
        let full = ScanLevels(darkest: 0.0, brightest: 1.0)
        XCTAssertLessThan(full.gain, 1, "whites come in from digital white")
        XCTAssertGreaterThanOrEqual(full.gain, 0.85)
        XCTAssertLessThan(full.black, 0, "blacks lift off digital black")
    }
}
