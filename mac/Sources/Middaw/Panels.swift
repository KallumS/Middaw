import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVFoundation
import MiddawCore
import MiddawEngines
import MiddawAudio

// ----------------------------------------------------- about a player --
/// Where the player is heard from: the seat's distance and side in the hall.
@MainActor func placeText(_ t: Track, in p: Project) -> String {
    guard let seat = Stage.seat(t.seat) else { return "At the front: no hall, in the middle" }
    let hall = Hall.named(p.hall)
    let sound = Stage.sound(seat, in: hall)
    return String(format: "%@: %.1f m away, %@, %.1f dB", seat.name, sound.distance, panText(sound.pan).lowercased(), 20 * log10(sound.direct))
}

/// What the instrument can play, from Midi Catalogue.
func rangeText(_ i: Engines.Instrument) -> String? {
    guard let lo = i.low, let hi = i.high, !i.isDrums else { return nil }
    var s = "\(Theory.noteName(lo)) to \(Theory.noteName(hi))"
    if let sw = i.sweet, sw.count == 2 { s += ", best \(Theory.noteName(sw[0]))–\(Theory.noteName(sw[1]))" }
    if let p = i.poly { s += p == 1 ? ", one note at a time" : ", \(p) notes at once" }
    return s
}

/// The player's level, mute and solo, at the end of their chain in Devices.
struct MixCard: View {
    @EnvironmentObject var s: Session
    let track: Track
    @State private var volume = 0.8
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Level").heading()
            HStack(spacing: 8) {
                Slider(value: $volume, in: 0...1) { editing in if !editing { s.updateTrack(track.id, "Change Level") { $0.volume = volume } } }
                Text(dbText(volume)).frame(width: 56, alignment: .trailing).foregroundStyle(Theme.text).monospacedDigit()
            }
            HStack(spacing: 4) {
                Button("Mute") { s.updateTrack(track.id, track.mute ? "Unmute" : "Mute") { $0.mute.toggle() } }.house(on: track.mute, compact: true)
                Button("Solo") { s.updateTrack(track.id, track.solo ? "Unsolo" : "Solo") { $0.solo.toggle() } }.house(on: track.solo, compact: true)
            }
            Text(placeText(track, in: s.project)).foregroundStyle(Theme.textDim).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(width: 220, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised))
        .onAppear { volume = track.volume }
        .onChange(of: track.volume) { _, v in volume = v }
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

// ----------------------------------------------------------- the guide --
/// Orchestration Helper's guide, in a window of its own (Window > Orchestration
/// Guide, or Help > About the instrument): searchable by instrument, composer
/// or character.
@MainActor
final class GuideSearch: ObservableObject {
    static let shared = GuideSearch()
    @Published var text = ""
}

struct GuideWindow: View {
    @EnvironmentObject var studio: Studio
    @ObservedObject var search = GuideSearch.shared
    var body: some View {
        VStack(spacing: 0) {
            TextField("Search: an instrument, a composer, a character", text: $search.text)
                .textFieldStyle(.roundedBorder).padding(10)
            List {
                ForEach(studio.engines == nil ? [] : OrchestrationGuide.shared.search(search.text)) { e in
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
        .background(Theme.ground)
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
