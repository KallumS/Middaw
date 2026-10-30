import SwiftUI
import AppKit
import MiddawCore
import MiddawEngines

/// Compose (Middaw's own prompt -> five parts), and the family's generators:
/// Good Idea, Midi Suggester, Midi Variator. Every result is heard before it
/// is used, and is placed by Miderator's rules.
@MainActor
final class GenerateModel: ObservableObject {
    /// Set by a menu or a button that wants a particular generator open.
    static var request: String? {
        didSet { NotificationCenter.default.post(name: .middawGenerate, object: nil) }
    }

    @Published var which = "compose"
    @Published var settings: [Engines.Setting] = []
    @Published var results: [Engines.Result] = []
    @Published var message: String?
    @Published var busy = false
    @Published var seed = Int.random(in: 1...9999)
    @Published var prompt = ""
    @Published var composed: Composer.Composition?
    private var sessions: [String: Engines.Session] = [:]

    func session(_ id: String) throws -> Engines.Session {
        if let s = sessions[id] { return s }
        guard let e = Studio.shared.engines else { throw Engines.Failure(description: "The engines are still loading.") }
        let s = try e.session(id)
        sessions[id] = s
        return s
    }

    /// Where the music goes and what the generator is told about it.
    func context(_ s: Session) -> Engines.Context {
        let p = s.project
        let bars = s.selection.range.map { max(1, Int((($0.end - $0.start) / p.beatsPerBar).rounded())) } ?? 4
        var sel: [Note] = [], beats = 0.0, drums = false
        if let c = s.clip {
            let idx = s.selection.notes.isEmpty ? Array(c.notes.indices) : s.selection.notes.sorted()
            sel = idx.map { c.notes[$0] }.filter { $0.start < c.length }
            beats = c.length
            drums = s.track?.drums ?? false
        }
        return Engines.Context(project: p, instrument: s.track?.instrument ?? "pno", bars: bars,
                               selection: sel, selectionBeats: beats, drums: drums)
    }

    func refresh(_ s: Session) {
        guard which != "compose" else { return }
        do {
            let ses = try session(which)
            try ses.useKey(s.project.key)
            settings = try ses.settings(context(s))
        } catch { message = "\(error)" }
    }

    func set(_ id: String, _ index: Int, _ s: Session) {
        do { try session(which).set(id, to: index, context(s)); refresh(s) } catch { message = "\(error)" }
    }

    func generate(_ s: Session, newSeed: Bool = false) {
        if newSeed { seed = Int.random(in: 1...9999) }
        if which == "compose" { compose(s); return }
        if (which == "midi-variator" || which == "midi-suggester") && s.clip == nil {
            message = "Choose a clip first: \(which == "midi-variator" ? "variations are made from it" : "suggestions go with it")."
            return
        }
        do {
            let ses = try session(which)
            try ses.useKey(s.project.key)
            let r = try ses.generate(context(s), seed: seed, count: 6)
            results = r.results
            message = r.message ?? (r.results.isEmpty ? "Nothing came of those settings. Try others." : nil)
            Pass.shared.event("idea")
        } catch { message = "\(error)" }
    }

