import SwiftUI
import AppKit
import UniformTypeIdentifiers
import MiddawCore
import MiddawEngines
import MiddawAudio

enum EditorTab: String { case roll, score, mixer }
enum InspectorTab: String { case track, generate }

struct Selection: Equatable {
    var trackID: String?
    var clipID: String?
    var notes: Set<Int> = []
    /// Bars chosen across tracks: where generated music goes (Miderator 0019).
    var range: (tracks: [String], start: Double, end: Double)?
    static func == (a: Selection, b: Selection) -> Bool {
        a.trackID == b.trackID && a.clipID == b.clipID && a.notes == b.notes &&
            a.range?.tracks == b.range?.tracks && a.range?.start == b.range?.start && a.range?.end == b.range?.end
    }
}

/// The ensembles Noterator builds, by Midi Catalogue's instrument ids.
let ensembles: [(name: String, ids: [String])] = [
    ("Piano", ["pno"]),
    ("String Quartet", ["vln1", "vln2", "vla", "vc"]),
    ("Wind Quintet", ["fl", "ob", "cl", "hn", "bsn"]),
    ("Brass Quintet", ["tpt", "tpt", "hn", "tbn", "tuba"]),
    ("Choir", ["sop", "alto", "ten", "bass"]),
    ("Band", ["pno", "gtr", "ebass", "kit"]),
    ("Jazz Combo", ["tpt", "tsax", "pno", "ubass", "kit"]),
    ("Beat Maker", ["synth", "pno", "ebass", "kit"]),
    ("Full Strings", ["vln1", "vln2", "vla", "vc", "cb"]),
    ("Full Woodwinds", ["picc", "fl", "fl", "ob", "ob", "eh", "cl", "cl", "bcl", "bsn", "bsn", "cbsn"]),
    ("Full Brass", ["hn", "hn", "hn", "hn", "tpt", "tpt", "tpt", "tbn", "tbn", "btbn", "tuba"]),
    ("Orchestral Percussion", ["timp", "glock", "xyl", "mar", "vib"]),
    ("Chamber Orchestra", ["fl", "ob", "cl", "bsn", "hn", "tpt", "timp", "vln1", "vln2", "vla", "vc", "cb"]),
    ("Full Orchestra", ["picc", "fl", "fl", "ob", "ob", "cl", "cl", "bsn", "bsn", "hn", "hn", "hn", "hn", "tpt", "tpt", "tpt",
                        "tbn", "tbn", "btbn", "tuba", "timp", "glock", "harp", "vln1", "vln2", "vla", "vc", "cb"]),
    ("Big Band", ["asax", "asax", "tsax", "tsax", "bsax", "tpt", "tpt", "tpt", "tpt", "tbn", "tbn", "tbn", "btbn", "gtr", "pno", "ubass", "kit"]),
]

/// Which of Middaw Synth's presets suits each instrument of the orchestra.
let presetFor: [String: String] = [
    "vln1": "solo", "vln2": "strings", "vla": "strings", "vc": "strings", "cb": "strings",
    "picc": "flute", "fl": "flute", "ob": "reed", "eh": "reed", "cl": "reed", "bcl": "reed", "bsn": "reed", "cbsn": "reed",
    "hn": "brass", "tpt": "brass", "tbn": "brass", "btbn": "brass", "tba": "brass", "tuba": "brass",
    "timp": "timpani", "glock": "bell", "xyl": "mallet", "mar": "mallet", "harp": "harp", "cel": "bell", "pno": "piano",
    "asax": "reed", "tsax": "reed", "bsax": "reed", "vib": "bell", "sop": "choir", "alto": "choir", "ten": "choir", "bass": "choir",
    "gtr": "pluck", "ebass": "bass", "ubass": "bass", "synth": "lead",
]

/// One window's view of its song: what is chosen, where the caret is, what
/// the editor shows - and every action a menu, a key or a button calls.
@MainActor
final class Session: ObservableObject {
    let document: SongDocument
    weak var undo: UndoManager?
    weak var window: NSWindow?

