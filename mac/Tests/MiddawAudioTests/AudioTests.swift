import XCTest
import MiddawCore
@testable import MiddawAudio

/// The renderer, run offline: what the app plays is what these hear.
final class AudioTests: XCTestCase {
    func song(device: String = "synth", preset: String? = "piano", drums: Bool = false) -> Project {
        var p = Project(tempo: 120)
        var t = Track(name: "T", drums: drums, sound: Device(device: device, preset: preset))
        let pitches = drums ? [36, 38, 42, 46] : [60, 64, 67, 72]
        t.clips = [Clip(start: 0, length: 4, notes: pitches.enumerated().map { Note(start: Double($0.offset), len: 0.9, pitch: $0.element) })]
        p.tracks = [t]
        return p
    }

    func rms(_ x: ArraySlice<Float>) -> Double {
        guard !x.isEmpty else { return 0 }
        return sqrt(x.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(x.count))
    }

    func testEveryPresetAndTheKitMakeSoundAndStayFinite() {
        for (id, _, _) in SynthPreset.all {
            let out = Bounce.render(song(preset: id), sampleRate: 24000, tail: 0.5)
            XCTAssertGreaterThan(rms(out.left[...]), 0.003, id)
            XCTAssertTrue(out.left.allSatisfy { $0.isFinite && abs($0) <= 1 }, id)
        }
        let kit = Bounce.render(song(device: "kit", preset: nil, drums: true), sampleRate: 24000, tail: 0.5)
        XCTAssertGreaterThan(rms(kit.left[...]), 0.003)
    }

    /// A note starts on its beat, to the sample: silence before, sound after.
    func testNotesStartOnTheirBeat() {
        var p = song()
        p.tracks[0].clips[0].notes = [Note(start: 1, len: 1, pitch: 60)]
        let rate = 24000.0
        let out = Bounce.render(p, sampleRate: rate, tail: 0)
        let onset = Int(rate * 0.5)                       // beat 1 at 120 bpm
        XCTAssertEqual(rms(out.left[0..<(onset - 10)]), 0, accuracy: 1e-9)
        XCTAssertGreaterThan(rms(out.left[onset..<(onset + 2400)]), 0.003)
    }

    func testMuteSilencesAndSoloLeavesOnlyTheSoloedTrack() {
        var p = song()
        p.tracks[0].mute = true
        XCTAssertEqual(rms(Bounce.render(p, sampleRate: 24000, tail: 0).left[...]), 0, accuracy: 1e-9)
        var q = song()
        var other = q.tracks[0]; other.id = makeID("t"); other.solo = true
        other.clips[0].notes = []
        q.tracks.append(other)
        XCTAssertEqual(rms(Bounce.render(q, sampleRate: 24000, tail: 0).left[...]), 0, accuracy: 1e-9)
    }

    func testTheReverbSendIsHeardAfterTheNoteEnds() {
        var dry = song(), wet = song()
        dry.tracks[0].clips[0].notes = [Note(start: 0, len: 0.25, pitch: 72)]
        wet.tracks[0].clips[0].notes = dry.tracks[0].clips[0].notes
        wet.tracks[0].send = 1
        dry.tracks[0].sound.preset = "organ"; wet.tracks[0].sound.preset = "organ"
        let rate = 24000.0, after = Int(rate * 1.0)
        let d = Bounce.render(dry, sampleRate: rate, tail: 1), w = Bounce.render(wet, sampleRate: rate, tail: 1)
        XCTAssertGreaterThan(rms(w.left[after..<(after + 6000)]), rms(d.left[after..<(after + 6000)]) * 3 + 1e-4)
    }

    func testTheLoopGoesRoundAgain() {
        var p = song()
        p.tracks[0].clips[0].notes = [Note(start: 0, len: 0.5, pitch: 60)]
        p.loop = Loop(on: true, start: 0, end: 2)
        let rate = 24000.0
        let r = Renderer(sampleRate: rate)
        r.update(p); r.play(from: 0)
        var l = [Float](repeating: 0, count: Int(rate * 1.5)), rr = l   // 3 beats: past the loop's end
        l.withUnsafeMutableBufferPointer { a in rr.withUnsafeMutableBufferPointer { b in r.render(a.count, a.baseAddress!, b.baseAddress!) } }
        let second = Int(rate * 1.0)                                  // beat 2 = beat 0 again
        XCTAssertGreaterThan(rms(l[second..<(second + 2400)]), 0.003)
        XCTAssertLessThan(r.position, 2)
    }

    func testAWavFileIsWellFormed() {
        let out = Bounce.render(song(), sampleRate: 24000, tail: 0)
        let wav = Bounce.wav(out.left, out.right, sampleRate: 24000)
        XCTAssertEqual(String(decoding: wav.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(wav.count, 44 + out.left.count * 4)
    }

    func testASampleSurvivesTheSongFile() {
        let left = (0..<1000).map { Float(sin(Double($0) / 10)) * 0.5 }
        let s = SampleCodec.encode(name: "hit.wav", left: left, right: nil, rate: 44100)
        let back = SampleCodec.decode(s)!
        XCTAssertEqual(back.left.count, 1000)
        XCTAssertEqual(back.left[37], left[37], accuracy: 1.0 / 32000)
        var p = song(device: "sampler", preset: nil)
        p.tracks[0].sound.sample = s
        XCTAssertGreaterThan(rms(Bounce.render(p, sampleRate: 24000, tail: 0).left[...]), 0.001)
    }
}
