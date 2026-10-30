import SwiftUI
import AppKit
import MiddawCore

@main
struct MiddawApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var studio = Studio.shared

    var body: some Scene {
        DocumentGroup(newDocument: { SongDocument() }) { file in
            SongWindow(document: file.document)
                .environmentObject(studio)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .commands { MiddawCommands() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run from `swift run` there is no bundle to say this is an app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in Studio.shared.start() }
        Snapshot.startIfAsked()
    }
}

/// `Middaw --snapshot out.png [song]`: open the song (or a new one), wait for
/// the engines, save a picture of the window, quit. CI uses it to see the app
/// it cannot look at; it draws the window itself, so it needs no screen
/// recording permission.
@MainActor
enum Snapshot {
    static func startIfAsked() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
        let out = URL(fileURLWithPath: args[i + 1])
        let song = args.dropFirst(i + 2).last { $0.hasSuffix(".mid") || $0.hasSuffix(".midi") || $0.hasSuffix(".middaw") }
            .map { URL(fileURLWithPath: $0) }
        let editor = args.firstIndex(of: "--editor").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        if let song = song {
            NSDocumentController.shared.openDocument(withContentsOf: song, display: true) { _, _, error in
                if let e = error { FileHandle.standardError.write(Data("could not open: \(e)\n".utf8)); exit(4) }
            }
        } else {
            NSDocumentController.shared.newDocument(nil)
        }
        Task { @MainActor in
            // Wait for the engines (they load on another thread), then a moment to draw.
            for _ in 0..<60 where Studio.shared.engines == nil { try? await Task.sleep(nanoseconds: 250_000_000) }
            if let e = editor, let tab = EditorTab(rawValue: e) { Studio.shared.active?.editor = tab }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            take(to: out)
        }
    }

    static func take(to url: URL) {
        guard let w = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil && $0.frame.width > 300 }) else {
            FileHandle.standardError.write(Data("no window\n".utf8)); exit(2)
        }
        w.setFrame(NSRect(x: 0, y: 0, width: 1440, height: 900), display: true)
        let view = w.contentView?.superview ?? w.contentView!
        view.layoutSubtreeIfNeeded()
        view.display()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(3) }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { exit(3) }
        do { try png.write(to: url) } catch { exit(5) }
        print("snapshot: \(url.path) \(Int(view.bounds.width))x\(Int(view.bounds.height))")
        exit(0)
    }
}

/// The song's window: browser, tracks over the editor, inspector.
struct SongWindow: View {
    @ObservedObject var document: SongDocument
    @StateObject private var session: Session
    @EnvironmentObject var studio: Studio
    @Environment(\.undoManager) private var undoManager

    init(document: SongDocument) {
        self.document = document
        _session = StateObject(wrappedValue: Session(document: document))
    }

    var body: some View {
        VStack(spacing: 0) {
            StatusLine()
            HSplitView {
                if session.showBrowser {
                    BrowserView().frame(minWidth: 190, idealWidth: 220, maxWidth: 320)
                }
                VSplitView {
                    ArrangeView().frame(minHeight: 120, idealHeight: 320)
                    EditorView().frame(minHeight: 160, idealHeight: 360)
                }
                .frame(minWidth: 420)
                InspectorView().frame(minWidth: 260, idealWidth: 290, maxWidth: 380)
            }
        }
        .background(Theme.ground)
        .toolbar { SongToolbar() }
        .environmentObject(session)
        .focusedSceneObject(session)
        .background(WindowReader { w in
            if session.window !== w { session.window = w }
            if w.isKeyWindow { studio.becameActive(session) }
        })
        .onAppear {
            session.undo = undoManager
            studio.start()
            studio.becameActive(session)
            // A song opens with its first track chosen, so its notes are in the editor.
            if session.selection.trackID == nil, let first = document.project.tracks.first { session.select(track: first.id) }
        }
        .onChange(of: undoManager) { _, u in session.undo = u }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { n in
            if let w = n.object as? NSWindow, w === session.window { studio.becameActive(session) }
        }
        .onChange(of: document.project) { _, p in if studio.active === session { studio.sync(p) } }
        .navigationTitle(document.project.title)
    }
}

/// The status line, at the top (HIG: nothing important at the bottom). It
/// stays until dismissed or replaced.
struct StatusLine: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    var body: some View {
        let text = studio.problem ?? s.status
        if !text.isEmpty {
            HStack(spacing: 8) {
                if s.statusIsWarning || studio.problem != nil {
                    Rectangle().fill(Theme.warn).frame(width: 3)
                }
                Text(text)
                    .foregroundStyle(s.statusIsWarning || studio.problem != nil ? Theme.warnText : Theme.text)
                    .lineLimit(2)
                Spacer()
                if s.statusOffersUndo { Button("Undo") { s.undo?.undo(); s.say("") }.house() }
                Button("Dismiss") { s.say(""); studio.problem = nil }.house()
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Theme.raised)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        }
    }
}

