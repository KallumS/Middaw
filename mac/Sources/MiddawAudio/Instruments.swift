import Foundation

// Middaw's built-in sounds, ported from the browser version's synths.js with
// the same presets and the same arithmetic. Everything here runs on the audio
// thread, so nothing allocates after it is made: voices and hits are fixed
// pools.
//
// Every instrument has the same face: noteOn, noteOff, cc, render.

@inline(__always) func mtof(_ p: Double) -> Double { 440 * pow(2, (p - 69) / 12) }
@inline(__always) func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double { x < a ? a : (x > b ? b : x) }

public protocol Instrument: AnyObject {
    func noteOn(_ pitch: Int, _ velocity: Int)
    func noteOff(_ pitch: Int)
    func cc(_ number: Int, _ value: Int)
    func allOff()
    /// Add `frames` samples into the two buffers.
    func render(_ frames: Int, _ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>)
}

/// A cheap noise source, the same LCG the browser version used.
struct Noise {
    var seed: Int32 = 22222
    @inline(__always) mutating func next() -> Double {
        seed = seed &* 196314165 &+ 907633515
        return Double(seed) / 2147483648
    }
}

// ----------------------------------------------------------------- synth --
public struct SynthPreset {
    public enum Osc { case saw, square, tri, sine, fm, bell, organ, ks }
    var osc: Osc
    var ratio = 1.0, index = 0.0, indexDecay = 0.0
    var a = 0.01, d = 0.2, s = 0.8, r = 0.2
    var cutoff = 8000.0, env = 0.0, envA = 0.0, envD = 0.4, res = 0.0
    var detune = 0.0, vib = 0.0, vibDepth = 0.0, vibDelay = 0.0
    var width = 0.5, sub = 0.0, breath = 0.0, noise = 0.0, drop = 0.0
    var damp = 0.5, trem = 0.0, hammer = 0.0
    var gain = 0.4

    public static let all: [(id: String, name: String, preset: SynthPreset)] = [
        ("keys", "Keys", SynthPreset(osc: .fm, ratio: 1, index: 2.2, indexDecay: 1.6, a: 0.002, d: 1.4, s: 0.15, r: 0.35, cutoff: 9000, gain: 0.55)),
        ("piano", "Piano", SynthPreset(osc: .fm, ratio: 1, index: 1.6, indexDecay: 2.4, a: 0.002, d: 2.2, s: 0.08, r: 0.5, cutoff: 7000, detune: 0.3, hammer: 0.15, gain: 0.6)),
        ("epiano", "Electric Piano", SynthPreset(osc: .fm, ratio: 1, index: 3.5, indexDecay: 3.0, a: 0.001, d: 2.0, s: 0.25, r: 0.4, cutoff: 12000, trem: 0.15, gain: 0.5)),
        ("strings", "Strings", SynthPreset(osc: .saw, a: 0.18, d: 0.3, s: 0.9, r: 0.45, cutoff: 2600, env: 0.3, res: 0.15, detune: 7, vib: 5.2, vibDepth: 0.12, vibDelay: 0.3, gain: 0.32)),
        ("solo", "Solo String", SynthPreset(osc: .saw, a: 0.06, d: 0.2, s: 0.95, r: 0.25, cutoff: 3600, env: 0.4, res: 0.2, detune: 3, vib: 5.6, vibDepth: 0.22, vibDelay: 0.25, gain: 0.34)),
        ("brass", "Brass", SynthPreset(osc: .saw, a: 0.05, d: 0.25, s: 0.85, r: 0.18, cutoff: 1400, env: 2.2, envA: 0.06, envD: 0.35, res: 0.1, detune: 4, vib: 5, vibDepth: 0.06, vibDelay: 0.4, gain: 0.34)),
        ("reed", "Reed", SynthPreset(osc: .square, a: 0.03, d: 0.1, s: 0.9, r: 0.12, cutoff: 2200, env: 0.6, res: 0.25, vib: 5.4, vibDepth: 0.08, vibDelay: 0.35, width: 0.32, breath: 0.03, gain: 0.26)),
        ("flute", "Flute", SynthPreset(osc: .tri, a: 0.06, d: 0.1, s: 0.9, r: 0.15, cutoff: 5000, env: 0.2, vib: 5.2, vibDepth: 0.1, vibDelay: 0.3, breath: 0.08, gain: 0.42)),
        ("pluck", "Pluck", SynthPreset(osc: .ks, a: 0.001, d: 0.1, s: 1, r: 0.3, cutoff: 8000, damp: 0.5, gain: 0.7)),
        ("harp", "Harp", SynthPreset(osc: .ks, a: 0.001, d: 0.1, s: 1, r: 0.8, cutoff: 9000, damp: 0.25, gain: 0.7)),
        ("bass", "Bass", SynthPreset(osc: .saw, a: 0.004, d: 0.35, s: 0.6, r: 0.1, cutoff: 900, env: 1.8, envD: 0.25, res: 0.2, sub: 0.5, gain: 0.45)),
        ("organ", "Organ", SynthPreset(osc: .organ, a: 0.005, d: 0.05, s: 1, r: 0.06, cutoff: 9000, gain: 0.32)),
        ("pad", "Pad", SynthPreset(osc: .saw, a: 0.6, d: 0.8, s: 0.8, r: 1.2, cutoff: 1800, env: 0.5, envA: 0.9, res: 0.15, detune: 11, vib: 0.3, vibDepth: 0.05, gain: 0.26)),
        ("bell", "Bell", SynthPreset(osc: .bell, ratio: 3.5, index: 3, indexDecay: 1.2, a: 0.001, d: 2.8, s: 0, r: 1.2, cutoff: 14000, gain: 0.35)),
        ("mallet", "Mallet", SynthPreset(osc: .bell, ratio: 4, index: 1.2, indexDecay: 6, a: 0.001, d: 0.7, s: 0, r: 0.3, cutoff: 12000, gain: 0.5)),
        ("timpani", "Timpani", SynthPreset(osc: .sine, a: 0.002, d: 1.4, s: 0, r: 0.6, cutoff: 3000, noise: 0.25, drop: 0.03, gain: 0.7)),
        ("lead", "Lead", SynthPreset(osc: .square, a: 0.005, d: 0.2, s: 0.8, r: 0.12, cutoff: 3000, env: 1.2, res: 0.3, vib: 5.5, vibDepth: 0.1, vibDelay: 0.4, width: 0.5, gain: 0.25)),
        ("choir", "Choir", SynthPreset(osc: .saw, a: 0.25, d: 0.3, s: 0.85, r: 0.5, cutoff: 1500, env: 0.2, res: 0.45, detune: 9, vib: 5, vibDepth: 0.1, vibDelay: 0.2, gain: 0.28)),
    ]

