import Foundation
import MiddawCore
#if canImport(os)
import os
#endif

/// The audio thread's whole world: every track's notes as MIDI events in
/// beats, its instrument, its level, pan and reverb send; the transport; the
/// metronome; the reverb return. `render` is called with a block of frames
/// and plays them sample-accurately.
///
/// The app changes it from the main thread only through `update`, `play`,
/// `stop` and `live`, which hand changes over under a lock the audio thread
/// only ever *tries* - it never waits.
public final class Renderer {
    public struct Event { public var beat: Double; public var status: UInt8; public var d1: UInt8; public var d2: UInt8 }

    public final class Channel {
        public let id: String
        public let signature: String
        let instrument: Instrument
        var events: [Event] = []
        var gainL: Float = 1, gainR: Float = 1, send: Float = 0
        var next = 0
        var held = [Bool](repeating: false, count: 128)
        var bufL: [Float], bufR: [Float]
        public internal(set) var peak: Float = 0

        init(id: String, signature: String, instrument: Instrument, capacity: Int) {
            self.id = id; self.signature = signature; self.instrument = instrument
            bufL = [Float](repeating: 0, count: capacity); bufR = [Float](repeating: 0, count: capacity)
        }

        func dispatch(_ e: Event) {
            let kind = e.status & 0xF0
            if kind == 0x90 && e.d2 > 0 { held[Int(e.d1)] = true; instrument.noteOn(Int(e.d1), Int(e.d2)) }
            else if kind == 0x80 || kind == 0x90 { held[Int(e.d1)] = false; instrument.noteOff(Int(e.d1)) }
            else if kind == 0xB0 { instrument.cc(Int(e.d1), Int(e.d2)) }
        }
        func releaseAll() {
            for p in 0..<128 where held[p] { held[p] = false; instrument.noteOff(p) }
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
    var playing = false
    var beat = 0.0
    var tempo = 120.0
    var beatsPerBar = 4.0
    var loop: Loop? = nil
    var metronome = false
    let click: Click
    let reverb: Reverb
    var clickL: [Float], clickR: [Float], sendL: [Float], sendR: [Float]
    struct Segment { var from: Int; var count: Int; var beat: Double }
    var segments: [Segment] = []
    /// The channels as last built on the main thread, for reading meters.
    var built: [Channel] = []

    // Handed over from the main thread.
    var lock = os_unfair_lock_s()
    var pendingChannels: [Channel]? = nil
    var pendingTransport: (playing: Bool, beat: Double)? = nil
    var pendingSettings: (tempo: Double, beatsPerBar: Double, loop: Loop?, metronome: Bool)? = nil
    var liveQueue: [(channel: String, status: UInt8, d1: UInt8, d2: UInt8)] = []
    var panicAll = false

    /// Where the music is, for the screen. Written by the audio thread.
    public private(set) var position: Double = 0
    public private(set) var isPlaying = false

    public init(sampleRate: Double) {
        self.sampleRate = sampleRate
        click = Click(sampleRate: sampleRate)
        reverb = Reverb(sampleRate: sampleRate)
        clickL = [Float](repeating: 0, count: Renderer.maxFrames); clickR = clickL
        sendL = clickL; sendR = clickL
        liveQueue.reserveCapacity(1024)
        segments.reserveCapacity(2)
    }

    // ------------------------------------------------------- main thread --
    /// The song as the audio thread should play it. Instruments whose track,
    /// device and preset have not changed are kept, so what is sounding goes
    /// on sounding.
    public func update(_ p: Project) {
        os_unfair_lock_lock(&lock)
        let existing = pendingChannels ?? channels
        os_unfair_lock_unlock(&lock)
        var byID: [String: Channel] = [:]
        for c in existing { byID[c.id] = c }
        let anySolo = p.tracks.contains { $0.solo }
        var fresh: [Channel] = []
        for t in p.tracks {
            let sig = Renderer.signature(t)
            let c: Channel
            if let old = byID[t.id], old.signature == sig {
                c = Channel(id: t.id, signature: sig, instrument: old.instrument, capacity: Renderer.maxFrames)
                c.held = old.held
            } else {
                c = Channel(id: t.id, signature: sig, instrument: Renderer.makeInstrument(t, sampleRate: sampleRate), capacity: Renderer.maxFrames)
            }
            c.events = Renderer.events(t)
            let audible = !t.mute && (!anySolo || t.solo)
            let g = audible ? Renderer.gain(t.volume) : 0
            let pan = max(-1, min(1, t.pan))
            c.gainL = Float(Double(g) * cos((pan + 1) * .pi / 4) * sqrt(2))
            c.gainR = Float(Double(g) * sin((pan + 1) * .pi / 4) * sqrt(2))
            c.send = Float(max(0, min(1, t.send)))
            fresh.append(c)
        }
        built = fresh
        os_unfair_lock_lock(&lock)
        pendingChannels = fresh
        pendingSettings = (p.tempo, p.beatsPerBar, p.loop.on && p.loop.end > p.loop.start ? p.loop : nil, pendingSettings?.metronome ?? metronome)
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
    /// A note or controller from a MIDI keyboard, played now on a track.
    public func live(_ trackID: String, _ status: UInt8, _ d1: UInt8, _ d2: UInt8) {
        os_unfair_lock_lock(&lock)
        if liveQueue.count < 1000 { liveQueue.append((trackID, status, d1, d2)) }
        os_unfair_lock_unlock(&lock)
    }
    public func panic() { os_unfair_lock_lock(&lock); panicAll = true; os_unfair_lock_unlock(&lock) }

    public func peak(of trackID: String) -> Float { built.first { $0.id == trackID }?.peak ?? 0 }

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
            // Notes held on a track that left or whose instrument changed stop.
            let keep = Set(fresh.map { ObjectIdentifier($0.instrument) })
            for c in channels where !keep.contains(ObjectIdentifier(c.instrument)) { c.releaseAll() }
            channels = fresh
            for c in channels { c.seek(beat) }
            pendingChannels = nil
        }
        if let s = pendingSettings {
            tempo = max(1, s.tempo); beatsPerBar = s.beatsPerBar; loop = s.loop; metronome = s.metronome
            pendingSettings = nil
        }
        if let t = pendingTransport {
            for c in channels { c.releaseAll() }
            playing = t.playing
            beat = t.beat
            for c in channels { c.seek(beat) }
            pendingTransport = nil
        }
        if panicAll {
            for c in channels { c.releaseAll(); c.instrument.allOff() }
            panicAll = false
        }
        for m in liveQueue {
            if let c = channels.first(where: { $0.id == m.channel }) {
                let kind = m.status & 0xF0
                if kind == 0x90 && m.d2 > 0 { c.instrument.noteOn(Int(m.d1), Int(m.d2)) }
                else if kind == 0x80 || kind == 0x90 { c.instrument.noteOff(Int(m.d1)) }
                else if kind == 0xB0 { c.instrument.cc(Int(m.d1), Int(m.d2)) }
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

        for c in channels {
            c.bufL.withUnsafeMutableBufferPointer { bl in
                c.bufR.withUnsafeMutableBufferPointer { br in
                    let L = bl.baseAddress!, R = br.baseAddress!
                    for i in 0..<n { L[i] = 0; R[i] = 0 }
                    for (si, seg) in segments.enumerated() {
                        if si > 0 { c.releaseAll(); c.seek(seg.beat) }
                        var pos = seg.from
                        let end = seg.from + seg.count
                        if playing {
                            let b1 = seg.beat + Double(seg.count) * beatsPerFrame
                            while c.next < c.events.count && c.events[c.next].beat < b1 {
                                let e = c.events[c.next]
                                let off = seg.from + max(0, min(seg.count, Int(((e.beat - seg.beat) / beatsPerFrame).rounded())))
                                if off > pos { c.instrument.render(off - pos, L + pos, R + pos); pos = off }
                                c.dispatch(e)
                                c.next += 1
                            }
                        }
                        if end > pos { c.instrument.render(end - pos, L + pos, R + pos) }
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
            }
        }

        // The metronome: a click on every beat, higher on the bar's first.
        clickL.withUnsafeMutableBufferPointer { cl in
            clickR.withUnsafeMutableBufferPointer { cr in
                let L = cl.baseAddress!, R = cr.baseAddress!
                var pos = 0
                if playing && metronome {
                    for seg in segments where seg.count > 0 {
                        var b = (seg.beat - 1e-9).rounded(.up)
                        let b1 = seg.beat + Double(seg.count) * beatsPerFrame
                        while b < b1 - 1e-12 {
                            let off = seg.from + min(seg.count - 1, max(0, Int(((b - seg.beat) / beatsPerFrame).rounded())))
                            if off > pos { click.render(off - pos, L + pos, R + pos); pos = off }
                            let down = abs(b / beatsPerBar - (b / beatsPerBar).rounded()) < 1e-6
                            click.noteOn(down ? 77 : 76, down ? 120 : 90)
                            b += 1
                        }
                    }
                }
                if n > pos { click.render(n - pos, L + pos, R + pos) }
            }
        }

        sendL.withUnsafeMutableBufferPointer { sl in
            sendR.withUnsafeMutableBufferPointer { sr in
                reverb.process(n, sl.baseAddress!, sr.baseAddress!, outL, outR)
            }
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
