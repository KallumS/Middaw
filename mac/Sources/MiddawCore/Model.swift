import Foundation

// The song: what Middaw saves, plays and edits.
//
// Times are in beats (quarter notes). A note's start is from its clip's start.
// The JSON is the same `.middaw` file the browser version wrote, so songs made
// there open here. Every field decodes with a default, so an older or newer
// file still opens.

public func makeID(_ prefix: String) -> String {
    let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    return prefix + String((0..<10).map { _ in alphabet.randomElement()! })
}

/// A note as the DAW keeps it.
public struct Note: Codable, Hashable {
    public var start: Double
    public var len: Double
    public var pitch: Int
    public var vel: Int

    public init(start: Double, len: Double, pitch: Int, vel: Int = 100) {
        self.start = start; self.len = len; self.pitch = pitch; self.vel = vel
    }

    enum CodingKeys: String, CodingKey { case start, len, pitch, vel, duration, velocity }

    /// Reads the DAW's `len`/`vel`, or `duration`/`velocity` as the composer
    /// and MIDI files say it.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = try c.decodeNumber(.start) ?? 0
        let l = try c.decodeNumber(.len) ?? c.decodeNumber(.duration) ?? 0.25
        len = l > 0 ? l : 0.25
        pitch = Int((try c.decodeNumber(.pitch) ?? 60).rounded())
        let v = try c.decodeNumber(.vel) ?? c.decodeNumber(.velocity) ?? 100
        vel = max(1, min(127, Int(v.rounded())))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(start, forKey: .start); try c.encode(len, forKey: .len)
        try c.encode(pitch, forKey: .pitch); try c.encode(vel, forKey: .vel)
    }

    public var end: Double { start + len }
}

/// A controller point: at `beat` (from the clip's start), `value` 0-127.
public struct CCPoint: Hashable {
    public var beat: Double
    public var value: Int
    public init(beat: Double, value: Int) { self.beat = beat; self.value = value }
}

public struct ClipSource: Codable, Hashable {
    public var generator: String?
    public var title: String?
    public var seed: Int?
    public init(generator: String? = nil, title: String? = nil, seed: Int? = nil) {
        self.generator = generator; self.title = title; self.seed = seed
    }
}

public struct Clip: Codable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var start: Double
    public var length: Double
    public var notes: [Note]
    /// Controller number -> its points, in order.
    public var cc: [Int: [CCPoint]]
    public var source: ClipSource?

    public init(id: String = makeID("c"), name: String = "", start: Double = 0, length: Double = 4,
                notes: [Note] = [], cc: [Int: [CCPoint]] = [:], source: ClipSource? = nil) {
        self.id = id; self.name = name; self.start = start; self.length = length
        self.notes = notes; self.cc = cc; self.source = source
    }

    public var end: Double { start + length }

    enum CodingKeys: String, CodingKey { case id, name, start, length, notes, cc, source }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? makeID("c")
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        start = try c.decodeNumber(.start) ?? 0
        length = try c.decodeNumber(.length) ?? 4
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
        source = try? c.decodeIfPresent(ClipSource.self, forKey: .source)
        var lanes: [Int: [CCPoint]] = [:]
        if let raw = try? c.decodeIfPresent([String: [[Double]]].self, forKey: .cc) {
            for (k, pts) in raw {
                guard let n = Int(k) else { continue }
                lanes[n] = pts.compactMap { $0.count >= 2 ? CCPoint(beat: $0[0], value: Int($0[1].rounded())) : nil }
            }
        }
        cc = lanes
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name)
        try c.encode(start, forKey: .start); try c.encode(length, forKey: .length)
        try c.encode(notes, forKey: .notes)
        var raw: [String: [[Double]]] = [:]
        for (k, pts) in cc { raw[String(k)] = pts.map { [$0.beat, Double($0.value)] } }
        try c.encode(raw, forKey: .cc)
        try c.encodeIfPresent(source, forKey: .source)
    }
}

/// A sound kept in the song (dropped on a sampler), as 16-bit PCM in base64.
public struct Sample: Codable, Hashable {
    public var name: String
    public var rate: Double
    public var channels: Int
    public var data: String
    public var root: Int?
    public init(name: String, rate: Double, channels: Int, data: String, root: Int? = nil) {
        self.name = name; self.rate = rate; self.channels = channels; self.data = data; self.root = root
    }
}

/// Any JSON, for a device's own saved state.
public indirect enum JSONValue: Codable, Hashable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

