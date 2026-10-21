import XCTest
@testable import PlasticcCore

final class RollLengthTests: XCTestCase {
    func testLengthsAreThreeForTestingThenTwelveTwentyFourThirtySix() {
        XCTAssertEqual(RollLength.allCases.map(\.exposures), [3, 12, 24, 36])
    }
}
