import Foundation
import MiddawCore

/// Compose: Middaw's own prompt-to-music composer (`middaw/`, Python),
/// bundled inside the app and run with the Mac's Python. It answers with the
/// spec it understood, the chords and the five parts.
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

    /// The folder holding `middaw/` and `data/`: inside the app, or the repository.
    static var root: URL? {
        if let res = Bundle.main.resourceURL?.appendingPathComponent("composer"),
           FileManager.default.fileExists(atPath: res.appendingPathComponent("middaw/__main__.py").path) { return res }
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            dir.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("middaw/__main__.py").path) { return dir }
        }
        return nil
    }

    /// A Python 3.9 or newer: Homebrew's, or the Mac's own once Apple's
    /// Command Line Tools are installed.
    static var python: URL? {
        for path in ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"] {
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }
            if path == "/usr/bin/python3" && !FileManager.default.fileExists(atPath: "/Library/Developer/CommandLineTools/usr/bin/python3")
                && !FileManager.default.fileExists(atPath: "/Applications/Xcode.app") { continue }
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    static func compose(_ prompt: String, seed: Int) throws -> Composition {
        guard let root = root else { throw Failure(description: "Compose is missing from this copy of Middaw.") }
        guard let py = python else {
            throw Failure(description: "Compose needs Python, which comes with Apple's Command Line Tools: run xcode-select --install in Terminal, then try again.")
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("middaw-\(UUID().uuidString).mid")
        defer { try? FileManager.default.removeItem(at: out) }
        let p = Process()
        p.executableURL = py
        p.arguments = ["-m", "middaw", "--seed", String(seed), "--json", "-o", out.path, "--", prompt]
        p.currentDirectoryURL = root
        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"] = root.path
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        p.environment = env
        let stdout = Pipe(), stderr = Pipe()
        p.standardOutput = stdout
        p.standardError = stderr
        try p.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let err = stderr.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(decoding: err, as: UTF8.self).split(separator: "\n").last.map(String.init) ?? "it stopped"
            throw Failure(description: "Compose failed: \(msg)")
        }
        return try JSONDecoder().decode(Composition.self, from: data)
    }
}
