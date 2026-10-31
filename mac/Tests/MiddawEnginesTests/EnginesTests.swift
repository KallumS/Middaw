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
        let text = String(decoding: try JSONSerialization.data(withJSONObject: entries), as: UTF8.self)
        XCTAssertTrue(text.contains("—") && text.contains("’"), "the guide's dashes and quotes arrive as themselves")
        XCTAssertFalse(text.contains("\u{FFFD}"), "nothing was decoded wrongly")
    }

    func testAnEngineErrorIsAnErrorNotACrash() throws {
        XCTAssertThrowsError(try engines.session("no-such-generator"))
    }
}

/// Compose without Python: runtime/composer/ in JavaScriptCore gives the
/// answer the Python composer gives for the same prompt and seed
/// (tools/make_swift_fixtures.py writes Python's).
final class ComposerTests: XCTestCase {
    struct Args: Encodable { let prompt: String; let seed: Int }

    /// Equal, with numbers to within a millionth: JavaScriptCore's sine and
    /// logarithm may differ from Python's in the last bit.
    func same(_ a: Any, _ b: Any, _ path: String = "") -> String? {
        switch (a, b) {
        case (let x as [String: Any], let y as [String: Any]):
            for k in Set(x.keys).union(y.keys).sorted() {
                guard let xv = x[k], let yv = y[k] else { return "\(path)/\(k) missing" }
                if let d = same(xv, yv, path + "/" + k) { return d }
            }
            return nil
        case (let x as [Any], let y as [Any]):
            guard x.count == y.count else { return "\(path): \(x.count) items against \(y.count)" }
            for (i, (xv, yv)) in zip(x, y).enumerated() { if let d = same(xv, yv, "\(path)[\(i)]") { return d } }
            return nil
        case (let x as String, let y as String):
            return x == y ? nil : "\(path): \(x) against \(y)"
        case (let x as NSNumber, let y as NSNumber):
            let p = x.doubleValue, q = y.doubleValue
            return abs(p - q) <= 1e-6 * max(1, abs(p), abs(q)) ? nil : "\(path): \(p) against \(q)"
        case (is NSNull, is NSNull):
            return nil
        default:
            return "\(path): \(a) against \(b)"
        }
    }

    func testComposeGivesWhatThePythonComposerGives() throws {
        let engines = try Engines(root: Engines.defaultRoot())
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../MiddawCoreTests/Fixtures/compositions.json")
        let cases = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [[String: Any]] ?? []
        XCTAssertFalse(cases.isEmpty)
        for c in cases {
            let prompt = c["prompt"] as? String ?? "", seed = (c["seed"] as? NSNumber)?.intValue ?? 0
            let got = try engines.callAny("compose", Args(prompt: prompt, seed: seed))
            XCTAssertNil(same(got, c["answer"] ?? NSNull()), prompt)
        }
    }

    func testTheAppReadsTheComposersAnswer() throws {
        let engines = try Engines(root: Engines.defaultRoot())
        struct Part: Decodable { let role: String; let notes: [Note] }
        struct Song: Decodable { let tracks: [Part] }
        struct Answer: Decodable { let song: Song; let summary: String }
        let a: Answer = try engines.compose("a hopeful folk song in G major", seed: 4)
        XCTAssertEqual(a.song.tracks.map(\.role), ["melody", "countermelody", "harmony", "bass", "drums"])
        XCTAssertFalse(a.song.tracks[0].notes.isEmpty)
        XCTAssertTrue(a.summary.contains("G Major"))
    }
}
