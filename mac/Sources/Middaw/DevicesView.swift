import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import MiddawCore
import MiddawEngines
import MiddawAudio

/// The chosen track's devices, left to right as the sound goes (Bitwig's
/// device chain): MIDI effects, the instrument, audio effects. Each device's
/// controls are its own sliders.
struct DevicesView: View {
    @EnvironmentObject var s: Session
    var body: some View {
        if let t = s.track {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(t.midiFx) { d in
                        DeviceCard(device: d, trackID: t.id)
                        Flow()
                    }
                    if DeviceCatalog.info(t.sound.device) != nil {
                        DeviceCard(device: t.sound, trackID: t.id, isSound: true)
                    } else {
                        BuiltInCard(track: t)
                    }
                    ForEach(t.audioFx) { d in
                        Flow()
                        DeviceCard(device: d, trackID: t.id)
                    }
                    AddDeviceMenu(track: t)
                }
                .padding(10)
            }
            .background(Theme.ground)
        } else {
            Text("Choose a track.").foregroundStyle(Theme.textDim).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.ground)
        }
    }
}

/// The arrow between two devices.
struct Flow: View {
    var body: some View {
        Image(systemName: "chevron.right").foregroundStyle(Theme.edge).frame(width: 14).padding(.top, 14).accessibilityHidden(true)
    }
}

struct BuiltInCard: View {
    let track: Track
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(builtInName(track.sound.device)).heading()
            SoundPanel(track: track)
        }
        .padding(10)
        .frame(width: 300, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised))
    }
}

func builtInName(_ id: String) -> String {
    switch id {
    case "kit": return "Drum Kit"
    case "sampler": return "Instant Instrument"
    default: return "Middaw Synth"
    }
}

struct AddDeviceMenu: View {
    @EnvironmentObject var s: Session
    let track: Track
    var body: some View {
        Menu {
            Section("MIDI Effects") {
                ForEach(DeviceCatalog.of(.midi), id: \.id) { d in Button(d.name) { s.addDevice(d.id, to: track.id) } }
            }
            Section("Audio Effects") {
                ForEach(DeviceCatalog.of(.audio), id: \.id) { d in Button(d.name) { s.addDevice(d.id, to: track.id) } }
            }
        } label: { Label("Add", systemImage: "plus") }
        .menuStyle(.button)
        .fixedSize()
        .padding(.top, 6)
        .help("Add a MIDI effect before the instrument, or an audio effect after it")
    }
}

/// One of the family's devices: its name, what it can do, its controls.
struct DeviceCard: View {
    @EnvironmentObject var s: Session
    let device: Device
    /// nil on the return.
    let trackID: String?
    var isSound = false

    var body: some View {
        if let info = DeviceCatalog.info(device.device) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(info.name).heading().lineLimit(1)
                    Spacer(minLength: 4)
                    if !isSound && trackID != nil {
                        Menu {
                            Button("Move Earlier") { s.moveDevice(device.id, by: -1) }
                            Button("Move Later") { s.moveDevice(device.id, by: 1) }
                            Divider()
                            Button("Remove") { s.removeDevice(device.id) }
                        } label: { Image(systemName: "ellipsis") }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                        .help("Move or remove \(info.name)")
                    }
                }
                DeviceActions(device: device, info: info, trackID: trackID)
                ForEach(info.main, id: \.self) { n in SliderControl(device: device, n: n) }
                ForEach(Array(info.groups.enumerated()), id: \.offset) { _, g in
                    DisclosureGroup(g.name) {
                        VStack(alignment: .leading, spacing: 8) { ForEach(g.sliders, id: \.self) { n in SliderControl(device: device, n: n) } }
                            .padding(.top, 6)
                    }
                    .foregroundStyle(Theme.text)
                }
                if !info.more.isEmpty {
                    DisclosureGroup("More") {
                        VStack(alignment: .leading, spacing: 8) { ForEach(info.more, id: \.self) { n in SliderControl(device: device, n: n) } }
                            .padding(.top, 6)
                    }
                    .foregroundStyle(Theme.text)
                }
            }
            .padding(10)
            .frame(width: 300, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised))
        }
    }
}

/// A slider as the device declares it: a menu for a list of choices, a
/// switch for off and on, else a slider with its value and unit.
struct SliderControl: View {
    @EnvironmentObject var s: Session
    let device: Device
    let n: Int
    @State private var position = 0.0
    @State private var editing = false

