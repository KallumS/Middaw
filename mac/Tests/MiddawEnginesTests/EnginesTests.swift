import XCTest
import MiddawCore
@testable import MiddawEngines

/// The family's engines through JavaScriptCore, as the app calls them.
final class EnginesTests: XCTestCase {
    static var shared: Engines?
    var engines: Engines {
        get throws {
            if let e = EnginesTests.shared { return e }
            let e = try Engines(root: Engines.defaultRoot())
            EnginesTests.shared = e
            return e
        }
    }

    func testEveryGeneratorIsOffered() throws {
        let ids = try engines.generators().map(\.id)
        for id in ["good-idea", "midi-suggester", "midi-variator", "starting-blocks", "midi-catalogue"] {
            XCTAssertTrue(ids.contains(id), id)
        }
    }

    func testStartingBlocksGivesABlockPerDegree() throws {
        let p = Project()
        let s = try engines.session("starting-blocks")
        try s.useKey(p.key)
        let r = try s.generate(Engines.Context(project: p, instrument: "pno", bars: 1), seed: 1, count: 12)
        XCTAssertEqual(r.results.count, 7)
        XCTAssertGreaterThanOrEqual(r.results[0].notes.count, 3)
    }

    func testGoodIdeaIsTheSameForTheSameNumber() throws {
        let ctx = Engines.Context(project: Project(), instrument: "pno", bars: 4)
        let a = try engines.session("good-idea").generate(ctx, seed: 4182, count: 2)
        let b = try engines.session("good-idea").generate(ctx, seed: 4182, count: 2)
        XCTAssertEqual(a.results, b.results)
        XCTAssertFalse(a.results.isEmpty)
    }

    func testChordsAreNamedByScaleView() throws {
        let c = Key(root: 1, scale: 1)
        XCTAssertEqual(try engines.nameChord([60, 64, 67, 70], in: c), "C7")
        XCTAssertEqual(try engines.nameChord([57, 60, 64], in: c), "Amin")
        XCTAssertEqual(try engines.noteNames(Key(root: 16, scale: 1))[10], "Bb")
    }

    func testTheOrchestraLoads() throws {
        let list = try engines.instruments()
        XCTAssertGreaterThan(list.count, 25)
        XCTAssertEqual(list.first { $0.id == "vln1" }?.low, 55)
    }

    func testAPartIsEngraved() throws {
        let notes = (0..<4).map { Note(start: Double($0), len: 1, pitch: 60 + 2 * $0) }
        let e = try engines.engrave(notes: notes, beats: 4, project: Project(), drums: false, width: 60, space: 8)
        XCTAssertGreaterThan(e.height, 0)
        XCTAssertTrue(e.ops.contains { if case .text(let s) = $0.first ?? .other { return s == "line" }; return false })
    }

    func testAutoCCDrawsDynamicsFromItsOwnJSFX() throws {
        let notes = (0..<4).map { Note(start: Double($0), len: 0.9, pitch: 60 + $0, vel: 60 + 15 * $0) }
        let lanes = try engines.autoCC(notes: notes, length: 4, project: Project(tempo: 100), sliders: [1: 1])
        XCTAssertFalse(lanes.isEmpty)
        for pts in lanes.values { XCTAssertTrue(pts.allSatisfy { $0.beat >= 0 && $0.beat <= 4 && (0...127).contains($0.value) }) }
    }

    /// Strings the engines pass through intact, accents and all - JavaScriptCore
    /// has no TextDecoder of its own.
    func testUnicodeCrossesTheBridge() throws {
        let names = try engines.instruments().map(\.name)
        XCTAssertFalse(names.isEmpty)
        let o = try engines.callAny("orchestration", [String: Int]()) as? [String: Any]
        let entries = o?["entries"] as? [[String: Any]] ?? []
        XCTAssertTrue(entries.contains { ($0["summary"] as? String ?? "").contains("—") || ($0["summary"] as? String ?? "").contains("é") })
    }

    func testAnEngineErrorIsAnErrorNotACrash() throws {
        XCTAssertThrowsError(try engines.session("no-such-generator"))
    }
}
