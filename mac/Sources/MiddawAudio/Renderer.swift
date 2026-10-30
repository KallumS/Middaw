import Foundation
import MiddawCore
import CJSFX
#if canImport(os)
import os
#endif

/// The audio thread's whole world: every track's notes as MIDI events in
/// beats, its device chain, its level, pan and reverb send; the transport;
/// the metronome; the reverb return. `render` is called with a block of
/// frames and plays them sample-accurately.
///
/// A track's block is a chain, as Bitwig and Ableton run one: the notes due
/// in it become MIDI with sample offsets, go through the track's MIDI effects,
/// are played by its instrument, and the sound goes through its audio effects.
///
/// The app changes it from the main thread only through `update`, `play`,
/// `stop` and `live`, which hand changes over under a lock the audio thread
/// only ever *tries* - it never waits.
public final class Renderer {
    public struct Event { public var beat: Double; public var status: UInt8; public var d1: UInt8; public var d2: UInt8 }

    public final class Channel {
        public let id: String
        public let signature: String
        /// Middaw's own instrument, or nil when a JSFX plays the track.
        let instrument: Instrument?
        let jsfxInstrument: JSFXDevice?
        let midiFx: [JSFXDevice]
        let audioFx: [JSFXDevice]
        let midiChannel: UInt8
        var events: [Event] = []
        var gainL: Float = 1, gainR: Float = 1, send: Float = 0
        var next = 0
        /// The notes the sequence has started and not yet ended.
        var held = [Bool](repeating: false, count: 128)
        var releaseNext = false, panicNext = false
        let bufL: UnsafeMutablePointer<Float>, bufR: UnsafeMutablePointer<Float>
        let zero: UnsafeMutablePointer<Float>
        let ins: UnsafeMutablePointer<UnsafePointer<Float>?>
        let outs: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>
        /// The block's MIDI, and what a keyboard played since the last block.
        static let midiCapacity = 4096
        let seq: UnsafeMutablePointer<jsfx_midi>
        var seqCount = 0
        let live: UnsafeMutablePointer<jsfx_midi>
        var liveCount = 0
        public internal(set) var peak: Float = 0

        init(id: String, signature: String, instrument: Instrument?, jsfx: JSFXDevice?, midiFx: [JSFXDevice], audioFx: [JSFXDevice],
             drums: Bool, capacity: Int) {
            self.id = id; self.signature = signature; self.instrument = instrument; self.jsfxInstrument = jsfx
            self.midiFx = midiFx; self.audioFx = audioFx
            midiChannel = drums ? 9 : 0
            bufL = .allocate(capacity: capacity); bufR = .allocate(capacity: capacity); zero = .allocate(capacity: capacity)
            bufL.initialize(repeating: 0, count: capacity); bufR.initialize(repeating: 0, count: capacity)
            zero.initialize(repeating: 0, count: capacity)
            ins = .allocate(capacity: 2); outs = .allocate(capacity: 2)
            ins.initialize(repeating: nil, count: 2); outs.initialize(repeating: nil, count: 2)
            seq = .allocate(capacity: Channel.midiCapacity); live = .allocate(capacity: 256)
        }

        deinit {
            bufL.deallocate(); bufR.deallocate(); zero.deallocate()
            ins.deallocate(); outs.deallocate(); seq.deallocate(); live.deallocate()
        }

        var devices: [JSFXDevice] { midiFx + (jsfxInstrument.map { [$0] } ?? []) + audioFx }

        @inline(__always) func push(_ offset: Int, _ status: UInt8, _ d1: UInt8, _ d2: UInt8) {
            guard seqCount < Channel.midiCapacity else { return }
            seq[seqCount] = jsfx_midi(offset: Int32(offset), len: 3, data: (status, d1, d2))
            seqCount += 1
        }
        /// Every note the sequence started, ended at `offset`.
        func releaseHeld(at offset: Int) {
            for p in 0..<128 where held[p] { held[p] = false; push(offset, 0x80 | midiChannel, UInt8(p), 0) }
        }

