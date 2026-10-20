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

    func testFilmsAreTheThreeStocks() {
        XCTAssertEqual(FilmStock.all.map(\.id), ["superia400", "portra800", "hp5"])
        XCTAssertEqual(FilmStock.with(id: "portra800"), .portra800)
        XCTAssertNil(FilmStock.with(id: "gold200"))
    }
}
