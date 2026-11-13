import XCTest
@testable import PlasticcCore

final class RollTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func loadedRoll(_ length: RollLength = .short) throws -> Roll {
        var roll = Roll(filmID: "superia400", length: length)
        try roll.tear()
        try roll.load()
        return roll
    }

    func shoot(_ roll: inout Roll, _ count: Int) throws {
        for i in 0..<count {
            try roll.wind()
            try roll.shoot(file: "\(i).jpg", takenAt: t0, flash: false, seed: UInt64(i))
        }
    }

    func testFullRollFromSealedToDone() throws {
        var roll = Roll(filmID: "hp5", length: .short)
        XCTAssertEqual(roll.phase, .sealed)
        try roll.tear()
        XCTAssertEqual(roll.phase, .unwrapped)
        try roll.load()
        XCTAssertEqual(roll.phase, .loaded)
        try shoot(&roll, 12)
        XCTAssertEqual(roll.phase, .rewinding)
        XCTAssertEqual(roll.remaining, 0)
        try roll.rewind(readyAt: t0)
        XCTAssertEqual(roll.phase, .developing)
        for i in 0..<12 { try roll.markDeveloped(index: i, file: "\(i)-dev.jpg") }
        XCTAssertEqual(roll.phase, .developed)
        for i in 0..<12 { try roll.review(index: i, verdict: i.isMultiple(of: 2) ? .keep : .trash) }
        XCTAssertEqual(roll.phase, .done)
    }

    func testEveryLengthRewindsAfterItsLastFrame() throws {
        for length in RollLength.allCases {
            var roll = try loadedRoll(length)
            try shoot(&roll, length.exposures - 1)
            XCTAssertEqual(roll.phase, .shooting)
            XCTAssertEqual(roll.remaining, 1)
            try shoot(&roll, 1)
            XCTAssertEqual(roll.phase, .rewinding)
        }
    }

    func testStepsCannotBeSkipped() throws {
        var sealed = Roll(filmID: "hp5", length: .short)
        XCTAssertThrowsError(try sealed.load()) { XCTAssertEqual($0 as? RollError, .wrongPhase(.sealed)) }
        XCTAssertThrowsError(try sealed.wind()) { XCTAssertEqual($0 as? RollError, .wrongPhase(.sealed)) }
        try sealed.tear()
        XCTAssertThrowsError(try sealed.tear()) { XCTAssertEqual($0 as? RollError, .wrongPhase(.unwrapped)) }
        XCTAssertThrowsError(try sealed.wind()) { XCTAssertEqual($0 as? RollError, .wrongPhase(.unwrapped)) }
    }

    func testLoadedRollCannotShootBeforeTheFirstWind() throws {
        var roll = try loadedRoll()
        XCTAssertThrowsError(try roll.shoot(file: "a.jpg", takenAt: t0, flash: false, seed: 0)) {
            XCTAssertEqual($0 as? RollError, .wrongPhase(.loaded))
        }
    }

    func testShutterNeedsAWindBetweenFrames() throws {
        var roll = try loadedRoll()
        try shoot(&roll, 1)
        XCTAssertFalse(roll.wound)
        XCTAssertThrowsError(try roll.shoot(file: "b.jpg", takenAt: t0, flash: false, seed: 0)) {
            XCTAssertEqual($0 as? RollError, .notWound)
        }
        try roll.wind()
        XCTAssertTrue(roll.wound)
        XCTAssertThrowsError(try roll.wind()) { XCTAssertEqual($0 as? RollError, .alreadyWound) }
        XCTAssertEqual(roll.shots.count, 1)
    }

    func testFullRollRefusesAnotherWindOrShot() throws {
        var roll = try loadedRoll()
        try shoot(&roll, 12)
        XCTAssertThrowsError(try roll.wind()) { XCTAssertEqual($0 as? RollError, .wrongPhase(.rewinding)) }
        XCTAssertThrowsError(try roll.shoot(file: "x.jpg", takenAt: t0, flash: false, seed: 0))
        XCTAssertEqual(roll.shots.count, 12)
    }

    func testRewindOnlyWhenTheRollIsFull() throws {
        var roll = try loadedRoll()
        try shoot(&roll, 11)
        XCTAssertThrowsError(try roll.rewind(readyAt: t0)) { XCTAssertEqual($0 as? RollError, .wrongPhase(.shooting)) }
    }

    func testReadyOnlyOnceReadyAtHasPassed() throws {
        var roll = try loadedRoll()
        XCTAssertFalse(roll.isReady(at: t0))
        try shoot(&roll, 12)
        try roll.rewind(readyAt: t0.addingTimeInterval(3600))
        XCTAssertEqual(roll.readyAt, t0.addingTimeInterval(3600))
        XCTAssertFalse(roll.isReady(at: t0))
        XCTAssertTrue(roll.isReady(at: t0.addingTimeInterval(3600)))
    }

    func testDevelopAndReviewGuards() throws {
        var roll = try loadedRoll()
        try shoot(&roll, 12)
        XCTAssertThrowsError(try roll.markDeveloped(index: 0, file: "d.jpg")) {
            XCTAssertEqual($0 as? RollError, .wrongPhase(.rewinding))
        }
        try roll.rewind(readyAt: t0)
        XCTAssertThrowsError(try roll.markDeveloped(index: 12, file: "d.jpg")) { XCTAssertEqual($0 as? RollError, .noSuchShot) }
        XCTAssertThrowsError(try roll.review(index: 0, verdict: .keep)) {
            XCTAssertEqual($0 as? RollError, .wrongPhase(.developing))
        }
        for i in 0..<12 { try roll.markDeveloped(index: i, file: "\(i)-dev.jpg") }
        try roll.review(index: 3, verdict: .keep)
        XCTAssertThrowsError(try roll.review(index: 3, verdict: .trash)) { XCTAssertEqual($0 as? RollError, .alreadyReviewed) }
        XCTAssertEqual(roll.shots[3].verdict, .keep)
        XCTAssertEqual(roll.phase, .developed)
    }

    func testShotKeepsItsDetails() throws {
        var roll = try loadedRoll()
        try roll.wind()
        try roll.shoot(file: "001.jpg", takenAt: t0, flash: true, seed: 42)
        XCTAssertEqual(roll.shots.first, Roll.Shot(file: "001.jpg", takenAt: t0, flash: true, seed: 42))
    }

    func testDecodedRollResumesMidRoll() throws {
        var roll = try loadedRoll(.standard)
        try shoot(&roll, 5)
        try roll.wind()
        let decoded = try JSONDecoder().decode(Roll.self, from: JSONEncoder().encode(roll))
        XCTAssertEqual(decoded, roll)
        XCTAssertEqual(decoded.phase, .shooting)
        XCTAssertEqual(decoded.remaining, 19)
        XCTAssertTrue(decoded.wound)
    }

    func shootDouble(_ roll: inout Roll) throws {
        try roll.wind()
        try roll.shoot(file: "a.jpg", takenAt: t0, flash: false, seed: 1)
        try roll.setMulti(true)
        try roll.wind()
        try roll.shoot(file: "b.jpg", takenAt: t0, flash: true, seed: 2, sceneEV100: 9)
    }

    func testMultiPutsTwoExposuresOnOneFrame() throws {
        var roll = try loadedRoll(.test)
        try shootDouble(&roll)
        XCTAssertEqual(roll.shots.count, 1)
        XCTAssertEqual(roll.shots[0].second, Roll.Shot.Second(file: "b.jpg", flash: true, sceneEV100: 9))
        XCTAssertFalse(roll.multi)
        XCTAssertFalse(roll.wound)
        XCTAssertEqual(roll.phase, .shooting)
        XCTAssertEqual(roll.remaining, 2)
    }

    func testMultiWindDoesNotMoveTheFilmOn() throws {
        var roll = try loadedRoll(.test)
        try shoot(&roll, 1)
        try roll.setMulti(true)
        try roll.wind()
        XCTAssertEqual(roll.shots.count, 1)
        XCTAssertTrue(roll.wound)
        XCTAssertTrue(roll.multi)
    }

    func testMultiRefusedBeforeFirstExposureAndOnFullFrame() throws {
        var roll = try loadedRoll()
        XCTAssertThrowsError(try roll.setMulti(true))
        try roll.wind()
        XCTAssertThrowsError(try roll.setMulti(true), "the shutter is armed but nothing is shot yet")
        try roll.shoot(file: "a.jpg", takenAt: t0, flash: false, seed: 1)
        try roll.setMulti(true)
        try roll.wind()
        try roll.shoot(file: "b.jpg", takenAt: t0, flash: false, seed: 2)
        XCTAssertThrowsError(try roll.setMulti(true), "the frame already holds two exposures")
        try roll.wind()
        try roll.shoot(file: "c.jpg", takenAt: t0, flash: false, seed: 3)
        XCTAssertNoThrow(try roll.setMulti(true), "the next normal frame can take a second")
    }

    func testCanSetMultiMatchesSetMulti() throws {
        var roll = try loadedRoll()
        XCTAssertTrue(roll.shots.isEmpty)
        XCTAssertFalse(roll.canSetMulti(true), "no first exposure on a freshly loaded roll")
        XCTAssertTrue(roll.canSetMulti(false))
        try roll.wind()
        XCTAssertFalse(roll.canSetMulti(true))
        XCTAssertFalse(roll.canSetMulti(false), "the shutter is armed")
        try roll.shoot(file: "a.jpg", takenAt: t0, flash: false, seed: 1)
        XCTAssertTrue(roll.canSetMulti(true))
    }

    func testMultiCannotOutliveTheRoll() throws {
        var roll = try loadedRoll(.test)
        try shoot(&roll, 3)
        XCTAssertEqual(roll.phase, .rewinding)
        XCTAssertThrowsError(try roll.setMulti(true)) {
            XCTAssertEqual($0 as? RollError, .wrongPhase(.rewinding))
        }
    }

    func testMultiCanBeTurnedOffBeforeTheNextWind() throws {
        var roll = try loadedRoll(.test)
        try shoot(&roll, 1)
        try roll.setMulti(true)
        try roll.setMulti(false)
        XCTAssertEqual(roll, try { var r = try loadedRoll(.test); try shoot(&r, 1); return r }())
    }

    func testMultiSurvivesRelaunch() throws {
        var roll = try loadedRoll(.test)
        try shoot(&roll, 1)
        try roll.setMulti(true)
        let decoded = try JSONDecoder().decode(Roll.self, from: JSONEncoder().encode(roll))
        XCTAssertEqual(decoded, roll)
        XCTAssertTrue(decoded.multi)
        var double = try loadedRoll(.test)
        try shootDouble(&double)
        let again = try JSONDecoder().decode(Roll.self, from: JSONEncoder().encode(double))
        XCTAssertEqual(again.shots[0].second, double.shots[0].second)
    }

    func testOldRollWithoutSecondDecodes() throws {
        let json = """
        {"filmID":"superia400","length":12,"phase":"shooting","wound":false,
         "shots":[{"file":"001.jpg","takenAt":0,"flash":false,"seed":7}]}
        """
        let roll = try JSONDecoder().decode(Roll.self, from: Data(json.utf8))
        XCTAssertFalse(roll.multi)
        XCTAssertNil(roll.shots[0].second)
    }

    func testFilmsAreTheThreeStocks() {
        XCTAssertEqual(FilmStock.all.map(\.id), ["superia400", "portra400", "ektar100", "hp5"])
        XCTAssertEqual(FilmStock.with(id: "portra400"), .portra400)
        XCTAssertNil(FilmStock.with(id: "gold200"))
        XCTAssertEqual(FilmStock.with(id: "portra800"), .portra400, "old Portra 800 rolls develop as Portra 400")
    }
}