    @Published var selection = Selection()
    @Published var caret: Double = 0
    @Published var editor: EditorTab = .roll
    @Published var inspector: InspectorTab = .track
    @Published var grid: Double = 0.25
    @Published var drawing = false
    @Published var follow = true
    @Published var metronome = false
    @Published var recording = false
    @Published var arrangeZoom: CGFloat = 22        // points per beat
    @Published var rollZoom: CGFloat = 70
    @Published var status: String = ""
    @Published var statusOffersUndo = false
    @Published var statusIsWarning = false
    @Published var showBrowser = true
    @Published var position: Double = 0
    @Published var playing = false
    /// The Generate panel's state, kept while the inspector switches tabs.
    let generate = GenerateModel()

    private var take: [Note] = []
    private var open: [Int: (start: Double, vel: Int)] = [:]
    private var recordStart: Double = 0
    private var clipboard: (clip: Clip?, notes: [Note])?

    init(document: SongDocument) { self.document = document }

    var project: Project { document.project }
    var track: Track? { selection.trackID.flatMap { id in project.tracks.first { $0.id == id } } }
    var clip: Clip? {
        guard let id = selection.clipID, let loc = project.clipLocation(id) else { return nil }
        return project.tracks[loc.track].clips[loc.clip]
    }

    func commit(_ label: String, _ change: (inout Project) -> Void) {
        document.commit(label, undo, change)
        Studio.shared.sync(project)
        Pass.shared.event(label.hasPrefix("Add") ? "track" : "edit")
    }

    func say(_ text: String, undoable: Bool = false, warning: Bool = false) {
        status = text; statusOffersUndo = undoable; statusIsWarning = warning
    }

    func tick(position: Double, playing: Bool) {
        if self.playing != playing { self.playing = playing }
        if playing || self.position != position { self.position = position }
    }

    // --------------------------------------------------------- choosing --
    func select(track id: String?) {
        selection.trackID = id
        selection.range = nil
        if let t = track, selection.clipID == nil || !t.clips.contains(where: { $0.id == selection.clipID }) {
            selection.clipID = (t.clip(at: caret) ?? t.clips.first)?.id
            selection.notes = []
        }
    }
    func select(clip id: String, on trackID: String) {
        selection = Selection(trackID: trackID, clipID: id)
    }
    func choose(range tracks: [String], from s: Double, to e: Double) {
        selection.range = tracks.isEmpty || e <= s ? nil : (tracks, s, e)
        selection.clipID = nil
        selection.notes = []
        if let first = tracks.first { selection.trackID = first }
    }

    // ------------------------------------------------------- transport --
    func playStop(fromStart: Bool = false) {
        Studio.shared.becameActive(self)
        if Studio.shared.isPlaying { stop() } else { Studio.shared.play(from: fromStart ? 0 : caret) }
    }
    func stop() {
        Studio.shared.stop()
        if recording { finishRecording() }
    }
    func toStart() { caret = 0; if Studio.shared.isPlaying { Studio.shared.play(from: 0) } }
    func toEnd() { caret = project.endOfMusic }
    func toggleMetronome() { metronome.toggle(); Studio.shared.setMetronome(metronome) }
    func toggleLoop() {
        let wasPlaying = Studio.shared.isPlaying
        commit(project.loop.on ? "Loop Off" : "Loop On") { p in
            if let r = selection.range, !p.loop.on { p.loop = Loop(on: true, start: r.start, end: r.end) }
            else if !p.loop.on && !(p.loop.end > p.loop.start) { p.loop = Loop(on: true, start: 0, end: 4 * p.beatsPerBar) }
            else { p.loop.on.toggle() }
        }
        if wasPlaying { Studio.shared.play(from: Studio.shared.position) }
    }

    // ------------------------------------------------------ recording ---
    var targetTrackForInput: String? { project.tracks.first { $0.arm }?.id ?? selection.trackID }

