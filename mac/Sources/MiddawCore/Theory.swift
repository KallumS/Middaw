import Foundation

/// Scales, keys and spelling, ported from ScaleView (via `middaw/scaleview.py`).
///
/// A key is ScaleView's pair of indices - root 1-18 (C, C#, Db ... Cb) and
/// scale 1-16 (Major ... Diminished Half-Whole) - because that is what every
/// family engine reads, so nothing is translated on the way in or out.
public enum Theory {
    public static let letters = ["C", "D", "E", "F", "G", "A", "B"]
    public static let letterPitchClasses = [0, 2, 4, 5, 7, 9, 11]
    public static let sharpNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    public static let flatNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    static let accidentals: [Int: String] = [-2: "bb", -1: "b", 0: "", 1: "#", 2: "x"]

    public struct Root: Hashable {
        public let name: String
        public let letter: Int
        public let accidental: Int
        public var pitchClass: Int { mod12(Theory.letterPitchClasses[letter] + accidental) }
    }

    public struct Scale: Hashable {
        /// The composer's name for it (`middaw/theory.py`).
        public let id: String
        /// ScaleView's full name, as the composer labels keys.
        public let name: String
        /// The name in Middaw's menus.
        public let menuName: String
        public let intervals: [Int]
        /// How many letter names each degree sits above the root's letter.
        public let letters: [Int]
    }

    /// Both spellings of every pitch class, plus Cb, in ScaleView's order.
    public static let roots: [Root] = [
        Root(name: "C", letter: 0, accidental: 0), Root(name: "C#", letter: 0, accidental: 1),
        Root(name: "Db", letter: 1, accidental: -1), Root(name: "D", letter: 1, accidental: 0),
        Root(name: "D#", letter: 1, accidental: 1), Root(name: "Eb", letter: 2, accidental: -1),
        Root(name: "E", letter: 2, accidental: 0), Root(name: "F", letter: 3, accidental: 0),
        Root(name: "F#", letter: 3, accidental: 1), Root(name: "Gb", letter: 4, accidental: -1),
        Root(name: "G", letter: 4, accidental: 0), Root(name: "G#", letter: 4, accidental: 1),
        Root(name: "Ab", letter: 5, accidental: -1), Root(name: "A", letter: 5, accidental: 0),
        Root(name: "A#", letter: 5, accidental: 1), Root(name: "Bb", letter: 6, accidental: -1),
        Root(name: "B", letter: 6, accidental: 0), Root(name: "Cb", letter: 0, accidental: -1),
    ]

    static let seven = [0, 1, 2, 3, 4, 5, 6]

    /// ScaleView's sixteen, in its menu's order.
    public static let scales: [Scale] = [
        Scale(id: "major", name: "Major", menuName: "Major", intervals: [0, 2, 4, 5, 7, 9, 11], letters: seven),
        Scale(id: "minor", name: "Minor (Natural)", menuName: "Minor", intervals: [0, 2, 3, 5, 7, 8, 10], letters: seven),
        Scale(id: "harmonic_minor", name: "Harmonic Minor", menuName: "Harmonic Minor", intervals: [0, 2, 3, 5, 7, 8, 11], letters: seven),
        Scale(id: "ionian", name: "Ionian", menuName: "Ionian", intervals: [0, 2, 4, 5, 7, 9, 11], letters: seven),
        Scale(id: "dorian", name: "Dorian", menuName: "Dorian", intervals: [0, 2, 3, 5, 7, 9, 10], letters: seven),
        Scale(id: "phrygian", name: "Phrygian", menuName: "Phrygian", intervals: [0, 1, 3, 5, 7, 8, 10], letters: seven),
        Scale(id: "lydian", name: "Lydian", menuName: "Lydian", intervals: [0, 2, 4, 6, 7, 9, 11], letters: seven),
        Scale(id: "mixolydian", name: "Mixolydian", menuName: "Mixolydian", intervals: [0, 2, 4, 5, 7, 9, 10], letters: seven),
        Scale(id: "aeolian", name: "Aeolian", menuName: "Aeolian", intervals: [0, 2, 3, 5, 7, 8, 10], letters: seven),
        Scale(id: "major_pentatonic", name: "Major Pentatonic", menuName: "Major Pentatonic", intervals: [0, 2, 4, 7, 9], letters: [0, 1, 2, 4, 5]),
        Scale(id: "minor_pentatonic", name: "Minor Pentatonic", menuName: "Minor Pentatonic", intervals: [0, 3, 5, 7, 10], letters: [0, 2, 3, 4, 6]),
        Scale(id: "major_blues", name: "Major Blues", menuName: "Major Blues", intervals: [0, 2, 3, 4, 7, 9], letters: [0, 1, 2, 2, 4, 5]),
        Scale(id: "blues", name: "Minor Blues", menuName: "Minor Blues", intervals: [0, 3, 5, 6, 7, 10], letters: [0, 2, 3, 4, 4, 6]),
        Scale(id: "whole_tone", name: "Whole Tone", menuName: "Whole Tone", intervals: [0, 2, 4, 6, 8, 10], letters: [0, 1, 2, 3, 4, 5]),
        Scale(id: "diminished_wh", name: "Diminished Whole-Half", menuName: "Diminished W-H", intervals: [0, 2, 3, 5, 6, 8, 9, 11], letters: [0, 1, 2, 3, 4, 5, 5, 6]),
        Scale(id: "diminished_hw", name: "Diminished Half-Whole", menuName: "Diminished H-W", intervals: [0, 1, 3, 4, 6, 7, 9, 10], letters: [0, 1, 2, 2, 3, 4, 5, 6]),
    ]