        func dispatch(_ status: UInt8, _ d1: UInt8, _ d2: UInt8) {
            guard let instrument else { return }
            let kind = status & 0xF0
            if kind == 0x90 && d2 > 0 { instrument.noteOn(Int(d1), Int(d2)) }
            else if kind == 0x80 || kind == 0x90 { instrument.noteOff(Int(d1)) }
            else if kind == 0xB0 && (d1 == 123 || d1 == 120) { instrument.allOff() }
            else if kind == 0xB0 { instrument.cc(Int(d1), Int(d2)) }
        }
        /// The next event at or after `beat`.
        func seek(_ beat: Double) {
            var lo = 0, hi = events.count
            while lo < hi { let mid = (lo + hi) / 2; if events[mid].beat < beat - 1e-9 { lo = mid + 1 } else { hi = mid } }
            next = lo
        }
    }

    public let sampleRate: Double
    public static let maxFrames = 4096

    // Owned by the audio thread.
    var channels: [Channel] = []
    var returnFx: [JSFXDevice] = []
    var playing = false
    var beat = 0.0
    var tempo = 120.0
    var beatsPerBar = 4.0
    var meter: (Double, Double) = (4, 4)
    var loop: Loop? = nil
    var metronome = false
    let click: Click
    let reverb: Reverb
    let clickL: UnsafeMutablePointer<Float>, clickR: UnsafeMutablePointer<Float>
    let sendL: UnsafeMutablePointer<Float>, sendR: UnsafeMutablePointer<Float>
    let returnIns: UnsafeMutablePointer<UnsafePointer<Float>?>
    let returnOuts: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>
    struct Segment { var from: Int; var count: Int; var beat: Double }
    var segments: [Segment] = []
    /// What the audio thread let go of, for the main thread to free.
    var retired: [Channel] = []
    var retiredFx: [JSFXDevice] = []
    /// The channels as last built on the main thread, for reading meters.
    var built: [Channel] = []
    var builtReturn: [JSFXDevice] = []

    // Handed over from the main thread.
    var lock = os_unfair_lock_s()
    var pendingChannels: [Channel]? = nil
    var pendingReturn: [JSFXDevice]? = nil
    var pendingTransport: (playing: Bool, beat: Double)? = nil
    var pendingSettings: (tempo: Double, beatsPerBar: Double, loop: Loop?, metronome: Bool)? = nil
    var pendingMeter: (Double, Double)? = nil
    var liveQueue: [(channel: String, status: UInt8, d1: UInt8, d2: UInt8)] = []
    var panicAll = false

