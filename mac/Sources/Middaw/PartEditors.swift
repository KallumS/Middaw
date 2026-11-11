import SwiftUI
import AppKit
import MiddawCore
import MiddawEngines

/// General MIDI's drum map, as the lanes of the drum editor and the rows of
/// a drum machine. On a kit a note names an instrument, not a pitch.
enum DrumMap {
    /// Cymbals at the top, kick at the bottom, as a drum editor reads.
    static let lanes: [(pitch: Int, name: String)] = [
        (49, "Crash"), (57, "Crash 2"), (51, "Ride"), (53, "Ride Bell"), (46, "Open Hat"), (44, "Pedal Hat"), (42, "Closed Hat"),
        (50, "Tom 1"), (48, "Tom 2"), (47, "Tom 3"), (45, "Tom 4"), (43, "Tom 5"), (41, "Tom 6"),
        (54, "Tambourine"), (56, "Cowbell"), (39, "Clap"), (37, "Side Stick"), (40, "Snare 2"), (38, "Snare"), (35, "Kick 2"), (36, "Kick"),
    ]
    /// A drum machine's eight.
    static let machine: [(pitch: Int, name: String)] = [
        (49, "Crash"), (46, "Open Hat"), (42, "Closed Hat"), (50, "High Tom"), (45, "Low Tom"), (39, "Clap"), (38, "Snare"), (36, "Kick"),
    ]

    /// The lanes, with any note the part plays that they do not name added at the top.
    static func rows(_ base: [(pitch: Int, name: String)], _ notes: [Note]) -> [(pitch: Int, name: String)] {
        let named = Set(base.map(\.pitch))
        let extra = Set(notes.map(\.pitch)).subtracting(named).sorted(by: >).map { (pitch: $0, name: "Note \($0)") }
        return extra + base
    }

    /// Accent, normal and ghost: the X, x and o the kit's patterns are written in.
    static func nextVelocity(_ v: Int) -> Int { v >= 115 ? 100 : (v >= 70 ? 50 : 127) }
}

/// What painting across cells does: the first cell decides whether the drag
/// adds or removes.
private struct Paint {
    var adding: Bool
    var accent: Bool
    var touched: Set<String> = []
    var notes: [Note]
}

/// Cells counted from the clip's start, `step` beats each; returns the notes
/// with the cell at `index` on `pitch` filled or emptied.
private func setCell(_ notes: inout [Note], pitch: Int, index: Int, step: Double, on: Bool, velocity: Int = 100) {
    let a = Double(index) * step, b = a + step
    if on {
        if !notes.contains(where: { $0.pitch == pitch && $0.start >= a - 1e-6 && $0.start < b - 1e-6 }) {
            notes.append(Note(start: a, len: step, pitch: pitch, vel: velocity))
            notes.sort { $0.start != $1.start ? $0.start < $1.start : $0.pitch < $1.pitch }
        }
    } else {
        notes.removeAll { $0.pitch == pitch && $0.start >= a - 1e-6 && $0.start < b - 1e-6 }
    }
}

private func cycleVelocity(_ notes: inout [Note], pitch: Int, index: Int, step: Double) -> Bool {
    let a = Double(index) * step, b = a + step
    var changed = false
    for i in notes.indices where notes[i].pitch == pitch && notes[i].start >= a - 1e-6 && notes[i].start < b - 1e-6 {
        notes[i].vel = DrumMap.nextVelocity(notes[i].vel); changed = true
    }
    return changed
}

/// The placeholder when there is nothing to edit.
struct NoPart: View {
    @EnvironmentObject var s: Session
    var body: some View {
        Text(s.track == nil ? "Choose a player on the stage." : "Choose a clip in the part, or double-click the part to make one.")
            .foregroundStyle(Theme.textDim).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.roll)
    }
}

