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

/// One place on the stage, for one player or one section: a wedge of the
/// fan the orchestra sits in, between two angles and two radii around the
/// conductor. Where it is drawn is where it is heard from: its position is
/// the middle of its wedge.
public struct Seat: Hashable, Identifiable {
    public let id: String
    public let name: String
    public let short: String
    /// Midi Catalogue's instrument id: range, clef, how many notes at once.
    public let instrument: String
    public let section: StageSection
    /// Degrees from straight ahead of the conductor, negative to the left.
    public let from: Double, to: Double
    /// Metres from the conductor.
    public let inner: Double, outer: Double
    public let height: Double
    /// How much of a plug-in's own stereo is kept: a section is wide, a solo
    /// wind is a point.
    public let width: Double
    /// Filled when its instrument is asked for by name. The percussion seat
    /// holds a kit, and a kit asked for by a band belongs at the front.
    public let automatic: Bool

    public init(_ id: String, _ name: String, _ short: String, _ instrument: String, _ section: StageSection,
                from: Double, to: Double, inner: Double, outer: Double, height: Double, width: Double, automatic: Bool = true) {
        self.id = id; self.name = name; self.short = short; self.instrument = instrument; self.section = section
        self.from = from; self.to = to; self.inner = inner; self.outer = outer
        self.height = height; self.width = width; self.automatic = automatic
    }

    public var angle: Double { (from + to) / 2 }
    public var radius: Double { (inner + outer) / 2 }
    /// Across the stage, negative to the left as the audience sees it.
    public var x: Double { radius * sin(angle * .pi / 180) }
    /// Back from the front edge of the stage, where the conductor stands.
    public var depth: Double { radius * cos(angle * .pi / 180) }
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
    public static let studio = Hall("studio", "Studio", width: 24, length: 25, height: 8, rt60: 0.6)
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
    /// American seating, as most orchestras sit now, in a fan around the
    /// conductor: first violins on the left and cellos on the right, both
    /// reaching the edge of the stage; seconds and violas inside them; flutes
    /// and oboes, then clarinets and bassoons; harp and piano on the left of
    /// the brass, horns on the left of the trumpets, trombones and tuba on the
    /// right with the basses beyond them; percussion with the timpani in the
    /// middle at the back; the choir on risers behind.
    public static let seats: [Seat] = {
        var out: [Seat] = []
        /// Seats side by side across one ring, each an equal slice.
        func ring(_ section: StageSection, _ from: Double, _ to: Double, _ inner: Double, _ outer: Double, height: Double, width: Double,
                  _ list: [(String, String, String, String)]) {
            let step = (to - from) / Double(list.count)
            for (k, s) in list.enumerated() {
                out.append(Seat(s.0, s.1, s.2, s.3, section, from: from + Double(k) * step, to: from + Double(k + 1) * step,
                                inner: inner, outer: outer, height: height, width: width, automatic: s.0 != "perc"))
            }
        }
        out.append(Seat("vln1", "Violins I", "Vln I", "vln1", .strings, from: -90, to: -60, inner: 2.5, outer: 8.0, height: 1.1, width: 0.5))
        ring(.strings, -60, 60, 2.5, 5.0, height: 1.1, width: 0.4,
             [("vln2", "Violins II", "Vln II", "vln2"), ("vla", "Violas", "Vla", "vla")])
        out.append(Seat("vc", "Cellos", "Vc", "vc", .strings, from: 60, to: 90, inner: 2.5, outer: 6.5, height: 0.9, width: 0.4))
        out.append(Seat("cb", "Basses", "Cb", "cb", .strings, from: 60, to: 90, inner: 6.5, outer: 9.5, height: 1.0, width: 0.35))
        ring(.woodwinds, -60, 60, 5.0, 6.5, height: 1.4, width: 0.1,
             [("picc", "Piccolo", "Picc", "picc"), ("fl2", "Flute 2", "Fl 2", "fl"), ("fl1", "Flute 1", "Fl 1", "fl"),
              ("ob1", "Oboe 1", "Ob 1", "ob"), ("ob2", "Oboe 2", "Ob 2", "ob"), ("eh", "Cor Anglais", "C.a.", "eh")])
        ring(.woodwinds, -60, 60, 6.5, 8.0, height: 1.5, width: 0.1,
             [("bcl", "Bass Clarinet", "B.cl", "bcl"), ("cl2", "Clarinet 2", "Cl 2", "cl"), ("cl1", "Clarinet 1", "Cl 1", "cl"),
              ("bsn1", "Bassoon 1", "Bsn 1", "bsn"), ("bsn2", "Bassoon 2", "Bsn 2", "bsn"), ("cbsn", "Contrabassoon", "Cbsn", "cbsn")])
        ring(.keys, -90, -60, 8.0, 9.5, height: 1.1, width: 0.2, [("harp", "Harp", "Hp", "harp"), ("pno", "Piano", "Pno", "pno")])
        ring(.brass, -60, -20, 8.0, 9.5, height: 1.7, width: 0.1,
             [("hn4", "Horn 4", "Hn 4", "hn"), ("hn3", "Horn 3", "Hn 3", "hn"), ("hn2", "Horn 2", "Hn 2", "hn"), ("hn1", "Horn 1", "Hn 1", "hn")])
        ring(.brass, -20, 10, 8.0, 9.5, height: 1.8, width: 0.1,
             [("tpt3", "Trumpet 3", "Tpt 3", "tpt"), ("tpt2", "Trumpet 2", "Tpt 2", "tpt"), ("tpt1", "Trumpet 1", "Tpt 1", "tpt")])
        ring(.brass, 10, 60, 8.0, 9.5, height: 1.8, width: 0.1,
             [("tbn1", "Trombone 1", "Tbn 1", "tbn"), ("tbn2", "Trombone 2", "Tbn 2", "tbn"),
              ("btbn", "Bass Trombone", "B.tbn", "btbn"), ("tuba", "Tuba", "Tba", "tuba")])
        ring(.percussion, -90, 90, 9.5, 11.0, height: 1.6, width: 0.2,
             [("cel", "Celesta", "Cel", "cel"), ("perc", "Percussion", "Perc", "kit"), ("glock", "Glockenspiel", "Glk", "glock"),
              ("timp", "Timpani", "Timp", "timp"), ("xyl", "Xylophone", "Xyl", "xyl"), ("mar", "Marimba", "Mar", "mar"),
              ("vib", "Vibraphone", "Vib", "vib")])
        ring(.choir, -60, 60, 11.0, 12.5, height: 2.4, width: 0.45,
             [("sop", "Sopranos", "S", "sop"), ("alto", "Altos", "A", "alto"), ("ten", "Tenors", "T", "ten"), ("choir-bass", "Basses", "B", "bass")])
        return out
    }()

    /// The fan's outer edge, in metres from the conductor.
    public static let radius = 12.5

    /// Metres from the front edge of the stage to the back wall of its shell.
    public static let depth = 13.0
    /// The main microphones: 3 m in front of the stage, 3.5 m up.
    public static let listener = (x: 0.0, depth: -3.0, height: 3.5)
    /// The distance at which the direct sound is heard as it was recorded.
    public static let reference = 7.0
    public static let speedOfSound = 343.0

    public static func seat(_ id: String?) -> Seat? { id.flatMap { i in seats.first { $0.id == i } } }

    /// The first free seat for an instrument: the principal's before the
    /// second's (Flute 1, then Flute 2), wherever they sit in the fan.
    public static func freeSeat(for instrument: String, taken: Set<String>) -> Seat? {
        seats.filter { $0.automatic && $0.instrument == instrument && !taken.contains($0.id) }
            .min { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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