    public static func named(_ id: String?) -> SynthPreset {
        all.first { $0.id == id }?.preset ?? all[0].preset
    }
}

final class SynthVoice {
    var on = false, released = false, held = false
    var pitch = 0, vel = 0.0, age = 0
    var ph1 = 0.0, ph2 = 0.0, ph3 = 0.0, mph = 0.0, lfo = 0.0
    var env = 0.0, stage = 0, lp1 = 0.0, lp2 = 0.0
    var ks = [Double](repeating: 0, count: 4096), ksLen = 2, ksi = 0
}

@inline(__always) func polyBlep(_ t0: Double, _ dt: Double) -> Double {
    if t0 < dt { let t = t0 / dt; return t + t - t * t - 1 }
    if t0 > 1 - dt { let t = (t0 - 1) / dt; return t * t + t + t + 1 }
    return 0
}

public final class Synth: Instrument {
    let sr: Double
    var p: SynthPreset
    var voices: [SynthVoice] = (0..<24).map { _ in SynthVoice() }
    var cc1 = 1.0, cc11 = 1.0, cc7 = 1.0, sustain = false
    var noise = Noise()
    var random = Noise(seed: 1234)

    public init(sampleRate: Double, preset: String?) {
        sr = sampleRate
        p = SynthPreset.named(preset)
    }

    public func noteOn(_ pitch: Int, _ velocity: Int) {
        if velocity <= 0 { noteOff(pitch); return }
        var v: SynthVoice? = nil, oldest: SynthVoice? = nil
        for x in voices {
            if !x.on { v = x; break }
            if oldest == nil || x.age > oldest!.age { oldest = x }
        }
        let voice = v ?? oldest!
        voice.on = true; voice.released = false; voice.held = false
        voice.pitch = pitch; voice.vel = Double(velocity) / 127; voice.age = 0
        voice.env = 0; voice.stage = 0; voice.lp1 *= 0.2; voice.lp2 *= 0.2
        voice.ph1 = abs(random.next()); voice.ph2 = abs(random.next()); voice.ph3 = 0; voice.mph = 0
        if p.osc == .ks {
            let len = min(voice.ks.count, max(2, Int((sr / mtof(Double(pitch))).rounded())))
            voice.ksLen = len; voice.ksi = 0
            // A pluck: noise, darker when played softly.
            let c = 0.3 + 0.7 * voice.vel
            var y = 0.0
            for k in 0..<len { y += c * (noise.next() - y); voice.ks[k] = y }
        }
    }

