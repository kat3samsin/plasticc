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
        let url = try original(width: 4032, height: 3024, orientation: .right)
        let data = try Developer().develop(original: url, film: .superia400, shot: shot(), frameIndex: 3, dateStamp: true)
        let s = try size(of: data)
        XCTAssertEqual(s.height, Developer.scanLongEdge)
        XCTAssertEqual(s.width / s.height, 2.0 / 3.0, accuracy: 0.002)
    }

    func testSidewaysShotBecomesALandscapePrint() throws {
        let url = try original(width: 4032, height: 3024, orientation: .up)
        let data = try Developer().develop(original: url, film: .hp5, shot: shot(flash: true), frameIndex: 0, dateStamp: false)
        let s = try size(of: data)
        XCTAssertEqual(s.width, Developer.scanLongEdge)
        XCTAssertEqual(s.width / s.height, 3.0 / 2.0, accuracy: 0.002)
    }

    func testSmallOriginalsAreNotUpscaled() throws {
        let url = try original(width: 900, height: 600, orientation: .up)
        let data = try Developer().develop(original: url, film: .portra800, shot: shot(), frameIndex: 5, dateStamp: true)
        XCTAssertEqual(try size(of: data), CGSize(width: 900, height: 600))
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
