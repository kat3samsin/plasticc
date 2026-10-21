import CoreImage
import XCTest
@testable import PlasticcCore

final class FilmEngineTests: XCTestCase {
    let engine = FilmEngine()
    let scene = TestImages.scene(width: 400, height: 600)
    let date = Date(timeIntervalSince1970: 1_790_000_000)

    /// A seed whose frame never leaks past the first two frames, so tests can compare looks alone.
    func quietSeed(_ film: FilmStock, from start: UInt64 = 1) -> UInt64 {
        var seed = start
        while FilmEngine.leakFires(film: film, seed: seed, frameIndex: 5) { seed += 1 }
        return seed
    }

    func develop(_ image: CIImage, _ film: FilmStock, seed: UInt64? = nil, frame: Int = 5, flash: Bool = false, date: Date? = nil) -> CIImage {
        engine.develop(image, film: film, seed: seed ?? quietSeed(film), frameIndex: frame, flash: flash, date: date)
    }

    func testCropsToATwoByThreePrintEitherWay() {
        let portrait = FilmEngine.cropToPrint(TestImages.solid(.gray, width: 3024, height: 4032)).extent
        XCTAssertEqual(portrait, CGRect(x: 0, y: 0, width: 2688, height: 4032))
        let landscape = FilmEngine.cropToPrint(TestImages.solid(.gray, width: 4032, height: 3024)).extent
        XCTAssertEqual(landscape, CGRect(x: 0, y: 0, width: 4032, height: 2688))
        let tall = FilmEngine.cropToPrint(TestImages.solid(.gray, width: 1000, height: 2000)).extent
        XCTAssertEqual(tall, CGRect(x: 0, y: 0, width: 1000, height: 1500))
    }

    func testPrintKeepsTheCroppedExtentForEveryFilm() {
        for film in FilmStock.all {
            XCTAssertEqual(develop(scene, film).extent, CGRect(x: 0, y: 0, width: 400, height: 600), film.id)
        }
    }

    func testSameSeedGivesTheSamePrint() {
        for film in FilmStock.all {
            let a = PixelReader.rgba(develop(scene, film, seed: 42, frame: 0, flash: true, date: date))
            let b = PixelReader.rgba(develop(scene, film, seed: 42, frame: 0, flash: true, date: date))
            XCTAssertEqual(a, b, film.id)
        }
    }

    func testDifferentSeedsGiveDifferentGrain() {
        let film = FilmStock.portra400
        let a = PixelReader.rgba(develop(scene, film, seed: quietSeed(film, from: 1)))
        let b = PixelReader.rgba(develop(scene, film, seed: quietSeed(film, from: 1000)))
        XCTAssertNotEqual(a, b)
    }

    func testEachFilmLooksDifferent() {
        let prints = FilmStock.all.map { PixelReader.rgba(develop(scene, $0, seed: 7)) }
        XCTAssertNotEqual(prints[0], prints[1])
        XCTAssertNotEqual(prints[1], prints[2])
        XCTAssertNotEqual(prints[0], prints[2])
    }

    func testHP5IsBlackAndWhite() {
        let center = CGRect(x: 150, y: 250, width: 100, height: 100)
        let colour = TestImages.solid(CIColor(red: 0.8, green: 0.3, blue: 0.2), width: 400, height: 600)
        let px = PixelReader.average(develop(colour, .hp5), in: center)
        XCTAssertEqual(px.r, px.g, accuracy: 2)
        XCTAssertEqual(px.g, px.b, accuracy: 2)
    }

    func testHP5RendersRedsDarkerThanBlues() {
        let center = CGRect(x: 150, y: 250, width: 100, height: 100)
        func level(_ c: CIColor) -> Double {
            PixelReader.average(develop(TestImages.solid(c, width: 400, height: 600), .hp5), in: center).g
        }
        XCTAssertLessThan(level(CIColor(red: 0.8, green: 0.2, blue: 0.2)), level(CIColor(red: 0.2, green: 0.2, blue: 0.8)) + 40)
        XCTAssertGreaterThan(level(CIColor(red: 0.2, green: 0.2, blue: 0.8)), level(CIColor(red: 0.2, green: 0.2, blue: 0.2)))
    }