    func compose(_ s: Session) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { message = "Describe some music first."; return }
        busy = true
        message = nil
        let seed = self.seed
        Task.detached(priority: .userInitiated) {
            let result = Result { try Composer.compose(text, seed: seed) }
            await MainActor.run {
                self.busy = false
                switch result {
                case .success(let c):
                    self.composed = c
                    self.seed = c.spec.seed ?? seed
                    if let u = c.spec.unmatchedTerms, !u.isEmpty { self.message = "Not understood yet, so left out: \(u.joined(separator: ", "))" }
                    Pass.shared.event("idea")
                case .failure(let e): self.message = "\(e)"
                }
            }
        }
    }

    // ------------------------------------------------------------ placing --
    /// Moved by octaves to sit best in the instrument; one note at a time for
    /// an instrument that plays one (the top note, or the bottom for a bass).
    static func fit(_ notes: [Note], to inst: Engines.Instrument?, bass: Bool) -> [Note] {
        guard let i = inst, !i.isDrums, let lo = i.low, let hi = i.high else { return notes }
        var out = notes
        if i.poly == 1 {
            var by: [Int: [Note]] = [:]
            for n in out { by[Int((n.start * 960).rounded()), default: []].append(n) }
            out = by.keys.sorted().map { k in
                let g = by[k]!.sorted { $0.pitch > $1.pitch }
                return bass ? g.last! : g.first!
            }
            for j in 0..<max(0, out.count - 1) { out[j].len = min(out[j].len, out[j + 1].start - out[j].start) }
        }
        var best = 0, bestMiss = Int.max
        for shift in stride(from: -48, through: 48, by: 12) {
            let miss = out.reduce(0) { m, n in
                let p = n.pitch + shift
                return m + (p < lo ? lo - p : p > hi ? p - hi : 0)
            }
            if miss < bestMiss || (miss == bestMiss && abs(shift) < abs(best)) { best = shift; bestMiss = miss }
        }
        return out.map { var n = $0; n.pitch = max(0, min(127, n.pitch + best)); return n }
    }

    func use(_ r: Engines.Result, in s: Session) {
        Preview.shared.stop()
        let p = s.project, bpb = p.beatsPerBar
        switch which {
        case "midi-variator":
            guard s.clip != nil else { return }
            let notes = r.notes
            s.updateClip("Use a Variation") { cl, _ in cl.notes = notes }
            s.say("Used \(r.title).", undoable: true)
        case "midi-suggester":
            // Beside the music it goes with, on a new track (Miderator 0040).
            guard let c = s.clip, let t = s.track else { return }
            var made: [String] = []
            s.commit("Use a Suggestion") { q in
                guard var at = q.trackIndex(t.id) else { return }
                for part in r.parts where !part.notes.isEmpty {
                    let chords = part.name.lowercased().contains("chord")
                    let bass = part.name.lowercased().contains("bass")
                    let instID = part.drums ? "kit" : (bass ? "ubass" : (chords ? "pno" : t.instrument))
                    var nt = s.makeTrack(instID, name: part.name.isEmpty ? "Suggestion" : part.name, in: q)
                    nt.role = chords ? "chords" : (bass ? "bass" : "melody")
                    if chords { nt.sound.preset = "epiano" }
                    q.tracks.insert(nt, at: at + 1)
                    at += 1
                    q.place(GenerateModel.fit(part.notes, to: Studio.shared.instrument(instID), bass: bass), on: nt.id, at: c.start,
                            length: c.length, name: r.title, source: ClipSource(generator: "Midi Suggester", title: r.title))
                    made.append(nt.id)
                }
            }
            if let first = made.first { s.select(track: first) }
            s.say("Added \(r.title) on \(made.count == 1 ? "a new track" : "\(made.count) new tracks").", undoable: true)
        default:
            // Into the chosen bars, else at the caret, on the chosen track; a
            // drum idea on a kit; further parts on tracks of their own.
            let start = s.selection.range?.start ?? (s.caret / bpb).rounded(.down) * bpb
            let length = max(bpb, (max(r.beats, r.notes.map(\.end).max() ?? 0) / bpb).rounded(.up) * bpb)
            var targets = s.selection.range?.tracks ?? (s.selection.trackID.map { [$0] } ?? [])
            var made: [String] = []
            s.commit("Insert \(r.title)") { q in
                for (k, part) in r.parts.enumerated() where !part.notes.isEmpty {
                    var tid: String? = k < targets.count ? targets[k] : nil
                    if let id = tid, let ti = q.trackIndex(id), q.tracks[ti].drums != part.drums { tid = nil }
                    if tid == nil {
                        let bass = part.name.lowercased().contains("bass")
                        let nt = s.makeTrack(part.drums ? "kit" : (bass ? "ubass" : "pno"), name: part.name.isEmpty ? nil : part.name, in: q)
                        q.tracks.append(nt)
                        tid = nt.id
                        targets.append(nt.id)
                    }
                    guard let id = tid, let ti = q.trackIndex(id) else { continue }
                    let inst = Studio.shared.instrument(q.tracks[ti].instrument)
                    let bass = part.name.lowercased().contains("bass") || q.tracks[ti].role == "bass"
                    q.place(GenerateModel.fit(part.notes, to: inst, bass: bass), on: id, at: start, length: length,
                            name: r.title, source: ClipSource(generator: Studio.shared.generators.first { $0.id == which }?.name ?? which, title: r.title, seed: seed))
                    made.append(id)
                }
                q.bars = max(q.bars, Int((q.endOfMusic / q.beatsPerBar).rounded(.up)) + 4)
            }
            if let first = made.first { s.select(track: first) }
            s.say("Inserted \(r.title).", undoable: true)
        }
        Pass.shared.event("notes", r.notes.count)
    }

    /// The composition becomes the song - or is added to it at the caret.
    func useComposed(in s: Session, replace: Bool) {
        guard let c = composed else { return }
        Preview.shared.stop()
        let bpbAfter = Double(c.song.meter[0]) * 4 / Double(c.song.meter[1])
        let at = replace || s.project.tracks.isEmpty ? 0 : (s.caret / s.project.beatsPerBar).rounded(.down) * s.project.beatsPerBar
        let asSong = replace || s.project.tracks.isEmpty
        var first: String?
        s.commit(asSong ? "Compose" : "Add a Composition") { q in
            if asSong {
                q.tracks = []
                q.tempo = c.spec.tempo
                q.meter = c.song.meter
                q.key = c.key
                q.title = String(c.spec.prompt?.prefix(60) ?? "Composed")
            }
            for part in c.song.tracks where !part.notes.isEmpty {
                let role = part.role == "harmony" ? "chords" : (part.role == "countermelody" ? "counter" : part.role)
                let inst = ["melody": "pno", "counter": "vla", "chords": "pno", "bass": "ubass", "drums": "kit"][role] ?? "pno"
                var t = s.makeTrack(inst, name: part.name + (part.detail.isEmpty ? "" : " (\(part.detail))"), in: q)
                t.role = role
                if role == "chords" { t.sound.preset = "epiano" }
                if role == "melody" { t.sound.preset = "piano" }
                q.tracks.append(t)
                let bars = Double(c.spec.bars ?? Int((c.song.lengthBeats / bpbAfter).rounded(.up)))
                q.place(part.notes, on: t.id, at: at, length: bars * q.beatsPerBar,
                        name: (c.spec.formName ?? "Composed").replacingOccurrences(of: "_", with: " ").capitalized,
                        source: ClipSource(generator: "Compose", title: c.spec.prompt, seed: c.spec.seed))
                if first == nil { first = t.id }
            }
            q.bars = max(q.bars, Int((q.endOfMusic / q.beatsPerBar).rounded(.up)) + 4)
        }
        s.select(track: first)
        s.caret = at
        s.say("Composed: \(c.summary)", undoable: true)
    }
}