    /// Where the music is, for the screen. Written by the audio thread.
    public private(set) var position: Double = 0
    public private(set) var isPlaying = false

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        click = Click(sampleRate: sampleRate)
        reverb = Reverb(sampleRate: sampleRate)
        let n = Renderer.maxFrames
        clickL = .allocate(capacity: n); clickR = .allocate(capacity: n)
        sendL = .allocate(capacity: n); sendR = .allocate(capacity: n)
        for b in [clickL, clickR, sendL, sendR] { b.initialize(repeating: 0, count: n) }
        returnIns = .allocate(capacity: 2); returnOuts = .allocate(capacity: 2)
        returnIns[0] = UnsafePointer(sendL); returnIns[1] = UnsafePointer(sendR)
        returnOuts[0] = sendL; returnOuts[1] = sendR
        liveQueue.reserveCapacity(1024)
        segments.reserveCapacity(2)
        retired.reserveCapacity(1024)
        retiredFx.reserveCapacity(64)
    }

    deinit {
        for b in [clickL, clickR, sendL, sendR] { b.deallocate() }
        returnIns.deallocate(); returnOuts.deallocate()
    }

    // ------------------------------------------------------- main thread --
    /// The song as the audio thread should play it. Instruments and devices
    /// whose track, kind and sounds have not changed are kept, so what is
    /// sounding goes on sounding and a device keeps its state.
    public func update(_ p: Project) {
        os_unfair_lock_lock(&lock)
        let existing = pendingChannels ?? channels
        let existingReturn = pendingReturn ?? returnFx
        // what the audio thread has let go of is freed here, not there
        let dead = retired, deadFx = retiredFx
        retired.removeAll(keepingCapacity: true)
        retiredFx.removeAll(keepingCapacity: true)
        os_unfair_lock_unlock(&lock)
        _ = dead; _ = deadFx
        var byID: [String: Channel] = [:]
        var devices: [String: JSFXDevice] = [:]
        for c in existing { byID[c.id] = c; for d in c.devices { devices[d.modelID] = d } }
        for d in existingReturn { devices[d.modelID] = d }
        let rate = sampleRate
        func device(_ d: Device) -> JSFXDevice? {
            if let old = devices[d.id], old.signature == JSFXDevice.signature(d) { old.sync(d); return old }
            return JSFXDevice(d, sampleRate: rate)
        }
        let anySolo = p.tracks.contains { $0.solo }
        var fresh: [Channel] = []
        for t in p.tracks {
            let sig = Renderer.signature(t)
            let isJSFX = DeviceCatalog.info(t.sound.device) != nil
            let builtIn: Instrument? = isJSFX ? nil :
                ((byID[t.id].flatMap { $0.signature == sig ? $0.instrument : nil }) ?? Renderer.makeInstrument(t, sampleRate: rate))
            let c = Channel(id: t.id, signature: sig, instrument: builtIn, jsfx: isJSFX ? device(t.sound) : nil,
                            midiFx: t.midiFx.compactMap(device), audioFx: t.audioFx.compactMap(device),
                            drums: t.drums, capacity: Renderer.maxFrames)
            if let old = byID[t.id], old.signature == sig { c.held = old.held }
            c.events = Renderer.events(t)
            let audible = !t.mute && (!anySolo || t.solo)
            let g = audible ? Renderer.gain(t.volume) : 0
            let pan = max(-1, min(1, t.pan))
            c.gainL = Float(Double(g) * cos((pan + 1) * .pi / 4) * sqrt(2))
            c.gainR = Float(Double(g) * sin((pan + 1) * .pi / 4) * sqrt(2))
            c.send = Float(max(0, min(1, t.send)))
            fresh.append(c)
        }
        let ret = (p.returns.first?.audioFx ?? []).compactMap(device)
        built = fresh
        builtReturn = ret
        os_unfair_lock_lock(&lock)
        pendingChannels = fresh
        pendingReturn = ret
        pendingSettings = (p.tempo, p.beatsPerBar, p.loop.on && p.loop.end > p.loop.start ? p.loop : nil, pendingSettings?.metronome ?? metronome)
        pendingMeter = (Double(p.meter.first ?? 4), Double(p.meter.count > 1 ? p.meter[1] : 4))
        os_unfair_lock_unlock(&lock)
    }

    public func play(from beat: Double) {
        os_unfair_lock_lock(&lock); pendingTransport = (true, max(0, beat)); os_unfair_lock_unlock(&lock)
    }
    public func stop() {
        os_unfair_lock_lock(&lock); pendingTransport = (false, position); os_unfair_lock_unlock(&lock)
    }
    public func setMetronome(_ on: Bool) {
        os_unfair_lock_lock(&lock)
        let s = pendingSettings ?? (tempo, beatsPerBar, loop, metronome)
        pendingSettings = (s.tempo, s.beatsPerBar, s.loop, on)
        os_unfair_lock_unlock(&lock)
    }
    /// A note or controller from a MIDI keyboard, played now on a track,
    /// through its MIDI effects.
    public func live(_ trackID: String, _ status: UInt8, _ d1: UInt8, _ d2: UInt8) {
        os_unfair_lock_lock(&lock)
        if liveQueue.count < 1000 { liveQueue.append((trackID, status, d1, d2)) }
        os_unfair_lock_unlock(&lock)
    }
    public func panic() { os_unfair_lock_lock(&lock); panicAll = true; os_unfair_lock_unlock(&lock) }

    public func peak(of trackID: String) -> Float { built.first { $0.id == trackID }?.peak ?? 0 }

    /// A device as it is playing now, by its id in the song.
    public func device(_ id: String) -> JSFXDevice? {
        for c in built { for d in c.devices where d.modelID == id { return d } }
        return builtReturn.first { $0.modelID == id }
    }
    /// Every device's saved state, by its id in the song: what Save keeps.
    public func deviceStates() -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for c in built { for d in c.devices { out[d.modelID] = d.state() } }
        for d in builtReturn { out[d.modelID] = d.state() }
        return out
    }

    // ---------------------------------------------------------- the song --
    /// 0.8 on the fader is unity; the fader is in dB, (v - 0.8) * 60.
    public static func gain(_ volume: Double) -> Float {
        volume <= 0 ? 0 : Float(pow(10, (volume - 0.8) * 60 / 20))
    }

    static func signature(_ t: Track) -> String {
        var s = t.sound.device + ":" + (t.sound.preset ?? "")
        if let sample = t.sound.sample { s += ":" + sample.name + ":\(sample.data.count):\(sample.root ?? 60)" }
        return s
    }

    static func makeInstrument(_ t: Track, sampleRate: Double) -> Instrument {
        switch t.sound.device {
        case "kit": return Kit(sampleRate: sampleRate)
        case "sampler":
            let s = Sampler(sampleRate: sampleRate)
            if let sample = t.sound.sample, let pcm = SampleCodec.decode(sample) {
                s.load(left: pcm.left, right: pcm.right, rate: sample.rate, root: sample.root ?? 60)
            }
            return s
        default:
            if t.drums { return Kit(sampleRate: sampleRate) }
            return Synth(sampleRate: sampleRate, preset: t.sound.preset)
        }
    }

    /// A track's notes and controllers as MIDI events in song beats. A
    /// note-off sorts before a note-on at the same beat, so a repeated note
    /// retriggers.
    public static func events(_ t: Track) -> [Event] {
        var ev: [Event] = []
        let ch: UInt8 = t.drums ? 9 : 0
        for c in t.clips {
            for n in c.notes where n.start < c.length - 1e-9 {
                let s = c.start + n.start, e = c.start + min(n.start + n.len, c.length)
                let p = UInt8(max(0, min(127, n.pitch)))
                ev.append(Event(beat: s, status: 0x90 | ch, d1: p, d2: UInt8(max(1, min(127, n.vel)))))
                ev.append(Event(beat: max(s + 1.0 / 128, e - 1.0 / 256), status: 0x80 | ch, d1: p, d2: 0))
            }
            for (num, pts) in c.cc {
                for pt in pts where pt.beat >= 0 && pt.beat <= c.length {
                    ev.append(Event(beat: c.start + pt.beat, status: 0xB0 | ch, d1: UInt8(num & 0x7F), d2: UInt8(max(0, min(127, pt.value)))))
                }
            }
        }
        return ev.sorted { a, b in
            if a.beat != b.beat { return a.beat < b.beat }
            return (a.status & 0xF0) < (b.status & 0xF0)
        }
    }

    // ------------------------------------------------------- audio thread --
    func takePending() {
        guard os_unfair_lock_trylock(&lock) else { return }
        defer { os_unfair_lock_unlock(&lock) }
        if let fresh = pendingChannels {
            // Notes held on a built-in instrument that left or changed stop.
            var kept = Set<ObjectIdentifier>()
            for c in fresh { if let i = c.instrument { kept.insert(ObjectIdentifier(i)) } }
            for c in channels {
                if let i = c.instrument, !kept.contains(ObjectIdentifier(i)) {
                    for p in 0..<128 where c.held[p] { i.noteOff(p) }
                }
            }
            if retired.count + channels.count <= retired.capacity { retired.append(contentsOf: channels) }
            channels = fresh
            for c in channels { c.seek(beat) }
            pendingChannels = nil
        }
        if let r = pendingReturn {
            if retiredFx.count + returnFx.count <= retiredFx.capacity { retiredFx.append(contentsOf: returnFx) }
            returnFx = r
            pendingReturn = nil
        }
        if let s = pendingSettings {
            tempo = max(1, s.tempo); beatsPerBar = s.beatsPerBar; loop = s.loop; metronome = s.metronome
            pendingSettings = nil
        }
        if let m = pendingMeter { meter = m; pendingMeter = nil }
        if let t = pendingTransport {
            for c in channels { c.releaseNext = true }
            playing = t.playing
            beat = t.beat
            for c in channels { c.seek(beat) }
            pendingTransport = nil
        }
        if panicAll {
            for c in channels { c.panicNext = true; c.instrument?.allOff() }
            panicAll = false
        }
        for m in liveQueue {
            for c in channels where c.id == m.channel && c.liveCount < 256 {
                c.live[c.liveCount] = jsfx_midi(offset: 0, len: 3, data: (m.status, m.d1, m.d2))
                c.liveCount += 1
            }
        }
        liveQueue.removeAll(keepingCapacity: true)
    }

    /// Render `frames` (up to `maxFrames`) into `left` and `right`, overwriting them.
    public func render(_ frames: Int, _ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>) {
        var done = 0
        while done < frames {
            let n = min(Renderer.maxFrames, frames - done)
            renderBlock(n, left + done, right + done)
            done += n
        }
    }

    func renderBlock(_ n: Int, _ outL: UnsafeMutablePointer<Float>, _ outR: UnsafeMutablePointer<Float>) {
        takePending()
        for i in 0..<n { outL[i] = 0; outR[i] = 0; sendL[i] = 0; sendR[i] = 0; clickL[i] = 0; clickR[i] = 0 }
        let beatsPerFrame = tempo / 60 / sampleRate

        // The block in up to two pieces: up to the loop's end, then from its start.
        segments.removeAll(keepingCapacity: true)
        if playing, let L = loop, beat < L.end, beat + Double(n) * beatsPerFrame > L.end {
            let first = max(0, min(n, Int(((L.end - beat) / beatsPerFrame).rounded(.up))))
            segments.append(Segment(from: 0, count: first, beat: beat))
            segments.append(Segment(from: first, count: n - first, beat: L.start))
        } else {
            segments.append(Segment(from: 0, count: n, beat: beat))
        }
        let time = DeviceTime(tempo: tempo, playing: playing, beat: beat, num: meter.0, den: meter.1)

        for c in channels {
            // 1. The block's MIDI: what a keyboard played, notes let go, then the song's.
            c.seqCount = 0
            for k in 0..<c.liveCount { if c.seqCount < Channel.midiCapacity { c.seq[c.seqCount] = c.live[k]; c.seqCount += 1 } }
            c.liveCount = 0
            if c.panicNext {
                c.releaseHeld(at: 0)
                for ch in 0..<16 { c.push(0, 0xB0 | UInt8(ch), 123, 0) }
                c.panicNext = false
            }
            if c.releaseNext { c.releaseHeld(at: 0); c.releaseNext = false }
            for (si, seg) in segments.enumerated() {
                if si > 0 { c.releaseHeld(at: seg.from); c.seek(seg.beat) }
                guard playing else { continue }
                let b1 = seg.beat + Double(seg.count) * beatsPerFrame
                while c.next < c.events.count && c.events[c.next].beat < b1 {
                    let e = c.events[c.next]
                    let off = seg.from + max(0, min(seg.count - 1, Int(((e.beat - seg.beat) / beatsPerFrame).rounded())))
                    let kind = e.status & 0xF0
                    if kind == 0x90 && e.d2 > 0 { c.held[Int(e.d1)] = true }
                    else if kind == 0x80 || kind == 0x90 { c.held[Int(e.d1)] = false }
                    c.push(off, e.status, e.d1, e.d2)
                    c.next += 1
                }
            }

            // 2. The MIDI effects, each reading what the one before it sent.
            var midi = UnsafePointer(c.seq)
            var count = c.seqCount
            for d in c.midiFx {
                let sent = d.process(n, nil, 0, nil, 0, midi, count, time)
                if sent >= 0 { midi = d.midiOut; count = sent }
            }

            // 3. The instrument.
            let L = c.bufL, R = c.bufR
            for i in 0..<n { L[i] = 0; R[i] = 0 }
            if let inst = c.instrument {
                var pos = 0
                for k in 0..<count {
                    let e = midi[k]
                    let off = max(0, min(n, Int(e.offset)))
                    if off > pos { inst.render(off - pos, L + pos, R + pos); pos = off }
                    c.dispatch(e.data.0, e.data.1, e.data.2)
                }
                if n > pos { inst.render(n - pos, L + pos, R + pos) }
            } else if let j = c.jsfxInstrument {
                c.ins[0] = UnsafePointer(c.zero); c.ins[1] = UnsafePointer(c.zero)
                c.outs[0] = L; c.outs[1] = R
                _ = j.process(n, UnsafePointer(c.ins), 2, UnsafePointer(c.outs), 2, midi, count, time)
            }

            // 4. The audio effects, in place.
            if !c.audioFx.isEmpty {
                c.ins[0] = UnsafePointer(L); c.ins[1] = UnsafePointer(R)
                c.outs[0] = L; c.outs[1] = R
                for d in c.audioFx { _ = d.process(n, UnsafePointer(c.ins), 2, UnsafePointer(c.outs), 2, nil, 0, time) }
            }

            var pk: Float = 0
            for i in 0..<n {
                let l = L[i] * c.gainL, r = R[i] * c.gainR
                outL[i] += l; outR[i] += r
                sendL[i] += l * c.send; sendR[i] += r * c.send
                pk = max(pk, abs(l), abs(r))
            }
            c.peak = max(pk, c.peak * 0.9)
        }

        // The metronome: a click on every beat, higher on the bar's first.
        var pos = 0
        if playing && metronome {
            for seg in segments where seg.count > 0 {
                var b = (seg.beat - 1e-9).rounded(.up)
                let b1 = seg.beat + Double(seg.count) * beatsPerFrame
                while b < b1 - 1e-12 {
                    let off = seg.from + min(seg.count - 1, max(0, Int(((b - seg.beat) / beatsPerFrame).rounded())))
                    if off > pos { click.render(off - pos, clickL + pos, clickR + pos); pos = off }
                    let down = abs(b / beatsPerBar - (b / beatsPerBar).rounded()) < 1e-6
                    click.noteOn(down ? 77 : 76, down ? 120 : 90)
                    b += 1
                }
            }
        }
        if n > pos { click.render(n - pos, clickL + pos, clickR + pos) }

        // The return: the song's own effects on it if it has any (Reverberator,
        // fully wet), else Middaw's reverb.
        if returnFx.isEmpty {
            reverb.process(n, sendL, sendR, outL, outR)
        } else {
            for d in returnFx { _ = d.process(n, UnsafePointer(returnIns), 2, UnsafePointer(returnOuts), 2, nil, 0, time) }
            for i in 0..<n { outL[i] += sendL[i]; outR[i] += sendR[i] }
        }
        for i in 0..<n {
            outL[i] = Renderer.soften((outL[i] + clickL[i]) * 0.9)
            outR[i] = Renderer.soften((outR[i] + clickR[i]) * 0.9)
        }

        if playing {
            beat = segments.last!.beat + Double(segments.last!.count) * beatsPerFrame
        }
        position = beat
        isPlaying = playing
    }

    /// Transparent below 0.9, then rounded off rather than clipped.
    @inline(__always) static func soften(_ x: Float) -> Float {
        let a = abs(x)
        if a <= 0.9 { return x }
        let y = 0.9 + 0.1 * tanh((a - 0.9) / 0.1)
        return x < 0 ? -y : y
    }
}