    func testPortraWarmsAGreyAndSuperiaDoesNot() {
        let center = CGRect(x: 150, y: 250, width: 100, height: 100)
        let grey = TestImages.solid(CIColor(red: 0.5, green: 0.5, blue: 0.5), width: 400, height: 600)
        let portra = PixelReader.average(develop(grey, .portra400), in: center)
        let superia = PixelReader.average(develop(grey, .superia400), in: center)
        XCTAssertGreaterThan(portra.r - portra.b, 8)
        XCTAssertGreaterThan(portra.r - portra.b, superia.r - superia.b + 5)
    }

    func testVignetteDarkensTheCorners() {
        let flat = TestImages.solid(CIColor(red: 0.6, green: 0.6, blue: 0.6), width: 400, height: 600)
        let out = develop(flat, .superia400)
        let corner = PixelReader.average(out, in: CGRect(x: 0, y: 0, width: 40, height: 40)).g
        let center = PixelReader.average(out, in: CGRect(x: 180, y: 280, width: 40, height: 40)).g
        // A very light vignette: the corners only just darker.
        XCTAssertLessThan(corner, center - 4)
    }

    func testFlashBrightensTheMiddleMoreThanTheEdges() {
        let dim = TestImages.solid(CIColor(red: 0.15, green: 0.15, blue: 0.15), width: 400, height: 600)
        let film = FilmStock.superia400
        let without = develop(dim, film)
        let with = develop(dim, film, flash: true)
        let mid = CGRect(x: 170, y: 290, width: 60, height: 60), edge = CGRect(x: 0, y: 270, width: 30, height: 60)
        let midGain = PixelReader.average(with, in: mid).g - PixelReader.average(without, in: mid).g
        let edgeGain = PixelReader.average(with, in: edge).g - PixelReader.average(without, in: edge).g
        XCTAssertGreaterThan(midGain, 10)
        XCTAssertGreaterThan(midGain, edgeGain + 8)
    }

    func testFirstFramesLeakMoreOften() {
        let film = FilmStock.superia400
        func leaks(_ frame: Int) -> Int { (0..<2000).filter { FilmEngine.leakFires(film: film, seed: UInt64($0), frameIndex: frame) }.count }
        let first = leaks(0), second = leaks(1), later = leaks(10)
        XCTAssertGreaterThan(first, second)
        XCTAssertGreaterThan(second, later)
        XCTAssertEqual(Double(later) / 2000, film.leakChance, accuracy: 0.03)
    }

    func testLeakIsWarmOnColourFilmAndNeutralOnHP5() {
        func leakSeed(_ film: FilmStock) -> UInt64 {
            var s: UInt64 = 1
            while !FilmEngine.leakFires(film: film, seed: s, frameIndex: 5) { s += 1 }
            return s
        }
        let dark = TestImages.solid(CIColor(red: 0.1, green: 0.1, blue: 0.1), width: 400, height: 600)
        func cast(_ film: FilmStock) -> Double {
            let seed = leakSeed(film)
            let with = PixelReader.rgba(develop(dark, film, seed: seed))
            let without = PixelReader.rgba(develop(dark, film, seed: quietSeed(film)))
            // The biggest red-minus-blue gain anywhere the leak brightened the frame.
            var best = 0.0
            for i in stride(from: 0, to: with.count, by: 4 * 37) {
                let dr = Double(with[i]) - Double(without[i]), db = Double(with[i + 2]) - Double(without[i + 2])
                if dr > 20 { best = max(best, dr - db) }
            }
            return best
        }
        XCTAssertGreaterThan(cast(.superia400), 20)
        XCTAssertLessThan(cast(.hp5), 6)
    }

