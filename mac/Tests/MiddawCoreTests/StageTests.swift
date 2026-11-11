import XCTest
@testable import MiddawCore

/// The stage and the halls: where each player sits and what the hall makes
/// of a sound from there.
final class StageTests: XCTestCase {
    func testEverySeatIsItsOwnAndInsideEveryHall() {
        XCTAssertEqual(Set(Stage.seats.map(\.id)).count, Stage.seats.count)
        for hall in Hall.all {
            for seat in Stage.seats {
                XCTAssertLessThan(abs(seat.x), hall.width / 2, "\(seat.id) in \(hall.id)")
                XCTAssertLessThan(seat.depth, Stage.depth, seat.id)
                XCTAssertLessThan(seat.height, hall.height, seat.id)
            }
            XCTAssertLessThan(Stage.depth - Stage.listener.depth, hall.length, hall.id)
        }
    }

    /// American seating, as heard from the microphones over the conductor.
    func testTheFirstViolinsAreLeftTheCellosRightTheTimpaniFarAndCentred() {
        let hall = Hall.concert
        func sound(_ id: String) -> SeatSound { Stage.sound(Stage.seat(id)!, in: hall) }
        XCTAssertLessThan(sound("vln1").pan, -0.6)
        XCTAssertGreaterThan(sound("vc").pan, 0.6)
        XCTAssertEqual(sound("timp").pan, 0, accuracy: 0.05)
        XCTAssertGreaterThan(sound("timp").distance, sound("vln1").distance + 5)
        XCTAssertLessThan(sound("timp").direct, sound("vln1").direct * 0.6)
        XCTAssertLessThan(sound("timp").airCutoff, sound("vln1").airCutoff)
        // the front desks are about as loud as recorded
        XCTAssertGreaterThan(sound("vln1").direct, 0.9)
    }

    func testReflectionsComeAfterTheDirectSoundAndAreQuieterThanIt() {
        for seat in Stage.seats {
            let s = Stage.sound(seat, in: .concert)
            XCTAssertFalse(s.reflections.isEmpty, seat.id)
            for r in s.reflections {
                XCTAssertGreaterThan(r.delay, 0, seat.id)
                XCTAssertLessThanOrEqual(r.delay, 0.15, seat.id)
                XCTAssertLessThan(max(r.left, r.right), s.direct * 2.0.squareRoot(), seat.id)
            }
        }
    }

    /// Sabine, and a tail as loud beside the direct sound as the critical
    /// distance says it should be.
    func testTheTailFallsSixtyDecibelsInItsReverberationTime() {
        let hall = Hall.concert, rate = 8000.0
        let tail = Stage.tail(hall, sampleRate: rate)
        XCTAssertEqual(tail.left.count, Int(hall.rt60 * rate))
        XCTAssertNotEqual(tail.left, tail.right)
        func energy(_ x: ArraySlice<Float>) -> Double { x.reduce(0.0) { $0 + Double($1) * Double($1) } }
        XCTAssertEqual(energy(tail.left[...]), pow(Stage.reference / hall.criticalDistance, 2), accuracy: 1e-3)
        // nothing before the first reflections
        XCTAssertEqual(energy(tail.left[0..<Int(0.012 * rate)]), 0)
        // a tenth of RT60 apart, the level falls 6 dB, whatever the colour does
        let a = energy(tail.left[Int(0.3 * rate)..<Int(0.5 * rate)]), b = energy(tail.left[Int(0.5 * rate)..<Int(0.7 * rate)])
        XCTAssertEqual(10 * log10(a / b), 6, accuracy: 2.5)
        XCTAssertGreaterThan(hall.criticalDistance, Hall.studio.criticalDistance)
    }

    func testAnInstrumentTakesTheFirstFreeSeatForIt() {
        XCTAssertEqual(Stage.freeSeat(for: "fl", taken: [])?.id, "fl1")
        XCTAssertEqual(Stage.freeSeat(for: "fl", taken: ["fl1"])?.id, "fl2")
        XCTAssertNil(Stage.freeSeat(for: "fl", taken: ["fl1", "fl2"]))
        XCTAssertNil(Stage.freeSeat(for: "kit", taken: []), "a kit is a band's unless it is put in the percussion seat")
        XCTAssertFalse(Stage.isOrchestral("pno"))
        XCTAssertFalse(Stage.isOrchestral("synth"))
        XCTAssertTrue(Stage.isOrchestral("ob"))
    }

    /// A song from before the stage: its orchestra sits down, its band stays at the front.
    func testAnOlderSongIsSeated() throws {
        let json = """
        {"version":1,"title":"Old","tracks":[
          {"id":"a","name":"Flute","instrument":"fl"},{"id":"b","name":"Flute","instrument":"fl"},
          {"id":"c","name":"Flute","instrument":"fl"},{"id":"d","name":"Piano","instrument":"pno"},
          {"id":"e","name":"Drums","instrument":"kit","drums":true},{"id":"f","name":"Cello","instrument":"vc"}]}
        """
        let p = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertEqual(p.tracks.map(\.seat), ["fl1", "fl2", nil, nil, nil, "vc"])
        XCTAssertEqual(p.version, Project.currentVersion)
        XCTAssertEqual(p.hall, "concert")
        // saved and opened again, nobody moves
        var moved = p
        moved.tracks[1].seat = nil
        let again = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(moved))
        XCTAssertEqual(again, moved)
    }

    func testAnAudioUnitIsKeptInTheSong() throws {
        var d = Device(device: "au")
        d.plugin = PluginRef(type: PluginRef.code("aumu"), subtype: PluginRef.code("dls "), manufacturer: PluginRef.code("appl"),
                             name: "DLSMusicDevice", maker: "Apple")
        d.state = .string("AAEC")
        XCTAssertEqual(PluginRef.code("aumu"), 0x6175_6D75)
        let back = try JSONDecoder().decode(Device.self, from: JSONEncoder().encode(d))
        XCTAssertEqual(back, d)
    }
}