/// Middaw's own reverb return: Freeverb's eight combs and four all-passes a
/// side - the shared space every track's Reverb send feeds.
final class Reverb {
    final class Comb {
        var buf: [Float]; var idx = 0; var store: Float = 0
        init(_ n: Int) { buf = [Float](repeating: 0, count: n) }
        @inline(__always) func process(_ x: Float, feedback: Float, damp: Float) -> Float {
            let y = buf[idx]
            store = y * (1 - damp) + store * damp
            buf[idx] = x + store * feedback
            idx += 1; if idx >= buf.count { idx = 0 }
            return y
        }
    }
    final class AllPass {
        var buf: [Float]; var idx = 0
        init(_ n: Int) { buf = [Float](repeating: 0, count: n) }
        @inline(__always) func process(_ x: Float) -> Float {
            let b = buf[idx]
            buf[idx] = x + b * 0.5
            idx += 1; if idx >= buf.count { idx = 0 }
            return b - x
        }
    }
    var combsL: [Comb], combsR: [Comb], apL: [AllPass], apR: [AllPass]
    var size: Float = 0.84, damp: Float = 0.3, wet: Float = 0.9

    init(sampleRate: Double) {
        let scale = sampleRate / 44100
        let combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617], aps = [556, 441, 341, 225]
        combsL = combs.map { Comb(Int(Double($0) * scale)) }
        combsR = combs.map { Comb(Int(Double($0 + 23) * scale)) }
        apL = aps.map { AllPass(Int(Double($0) * scale)) }
        apR = aps.map { AllPass(Int(Double($0 + 23) * scale)) }
    }

    func process(_ n: Int, _ inL: UnsafeMutablePointer<Float>, _ inR: UnsafeMutablePointer<Float>,
                 _ outL: UnsafeMutablePointer<Float>, _ outR: UnsafeMutablePointer<Float>) {
        for i in 0..<n {
            let x = (inL[i] + inR[i]) * 0.015
            var l: Float = 0, r: Float = 0
            for c in combsL { l += c.process(x, feedback: size, damp: damp) }
            for c in combsR { r += c.process(x, feedback: size, damp: damp) }
            for a in apL { l = a.process(l) }
            for a in apR { r = a.process(r) }
            outL[i] += l * wet; outR[i] += r * wet
        }
    }
}