    /// Record with the transport running takes what you play; stopped, each
    /// note goes in at the caret, a grid step long, and the caret moves on.
    func toggleRecord() {
        if recording { finishRecording(); return }
        guard targetTrackForInput != nil else { say("Add a track to record into."); return }
        recording = true
        take = []; open = [:]; recordStart = Studio.shared.isPlaying ? Studio.shared.position : caret
        say(Studio.shared.isPlaying ? "Recording." : "Step input: play notes on your MIDI keyboard.")
    }
    func received(_ status: UInt8, _ d1: UInt8, _ d2: UInt8, at beat: Double, playing: Bool) {
        guard recording else { return }
        let kind = status & 0xF0, on = kind == 0x90 && d2 > 0, off = kind == 0x80 || (kind == 0x90 && d2 == 0)
        if !playing {
            guard on else { return }
            insertBlock([Note(start: 0, len: grid, pitch: Int(d1), vel: Int(d2))], beats: grid, name: "Step")
            return
        }
        if on { open[Int(d1)] = (beat, Int(d2)) }
        else if off, let o = open.removeValue(forKey: Int(d1)) {
            take.append(Note(start: o.start, len: max(1.0 / 32, beat - o.start), pitch: Int(d1), vel: o.vel))
        }
    }
    func finishRecording() {
        recording = false
        guard let id = targetTrackForInput, !take.isEmpty else { return }
        let bpb = project.beatsPerBar
        let s = (take.map(\.start).min()! / bpb).rounded(.down) * bpb
        let e = (take.map(\.end).max()! / bpb).rounded(.up) * bpb
        let notes = take.map { Note(start: $0.start - s, len: $0.len, pitch: $0.pitch, vel: $0.vel) }
        var clipID: String?
        commit("Record") { p in clipID = p.place(notes, on: id, at: s, length: max(bpb, e - s), name: "Recording") }
        if let c = clipID { select(clip: c, on: id) }
        take = []
    }

    // --------------------------------------------------------- tracks ---
    func makeTrack(_ instrumentID: String, name: String? = nil, in p: Project) -> Track {
        let inst = Studio.shared.instrument(instrumentID)
        let drums = instrumentID == "kit" || (inst?.isDrums ?? false)
        let base = name ?? inst?.name ?? "Track"
        let count = p.tracks.filter { $0.instrument == instrumentID }.count
        return Track(name: name == nil && count > 0 ? "\(base) \(count + 1)" : base, instrument: instrumentID, drums: drums,
                     sound: Device(device: drums ? "kit" : "synth", preset: drums ? nil : (presetFor[instrumentID] ?? "keys")))
    }

    func addTrack(_ instrumentID: String) {
        var id: String?
        commit("Add Track") { p in let t = makeTrack(instrumentID, in: p); p.tracks.append(t); id = t.id }
        select(track: id)
    }

    func addEnsemble(_ name: String, _ ids: [String]) {
        var first: String?
        commit("Add \(name)") { p in
            for i in ids { let t = makeTrack(i, in: p); p.tracks.append(t); if first == nil { first = t.id } }
            if p.title == "Untitled" { p.title = name }
        }
        select(track: first)
        say("Added \(name): \(ids.count) \(ids.count == 1 ? "track" : "tracks").", undoable: true)
    }

    func deleteTrack(_ id: String) {
        let name = project.tracks.first { $0.id == id }?.name ?? "the track"
        commit("Delete Track") { p in p.tracks.removeAll { $0.id == id } }
        if selection.trackID == id { selection = Selection() }
        say("Deleted \(name).", undoable: true)
    }

    func duplicateTrack(_ id: String) {
        var nid: String?
        commit("Duplicate Track") { p in
            guard let i = p.trackIndex(id) else { return }
            var c = p.tracks[i]
            c.id = makeID("t"); c.name += " copy"
            for k in c.clips.indices { c.clips[k].id = makeID("c") }
            c.sound.id = makeID("d")
            p.tracks.insert(c, at: i + 1); nid = c.id
        }
        select(track: nid)
    }

