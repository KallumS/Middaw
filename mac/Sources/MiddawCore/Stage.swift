import Foundation

// The stage: where each player of the orchestra sits, the halls they can sit
// in, and what the hall does to a sound from each seat. `docs/STAGE.md` is the
// record of the seating, the numbers and where they come from.
//
// Coordinates are metres, seen from the audience: `x` is across the stage,
// negative to the left; `depth` is how far back from the front edge of the
// stage; `height` is where the instrument sounds from. The listener is the main
// microphone pair over the conductor's shoulder, as a Decca tree is placed.

/// The orchestra's sections, front to back as they are drawn.
public enum StageSection: String, CaseIterable, Codable {
    case strings, keys, woodwinds, brass, percussion, choir

    public var name: String {
        switch self {
        case .strings: return "Strings"
        case .keys: return "Harp and Keyboards"
        case .woodwinds: return "Woodwinds"
        case .brass: return "Brass"
        case .percussion: return "Percussion"
        case .choir: return "Choir"
        }
    }
}

/// One place on the stage, for one player or one section.
public struct Seat: Hashable, Identifiable {
    public let id: String
    public let name: String
    public let short: String
    /// Midi Catalogue's instrument id: range, clef, how many notes at once.
    public let instrument: String
    public let section: StageSection
    public let x: Double
    public let depth: Double
    public let height: Double
    /// How much of a plug-in's own stereo is kept: a section is wide, a solo
    /// wind is a point.
    public let width: Double
    /// Filled when its instrument is asked for by name. The percussion seat
    /// holds a kit, and a kit asked for by a band belongs at the front.
    public let automatic: Bool

    public init(_ id: String, _ name: String, _ short: String, _ instrument: String, _ section: StageSection,
                x: Double, depth: Double, height: Double, width: Double, automatic: Bool = true) {
        self.id = id; self.name = name; self.short = short; self.instrument = instrument; self.section = section
        self.x = x; self.depth = depth; self.height = height; self.width = width; self.automatic = automatic
    }
}

/// A room the orchestra plays in. Its size and reverberation time decide its
/// reflections, its tail and how loud the tail is beside the direct sound.
public struct Hall: Hashable, Identifiable {
    public let id: String
    public let name: String
    public let width: Double
    public let length: Double
    public let height: Double
    /// Seconds for the sound to fall 60 dB.
    public let rt60: Double

    public init(_ id: String, _ name: String, width: Double, length: Double, height: Double, rt60: Double) {
        self.id = id; self.name = name; self.width = width; self.length = length; self.height = height; self.rt60 = rt60
    }

    public var volume: Double { width * length * height }
    public var surface: Double { 2 * (width * length + width * height + length * height) }
    /// Sabine: RT60 = 0.161 V / (S a), so the average absorption is what the
    /// room's size and reverberation time say it must be.
    public var absorption: Double { max(0.02, min(0.95, 0.161 * volume / (surface * rt60))) }
    /// Where direct and reverberant sound are equally loud, for an instrument
    /// of directivity 2 (it faces the audience): 0.057 sqrt(Q V / RT60).
    public var criticalDistance: Double { 0.057 * (2 * volume / rt60).squareRoot() }

    public static let concert = Hall("concert", "Concert Hall", width: 26, length: 44, height: 18, rt60: 2.0)
    public static let scoring = Hall("scoring", "Scoring Stage", width: 30, length: 40, height: 12, rt60: 1.4)
    public static let studio = Hall("studio", "Studio", width: 20, length: 25, height: 8, rt60: 0.6)
    public static let all = [concert, scoring, studio]

    public static func named(_ id: String) -> Hall { all.first { $0.id == id } ?? concert }
}

/// A reflection off the hall's walls: how long after the direct sound it
/// arrives, and how loud in each ear.
public struct Reflection: Hashable {
    public let delay: Double
    public let left: Double
    public let right: Double
}

/// What the hall does to a sound from one seat, heard at the listener.
public struct SeatSound: Hashable {
    public let distance: Double
    /// -1 left to 1 right.
    public let pan: Double
    /// The direct sound's level: 1 at the reference distance, falling as 1/r.
    public let direct: Double
    public let width: Double
    /// Air takes the top off a sound that has come further.
    public let airCutoff: Double
    public let reflections: [Reflection]
}

