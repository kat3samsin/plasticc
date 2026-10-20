import XCTest
@testable import PlasticcCore

final class RollLengthTests: XCTestCase {
    func testLengthsAreTwelveTwentyFourThirtySix() {
        XCTAssertEqual(RollLength.allCases.map(\.exposures), [12, 24, 36])
    }
}