extension Notification.Name { static let middawGenerate = Notification.Name("middaw.generate") }

struct GenerateView: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @ObservedObject var model: GenerateModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $model.which) {
                Text("Compose").tag("compose")
                Text("Idea").tag("good-idea")
                Text("Suggest").tag("midi-suggester")
                Text("Vary").tag("midi-variator")
            }
            .pickerStyle(.segmented).labelsHidden()
            .onChange(of: model.which) { _, _ in model.results = []; model.message = nil; model.refresh(s) }

            if model.which == "compose" { compose } else { engine }

            if let m = model.message { Text(m).foregroundStyle(Theme.warnText).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true) }

            if model.which == "compose" {
                if let c = model.composed { composedCard(c) }
            } else {
                ForEach(Array(model.results.enumerated()), id: \.offset) { _, r in resultCard(r) }
            }
        }
        .onAppear { takeRequest(); model.refresh(s) }
        .onReceive(NotificationCenter.default.publisher(for: .middawGenerate)) { _ in takeRequest() }
        .onChange(of: s.selection.clipID) { _, _ in model.refresh(s) }
    }

    func takeRequest() {
        if let r = GenerateModel.request { model.which = r; GenerateModel.request = nil; model.refresh(s); model.generate(s) }
    }

    var compose: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $model.prompt)
                .font(.system(size: 13))
                .frame(minHeight: 64, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.sunken))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.edge))
                .accessibilityLabel("Describe the music")
            HStack(spacing: 6) {
                Button(model.busy ? "Composing…" : "Compose") { model.generate(s) }.house(primary: true).disabled(model.busy)
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Another Take") { model.generate(s, newSeed: true) }.house().disabled(model.busy || model.composed == nil)
            }
        }
    }

    var engine: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.settings) { setting in
                VStack(alignment: .leading, spacing: 3) {
                    Text(setting.label).foregroundStyle(Theme.label).font(.system(size: 12))
                    Picker(setting.label, selection: Binding(get: { setting.index }, set: { model.set(setting.id, $0, s) })) {
                        ForEach(Array(setting.names.enumerated()), id: \.offset) { i, n in Text(n).tag(i + 1) }
                    }
                    .labelsHidden()
                    .help(setting.hint ?? "")
                }
            }
            HStack(spacing: 6) {
                Button("Generate") { model.generate(s) }.house(primary: true)
                Button("More Ideas") { model.generate(s, newSeed: true) }.house()
                if model.which == "good-idea" {
                    Text("Idea").foregroundStyle(Theme.label)
                    TextField("Idea", value: $model.seed, format: .number.grouping(.never)).frame(width: 60)
                }
            }
        }
    }

    func resultCard(_ r: Engines.Result) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(r.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
            if !r.detail.isEmpty { Text(r.detail).font(.system(size: 12)).foregroundStyle(Theme.textDim).lineLimit(4) }
            MiniRoll(parts: r.parts.map { (notes: $0.notes, drums: $0.drums) }, beats: max(r.beats, 1))
                .frame(height: 34)
            HStack(spacing: 6) {
                Button("Hear") { Preview.shared.play(r.parts.map { (notes: $0.notes, drums: $0.drums) }, tempo: s.project.tempo) }.house()
                Button(model.which == "midi-variator" ? "Use" : "Insert") { model.use(r, in: s) }.house(primary: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised))
    }

    func composedCard(_ c: Composer.Composition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(c.summary).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            Text(c.chords.prefix(8).map(\.symbol).joined(separator: "  ")).font(.system(size: 12)).foregroundStyle(Theme.textDim)
            MiniRoll(parts: c.song.tracks.map { (notes: $0.notes, drums: $0.role == "drums") }, beats: max(1, c.song.lengthBeats))
                .frame(height: 40)
            HStack(spacing: 6) {
                if s.project.tracks.isEmpty {
                    Button("Use as the Song") { model.useComposed(in: s, replace: true) }.house(primary: true)
                } else {
                    Button("Add to the Song") { model.useComposed(in: s, replace: false) }.house(primary: true)
                    Button("Replace the Song") { model.useComposed(in: s, replace: true) }.house()
                }
                Button("Hear") {
                    Preview.shared.play(c.song.tracks.map { (notes: $0.notes, drums: $0.role == "drums") }, tempo: c.spec.tempo)
                }.house()
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised))
    }
}

