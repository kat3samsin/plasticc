import XCTest
@testable import PlasticcCore

/// Each film's signature, measured on ColorChecker patches (sRGB 8-bit values). Ranges, not exact numbers,
/// so the looks can be retuned without rewriting the tests.
final class FilmCharacterTests: XCTestCase {
    static let patches: [String: SIMD3<Double>] = [
        "darkSkin": SIMD3(115, 82, 68), "lightSkin": SIMD3(194, 150, 130), "blueSky": SIMD3(98, 122, 157),
        "foliage": SIMD3(87, 108, 67), "blueFlower": SIMD3(133, 128, 177), "bluishGreen": SIMD3(103, 189, 170),
        "orange": SIMD3(214, 126, 44), "purplishBlue": SIMD3(80, 91, 166), "moderateRed": SIMD3(193, 90, 99),
        "purple": SIMD3(94, 60, 108), "yellowGreen": SIMD3(157, 188, 64), "orangeYellow": SIMD3(224, 163, 46),
        "blue": SIMD3(56, 61, 150), "green": SIMD3(70, 148, 73), "red": SIMD3(175, 54, 60),
        "yellow": SIMD3(231, 199, 31), "magenta": SIMD3(187, 86, 149), "cyan": SIMD3(8, 133, 161),
    ].mapValues { $0 / 255 }

    func lch(_ c: SIMD3<Double>) -> SIMD3<Double> { Color.oklch(fromLinear: Color.decode(c)) }

    func chromaRatio(_ film: FilmStock, _ patch: String) -> Double {
        let c = Self.patches[patch]!
        return lch(film.look.apply(c)).y / lch(c).y
    }

    func hueShift(_ film: FilmStock, _ patch: String) -> Double {
        let c = Self.patches[patch]!
        var d = lch(film.look.apply(c)).z - lch(c).z
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    func meanChroma(_ film: FilmStock) -> Double {
        Self.patches.keys.map { chromaRatio(film, $0) }.reduce(0, +) / Double(Self.patches.count)
    }

    func testSuperiaIsPunchierThanPortraButNotGaudy() {
        // Superia pushed toward the rich colour of Lomography community scans; Portra kept soft and pastel.
        XCTAssertEqual(meanChroma(.superia400), 1.34, accuracy: 0.08)
        XCTAssertEqual(meanChroma(.portra400), 0.96, accuracy: 0.08)
        XCTAssertGreaterThan(meanChroma(.superia400), meanChroma(.portra400) + 0.04)
    }

    func testSuperiaGreensAreRichAndLeanTeal() {
        for patch in ["green", "foliage"] {
            XCTAssertGreaterThan(chromaRatio(.superia400, patch), 1.1, patch)
            XCTAssertGreaterThan(hueShift(.superia400, patch), 4, patch)
        }
    }

    func testPortraSkinLeansWarmAndItsGreensAndBluesAreSoft() {
        XCTAssertGreaterThan(hueShift(.portra400, "lightSkin"), 1)
        XCTAssertLessThan(chromaRatio(.portra400, "green"), chromaRatio(.superia400, "green") - 0.1)
        XCTAssertLessThan(chromaRatio(.portra400, "blueSky"), chromaRatio(.superia400, "blueSky"))
    }

    func testEktarIsTheMostColourful() {
        XCTAssertGreaterThan(meanChroma(.ektar100), meanChroma(.superia400) + 0.05)
        XCTAssertGreaterThan(chromaRatio(.ektar100, "red"), 1.25)
        XCTAssertGreaterThan(chromaRatio(.ektar100, "blueSky"), 1.25)
    }

    func testSkinKeepsItsHueOnSuperia() {
        XCTAssertLessThan(abs(hueShift(.superia400, "lightSkin")), 4)
    }

    func testHP5KeepsMidGreyAndOpenShadows() {
        let look = FilmStock.hp5.look
        XCTAssertEqual(look.apply(SIMD3(repeating: 0.46)).x, 0.47, accuracy: 0.05)
        XCTAssertGreaterThan(look.apply(SIMD3(repeating: 0.1)).x, 0.05, "shadows stay open, not crushed")
    }
}
