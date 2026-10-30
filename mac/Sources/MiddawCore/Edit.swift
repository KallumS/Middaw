import Foundation

// What can be done to the song. Each is a plain change to a value; the
// document wraps it in an undo step.

extension Track {
    /// Clear `start..<end`, keeping what was either side of it (clips are cut).
    public mutating func clear(from s: Double, to e: Double) {
        var keep: [Clip] = []
        for c in clips {
            let cs = c.start, ce = c.end
            if ce <= s + 1e-9 || cs >= e - 1e-9 { keep.append(c); continue }
            if cs < s - 1e-9 {
                var left = c
                left.id = makeID("c")
                left.length = s - cs
                left.notes = left.notes.filter { $0.start < left.length - 1e-9 }
                for i in left.notes.indices { left.notes[i].len = min(left.notes[i].len, left.length - left.notes[i].start) }
                left.cc = left.cc.mapValues { $0.filter { $0.beat <= left.length } }
                keep.append(left)
            }
            if ce > e + 1e-9 {
                var right = c
                right.id = makeID("c")
                let off = e - cs
                right.start = e
                right.length = ce - e
                right.notes = right.notes.filter { $0.start >= off - 1e-9 }.map { var n = $0; n.start -= off; return n }
                right.cc = right.cc.mapValues { $0.filter { $0.beat >= off }.map { CCPoint(beat: $0.beat - off, value: $0.value) } }
                keep.append(right)
            }
        }
        clips = keep.sorted { $0.start < $1.start }
    }

    /// Split the clip at `at`; returns the new right-hand clip's id.
    @discardableResult
    public mutating func split(clipID: String, at: Double) -> String? {
        guard let i = clips.firstIndex(where: { $0.id == clipID }) else { return nil }
        let clip = clips[i]
        guard at > clip.start + 1e-9, at < clip.end - 1e-9 else { return nil }
        let off = at - clip.start
        var right = clip
        right.id = makeID("c")
        right.start = at
        right.length = clip.length - off
        right.notes = clip.notes.filter { $0.start >= off - 1e-9 }.map { var n = $0; n.start -= off; return n }
        right.cc = clip.cc.mapValues { $0.filter { $0.beat >= off }.map { CCPoint(beat: $0.beat - off, value: $0.value) } }
        clips[i].length = off
        clips[i].notes = clip.notes.filter { $0.start < off - 1e-9 }.map { var n = $0; n.len = min(n.len, off - n.start); return n }
        clips[i].cc = clip.cc.mapValues { $0.filter { $0.beat <= off } }
        clips.append(right)
        clips.sort { $0.start < $1.start }
        return right.id
    }

    /// A copy of the clip straight after it; returns the copy's id.
    @discardableResult
    public mutating func duplicate(clipID: String) -> String? {
        guard let c = clips.first(where: { $0.id == clipID }) else { return nil }
        var copy = c
        copy.id = makeID("c")
        copy.start = c.end
        clear(from: copy.start, to: copy.end)
        clips.append(copy)
        clips.sort { $0.start < $1.start }
        return copy.id
    }
}

extension Project {
    /// Notes into a new clip on a track, clearing what was under it. Notes are
    /// cut at the clip's end. Returns the clip's id.
    @discardableResult
    public mutating func place(_ notes: [Note], on trackID: String, at start: Double, length: Double,
                               name: String = "", source: ClipSource? = nil, cc: [Int: [CCPoint]] = [:]) -> String? {
        guard let t = trackIndex(trackID) else { return nil }
        tracks[t].clear(from: start, to: start + length)
        let kept = notes.filter { $0.start < length - 1e-9 }.map { n -> Note in
            var x = n
            x.len = max(1.0 / 64, min(n.len, length - n.start))
            return x
        }
        let clip = Clip(name: name, start: start, length: length, notes: kept, cc: cc, source: source)
        tracks[t].clips.append(clip)
        tracks[t].clips.sort { $0.start < $1.start }
        return clip.id
    }