    var body: some View {
        if let info = DeviceCatalog.slider(device.device, n) {
            let value = device.sliders[n] ?? info.def
            let parts = SliderControl.split(info.name)
            let label = parts.0, unit = parts.1
            if !info.choices.isEmpty {
                HStack(spacing: 8) {
                    Text(label).foregroundStyle(Theme.label).lineLimit(1).frame(width: 110, alignment: .leading)
                    Picker(label, selection: Binding(get: { max(0, min(info.choices.count - 1, Int((value - info.min).rounded()))) },
                                                     set: { k in s.setDeviceSlider(device.id, n, info.min + Double(k), name: label) })) {
                        ForEach(info.choices.indices, id: \.self) { k in Text(info.choices[k]).tag(k) }
                    }
                    .labelsHidden()
                }
            } else if info.min == 0 && info.max == 1 && info.step == 1 {
                Toggle(label, isOn: Binding(get: { value >= 0.5 }, set: { on in s.setDeviceSlider(device.id, n, on ? 1 : 0, name: label) }))
                    .foregroundStyle(Theme.label)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(label).foregroundStyle(Theme.label).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(SliderControl.text(editing ? SliderControl.value(position, info) : value, info, unit))
                            .foregroundStyle(Theme.text).monospacedDigit()
                    }
                    Slider(value: $position, in: 0...1) { e in
                        editing = e
                        if !e { s.setDeviceSlider(device.id, n, SliderControl.value(position, info), name: label) }
                    }
                    .onChange(of: position) { _, p in if editing { s.liveDeviceSlider(device.id, n, SliderControl.value(p, info)) } }
                    .accessibilityLabel(label)
                    .accessibilityValue(SliderControl.text(value, info, unit))
                }
                .onAppear { position = SliderControl.position(value, info) }
                .onChange(of: value) { _, v in if !editing { position = SliderControl.position(v, info) } }
            }
        }
    }

    /// "Mix (%)" is Mix, in %.
    static func split(_ name: String) -> (String, String) {
        guard name.hasSuffix(")"), let open = name.lastIndex(of: "(") else { return (name, "") }
        let label = name[..<open].trimmingCharacters(in: .whitespaces)
        let unit = String(name[name.index(after: open)..<name.index(before: name.endIndex)])
        return (label.isEmpty ? name : label, unit)
    }

    /// The slider's travel as its header shapes it: log sliders spread their
    /// low end, squared ones their top.
    static func value(_ p: Double, _ s: SliderInfo) -> Double {
        let p = max(0, min(1, p))
        var v: Double
        if s.shape == 1 && s.min > 0 && s.max > s.min { v = s.min * pow(s.max / s.min, p) }
        else if s.shape == 2 { v = s.min + (s.max - s.min) * p * p }
        else { v = s.min + (s.max - s.min) * p }
        if s.step > 0 { v = s.min + ((v - s.min) / s.step).rounded() * s.step }
        return max(min(s.min, s.max), min(max(s.min, s.max), v))
    }
    static func position(_ v: Double, _ s: SliderInfo) -> Double {
        guard s.max != s.min else { return 0 }
        if s.shape == 1 && s.min > 0 && s.max > s.min && v > 0 { return max(0, min(1, log(v / s.min) / log(s.max / s.min))) }
        let f = max(0, min(1, (v - s.min) / (s.max - s.min)))
        return s.shape == 2 ? sqrt(f) : f
    }
    static func text(_ v: Double, _ s: SliderInfo, _ unit: String) -> String {
        let whole = s.step >= 1 || (s.step == 0 && abs(s.max - s.min) >= 100)
        let num = whole ? String(format: "%.0f", v) : (s.step >= 0.1 || s.step == 0 ? String(format: "%.1f", v) : String(format: "%.2f", v))
        if unit.isEmpty { return num }
        return unit == "%" ? num + "%" : num + " " + unit
    }
}

/// What a device can do besides its sliders: the buttons it has in REAPER.
struct DeviceActions: View {
    @EnvironmentObject var s: Session
    let device: Device
    let info: DeviceInfo
    let trackID: String?