// ------------------------------------------------------------- drums --
/// Drums, as Cubase's and Logic's drum editors show them: a lane per drum,
/// a hit as a diamond where it starts. Click or drag along a lane to add
/// hits on the grid, start on a hit to take them away; Option-click a hit to
/// make it an accent, a normal hit or a ghost.
struct DrumEditor: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var paint: Paint?
    let namesWidth: CGFloat = 96
    let row: CGFloat = 20
    let ruler: CGFloat = 22

    var body: some View {
        if let c = s.clip, let t = s.track {
            let lanes = DrumMap.rows(DrumMap.lanes, c.notes)
            let width = max(200, CGFloat(c.length) * s.rollZoom)
            let height = ruler + CGFloat(lanes.count) * row
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: ruler)
                        ForEach(Array(lanes.enumerated()), id: \.offset) { i, lane in
                            Text(lane.name).font(.system(size: 11)).foregroundStyle(Theme.label)
                                .frame(width: namesWidth - 8, height: row, alignment: .leading).padding(.leading, 8)
                                .background(i % 2 == 0 ? Theme.ground : Theme.sunken)
                                .contentShape(Rectangle())
                                .onTapGesture { studio.audition(lane.pitch, on: t.id) }
                                .help("Hear the \(lane.name)")
                        }
                    }
                    .frame(width: namesWidth)
                    ScrollView(.horizontal) {
                        grid(c, lanes: lanes, width: width, height: height)
                            .frame(width: width, height: height)
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { v in changed(v, c, lanes, track: t) }
                                .onEnded { _ in ended() })
                    }
                }
            }
            .background(Theme.roll)
        } else {
            NoPart()
        }
    }

    func grid(_ c: Clip, lanes: [(pitch: Int, name: String)], width: CGFloat, height: CGFloat) -> some View {
        let pxb = s.rollZoom, grid = s.grid, p = s.project
        let notes = paint?.notes ?? c.notes
        return Canvas { g, size in
            for i in lanes.indices where i % 2 == 1 {
                g.fill(Path(CGRect(x: 0, y: ruler + CGFloat(i) * row, width: size.width, height: row)), with: .color(Theme.ground.opacity(0.35)))
            }
            // the grid, the beats and the bars, counted from the bar lines
            var b = 0.0
            while b <= c.length + 1e-9 {
                let song = c.start + b
                let isBar = abs(song / p.beatsPerBar - (song / p.beatsPerBar).rounded()) < 1e-6
                let isBeat = abs(song - song.rounded()) < 1e-6
                let x = CGFloat(b) * pxb
                g.fill(Path(CGRect(x: x, y: isBar ? 0 : ruler, width: 1, height: size.height)),
                       with: .color(isBar ? Theme.rule : (isBeat ? Theme.beat : Theme.beat.opacity(0.5))))
                if isBar {
                    g.draw(Text("\(p.bar(of: song) + 1)").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.label),
                           at: CGPoint(x: x + 4, y: ruler / 2), anchor: .leading)
                }
                b += grid
            }
            g.fill(Path(CGRect(x: 0, y: ruler - 1, width: size.width, height: 1)), with: .color(Theme.rule))
            // the hits
            let rowOf = Dictionary(lanes.enumerated().map { ($0.element.pitch, $0.offset) }, uniquingKeysWith: { a, _ in a })
            for n in notes where n.start < c.length {
                guard let i = rowOf[n.pitch] else { continue }
                let cx = CGFloat(n.start) * pxb, cy = ruler + CGFloat(i) * row + row / 2
                let r = n.vel < 70 ? row * 0.24 : row * 0.36
                var d = Path()
                d.move(to: CGPoint(x: cx, y: cy - r)); d.addLine(to: CGPoint(x: cx + r, y: cy))
                d.addLine(to: CGPoint(x: cx, y: cy + r)); d.addLine(to: CGPoint(x: cx - r, y: cy)); d.closeSubpath()
                g.fill(d, with: .color(n.vel >= 115 ? Theme.controlHover : Theme.note.opacity(n.vel < 70 ? 0.6 : 1)))
                if n.vel >= 115 { g.stroke(d, with: .color(Theme.ink), lineWidth: 1.5) }
            }
            // caret and playhead
            let caret = s.caret - c.start
            if caret >= 0 && caret <= c.length {
                g.fill(Path(CGRect(x: CGFloat(caret) * pxb, y: ruler, width: 1, height: size.height)), with: .color(Theme.accent.opacity(0.7)))
            }
            let pos = s.position - c.start
            if s.playing && pos >= 0 && pos <= c.length {
                g.fill(Path(CGRect(x: CGFloat(pos) * pxb, y: 0, width: 2, height: size.height)), with: .color(Theme.playhead))
            }
        }
        .accessibilityLabel("Drum lanes")
    }

    func changed(_ v: DragGesture.Value, _ c: Clip, _ lanes: [(pitch: Int, name: String)], track t: Track) {
        let grid = s.grid
        let lane = Int(((v.location.y - ruler) / row).rounded(.down))
        let beat = Double(v.location.x / s.rollZoom)
        let index = Int((beat / grid).rounded(.down))
        if paint == nil {
            if v.startLocation.y < ruler {
                s.caret = max(0, c.start + (beat / grid).rounded(.down) * grid)
                if s.playing { Studio.shared.play(from: s.caret) }
                paint = Paint(adding: false, accent: false, touched: ["ruler"], notes: c.notes)
                return
            }
            guard lane >= 0, lane < lanes.count, beat >= 0, beat < c.length else { return }
            let pitch = lanes[lane].pitch
            var notes = c.notes
            let a = Double(index) * grid
            let hit = notes.contains { $0.pitch == pitch && $0.start >= a - 1e-6 && $0.start < a + grid - 1e-6 }
            if Clicks.modifiers.contains(.option) {
                _ = cycleVelocity(&notes, pitch: pitch, index: index, step: grid)
                paint = Paint(adding: false, accent: true, touched: ["\(lane):\(index)"], notes: notes)
                return
            }
            setCell(&notes, pitch: pitch, index: index, step: grid, on: !hit)
            if !hit { studio.audition(pitch, on: t.id) }
            paint = Paint(adding: !hit, accent: false, touched: ["\(lane):\(index)"], notes: notes)
            return
        }
        guard var p = paint, !p.accent, !p.touched.contains("ruler"), lane >= 0, lane < lanes.count, beat >= 0, beat < c.length else { return }
        let key = "\(lane):\(index)"
        guard !p.touched.contains(key) else { return }
        p.touched.insert(key)
        setCell(&p.notes, pitch: lanes[lane].pitch, index: index, step: grid, on: p.adding)
        paint = p
    }

    func ended() {
        defer { paint = nil }
        guard let p = paint, !p.touched.contains("ruler") else { return }
        s.setNotes(p.notes, label: p.accent ? "Change Velocity" : (p.adding ? "Draw Hits" : "Erase Hits"))
    }
}

