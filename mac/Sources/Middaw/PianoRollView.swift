import SwiftUI
import AppKit
import MiddawCore
import MiddawEngines

/// Under the tracks: the chosen clip in the piano roll, as a score, or the mixer.
struct EditorView: View {
    @EnvironmentObject var s: Session
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.gap) {
                Text(s.clip.map { $0.name.isEmpty ? (s.track?.name ?? "") : "\(s.track?.name ?? "") — \($0.name)" } ?? (s.track?.name ?? ""))
                    .foregroundStyle(Theme.textDim).lineLimit(1)
                Spacer()
                if s.editor == .roll {
                    Toggle(isOn: $s.drawing) { Label("Draw", systemImage: "pencil") }.toggleStyle(.button).help("Draw notes (D)")
                    Picker("Grid", selection: $s.grid) {
                        Text("1 bar").tag(4.0); Text("1/2").tag(2.0); Text("1/4").tag(1.0); Text("1/8").tag(0.5)
                        Text("1/16").tag(0.25); Text("1/32").tag(0.125)
                        Text("1/8T").tag(1.0 / 3); Text("1/16T").tag(1.0 / 6)
                    }
                    .frame(width: 110)
                    .help("Grid (1-6)")
                    Button("Quantize") { s.quantize() }.house().disabled(s.clip == nil).help("Quantize (Q)")
                }
            }
            .padding(.horizontal, 10).frame(height: 40)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
            switch s.editor {
            case .roll:
                BlocksBar()
                PianoRoll()
            case .score: ScoreView()
            case .mixer: MixerView()
            }
        }
        .background(Theme.ground)
    }
}

/// Starting Blocks as a toolbox (Miderator 0018): a kind, then a button per
/// degree of the key. Click to hear it, double-click to put it at the caret;
/// the caret moves on, so blocks laid in a row become a phrase.
struct BlocksBar: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @StateObject private var model = BlocksModel()

    var body: some View {
        HStack(spacing: 6) {
            Text("Blocks").foregroundStyle(Theme.label)
            ForEach(model.settings.filter { ["cat", "dia", "inv", "bars"].contains($0.id) }) { setting in
                Picker(setting.label, selection: Binding(get: { setting.index }, set: { model.set(setting.id, $0, s) })) {
                    ForEach(Array(setting.names.enumerated()), id: \.offset) { i, n in Text(n).tag(i + 1) }
                }
                .labelsHidden().fixedSize().help(setting.label)
            }
            ForEach(Array(model.results.enumerated()), id: \.offset) { _, r in
                Button(r.title.split(separator: " ").first.map(String.init) ?? r.title) {
                    if Clicks.modifiers.contains(.option) || NSApp.currentEvent?.clickCount == 2 {
                        s.insertBlock(r.notes, beats: r.beats, name: r.title)
                    } else {
                        Preview.shared.play(r.parts.map { (notes: $0.notes, drums: $0.drums) }, tempo: s.project.tempo)
                    }
                }
                .house(compact: true)
                .help("\(r.detail.isEmpty ? r.title : r.detail) — double-click to put it at the caret")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).frame(height: 38)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .onAppear { model.refresh(s) }
        .onChange(of: studio.engines != nil) { _, _ in model.refresh(s) }
        .onChange(of: s.project.key) { _, _ in model.refresh(s) }
        .onChange(of: s.project.meter) { _, _ in model.refresh(s) }
    }
}

@MainActor
final class BlocksModel: ObservableObject {
    @Published var settings: [Engines.Setting] = []
    @Published var results: [Engines.Result] = []
    private var session: Engines.Session?

    func context(_ s: Session) -> Engines.Context { Engines.Context(project: s.project, instrument: s.track?.instrument ?? "pno", bars: 1) }

    func refresh(_ s: Session) {
        guard let e = Studio.shared.engines else { return }
        do {
            if session == nil { session = try e.session("starting-blocks") }
            try session!.useKey(s.project.key)
            let ctx = context(s)
            settings = try session!.settings(ctx)
            results = try session!.generate(ctx, seed: 1, count: 12).results
        } catch { s.say("Starting Blocks stopped: \(error)", warning: true) }
    }

    func set(_ id: String, _ index: Int, _ s: Session) {
        try? session?.set(id, to: index, context(s))
        refresh(s)
    }
}

