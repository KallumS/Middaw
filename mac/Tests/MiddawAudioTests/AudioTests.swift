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

    // ------------------------------------------------------------- stage --
    /// A note on pitch 64, which Middaw Synth itself pans to the middle.
    func seated(_ seat: String?, preset: String = "organ", hall: String = "concert") -> Project {
        var p = song(preset: preset)
        p.tracks[0].clips[0].notes = [Note(start: 0, len: 0.5, pitch: 64)]
        p.tracks[0].seat = seat
        p.hall = hall
        return p
    }

    /// At the front nothing is added: no hall after the note, no side.
    func testTheFrontIsDryAndInTheMiddle() {
        let rate = 24000.0
        let out = Bounce.render(seated(nil), sampleRate: rate, tail: 1)
        XCTAssertEqual(out.left, out.right)
        let after = Int(rate * 0.75)                        // the organ's release is 60 ms
        XCTAssertLessThan(rms(out.left[after...]), 1e-4)
    }

    /// The first violins sit on the left; the cellos on the right; both are
    /// heard in the hall after the note ends.
    func testASeatIsHeardFromWhereItIsInTheHall() {
        let rate = 24000.0
        let violins = Bounce.render(seated("vln1"), sampleRate: rate, tail: 1)
        let cellos = Bounce.render(seated("vc"), sampleRate: rate, tail: 1)
        let note = 0..<Int(rate * 0.25)
        XCTAssertGreaterThan(rms(violins.left[note]), rms(violins.right[note]) * 1.5)
        XCTAssertGreaterThan(rms(cellos.right[note]), rms(cellos.left[note]) * 1.5)
        let after = Int(rate * 0.75)..<Int(rate * 1.25)
        XCTAssertGreaterThan(rms(violins.left[after]), 1e-4)
        XCTAssertTrue(violins.left.allSatisfy { $0.isFinite && abs($0) <= 1 })
    }

    /// The timpani are further away than the violins: of what reaches the
    /// microphones from a seat - direct sound, reflections, the hall's tail -
    /// the direct sound is a much smaller share. That ratio is how an ear
    /// hears distance.
    func testTheBackOfTheStageIsFurtherAway() {
        let rate = 24000.0, hall = Hall.concert
        let tailEnergy = pow(Stage.reference / hall.criticalDistance, 2)
        func directToReverberant(_ id: String) -> Double {
            let seat = Stage.seat(id)!
            XCTAssertGreaterThan(Stage.sound(seat, in: hall).reflections.first!.delay, 0.001, id)
            let voice = SeatVoice(seat: seat, hall: hall, sampleRate: rate)
            let n = Int(rate * 0.2)
            var inL = [Float](repeating: 0, count: n), inR = inL, outL = inL, outR = inL, tail = inL
            inL[0] = 1; inR[0] = 1
            voice.process(n, inL, inR, gain: 1, &outL, &outR, &tail)
            let both = zip(outL, outR).map { Double($0) * Double($0) + Double($1) * Double($1) }
            let early = Int(rate * 0.0008)
            let direct = both[0..<early].reduce(0, +)
            let reflected = both[early...].reduce(0, +)
            let fed = tail.reduce(0.0) { $0 + Double($1) * Double($1) }
            return direct / (reflected + 2 * tailEnergy * fed)
        }
        let violins = directToReverberant("vln1"), timpani = directToReverberant("timp")
        XCTAssertLessThan(10 * log10(timpani / violins), -4)
    }

    /// A drier room leaves less behind.
    func testTheStudioIsDrierThanTheConcertHall() {
        let rate = 24000.0
        let concert = Bounce.render(seated("ob1", hall: "concert"), sampleRate: rate, tail: 1.5)
        let studio = Bounce.render(seated("ob1", hall: "studio"), sampleRate: rate, tail: 1.5)
        let late = Int(rate * 1.2)..<Int(rate * 1.8)
        XCTAssertGreaterThan(rms(concert.left[late]), rms(studio.left[late]) * 4)
    }

    /// The convolver is the convolution: against the sum written out, for a
    /// response with a head and a tail, fed in blocks of any size.
    func testTheConvolverIsExactAndOnTime() {
        var seed: UInt32 = 7
        func random() -> Float { seed = seed &* 1664525 &+ 1013904223; return Float(seed >> 8) / Float(1 << 24) - 0.5 }
        let ir = (0..<1500).map { _ in random() }
        let x = (0..<5000).map { _ in random() }
        var expected = [Float](repeating: 0, count: x.count)
        for t in 0..<x.count { var acc: Float = 0; for m in 0..<min(ir.count, t + 1) { acc += ir[m] * x[t - m] }; expected[t] = acc }
        let conv = Convolver(ir: ir, block: 64)
        var got = [Float](repeating: 0, count: x.count)
        var at = 0, k = 0
        let sizes = [1, 7, 64, 100, 3, 250, 64, 1]
        x.withUnsafeBufferPointer { xs in
            got.withUnsafeMutableBufferPointer { ys in
                while at < x.count {
                    let n = min(sizes[k % sizes.count], x.count - at)
                    conv.process(n, xs.baseAddress! + at, ys.baseAddress! + at)
                    at += n; k += 1
                }
            }
        }
        for t in 0..<x.count { XCTAssertEqual(got[t], expected[t], accuracy: 1e-3, "sample \(t)") }
    }

    /// An Audio Unit plays a seat: Apple's own DLS synth, which every Mac has.
    func testAnAudioUnitPlaysInASeat() throws {
        let ref = PluginRef(type: PluginRef.code("aumu"), subtype: PluginRef.code("dls "), manufacturer: PluginRef.code("appl"),
                            name: "DLSMusicDevice", maker: "Apple")
        guard PluginCatalog.instruments().contains(where: { $0.subtype == ref.subtype && $0.manufacturer == ref.manufacturer }) else {
            throw XCTSkip("Apple's DLS synth is not on this Mac")
        }
        var p = seated("ob1")
        p.tracks[0].sound = Device(device: "au")
        p.tracks[0].sound.plugin = ref
        p.tracks[0].clips[0].notes = [Note(start: 0, len: 1, pitch: 72, vel: 110)]
        let out = Bounce.render(p, sampleRate: 48000, tail: 0.5)
        XCTAssertGreaterThan(rms(out.left[0..<24000]), 1e-4)
        XCTAssertTrue(out.left.allSatisfy { $0.isFinite })
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