public enum Stage {
    /// American seating, as most orchestras sit now: first violins on the
    /// conductor's left, cellos on the right, violas and seconds inside them,
    /// basses behind the cellos, woodwinds in the middle, horns to the left
    /// of the brass, percussion at the back and the choir on risers behind.
    public static let seats: [Seat] = [
        Seat("vln1", "Violins I", "Vln I", "vln1", .strings, x: -5.0, depth: 1.8, height: 1.1, width: 0.5),
        Seat("vln2", "Violins II", "Vln II", "vln2", .strings, x: -2.4, depth: 4.2, height: 1.1, width: 0.4),
        Seat("vla", "Violas", "Vla", "vla", .strings, x: 2.4, depth: 4.2, height: 1.1, width: 0.4),
        Seat("vc", "Cellos", "Vc", "vc", .strings, x: 5.0, depth: 2.0, height: 0.9, width: 0.4),
        Seat("cb", "Basses", "Cb", "cb", .strings, x: 7.2, depth: 5.4, height: 1.0, width: 0.35),

        Seat("pno", "Piano", "Pno", "pno", .keys, x: -7.6, depth: 2.4, height: 1.0, width: 0.3),
        Seat("harp", "Harp", "Hp", "harp", .keys, x: -7.2, depth: 5.0, height: 1.2, width: 0.15),
        Seat("cel", "Celesta", "Cel", "cel", .keys, x: -7.4, depth: 7.4, height: 1.0, width: 0.1),

        Seat("fl1", "Flute 1", "Fl 1", "fl", .woodwinds, x: -0.8, depth: 6.6, height: 1.4, width: 0.1),
        Seat("fl2", "Flute 2", "Fl 2", "fl", .woodwinds, x: -1.8, depth: 6.6, height: 1.4, width: 0.1),
        Seat("picc", "Piccolo", "Picc", "picc", .woodwinds, x: -2.8, depth: 6.6, height: 1.4, width: 0.1),
        Seat("ob1", "Oboe 1", "Ob 1", "ob", .woodwinds, x: 0.8, depth: 6.6, height: 1.3, width: 0.1),
        Seat("ob2", "Oboe 2", "Ob 2", "ob", .woodwinds, x: 1.8, depth: 6.6, height: 1.3, width: 0.1),
        Seat("eh", "Cor Anglais", "C.a.", "eh", .woodwinds, x: 2.8, depth: 6.6, height: 1.3, width: 0.1),
        Seat("cl1", "Clarinet 1", "Cl 1", "cl", .woodwinds, x: -0.8, depth: 7.9, height: 1.5, width: 0.1),
        Seat("cl2", "Clarinet 2", "Cl 2", "cl", .woodwinds, x: -1.8, depth: 7.9, height: 1.5, width: 0.1),
        Seat("bcl", "Bass Clarinet", "B.cl", "bcl", .woodwinds, x: -2.8, depth: 7.9, height: 1.4, width: 0.1),
        Seat("bsn1", "Bassoon 1", "Bsn 1", "bsn", .woodwinds, x: 0.8, depth: 7.9, height: 1.5, width: 0.1),
        Seat("bsn2", "Bassoon 2", "Bsn 2", "bsn", .woodwinds, x: 1.8, depth: 7.9, height: 1.5, width: 0.1),
        Seat("cbsn", "Contrabassoon", "Cbsn", "cbsn", .woodwinds, x: 2.8, depth: 7.9, height: 1.5, width: 0.1),

        Seat("hn1", "Horn 1", "Hn 1", "hn", .brass, x: -3.7, depth: 9.4, height: 1.7, width: 0.1),
        Seat("hn2", "Horn 2", "Hn 2", "hn", .brass, x: -4.6, depth: 9.4, height: 1.7, width: 0.1),
        Seat("hn3", "Horn 3", "Hn 3", "hn", .brass, x: -5.5, depth: 9.4, height: 1.7, width: 0.1),
        Seat("hn4", "Horn 4", "Hn 4", "hn", .brass, x: -6.4, depth: 9.4, height: 1.7, width: 0.1),
        Seat("tpt1", "Trumpet 1", "Tpt 1", "tpt", .brass, x: 0.4, depth: 9.4, height: 1.8, width: 0.1),
        Seat("tpt2", "Trumpet 2", "Tpt 2", "tpt", .brass, x: -0.5, depth: 9.4, height: 1.8, width: 0.1),
        Seat("tpt3", "Trumpet 3", "Tpt 3", "tpt", .brass, x: -1.4, depth: 9.4, height: 1.8, width: 0.1),
        Seat("tbn1", "Trombone 1", "Tbn 1", "tbn", .brass, x: 1.4, depth: 9.4, height: 1.8, width: 0.1),
        Seat("tbn2", "Trombone 2", "Tbn 2", "tbn", .brass, x: 2.3, depth: 9.4, height: 1.8, width: 0.1),
        Seat("btbn", "Bass Trombone", "B.tbn", "btbn", .brass, x: 3.2, depth: 9.4, height: 1.8, width: 0.1),
        Seat("tuba", "Tuba", "Tba", "tuba", .brass, x: 4.2, depth: 9.4, height: 1.7, width: 0.15),

        Seat("perc", "Percussion", "Perc", "kit", .percussion, x: -6.0, depth: 11.0, height: 1.6, width: 0.3, automatic: false),
        Seat("glock", "Glockenspiel", "Glk", "glock", .percussion, x: -4.5, depth: 11.0, height: 1.6, width: 0.15),
        Seat("xyl", "Xylophone", "Xyl", "xyl", .percussion, x: -3.0, depth: 11.0, height: 1.6, width: 0.2),
        Seat("timp", "Timpani", "Timp", "timp", .percussion, x: 0.0, depth: 11.0, height: 1.8, width: 0.25),
        Seat("mar", "Marimba", "Mar", "mar", .percussion, x: 3.0, depth: 11.0, height: 1.6, width: 0.25),
        Seat("vib", "Vibraphone", "Vib", "vib", .percussion, x: 4.5, depth: 11.0, height: 1.6, width: 0.2),

        Seat("sop", "Sopranos", "S", "sop", .choir, x: -4.5, depth: 12.4, height: 2.4, width: 0.45),
        Seat("alto", "Altos", "A", "alto", .choir, x: -1.5, depth: 12.4, height: 2.4, width: 0.45),
        Seat("ten", "Tenors", "T", "ten", .choir, x: 1.5, depth: 12.4, height: 2.4, width: 0.45),
        Seat("choir-bass", "Basses", "B", "bass", .choir, x: 4.5, depth: 12.4, height: 2.4, width: 0.45),
    ]

