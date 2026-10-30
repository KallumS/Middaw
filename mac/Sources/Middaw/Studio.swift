import SwiftUI
import AppKit
import MiddawCore
import MiddawEngines
import MiddawAudio

/// What every window shares: the engines, the sound card, the MIDI keyboard.
/// One window plays at a time - the one in front.
@MainActor
final class Studio: ObservableObject {
    static let shared = Studio()

    let audio = AudioEngine()
    let midi = MIDIInput()
    @Published private(set) var engines: Engines?
    @Published private(set) var instruments: [Engines.Instrument] = []
    @Published private(set) var generators: [Engines.Generator] = []
    @Published var problem: String?
    /// Where the music is and whether it plays, refreshed for the screen.
    @Published private(set) var position: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var held: Set<Int> = []

    /// The window whose song the sound card is playing.
    weak var active: Session?
    private var started = false
    private var timer: Timer?

    func start() {
        guard !started else { return }
        started = true
        do { try audio.start() } catch { problem = "The sound card would not start: \(error.localizedDescription)" }
        midi.onMessage = { s, d1, d2 in DispatchQueue.main.async { Studio.shared.fromKeyboard(s, d1, d2) } }
        midi.start()
        let root = Engines.defaultRoot()
        Task.detached(priority: .userInitiated) {
            do {
                let e = try Engines(root: root)
                let list = try e.instruments()
                let gens = try e.generators()
                await MainActor.run {
                    Studio.shared.engines = e
                    Studio.shared.instruments = list
                    Studio.shared.generators = gens
                }
            } catch {
                await MainActor.run { Studio.shared.problem = "The engines would not load: \(error)" }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { _ in
            Task { @MainActor in Studio.shared.tick() }
        }
        KeyMonitor.shared.install()
    }

    private func tick() {
        let r = audio.renderer
        if r.isPlaying != isPlaying { isPlaying = r.isPlaying }
        if isPlaying || abs(r.position - position) > 1e-6 { position = r.position }
        active?.tick(position: position, playing: isPlaying)
    }

    func instrument(_ id: String) -> Engines.Instrument? { instruments.first { $0.id == id } }

    // ------------------------------------------------------- transport --
    func becameActive(_ s: Session) {
        guard active !== s else { return }
        if isPlaying { audio.renderer.stop() }
        active = s
        sync(s.document.project)
    }
    func sync(_ p: Project) { audio.renderer.update(p) }
    func play(from beat: Double) { audio.renderer.play(from: beat) }
    func stop() { audio.renderer.stop() }
    func setMetronome(_ on: Bool) { audio.renderer.setMetronome(on) }

    // ------------------------------------------------------ the keyboard --
    func fromKeyboard(_ status: UInt8, _ d1: UInt8, _ d2: UInt8) {
        guard let s = active else { return }
        let kind = status & 0xF0
        if kind == 0x90 && d2 > 0 { held.insert(Int(d1)) } else if kind == 0x80 || kind == 0x90 { held.remove(Int(d1)) }
        if let t = s.targetTrackForInput { audio.renderer.live(t, status, d1, d2) }
        s.received(status, d1, d2, at: audio.renderer.position, playing: isPlaying)
    }

    /// A result heard as it is: every part on a piano, drums on the kit
    /// (Miderator 0043), from the top, without touching the song.
    func preview(_ parts: [(notes: [Note], drums: Bool)], tempo: Double) {
        var p = Project(tempo: tempo)
        for (i, part) in parts.enumerated() {
            var t = Track(id: "preview\(i)", name: "Preview", drums: part.drums,
                          sound: Device(device: part.drums ? "kit" : "synth", preset: part.drums ? nil : "piano"))
            let end = part.notes.map(\.end).max() ?? 0
            t.clips = [Clip(start: 0, length: max(0.25, end + 0.01), notes: part.notes)]
            p.tracks.append(t)
        }
        audio.preview.stop()
        audio.preview.update(p)
        audio.preview.play(from: 0)
    }
    func stopPreview() { audio.preview.stop() }

    /// A note heard now, from the piano roll's keys or a result's preview.
    func audition(_ pitch: Int, on trackID: String?, velocity: Int = 100) {
        guard let t = trackID ?? active?.selection.trackID else { return }
        audio.renderer.live(t, 0x90, UInt8(max(0, min(127, pitch))), UInt8(velocity))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [audio] in audio.renderer.live(t, 0x80, UInt8(max(0, min(127, pitch))), 0) }
    }
}

/// Plain keys - Space, R, L, the arrows - for the window in front, unless a
/// text field has them. Keys with Command are the menus' business.
@MainActor
final class KeyMonitor {
    static let shared = KeyMonitor()
    private var installed = false

    func install() {
        guard !installed else { return }
        installed = true
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) { return event }
            if let responder = NSApp.keyWindow?.firstResponder, responder is NSText { return event }
            guard let s = Studio.shared.active, s.window === NSApp.keyWindow else { return event }
            return s.handleKey(event) ? nil : event
        }
    }
}

/// Captures the NSWindow a SwiftUI view lives in.
struct WindowReader: NSViewRepresentable {
    let found: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { if let w = v.window { found(w) } }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { if let w = nsView.window { found(w) } }
    }
}