    func testDateStampOnlyWhenADateIsGiven() {
        let dark = TestImages.solid(CIColor(red: 0.1, green: 0.1, blue: 0.1), width: 400, height: 600)
        let film = FilmStock.portra400
        // On a portrait frame the stamp runs down the lower left, as on a camera turned on its side.
        let region = CGRect(x: 10, y: 30, width: 40, height: 180)
        let stamped = PixelReader.average(develop(dark, film, date: date), in: region)
        let plain = PixelReader.average(develop(dark, film), in: region)
        XCTAssertGreaterThan(stamped.r - plain.r, 2)
        XCTAssertGreaterThan(stamped.r - plain.r, (stamped.b - plain.b) * 1.5)
        let corner = CGRect(x: 250, y: 0, width: 150, height: 60)
        XCTAssertEqual(PixelReader.average(develop(dark, film, date: date), in: corner).r,
                       PixelReader.average(develop(dark, film), in: corner).r, accuracy: 1.5, "not in the bottom-right corner")
    }
}

final class DisposableExposureTests: XCTestCase {
    func testDaylightIsAboutRight() {
        // Bright overcast to sun, EV 12–15: negative film soaks it up.
        for ev in [11.3, 12.0, 15.0] {
            let stops = FilmEngine.disposableExposure(sceneEV100: ev, flash: false)
            XCTAssertEqual(stops, -0.5)
        }
    }

    func testIndoorsWithoutFlashGoesDark() {
        // A lit room is about EV 7.
        XCTAssertLessThan(FilmEngine.disposableExposure(sceneEV100: 7, flash: false), -1.5)
    }

    func testFlashRescuesADimRoom() {
        let without = FilmEngine.disposableExposure(sceneEV100: 6, flash: false)
        let with = FilmEngine.disposableExposure(sceneEV100: 6, flash: true)
        XCTAssertGreaterThan(with, without + 1.5)
        XCTAssertGreaterThanOrEqual(with, -0.9)
    }

    func testNeverDarkerThanTheScannerCanPrint() {
        XCTAssertEqual(FilmEngine.disposableExposure(sceneEV100: -2, flash: false), -2.6)
    }

    func testDarkerExposureMeansMoreGrain() {
        let engine = FilmEngine()
        let grey = TestImages.solid(CIColor(red: 0.5, green: 0.5, blue: 0.5), width: 300, height: 450)
        func spread(_ exposure: Double) -> Double {
            let px = PixelReader.rgba(engine.develop(grey, film: .hp5, seed: 3, frameIndex: 9, flash: false, date: nil, exposure: exposure)
                .cropped(to: CGRect(x: 100, y: 175, width: 100, height: 100)))
            let g = stride(from: 1, to: px.count, by: 4).map { Double(px[$0]) }
            let mean = g.reduce(0, +) / Double(g.count)
            return (g.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(g.count)).squareRoot() / max(mean, 1)
        }
        XCTAssertGreaterThan(spread(-2), spread(0))
        XCTAssertLessThan(spread(0.3), spread(0), "a bright, well-exposed frame prints finer")
    }
}

final class LightLeakPlacementTests: XCTestCase {
    /// Leaks land on every side of the frame across seeds, not always the same corner.
    func testLeaksLandOnDifferentSides() {
        let engine = FilmEngine()
        let film = FilmStock.superia400
        let dark = TestImages.solid(CIColor(red: 0.05, green: 0.05, blue: 0.05), width: 120, height: 180)
        var sides = Set<String>()
        var seed: UInt64 = 1
        while sides.count < 4, seed < 400 {
            defer { seed += 1 }
            guard FilmEngine.leakFires(film: film, seed: seed, frameIndex: 9) else { continue }
            let img = engine.develop(dark, film: film, seed: seed, frameIndex: 9, flash: false, date: nil)
            func red(_ r: CGRect) -> Double { PixelReader.average(img, in: r).r }
            let edges = ["left": red(CGRect(x: 0, y: 30, width: 12, height: 120)), "right": red(CGRect(x: 108, y: 30, width: 12, height: 120)),
                         "bottom": red(CGRect(x: 20, y: 0, width: 80, height: 12)), "top": red(CGRect(x: 20, y: 168, width: 80, height: 12))]
            sides.insert(edges.max { $0.value < $1.value }!.key)
        }
        XCTAssertEqual(sides.count, 4, "leak sides seen: \(sides)")
    }
}

