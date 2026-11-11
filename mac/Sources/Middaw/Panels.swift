import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVFoundation
import MiddawCore
import MiddawEngines
import MiddawAudio

// ------------------------------------------------------------- inspector --
/// The chosen player: what they play, where they sit, what plays them, how
/// loud - and what Orchestration Helper says about the instrument. Generate
/// shares the same column.
struct InspectorView: View {
    @EnvironmentObject var s: Session
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $s.inspector) {
                Text("Player").tag(InspectorTab.track)
                Text("Generate").tag(InspectorTab.generate)
            }
            .pickerStyle(.segmented).labelsHidden()
            .padding(10)
            Divider().overlay(Theme.rule)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if s.inspector == .generate { GenerateView(model: s.generate) } else { TrackInspector() }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.ground)
    }
}

struct TrackInspector: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var name = ""
    @State private var volume = 0.8

    var body: some View {
        if let t = s.track {
            VStack(alignment: .leading, spacing: 10) {
                Row(label: "Name") {
                    TextField("Name", text: $name).onSubmit {
                        let n = name.trimmingCharacters(in: .whitespaces)
                        if !n.isEmpty { s.updateTrack(t.id, "Rename Track") { $0.name = n } }
                    }
                }
                Row(label: "Instrument") {
                    Picker("", selection: Binding(get: { t.instrument }, set: { s.setInstrument(t.id, $0) })) {
                        ForEach(families, id: \.0) { fam, list in
                            Section(fam) { ForEach(list) { i in Text(i.name).tag(i.id) } }
                        }
                    }.labelsHidden()
                }
                if let i = studio.instrument(t.instrument), let lo = i.low, let hi = i.high {
                    Text(rangeText(i, lo, hi)).foregroundStyle(Theme.textDim).font(.system(size: 12))
                }
                Row(label: "Sits") {
                    Picker("", selection: Binding(get: { t.seat ?? "" }, set: { s.place(t.id, seat: $0.isEmpty ? nil : $0) })) {
                        Text("At the Front").tag("")
                        ForEach(StageSection.allCases, id: \.self) { sec in
                            let open = Stage.seats.filter { $0.section == sec && ($0.id == t.seat || !s.project.takenSeats.contains($0.id)) }
                            if !open.isEmpty { Section(sec.name) { ForEach(open) { seat in Text(seat.name).tag(seat.id) } } }
                        }
                    }.labelsHidden()
                }
                Text(placeText(t)).foregroundStyle(Theme.textDim).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }
            .onAppear { load(t) }
            .onChange(of: t.id) { _, _ in load(t) }

            if let c = s.clip {
                Divider().overlay(Theme.rule)
                Text("Clip").heading()
                Text("Bar \(s.project.bar(of: c.start) + 1), \(barsText(c.length)), \(c.notes.count) notes")
                    .foregroundStyle(Theme.textDim).font(.system(size: 12))
                if let src = c.source, let g = src.generator {
                    Text("Made with \(g)\(src.title.map { ": \($0)" } ?? "")").foregroundStyle(Theme.textDim).font(.system(size: 12)).lineLimit(2)
                }
                HStack(spacing: 6) {
                    Button("Vary…") { s.inspector = .generate; GenerateModel.request = "midi-variator" }.house()
                    Button("Suggest…") { s.inspector = .generate; GenerateModel.request = "midi-suggester" }.house()
                    Menu("More") {
                        Menu("Transform") { ForEach(Session.Shape.allCases, id: \.self) { sh in Button(sh.rawValue) { s.transform(sh) } } }
                        Button("Draw Dynamics with AutoCC") { s.drawDynamics() }
                    }
                    .fixedSize()
                }
            }

            Divider().overlay(Theme.rule)
            Text("Sound").heading()
            SoundPanel(track: t)

            Divider().overlay(Theme.rule)
            Text("Mix").heading()
            Row(label: "Level") {
                Slider(value: $volume, in: 0...1) { editing in if !editing { s.updateTrack(t.id, "Change Level") { $0.volume = volume } } }
                Text(dbText(volume)).frame(width: 52, alignment: .trailing).foregroundStyle(Theme.text).monospacedDigit()
            }
            HStack(spacing: 4) {
                Button("Mute") { s.updateTrack(t.id, t.mute ? "Unmute" : "Mute") { $0.mute.toggle() } }.house(on: t.mute, compact: true)
                Button("Solo") { s.updateTrack(t.id, t.solo ? "Unsolo" : "Solo") { $0.solo.toggle() } }.house(on: t.solo, compact: true)
            }

            if let entry = OrchestrationGuide.shared.entry(for: t.instrument, name: studio.instrument(t.instrument)?.name) {
                Divider().overlay(Theme.rule)
                Text("About the \(entry.title)").heading()
                Text(entry.summary).foregroundStyle(Theme.text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text("Choose a player on the stage, or describe some music in Generate.").foregroundStyle(Theme.textDim)
        }
    }

    func load(_ t: Track) { name = t.name; volume = t.volume }

    /// Where the player is heard from: the seat's distance and side in the hall.
    func placeText(_ t: Track) -> String {
        guard let seat = Stage.seat(t.seat) else { return "Heard as it is: no hall, in the middle." }
        let hall = Hall.named(s.project.hall)
        let sound = Stage.sound(seat, in: hall)
        let db = 20 * log10(sound.direct)
        return String(format: "%.1f m from the microphones, %@, direct sound %.1f dB, in the %@.",
                      sound.distance, panText(sound.pan).lowercased(), db, hall.name)
    }

    var families: [(String, [Engines.Instrument])] {
        var order: [String] = []
        var by: [String: [Engines.Instrument]] = [:]
        for i in studio.instruments where i.low != nil || i.isDrums {
            let f = i.family ?? "Other"
            if by[f] == nil { order.append(f) }
            by[f, default: []].append(i)
        }
        return order.map { ($0, by[$0]!) }
    }

    func rangeText(_ i: Engines.Instrument, _ lo: Int, _ hi: Int) -> String {
        var s = "\(Theory.noteName(lo)) to \(Theory.noteName(hi))"
        if let sw = i.sweet, sw.count == 2 { s += ", best \(Theory.noteName(sw[0]))–\(Theory.noteName(sw[1]))" }
        if let p = i.poly { s += p == 1 ? ", one note at a time" : ", \(p) notes at once" }
        return s
    }
    func barsText(_ beats: Double) -> String {
        let bars = beats / s.project.beatsPerBar
        return bars == bars.rounded() ? "\(Int(bars)) \(bars == 1 ? "bar" : "bars")" : String(format: "%.2f bars", bars)
    }
}

func dbText(_ v: Double) -> String {
    if v <= 0 { return "−∞ dB" }
    let db = (v - 0.8) * 60
    return String(format: "%@%.1f dB", db > 0.05 ? "+" : "", db)
}
func panText(_ p: Double) -> String {
    abs(p) < 0.05 ? "Centre" : (p < 0 ? "Left \(Int((-p * 100).rounded()))" : "Right \(Int((p * 100).rounded()))")
}

/// What plays the track: Middaw Synth's presets, the kit, or the Instant
/// Instrument - a sound dropped on the track, played across the keyboard.
struct SoundPanel: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    let track: Track
    @State private var dropping = false
    @State private var choosing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Row(label: "Played by") {
                Picker("", selection: Binding(get: { track.sound.device }, set: { setDevice($0) })) {
                    Text("Middaw Synth").tag("synth")
                    Text("Drum Kit").tag("kit")
                    Text("Instant Instrument").tag("sampler")
                    ForEach(DeviceCatalog.of(.instrument), id: \.id) { d in Text(d.name).tag(d.id) }
                    if track.sound.device == "au" { Text(track.sound.plugin?.name ?? "Audio Unit").tag("au") }
                }.labelsHidden()
            }
            HStack(spacing: 6) {
                Button("Audio Units…") { choosing = true }.house()
                    .help("Play this part with an Audio Unit instrument on this Mac")
                    .popover(isPresented: $choosing) {
                        SoundMenu(title: track.name, instrument: track.instrument, section: Stage.seat(track.seat)?.section,
                                  drums: track.drums, current: track.sound) { c in choosing = false; s.setSound(track.id, c) }
                            .environmentObject(studio)
                    }
                if track.sound.device == "au" {
                    Button("Show Its Window") { PluginWindows.shared.show(track.sound.id, title: "\(track.name) – \(track.sound.plugin?.name ?? "")") }.house()
                }
            }
            if let why = studio.audio.plugins.failures[track.sound.id] {
                Text(why).foregroundStyle(Theme.warnText).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }
            if DeviceCatalog.info(track.sound.device) != nil {
                Button("Show Its Controls") { s.select(track: track.id); s.editor = .devices }.house()
            }
            if track.sound.device == "synth" {
                Row(label: "Preset") {
                    Picker("", selection: Binding(get: { track.sound.preset ?? "keys" }, set: { v in s.updateTrack(track.id, "Change Sound") { $0.sound.preset = v } })) {
                        ForEach(SynthPreset.all, id: \.id) { p in Text(p.name).tag(p.id) }
                    }.labelsHidden()
                }
            }
            if track.sound.device == "sampler" {
                Text(track.sound.sample?.name ?? "Add a Sound…")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(Theme.text)
                    .background(RoundedRectangle(cornerRadius: 6).strokeBorder(dropping ? Theme.accent : Theme.edge, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .contentShape(Rectangle())
                    .onTapGesture { choose() }
                    .onDrop(of: [.fileURL], isTargeted: $dropping) { providers in
                        _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                            if let u = url { Task { @MainActor in load(u) } }
                        }
                        return true
                    }
                    .help("Drop a sound here, or click to choose one")
                if track.sound.sample != nil {
                    Row(label: "Its pitch") {
                        Picker("", selection: Binding(get: { track.sound.sample?.root ?? 60 }, set: { v in s.updateTrack(track.id, "Change Root") { $0.sound.sample?.root = v } })) {
                            ForEach(36...84, id: \.self) { p in Text(Theory.noteName(p)).tag(p) }
                        }.labelsHidden()
                    }
                }
            }
        }
    }

    func setDevice(_ d: String) {
        guard d != "au" else { return }
        s.updateTrack(track.id, "Change Sound") { t in
            t.sound = DeviceCatalog.info(d) != nil ? Session.makeDevice(d) : Device(device: d, preset: d == "synth" ? (presetFor[t.instrument] ?? "keys") : nil)
            t.drums = d == "kit" ? true : (t.instrument == "kit")
        }
    }

    func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        if panel.runModal() == .OK, let u = panel.url { load(u) }
    }

    /// Up to sixteen seconds of the sound, kept in the song.
    func load(_ url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frames = AVAudioFrameCount(min(Double(file.length), format.sampleRate * 16))
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
            try file.read(into: buf, frameCount: frames)
            guard let data = buf.floatChannelData else { return }
            let n = Int(buf.frameLength)
            let left = Array(UnsafeBufferPointer(start: data[0], count: n))
            let right = format.channelCount > 1 ? Array(UnsafeBufferPointer(start: data[1], count: n)) : nil
            let sample = SampleCodec.encode(name: url.lastPathComponent, left: left, right: right, rate: format.sampleRate, root: 60)
            s.updateTrack(track.id, "Load a Sound") { $0.sound.sample = sample }
            s.say("Loaded \(url.lastPathComponent).")
        } catch {
            s.say("That sound could not be read: \(error.localizedDescription)", warning: true)
        }
    }
}

