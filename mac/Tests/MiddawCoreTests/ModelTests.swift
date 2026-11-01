import XCTest
@testable import MiddawCore

final class ModelTests: XCTestCase {
    let cMajor = Key(root: 1, scale: 1)

    func project() -> (Project, String) {
        var p = Project()
        let t = Track(name: "Piano")
        p.tracks = [t]
        return (p, t.id)
    }

    func testPlacingMusicClearsWhatWasUnderItKeepingBothSides() {
        var (p, id) = project()
        p.place([0.0, 4, 8, 12].map { Note(start: $0, len: 2, pitch: 60) }, on: id, at: 0, length: 16)
        p.place([Note(start: 0, len: 1, pitch: 72)], on: id, at: 4, length: 4)
        XCTAssertEqual(p.tracks[0].clips.map { [$0.start, $0.length] }, [[0, 4], [4, 4], [8, 8]])
        XCTAssertEqual(p.tracks[0].notes.map { [$0.start, Double($0.pitch)] }, [[0, 60], [4, 72], [8, 60], [12, 60]])
    }

    func testANoteIsCutAtTheEndOfItsClip() {
        var (p, id) = project()
        p.place([Note(start: 3, len: 4, pitch: 60), Note(start: 5, len: 1, pitch: 62)], on: id, at: 0, length: 4)
        XCTAssertEqual(p.tracks[0].clips[0].notes.map { [$0.start, $0.len] }, [[3, 1]])
    }

    func testTurningATuneUpsideDownKeepsItInItsKey() {
        var notes = [60, 62, 64, 65, 67, 71].enumerated().map { Note(start: Double($0.offset), len: 1, pitch: $0.element) }
        Transform.invert(&notes, key: cMajor)
        XCTAssertEqual(notes.map(\.pitch), [71, 69, 67, 65, 64, 60])
        XCTAssertTrue(notes.allSatisfy { cMajor.contains($0.pitch) })
    }

    func testAChromaticLineIsMirroredChromatically() {
        var notes = [60, 61, 63].map { Note(start: 0, len: 1, pitch: $0) }
        Transform.invert(&notes, key: cMajor)
        XCTAssertEqual(notes.map(\.pitch), [63, 62, 60])
    }

    func testPlayedBackwardsTheRhythmIsMirroredToo() {
        var notes = [Note(start: 0, len: 1, pitch: 60), Note(start: 1, len: 3, pitch: 62)]
        Transform.retrograde(&notes, length: 4)
        XCTAssertEqual(notes.map { [$0.start, Double($0.pitch)] }, [[0, 62], [3, 60]])
    }

    func testFittingToTheKeyMovesOnlyTheNotesOutsideIt() {
        var notes = [61, 62, 66, 70].map { Note(start: 0, len: 1, pitch: $0) }
        Transform.fitToKey(&notes, key: cMajor)
        XCTAssertTrue(notes.allSatisfy { cMajor.contains($0.pitch) })
        XCTAssertEqual(notes[1].pitch, 62)
    }

    func testSnappingAndQuantizingWorkBarByBarInOddMeters() {
        var (p, _) = project()
        p.meter = [7, 8]
        XCTAssertEqual(p.beatsPerBar, 3.5)
        XCTAssertEqual(p.snap(3.6, grid: 1), 3.5)
        XCTAssertEqual(p.quantized([Note(start: 4.6, len: 1, pitch: 60)], grid: 1)[0].start, 4.5)
        XCTAssertEqual(p.position(3.5 + 0.75), "2.2.2")
    }

    func testSplittingAClipDividesItsNotes() {
        var (p, id) = project()
        let c = p.place([Note(start: 1, len: 1, pitch: 60), Note(start: 5, len: 1, pitch: 64)], on: id, at: 0, length: 8)!
        let right = p.tracks[0].split(clipID: c, at: 4)!
        let clips = p.tracks[0].clips
        XCTAssertEqual(clips.map(\.length), [4, 4])
        XCTAssertEqual(clips.first { $0.id == right }!.notes.map { [$0.start, Double($0.pitch)] }, [[1, 64]])
    }

    func testUndoAndRedoWalkTheHistoryAndNameEachStep() {
        var h = History(project().0)
        h.commit("Rename Track") { $0.tracks[0].name = "Lead" }
        h.commit("Change Tempo") { $0.tempo = 90 }
        XCTAssertEqual(h.undoLabel, "Change Tempo")
        XCTAssertEqual(h.undo(), "Change Tempo")
        XCTAssertEqual(h.project.tempo, 110)
        XCTAssertEqual(h.project.tracks[0].name, "Lead")
        XCTAssertEqual(h.redo(), "Change Tempo")
        XCTAssertEqual(h.project.tempo, 90)
        h.undo()
        h.commit("Mute") { $0.tracks[0].mute = true }
        XCTAssertNil(h.redoLabel)
    }

    func testADeclinedChangeIsNotAStep() {
        var h = History(project().0)
        XCTAssertFalse(h.commitIf("Nothing") { _ in false })
        XCTAssertNil(h.undoLabel)
    }

    /// A song saved by the browser version opens, notes and all.
    func testOpensABrowserSong() throws {
        let json = """
        {"version":1,"title":"Folk","tempo":104,"meter":[3,4],"key":{"root":11,"scale":1},"bars":20,
         "loop":{"on":true,"start":0,"end":12},"created":1700000000000,
         "tracks":[{"id":"t1","name":"Melody","instrument":"pno","role":"melody","drums":false,
           "sound":{"id":"d1","device":"synth","preset":"piano","sliders":{},"state":null},
           "midiFx":[{"id":"d2","device":"autocc","sliders":{"1":2,"18":1},"state":{"vars":[1,2,3]}}],
           "audioFx":[],"volume":0.8,"pan":-0.2,"send":0.3,"mute":false,"solo":false,"arm":false,
           "clips":[{"id":"c1","name":"Binary","start":0,"length":12,
             "notes":[{"start":0,"len":1,"pitch":67,"vel":96.4},{"start":1,"duration":0.5,"pitch":69,"velocity":80}],
             "cc":{"11":[[0,40],[2.5,90]]},"source":{"generator":"Compose","title":"a folk song"}}]}],
         "returns":[{"id":"return","name":"Reverb","audioFx":[{"id":"d9","device":"reverberator","sliders":{"1":5,"2":100}}]}]}
        """
        let p = try JSONDecoder().decode(Project.self, from: Data(json.utf8))
        XCTAssertEqual(p.key, Key(root: 11, scale: 1))
        XCTAssertEqual(p.beatsPerBar, 3)
        let t = p.tracks[0]
        XCTAssertEqual(t.midiFx[0].sliders[18], 1)
        XCTAssertEqual(t.clips[0].notes.map(\.vel), [96, 80])
        XCTAssertEqual(t.clips[0].notes[1].len, 0.5)
        XCTAssertEqual(t.clips[0].cc[11]?.last, CCPoint(beat: 2.5, value: 90))
        XCTAssertEqual(p.returns[0].audioFx[0].device, "reverberator")
        // and it saves and opens again unchanged
        let again = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(again, p)
    }
}