    func setInstrument(_ trackID: String, _ instrumentID: String) {
        commit("Change Instrument") { p in
            guard let i = p.trackIndex(trackID) else { return }
            let inst = Studio.shared.instrument(instrumentID)
            let oldName = Studio.shared.instrument(p.tracks[i].instrument)?.name
            p.tracks[i].instrument = instrumentID
            p.tracks[i].drums = instrumentID == "kit"
            if p.tracks[i].drums { p.tracks[i].sound = Device(device: "kit") }
            else if p.tracks[i].sound.device == "kit" || p.tracks[i].sound.device == "synth" {
                p.tracks[i].sound = Device(device: "synth", preset: presetFor[instrumentID] ?? "keys")
            }
            if let n = inst?.name, p.tracks[i].name == oldName || p.tracks[i].name == "Track" { p.tracks[i].name = n }
        }
    }

    func updateTrack(_ id: String, _ label: String, _ change: (inout Track) -> Void) {
        commit(label) { p in if let i = p.trackIndex(id) { change(&p.tracks[i]) } }
    }

    // ---------------------------------------------------------- clips ---
    func updateClip(_ label: String, _ change: (inout Clip, Project) -> Void) {
        guard let id = selection.clipID else { return }
        commit(label) { p in
            guard let loc = p.clipLocation(id) else { return }
            let snapshot = p
            change(&p.tracks[loc.track].clips[loc.clip], snapshot)
        }
    }

    func newClip(on trackID: String, at beat: Double) {
        let bpb = project.beatsPerBar
        let start = (beat / bpb).rounded(.down) * bpb
        var cid: String?
        commit("New Clip") { p in cid = p.place([], on: trackID, at: start, length: bpb) }
        if let c = cid { select(clip: c, on: trackID) }
    }

    /// Notes at the caret, into the clip under it (or the one ending there,
    /// which grows to take them) - blocks laid in a row become one phrase.
    func insertBlock(_ notes: [Note], beats: Double, name: String) {
        guard let t = track else { say("Choose a track first."); return }
        let at = caret, bpb = project.beatsPerBar
        let into = t.clip(at: at) ?? t.clips.first { abs($0.end - at) < 1e-6 }
        var cid: String?
        commit("Insert \(name)") { p in
            guard let ti = p.trackIndex(t.id) else { return }
            if let into = into, let ci = p.tracks[ti].clips.firstIndex(where: { $0.id == into.id }) {
                let c = p.tracks[ti].clips[ci]
                let need = ((at + beats - c.start) / bpb - 1e-9).rounded(.up) * bpb
                if c.start + need > c.end + 1e-9 {
                    p.tracks[ti].clear(from: c.end, to: c.start + need)
                    if let k = p.tracks[ti].clips.firstIndex(where: { $0.id == into.id }) { p.tracks[ti].clips[k].length = need }
                }
                if let k = p.tracks[ti].clips.firstIndex(where: { $0.id == into.id }) {
                    for n in notes { p.tracks[ti].clips[k].notes.append(Note(start: at - c.start + n.start, len: n.len, pitch: n.pitch, vel: n.vel)) }
                    p.tracks[ti].clips[k].notes.sort { $0.start != $1.start ? $0.start < $1.start : $0.pitch < $1.pitch }
                }
                cid = into.id
            } else {
                cid = p.place(notes, on: t.id, at: at, length: max(beats, 0.25), name: name, source: ClipSource(generator: "Starting Blocks", title: name))
            }
        }
        if let c = cid { select(clip: c, on: t.id) }
        caret = at + beats
    }

    func deleteSelection() {
        if let c = clip, !selection.notes.isEmpty {
            let del = selection.notes
            updateClip("Delete Notes") { cl, _ in cl.notes = cl.notes.enumerated().filter { !del.contains($0.offset) }.map(\.element) }
            selection.notes = []
            _ = c
        } else if let c = clip, let tid = selection.trackID {
            commit("Delete Clip") { p in if let i = p.trackIndex(tid) { p.tracks[i].clips.removeAll { $0.id == c.id } } }
            selection.clipID = nil
        } else if let r = selection.range {
            commit("Clear the Chosen Bars") { p in for id in r.tracks { if let i = p.trackIndex(id) { p.tracks[i].clear(from: r.start, to: r.end) } } }
        }
    }