    public func noteOff(_ pitch: Int) {
        for v in voices where v.on && v.pitch == pitch && !v.released {
            if sustain { v.held = true } else { v.released = true; v.stage = 3 }
        }
    }

    public func allOff() { for v in voices { v.on = false } }

    public func cc(_ n: Int, _ value: Int) {
        let x = Double(value) / 127
        switch n {
        case 1: cc1 = 0.25 + 0.75 * x
        case 11: cc11 = x
        case 7: cc7 = x
        case 64:
            sustain = value >= 64
            if !sustain { for v in voices where v.held { v.held = false; v.released = true; v.stage = 3 } }
        case 120, 123: allOff()
        default: break
        }
    }

    public func render(_ n: Int, _ L: UnsafeMutablePointer<Float>, _ R: UnsafeMutablePointer<Float>) {
        let p = self.p, dt = 1 / sr
        let level = p.gain * cc11 * cc7
        let bright = cc1
        for v in voices where v.on {
            let f0 = mtof(Double(v.pitch))
            let aRate = dt / max(0.0005, p.a), dRate = dt / max(0.001, p.d), rRate = dt / max(0.005, p.r)
            let vel = v.vel
            let baseCut = p.cutoff * (0.35 + 0.65 * vel) * bright * (1 + Double(v.pitch - 60) / 96)
            let pan = clamp(Double(v.pitch - 64) / 90, -0.4, 0.4)
            let gl = Float(sqrt(0.5 * (1 - pan))), gr = Float(sqrt(0.5 * (1 + pan)))
            for i in 0..<n {
                if v.stage == 0 { v.env += aRate; if v.env >= 1 { v.env = 1; v.stage = 1 } }
                else if v.stage == 1 { v.env -= (v.env - p.s) * dRate * 4; if abs(v.env - p.s) < 0.001 { v.stage = 2 } }
                else if v.stage == 3 { v.env -= v.env * rRate * 5; if v.env < 0.0005 { v.on = false; break } }
                if p.s == 0 && v.stage == 2 { v.env -= v.env * dRate * 4 }
                let t = Double(v.age) * dt
                v.age += 1
                var vib = 0.0
                if p.vib > 0 {
                    v.lfo += p.vib * dt
                    let depth = p.vibDepth * min(1, max(0, (t - p.vibDelay) * 2))
                    vib = sin(2 * .pi * v.lfo) * depth
                }
                var f = f0 * pow(2, vib / 12)
                if p.drop > 0 { f *= 1 + p.drop * exp(-t * 30) }
                let inc = f * dt
                var s = 0.0
                switch p.osc {
                case .saw:
                    let inc2 = inc * pow(2, p.detune / 1200)
                    s = (2 * v.ph1 - 1) - polyBlep(v.ph1, inc)
                    s += (2 * v.ph2 - 1) - polyBlep(v.ph2, inc2)
                    s *= 0.5
                    v.ph1 += inc; if v.ph1 >= 1 { v.ph1 -= 1 }
                    v.ph2 += inc2; if v.ph2 >= 1 { v.ph2 -= 1 }
                    if p.sub > 0 { v.ph3 += inc * 0.5; if v.ph3 >= 1 { v.ph3 -= 1 }; s += p.sub * sin(2 * .pi * v.ph3) }
                case .square:
                    let w = p.width
                    s = (v.ph1 < w ? 1 : -1) + polyBlep(v.ph1, inc) - polyBlep((v.ph1 + 1 - w).truncatingRemainder(dividingBy: 1), inc)
                    v.ph1 += inc; if v.ph1 >= 1 { v.ph1 -= 1 }
                case .tri:
                    s = 1 - 4 * abs(v.ph1 - 0.5)
                    s = 0.7 * s + 0.3 * sin(2 * .pi * v.ph1)
                    v.ph1 += inc; if v.ph1 >= 1 { v.ph1 -= 1 }
                case .sine:
                    s = sin(2 * .pi * v.ph1)
                    v.ph1 += inc; if v.ph1 >= 1 { v.ph1 -= 1 }
                case .fm, .bell:
                    let idx = p.index * (0.4 + 0.6 * vel) * exp(-t * p.indexDecay) * bright
                    let m = sin(2 * .pi * v.mph)
                    v.mph += inc * p.ratio; if v.mph >= 1 { v.mph -= 1 }
                    s = sin(2 * .pi * v.ph1 + idx * m)
                    if p.detune != 0 {
                        s = 0.6 * s + 0.4 * sin(2 * .pi * v.ph2 + idx * 0.5 * m)
                        v.ph2 += inc * (1 + p.detune / 1200); if v.ph2 >= 1 { v.ph2 -= 1 }
                    }
                    if p.trem > 0 { s *= 1 - p.trem * (0.5 + 0.5 * sin(2 * .pi * 5.5 * t)) }
                    if p.hammer > 0 && t < 0.01 { s += p.hammer * noise.next() * (1 - t / 0.01) }
                    v.ph1 += inc; if v.ph1 >= 1 { v.ph1 -= 1 }
                case .organ:
                    let ph = 2 * .pi * v.ph1
                    s = 0.5 * sin(ph) + 0.35 * sin(2 * ph) + 0.25 * sin(3 * ph) + 0.15 * sin(4 * ph) + 0.1 * sin(6 * ph)
                    v.ph1 += inc; if v.ph1 >= 1 { v.ph1 -= 1 }
                case .ks:
                    let len = v.ksLen, k = v.ksi
                    let nxt = (k + 1) % len
                    let damp = 0.5 - p.damp * 0.02
                    let out = v.ks[k]
                    v.ks[k] = (v.ks[k] + v.ks[nxt]) * damp
                    v.ksi = nxt
                    s = out * 1.6
                }
                if p.breath > 0 { s += p.breath * noise.next() * (0.5 + vel) }
                if p.noise > 0 { s += p.noise * noise.next() * exp(-t * 40) }
                var cut = baseCut
                if p.env != 0 {
                    let fe = p.envA > 0 ? min(1, t / p.envA) * exp(-max(0, t - p.envA) / p.envD) : exp(-t / p.envD)
                    cut *= 1 + p.env * fe * vel
                }
                let g = 1 - exp(-2 * .pi * clamp(cut, 40, sr * 0.45) * dt)
                v.lp1 += g * (s - v.lp1)
                v.lp2 += g * (v.lp1 - v.lp2)
                let y = Float((p.res > 0 ? v.lp2 + p.res * (v.lp1 - v.lp2) : v.lp2) * v.env * level * (0.35 + 0.65 * vel))
                L[i] += y * gl
                R[i] += y * gr
            }
        }
    }
}