    /// Metres from the front edge of the stage to the back wall of its shell.
    public static let depth = 13.0
    /// The main microphones: 3 m in front of the stage, 3.5 m up.
    public static let listener = (x: 0.0, depth: -3.0, height: 3.5)
    /// The distance at which the direct sound is heard as it was recorded.
    public static let reference = 7.0
    public static let speedOfSound = 343.0

    public static func seat(_ id: String?) -> Seat? { id.flatMap { i in seats.first { $0.id == i } } }

    /// The first free seat for an instrument, in seating order.
    public static func freeSeat(for instrument: String, taken: Set<String>) -> Seat? {
        seats.first { $0.automatic && $0.instrument == instrument && !taken.contains($0.id) }
    }

    /// Instruments that belong in the orchestra when a song does not say:
    /// the piano is as often a band's as an orchestra's, so it waits to be asked.
    public static func isOrchestral(_ instrument: String) -> Bool {
        instrument != "pno" && seats.contains { $0.automatic && $0.instrument == instrument }
    }

    /// Constant power, unity in the centre.
    public static func panGains(_ pan: Double) -> (left: Double, right: Double) {
        let p = max(-1, min(1, pan))
        return (cos((p + 1) * .pi / 4) * 2.0.squareRoot(), sin((p + 1) * .pi / 4) * 2.0.squareRoot())
    }

    /// Where a point sits left to right for the listener. A spaced main pair
    /// spreads the stage wider than the angle alone, so the sine is widened
    /// by a quarter: the front desks of the firsts are nearly hard left.
    static func pan(dx: Double, dy: Double) -> Double {
        let angle = atan2(dx, dy)
        return max(-1, min(1, 1.25 * sin(angle)))
    }

