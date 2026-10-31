import Foundation
import MiddawCore
import MiddawEngines

/// Compose: Middaw's own prompt-to-music composer. It answers with the spec
/// it understood, the chords and the five parts.
enum Composer {
    struct Failure: Error, CustomStringConvertible { let description: String }

    struct Spec: Decodable {
        let seed: Int?
        let tempo: Double
        let key: String
        let mode: String
        let tonic: Int
        let bars: Int?
        let formName: String?
        let unmatchedTerms: [String]?
        let prompt: String?
        enum CodingKeys: String, CodingKey {
            case seed, tempo, key, mode, tonic, bars, prompt
            case formName = "form_name", unmatchedTerms = "unmatched_terms"
        }
    }
    struct Part: Decodable { let name: String; let role: String; let detail: String; let notes: [Note] }
    struct Song: Decodable { let meter: [Int]; let lengthBeats: Double; let tracks: [Part] }
    struct Chord: Decodable { let symbol: String }
    struct Composition: Decodable {
        let spec: Spec
        let song: Song
        let chords: [Chord]
        let summary: String

        /// The composer's key as ScaleView's pair.
        var key: Key {
            let rootName = spec.key.split(separator: " ").first.map(String.init) ?? "C"
            let root = (Theory.roots.firstIndex { $0.name == rootName } ?? Theory.roots.firstIndex { $0.pitchClass == mod12(spec.tonic) } ?? 0) + 1
            let modes = ["major": 1, "minor": 2, "harmonic_minor": 3, "melodic_minor": 2, "ionian": 4, "dorian": 5, "phrygian": 6,
                         "lydian": 7, "mixolydian": 8, "aeolian": 9, "locrian": 9, "major_pentatonic": 10, "minor_pentatonic": 11,
                         "major_blues": 12, "blues": 13, "whole_tone": 14, "diminished_wh": 15, "diminished_hw": 16]
            return Key(root: root, scale: modes[spec.mode] ?? 1)
        }
    }

    /// The composer runs in the engines' JavaScriptCore (runtime/composer/,
    /// the port of middaw/, held to it by tests/test_composer_js.py): no
    /// Python, nothing to install.
    static func compose(_ prompt: String, seed: Int, engines: Engines) throws -> Composition {
        do {
            return try engines.compose(prompt, seed: seed)
        } catch let e as Engines.Failure {
            throw Failure(description: "Compose failed: \(e.description)")
        }
    }
}
