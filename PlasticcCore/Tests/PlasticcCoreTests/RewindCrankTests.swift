import XCTest
@testable import PlasticcCore

final class RewindCrankTests: XCTestCase {
    let degree = Double.pi / 180

    /// Cranks in small steps and collects every event, like a finger moving round.
    func crankAll(_ crank: inout RewindCrank, step: Double = 2) -> [RewindCrank.Event] {
        var events: [RewindCrank.Event] = []
        for _ in 0..<10_000 where !crank.isDone {
            events += crank.turn(by: step * degree)
        }
        return events
    }

    func intensities(_ events: [RewindCrank.Event]) -> [Double] {
        events.compactMap { if case .tick(let i) = $0 { i } else { nil } }
    }

    func testLongerRollsTakeMoreTurns() {
        XCTAssertEqual(RewindCrank(exposures: 12).totalAngle, 1.5 * 2 * .pi, accuracy: 1e-9)
        XCTAssertEqual(RewindCrank(exposures: 24).totalAngle, 2 * 2 * .pi, accuracy: 1e-9)
        XCTAssertEqual(RewindCrank(exposures: 36).totalAngle, 2.5 * 2 * .pi, accuracy: 1e-9)
    }

    func testReleasesOnceAtTheEndAndThenGoesQuiet() {
        var crank = RewindCrank(exposures: 12)
        let events = crankAll(&crank)
        XCTAssertEqual(events.last, .released)
        XCTAssertEqual(events.filter { $0 == .released }.count, 1)
        XCTAssertTrue(crank.isDone)
        XCTAssertEqual(crank.progress, 1)
        XCTAssertEqual(crank.turn(by: .pi), [])
    }

    func testTicksGetCloserAndLighter() {
        var crank = RewindCrank(exposures: 24)
        var tickAngles: [Double] = []
        for _ in 0..<10_000 where !crank.isDone {
            if crank.turn(by: 1 * degree).contains(where: { if case .tick = $0 { true } else { false } }) {
                tickAngles.append(crank.angle)
            }
        }
        let gaps = zip(tickAngles.dropFirst(), tickAngles).map { $0 - $1 }
        XCTAssertGreaterThan(gaps.first!, 18 * degree)
        XCTAssertLessThan(gaps.last!, 12 * degree)

        var fresh = RewindCrank(exposures: 24)
        let levels = intensities(crankAll(&fresh))
        XCTAssertEqual(levels.first!, 1, accuracy: 0.05)
        XCTAssertLessThan(levels.last!, 0.4)
        XCTAssertEqual(levels, levels.sorted(by: >))
    }

    func testDirectionDoesNotMatter() {
        var forward = RewindCrank(exposures: 12)
        var backward = RewindCrank(exposures: 12)
        XCTAssertEqual(crankAll(&forward, step: 3), crankAll(&backward, step: -3))
    }

    func testOneBigJumpStillTicksEveryClick() {
        var crank = RewindCrank(exposures: 12)
        let events = crank.turn(by: 90 * degree)
        XCTAssertEqual(events.count, 4) // clicks at about 20°, 40°, 60° and 80°
        XCTAssertFalse(crank.isDone)
    }
}
