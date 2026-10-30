import SwiftUI
import AppKit
import MiddawCore
import MiddawEngines

/// The chords lane: what the accompaniment plays, beat by beat, named by
/// ScaleView's reader. Only harmony (three pitch classes or more) is named.
enum ChordLane {
    struct Span { var start: Double; var end: Double; var name: String }
    @MainActor private static var cache: (key: Int, spans: [Span]) = (0, [])

    @MainActor static func spans(_ p: Project, engines: Engines?) -> [Span] {
        guard let e = engines else { return [] }
        var h = Hasher()
        h.combine(p.key); h.combine(p.meter)
        for t in p.tracks where !t.drums && !t.mute { h.combine(t.clips); h.combine(t.role) }
        let key = h.finalize()
        if cache.key == key { return cache.spans }
        // The harmony is what the accompaniment plays; a tune's passing notes
        // are not chord tones. With no accompaniment, everything counts.
        let pitched = p.tracks.filter { !$0.drums && !$0.mute }
        let under = pitched.filter { $0.role != "melody" && $0.role != "counter" }
        let notes = (under.isEmpty || under.count == pitched.count ? pitched : under).flatMap(\.notes)
        var out: [Span] = []
        if !notes.isEmpty {
            let end = p.endOfMusic
            let step = p.meter[1] == 8 && p.meter[0] % 3 == 0 ? 1.5 : 1.0
            var b = 0.0
            while b < end {
                var pitches: [Int] = []
                var pcs = Set<Int>()
                for n in notes {
                    let overlap = min(n.end, b + step) - max(n.start, b)
                    if overlap >= step * 0.5 - 1e-6 || (abs(n.start - b) < 1e-6 && overlap > 0) { pitches.append(n.pitch); pcs.insert(mod12(n.pitch)) }
                }
                let name = pcs.count >= 3 ? e.nameChord(pitches, in: p.key) : ""
                if let last = out.last, last.name == name, abs(last.end - b) < 1e-9 { out[out.count - 1].end = b + step }
                else { out.append(Span(start: b, end: b + step, name: name)) }
                b += step
            }
        }
        cache = (key, out.filter { !$0.name.isEmpty })
        return cache.spans
    }

    @MainActor static func chord(at beat: Double, in p: Project, engines: Engines?) -> String? {
        spans(p, engines: engines).first { beat >= $0.start && beat < $0.end }?.name
    }
}