// ----------------------------------------------------------- the browser --
/// Ensembles and instruments to add; Midi Catalogue's ideas; Orchestration
/// Helper's guide.
struct BrowserView: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var tab = 0
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Sounds").tag(0); Text("Ideas").tag(1); Text("Guide").tag(2)
            }
            .pickerStyle(.segmented).labelsHidden().padding(10)
            Divider().overlay(Theme.rule)
            switch tab {
            case 0: sounds
            case 1: IdeasView()
            default: guide
            }
        }
        .background(Theme.ground)
    }

    var sounds: some View {
        List {
            Section("Ensembles") {
                ForEach(ensembles, id: \.name) { e in
                    Button(e.name) { s.addEnsemble(e.name, e.ids, stage: e.stage) }.buttonStyle(.plain)
                        .help(e.stage ? "Seat \(e.ids.count) \(e.ids.count == 1 ? "player" : "players") on the stage"
                                      : "Add \(e.ids.count) \(e.ids.count == 1 ? "player" : "players") at the front")
                }
            }
            ForEach(families, id: \.0) { fam, list in
                Section(fam) {
                    ForEach(list) { i in
                        Button(i.name) { s.addPlayer(i.id) }.buttonStyle(.plain)
                            .help(Stage.isOrchestral(i.id) ? "Seat a \(i.name) on the stage" : "Add a \(i.name) at the front")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    var families: [(String, [Engines.Instrument])] {
        var order: [String] = []
        var by: [String: [Engines.Instrument]] = [:]
        for i in studio.instruments where i.low != nil {
            let f = i.family ?? "Other"
            if by[f] == nil { order.append(f) }
            by[f, default: []].append(i)
        }
        return order.map { ($0, by[$0]!) }
    }

    var guide: some View {
        VStack(spacing: 0) {
            TextField("Search: an instrument, a composer, a character", text: $search)
                .textFieldStyle(.roundedBorder).padding(10)
            List {
                ForEach(OrchestrationGuide.shared.search(search)) { e in
                    DisclosureGroup {
                        Text(e.summary).font(.system(size: 12)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
                    } label: {
                        Text(e.title).foregroundStyle(Theme.text)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }
}

/// Orchestration Helper's entries, read once from its own data.
@MainActor
final class OrchestrationGuide {
    static let shared = OrchestrationGuide()
    struct Entry: Identifiable { let id: String; let title: String; let summary: String; let haystack: String }
    private var entries: [Entry]?

    func all() -> [Entry] {
        if let e = entries { return e }
        guard let eng = Studio.shared.engines, let obj = try? eng.callAny("orchestration", [String: Int]()) as? [String: Any],
              let list = obj["entries"] as? [[String: Any]] else { return [] }
        let out = list.enumerated().map { i, d -> Entry in
            let title = (d["name"] as? String) ?? (d["title"] as? String) ?? "Entry \(i + 1)"
            let summary = (d["summary"] as? String) ?? (d["text"] as? String) ?? (d["quote"] as? String) ?? ""
            let aliases = (d["aliases"] as? [String]) ?? []
            let hay = ([title, summary, (d["family"] as? String) ?? ""] + aliases).joined(separator: " ").lowercased()
            return Entry(id: (d["id"] as? String) ?? "\(i)", title: title, summary: summary, haystack: hay)
        }
        entries = out
        return out
    }

    func search(_ q: String) -> [Entry] {
        let words = q.lowercased().split(separator: " ").map(String.init)
        return words.isEmpty ? all() : all().filter { e in words.allSatisfy { e.haystack.contains($0) } }
    }

    /// Midi Catalogue's instrument ids to the guide's entries.
    static let ids: [String: String] = [
        "vln1": "violin", "vln2": "violin", "vla": "viola", "vc": "cello", "cb": "doublebass",
        "picc": "piccolo", "fl": "flute", "ob": "oboe", "eh": "englishhorn", "cl": "clarinet", "bcl": "bassclarinet",
        "bsn": "bassoon", "cbsn": "contrabassoon", "hn": "horn", "tpt": "trumpet", "tbn": "trombone", "btbn": "trombone",
        "tuba": "tuba", "tba": "tuba", "timp": "timpani", "harp": "harp", "pno": "piano", "glock": "glockenspiel",
        "xyl": "xylophone", "cel": "celesta", "mar": "marimba", "vib": "vibraphone",
    ]

    func entry(for instrumentID: String, name: String?) -> Entry? {
        let list = all()
        if let id = OrchestrationGuide.ids[instrumentID], let e = list.first(where: { $0.id == id }) { return e }
        guard let n = name?.lowercased() else { return nil }
        return list.first { $0.title.lowercased() == n }
    }
}