final class GrainStrengthTests: XCTestCase {
    /// RMS difference in green levels between two renders of the same patch, with and without grain.
    func grainRMS(_ film: FilmStock, level: CGFloat) -> Double {
        let engine = FilmEngine()
        let size = CGSize(width: 2058, height: 3088)
        let patch = TestImages.solid(CIColor(red: level, green: level, blue: level), width: size.width, height: size.height)
        let plain = FilmStock(id: film.id, name: film.name, look: film.look,
                          grain: .init(rms: 0, size: film.grain.size, chroma: 0, underexposure: 0),
                          halation: film.halation, leakTones: film.leakTones, leakChance: 0, vignette: film.vignette, softness: film.softness)
        let quiet = FilmStock(id: film.id, name: film.name, look: film.look, grain: film.grain,
                          halation: film.halation, leakTones: film.leakTones, leakChance: 0, vignette: film.vignette, softness: film.softness)
        let middle = CGRect(x: 900, y: 1400, width: 256, height: 256)
        let a = PixelReader.rgba(engine.develop(patch, film: quiet, seed: 5, frameIndex: 9, flash: false, date: nil).cropped(to: middle))
        let b = PixelReader.rgba(engine.develop(patch, film: plain, seed: 5, frameIndex: 9, flash: false, date: nil).cropped(to: middle))
        let diffs = stride(from: 1, to: a.count, by: 4).map { Double(Int(a[$0]) - Int(b[$0])) }
        return (diffs.map { $0 * $0 }.reduce(0, +) / Double(diffs.count)).squareRoot()
    }

    func testMidtoneGrainIsNearTheResearchedStrength() {
        for film in FilmStock.all {
            let rms = grainRMS(film, level: 0.45)
            XCTAssertEqual(rms, film.grain.rms, accuracy: film.grain.rms * 0.5, film.id)
        }
    }

    func testHighlightsAreLessGrainyThanMidtones() {
        for film in FilmStock.all {
            XCTAssertLessThan(grainRMS(film, level: 0.95), grainRMS(film, level: 0.45) * 0.7, film.id)
        }
    }
}

final class DustTests: XCTestCase {
    func testDustIsFaintFewAndRepeatable() {
        let grey = TestImages.solid(CIColor(red: 0.4, green: 0.4, blue: 0.4), width: 600, height: 900)
        let a = PixelReader.rgba(Dust.apply(to: grey, seed: 11, scale: 0.9))
        XCTAssertEqual(a, PixelReader.rgba(Dust.apply(to: grey, seed: 11, scale: 0.9)), "same seed, same dust")
        let base = PixelReader.rgba(grey)
        let marked = stride(from: 0, to: a.count, by: 4).filter { Int(a[$0]) - Int(base[$0]) > 6 }.count
        XCTAssertGreaterThan(marked, 0)
        XCTAssertLessThan(Double(marked) / Double(a.count / 4), 0.004, "a few specks, not a haze")
    }
}

final class DateStampVisibilityTests: XCTestCase {
    func testStampShowsRedOnAWhiteWall() {
        let white = TestImages.solid(CIColor(red: 0.95, green: 0.95, blue: 0.95), width: 400, height: 600)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let stamped = DateStamp.apply(to: white, date: date, seed: 1)
        let px = PixelReader.rgba(stamped.cropped(to: CGRect(x: 10, y: 30, width: 40, height: 180)))
        let reddest = stride(from: 0, to: px.count, by: 4).map { Int(px[$0]) - Int(px[$0 + 2]) }.max() ?? 0
        XCTAssertGreaterThan(reddest, 60, "the digits read as red-orange, not white on white")
    }
}