    /// Notes moved to the grid, counted from each bar line.
    public func quantized(_ notes: [Note], grid: Double, strength: Double = 1, offset: Double = 0) -> [Note] {
        notes.map { n in
            var x = n
            let target = snap(n.start + offset, grid: grid) - offset
            x.start = max(0, n.start + (target - n.start) * strength)
            return x
        }
    }
}

/// Midi Catalogue's "Shape It" and the usual DAW transforms, on clip notes.
public enum Transform {
    public static func transpose(_ notes: inout [Note], by: Int) {
        for i in notes.indices { notes[i].pitch = max(0, min(127, notes[i].pitch + by)) }
    }

    /// Mirrored inside the key, step for step, when the notes are all in it -
    /// a chromatic mirror of a tune in C major lands half of it outside C major.
    public static func invert(_ notes: inout [Note], key: Key?) {
        guard !notes.isEmpty else { return }
        if let key = key, notes.allSatisfy({ key.contains($0.pitch) }) {
            let iv = key.intervals, n = iv.count, tonic = key.tonic
            func degree(_ p: Int) -> Int {
                let rel = p - tonic
                let oct = Int((Double(rel) / 12).rounded(.down))
                return oct * n + (iv.firstIndex(of: rel - oct * 12) ?? 0)
            }
            func pitch(_ d: Int) -> Int {
                let oct = Int((Double(d) / Double(n)).rounded(.down))
                return tonic + oct * 12 + iv[d - oct * n]
            }
            let ds = notes.map { degree($0.pitch) }
            let axis = ds.max()! + ds.min()!
            for i in notes.indices { notes[i].pitch = max(0, min(127, pitch(axis - ds[i]))) }
            return
        }
        let hi = notes.map(\.pitch).max()!, lo = notes.map(\.pitch).min()!
        for i in notes.indices { notes[i].pitch = hi + lo - notes[i].pitch }
    }

    /// Played backwards: the rhythm mirrored too.
    public static func retrograde(_ notes: inout [Note], length: Double) {
        for i in notes.indices { notes[i].start = max(0, length - notes[i].start - notes[i].len) }
        notes.sort { $0.start != $1.start ? $0.start < $1.start : $0.pitch < $1.pitch }
    }

    public static func scaleTime(_ notes: inout [Note], by factor: Double) {
        for i in notes.indices { notes[i].start *= factor; notes[i].len *= factor }
    }

    /// Notes outside the key moved to the nearest note that is in it.
    public static func fitToKey(_ notes: inout [Note], key: Key) {
        let pcs = key.pitchClasses
        for i in notes.indices where !pcs[mod12(notes[i].pitch)] {
            for d in 1..<6 {
                if pcs[mod12(notes[i].pitch - d)] { notes[i].pitch -= d; break }
                if pcs[mod12(notes[i].pitch + d)] { notes[i].pitch += d; break }
            }
        }
    }
}

/// The song's undo history: every change is one named step.
public struct History {
    public private(set) var project: Project
    private var past: [(label: String, project: Project)] = []
    private var future: [(label: String, project: Project)] = []
    public static let depth = 200

    public init(_ project: Project) { self.project = project }

    /// Apply `change` as one step, unless it returns false: then it is not a step.
    @discardableResult
    public mutating func commitIf(_ label: String, _ change: (inout Project) -> Bool) -> Bool {
        var next = project
        guard change(&next) else { return false }
        past.append((label, project))
        if past.count > History.depth { past.removeFirst() }
        future.removeAll()
        project = next
        return true
    }

    public mutating func commit(_ label: String, _ change: (inout Project) -> Void) {
        commitIf(label) { (p: inout Project) -> Bool in change(&p); return true }
    }

    @discardableResult
    public mutating func undo() -> String? {
        guard let step = past.popLast() else { return nil }
        future.append((step.label, project))
        project = step.project
        return step.label
    }

    @discardableResult
    public mutating func redo() -> String? {
        guard let step = future.popLast() else { return nil }
        past.append((step.label, project))
        project = step.project
        return step.label
    }

    public mutating func replace(with p: Project) { project = p; past.removeAll(); future.removeAll() }

    public var undoLabel: String? { past.last?.label }
    public var redoLabel: String? { future.last?.label }
}
