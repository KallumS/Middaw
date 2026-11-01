import Foundation

/// Standard MIDI Files, read and written by hand - byte for byte what
/// `middaw/midi.py` writes, which the tests hold it to. MIDI accuracy is the
/// premise of the product, so it is not delegated to a library.
public enum MIDIFile {
    public struct Note: Hashable {
        public var start: Double, duration: Double, pitch: Int, velocity: Double
        public init(start: Double, duration: Double, pitch: Int, velocity: Double) {
            self.start = start; self.duration = duration; self.pitch = pitch; self.velocity = velocity
        }
        public var end: Double { start + duration }
    }

    public struct Control: Hashable {
        public var start: Double, controller: Int, value: Int
        public init(start: Double, controller: Int, value: Int) {
            self.start = start; self.controller = controller; self.value = value
        }
    }

    public struct Track: Hashable {
        public var name: String, program: Int, channel: Int
        public var notes: [Note], controls: [Control]
        public init(name: String, program: Int = 0, channel: Int = 0, notes: [Note] = [], controls: [Control] = []) {
            self.name = name; self.program = program; self.channel = channel; self.notes = notes; self.controls = controls
        }
    }

    public struct Song {
        public var tempo: Double
        public var meter: (Int, Int)
        public var key: Key?
        public var ticksPerBeat: Int
        public var tracks: [Track]
        public init(tempo: Double, meter: (Int, Int), key: Key?, ticksPerBeat: Int = 480, tracks: [Track]) {
            self.tempo = tempo; self.meter = meter; self.key = key; self.ticksPerBeat = ticksPerBeat; self.tracks = tracks
        }
    }

    public struct ParseError: Error, CustomStringConvertible {
        public let description: String
    }

    // ------------------------------------------------------------ writing --
    static func vlq(_ value: Int) -> [UInt8] {
        var v = value
        var buffer: [UInt8] = [UInt8(v & 0x7F)]
        v >>= 7
        while v > 0 { buffer.append(UInt8((v & 0x7F) | 0x80)); v >>= 7 }
        return buffer.reversed()
    }

    static func chunk(_ tag: String, _ payload: [UInt8]) -> [UInt8] {
        Array(tag.utf8) + be32(payload.count) + payload
    }

