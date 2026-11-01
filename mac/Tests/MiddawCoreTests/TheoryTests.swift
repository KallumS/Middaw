import XCTest
@testable import MiddawCore

final class TheoryTests: XCTestCase {
    /// Every root and scale spelled, signed and labelled as ScaleView's port does.
    func testEveryKeyMatchesThePythonReference() throws {
        let keys = try XCTUnwrap(Fixtures.json("keys.json") as? [[String: Any]])
        XCTAssertEqual(keys.count, 18 * 16)
        for k in keys {
            let key = Key(root: k["root"] as! Int, scale: k["scale"] as! Int)
            let label = k["label"] as! String
            XCTAssertEqual(key.label, label)
            XCTAssertEqual(key.names, k["names"] as! [String], label)
            let sig = key.signature
            XCTAssertEqual(sig.sharpsOrFlats, k["sharpsOrFlats"] as! Int, label)
            XCTAssertEqual(sig.minor ? 1 : 0, k["minor"] as! Int, label)
        }
    }

    func testKeyMembership() {
        let cMajor = Key(root: 1, scale: 1)
        XCTAssertTrue(cMajor.contains(60))
        XCTAssertFalse(cMajor.contains(61))
        XCTAssertEqual(Key(root: 16, scale: 2).displayName, "Bb Minor")
        XCTAssertEqual(Theory.noteName(60), "C4")
        XCTAssertEqual(Theory.noteName(70, in: Key(root: 16, scale: 1)), "Bb4")
    }
}
