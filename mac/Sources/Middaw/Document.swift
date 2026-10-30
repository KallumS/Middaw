import SwiftUI
import UniformTypeIdentifiers
import MiddawCore

extension UTType {
    /// A Middaw song: the same JSON the browser version saved.
    static let middawSong = UTType(exportedAs: "com.kallums.middaw.song", conformingTo: .json)
    static let standardMIDI = UTType(importedAs: "public.midi-audio", conformingTo: .audio)
}

/// One song in one window. Every change is one undo step with a name, on the
/// window's own UndoManager, so Edit > Undo says what it undoes and the
/// window knows when it has unsaved changes.
final class SongDocument: ReferenceFileDocument, ObservableObject {
    @Published private(set) var project: Project

    static var readableContentTypes: [UTType] { [.middawSong, .standardMIDI, .midi, .json] }
    static var writableContentTypes: [UTType] { [.middawSong] }

    init() {
        var p = Project()
        p.returns = [Return(audioFx: [])]
        project = p
    }

    init(project: Project) { self.project = project }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        if data.starts(with: Array("MThd".utf8)) {
            project = try SongDocument.importMIDI(data, title: configuration.file.filename ?? "Imported")
        } else {
            project = try JSONDecoder().decode(Project.self, from: data)
        }
    }

    func snapshot(contentType: UTType) throws -> Project { project }

    func fileWrapper(snapshot: Project, configuration: WriteConfiguration) throws -> FileWrapper {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return FileWrapper(regularFileWithContents: try enc.encode(snapshot))
    }

    /// Change the song as one named undo step. A change that changes nothing
    /// is not a step.
    func commit(_ label: String, _ undo: UndoManager?, _ change: (inout Project) -> Void) {
        var next = project
        change(&next)
        guard next != project else { return }
        replace(with: next, label: label, undo: undo)
    }

    private func replace(with next: Project, label: String, undo: UndoManager?) {
        let old = project
        project = next
        undo?.registerUndo(withTarget: self) { doc in doc.replace(with: old, label: label, undo: undo) }
        undo?.setActionName(label)
    }

    /// A Standard MIDI File as a song: a track per MIDI track with notes, the
    /// kit on channel 10.
    static func importMIDI(_ data: Data, title: String) throws -> Project {
        let file = try MIDIFile.read(data)
        var p = Project(title: (title as NSString).deletingPathExtension, tempo: file.tempo.rounded(), meter: [file.meter.0, file.meter.1])
        let bpb = p.beatsPerBar
        for t in file.tracks where !t.notes.isEmpty || !t.controls.isEmpty {
            let drums = t.channel == 9
            var track = Track(name: t.name.isEmpty ? (drums ? "Drums" : "Track \(p.tracks.count + 1)") : t.name,
                              instrument: drums ? "kit" : "pno", drums: drums,
                              sound: Device(device: drums ? "kit" : "synth", preset: drums ? nil : "piano"))
            let end = t.notes.map(\.end).max() ?? 0
            let length = max(bpb, (end / bpb).rounded(.up) * bpb)
            var cc: [Int: [CCPoint]] = [:]
            for c in t.controls { cc[c.controller, default: []].append(CCPoint(beat: c.start, value: c.value)) }
            track.clips = [Clip(name: p.title, start: 0, length: length,
                                notes: t.notes.map { Note(start: $0.start, len: $0.duration, pitch: $0.pitch, vel: Int($0.velocity)) },
                                cc: cc)]
            p.tracks.append(track)
        }
        p.bars = max(p.bars, Int((p.endOfMusic / bpb).rounded(.up)) + 4)
        p.returns = [Return(audioFx: [])]
        return p
    }
}