/// An instrument or effect on a track: Middaw's own (synth, kit, sampler) or
/// one of the family's JSFX, with its slider values and saved state.
public struct Device: Codable, Hashable, Identifiable {
    public var id: String
    public var device: String
    public var preset: String?
    public var sliders: [Int: Double]
    public var state: JSONValue?
    public var sample: Sample?
    public var samples: [Sample?]?
    public var presetIndex: Int?
    public var presetName: String?

    public init(id: String = makeID("d"), device: String, preset: String? = nil, sliders: [Int: Double] = [:]) {
        self.id = id; self.device = device; self.preset = preset; self.sliders = sliders
    }

    enum CodingKeys: String, CodingKey { case id, device, preset, sliders, state, sample, samples, presetIndex, presetName }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? makeID("d")
        device = try c.decodeIfPresent(String.self, forKey: .device) ?? "synth"
        preset = try? c.decodeIfPresent(String.self, forKey: .preset)
        var s: [Int: Double] = [:]
        if let raw = try? c.decodeIfPresent([String: Double].self, forKey: .sliders) {
            for (k, v) in raw { if let n = Int(k) { s[n] = v } }
        }
        sliders = s
        state = try? c.decodeIfPresent(JSONValue.self, forKey: .state)
        sample = try? c.decodeIfPresent(Sample.self, forKey: .sample)
        samples = try? c.decodeIfPresent([Sample?].self, forKey: .samples)
        presetIndex = try? c.decodeIfPresent(Int.self, forKey: .presetIndex)
        presetName = try? c.decodeIfPresent(String.self, forKey: .presetName)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(device, forKey: .device)
        try c.encodeIfPresent(preset, forKey: .preset)
        try c.encode(Dictionary(uniqueKeysWithValues: sliders.map { (String($0.key), $0.value) }), forKey: .sliders)
        try c.encodeIfPresent(state, forKey: .state)
        try c.encodeIfPresent(sample, forKey: .sample)
        try c.encodeIfPresent(samples, forKey: .samples)
        try c.encodeIfPresent(presetIndex, forKey: .presetIndex)
        try c.encodeIfPresent(presetName, forKey: .presetName)
    }
}

public struct Track: Codable, Hashable, Identifiable {
    public var id: String
    public var name: String
    /// Midi Catalogue's orchestra id: range, clef, how many notes at once.
    public var instrument: String
    /// melody, counter, chords, bass, drums - or empty.
    public var role: String
    public var drums: Bool
    public var sound: Device
    public var midiFx: [Device]
    public var audioFx: [Device]
    /// 0.8 is unity; the fader is in dB, (volume - 0.8) * 60.
    public var volume: Double
    public var pan: Double
    /// To the reverb return.
    public var send: Double
    public var mute: Bool
    public var solo: Bool
    public var arm: Bool
    public var clips: [Clip]

    public init(id: String = makeID("t"), name: String = "Track", instrument: String = "pno", role: String = "",
                drums: Bool = false, sound: Device? = nil) {
        self.id = id; self.name = name; self.instrument = instrument; self.role = role; self.drums = drums
        self.sound = sound ?? Device(device: drums ? "kit" : "synth", preset: drums ? nil : "keys")
        midiFx = []; audioFx = []; volume = 0.8; pan = 0; send = 0
        mute = false; solo = false; arm = false; clips = []
    }

    enum CodingKeys: String, CodingKey {
        case id, name, instrument, role, drums, sound, midiFx, audioFx, volume, pan, send, mute, solo, arm, clips
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? makeID("t")
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Track"
        instrument = try c.decodeIfPresent(String.self, forKey: .instrument) ?? "pno"
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        drums = try c.decodeIfPresent(Bool.self, forKey: .drums) ?? false
        sound = try c.decodeIfPresent(Device.self, forKey: .sound) ?? Device(device: drums ? "kit" : "synth")
        midiFx = try c.decodeIfPresent([Device].self, forKey: .midiFx) ?? []
        audioFx = try c.decodeIfPresent([Device].self, forKey: .audioFx) ?? []
        volume = try c.decodeNumber(.volume) ?? 0.8
        pan = try c.decodeNumber(.pan) ?? 0
        send = try c.decodeNumber(.send) ?? 0
        mute = try c.decodeIfPresent(Bool.self, forKey: .mute) ?? false
        solo = try c.decodeIfPresent(Bool.self, forKey: .solo) ?? false
        arm = try c.decodeIfPresent(Bool.self, forKey: .arm) ?? false
        clips = try c.decodeIfPresent([Clip].self, forKey: .clips) ?? []
    }