// ---------------------------------------------------- step sequencer --
/// A step sequencer, as FL Studio's channel rack and Logic's Step Sequencer
/// have one: a row per drum (a drum machine's eight) or per note of the key,
/// a cell per step of the grid. Click a cell to turn it on or off, drag to
/// paint; Option-click to make a step an accent, normal or a ghost.
struct StepSequencer: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var paint: Paint?
    let namesWidth: CGFloat = 84
    let cell = CGSize(width: 26, height: 22)
    let header: CGFloat = 22

    /// Steps no coarser than a quarter and no finer than a thirty-second.
    var step: Double { min(1, max(0.125, s.grid)) }

    var body: some View {
        if let c = s.clip, let t = s.track {
            let lanes = rows(c, track: t)
            let count = max(1, Int((c.length / step - 1e-9).rounded(.up)))
            let width = CGFloat(count) * cell.width
            let height = header + CGFloat(lanes.count) * cell.height
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: header)
                        ForEach(Array(lanes.enumerated()), id: \.offset) { _, r in
                            Text(r.name).font(.system(size: 11)).foregroundStyle(Theme.label)
                                .frame(width: namesWidth - 8, height: cell.height, alignment: .leading).padding(.leading, 8)
                                .contentShape(Rectangle())
                                .onTapGesture { studio.audition(r.pitch, on: t.id) }
                                .help("Hear \(r.name)")
                        }
                    }
                    .frame(width: namesWidth)
                    ScrollView(.horizontal) {
                        cells(c, rows: lanes, count: count)
                            .frame(width: width, height: height)
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { v in changed(v, c, lanes, count: count, track: t) }
                                .onEnded { _ in ended() })
                    }
                }
                .padding(.vertical, 4)
            }
            .background(Theme.roll)
        } else {
            NoPart()
        }
    }

    /// For a kit, a drum machine's lanes; for anything else, the notes of the
    /// key over two octaves around the part, highest first - and any note
    /// the part plays outside them.
    func rows(_ c: Clip, track t: Track) -> [(pitch: Int, name: String)] {
        if t.drums { return DrumMap.rows(DrumMap.machine, c.notes) }
        let key = s.project.key
        let played = c.notes.map(\.pitch).sorted()
        let inst = studio.instrument(t.instrument)
        let centre = played.isEmpty ? (inst?.sweet.map { ($0[0] + $0[1]) / 2 } ?? 60) : played[played.count / 2]
        var pitches = Set((centre - 12)...(centre + 12)).filter { key.contains($0) }
        pitches.formUnion(played)
        return pitches.filter { $0 >= 0 && $0 <= 127 }.sorted(by: >).map { (pitch: $0, name: Theory.noteName($0, in: key)) }
    }

    func cells(_ c: Clip, rows: [(pitch: Int, name: String)], count: Int) -> some View {
        let notes = paint?.notes ?? c.notes
        let step = self.step, p = s.project
        let playing = s.playing ? Int(((s.position - c.start) / step).rounded(.down)) : -1
        return Canvas { g, size in
            for i in 0..<count {
                let song = c.start + Double(i) * step
                let x = CGFloat(i) * cell.width
                let isBar = abs(song / p.beatsPerBar - (song / p.beatsPerBar).rounded()) < 1e-6
                let isBeat = abs(song - song.rounded()) < 1e-6
                if isBeat {
                    g.draw(Text(isBar ? "\(p.bar(of: song) + 1)" : "·").font(.system(size: 11, weight: isBar ? .semibold : .regular))
                            .foregroundColor(Theme.label), at: CGPoint(x: x + 4, y: header / 2), anchor: .leading)
                }
                if isBar { g.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(Theme.rule)) }
                if i == playing {
                    g.fill(Path(CGRect(x: x, y: header, width: cell.width, height: size.height - header)), with: .color(Theme.playhead.opacity(0.12)))
                }
                // A beat's steps are set apart from the next beat's, as a drum machine's are.
                let beatIndex = Int((song + 1e-6).rounded(.down))
                let shade = beatIndex % 2 == 0 ? Theme.sunken : Theme.ground
                for (r, rowInfo) in rows.enumerated() {
                    let rect = CGRect(x: x + 2, y: header + CGFloat(r) * cell.height + 2, width: cell.width - 4, height: cell.height - 4)
                    let a = Double(i) * step
                    let on = notes.first { $0.pitch == rowInfo.pitch && $0.start >= a - 1e-6 && $0.start < a + step - 1e-6 }
                    if let n = on {
                        g.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(n.vel >= 115 ? Theme.controlHover : Theme.note.opacity(n.vel < 70 ? 0.55 : 1)))
                        if n.vel >= 115 {
                            g.fill(Path(CGRect(x: rect.minX + 4, y: rect.maxY - 4, width: rect.width - 8, height: 2)), with: .color(Theme.ink))
                        }
                    } else {
                        g.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(shade))
                    }
                }
            }
        }
        .accessibilityLabel("Steps")
    }

    func changed(_ v: DragGesture.Value, _ c: Clip, _ rows: [(pitch: Int, name: String)], count: Int, track t: Track) {
        let r = Int(((v.location.y - header) / cell.height).rounded(.down))
        let i = Int((v.location.x / cell.width).rounded(.down))
        guard r >= 0, r < rows.count, i >= 0, i < count else { return }
        let pitch = rows[r].pitch
        let key = "\(r):\(i)"
        if paint == nil {
            var notes = c.notes
            let a = Double(i) * step
            if Clicks.modifiers.contains(.option) {
                _ = cycleVelocity(&notes, pitch: pitch, index: i, step: step)
                paint = Paint(adding: false, accent: true, touched: [key], notes: notes)
                return
            }
            let on = notes.contains { $0.pitch == pitch && $0.start >= a - 1e-6 && $0.start < a + step - 1e-6 }
            setCell(&notes, pitch: pitch, index: i, step: step, on: !on)
            if !on { studio.audition(pitch, on: t.id) }
            paint = Paint(adding: !on, accent: false, touched: [key], notes: notes)
            return
        }
        guard var p = paint, !p.accent, !p.touched.contains(key) else { return }
        p.touched.insert(key)
        setCell(&p.notes, pitch: pitch, index: i, step: step, on: p.adding)
        paint = p
    }

    func ended() {
        defer { paint = nil }
        guard let p = paint else { return }
        s.setNotes(p.notes, label: p.accent ? "Change Velocity" : (p.adding ? "Add Steps" : "Clear Steps"))
    }
}