    /// The direct sound and the walls' reflections, by mirror images of the
    /// seat in the hall (Allen and Berkley's image method) up to the second
    /// order. The stage floor is left out: the players and their chairs stand
    /// between it and the microphones.
    public static func sound(_ seat: Seat, in hall: Hall) -> SeatSound {
        // Hall coordinates: x from the left wall, y from the stage's back wall, z up.
        let W = hall.width, L = hall.length, H = hall.height
        let sx = W / 2 + seat.x, sy = depth - seat.depth, sz = seat.height
        let lx = W / 2 + listener.x, ly = depth - listener.depth, lz = listener.height
        func dist(_ x: Double, _ y: Double, _ z: Double) -> Double {
            ((x - lx) * (x - lx) + (y - ly) * (y - ly) + (z - lz) * (z - lz)).squareRoot()
        }
        func image(_ n: Int, _ s: Double, _ size: Double) -> Double { Double(n) * size + (n % 2 == 0 ? s : size - s) }
        let d0 = dist(sx, sy, sz)
        let beta = (1 - hall.absorption).squareRoot()
        var reflections: [Reflection] = []
        for nx in -2...2 {
            for ny in -2...2 {
                for nz in 0...1 {
                    let order = abs(nx) + abs(ny) + nz
                    guard order > 0, order <= 2 else { continue }
                    let ix = image(nx, sx, W), iy = image(ny, sy, L), iz = image(nz, sz, H)
                    let d = dist(ix, iy, iz)
                    let delay = (d - d0) / speedOfSound
                    guard delay > 0, delay <= 0.15 else { continue }
                    let g = reference / d * pow(beta, Double(order))
                    let lr = panGains(pan(dx: ix - lx, dy: ly - iy))
                    reflections.append(Reflection(delay: delay, left: g * lr.left, right: g * lr.right))
                }
            }
        }
        reflections.sort { $0.delay < $1.delay }
        return SeatSound(distance: d0, pan: pan(dx: sx - lx, dy: ly - sy), direct: min(1, reference / d0),
                         width: seat.width, airCutoff: 16000 * exp(-d0 / 25), reflections: reflections)
    }

    /// The hall's late reverberation: decorrelated noise in each ear falling
    /// 60 dB over RT60, darkening as it falls, building up after the first
    /// reflections. A diffuse tail sounds the same from every seat - only its
    /// level beside the direct sound changes - so one tail serves the stage.
    /// Its energy is set so a source at the critical distance hears as much
    /// tail as direct sound.
    public static func tail(_ hall: Hall, sampleRate sr: Double) -> (left: [Float], right: [Float]) {
        let count = max(1, Int(hall.rt60 * sr))
        let onset = 0.012, build = 0.03
        func ear(_ seed: UInt32) -> [Float] {
            var state = seed
            var out = [Float](repeating: 0, count: count)
            var lp = 0.0
            for i in 0..<count {
                let t = Double(i) / sr
                guard t >= onset else { continue }
                state ^= state << 13; state ^= state >> 17; state ^= state << 5
                let noise = Double(state) / Double(UInt32.max) * 2 - 1
                let fc = 1200 + 9000 * exp(-3 * t / hall.rt60)
                lp += (1 - exp(-2 * .pi * fc / sr)) * (noise - lp)
                let rise = 1 - exp(-(t - onset) / build)
                let fall = exp(-6.91 * t / hall.rt60)
                let fade = min(1, Double(count - i) / (0.1 * Double(count)))
                out[i] = Float(lp * rise * fall * fade)
            }
            let energy = out.reduce(0.0) { $0 + Double($1) * Double($1) }
            let target = pow(reference / hall.criticalDistance, 2)
            let scale = energy > 0 ? Float((target / energy).squareRoot()) : 0
            return out.map { $0 * scale }
        }
        return (ear(0x9E37_79B9), ear(0x85EB_CA6B))
    }
}

extension Project {
    /// Seats with a player in them.
    public var takenSeats: Set<String> { Set(tracks.compactMap(\.seat)) }

    public func track(inSeat id: String) -> Track? { tracks.first { $0.seat == id } }

    /// A song from before the stage: each orchestral instrument takes the
    /// first free seat for it; everything else plays at the front.
    mutating func seatTheOrchestra() {
        var taken = takenSeats
        for i in tracks.indices where tracks[i].seat == nil && !tracks[i].drums && Stage.isOrchestral(tracks[i].instrument) {
            if let seat = Stage.freeSeat(for: tracks[i].instrument, taken: taken) {
                tracks[i].seat = seat.id
                taken.insert(seat.id)
            }
        }
    }
}