// ------------------------------------------------------------------- kit --
/// A General MIDI drum kit, every drum synthesised.
public final class Kit: Instrument {
    struct Hit { var active = false, pitch = 0, vel = 0.0, t = 0.0, ph = 0.0, ph2 = 0.0, bp1 = 0.0, bp2 = 0.0, hp = 0.0, choke = false }
    let sr: Double
    var hits = [Hit](repeating: Hit(), count: 48)
    var next = 0
    var noise = Noise(seed: 1234567)
    var cc7 = 1.0, cc11 = 1.0

    public init(sampleRate: Double) { sr = sampleRate }

    public func noteOn(_ pitch: Int, _ velocity: Int) {
        guard velocity > 0 else { return }
        // a closed or pedal hat chokes an open one
        if pitch == 42 || pitch == 44 { for i in hits.indices where hits[i].active && hits[i].pitch == 46 { hits[i].choke = true } }
        hits[next] = Hit(active: true, pitch: pitch, vel: Double(velocity) / 127)
        next = (next + 1) % hits.count
    }
    public func noteOff(_ pitch: Int) {}
    public func allOff() { for i in hits.indices { hits[i].active = false } }
    public func cc(_ n: Int, _ value: Int) {
        if n == 7 { cc7 = Double(value) / 127 }
        if n == 11 { cc11 = Double(value) / 127 }
        if n == 120 || n == 123 { allOff() }
    }

    static let tomBase: [Int: Double] = [41: 80, 43: 95, 45: 115, 47: 135, 48: 160, 50: 190]

