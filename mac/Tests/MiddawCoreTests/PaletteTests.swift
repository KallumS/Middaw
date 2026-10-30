import XCTest
@testable import MiddawCore

/// The house scheme, measured: every word 7:1, every button's ink 7:1 on its
/// fill, the marks you follow or grab 3:1, the greys cool.
final class PaletteTests: XCTestCase {
    typealias P = HousePalette
    let grounds: [(String, UInt32)] = [("ground", P.ground), ("raised", P.raised), ("sunken", P.sunken), ("roll", P.roll)]

    func testEveryWordIsSevenToOneOnEverySurface() {
        for (name, word) in [("text", P.text), ("textDim", P.textDim), ("label", P.label), ("warnText", P.warnText)] {
            for (gname, g) in grounds {
                XCTAssertGreaterThanOrEqual(P.contrast(word, g), 7, "\(name) on \(gname)")
            }
        }
    }

    func testInkIsSevenToOneOnEveryButton() {
        for (name, fill) in [("control", P.control), ("controlHover", P.controlHover), ("accent", P.accent), ("accentHover", P.accentHover)] {
            XCTAssertGreaterThanOrEqual(P.contrast(P.ink, fill), 7, name)
        }
        XCTAssertGreaterThanOrEqual(P.contrast(P.ink, P.controlHeld), 4.5)
    }

    func testMarksYouFollowOrGrabAreThreeToOne() {
        for (name, mark) in [("playhead", P.playhead), ("edge", P.edge), ("control", P.control), ("accent", P.accent)] {
            XCTAssertGreaterThanOrEqual(P.contrast(mark, P.roll), 3, name)
        }
    }

    func testTheGreysAreCool() {
        for (name, c) in [("control", P.control), ("ground", P.ground), ("raised", P.raised), ("sunken", P.sunken), ("roll", P.roll),
                          ("rule", P.rule), ("edge", P.edge), ("ink", P.ink), ("text", P.text), ("textDim", P.textDim), ("label", P.label)] {
            let r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF
            XCTAssertTrue(r <= g && g <= b && r < b, name)
        }
    }

    /// The numbers are the ones docs/COLOUR.md publishes.
    func testTheDocumentedValuesAreTheOnesUsed() throws {
        let doc = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../docs/COLOUR.md").standardized, encoding: .utf8)
        for v in [P.accent, P.control, P.ground, P.ink, P.textDim, P.warnText, P.warn, P.raised] {
            XCTAssertTrue(doc.uppercased().contains(String(format: "#%06X", v)), String(format: "#%06X", v))
        }
    }
}
