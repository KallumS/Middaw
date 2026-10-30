import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVFoundation
import MiddawCore
import MiddawEngines
import MiddawAudio

// ------------------------------------------------------------- inspector --
/// The chosen track: what it is, what plays it, how loud - and what
/// Orchestration Helper says about it. Generate shares the same column.
struct InspectorView: View {
    @EnvironmentObject var s: Session
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $s.inspector) {
                Text("Track").tag(InspectorTab.track)
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
    @State private var pan = 0.0
    @State private var send = 0.0

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
                    Menu("Transform") { ForEach(Session.Shape.allCases, id: \.self) { sh in Button(sh.rawValue) { s.transform(sh) } } }
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
            Row(label: "Pan") {
                Slider(value: $pan, in: -1...1) { editing in if !editing { s.updateTrack(t.id, "Change Pan") { $0.pan = pan } } }
                Text(panText(pan)).frame(width: 52, alignment: .trailing).foregroundStyle(Theme.text)
            }
            Row(label: "Reverb") {
                Slider(value: $send, in: 0...1) { editing in if !editing { s.updateTrack(t.id, "Change Reverb Send") { $0.send = send } } }
                Text("\(Int((send * 100).rounded()))%").frame(width: 52, alignment: .trailing).foregroundStyle(Theme.text).monospacedDigit()
            }

            if let entry = OrchestrationGuide.shared.entry(for: t.instrument, name: studio.instrument(t.instrument)?.name) {
                Divider().overlay(Theme.rule)
                Text("About the \(entry.title)").heading()
                Text(entry.summary).foregroundStyle(Theme.text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text("Add a track, or describe some music in Generate.").foregroundStyle(Theme.textDim)
        }
    }

    func load(_ t: Track) { name = t.name; volume = t.volume; pan = t.pan; send = t.send }

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
    abs(p) < 0.01 ? "Centre" : (p < 0 ? "L \(Int((-p * 100).rounded()))" : "R \(Int((p * 100).rounded()))")
}

/// What plays the track: Middaw Synth's presets, the kit, or the Instant
/// Instrument - a sound dropped on the track, played across the keyboard.
struct SoundPanel: View {
    @EnvironmentObject var s: Session
    let track: Track
    @State private var dropping = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Row(label: "Played by") {
                Picker("", selection: Binding(get: { track.sound.device }, set: { setDevice($0) })) {
                    Text("Middaw Synth").tag("synth")
                    Text("Drum Kit").tag("kit")
                    Text("Instant Instrument").tag("sampler")
                }.labelsHidden()
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
                        providers.first?.loadObject(ofClass: URL.self) { url, _ in
                            if let u = url { DispatchQueue.main.async { load(u) } }
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
        s.updateTrack(track.id, "Change Sound") { t in
            t.sound = Device(device: d, preset: d == "synth" ? (presetFor[t.instrument] ?? "keys") : nil)
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

// ----------------------------------------------------------- the mixer --
struct MixerView: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                ForEach(s.project.tracks) { t in Strip(track: t) }
            }
            .padding(8)
        }
        .background(Theme.ground)
    }
}

struct Strip: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    let track: Track
    @State private var volume = 0.8
    @State private var pan = 0.0
    @State private var send = 0.0

    var body: some View {
        VStack(spacing: 8) {
            Text(track.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
            VStack(spacing: 2) {
                Text("Reverb").font(.system(size: 11)).foregroundStyle(Theme.label)
                Slider(value: $send, in: 0...1) { e in if !e { s.updateTrack(track.id, "Change Reverb Send") { $0.send = send } } }
            }
            VStack(spacing: 2) {
                Text(panText(pan)).font(.system(size: 11)).foregroundStyle(Theme.label)
                Slider(value: $pan, in: -1...1) { e in if !e { s.updateTrack(track.id, "Change Pan") { $0.pan = pan } } }
            }
            HStack(alignment: .bottom, spacing: 6) {
                Slider(value: $volume, in: 0...1) { e in if !e { s.updateTrack(track.id, "Change Level") { $0.volume = volume } } }
                    .rotationEffect(.degrees(-90))
                    .frame(width: 150, height: 28)
                    .frame(width: 28, height: 150)
                    .accessibilityLabel("\(track.name) level")
                Meter(trackID: track.id).frame(width: 8, height: 150)
            }
            Text(dbText(volume)).font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.text)
            HStack(spacing: 4) {
                Button("M") { s.updateTrack(track.id, "Mute") { $0.mute.toggle() } }.house(on: track.mute, compact: true)
                Button("S") { s.updateTrack(track.id, "Solo") { $0.solo.toggle() } }.house(on: track.solo, compact: true)
            }
        }
        .padding(8)
        .frame(width: 92)
        .background(RoundedRectangle(cornerRadius: 6).fill(track.id == s.selection.trackID ? Theme.raised : Theme.sunken))
        .onTapGesture { s.select(track: track.id) }
        .onAppear { volume = track.volume; pan = track.pan; send = track.send }
        .onChange(of: track) { _, t in volume = t.volume; pan = t.pan; send = t.send }
    }
}

struct Meter: View {
    @EnvironmentObject var studio: Studio
    let trackID: String
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            Canvas { g, size in
                g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.sunken))
                let v = studio.audio.renderer.peak(of: trackID)
                let db = v > 0 ? 20 * log10(Double(v)) : -60
                let f = max(0, min(1, (db + 60) / 66))
                g.fill(Path(CGRect(x: 0, y: size.height * (1 - f), width: size.width, height: size.height * f)),
                       with: .color(db > -0.5 ? Theme.warn : Theme.control))
            }
        }
        .accessibilityHidden(true)
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
                    Button(e.name) { s.addEnsemble(e.name, e.ids) }.buttonStyle(.plain)
                        .help("Add \(e.ids.count) \(e.ids.count == 1 ? "track" : "tracks")")
                }
            }
            ForEach(families, id: \.0) { fam, list in
                Section(fam) {
                    ForEach(list) { i in
                        Button(i.name) { s.addTrack(i.id) }.buttonStyle(.plain).help("Add a track for the \(i.name)")
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