    /// Every note on the track, in song time, in order.
    public var notes: [Note] {
        var out: [Note] = []
        for c in clips {
            for n in c.notes where n.start < c.length - 1e-9 {
                out.append(Note(start: c.start + n.start, len: min(n.len, c.length - n.start), pitch: n.pitch, vel: n.vel))
            }
        }
        return out.sorted { $0.start != $1.start ? $0.start < $1.start : $0.pitch < $1.pitch }
    }

    public func clip(at beat: Double) -> Clip? {
        clips.first { beat >= $0.start - 1e-9 && beat < $0.end - 1e-9 }
    }
}

public struct Loop: Codable, Hashable {
    public var on: Bool
    public var start: Double
    public var end: Double
    public init(on: Bool = false, start: Double = 0, end: Double = 16) { self.on = on; self.start = start; self.end = end }
}

/// The reverb return: an effects chain every track can send to.
public struct Return: Codable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var audioFx: [Device]
    public init(id: String = "return", name: String = "Reverb", audioFx: [Device] = []) {
        self.id = id; self.name = name; self.audioFx = audioFx
    }
}

public struct Project: Codable, Hashable {
    public var version: Int
    public var title: String
    public var tempo: Double
    public var meter: [Int]
    public var key: Key
    public var bars: Int
    public var loop: Loop
    public var tracks: [Track]
    public var returns: [Return]

    public init(title: String = "Untitled", tempo: Double = 110, meter: [Int] = [4, 4], key: Key = Key(), bars: Int = 32) {
        version = 1; self.title = title; self.tempo = tempo; self.meter = meter; self.key = key
        self.bars = bars; loop = Loop(); tracks = []; returns = []
    }

    enum CodingKeys: String, CodingKey { case version, title, tempo, meter, key, bars, loop, tracks, returns }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        tempo = try c.decodeNumber(.tempo) ?? 110
        let m = try c.decodeIfPresent([Int].self, forKey: .meter) ?? [4, 4]
        meter = m.count == 2 && m[0] > 0 && m[1] > 0 ? m : [4, 4]
        key = try c.decodeIfPresent(Key.self, forKey: .key) ?? Key()
        bars = try c.decodeIfPresent(Int.self, forKey: .bars) ?? 32
        loop = try c.decodeIfPresent(Loop.self, forKey: .loop) ?? Loop()
        tracks = try c.decodeIfPresent([Track].self, forKey: .tracks) ?? []
        returns = try c.decodeIfPresent([Return].self, forKey: .returns) ?? []
    }

    // ------------------------------------------------------------- time --
    public var beatsPerBar: Double { Double(meter[0]) * 4 / Double(meter[1]) }

    public func bar(of beat: Double) -> Int { Int((beat / beatsPerBar + 1e-9).rounded(.down)) }

    /// "3.2.1": bar, beat (of the meter's unit), sixteenth.
    public func position(_ beat: Double) -> String {
        let bpb = beatsPerBar, unit = 4 / Double(meter[1])
        let bar = (beat / bpb + 1e-9).rounded(.down)
        let inBar = beat - bar * bpb
        let b = (inBar / unit + 1e-9).rounded(.down)
        let sixteenth = ((inBar - b * unit) / 0.25 + 1e-9).rounded(.down)
        return "\(Int(bar) + 1).\(Int(b) + 1).\(Int(sixteenth) + 1)"
    }

    public func seconds(_ beat: Double) -> Double { beat * 60 / tempo }

    /// Grid lines count from each bar line (Miderator 0028), not from beat 0.
    public func snap(_ beat: Double, grid: Double, floor: Bool = false) -> Double {
        guard grid > 0 else { return beat }
        let bpb = beatsPerBar
        let bar = (beat / bpb + 1e-9).rounded(.down) * bpb
        let off = beat - bar
        let k = floor ? (off / grid + 1e-6).rounded(.down) : (off / grid).rounded()
        return ((bar + k * grid) * 960).rounded() / 960
    }

    /// Where the last note or clip ends.
    public var endOfMusic: Double {
        tracks.flatMap { $0.clips }.map { $0.end }.max() ?? 0
    }

    public func trackIndex(_ id: String) -> Int? { tracks.firstIndex { $0.id == id } }

    public func clipLocation(_ id: String) -> (track: Int, clip: Int)? {
        for (t, track) in tracks.enumerated() {
            if let c = track.clips.firstIndex(where: { $0.id == id }) { return (t, c) }
        }
        return nil
    }
}

extension KeyedDecodingContainer {
    /// A number whether the JSON wrote it as an integer or a float.
    func decodeNumber(_ key: Key) throws -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return Double(i) }
        return nil
    }
}
