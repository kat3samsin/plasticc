import XCTest
@testable import PlasticcCore

final class DevelopTimeTests: XCTestCase {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func testInstantIsReadyNow() {
        XCTAssertEqual(DevelopTime.instant.readyAt(from: date(20, 15), calendar: calendar), date(20, 15))
    }

    func testHourIsAnHourLater() {
        XCTAssertEqual(DevelopTime.hour.readyAt(from: date(20, 15, 30), calendar: calendar), date(20, 16, 30))
    }

    func testNextMorningInTheAfternoonIsTomorrowAtNine() {
        XCTAssertEqual(DevelopTime.nextMorning.readyAt(from: date(20, 15), calendar: calendar), date(21, 9))
    }

    func testNextMorningBeforeNineIsThisMorning() {
        XCTAssertEqual(DevelopTime.nextMorning.readyAt(from: date(20, 2), calendar: calendar), date(20, 9))
    }

    func testNextMorningAtNineIsTomorrow() {
        XCTAssertEqual(DevelopTime.nextMorning.readyAt(from: date(20, 9), calendar: calendar), date(21, 9))
    }
}