    public func render(_ n: Int, _ L: UnsafeMutablePointer<Float>, _ R: UnsafeMutablePointer<Float>) {
        let dt = 1 / sr, level = cc7 * cc11
        for hi in hits.indices where hits[hi].active {
            var h = hits[hi]
            var alive = true
            var pan = 0.0
            for i in 0..<n {
                let t = h.t
                var s = 0.0
                switch h.pitch {
                case 35, 36:                                         // kick
                    let f = 45 + 110 * exp(-t * 28)
                    h.ph += f * dt
                    s = sin(2 * .pi * h.ph) * exp(-t * 7) * 1.1 + (t < 0.003 ? noise.next() * 0.4 : 0)
                    if t > 0.6 { alive = false }
                case 38, 40:                                         // snare
                    h.ph += 185 * dt
                    let nz = noise.next()
                    h.hp += 0.35 * (nz - h.hp)
                    s = sin(2 * .pi * h.ph) * exp(-t * 22) * 0.6 + (nz - h.hp) * exp(-t * 16) * 0.9
                    if t > 0.35 { alive = false }
                case 37:                                             // side stick
                    h.ph += 1800 * dt
                    s = sin(2 * .pi * h.ph) * exp(-t * 90) * 0.7
                    if t > 0.08 { alive = false }
                case 39:                                             // clap
                    let burst: Double = t.truncatingRemainder(dividingBy: 0.011) < 0.004 && t < 0.035 ? 1 : 0
                    let nz = noise.next()
                    h.bp1 += 0.3 * (nz - h.bp1); h.bp2 += 0.3 * (h.bp1 - h.bp2)
                    s = (h.bp1 - h.bp2) * 2.2 * (burst + (t >= 0.035 ? exp(-(t - 0.035) * 14) : 0))
                    if t > 0.4 { alive = false }
                case 42, 44, 46:                                     // hats
                    let nz = noise.next()
                    h.hp += 0.9 * (nz - h.hp)
                    var decay: Double = h.pitch == 46 ? 5 : (h.pitch == 44 ? 30 : 45)
                    if h.choke { decay = 80 }
                    s = (nz - h.hp) * exp(-t * decay) * 0.5
                    pan = 0.25
                    if t > (h.pitch == 46 ? 1.2 : 0.2) || (h.choke && t > 0.05) { alive = false }
                case 41, 43, 45, 47, 48, 50:                         // toms
                    let base = Kit.tomBase[h.pitch] ?? 120
                    h.ph += base * (1 + 0.6 * exp(-t * 18)) * dt
                    s = sin(2 * .pi * h.ph) * exp(-t * 7) * 0.9
                    pan = Double(h.pitch - 45) / 20
                    if t > 0.7 { alive = false }
                case 49, 57, 52, 55:                                 // crash, china, splash
                    let nz = noise.next()
                    h.hp += 0.75 * (nz - h.hp)
                    s = (nz - h.hp) * exp(-t * (h.pitch == 55 ? 6 : 1.6)) * 0.45
                    pan = h.pitch == 57 ? 0.4 : -0.3
                    if t > 3 { alive = false }
                case 51, 59, 53:                                     // ride, bell
                    let nz = noise.next()
                    h.hp += 0.8 * (nz - h.hp)
                    h.ph += 520 * dt; h.ph2 += 1370 * dt
                    let ping = (sin(2 * .pi * h.ph) + sin(2 * .pi * h.ph2)) * (h.pitch == 53 ? 0.35 : 0.12)
                    s = ((nz - h.hp) * 0.22 + ping) * exp(-t * (h.pitch == 53 ? 3 : 2.2))
                    pan = 0.35
                    if t > 2.5 { alive = false }
                case 54, 69, 70, 82:                                 // tambourine, cabasa, maracas, shaker
                    let nz = noise.next()
                    h.hp += 0.85 * (nz - h.hp)
                    s = (nz - h.hp) * exp(-t * (h.pitch == 54 ? 9 : 25)) * 0.45
                    pan = -0.3
                    if t > 0.5 { alive = false }
                case 56:                                             // cowbell
                    h.ph += 540 * dt; h.ph2 += 800 * dt
                    let a: Double = h.ph.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : -1
                    let b: Double = h.ph2.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : -1
                    s = (a + b) * 0.18 * exp(-t * 9)
                    if t > 0.5 { alive = false }
                case 75, 76, 77:                                     // claves, woodblocks
                    h.ph += (h.pitch == 75 ? 2500 : h.pitch == 76 ? 1300 : 1000) * dt
                    s = sin(2 * .pi * h.ph) * exp(-t * 60) * 0.6
                    if t > 0.15 { alive = false }
                default:
                    h.ph += (200 + Double(h.pitch - 60) * 12) * dt
                    s = sin(2 * .pi * h.ph) * exp(-t * 20) * 0.5
                    if t > 0.3 { alive = false }
                }
                s *= h.vel * 0.8 * level
                L[i] += Float(s * (1 - max(0, pan)))
                R[i] += Float(s * (1 + min(0, pan)))
                h.t += dt
                if !alive { break }
            }
            h.active = alive
            hits[hi] = h
        }
    }
}