/// A result's notes, small: the tune in the accent, the rest grey (Good Idea 0009).
struct MiniRoll: View {
    let parts: [(notes: [Note], drums: Bool)]
    let beats: Double
    var body: some View {
        Canvas { g, size in
            g.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4), with: .color(Theme.sunken))
            let all = parts.flatMap(\.notes)
            guard let lo = all.map(\.pitch).min(), let hi = all.map(\.pitch).max() else { return }
            let span = Double(max(12, hi - lo))
            for (k, part) in parts.enumerated() {
                for n in part.notes {
                    let x = CGFloat(n.start / beats) * size.width
                    let w = max(1.5, CGFloat(n.len / beats) * size.width - 1)
                    let y = size.height - 3 - CGFloat(Double(n.pitch - lo) / span) * (size.height - 6)
                    g.fill(Path(CGRect(x: x, y: y - 1, width: w, height: 2)), with: .color(k == 0 && !part.drums ? Theme.accent : Theme.note))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Midi Catalogue's ideas, in the browser: browse by kind, hear, insert.
struct IdeasView: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @StateObject private var model = CatalogueModel()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("For the \(studio.instrument(s.track?.instrument ?? "pno")?.name ?? "Piano"), in \(s.project.key.displayName)")
                    .foregroundStyle(Theme.textDim).font(.system(size: 12))
                ForEach(model.settings) { setting in
                    Row(label: setting.label) {
                        Picker("", selection: Binding(get: { setting.index }, set: { model.set(setting.id, $0, s) })) {
                            ForEach(Array(setting.names.enumerated()), id: \.offset) { i, n in Text(n).tag(i + 1) }
                        }.labelsHidden()
                    }
                }
                Button("Browse") { model.browse(s) }.house(primary: true)
                ForEach(Array(model.results.enumerated()), id: \.offset) { _, r in
                    HStack(spacing: 6) {
                        Text(r.title).foregroundStyle(Theme.text).font(.system(size: 12)).lineLimit(2)
                        Spacer()
                        Button("Hear") { Preview.shared.play(r.parts.map { (notes: $0.notes, drums: $0.drums) }, tempo: s.project.tempo) }.house(compact: true)
                        Button("Insert") { s.insertBlock(r.notes, beats: r.beats, name: r.title) }.house(primary: true, compact: true)
                    }
                }
            }
            .padding(10)
        }
        .onAppear { model.refresh(s) }
        .onChange(of: studio.engines != nil) { _, _ in model.refresh(s) }
    }
}

@MainActor
final class CatalogueModel: ObservableObject {
    @Published var settings: [Engines.Setting] = []
    @Published var results: [Engines.Result] = []
    private var session: Engines.Session?
    func context(_ s: Session) -> Engines.Context { Engines.Context(project: s.project, instrument: s.track?.instrument ?? "pno", bars: 4) }
    func refresh(_ s: Session) {
        guard let e = Studio.shared.engines else { return }
        if session == nil { session = try? e.session("midi-catalogue") }
        try? session?.useKey(s.project.key)
        settings = (try? session?.settings(context(s))) ?? []
    }
    func set(_ id: String, _ index: Int, _ s: Session) { try? session?.set(id, to: index, context(s)); refresh(s) }
    func browse(_ s: Session) {
        try? session?.useKey(s.project.key)
        results = (try? session?.generate(context(s), seed: Int.random(in: 1...9999), count: 24).results) ?? []
    }
}