struct SongToolbar: ToolbarContent {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { s.toStart() } label: { Image(systemName: "backward.end.fill") }
                .help("To the start (Home)")
            Button { s.playStop() } label: { Image(systemName: s.playing ? "stop.fill" : "play.fill") }
                .help(s.playing ? "Stop (Space)" : "Play from the caret (Space)")
                .accessibilityLabel(s.playing ? "Stop" : "Play")
            Button { s.toggleRecord() } label: { Image(systemName: "record.circle") }
                .foregroundStyle(s.recording ? Theme.warn : Theme.text)
                .help("Record; with the music stopped, step input (R)")
            Toggle(isOn: Binding(get: { s.project.loop.on }, set: { _ in s.toggleLoop() })) { Image(systemName: "repeat") }
                .help("Loop (L)")
            Toggle(isOn: Binding(get: { s.metronome }, set: { _ in s.toggleMetronome() })) { Image(systemName: "metronome") }
                .help("Metronome (C)")
        }
        ToolbarItem(placement: .principal) { Readout() }
        ToolbarItemGroup(placement: .primaryAction) {
            Toggle(isOn: $s.follow) { Text("Follow") }.help("Follow the music (F)")
            Picker("Editor", selection: $s.editor) {
                Text("Piano Roll").tag(EditorTab.roll)
                Text("Score").tag(EditorTab.score)
                Text("Mixer").tag(EditorTab.mixer)
            }
            .pickerStyle(.segmented)
            .help("Piano roll, score or mixer (M for the mixer)")
            Button { s.inspector = s.inspector == .generate ? .track : .generate } label: { Label("Generate", systemImage: "sparkles") }
                .help("Generate (G)")
            PassButton()
        }
    }
}

/// Position, tempo, meter and key - with ScaleView's octave and the chord
/// sounding now.
struct Readout: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var tempoText = ""
    @State private var keyOpen = false

    var body: some View {
        HStack(spacing: 10) {
            Text(s.project.position(s.playing ? s.position : s.caret))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .frame(minWidth: 52)
            HStack(spacing: 4) {
                TextField("Tempo", text: $tempoText)
                    .frame(width: 44)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { setTempo() }
                    .onAppear { tempoText = format(s.project.tempo) }
                    .onChange(of: s.project.tempo) { _, t in tempoText = format(t) }
                Text("BPM").foregroundStyle(Theme.label)
            }
            Menu("\(s.project.meter[0])/\(s.project.meter[1])") {
                ForEach([[2, 4], [3, 4], [4, 4], [5, 4], [6, 8], [7, 8], [9, 8], [12, 8]], id: \.self) { m in
                    Button("\(m[0])/\(m[1])") { s.commit("Change Time Signature") { $0.meter = m } }
                }
            }
            .fixedSize()
            Button { keyOpen.toggle() } label: {
                HStack(spacing: 6) {
                    ScaleViewIcon(key: s.project.key, sounding: sounding)
                    Text(s.project.key.displayName)
                }
            }
            .buttonStyle(.plain)
            .help("Key and scale")
            .popover(isPresented: $keyOpen) { KeyPicker().environmentObject(s) }
            Text(chordNow).frame(minWidth: 70, alignment: .leading).foregroundStyle(Theme.text)
        }
    }

    func format(_ t: Double) -> String { t == t.rounded() ? String(Int(t)) : String(format: "%.1f", t) }
    func setTempo() {
        if let v = Double(tempoText.replacingOccurrences(of: ",", with: ".")), v >= 20, v <= 300 {
            s.commit("Change Tempo") { $0.tempo = v }
        } else { tempoText = format(s.project.tempo) }
    }

    var sounding: Set<Int> {
        var out = studio.held
        if s.playing {
            for t in s.project.tracks where !t.drums && !t.mute {
                for n in t.notes where n.start <= s.position && n.end > s.position { out.insert(n.pitch) }
            }
        }
        return out
    }

    var chordNow: String {
        let held = Array(studio.held)
        if held.count >= 2 { return studio.engines?.nameChord(held, in: s.project.key) ?? "" }
        if held.count == 1 { return Theory.noteName(held[0], in: s.project.key) }
        if s.playing { return ChordLane.chord(at: s.position, in: s.project, engines: studio.engines) ?? "" }
        return ""
    }
}

