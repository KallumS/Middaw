import XCTest
@testable import MiddawCore

final class MIDIFileTests: XCTestCase {
    func fixtureSongs() throws -> [(name: String, song: MIDIFile.Song, bytes: Data)] {
        let list = try XCTUnwrap(Fixtures.json("midi.json") as? [[String: Any]])
        return list.map { s in
            let meter = s["meter"] as! [Int]
            let tracks = (s["tracks"] as! [[String: Any]]).map { t -> MIDIFile.Track in
                // exact hex floats, as the fixture writes them
                func d(_ s: String) -> Double { Double(s)! }
                let notes = (t["notes"] as! [[String]]).map {
                    MIDIFile.Note(start: d($0[0]), duration: d($0[1]), pitch: Int(d($0[2])), velocity: d($0[3]))
                }
                let controls = (t["controls"] as! [[String]]).map {
                    MIDIFile.Control(start: d($0[0]), controller: Int(d($0[1])), value: Int(d($0[2])))
                }
                return MIDIFile.Track(name: t["name"] as! String, program: t["program"] as! Int,
                                      channel: t["channel"] as! Int, notes: notes, controls: controls)
            }
            let song = MIDIFile.Song(tempo: Double(s["tempo"] as! Int), meter: (meter[0], meter[1]),
                                     key: Key(root: s["root"] as! Int, scale: s["scale"] as! Int), tracks: tracks)
            return (s["name"] as! String, song, Data(base64Encoded: s["midi"] as! String)!)
        }
    }

    /// Byte for byte what middaw/midi.py writes for the same song.
    func testWritesTheSameBytesAsThePython() throws {
        for f in try fixtureSongs() {
            let mine = MIDIFile.write(f.song)
            if mine != f.bytes {
                let a = [UInt8](mine), b = [UInt8](f.bytes)
                let first = zip(a, b).enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? min(a.count, b.count)
                XCTFail("\(f.name): differs at byte \(first) of \(b.count) (mine \(a.count))")
            }
        }
    }

    func testReadsBackWhatItWrote() throws {
        for f in try fixtureSongs() {
            let back = try MIDIFile.read(MIDIFile.write(f.song))
            XCTAssertEqual(back.tracks.count, f.song.tracks.count + 1, f.name)     // + the conductor
            XCTAssertEqual(back.meter.0, f.song.meter.0)
            XCTAssertEqual(back.meter.1, f.song.meter.1)
            XCTAssertEqual(back.tempo, f.song.tempo, accuracy: 0.01)
            for (orig, read) in zip(f.song.tracks, back.tracks.dropFirst()) {
                XCTAssertEqual(read.notes.count, orig.notes.count, f.name)
                XCTAssertEqual(read.controls.count, orig.controls.count, f.name)
            }
        }
    }

    /// The key signature comes back as the key the song was in (for the
    /// major and natural minor keys a signature can name).
    func testTheKeySignatureIsReadBack() throws {
        for (root, scale) in [(11, 1), (16, 1), (4, 2), (9, 2), (18, 1), (5, 2)] {
            let k = Key(root: root, scale: scale)
            let song = MIDIFile.Song(tempo: 100, meter: (4, 4), key: k, tracks: [MIDIFile.Track(name: "x", notes: [.init(start: 0, duration: 1, pitch: 60, velocity: 90)])])
            XCTAssertEqual(try MIDIFile.read(MIDIFile.write(song)).key, k, k.label)
        }
        // a mode reads back as its signature's major or minor: D dorian has no sharps and a minor third
        let dorian = MIDIFile.Song(tempo: 100, meter: (4, 4), key: Key(root: 4, scale: 5), tracks: [])
        XCTAssertEqual(try MIDIFile.read(MIDIFile.write(dorian)).key, Key(root: 14, scale: 2))   // A minor
    }

    func testRefusesWhatIsNotMIDI() {
        XCTAssertThrowsError(try MIDIFile.read(Data("this is not a midi file at all".utf8)))
        XCTAssertThrowsError(try MIDIFile.read(Data([0x4D, 0x54, 0x68, 0x64, 0, 0, 0, 6, 0, 1, 0, 1, 0x01, 0xE0,
                                                     0x4D, 0x54, 0x72, 0x6B, 0, 0, 0, 3, 0x00, 0x40, 0x40])))
    }

    func testTheDAWsSongBecomesAFile() throws {
        var p = Project(tempo: 96, meter: [3, 4], key: Key(root: 4, scale: 2))
        var lead = Track(name: "Lead")
        lead.clips = [Clip(start: 4, length: 4, notes: [Note(start: 0, len: 1, pitch: 62), Note(start: 5, len: 1, pitch: 64)],
                           cc: [11: [CCPoint(beat: 0, value: 70)]])]
        var kit = Track(name: "Kit", instrument: "kit", drums: true)
        kit.clips = [Clip(start: 0, length: 4, notes: [Note(start: 0, len: 0.25, pitch: 36)])]
        p.tracks = [lead, kit]
        let file = p.midiFile()
        XCTAssertEqual(file.tracks.map(\.channel), [0, 9])
        XCTAssertEqual(file.tracks[0].notes.map(\.start), [4])            // the note past the clip's end is cut
        XCTAssertEqual(file.tracks[0].controls.first?.start, 4)
        let back = try MIDIFile.read(MIDIFile.write(file))
        XCTAssertEqual(back.tracks[2].channel, 9)
    }
}
