import SwiftUI
import AppKit
import MiddawCore
import MiddawEngines
import MiddawAudio

/// The menus at the top: everything the side panels used to hold, so the
/// window is the stage and the editor, the whole width.
///
/// - Stage: add players and ensembles, the front, the hall.
/// - Player: the chosen player's name, instrument, seat, sound, mute and solo.
/// - Clip: what the generators and transforms do to the chosen clip.
struct MiddawCommands: Commands {
    @FocusedObject var s: Session?
    @ObservedObject var studio: Studio
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Export MIDI File…") { s?.exportMIDI() }.keyboardShortcut("e", modifiers: [.command, .shift]).disabled(s == nil)
            Button("Export Audio…") { s?.exportAudio() }.disabled(s == nil)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Select All Notes") { s?.selectAllNotes() }.keyboardShortcut("a", modifiers: [.command, .option]).disabled(s?.clip == nil)
        }
        CommandGroup(after: .sidebar) {
            Button("MIDI") { s?.editor = .roll }.keyboardShortcut("p", modifiers: [.command, .option])
            Button("Notation") { s?.editor = .score }.keyboardShortcut("s", modifiers: [.command, .option])
            Button("Drums") { s?.editor = .drums }
            Button("Step Sequencer") { s?.editor = .steps }
            Button("Devices") { s?.editor = .devices }
            Divider()
            Toggle("Generate", isOn: Binding(get: { s?.generating ?? false }, set: { s?.generating = $0 })).disabled(s == nil)
        }
        CommandMenu("Stage") { stage }
        CommandMenu("Player") { player }
        CommandMenu("Clip") { clip }
        CommandMenu("Transport") {
            Button(s?.playing == true ? "Stop" : "Play") { s?.playStop() }
            Button("Play from the Start") { s?.playStop(fromStart: true) }
            Button("Record") { s?.toggleRecord() }
            Button("Loop") { s?.toggleLoop() }
            Button("Metronome") { s?.toggleMetronome() }
        }
        CommandGroup(after: .help) {
            if let t = s?.track, let i = studio.instrument(t.instrument), OrchestrationGuide.shared.entry(for: i.id, name: i.name) != nil {
                Button("About the \(i.name)") { GuideSearch.shared.text = i.name; openWindow(id: "guide") }
            }
            Button("Orchestration Guide") { openWindow(id: "guide") }
        }
    }

    // ------------------------------------------------------------- stage --
    @ViewBuilder var stage: some View {
        Menu("Add an Ensemble") {
            ForEach(ensembles, id: \.name) { e in Button(e.name) { s?.addEnsemble(e.name, e.ids, stage: e.stage) } }
        }
        .disabled(s == nil)
        Menu("Add a Player") {
            ForEach(studio.families, id: \.name) { fam in
                Menu(fam.name) {
                    ForEach(fam.instruments) { i in Button(i.name) { s?.addPlayer(i.id) } }
                }
            }
        }
        .disabled(s == nil)
        Divider()
        Button("New Player at the Front") { s?.addTrack("synth") }.keyboardShortcut("n", modifiers: [.command, .option]).disabled(s == nil)
        Button("New Drum Machine at the Front") { s?.addToFront(.kit, drums: true) }.disabled(s == nil)
        Divider()
        Menu("Hall") {
            ForEach(Hall.all) { h in
                Toggle(h.name, isOn: Binding(get: { s?.project.hall == h.id }, set: { _ in s?.setHall(h.id) }))
            }
        }
        .disabled(s == nil)
        Button("Look Again for Audio Units") { studio.rescanPlugins() }
    }

    // ------------------------------------------------------------ player --
    @ViewBuilder var player: some View {
        if let s, let t = s.track {
            Text(placeText(t, in: s.project))
            if let i = studio.instrument(t.instrument), let range = rangeText(i) { Text(range) }
            Divider()
            Button("Rename…") { s.renaming = true }
            Menu("Instrument") {
                ForEach(studio.families, id: \.name) { fam in
                    Menu(fam.name) {
                        ForEach(fam.instruments) { i in
                            Toggle(i.name, isOn: Binding(get: { t.instrument == i.id }, set: { _ in s.setInstrument(t.id, i.id) }))
                        }
                    }
                }
            }
            Menu("Seat") {
                Toggle("At the Front", isOn: Binding(get: { t.seat == nil }, set: { _ in s.place(t.id, seat: nil) }))
                ForEach(StageSection.allCases, id: \.self) { sec in
                    let open = Stage.seats.filter { $0.section == sec && ($0.id == t.seat || !s.project.takenSeats.contains($0.id)) }
                    if !open.isEmpty {
                        Menu(sec.name) {
                            ForEach(open) { seat in
                                Toggle(seat.name, isOn: Binding(get: { t.seat == seat.id }, set: { _ in s.place(t.id, seat: seat.id) }))
                            }
                        }
                    }
                }
            }
            sound(t, s)
            Divider()
            Toggle("Mute", isOn: Binding(get: { t.mute }, set: { _ in s.updateTrack(t.id, t.mute ? "Unmute" : "Mute") { $0.mute.toggle() } }))
            Toggle("Solo", isOn: Binding(get: { t.solo }, set: { _ in s.updateTrack(t.id, t.solo ? "Unsolo" : "Solo") { $0.solo.toggle() } }))
            Divider()
            Button("Duplicate the Player") { s.duplicateTrack(t.id) }
            Button("Remove the Player") { s.deleteTrack(t.id) }
        } else {
            Text("Choose a player on the stage")
        }
    }

    /// What plays the player: Middaw's own sounds, the family's instruments,
    /// and every Audio Unit on this Mac by maker.
    @ViewBuilder func sound(_ t: Track, _ s: Session) -> some View {
        Menu("Sound") {
            Menu("Middaw Synth") {
                ForEach(SynthPreset.all, id: \.id) { p in
                    Toggle(p.name, isOn: Binding(get: { t.sound.device == "synth" && t.sound.preset == p.id }, set: { _ in s.setSound(t.id, .synth(p.id)) }))
                }
            }
            Toggle("Drum Kit", isOn: Binding(get: { t.sound.device == "kit" }, set: { _ in s.setSound(t.id, .kit) }))
            Toggle("Instant Instrument", isOn: Binding(get: { t.sound.device == "sampler" }, set: { _ in s.setSound(t.id, .sampler) }))
            ForEach(DeviceCatalog.of(.instrument), id: \.id) { d in
                Toggle(d.name, isOn: Binding(get: { t.sound.device == d.id }, set: { _ in s.setSound(t.id, .jsfx(d.id)) }))
            }
            Divider()
            Menu("Audio Units") {
                ForEach(makers, id: \.self) { maker in
                    Menu(maker) {
                        ForEach(studio.plugins.filter { $0.maker == maker }, id: \.self) { r in
                            Toggle(r.name, isOn: Binding(get: { t.sound.device == "au" && t.sound.plugin == r }, set: { _ in s.setSound(t.id, .plugin(r)) }))
                        }
                    }
                }
                if studio.plugins.isEmpty { Text("None installed") }
            }
            if t.sound.device == "au" {
                Divider()
                Button("Show the Plug-in Window") { PluginWindows.shared.show(t.sound.id, title: "\(t.name) – \(t.sound.plugin?.name ?? "")") }
            }
        }
    }

    var makers: [String] {
        var seen: [String] = []
        for r in studio.plugins where !seen.contains(r.maker) { seen.append(r.maker) }
        return seen
    }

    // -------------------------------------------------------------- clip --
    @ViewBuilder var clip: some View {
        let has = s?.clip != nil
        Button("Vary…") { s?.generating = true; GenerateModel.request = "midi-variator" }.disabled(!has)
        Button("Suggest…") { s?.generating = true; GenerateModel.request = "midi-suggester" }.disabled(!has)
        Menu("Transform") {
            ForEach(Session.Shape.allCases, id: \.self) { shape in Button(shape.rawValue) { s?.transform(shape) } }
        }
        .disabled(!has)
        Button("Draw Dynamics with AutoCC") { s?.drawDynamics() }.disabled(!has)
        Divider()
        Button("Quantize") { s?.quantize() }.disabled(!has)
        Button("Duplicate") { s?.duplicate() }.keyboardShortcut("d").disabled(!has)
        Button("Split at the Caret") { s?.split() }.keyboardShortcut("e").disabled(!has)
        Divider()
        Button("Export as MIDI…") { s?.exportMIDI(clipOnly: true) }.disabled(!has)
    }
}

/// Player > Rename…
struct RenameSheet: View {
    @EnvironmentObject var s: Session
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename the Player").heading()
            TextField("Name", text: $name).onSubmit { done() }
            HStack {
                Spacer()
                Button("Cancel") { s.renaming = false }.house().keyboardShortcut(.cancelAction)
                Button("Rename") { done() }.house(primary: true).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { name = s.track?.name ?? "" }
    }

    func done() {
        let n = name.trimmingCharacters(in: .whitespaces)
        if let t = s.track, !n.isEmpty, n != t.name { s.updateTrack(t.id, "Rename the Player") { $0.name = n } }
        s.renaming = false
    }
}