    func duplicate() {
        guard let c = clip, let tid = selection.trackID else { return }
        var nid: String?
        commit("Duplicate Clip") { p in if let i = p.trackIndex(tid) { nid = p.tracks[i].duplicate(clipID: c.id) } }
        if let n = nid { select(clip: n, on: tid) }
    }

    func split() {
        guard let c = clip, let tid = selection.trackID else { return }
        commit("Split Clip") { p in if let i = p.trackIndex(tid) { p.tracks[i].split(clipID: c.id, at: caret) } }
    }

    func copy() {
        guard let c = clip else { return }
        if selection.notes.isEmpty { clipboard = (c, []); say("Copied the clip.") }
        else { clipboard = (nil, selection.notes.sorted().map { c.notes[$0] }); say("Copied \(selection.notes.count) notes.") }
    }

    var canPaste: Bool { clipboard != nil }

    func paste() {
        guard let cb = clipboard, let t = track else { return }
        if var c = cb.clip {
            c.id = makeID("c")
            c.start = project.snap(caret, grid: project.beatsPerBar, floor: true)
            let copy = c
            commit("Paste Clip") { p in
                guard let i = p.trackIndex(t.id) else { return }
                p.tracks[i].clear(from: copy.start, to: copy.end)
                p.tracks[i].clips.append(copy)
                p.tracks[i].clips.sort { $0.start < $1.start }
            }
            select(clip: c.id, on: t.id)
        } else if let target = clip ?? t.clip(at: caret), let first = cb.notes.map(\.start).min() {
            let base = caret - target.start
            selection.clipID = target.id
            let n0 = target.notes.count
            updateClip("Paste Notes") { cl, _ in
                for n in cb.notes {
                    var x = n; x.start = base + n.start - first
                    if x.start >= 0 && x.start < cl.length { cl.notes.append(x) }
                }
            }
            selection.notes = Set(n0..<(n0 + cb.notes.count))
        }
    }

    func selectAllNotes() { if let c = clip { selection.notes = Set(c.notes.indices) } }

    private var chosenIndices: [Int] {
        guard let c = clip else { return [] }
        return selection.notes.isEmpty ? Array(c.notes.indices) : selection.notes.sorted()
    }

    func quantize() {
        guard clip != nil else { return }
        let idx = chosenIndices, g = grid
        updateClip("Quantize") { cl, p in
            let moved = p.quantized(idx.map { cl.notes[$0] }, grid: g, offset: cl.start)
            for (k, i) in idx.enumerated() { cl.notes[i] = moved[k] }
        }
    }

    func transpose(_ by: Int) {
        guard clip != nil else { return }
        let idx = chosenIndices
        updateClip(by > 0 ? "Transpose Up" : "Transpose Down") { cl, _ in
            for i in idx { cl.notes[i].pitch = max(0, min(127, cl.notes[i].pitch + by)) }
        }
    }

    func nudge(_ by: Double) {
        guard clip != nil, !selection.notes.isEmpty else { return }
        let idx = chosenIndices
        updateClip("Move Notes") { cl, _ in for i in idx { cl.notes[i].start = max(0, cl.notes[i].start + by) } }
    }

    enum Shape: String, CaseIterable {
        case invert = "Turn Upside Down", retrograde = "Play Backwards", half = "Half Speed", double = "Double Speed", key = "Fit to the Key"
    }

    /// Midi Catalogue's Shape It, on any clip. On a kit a note names a drum,
    /// so mirroring or keying it would swap instruments: not offered.
    func transform(_ shape: Shape) {
        guard clip != nil else { return }
        if track?.drums == true && (shape == .invert || shape == .key) {
            say("Drums have no key, so they are not turned or fitted to one."); return
        }
        updateClip(shape.rawValue) { cl, p in
            switch shape {
            case .invert: Transform.invert(&cl.notes, key: p.key)
            case .retrograde: Transform.retrograde(&cl.notes, length: cl.length)
            case .half: Transform.scaleTime(&cl.notes, by: 2); cl.length *= 2
            case .double: Transform.scaleTime(&cl.notes, by: 0.5); cl.length = max(p.beatsPerBar, cl.length / 2)
            case .key: Transform.fitToKey(&cl.notes, key: p.key)
            }
        }
    }