    var body: some View {
        switch info.id {
        case "creator":
            Row(label: "Instrument") {
                Picker("Instrument", selection: Binding(get: { device.presetIndex ?? -1 }, set: { s.chooseCreatorPreset(device.id, $0) })) {
                    Text("Your Own").tag(-1)
                    ForEach(Array(Session.creatorPresets.enumerated()), id: \.offset) { k, p in Text(p.name).tag(k) }
                }
                .labelsHidden()
            }
            Button("Surprise Me") { s.surpriseCreator(device.id) }.house().help("A random instrument from its parts")
        case "shuffler":
            HStack(spacing: 6) {
                SoundDrop(title: device.samples?.first.flatMap { $0?.name } ?? "Sample A…") { s.loadDeviceSound(device.id, slot: 0, from: $0) }
                SoundDrop(title: (device.samples?.count ?? 0) > 1 ? (device.samples?[1]?.name ?? "Sample B…") : "Sample B…") { s.loadDeviceSound(device.id, slot: 1, from: $0) }
            }
        case "evolver":
            HStack(spacing: 6) {
                Button("Insert the Take") { s.insertEvolverTake(device.id) }.house().help("Put what Midi Evolver last played into this track at the caret")
                Button("Record") { s.pressDevice(device.id, variable: "rec_req") }.house().help("Keep holds together as one take")
                Button("Panic") { s.pressDevice(device.id, variable: "panic_req") }.house().help("Stop every note it started")
            }
        case "mpc":
            HStack(spacing: 6) {
                Button("Load the Clip") { s.loadClipIntoMPC(device.id) }.house().disabled(s.clip == nil).help("Chop the chosen clip onto the pads")
                Button("Transfer to Pads") { s.pressDevice(device.id, variable: "ui_req_xfer"); s.say("Chops transferred to bank A.") }.house()
            }
            if let t = trackID {
                VStack(spacing: 4) {
                    ForEach((0..<4).reversed(), id: \.self) { row in
                        HStack(spacing: 4) { ForEach(0..<4, id: \.self) { col in Pad(number: row * 4 + col, trackID: t) } }
                    }
                }
            }
        case "autocc":
            Button("Draw into the Clip") { s.drawDynamics() }.house().disabled(s.clip == nil)
                .help("Write the curves AutoCC plays into the chosen clip’s controller lanes")
        default:
            EmptyView()
        }
    }
}

/// One of the MPC's sixteen pads: held, it plays its note.
struct Pad: View {
    @EnvironmentObject var s: Session
    let number: Int
    let trackID: String
    @State private var down = false
    var body: some View {
        Text("\(number + 1)")
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
            .frame(width: 58, height: 40)
            .background(RoundedRectangle(cornerRadius: 6).fill(down ? Theme.accent : Theme.control))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !down { down = true; s.playPad(trackID, 36 + number, on: true) } }
                .onEnded { _ in down = false; s.playPad(trackID, 36 + number, on: false) })
            .accessibilityLabel("Pad \(number + 1)")
            .accessibilityAddTraits(.isButton)
    }
}

/// A place to drop a sound, or click to choose one.
struct SoundDrop: View {
    let title: String
    let take: (URL) -> Void
    @State private var over = false
    var body: some View {
        Text(title)
            .font(.system(size: 12)).foregroundStyle(Theme.text).lineLimit(1).truncationMode(.middle)
            .frame(maxWidth: .infinity, minHeight: 40).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 6).strokeBorder(over ? Theme.accent : Theme.edge, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .contentShape(Rectangle())
            .onTapGesture {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.audio]
                if panel.runModal() == .OK, let u = panel.url { take(u) }
            }
            .onDrop(of: [.fileURL], isTargeted: $over) { providers in
                _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                    if let u = url { Task { @MainActor in take(u) } }
                }
                return true
            }
            .help("Drop a sound here, or click to choose one")
    }
}

/// Up to sixteen seconds of a sound file, as the song keeps it.
func readSound(_ url: URL) throws -> Sample {
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    let frames = AVAudioFrameCount(min(Double(file.length), format.sampleRate * 16))
    guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { throw CocoaError(.fileReadCorruptFile) }
    try file.read(into: buf, frameCount: frames)
    guard let data = buf.floatChannelData else { throw CocoaError(.fileReadCorruptFile) }
    let n = Int(buf.frameLength)
    let left = Array(UnsafeBufferPointer(start: data[0], count: n))
    let right = format.channelCount > 1 ? Array(UnsafeBufferPointer(start: data[1], count: n)) : nil
    return SampleCodec.encode(name: url.lastPathComponent, left: left, right: right, rate: format.sampleRate, root: 60)
}

