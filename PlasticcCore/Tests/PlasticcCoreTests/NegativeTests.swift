import CoreImage
import XCTest
@testable import PlasticcCore

final class NegativeTests: XCTestCase {
    let patch = CGRect(x: 10, y: 10, width: 40, height: 40)

    func negative(_ level: CGFloat, _ film: FilmStock) -> (r: Double, g: Double, b: Double) {
        let solid = TestImages.solid(CIColor(red: level, green: level, blue: level), width: 60, height: 60)
        return PixelReader.average(Negative.make(from: solid, film: film), in: patch)
    }

    func testBrightSceneIsDenseAndDarkSceneIsClear() {
        for film in FilmStock.all {
            XCTAssertLessThan(negative(0.95, film).g, negative(0.05, film).g, film.id)
        }
    }

    func testColourFilmSitsOnAnOrangeMask() {
        let mid = negative(0.5, .portra800)
        XCTAssertGreaterThan(mid.r, mid.g + 20)
        XCTAssertGreaterThan(mid.g, mid.b + 10)
    }

    func testBlackAndWhiteIsNeutral() {
        let mid = negative(0.5, .hp5)
        XCTAssertEqual(mid.r, mid.b, accuracy: 8)
    }
}