/// Samples kept in the song: 16-bit PCM, interleaved, base64.
public enum SampleCodec {
    public static func decode(_ s: Sample) -> (left: [Float], right: [Float]?)? {
        guard let data = Data(base64Encoded: s.data) else { return nil }
        let ch = max(1, s.channels)
        let count = data.count / 2 / ch
        var left = [Float](repeating: 0, count: count)
        var right: [Float]? = ch > 1 ? [Float](repeating: 0, count: count) : nil
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            for i in 0..<count {
                let l = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: (i * ch) * 2, as: Int16.self))
                left[i] = Float(l) / 32768
                if ch > 1 {
                    let r = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: (i * ch + 1) * 2, as: Int16.self))
                    right![i] = Float(r) / 32768
                }
            }
        }
        return (left, right)
    }

    public static func encode(name: String, left: [Float], right: [Float]?, rate: Double, root: Int = 60) -> Sample {
        let ch = right == nil ? 1 : 2
        var data = Data(capacity: left.count * ch * 2)
        func put(_ x: Float) {
            let v = Int16(max(-32768, min(32767, (x * 32767).rounded())))
            withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
        }
        for i in 0..<left.count { put(left[i]); if let r = right { put(r[i]) } }
        return Sample(name: name, rate: rate, channels: ch, data: data.base64EncodedString(), root: root)
    }
}