struct ArrangeView: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var scrollX: CGFloat = 0
    @State private var scrollY: CGFloat = 0
    @State private var drag: Drag?
    @State private var clicks = Clicks()
    @State private var hover: CGPoint = .zero
    @State private var loopDraft: (Double, Double)?

    let headWidth: CGFloat = 176
    let rulerHeight: CGFloat = 40
    let trackHeight: CGFloat = 58

    enum DragKind { case move, resize, range, caret }
    struct Drag {
        var kind: DragKind
        var start: CGPoint
        var trackIndex: Int
        var clipID: String?
        var clipStart: Double = 0
        var clipLength: Double = 0
        var copy = false
        var current: CGPoint
    }

    var pxb: CGFloat { s.arrangeZoom }
    func x(_ beat: Double) -> CGFloat { CGFloat(beat) * pxb - scrollX }
    func beat(_ x: CGFloat) -> Double { Double((x + scrollX) / pxb) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack {
                    Menu {
                        ForEach(["pno", "synth", "kit", "vln1", "vla", "vc", "fl", "cl", "tpt", "hn", "gtr", "ebass"], id: \.self) { id in
                            Button(studio.instrument(id)?.name ?? id) { s.addTrack(id) }
                        }
                        Divider()
                        Menu("An Ensemble") {
                            ForEach(ensembles, id: \.name) { e in Button(e.name) { s.addEnsemble(e.name, e.ids) } }
                        }
                    } label: { Label("Add Track", systemImage: "plus") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .help("Add a track (⌥⌘N)")
                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(width: headWidth, height: rulerHeight)
                .background(Theme.ground)
                ruler
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
            HStack(spacing: 0) {
                heads
                timeline
            }
        }
        .background(Theme.roll)
        .clipped()
        .scrolls("arrange-\(ObjectIdentifier(s).hashValue)", window: s.window, scroll: { dx, dy, mods in
            if mods.contains(.command) || mods.contains(.option) { zoom(by: 1 + dy / 200, at: hover.x) }
            else {
                scrollX = max(0, scrollX - (mods.contains(.shift) ? dy : dx))
                if !mods.contains(.shift) { scrollY = max(0, min(scrollY - dy, max(0, CGFloat(s.project.tracks.count) * trackHeight - 100))) }
            }
        }, magnify: { m, p in zoom(by: 1 + m, at: p.x - headWidth) })
        .onChange(of: s.position) { _, pos in followPlayhead(pos) }
    }

    func zoom(by f: CGFloat, at px: CGFloat) {
        let b = beat(px)
        s.arrangeZoom = max(3, min(160, s.arrangeZoom * f))
        scrollX = max(0, CGFloat(b) * s.arrangeZoom - px)
    }

    func followPlayhead(_ pos: Double) {
        guard s.follow, s.playing else { return }
        let px = x(pos)
        if px > 600 || px < 0 { scrollX = max(0, CGFloat(pos) * pxb - 80) }
    }

    // ------------------------------------------------------------- heads --
    var heads: some View {
        GeometryReader { g in
            VStack(spacing: 0) {
                ForEach(s.project.tracks) { t in
                    TrackHead(track: t, selected: t.id == s.selection.trackID)
                        .frame(height: trackHeight)
                }
                Spacer(minLength: 0)
            }
            .offset(y: -scrollY)
            .frame(width: headWidth, height: g.size.height, alignment: .top)
            .clipped()
        }
        .frame(width: headWidth)
        .background(Theme.ground)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.rule).frame(width: 1) }
    }

    // ------------------------------------------------------------- ruler --
    var ruler: some View {
        let p = s.project
        let spans = ChordLane.spans(p, engines: studio.engines)
        return Canvas { g, size in
            let half = size.height / 2
            g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.ground))
            let loop = loopDraft.map { Loop(on: true, start: $0.0, end: $0.1) } ?? p.loop
            if loop.end > loop.start {
                let r = CGRect(x: x(loop.start), y: 2, width: x(loop.end) - x(loop.start), height: half - 4)
                g.fill(Path(r), with: .color(loop.on ? Theme.accent.opacity(0.28) : Theme.control.opacity(0.18)))
                if loop.on { g.fill(Path(CGRect(x: r.minX, y: half - 4, width: r.width, height: 2)), with: .color(Theme.accent)) }
            }
            let bpb = p.beatsPerBar
            let every = pxb * CGFloat(bpb) < 28 ? (pxb * CGFloat(bpb) < 10 ? 8 : 4) : 1
            let first = max(0, Int(Double(scrollX / pxb) / bpb)), last = Int(Double((scrollX + size.width) / pxb) / bpb) + 1
            if first <= last {
                for bar in first...last {
                    let bx = x(Double(bar) * bpb)
                    g.fill(Path(CGRect(x: bx, y: 0, width: 1, height: size.height)), with: .color(Theme.rule))
                    if bar % every == 0 {
                        g.draw(Text("\(bar + 1)").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.label),
                               at: CGPoint(x: bx + 4, y: half / 2 + 1), anchor: .leading)
                    }
                }
            }
            g.fill(Path(CGRect(x: 0, y: half, width: size.width, height: 1)), with: .color(Theme.rule))
            for c in spans {
                let x1 = x(c.start), x2 = x(c.end)
                guard x2 > 0, x1 < size.width else { continue }
                g.fill(Path(CGRect(x: x1 + 1, y: half + 3, width: max(1, x2 - x1 - 2), height: half - 6)), with: .color(Theme.raised))
                let label = g.resolve(Text(c.name).font(.system(size: 12)).foregroundColor(Theme.text))
                if label.measure(in: size).width <= x2 - x1 - 8 { g.draw(label, at: CGPoint(x: x1 + 5, y: half + half / 2), anchor: .leading) }
            }
            let cx = x(s.caret)
            var tri = Path(); tri.move(to: CGPoint(x: cx - 5, y: 0)); tri.addLine(to: CGPoint(x: cx + 5, y: 0)); tri.addLine(to: CGPoint(x: cx, y: 7)); tri.closeSubpath()
            g.fill(tri, with: .color(Theme.accent))
            if s.playing { g.fill(Path(CGRect(x: x(s.position), y: 0, width: 2, height: size.height)), with: .color(Theme.playhead)) }
        }
        .frame(height: rulerHeight)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                // The top half sets the loop by dragging; a click anywhere moves the caret.
                guard v.startLocation.y < rulerHeight / 2, abs(v.translation.width) > 3 else { return }
                let a = s.project.snap(beat(min(v.startLocation.x, v.location.x)), grid: s.project.beatsPerBar)
                let b = s.project.snap(beat(max(v.startLocation.x, v.location.x)), grid: s.project.beatsPerBar)
                loopDraft = b > a ? (a, b) : nil
            }
            .onEnded { v in
                if let l = loopDraft {
                    s.commit("Set the Loop") { $0.loop = Loop(on: true, start: l.0, end: l.1) }
                    loopDraft = nil
                } else if abs(v.translation.width) <= 3 {
                    s.caret = max(0, s.project.snap(beat(v.location.x), grid: 1))
                    if s.playing { Studio.shared.play(from: s.caret) }
                }
            })
        .accessibilityLabel("Ruler: bars, the loop and the chords")
    }

    // ---------------------------------------------------------- timeline --
    func trackIndex(at y: CGFloat) -> Int { Int((y + scrollY) / trackHeight) }

    func hit(_ p: CGPoint) -> (track: Int, clip: Clip?, edge: Bool) {
        let ti = trackIndex(at: p.y)
        guard ti >= 0, ti < s.project.tracks.count else { return (ti, nil, false) }
        let b = beat(p.x)
        if let c = s.project.tracks[ti].clips.first(where: { b >= $0.start && b < $0.end }) {
            return (ti, c, x(c.end) - p.x < 7)
        }
        return (ti, nil, false)
    }

    var timeline: some View {
        let p = s.project
        return Canvas { g, size in
            let bpb = p.beatsPerBar
            // beats and bars
            let firstBeat = max(0, Int(scrollX / pxb)), lastBeat = Int((scrollX + size.width) / pxb) + 1
            if firstBeat <= lastBeat && pxb >= 6 {
                for b in firstBeat...lastBeat {
                    let isBar = abs(Double(b) / bpb - (Double(b) / bpb).rounded()) < 1e-9
                    g.fill(Path(CGRect(x: x(Double(b)), y: 0, width: 1, height: size.height)), with: .color(isBar ? Theme.rule : Theme.beat))
                }
            }
            // the chosen bars
            if let r = s.selection.range {
                for id in r.tracks {
                    guard let ti = p.trackIndex(id) else { continue }
                    g.fill(Path(CGRect(x: x(r.start), y: CGFloat(ti) * trackHeight - scrollY, width: x(r.end) - x(r.start), height: trackHeight)),
                           with: .color(Theme.accent.opacity(0.16)))
                }
            }
            for (ti, t) in p.tracks.enumerated() {
                let y0 = CGFloat(ti) * trackHeight - scrollY
                guard y0 + trackHeight > 0, y0 < size.height else { continue }
                if t.id == s.selection.trackID { g.fill(Path(CGRect(x: 0, y: y0, width: size.width, height: trackHeight)), with: .color(Theme.ground.opacity(0.35))) }
                g.fill(Path(CGRect(x: 0, y: y0 + trackHeight - 1, width: size.width, height: 1)), with: .color(Theme.beat))
                for c in t.clips { drawClip(g, c, track: t, y0: y0, size: size, ghost: false) }
            }
            // a clip being moved or resized, where it would go
            if let d = drag, let id = d.clipID, d.kind == .move || d.kind == .resize,
               let loc = p.clipLocation(id) {
                var c = p.tracks[loc.track].clips[loc.clip]
                let moved = moveTarget(d)
                c.start = moved.start; c.length = moved.length
                let ti = moved.track
                drawClip(g, c, track: p.tracks[loc.track], y0: CGFloat(ti) * trackHeight - scrollY, size: size, ghost: true)
            }
            if let d = drag, d.kind == .range {
                let r = CGRect(x: min(d.start.x, d.current.x), y: min(d.start.y, d.current.y),
                               width: abs(d.current.x - d.start.x), height: abs(d.current.y - d.start.y))
                g.stroke(Path(r), with: .color(Theme.accent.opacity(0.6)), lineWidth: 1)
            }
            g.fill(Path(CGRect(x: x(s.caret), y: 0, width: 1, height: size.height)), with: .color(Theme.accent.opacity(0.7)))
            if s.playing { g.fill(Path(CGRect(x: x(s.position), y: 0, width: 2, height: size.height)), with: .color(Theme.playhead)) }
        }
        .onContinuousHover { phase in if case .active(let pt) = phase { hover = pt } }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in dragChanged(v) }
            .onEnded { v in dragEnded(v) })
        .contextMenu { contextMenu }
        .accessibilityLabel("Tracks and clips")
    }

    func drawClip(_ g: GraphicsContext, _ c: Clip, track t: Track, y0: CGFloat, size: CGSize, ghost: Bool) {
        let x1 = x(c.start), x2 = x(c.end)
        guard x2 > 0, x1 < size.width else { return }
        let rect = CGRect(x: x1 + 0.5, y: y0 + 3, width: max(3, x2 - x1 - 1), height: trackHeight - 6)
        let selected = c.id == s.selection.clipID
        var gg = g
        gg.opacity = ghost ? 0.6 : 1
        gg.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Theme.raised))
        gg.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(selected ? Theme.accent : Theme.edge), lineWidth: selected ? 2 : 1)
        if !c.name.isEmpty && rect.width > 30 {
            gg.draw(Text(c.name).font(.system(size: 11)).foregroundColor(Theme.text), at: CGPoint(x: rect.minX + 5, y: rect.minY + 8), anchor: .leading)
        }
        // the notes, small
        guard !c.notes.isEmpty else { return }
        let lo = c.notes.map(\.pitch).min()!, hi = c.notes.map(\.pitch).max()!
        let top = rect.minY + 16, h = rect.height - 20
        let span = max(12, hi - lo)
        for n in c.notes where n.start < c.length {
            let nx = x(c.start + n.start), nw = max(1.5, CGFloat(min(n.len, c.length - n.start)) * pxb - 1)
            let ny = top + h - CGFloat(n.pitch - lo) / CGFloat(span) * h
            gg.fill(Path(CGRect(x: nx, y: ny - 1, width: nw, height: 2)), with: .color(selected ? Theme.accent : Theme.note))
        }
    }

    func moveTarget(_ d: Drag) -> (track: Int, start: Double, length: Double) {
        let p = s.project, grid = 1.0          // clips move by beats
        let dBeat = Double((d.current.x - d.start.x) / pxb)
        if d.kind == .resize {
            let len = max(grid, p.snap(d.clipStart + d.clipLength + dBeat, grid: grid) - d.clipStart)
            return (d.trackIndex, d.clipStart, len)
        }
        let start = max(0, p.snap(d.clipStart + dBeat, grid: grid))
        let ti = max(0, min(p.tracks.count - 1, trackIndex(at: d.current.y)))
        return (ti, start, d.clipLength)
    }

    func dragChanged(_ v: DragGesture.Value) {
        if drag == nil {
            clicks.register(v.startLocation)
            let h = hit(v.startLocation)
            let p = s.project
            if h.track >= 0, h.track < p.tracks.count { s.select(track: p.tracks[h.track].id) }
            if clicks.count == 2 {
                if let c = h.clip { s.select(clip: c.id, on: p.tracks[h.track].id); s.editor = s.editor == .mixer ? .roll : s.editor }
                else if h.track >= 0, h.track < p.tracks.count { s.newClip(on: p.tracks[h.track].id, at: beat(v.startLocation.x)) }
                drag = Drag(kind: .caret, start: v.startLocation, trackIndex: h.track, current: v.location)
                return
            }
            if let c = h.clip {
                s.select(clip: c.id, on: p.tracks[h.track].id)
                drag = Drag(kind: h.edge ? .resize : .move, start: v.startLocation, trackIndex: h.track, clipID: c.id,
                            clipStart: c.start, clipLength: c.length, copy: Clicks.modifiers.contains(.option), current: v.location)
            } else {
                drag = Drag(kind: .range, start: v.startLocation, trackIndex: h.track, current: v.location)
            }
        }
        drag?.current = v.location
    }

    func dragEnded(_ v: DragGesture.Value) {
        defer { drag = nil }
        guard let d = drag else { return }
        let moved = hypot(v.translation.width, v.translation.height) > 3
        let p = s.project
        switch d.kind {
        case .caret: break
        case .move, .resize:
            guard moved, let id = d.clipID, let loc = p.clipLocation(id) else { return }
            let target = moveTarget(d)
            _ = loc
            let toTrack = p.tracks[target.track].id
            var newID = id
            s.commit(d.copy ? "Copy Clip" : (d.kind == .resize ? "Resize Clip" : "Move Clip")) { q in
                guard let src = q.clipLocation(id) else { return }
                var c = q.tracks[src.track].clips[src.clip]
                if !d.copy { q.tracks[src.track].clips.remove(at: src.clip) } else { c.id = makeID("c"); newID = c.id }
                c.start = target.start; c.length = target.length
                c.notes = c.notes.filter { $0.start < c.length - 1e-9 }
                guard let ti = q.trackIndex(toTrack) else { return }
                q.tracks[ti].clear(from: c.start, to: c.end)
                q.tracks[ti].clips.append(c)
                q.tracks[ti].clips.sort { $0.start < $1.start }
            }
            s.select(clip: newID, on: toTrack)
        case .range:
            if !moved {
                s.caret = max(0, p.snap(beat(v.location.x), grid: s.grid))
                if s.playing { Studio.shared.play(from: s.caret) }
                s.selection.range = nil
                return
            }
            let a = max(0, min(trackIndex(at: d.start.y), trackIndex(at: v.location.y)))
            let b = min(p.tracks.count - 1, max(trackIndex(at: d.start.y), trackIndex(at: v.location.y)))
            guard a <= b else { return }
            let s0 = p.snap(beat(min(d.start.x, v.location.x)), grid: p.beatsPerBar)
            var s1 = p.snap(beat(max(d.start.x, v.location.x)), grid: p.beatsPerBar)
            if s1 <= s0 { s1 = s0 + p.beatsPerBar }
            s.choose(range: Array(p.tracks[a...b].map(\.id)), from: s0, to: s1)
            s.caret = s0
        }
    }

    @ViewBuilder var contextMenu: some View {
        let h = hit(hover)
        if let c = h.clip, h.track < s.project.tracks.count {
            let tid = s.project.tracks[h.track].id
            Button("Vary…") { s.select(clip: c.id, on: tid); s.inspector = .generate; GenerateModel.request = "midi-variator" }
            Button("Suggest…") { s.select(clip: c.id, on: tid); s.inspector = .generate; GenerateModel.request = "midi-suggester" }
            Menu("Transform") {
                ForEach(Session.Shape.allCases, id: \.self) { shape in Button(shape.rawValue) { s.select(clip: c.id, on: tid); s.transform(shape) } }
            }
            Divider()
            Button("Duplicate") { s.select(clip: c.id, on: tid); s.duplicate() }
            Button("Split at the Caret") { s.select(clip: c.id, on: tid); s.split() }
            Button("Quantize") { s.select(clip: c.id, on: tid); s.quantize() }
            Button("Export as MIDI…") { s.select(clip: c.id, on: tid); s.exportMIDI(clipOnly: true) }
            Divider()
            Button("Delete") { s.select(clip: c.id, on: tid); s.deleteSelection() }
        } else if h.track >= 0 && h.track < s.project.tracks.count {
            let tid = s.project.tracks[h.track].id
            Button("New Clip Here") { s.newClip(on: tid, at: beat(hover.x)) }
            Button("Generate Here…") { s.select(track: tid); s.caret = s.project.snap(beat(hover.x), grid: s.project.beatsPerBar, floor: true); s.inspector = .generate }
            if s.canPaste { Button("Paste") { s.select(track: tid); s.caret = beat(hover.x); s.paste() } }
        } else {
            Button("Add Track") { s.addTrack("pno") }
        }
    }
}