    /// AutoCC, the JSFX itself, run over the clip: its curves written into the
    /// clip's controller lanes, to edit like any other automation.
    func drawDynamics() {
        guard let c = clip, let t = track else { say("Choose a clip first."); return }
        guard let e = Studio.shared.engines else { say("The engines are still loading."); return }
        let fam = Studio.shared.instrument(t.instrument)?.family
        let style: Double = fam == "Strings" ? 1 : fam == "Brass" ? 2 : fam == "Woodwind" ? 3 : 0
        do {
            let lanes = try e.autoCC(notes: c.notes, length: c.length, project: project, sliders: [1: style])
            guard !lanes.isEmpty else { say("AutoCC drew nothing for this clip."); return }
            updateClip("Draw Dynamics with AutoCC") { cl, _ in for (k, v) in lanes { cl.cc[k] = v } }
            say("AutoCC drew CC\(lanes.keys.sorted().map(String.init).joined(separator: ", CC")) into the clip.", undoable: true)
        } catch { say("AutoCC stopped: \(error)", warning: true) }
    }

    // ---------------------------------------------------------- notes ---
    func setNotes(_ notes: [Note], label: String) { updateClip(label) { cl, _ in cl.notes = notes } }

    // ----------------------------------------------------------- files --
    func exportMIDI(clipOnly: Bool = false) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.midi]
        panel.nameFieldStringValue = (clipOnly ? (clip?.name.isEmpty == false ? clip!.name : "Clip") : project.title) + ".mid"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try MIDIFile.write(project.midiFile(onlyClip: clipOnly ? selection.clipID : nil)).write(to: url)
            say("Exported \(url.lastPathComponent).")
        } catch { say("The MIDI file could not be written: \(error.localizedDescription)", warning: true) }
    }

    func exportAudio() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.wav]
        panel.nameFieldStringValue = project.title + ".wav"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let p = project
        say("Rendering the song…")
        Task.detached(priority: .userInitiated) {
            let out = Bounce.render(p, sampleRate: 48000)
            let data = Bounce.wav(out.left, out.right, sampleRate: 48000)
            do {
                try data.write(to: url)
                await MainActor.run { self.say("Exported \(url.lastPathComponent).") }
            } catch {
                await MainActor.run { self.say("The audio could not be written: \(error.localizedDescription)", warning: true) }
            }
        }
    }

    // ------------------------------------------------------------ keys --
    /// Plain keys while no text field has them. Returns true when used.
    func handleKey(_ e: NSEvent) -> Bool {
        let shift = e.modifierFlags.contains(.shift), option = e.modifierFlags.contains(.option)
        switch e.keyCode {
        case 49: playStop(fromStart: shift); return true                        // space
        case 115: toStart(); return true                                         // home
        case 119: toEnd(); return true                                           // end
        case 51, 117: deleteSelection(); return true                             // delete
        case 126: if clip != nil { transpose(shift ? 12 : 1); return true }      // up
        case 125: if clip != nil { transpose(shift ? -12 : -1); return true }    // down
        case 123: if !selection.notes.isEmpty { nudge(-grid); return true }      // left
        case 124: if !selection.notes.isEmpty { nudge(grid); return true }       // right
        case 53:                                                                 // escape
            if selection.range != nil || !selection.notes.isEmpty { selection.range = nil; selection.notes = []; return true }
            return false
        default: break
        }
        if option { return false }
        switch e.charactersIgnoringModifiers?.lowercased() ?? "" {
        case "r": toggleRecord()
        case "l": toggleLoop()
        case "c": toggleMetronome()
        case "f": follow.toggle()
        case "g": inspector = inspector == .generate ? .track : .generate
        case "m": editor = editor == .mixer ? .roll : .mixer
        case "b": showBrowser.toggle()
        case "d": drawing.toggle()
        case "q": quantize()
        case "1": grid = 4
        case "2": grid = 2
        case "3": grid = 1
        case "4": grid = 0.5
        case "5": grid = 0.25
        case "6": grid = 0.125
        default: return false
        }
        return true
    }
}
