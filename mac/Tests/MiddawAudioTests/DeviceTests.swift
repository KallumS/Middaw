import XCTest
import CJSFX
import MiddawCore
@testable import MiddawAudio

/// The family's JSFX compiled to C and played in the track's chain. That the
/// C does what the JSFX does is tests/test_jsfx_c.py's job; these check the
/// devices are wired in: they get MIDI, make sound, keep their state.
final class DeviceTests: XCTestCase {
    func rms(_ x: ArraySlice<Float>) -> Double {
        guard !x.isEmpty else { return 0 }
        return sqrt(x.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(x.count))
    }

    func song(sound: Device, notes: [Note], midiFx: [Device] = [], audioFx: [Device] = []) -> Project {
        var p = Project(tempo: 120)
        var t = Track(name: "T", sound: sound)
        t.midiFx = midiFx; t.audioFx = audioFx
        t.clips = [Clip(start: 0, length: 8, notes: notes)]
        p.tracks = [t]
        return p
    }

    func testEveryDeviceIsCompiledInWithItsControls() {
        XCTAssertEqual(Int(jsfx_count()), DeviceCatalog.all.count)
        for d in DeviceCatalog.all {
            let sliders = DeviceCatalog.sliders(d.id)
            XCTAssertFalse(sliders.isEmpty, d.id)
            let have = Set(sliders.map(\.index))
            for n in d.main + d.more + d.groups.flatMap(\.sliders) { XCTAssertTrue(have.contains(n), "\(d.id) slider \(n)") }
            XCTAssertNotNil(JSFXDevice(Device(device: d.id), sampleRate: 48000), d.id)
        }
    }

    func testInstrumentCreatorPlaysANote() {
        let p = song(sound: Device(device: "creator"), notes: [Note(start: 0, len: 1, pitch: 60)])
        let out = Bounce.render(p, sampleRate: 48000, tail: 0.5)
        XCTAssertGreaterThan(rms(out.left[0..<24000]), 0.001)
        XCTAssertTrue(out.left.allSatisfy { $0.isFinite })
    }

    func testTransientShufflerPlaysItsSounds() {
        let rate = 48000.0
        func burst(_ f: Double) -> Sample {
            let left = (0..<12000).map { i -> Float in Float(sin(2 * .pi * f * Double(i) / rate) * exp(-Double(i) / 2000)) * 0.8 }
            return SampleCodec.encode(name: "burst\(Int(f)).wav", left: left, right: nil, rate: rate)
        }
        var ts = Device(device: "shuffler")
        ts.samples = [burst(220), burst(330)]
        let p = song(sound: ts, notes: [Note(start: 0, len: 1, pitch: 60)])
        let out = Bounce.render(p, sampleRate: rate, tail: 0.2)
        XCTAssertGreaterThan(rms(out.left[0..<12000]), 0.001)
        XCTAssertTrue(out.left.allSatisfy { $0.isFinite })
    }

    func testReverberatorLeavesATail() {
        let note = [Note(start: 0, len: 0.25, pitch: 72)]
        let dry = Bounce.render(song(sound: Device(device: "synth", preset: "organ"), notes: note), sampleRate: 48000, tail: 1)
        var verb = Device(device: "reverberator"); verb.sliders = [2: 100, 4: 300]
        let wet = Bounce.render(song(sound: Device(device: "synth", preset: "organ"), notes: note, audioFx: [verb]), sampleRate: 48000, tail: 1)
        let after = 48000                                   // two beats: long after the note
        XCTAssertGreaterThan(rms(wet.left[after..<(after + 12000)]), rms(dry.left[after..<(after + 12000)]) * 2 + 1e-5)
        XCTAssertTrue(wet.left.allSatisfy { $0.isFinite })
    }

    func testReverberatorOnTheReturn() {
        var p = song(sound: Device(device: "synth", preset: "organ"), notes: [Note(start: 0, len: 0.25, pitch: 72)])
        p.tracks[0].send = 1
        var verb = Device(device: "reverberator"); verb.sliders = [2: 100]
        p.returns = [Return(audioFx: [verb])]
        let out = Bounce.render(p, sampleRate: 48000, tail: 1)
        XCTAssertGreaterThan(rms(out.left[36000..<48000]), 1e-4)
        XCTAssertTrue(out.left.allSatisfy { $0.isFinite })
    }

    func testMidiEvolverPlaysAHeldChordThroughTheSynth() {
        let chord = [60, 64, 67].map { Note(start: 0, len: 8, pitch: $0) }
        let p = song(sound: Device(device: "synth", preset: "keys"), notes: chord, midiFx: [Device(device: "evolver")])
        let out = Bounce.render(p, sampleRate: 48000, tail: 0)
        XCTAssertGreaterThan(rms(out.left[...]), 0.001)
    }

    /// AutoCC, between a note and the instrument, draws its arc as CC1.
    func testAutoCCSendsControllers() {
        let d = JSFXDevice(Device(device: "autocc"), sampleRate: 48000)!
        let midi = UnsafeMutablePointer<jsfx_midi>.allocate(capacity: 1)
        defer { midi.deallocate() }
        midi[0] = jsfx_midi(offset: 0, len: 3, data: (0x90, 60, 100))
        let time = DeviceTime(tempo: 120, playing: true, beat: 0, num: 4, den: 4)
        var ccs = 0
        for b in 0..<200 {
            let n = d.process(256, nil, 0, nil, 0, b == 0 ? UnsafePointer(midi) : nil, b == 0 ? 1 : 0, time)
            XCTAssertGreaterThanOrEqual(n, 0)
            for k in 0..<max(0, n) where d.midiOut[k].data.0 & 0xF0 == 0xB0 { ccs += 1 }
        }
        XCTAssertGreaterThan(ccs, 0)
    }

    /// Saved and opened again, a device is as it was.
    func testStateSurvivesSavingAndReopening() {
        var dev = Device(device: "evolver")
        dev.sliders = [1: 2, 3: 40]
        let a = JSFXDevice(dev, sampleRate: 48000)!
        let st = a.state()
        guard case .object(let o) = st, case .array(let data)? = o["data"] else { return XCTFail("no state") }
        XCTAssertFalse(data.isEmpty)
        dev.state = st
        let b = JSFXDevice(dev, sampleRate: 48000)!
        XCTAssertEqual(b.state(), st)
        XCTAssertEqual(b.slider(3), 40)
        // and through JSON, as a song file keeps it
        let json = try! JSONEncoder().encode(dev)
        let back = try! JSONDecoder().decode(Device.self, from: json)
        XCTAssertEqual(JSFXDevice(back, sampleRate: 48000)!.state(), st)
    }

    func testInstrumentCreatorsInstrumentsAreReadFromItsSource() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../family/devices/Instrument-Creator.jsfx")
        let presets = DeviceCatalog.creatorPresets(source: try String(contentsOf: url, encoding: .utf8))
        XCTAssertEqual(presets.count, 19)
        XCTAssertEqual(presets.first?.name, "Bamboo Saxophone")
        XCTAssertEqual(presets.last?.name, "Tin Roof Banjo")
        XCTAssertTrue(presets.allSatisfy { $0.values.count >= 18 })
    }
}