    /// Name `pitchClass` with the given letter, or nil if it needs a triple accidental.
    public static func spell(letter: Int, pitchClass: Int) -> String? {
        let l = ((letter % 7) + 7) % 7
        let offset = mod12(pitchClass - letterPitchClasses[l] + 6) - 6
        guard let acc = accidentals[offset] else { return nil }
        return letters[l] + acc
    }

    /// A note number as a musician reads it: 60 is C4.
    public static func noteName(_ pitch: Int, in key: Key? = nil) -> String {
        let names = key?.names ?? sharpNames
        return names[mod12(pitch)] + String(pitch / 12 - 1)
    }
}

@inline(__always) public func mod12(_ x: Int) -> Int { ((x % 12) + 12) % 12 }

/// A key: ScaleView's root (1-18) and scale (1-16).
public struct Key: Codable, Hashable {
    public var root: Int
    public var scale: Int

    public init(root: Int = 1, scale: Int = 1) {
        self.root = min(max(root, 1), Theory.roots.count)
        self.scale = min(max(scale, 1), Theory.scales.count)
    }

    public var rootInfo: Theory.Root { Theory.roots[min(max(root, 1), Theory.roots.count) - 1] }
    public var scaleInfo: Theory.Scale { Theory.scales[min(max(scale, 1), Theory.scales.count) - 1] }
    public var tonic: Int { rootInfo.pitchClass }
    public var intervals: [Int] { scaleInfo.intervals }

    /// "Bb Minor", as Middaw's toolbar says it.
    public var displayName: String { "\(rootInfo.name) \(scaleInfo.menuName)" }
    /// "Bb Minor (Natural)", as the composer and ScaleView label it.
    public var label: String { "\(rootInfo.name) \(scaleInfo.name)" }

    /// Which of the twelve pitch classes are in the key.
    public var pitchClasses: [Bool] {
        var out = [Bool](repeating: false, count: 12)
        for iv in intervals { out[mod12(tonic + iv)] = true }
        return out
    }

    public func contains(_ pitch: Int) -> Bool { pitchClasses[mod12(pitch)] }

    /// Each pitch class spelled for this key; notes outside it lean the way the key does.
    public var names: [String] { spelling().names }

    public var usesFlats: Bool { spelling().usesFlats }

    func spelling() -> (names: [String], usesFlats: Bool) {
        var names = [String?](repeating: nil, count: 12)
        var sharps = 0, flats = 0
        let r = rootInfo, s = scaleInfo
        for (degree, iv) in s.intervals.enumerated() {
            let pc = mod12(r.pitchClass + iv)
            if let name = Theory.spell(letter: r.letter + s.letters[degree], pitchClass: pc) {
                names[pc] = name
                if name.contains("#") || name.contains("x") { sharps += 1 }
                if name.dropFirst().contains("b") { flats += 1 }
            }
        }
        let usesFlats = flats > sharps
        let outside = usesFlats ? Theory.flatNames : Theory.sharpNames
        return (names.enumerated().map { $0.element ?? outside[$0.offset] }, usesFlats)
    }

    /// The key signature a MIDI file carries: sharps (+) or flats (-), and
    /// whether the key is minor. A mode writes its parent's signature; altered
    /// minors, pentatonics and blues borrow the scale they come from.
    public var signature: (sharpsOrFlats: Int, minor: Bool) {
        let parentOf: [String: String] = [
            "harmonic_minor": "minor", "melodic_minor": "minor", "minor_pentatonic": "minor",
            "blues": "minor", "major_pentatonic": "major", "major_blues": "major",
        ]
        let minorThird: Set<String> = ["minor", "aeolian", "dorian", "phrygian", "locrian", "harmonic_minor",
                                       "melodic_minor", "minor_pentatonic", "blues", "diminished_wh"]
        let id = scaleInfo.id
        let parentId = parentOf[id] ?? id
        let parentIndex = (Theory.scales.firstIndex { $0.id == parentId } ?? 0) + 1
        let parent = Key(root: root, scale: parentIndex)
        var count = 0
        if parent.intervals.count == 7 {
            let names = parent.names
            for (pc, inKey) in parent.pitchClasses.enumerated() where inKey {
                let tail = names[pc].dropFirst()
                count += tail.filter { $0 == "#" }.count + 2 * tail.filter { $0 == "x" }.count
                count -= tail.filter { $0 == "b" }.count
            }
        }
        return (max(-7, min(7, count)), minorThird.contains(id))
    }
}