/// A track's head: its name, mute, solo, record arm and what plays it.
struct TrackHead: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    let track: Track
    let selected: Bool
    @State private var renaming = false
    @State private var name = ""

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(selected ? Theme.accent : Color.clear).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                if renaming {
                    TextField("Name", text: $name, onCommit: {
                        let n = name.trimmingCharacters(in: .whitespaces)
                        if !n.isEmpty { s.updateTrack(track.id, "Rename Track") { $0.name = n } }
                        renaming = false
                    }).textFieldStyle(.plain)
                } else {
                    Text(track.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                }
                HStack(spacing: 4) {
                    Button("M") { s.updateTrack(track.id, track.mute ? "Unmute" : "Mute") { $0.mute.toggle() } }
                        .house(on: track.mute, compact: true).help("Mute").accessibilityLabel("Mute \(track.name)")
                    Button("S") { s.updateTrack(track.id, track.solo ? "Unsolo" : "Solo") { $0.solo.toggle() } }
                        .house(on: track.solo, compact: true).help("Solo").accessibilityLabel("Solo \(track.name)")
                    Button { s.updateTrack(track.id, track.arm ? "Disarm" : "Arm for Recording") { $0.arm.toggle() } } label: {
                        Image(systemName: "circle.fill").font(.system(size: 9))
                    }
                    .house(on: track.arm, compact: true).help("Record into this track").accessibilityLabel("Arm \(track.name)")
                    Text(soundName).font(.system(size: 11)).foregroundStyle(Theme.textDim).lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .background(selected ? Theme.raised : Theme.ground)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { name = track.name; renaming = true }
        .onTapGesture { s.select(track: track.id) }
        .contextMenu {
            Button("Rename…") { name = track.name; renaming = true }
            Button("Duplicate Track") { s.duplicateTrack(track.id) }
            Button("Delete Track") { s.deleteTrack(track.id) }
            Divider()
            Button("Generate Here…") { s.select(track: track.id); s.inspector = .generate }
        }
    }

    var soundName: String {
        switch track.sound.device {
        case "kit": return "Drum Kit"
        case "sampler": return "Instant Instrument"
        case "synth": return SynthPresetName.name(track.sound.preset)
        default: return track.sound.device
        }
    }
}

enum SynthPresetName {
    static func name(_ id: String?) -> String {
        ["keys": "Keys", "piano": "Piano", "epiano": "Electric Piano", "strings": "Strings", "solo": "Solo String", "brass": "Brass",
         "reed": "Reed", "flute": "Flute", "pluck": "Pluck", "harp": "Harp", "bass": "Bass", "organ": "Organ", "pad": "Pad",
         "bell": "Bell", "mallet": "Mallet", "timpani": "Timpani", "lead": "Lead", "choir": "Choir"][id ?? "keys"] ?? "Keys"
    }
}