// ------------------------------------------------------- the actions --
extension Project {
    /// The device with this id, wherever it is: a track's chain or the return.
    mutating func withDevice(_ id: String, _ change: (inout Device) -> Void) -> Bool {
        for t in tracks.indices {
            if tracks[t].sound.id == id { change(&tracks[t].sound); return true }
            if let k = tracks[t].midiFx.firstIndex(where: { $0.id == id }) { change(&tracks[t].midiFx[k]); return true }
            if let k = tracks[t].audioFx.firstIndex(where: { $0.id == id }) { change(&tracks[t].audioFx[k]); return true }
        }
        for r in returns.indices {
            if let k = returns[r].audioFx.firstIndex(where: { $0.id == id }) { change(&returns[r].audioFx[k]); return true }
        }
        return false
    }
    func device(_ id: String) -> Device? {
        var copy = self
        var found: Device?
        _ = copy.withDevice(id) { found = $0 }
        return found
    }
    /// The track a device is on.
    func trackID(ofDevice id: String) -> String? {
        tracks.first { t in t.sound.id == id || t.midiFx.contains { $0.id == id } || t.audioFx.contains { $0.id == id } }?.id
    }
}

extension Session {
    static let creatorPresets: [(name: String, values: [Double])] = {
        let url = Engines.defaultRoot().appendingPathComponent("family/devices/Instrument-Creator.jsfx")
        guard let src = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return DeviceCatalog.creatorPresets(source: src)
    }()

    /// A new device of this kind, with Instrument Creator ready to play.
    static func makeDevice(_ id: String) -> Device {
        var d = Device(device: id)
        if id == "creator", creatorPresets.count > 1 {
            d.presetIndex = 1; d.presetName = creatorPresets[1].name
            for (j, v) in creatorPresets[1].values.enumerated() { d.sliders[j + 1] = v }
        }
        return d
    }

    func addDevice(_ id: String, to trackID: String) {
        guard let info = DeviceCatalog.info(id) else { return }
        updateTrack(trackID, "Add \(info.name)") { t in
            switch info.role {
            case .midi: t.midiFx.append(Session.makeDevice(id))
            case .audio: t.audioFx.append(Session.makeDevice(id))
            case .instrument: t.sound = Session.makeDevice(id)
            }
        }
        editor = .devices
    }

    func removeDevice(_ id: String) {
        let name = project.device(id).flatMap { DeviceCatalog.info($0.device)?.name } ?? "Device"
        commit("Remove \(name)") { p in
            for t in p.tracks.indices {
                p.tracks[t].midiFx.removeAll { $0.id == id }
                p.tracks[t].audioFx.removeAll { $0.id == id }
            }
            for r in p.returns.indices { p.returns[r].audioFx.removeAll { $0.id == id } }
        }
    }

    func moveDevice(_ id: String, by step: Int) {
        commit("Move Device") { p in
            for t in p.tracks.indices {
                for kp in [\Track.midiFx, \Track.audioFx] {
                    if let k = p.tracks[t][keyPath: kp].firstIndex(where: { $0.id == id }) {
                        let to = max(0, min(p.tracks[t][keyPath: kp].count - 1, k + step))
                        if to != k { let d = p.tracks[t][keyPath: kp].remove(at: k); p.tracks[t][keyPath: kp].insert(d, at: to) }
                    }
                }
            }
        }
    }

    /// While a slider is dragged: heard at once, not yet a step.
    func liveDeviceSlider(_ id: String, _ n: Int, _ v: Double) {
        guard Studio.shared.active === self else { return }
        Studio.shared.audio.renderer.device(id)?.setSlider(n, v)
    }
    func setDeviceSlider(_ id: String, _ n: Int, _ v: Double, name: String) {
        commit("Change \(name)") { p in _ = p.withDevice(id) { d in d.sliders[n] = v; if d.device == "creator" && n <= 12 { d.presetIndex = -1; d.presetName = nil } } }
    }

    /// A button a device polls for, pressed.
    func pressDevice(_ id: String, variable: String) {
        Studio.shared.becameActive(self)
        guard let d = Studio.shared.audio.renderer.device(id) else { return }
        d.setVariable(variable, 1)
    }

    func chooseCreatorPreset(_ id: String, _ k: Int) {
        let pr = k >= 0 && k < Session.creatorPresets.count ? Session.creatorPresets[k] : nil
        commit("Choose an Instrument") { p in
            _ = p.withDevice(id) { d in
                d.presetIndex = k; d.presetName = pr?.name
                if let pr { for (j, v) in pr.values.enumerated() { d.sliders[j + 1] = v } }
            }
        }
    }

    func surpriseCreator(_ id: String) {
        guard let info = DeviceCatalog.info("creator"), let parts = info.groups.first?.sliders else { return }
        var vals: [Int: Double] = [:]
        for n in parts {
            guard let sl = DeviceCatalog.slider("creator", n) else { continue }
            let count = sl.choices.isEmpty ? Int(sl.max - sl.min) + 1 : sl.choices.count
            vals[n] = sl.min + Double(Int.random(in: 0..<max(1, count)))
        }
        commit("Surprise Me") { p in _ = p.withDevice(id) { d in d.presetIndex = -1; d.presetName = nil; for (n, v) in vals { d.sliders[n] = v } } }
    }