/// ScaleView's icon: one octave as dots, the key's notes lit, what is
/// sounding ringed in the accent.
struct ScaleViewIcon: View {
    let key: Key
    let sounding: Set<Int>
    var body: some View {
        Canvas { g, size in
            let inKey = key.pitchClasses
            let pcs = Set(sounding.map { mod12($0) })
            let step = size.width / 7, r = min(step * 0.32, size.height * 0.2)
            let whites = [0, 2, 4, 5, 7, 9, 11]
            let blacks: [(Int, Double)] = [(1, 0.5), (3, 1.5), (6, 3.5), (8, 4.5), (10, 5.5)]
            func dot(_ pc: Int, _ x: Double, _ y: Double) {
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                g.fill(Path(ellipseIn: rect), with: .color(inKey[pc] ? Theme.text : Theme.rule))
                if pcs.contains(pc) {
                    g.stroke(Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(Theme.accent), lineWidth: 1.6)
                }
            }
            for (i, pc) in whites.enumerated() { dot(pc, step * (Double(i) + 0.5), size.height * 0.72) }
            for (pc, pos) in blacks { dot(pc, step * (pos + 0.5), size.height * 0.28) }
        }
        .frame(width: 46, height: 22)
        .accessibilityHidden(true)
    }
}

struct KeyPicker: View {
    @EnvironmentObject var s: Session
    @State private var root = 1
    @State private var scale = 1
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Key note").heading()
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 4), count: 9), spacing: 4) {
                ForEach(1...18, id: \.self) { i in
                    Button(Theory.roots[i - 1].name) { root = i }.house(on: root == i, compact: true)
                }
            }
            Text("Scale").heading()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(1...16, id: \.self) { i in
                    Button(Theory.scales[i - 1].menuName) { scale = i }.house(on: scale == i, compact: true)
                }
            }
            let k = Key(root: root, scale: scale)
            Text(k.intervals.map { k.names[mod12(k.tonic + $0)] }.joined(separator: "  ")).foregroundStyle(Theme.textDim)
            HStack {
                Spacer()
                Button("Use \(k.displayName)") { s.commit("Change Key") { $0.key = k } }.house(primary: true)
            }
        }
        .padding(14)
        .frame(width: 420)
        .onAppear { root = s.project.key.root; scale = s.project.key.scale }
    }
}

// ----------------------------------------------------------------- menus --
struct MiddawCommands: Commands {
    @FocusedObject var s: Session?

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Export MIDI File…") { s?.exportMIDI() }.keyboardShortcut("e", modifiers: [.command, .shift]).disabled(s == nil)
            Button("Export Audio…") { s?.exportAudio() }.disabled(s == nil)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Duplicate") { s?.duplicate() }.keyboardShortcut("d").disabled(s?.clip == nil)
            Button("Split at the Caret") { s?.split() }.keyboardShortcut("e").disabled(s?.clip == nil)
            Button("Select All Notes") { s?.selectAllNotes() }.keyboardShortcut("a", modifiers: [.command, .option]).disabled(s?.clip == nil)
            Divider()
            Button("Quantize") { s?.quantize() }.disabled(s?.clip == nil)
            Menu("Transform") {
                ForEach(Session.Shape.allCases, id: \.self) { shape in Button(shape.rawValue) { s?.transform(shape) } }
            }
            .disabled(s?.clip == nil)
        }
        CommandMenu("Track") {
            Button("New Track") { s?.addTrack("pno") }.keyboardShortcut("n", modifiers: [.command, .option])
            Button("Duplicate Track") { if let id = s?.selection.trackID { s?.duplicateTrack(id) } }.disabled(s?.selection.trackID == nil)
            Button("Delete Track") { if let id = s?.selection.trackID { s?.deleteTrack(id) } }.disabled(s?.selection.trackID == nil)
        }
        CommandMenu("Transport") {
            Button(s?.playing == true ? "Stop" : "Play") { s?.playStop() }
            Button("Play from the Start") { s?.playStop(fromStart: true) }
            Button("Record") { s?.toggleRecord() }
            Button("Loop") { s?.toggleLoop() }
            Button("Metronome") { s?.toggleMetronome() }
        }
        CommandGroup(after: .sidebar) {
            Button("Show or Hide the Browser") { s?.showBrowser.toggle() }.keyboardShortcut("b", modifiers: [.command, .option])
            Button("Mixer") { s?.editor = .mixer }.keyboardShortcut("m", modifiers: [.command, .option])
            Button("Score") { s?.editor = .score }.keyboardShortcut("s", modifiers: [.command, .option])
            Button("Piano Roll") { s?.editor = .roll }.keyboardShortcut("p", modifiers: [.command, .option])
        }
    }
}