    static func be32(_ v: Int) -> [UInt8] { [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }

    /// Python's `int(round(x))`: halves go to the even neighbour.
    static func roundInt(_ x: Double) -> Int { Int(x.rounded(.toNearestOrEven)) }

    typealias Event = (tick: Int, order: Int, bytes: [UInt8])

    static func trackChunk(_ events: [Event]) -> [UInt8] {
        // Stable: equal (tick, order) keep the order they were added in.
        let sorted = events.enumerated().sorted {
            ($0.element.tick, $0.element.order, $0.offset) < ($1.element.tick, $1.element.order, $1.offset)
        }.map { $0.element }
        var out: [UInt8] = []
        var previous = 0
        for e in sorted {
            out += vlq(e.tick - previous)
            out += e.bytes
            previous = e.tick
        }
        out += vlq(0) + [0xFF, 0x2F, 0x00]
        return chunk("MTrk", out)
    }

    /// A format-1 Standard MIDI File: a conductor track, then one per track.
    public static func write(_ song: Song) -> Data {
        let tpb = song.ticksPerBeat
        var conductor: [Event] = []
        let us = roundInt(60_000_000.0 / max(1, song.tempo.rounded(.toNearestOrEven)))
        conductor.append((0, 0, [0xFF, 0x51, 0x03, UInt8((us >> 16) & 0xFF), UInt8((us >> 8) & 0xFF), UInt8(us & 0xFF)]))
        let (num, den) = song.meter
        let denPower = max(0, (Int.bitWidth - den.leadingZeroBitCount) - 1)
        conductor.append((0, 0, [0xFF, 0x58, 0x04, UInt8(num & 0xFF), UInt8(denPower), 24, 8]))
        let sig = (song.key ?? Key()).signature
        conductor.append((0, 0, [0xFF, 0x59, 0x02, UInt8(bitPattern: Int8(sig.sharpsOrFlats)), sig.minor ? 1 : 0]))
        let me = Array("Middaw".utf8)
        conductor.append((0, 1, [0xFF, 0x03] + vlq(me.count) + me))
        var chunks = trackChunk(conductor)

        for track in song.tracks {
            var events: [Event] = []
            let name = Array(Array(track.name.utf8).prefix(64))
            let ch = UInt8(track.channel & 0x0F)
            events.append((0, 0, [0xFF, 0x03] + vlq(name.count) + name))
            events.append((0, 1, [0xC0 | ch, UInt8(track.program & 0x7F)]))
            for c in track.controls {
                // A controller lands before a note at the same tick.
                events.append((max(0, roundInt(c.start * Double(tpb))), 1,
                               [0xB0 | ch, UInt8(c.controller & 0x7F), UInt8(max(0, min(127, c.value)))]))
            }
            for n in track.notes {
                let start = roundInt(n.start * Double(tpb))
                let end = max(start + 1, roundInt(n.end * Double(tpb)))
                let pitch = UInt8(max(0, min(127, n.pitch)))
                let velocity = UInt8(max(1, min(127, Int(n.velocity))))
                // Note-offs sort before note-ons at the same tick, so a
                // repeated pitch retriggers instead of cancelling itself.
                events.append((end, 2, [0x80 | ch, pitch, 64]))
                events.append((start, 3, [0x90 | ch, pitch, velocity]))
            }
            chunks += trackChunk(events)
        }
        let header = chunk("MThd", [0, 1] + [UInt8((song.tracks.count + 1) >> 8), UInt8((song.tracks.count + 1) & 0xFF)]
                                    + [UInt8(tpb >> 8), UInt8(tpb & 0xFF)])
        return Data(header + chunks)
    }

    // ------------------------------------------------------------ reading --
    static func readVLQ(_ data: [UInt8], _ pos: inout Int) throws -> Int {
        var value = 0
        for _ in 0..<4 {
            guard pos < data.count else { throw ParseError(description: "truncated variable-length quantity") }
            let byte = data[pos]
            pos += 1
            value = (value << 7) | Int(byte & 0x7F)
            if byte & 0x80 == 0 { return value }
        }
        throw ParseError(description: "variable-length quantity too long")
    }

    /// Parse a Standard MIDI File into absolute-time notes per track.
    public static func read(_ input: Data) throws -> Song {
        let data = [UInt8](input)
        guard data.count >= 14, Array(data[0..<4]) == Array("MThd".utf8) else {
            throw ParseError(description: "not a Standard MIDI File (missing MThd)")
        }
        func u32(_ i: Int) -> Int { Int(data[i]) << 24 | Int(data[i + 1]) << 16 | Int(data[i + 2]) << 8 | Int(data[i + 3]) }
        func u16(_ i: Int) -> Int { Int(data[i]) << 8 | Int(data[i + 1]) }
        let headerLength = u32(4)
        let ntrks = u16(10), division = u16(12)
        if division & 0x8000 != 0 { throw ParseError(description: "SMPTE time division is not supported") }
        let tpb = division == 0 ? 480 : division
        var pos = 8 + headerLength
        var tempo = 120.0
        var meter = (4, 4)
        var key: Key? = nil
        var tracks: [Track] = []

        for _ in 0..<ntrks {
            guard pos + 8 <= data.count else { break }
            let tag = Array(data[pos..<pos + 4])
            let length = u32(pos + 4)
            let bodyEnd = min(data.count, pos + 8 + length)
            let body = Array(data[(pos + 8)..<bodyEnd])
            pos += 8 + length
            guard tag == Array("MTrk".utf8) else { continue }

            var track = Track(name: "")
            var open: [Int: [(tick: Int, velocity: Int)]] = [:]
            var tick = 0, cursor = 0, running = 0
            func need(_ n: Int) throws {
                if cursor + n > body.count { throw ParseError(description: "truncated event") }
            }
            while cursor < body.count {
                tick += try readVLQ(body, &cursor)
                if cursor >= body.count { break }
                var status = Int(body[cursor])
                if status & 0x80 != 0 {
                    cursor += 1
                    running = status < 0xF0 ? status : 0
                } else {
                    status = running
                    if status == 0 { throw ParseError(description: "running status with no prior status byte") }
                }
                if status == 0xFF {
                    try need(1)
                    let type = body[cursor]; cursor += 1
                    let len = try readVLQ(body, &cursor)
                    let payload = Array(body[min(cursor, body.count)..<min(cursor + len, body.count)])
                    cursor += len
                    if type == 0x51 && len == 3 && payload.count == 3 {
                        let us = Int(payload[0]) << 16 | Int(payload[1]) << 8 | Int(payload[2])
                        if us > 0 { tempo = 60_000_000.0 / Double(us) }
                    } else if type == 0x58 && len >= 2 && payload.count >= 2 {
                        meter = (Int(payload[0]), 1 << Int(payload[1]))
                    } else if type == 0x59 && len == 2 && payload.count == 2 && key == nil {
                        key = MIDIFile.key(fromSignature: Int(Int8(bitPattern: payload[0])), minor: payload[1] == 1)
                    } else if type == 0x03 && track.name.isEmpty {
                        track.name = String(decoding: payload, as: UTF8.self)
                    }
                } else if status == 0xF0 || status == 0xF7 {
                    let len = try readVLQ(body, &cursor)
                    cursor += len
                } else {
                    let kind = status & 0xF0, channel = status & 0x0F
                    if [0x80, 0x90, 0xA0, 0xB0, 0xE0].contains(kind) {
                        try need(2)
                        let d1 = Int(body[cursor]), d2 = Int(body[cursor + 1])
                        cursor += 2
                        if kind == 0xB0 {
                            track.controls.append(Control(start: Double(tick) / Double(tpb), controller: d1, value: d2))
                        } else if kind == 0x90 && d2 > 0 {
                            open[channel << 8 | d1, default: []].append((tick, d2))
                        } else if kind == 0x80 || (kind == 0x90 && d2 == 0) {
                            if var stack = open[channel << 8 | d1], !stack.isEmpty {
                                let first = stack.removeFirst()
                                open[channel << 8 | d1] = stack
                                track.channel = channel
                                track.notes.append(Note(start: Double(first.tick) / Double(tpb),
                                                        duration: Double(max(1, tick - first.tick)) / Double(tpb),
                                                        pitch: d1, velocity: Double(first.velocity)))
                            }
                        }
                    } else if kind == 0xC0 || kind == 0xD0 {
                        try need(1)
                        if kind == 0xC0 { track.program = Int(body[cursor]) }
                        cursor += 1
                    } else {
                        cursor += 1
                    }
                }
            }
            track.notes.sort { $0.start != $1.start ? $0.start < $1.start : $0.pitch < $1.pitch }
            tracks.append(track)
        }
        return Song(tempo: tempo, meter: meter, key: key, ticksPerBeat: tpb, tracks: tracks)
    }

    /// The major or minor key a key signature names. A signature is not a
    /// key - two sharps is D major, B minor and E dorian - so this is only
    /// where a song starts; the mode is the file's word for it.
    public static func key(fromSignature sf: Int, minor: Bool) -> Key? {
        guard (-7...7).contains(sf) else { return nil }
        let majors = ["Cb", "Gb", "Db", "Ab", "Eb", "Bb", "F", "C", "G", "D", "A", "E", "B", "F#", "C#"]
        let minors = ["Ab", "Eb", "Bb", "F", "C", "G", "D", "A", "E", "B", "F#", "C#", "G#", "D#", "A#"]
        let name = (minor ? minors : majors)[sf + 7]
        guard let root = Theory.roots.firstIndex(where: { $0.name == name }) else { return nil }
        return Key(root: root + 1, scale: minor ? 2 : 1)
    }
}

// ------------------------------------------------------- from the DAW --
extension Project {
    /// The song as a MIDI file: pitched tracks on channels 1-16 skipping 10,
    /// the kit on 10. Muted tracks are left out.
    public func midiFile(onlyClip clipID: String? = nil) -> MIDIFile.Song {
        var channel = 0
        var out: [MIDIFile.Track] = []
        for t in tracks where !t.mute || clipID != nil {
            var clips = t.clips
            if let id = clipID {
                clips = clips.filter { $0.id == id }
                if clips.isEmpty { continue }
            }
            let ch: Int
            if t.drums { ch = 9 } else {
                ch = min(channel, 15)
                channel += 1
                if channel == 9 { channel += 1 }
            }
            let base = clipID == nil ? 0.0 : (clips.first?.start ?? 0)
            var notes: [MIDIFile.Note] = [], controls: [MIDIFile.Control] = []
            for c in clips {
                for n in c.notes where n.start < c.length - 1e-9 {
                    notes.append(MIDIFile.Note(start: c.start - base + n.start, duration: min(n.len, c.length - n.start),
                                               pitch: n.pitch, velocity: Double(n.vel)))
                }
                for (num, pts) in c.cc.sorted(by: { $0.key < $1.key }) {
                    for p in pts where p.beat >= 0 && p.beat <= c.length {
                        controls.append(MIDIFile.Control(start: c.start - base + p.beat, controller: num, value: p.value))
                    }
                }
            }
            notes.sort { $0.start != $1.start ? $0.start < $1.start : $0.pitch < $1.pitch }
            controls.sort { $0.start < $1.start }
            out.append(MIDIFile.Track(name: t.name, program: 0, channel: ch, notes: notes, controls: controls))
        }
        return MIDIFile.Song(tempo: tempo, meter: (meter[0], meter[1]), key: key, tracks: out)
    }
}