/// Results heard as they are, on a piano, or the kit for drums (Miderator
/// 0043), without touching the song.
@MainActor
final class Preview {
    static let shared = Preview()
    func play(_ parts: [(notes: [Note], drums: Bool)], tempo: Double) { Studio.shared.preview(parts, tempo: tempo) }
    func stop() { Studio.shared.stopPreview() }
}

struct PianoRoll: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var scrollX: CGFloat = 0
    @State private var top: Int = 84                 // the pitch at the top edge
    @State private var drag: Drag?
    @State private var clicks = Clicks()
    @State private var lane = 0                      // 0 velocity, else a CC number

    let keysWidth: CGFloat = 60
    let rulerHeight: CGFloat = 22
    let laneHeight: CGFloat = 72
    let row: CGFloat = 12

    enum Kind { case move, resize, lasso, draw, velocity, cc, key }
    struct Drag {
        var kind: Kind
        var start: CGPoint
        var current: CGPoint
        var notes: [Int] = []
        var copy = false
        var pitch = 0
        var original: [Note] = []
        var ccPoints: [CCPoint] = []
    }

    var pxb: CGFloat { s.rollZoom }
    func x(_ beat: Double) -> CGFloat { keysWidth + CGFloat(beat) * pxb - scrollX }
    func beat(_ x: CGFloat) -> Double { Double((x - keysWidth + scrollX) / pxb) }
    func y(_ pitch: Int) -> CGFloat { rulerHeight + CGFloat(top - pitch) * row }
    func pitch(_ y: CGFloat) -> Int { Int((CGFloat(top) - (y - rulerHeight) / row + 1).rounded(.down)) }

    var body: some View {
        GeometryReader { geo in
            canvas(size: geo.size)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in changed(v, size: geo.size) }
                    .onEnded { v in ended(v, size: geo.size) })
                .scrolls("roll-\(ObjectIdentifier(s).hashValue)", window: s.window, scroll: { dx, dy, mods in
                    if mods.contains(.command) || mods.contains(.option) {
                        s.rollZoom = max(12, min(400, s.rollZoom * (1 + dy / 200)))
                    } else if mods.contains(.shift) {
                        scrollX = max(0, scrollX - dy)
                    } else {
                        scrollX = max(0, scrollX - dx)
                        top = max(20, min(127, top + Int((dy / row).rounded())))
                    }
                }, magnify: { m, _ in s.rollZoom = max(12, min(400, s.rollZoom * (1 + m))) })
                .contextMenu {
                    Picker("Lane", selection: $lane) {
                        Text("Velocity").tag(0); Text("CC1 Dynamics").tag(1); Text("CC11 Expression").tag(11)
                        Text("CC7 Volume").tag(7); Text("CC64 Sustain").tag(64)
                    }
                    Divider()
                    Button("Select All Notes") { s.selectAllNotes() }
                    Button("Quantize") { s.quantize() }
                    Menu("Transform") { ForEach(Session.Shape.allCases, id: \.self) { sh in Button(sh.rawValue) { s.transform(sh) } } }
                }
        }
        .background(Theme.roll)
        .clipped()
        .onChange(of: s.selection.clipID) { _, _ in reveal() }
        .onAppear { reveal() }
        .onChange(of: s.position) { _, pos in
            guard s.follow, s.playing else { return }
            let px = x(pos)
            if px > 900 || px < keysWidth { scrollX = max(0, CGFloat(pos) * pxb - 60) }
        }
    }

    /// Bring the chosen clip's notes into view.
    func reveal() {
        guard let c = s.clip else { return }
        scrollX = max(0, CGFloat(c.start) * pxb - 20)
        if let hi = c.notes.map(\.pitch).max(), let lo = c.notes.map(\.pitch).min() {
            top = min(127, max(hi + 4, (hi + lo) / 2 + 14))
        }
    }

    func noteAt(_ p: CGPoint) -> (index: Int, edge: Bool)? {
        guard let c = s.clip else { return nil }
        let b = beat(p.x), pi = pitch(p.y)
        for (i, n) in c.notes.enumerated().reversed() where n.pitch == pi {
            let st = c.start + n.start
            if b >= st && b < st + n.len { return (i, x(st + n.len) - p.x < 6) }
        }
        return nil
    }

    // ------------------------------------------------------------ drawing --
    func canvas(size: CGSize) -> some View {
        let p = s.project
        let clip = s.clip
        let track = s.track
        let inst = track.flatMap { studio.instrument($0.instrument) }
        let preview = drag.map { previewNotes($0) }
        return Canvas { g, size in
            let noteBottom = size.height - laneHeight
            let inKey = p.key.pitchClasses
            // rows
            var pp = pitch(noteBottom) - 1
            while pp <= top {
                let yy = y(pp)
                if yy < noteBottom && yy + row > rulerHeight && pp >= 0 && pp <= 127 {
                    let black = [1, 3, 6, 8, 10].contains(mod12(pp))
                    let fill = !inKey[mod12(pp)] ? Theme.beat : (black ? Theme.sunken : Theme.roll)
                    g.fill(Path(CGRect(x: keysWidth, y: yy, width: size.width, height: row)), with: .color(fill))
                    if mod12(pp) == 0 { g.fill(Path(CGRect(x: keysWidth, y: yy + row - 1, width: size.width, height: 1)), with: .color(Theme.rule)) }
                }
                pp += 1
            }
            // beats and the grid
            let bpb = p.beatsPerBar
            let firstBeat = max(0, Int(scrollX / pxb)), lastBeat = Int((scrollX + size.width) / pxb) + 1
            if firstBeat <= lastBeat {
                for b in firstBeat...lastBeat {
                    let bx = x(Double(b))
                    let isBar = abs(Double(b) / bpb - (Double(b) / bpb).rounded()) < 1e-9
                    g.fill(Path(CGRect(x: bx, y: rulerHeight, width: 1, height: noteBottom - rulerHeight)), with: .color(isBar ? Theme.rule : Theme.beat))
                    if isBar {
                        g.draw(Text("\(Int((Double(b) / bpb).rounded()) + 1)").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.label),
                               at: CGPoint(x: bx + 4, y: rulerHeight / 2), anchor: .leading)
                    }
                }
            }
            // the other tracks, faint, so the part can be written against them
            for t in p.tracks where t.id != track?.id && !t.drums && !t.mute {
                for n in t.notes {
                    let nx = x(n.start), nw = CGFloat(n.len) * pxb
                    guard nx + nw > keysWidth, nx < size.width else { continue }
                    g.fill(Path(CGRect(x: nx, y: y(n.pitch) + 2, width: max(2, nw - 1), height: row - 4)), with: .color(Theme.noteDim))
                }
            }
            // the clip's span
            if let c = clip {
                g.fill(Path(CGRect(x: x(c.start), y: rulerHeight, width: CGFloat(c.length) * pxb, height: noteBottom - rulerHeight)),
                       with: .color(Theme.control.opacity(0.04)))
                g.fill(Path(CGRect(x: x(c.end), y: rulerHeight, width: 1, height: noteBottom - rulerHeight)), with: .color(Theme.edge))
                let notes = preview ?? c.notes
                for (i, n) in notes.enumerated() where n.start < c.length {
                    let nx = x(c.start + n.start), nw = max(3, CGFloat(min(n.len, c.length - n.start)) * pxb - 1)
                    guard nx + nw > keysWidth, nx < size.width else { continue }
                    let chosen = s.selection.notes.contains(i) || (drag?.notes.contains(i) ?? false)
                    let out = inst.map { n.pitch < ($0.low ?? 0) || n.pitch > ($0.high ?? 127) } ?? false
                    let r = CGRect(x: nx, y: y(n.pitch) + 1, width: nw, height: row - 2)
                    g.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(chosen ? Theme.accent : Theme.note))
                    if out { g.fill(Path(CGRect(x: r.minX, y: r.minY, width: 3, height: r.height)), with: .color(Theme.warn)) }
                }
            } else {
                g.draw(Text(track == nil ? "Add a track to begin." : "Choose a clip, or double-click a track to make one.")
                        .font(.system(size: 13)).foregroundColor(Theme.textDim),
                       at: CGPoint(x: size.width / 2, y: (rulerHeight + noteBottom) / 2))
            }
            if let d = drag, d.kind == .lasso {
                let r = CGRect(x: min(d.start.x, d.current.x), y: min(d.start.y, d.current.y), width: abs(d.current.x - d.start.x), height: abs(d.current.y - d.start.y))
                g.fill(Path(r), with: .color(Theme.accent.opacity(0.12)))
                g.stroke(Path(r), with: .color(Theme.accent.opacity(0.7)), lineWidth: 1)
            }
            // caret and playhead
            g.fill(Path(CGRect(x: x(s.caret), y: rulerHeight, width: 1, height: noteBottom - rulerHeight)), with: .color(Theme.accent.opacity(0.7)))
            if s.playing { g.fill(Path(CGRect(x: x(s.position), y: 0, width: 2, height: noteBottom)), with: .color(Theme.playhead)) }
            // the keys, with the instrument's range bracketed beside them
            g.fill(Path(CGRect(x: 0, y: 0, width: keysWidth, height: size.height)), with: .color(Theme.ground))
            pp = pitch(noteBottom) - 1
            while pp <= top {
                let yy = y(pp)
                if yy < noteBottom && yy + row > rulerHeight && pp >= 0 && pp <= 127 {
                    let black = [1, 3, 6, 8, 10].contains(mod12(pp))
                    let held = studio.held.contains(pp)
                    let r = CGRect(x: keysWidth * 0.32, y: yy, width: keysWidth * 0.68 - 1, height: row - 1)
                    g.fill(Path(r), with: .color(held ? Theme.accent : (black ? Theme.rule : Theme.controlHover)))
                    let label = track?.drums == true ? (drumNames[pp] ?? "") : (mod12(pp) == 0 ? "C\(pp / 12 - 1)" : "")
                    if !label.isEmpty {
                        g.draw(Text(label).font(.system(size: 9)).foregroundColor(black && !held ? Theme.text : Theme.ink),
                               at: CGPoint(x: keysWidth - 4, y: yy + row / 2), anchor: .trailing)
                    }
                }
                pp += 1
            }
            if let i = inst, let lo = i.low, let hi = i.high, track?.drums != true {
                let bx = keysWidth * 0.32 - 5
                let y1 = max(rulerHeight, y(hi)), y2 = min(noteBottom, y(lo) + row)
                if y2 > y1 { g.fill(Path(CGRect(x: bx, y: y1, width: 2, height: y2 - y1)), with: .color(Theme.edge)) }
                if let sw = i.sweet, sw.count == 2 {
                    let s1 = max(rulerHeight, y(sw[1])), s2 = min(noteBottom, y(sw[0]) + row)
                    if s2 > s1 { g.fill(Path(CGRect(x: bx - 2, y: s1, width: 4, height: s2 - s1)), with: .color(Theme.control)) }
                }
            }
            g.fill(Path(CGRect(x: keysWidth - 1, y: 0, width: 1, height: size.height)), with: .color(Theme.rule))
            g.fill(Path(CGRect(x: 0, y: rulerHeight - 1, width: size.width, height: 1)), with: .color(Theme.rule))
            // the lane: velocity, or a controller
            drawLane(g, size: size, clip: clip, notes: preview ?? clip?.notes ?? [])
        }
    }

    func drawLane(_ g: GraphicsContext, size: CGSize, clip: Clip?, notes: [Note]) {
        let top = size.height - laneHeight
        g.fill(Path(CGRect(x: 0, y: top, width: size.width, height: laneHeight)), with: .color(Theme.sunken))
        g.fill(Path(CGRect(x: 0, y: top, width: size.width, height: 1)), with: .color(Theme.rule))
        g.draw(Text(lane == 0 ? "Velocity" : "CC\(lane)").font(.system(size: 11)).foregroundColor(Theme.label), at: CGPoint(x: 6, y: top + 10), anchor: .leading)
        guard let c = clip else { return }
        let inner = laneHeight - 10, base = size.height - 4
        if lane == 0 {
            for (i, n) in notes.enumerated() where n.start < c.length {
                let nx = x(c.start + n.start)
                guard nx > keysWidth, nx < size.width else { continue }
                let h = CGFloat(n.vel) / 127 * inner
                let chosen = s.selection.notes.contains(i)
                g.fill(Path(CGRect(x: nx, y: base - h, width: 3, height: h)), with: .color(chosen ? Theme.accent : Theme.note))
                g.fill(Path(CGRect(x: nx - 2, y: base - h, width: 7, height: 2)), with: .color(chosen ? Theme.accent : Theme.note))
            }
        } else {
            let pts = drag?.kind == .cc ? (drag?.ccPoints ?? []) : (c.cc[lane] ?? [])
            guard !pts.isEmpty else { return }
            var path = Path()
            for (i, pt) in pts.enumerated() {
                let px = x(c.start + pt.beat), py = base - CGFloat(pt.value) / 127 * inner
                if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                else { path.addLine(to: CGPoint(x: px, y: base - CGFloat(pts[i - 1].value) / 127 * inner)); path.addLine(to: CGPoint(x: px, y: py)) }
            }
            g.stroke(path, with: .color(Theme.note), lineWidth: 2)
        }
    }

    let drumNames: [Int: String] = [35: "Kick 2", 36: "Kick", 37: "Stick", 38: "Snare", 39: "Clap", 40: "Snare 2", 41: "Tom 6",
        42: "Hat", 43: "Tom 5", 44: "Pedal", 45: "Tom 4", 46: "Open", 47: "Tom 3", 48: "Tom 2", 49: "Crash", 50: "Tom 1",
        51: "Ride", 53: "Bell", 54: "Tamb", 56: "Cowbell", 57: "Crash 2"]

    // ------------------------------------------------------------ editing --
    func snapBeat(_ b: Double) -> Double {
        guard let c = s.clip else { return b }
        let local = b - c.start
        return (local / s.grid).rounded() * s.grid
    }

    /// The clip's notes as they would be if the drag ended now.
    func previewNotes(_ d: Drag) -> [Note]? {
        guard let c = s.clip, [.move, .resize, .draw, .velocity].contains(d.kind) else { return nil }
        let dBeat = (Double((d.current.x - d.start.x) / pxb) / s.grid).rounded() * s.grid
        let dPitch = Int(((d.start.y - d.current.y) / row).rounded())
        var out = d.original.isEmpty ? c.notes : d.original
        switch d.kind {
        case .move:
            var copies: [Note] = []
            for i in d.notes where i < out.count {
                if d.copy { copies.append(out[i]) }
                out[i].start = max(0, out[i].start + dBeat)
                out[i].pitch = max(0, min(127, out[i].pitch + dPitch))
            }
            out += copies
        case .resize:
            for i in d.notes where i < out.count { out[i].len = max(s.grid / 2, out[i].len + dBeat) }
        case .draw:
            if let i = d.notes.first, i < out.count {
                let st = c.start + out[i].start
                out[i].len = max(s.grid, (Double((beat(d.current.x) - st) / s.grid)).rounded(.up) * s.grid)
            }
        case .velocity:
            let base = d.start.y
            for i in d.notes where i < out.count {
                out[i].vel = max(1, min(127, out[i].vel + Int((base - d.current.y) / 0.5)))
            }
        default: break
        }
        return out
    }

    func changed(_ v: DragGesture.Value, size: CGSize) {
        if drag == nil { begin(v, size: size) }
        drag?.current = v.location
        if drag?.kind == .cc, let c = s.clip {
            let inner = laneHeight - 10, base = size.height - 4
            let b = max(0, min(c.length, (beat(v.location.x) - c.start)))
            let val = max(0, min(127, Int(((base - v.location.y) / inner * 127).rounded())))
            var pts = drag!.ccPoints.filter { abs($0.beat - b) > s.grid / 4 }
            pts.append(CCPoint(beat: (b / (s.grid / 2)).rounded() * (s.grid / 2), value: val))
            drag!.ccPoints = pts.sorted { $0.beat < $1.beat }
        }
        if drag?.kind == .key {
            let pi = pitch(v.location.y)
            if pi != drag!.pitch { drag!.pitch = pi; studio.audition(pi, on: s.track?.id) }
        }
    }

    func begin(_ v: DragGesture.Value, size: CGSize) {
        clicks.register(v.startLocation)
        let p0 = v.startLocation
        let laneTop = size.height - laneHeight
        guard let c = s.clip else {
            drag = Drag(kind: .lasso, start: p0, current: p0)
            return
        }
        if p0.x < keysWidth {
            let pi = pitch(p0.y)
            studio.audition(pi, on: s.track?.id)
            drag = Drag(kind: .key, start: p0, current: p0, pitch: pi)
            return
        }
        if p0.y > laneTop {
            if lane == 0 {
                // the notes whose velocity bar is under the pointer, or the chosen ones
                let near = c.notes.indices.filter { abs(x(c.start + c.notes[$0].start) - p0.x) < 5 }
                let idx = s.selection.notes.isEmpty || !near.contains(where: { s.selection.notes.contains($0) }) ? near : Array(s.selection.notes)
                drag = Drag(kind: .velocity, start: p0, current: p0, notes: idx, original: c.notes)
            } else {
                drag = Drag(kind: .cc, start: p0, current: p0, ccPoints: c.cc[lane] ?? [])
            }
            return
        }
        let hit = noteAt(p0)
        if clicks.count == 2, let h = hit {
            // a double-click on a note removes it
            s.selection.notes = []
            var notes = c.notes; notes.remove(at: h.index)
            s.setNotes(notes, label: "Delete Note")
            drag = Drag(kind: .key, start: p0, current: p0, pitch: -1)
            return
        }
        if let h = hit {
            if !s.selection.notes.contains(h.index) {
                s.selection.notes = Clicks.modifiers.contains(.shift) ? s.selection.notes.union([h.index]) : [h.index]
            }
            studio.audition(c.notes[h.index].pitch, on: s.track?.id, velocity: c.notes[h.index].vel)
            drag = Drag(kind: h.edge ? .resize : .move, start: p0, current: p0, notes: Array(s.selection.notes),
                        copy: Clicks.modifiers.contains(.option), original: c.notes)
            return
        }
        if s.drawing || clicks.count == 2 {
            let st = max(0, ((beat(p0.x) - c.start) / s.grid).rounded(.down) * s.grid)
            guard st < c.length else { drag = Drag(kind: .lasso, start: p0, current: p0); return }
            var notes = c.notes
            let n = Note(start: st, len: s.grid, pitch: pitch(p0.y), vel: 100)
            notes.append(n)
            studio.audition(n.pitch, on: s.track?.id)
            drag = Drag(kind: .draw, start: p0, current: p0, notes: [notes.count - 1], original: notes)
            s.selection.notes = [notes.count - 1]
            return
        }
        drag = Drag(kind: .lasso, start: p0, current: p0)
    }

    func ended(_ v: DragGesture.Value, size: CGSize) {
        defer { drag = nil }
        guard let d = drag else { return }
        let moved = hypot(v.translation.width, v.translation.height) > 2
        switch d.kind {
        case .key: break
        case .move, .resize:
            guard moved, let notes = previewNotes(d) else { return }
            let label = d.kind == .resize ? "Resize Notes" : (d.copy ? "Copy Notes" : "Move Notes")
            s.setNotes(notes, label: label)
            if d.copy { s.selection.notes = Set((notes.count - d.notes.count)..<notes.count) }
        case .draw:
            if let notes = previewNotes(d) { s.setNotes(notes, label: "Draw Note") }
        case .velocity:
            if moved, let notes = previewNotes(d) { s.setNotes(notes, label: "Change Velocity") }
        case .cc:
            let pts = d.ccPoints, l = lane
            s.updateClip("Draw CC\(l)") { cl, _ in cl.cc[l] = pts }
        case .lasso:
            guard let c = s.clip else { return }
            if !moved {
                s.selection.notes = []
                s.caret = max(0, c.start + snapBeat(beat(v.location.x)))
                return
            }
            let r = CGRect(x: min(d.start.x, d.current.x), y: min(d.start.y, d.current.y), width: abs(d.current.x - d.start.x), height: abs(d.current.y - d.start.y))
            var chosen = Set<Int>()
            for (i, n) in c.notes.enumerated() {
                let nr = CGRect(x: x(c.start + n.start), y: y(n.pitch), width: max(3, CGFloat(n.len) * pxb), height: row)
                if nr.intersects(r) { chosen.insert(i) }
            }
            s.selection.notes = Clicks.modifiers.contains(.shift) ? s.selection.notes.union(chosen) : chosen
        }
    }
}