/// The song as a WAV file, rendered faster than real time by the same
/// renderer that plays it.
public enum Bounce {
    public static func render(_ p: Project, sampleRate: Double = 48000, tail: Double = 3) -> (left: [Float], right: [Float]) {
        let r = Renderer(sampleRate: sampleRate)
        r.update(p)
        r.play(from: 0)
        let seconds = p.seconds(max(4, p.endOfMusic)) + tail
        let total = Int(seconds * sampleRate)
        var left = [Float](repeating: 0, count: total), right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { rr in
                var done = 0
                while done < total {
                    let n = min(1024, total - done)
                    r.render(n, l.baseAddress! + done, rr.baseAddress! + done)
                    done += n
                }
            }
        }
        return (left, right)
    }

    public static func wav(_ left: [Float], _ right: [Float], sampleRate: Double) -> Data {
        let n = left.count, ch = 2
        var d = Data()
        func u32(_ v: Int) { withUnsafeBytes(of: UInt32(v).littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: Int) { withUnsafeBytes(of: UInt16(v).littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + n * ch * 2); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(ch); u32(Int(sampleRate)); u32(Int(sampleRate) * ch * 2); u16(ch * 2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(n * ch * 2)
        d.reserveCapacity(d.count + n * ch * 2)
        for i in 0..<n {
            for x in [left[i], right[i]] {
                let v = Int16(max(-32768, min(32767, (x * 32767).rounded())))
                withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) }
            }
        }
        return d
    }
}
