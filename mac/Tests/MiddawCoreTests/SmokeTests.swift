import XCTest
@testable import MiddawCore

final class SmokeTests: XCTestCase {
    func testName() { XCTAssertEqual(Middaw.name, "Middaw") }
}