    func loadDeviceSound(_ id: String, slot: Int, from url: URL) {
        do {
            let sample = try readSound(url)
            commit("Load a Sound") { p in
                _ = p.withDevice(id) { d in
                    var list = d.samples ?? []
                    while list.count <= slot { list.append(nil) }
                    list[slot] = sample
                    d.samples = list
                }
            }
            say("Loaded \(url.lastPathComponent).")
        } catch {
            say("That sound could not be read: \(error.localizedDescription)", warning: true)
        }
    }

    func playPad(_ trackID: String, _ note: Int, on: Bool) {
        Studio.shared.becameActive(self)
        Studio.shared.audio.renderer.live(trackID, on ? 0x90 : 0x80, UInt8(note), on ? 110 : 0)
    }

    /// What Midi Evolver last played, as a clip at the caret.
    func insertEvolverTake(_ id: String) {
        guard let tid = project.trackID(ofDevice: id), let d = Studio.shared.audio.renderer.device(id) else {
            say("Play the song once first: Midi Evolver keeps what it plays as the take."); return
        }
        let n = Int(d.variable("rec_n")), length = d.variable("take_len"), base = Int(d.variable("rec_base"))
        guard n > 0 else { say("Hold a chord first: Midi Evolver keeps what it plays as the take."); return }
        let mem = d.memory(base, n * 4)
        var on: [Int: Note] = [:], notes: [Note] = []
        for i in 0..<n {
            let at = mem[i * 4], st = Int(mem[i * 4 + 1]) & 0xF0, pitch = Int(mem[i * 4 + 2]), vel = Int(mem[i * 4 + 3])
            if st == 0x90 && vel > 0 { on[pitch] = Note(start: at, len: 0, pitch: pitch, vel: vel) }
            else if st == 0x80 || st == 0x90, var x = on[pitch] {
                x.len = max(1.0 / 32, at - x.start); notes.append(x); on[pitch] = nil
            }
        }
        for (_, x) in on { var y = x; y.len = max(1.0 / 32, length - x.start); notes.append(y) }
        notes.sort { $0.start < $1.start }
        let bpb = project.beatsPerBar
        let at0 = (caret / bpb).rounded(.down) * bpb
        let len = (max(length, 1) / bpb).rounded(.up) * bpb
        var clipID: String?
        commit("Insert the Take") { p in
            clipID = p.place(notes, on: tid, at: at0, length: len, name: "Midi Evolver take", source: ClipSource(generator: "Midi Evolver"))
        }
        if let c = clipID { select(clip: c, on: tid) }
        say("Inserted the take: \(notes.count) notes. Take Midi Evolver off the track to hear just the notes.", undoable: true)
    }

    /// The chosen clip into MIDI Production Center, as its REAPER loader writes it.
    func loadClipIntoMPC(_ id: String) {
        guard let c = clip else { say("Choose a clip first."); return }
        Studio.shared.becameActive(self)
        guard let d = Studio.shared.audio.renderer.device(id) else { return }
        let inst = d.slider(48)
        guard inst != 0 else { say("MIDI Production Center is still starting. Try again in a moment."); return }
        var w: [(Int, Double)] = []
        let notes = Array(c.notes.prefix(8192))
        for (i, n) in notes.enumerated() {
            let b = 100 + i * 5
            w += [(b, n.start), (b + 1, n.len), (b + 2, Double(n.pitch)), (b + 3, Double(n.vel)), (b + 4, 0)]
        }
        let name = String(String((c.name.isEmpty ? "Clip" : c.name).unicodeScalars.filter { $0.value >= 0x20 && $0.value < 0x7F }).prefix(64))
        for (k, ch) in name.unicodeScalars.enumerated() { w.append((61000 + k, Double(ch.value))) }
        w += [(1, inst), (2, Double(notes.count)), (3, c.length), (4, project.tempo), (5, Double(project.meter.first ?? 4)),
              (6, Double(project.meter.count > 1 ? project.meter[1] : 4)), (7, 0), (8, Double(name.unicodeScalars.count))]
        w.append((0, Double(Int(Date().timeIntervalSince1970 * 1000) % 1_000_000 + 1)))
        d.writeShared(w)
        say("Loaded “\(name)” into MIDI Production Center and chopped it onto the pads.")
    }
}