// ---------------------------------------------- the Instant Instrument --
/// A sound dropped on a track, played across the keyboard: its own pitch at
/// `root`, transposed by speed elsewhere, as a sampler does.
public final class Sampler: Instrument {
    struct Voice { var active = false, pitch = 0, pos = 0.0, step = 1.0, vel = 0.0, env = 0.0, rel = false, held = false }
    let sr: Double
    var left: [Float] = [], right: [Float] = []
    var rate = 44100.0, root = 60
    var voices = [Voice](repeating: Voice(), count: 32)
    var next = 0
    var cc7 = 1.0, cc11 = 1.0, sustain = false

    public init(sampleRate: Double) { sr = sampleRate }

    /// Call before playback starts, not from the audio thread.
    public func load(left: [Float], right: [Float]?, rate: Double, root: Int) {
        self.left = left; self.right = right ?? left; self.rate = rate; self.root = root
    }

    public func noteOn(_ pitch: Int, _ velocity: Int) {
        if velocity <= 0 { noteOff(pitch); return }
        guard !left.isEmpty else { return }
        voices[next] = Voice(active: true, pitch: pitch, pos: 0, step: pow(2, Double(pitch - root) / 12) * rate / sr,
                             vel: Double(velocity) / 127)
        next = (next + 1) % voices.count
    }
    public func noteOff(_ pitch: Int) {
        for i in voices.indices where voices[i].active && voices[i].pitch == pitch && !voices[i].rel {
            if sustain { voices[i].held = true } else { voices[i].rel = true }
        }
    }
    public func allOff() { for i in voices.indices { voices[i].active = false } }
    public func cc(_ n: Int, _ value: Int) {
        switch n {
        case 7: cc7 = Double(value) / 127
        case 11: cc11 = Double(value) / 127
        case 64:
            sustain = value >= 64
            if !sustain { for i in voices.indices where voices[i].held { voices[i].held = false; voices[i].rel = true } }
        case 120, 123: allOff()
        default: break
        }
    }
    public func render(_ n: Int, _ L: UnsafeMutablePointer<Float>, _ R: UnsafeMutablePointer<Float>) {
        let len = left.count
        guard len > 1 else { return }
        let aR = 1 / (0.002 * sr), rR = 1 / (0.25 * sr), lev = cc7 * cc11 * 0.8
        for vi in voices.indices where voices[vi].active {
            var v = voices[vi]
            for i in 0..<n {
                if v.rel { v.env -= rR; if v.env <= 0 { v.active = false; break } }
                else if v.env < 1 { v.env = min(1, v.env + aR) }
                let k = Int(v.pos)
                if k + 1 >= len { v.active = false; break }
                let fr = Float(v.pos - Double(k)), g = Float(v.env * v.vel * lev)
                L[i] += (left[k] + (left[k + 1] - left[k]) * fr) * g
                R[i] += (right[k] + (right[k + 1] - right[k]) * fr) * g
                v.pos += v.step
            }
            voices[vi] = v
        }
    }
}

// ---------------------------------------------------------------- click --
public final class Click: Instrument {
    struct Hit { var active = false, f = 1320.0, t = 0.0, v = 0.0, ph = 0.0 }
    let sr: Double
    var hits = [Hit](repeating: Hit(), count: 8)
    var next = 0
    public init(sampleRate: Double) { sr = sampleRate }
    public func noteOn(_ pitch: Int, _ velocity: Int) {
        hits[next] = Hit(active: true, f: pitch >= 76 ? 1760 : 1320, t: 0, v: Double(velocity) / 127)
        next = (next + 1) % hits.count
    }
    public func noteOff(_ pitch: Int) {}
    public func allOff() { for i in hits.indices { hits[i].active = false } }
    public func cc(_ n: Int, _ value: Int) {}
    public func render(_ n: Int, _ L: UnsafeMutablePointer<Float>, _ R: UnsafeMutablePointer<Float>) {
        let dt = 1 / sr
        for hi in hits.indices where hits[hi].active {
            var h = hits[hi]
            for i in 0..<n {
                h.ph += h.f * dt
                let s = Float(sin(2 * .pi * h.ph) * exp(-h.t * 70) * 0.35 * h.v)
                L[i] += s; R[i] += s; h.t += dt
            }
            h.active = h.t < 0.1
            hits[hi] = h
        }
    }
}
