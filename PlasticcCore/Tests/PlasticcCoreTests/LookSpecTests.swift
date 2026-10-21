import XCTest
@testable import PlasticcCore

final class LookSpecTests: XCTestCase {
    func grey(_ v: Double) -> SIMD3<Double> { SIMD3(repeating: v) }

    func lch(_ c: SIMD3<Double>) -> SIMD3<Double> { Color.oklch(fromLinear: Color.decode(c)) }

    func hueDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }

    func testOklabRoundTrips() {
        for c in [SIMD3(0.8, 0.2, 0.1), SIMD3(0.1, 0.6, 0.3), SIMD3(0.2, 0.3, 0.9), SIMD3(0.5, 0.5, 0.5)] {
            let back = Color.linear(fromOklch: Color.oklch(fromLinear: c))
            XCTAssertEqual(back.x, c.x, accuracy: 1e-6)
            XCTAssertEqual(back.y, c.y, accuracy: 1e-6)
            XCTAssertEqual(back.z, c.z, accuracy: 1e-6)
        }
    }

    func testNeutralSpecKeepsTheTonalRangeAndGreysNeutral() {
        let spec = LookSpec()
        XCTAssertEqual(spec.apply(grey(0.46)).y, 0.46, accuracy: 0.04, "mid-grey prints as mid-grey")
        XCTAssertLessThan(spec.apply(grey(0)).y, 0.02)
        XCTAssertGreaterThan(spec.apply(grey(1)).y, 0.97)
        let out = spec.apply(grey(0.3))
        XCTAssertEqual(out.x, out.z, accuracy: 0.002)
    }

    func testEveryFilmIsMonotonicAlongAGreyRamp() {
        for film in FilmStock.all {
            var last = -1.0
            for i in 0...40 {
                let y = (film.look.apply(grey(Double(i) / 40)) * SIMD3(0.2126, 0.7152, 0.0722)).sum()
                XCTAssertGreaterThanOrEqual(y, last - 1e-9, "\(film.id) at \(i)")
                last = y
            }
        }
    }

    func testSteeperBlueGivesCrossover() {
        var spec = LookSpec()
        spec.contrast = SIMD3(1, 1, 1.3)
        let dark = spec.apply(grey(0.18)), light = spec.apply(grey(0.82))
        XCTAssertLessThan(dark.z, dark.x, "shadows go warm")
        XCTAssertGreaterThan(light.z, light.x, "highlights go cool")
    }

    func testCurveOffsetMovesMidtonesButNotBlackOrWhite() {
        var spec = LookSpec()
        spec.curveOffset = SIMD3(0.3, 0, -0.3)
        let mid = spec.apply(grey(0.46))
        XCTAssertGreaterThan(mid.x, mid.z + 0.03)
        let white = spec.apply(grey(1)), black = spec.apply(grey(0))
        XCTAssertEqual(white.x, white.z, accuracy: 0.03)
        XCTAssertEqual(black.x, black.z, accuracy: 0.03)
    }

    func testHueSectorTurnsGreensTowardCyanOnly() {
        var spec = LookSpec()
        spec.saturationRolloff = 0
        spec.hueSectors = [.init(center: 145, width: 80, hueShift: 12)]
        let green = SIMD3(0.27, 0.58, 0.29), red = SIMD3(0.69, 0.21, 0.24)
        let base = LookSpec()
        XCTAssertGreaterThan(lch(spec.apply(green)).z - lch(base.apply(green)).z, 6)
        XCTAssertLessThan(hueDistance(lch(spec.apply(red)).z, lch(base.apply(red)).z), 0.5)
    }

    func testSaturationFallsInDeepShadows() {
        var spec = LookSpec()
        spec.saturationRolloff = 0.35
        let ratio = { (c: SIMD3<Double>) in self.lch(spec.apply(c)).y / self.lch(c).y }
        XCTAssertLessThan(ratio(SIMD3(0.12, 0.05, 0.04)), ratio(SIMD3(0.55, 0.3, 0.25)))
    }

    func testBrightSkinKeepsItsHueThroughTheHighlightRolloff() {
        var spec = LookSpec()
        spec.highlightRolloff = 0.2
        let skin = SIMD3(0.98, 0.86, 0.76)
        XCTAssertLessThan(hueDistance(lch(spec.apply(skin)).z, lch(LookSpec().apply(skin)).z), 3)
        XCTAssertLessThan(lch(spec.apply(skin)).x, lch(LookSpec().apply(skin)).x)
    }

    func testMonochromeIsGrey() {
        let out = FilmStock.hp5.look.apply(SIMD3(0.8, 0.3, 0.2))
        XCTAssertEqual(out.x, out.y, accuracy: 1e-9)
        XCTAssertEqual(out.y, out.z, accuracy: 1e-9)
    }
}
