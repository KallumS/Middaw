import SwiftUI
import AppKit
import MiddawCore
import MiddawEngines

// ------------------------------------------------------------ battle pass --
/// DAW Battle Pass, unchanged (bp_game.lua), fed by what you do in Middaw:
/// active minutes fill the tier; edits, tracks, notes and ideas earn XP.
/// Progress belongs to you, not to a song: it is kept in Application Support.
@MainActor
final class Pass: ObservableObject {
    static let shared = Pass()
    @Published var tier = 0
    @Published var tierFraction = 0.0
    @Published var level = 1
    @Published var xp = 0
    @Published var coins = 0
    @Published var news = false
    @Published var lastNotice = ""
    private var started = false
    private var lastInput = Date.distantPast
    private var dirty = false
    private let clockStart = Date()
    static let tierSeconds = 900.0

    var file: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Middaw")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("battlepass.txt")
    }

    var clock: Double { Date().timeIntervalSince(clockStart) }
    var epoch: Int { Int(Date().timeIntervalSince1970) }

    struct StartArgs: Encodable { let epoch: Int; let clock: Double; let saved: String? }
    struct CallArgs: Encodable { let fn: String; let args: [Arg] }
    enum Arg: Encodable {
        case s(String), n(Double), b(Bool), o([String: Arg])
        func encode(to e: Encoder) throws {
            var c = e.singleValueContainer()
            switch self {
            case .s(let v): try c.encode(v)
            case .n(let v): try c.encode(v)
            case .b(let v): try c.encode(v)
            case .o(let v): try c.encode(v)
            }
        }
    }

    func start() {
        guard !started, let e = Studio.shared.engines else { return }
        started = true
        let saved = try? String(contentsOf: file, encoding: .isoLatin1)
        _ = try? e.callAny("passStart", StartArgs(epoch: epoch, clock: clock, saved: saved))
        read()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in Task { @MainActor in Pass.shared.tick() } }
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in Task { @MainActor in Pass.shared.save() } }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in Pass.shared.save(force: true) }
        }
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown, .scrollWheel]) { ev in
            Task { @MainActor in Pass.shared.input() }
            return ev
        }
    }

    func input() { lastInput = Date() }

    func call(_ fn: String, _ args: [Arg]) {
        guard let e = Studio.shared.engines, started else { return }
        _ = try? e.callAny("passCall", CallArgs(fn: fn, args: args))
    }

    func tick() {
        guard started else { return }
        let s = Studio.shared
        let signals: [String: Arg] = [
            "input": .b(Date().timeIntervalSince(lastInput) < 1.5),
            "playing": .b(s.isPlaying),
            "recording": .b(s.active?.recording ?? false),
            "project": .s(s.active?.project.title ?? "Untitled"),
        ]
        call("tick", [.s("$state"), .s("$session"), .n(clock), .n(Double(epoch)), .o(signals)])
        call("refresh", [.s("$state"), .s("$session"), .n(Double(epoch)), .o([:])])
        call("checkAchievements", [.s("$state"), .s("$session")])
        dirty = true
        read()
        drain()
    }

    /// Something happened: edit, track, notes, take, idea, fx.
    func event(_ kind: String, _ n: Int = 1) {
        guard started else { return }
        input()
        call("event", [.s("$state"), .s("$session"), .s(kind), .n(Double(n))])
        dirty = true
        drain()
    }

    func read() {
        guard let e = Studio.shared.engines else { return }
        func get(_ path: String) -> Double { (try? e.callAny("passGet", ["path": path]) as? Double) ?? 0 }
        tier = Int(get("pass.tier"))
        tierFraction = min(1, get("pass.secs") / Pass.tierSeconds)
        level = max(1, Int(get("level")))
        xp = Int(get("xp"))
        coins = Int(get("coins"))
    }

    /// What the game wants celebrated: marked on its button, said in the
    /// status line only when that is free.
    func drain() {
        guard let e = Studio.shared.engines, let list = try? e.callAny("passNotices", [String: Int]()) as? [[String: Any]], !list.isEmpty else { return }
        var said: String?
        for n in list {
            switch n["kind"] as? String {
            case "tier": said = "Battle Pass: tier \(tier) unlocked."
            case "level": said = "Level \(level) - a crate is waiting."
            case "quest": said = "Quest done: \((n["text"] as? String) ?? (n["name"] as? String) ?? "")."
            case "season": said = "A new season of the Battle Pass has started."
            default: break
            }
        }
        if let s = said {
            news = true
            lastNotice = s
            if let a = Studio.shared.active, a.status.isEmpty { a.say(s) }
        }
    }

    func save(force: Bool = false) {
        guard started, dirty || force, let e = Studio.shared.engines,
              let text = try? e.callAny("passSave", [String: Int]()) as? String else { return }
        try? text.write(to: file, atomically: true, encoding: .isoLatin1)
        dirty = false
    }
}

struct PassButton: View {
    @ObservedObject var pass = Pass.shared
    @EnvironmentObject var studio: Studio
    @State private var open = false
    var body: some View {
        Button { open.toggle(); pass.news = false } label: {
            HStack(spacing: 5) {
                ZStack {
                    Circle().stroke(Theme.rule, lineWidth: 3)
                    Circle().trim(from: 0, to: pass.tierFraction).stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if pass.news { Circle().fill(Theme.accent).frame(width: 6, height: 6).offset(x: 7, y: -7) }
                }
                .frame(width: 16, height: 16)
                Text("Tier \(pass.tier)")
            }
        }
        .help("Battle Pass")
        .popover(isPresented: $open) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Battle Pass").heading()
                Text("Tier \(pass.tier): \(Int(((1 - pass.tierFraction) * Pass.tierSeconds / 60).rounded(.up))) active minutes to the next.")
                    .foregroundStyle(Theme.text)
                ProgressView(value: pass.tierFraction).tint(Theme.accent)
                Text("Level \(pass.level), \(pass.xp) XP, \(pass.coins) coins.").foregroundStyle(Theme.textDim)
                if !pass.lastNotice.isEmpty { Text(pass.lastNotice).foregroundStyle(Theme.text) }
            }
            .padding(14).frame(width: 300)
        }
        .onChange(of: studio.engines != nil) { _, ready in if ready { pass.start() } }
        .onAppear { pass.start() }
    }
}

// ----------------------------------------------------------------- score --
/// The same notes, engraved by Starting Blocks Notation (sb_notate.lua,
/// sb_draw.lua, sb_glyphs.lua, unchanged): this view is only the pen.
struct ScoreView: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var full = false
    @State private var light = false
    @State private var pages: [(name: String, engraving: Engines.Engraving?)] = []
    @State private var key = 0
    let space: Double = 8

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Toggle("Full Score", isOn: $full).toggleStyle(.button)
                Toggle("Light Page", isOn: $light).toggleStyle(.button)
                Spacer()
            }
            .padding(.horizontal, 10).frame(height: 34)
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { _, page in
                            Text(page.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(light ? Theme.ink : Theme.text)
                            if let e = page.engraving {
                                Canvas { g, _ in draw(e, g) }.frame(height: e.height + 10)
                            } else {
                                Text("This part could not be engraved.").foregroundStyle(Theme.warnText)
                            }
                        }
                        if pages.isEmpty { Text("Choose a track to see its part.").foregroundStyle(Theme.textDim) }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(light ? Theme.playhead : Theme.roll)
                .onAppear { engrave(width: geo.size.width) }
                .onChange(of: geo.size.width) { _, w in engrave(width: w) }
                .onChange(of: s.project) { _, _ in engrave(width: geo.size.width) }
                .onChange(of: s.selection.trackID) { _, _ in engrave(width: geo.size.width) }
                .onChange(of: full) { _, _ in engrave(width: geo.size.width) }
                .onChange(of: studio.engines != nil) { _, _ in engrave(width: geo.size.width) }
            }
        }
    }

    /// Played and humanised onsets put back on the grid they were meant on:
    /// a sixteenth unless a triplet fits clearly better. The page writes each
    /// note up to the next onset, so a few ms of feel would print as 32nds.
    static func written(_ list: [Note]) -> [Note] {
        var seen = Set<String>(), out: [Note] = []
        for n in list {
            let q4 = (n.start * 4).rounded() / 4, q3 = (n.start * 3).rounded() / 3
            let at = abs(n.start - q4) <= abs(n.start - q3) + 0.04 ? q4 : q3
            let k = "\(Int((at * 960).rounded())):\(n.pitch)"
            if seen.contains(k) { continue }
            seen.insert(k)
            out.append(Note(start: at, len: max(0.25, n.len), pitch: n.pitch, vel: n.vel))
        }
        return out
    }

    func engrave(width: CGFloat) {
        guard let e = studio.engines else { return }
        let p = s.project
        let tracks = full ? p.tracks : (s.track.map { [$0] } ?? [])
        let bpb = p.beatsPerBar
        let end = max(bpb, (p.endOfMusic / bpb).rounded(.up) * bpb)
        let w = Double(max(200, width - 40)) / space
        key += 1
        let mine = key
        let jobs = tracks.map { (name: $0.name, notes: ScoreView.written($0.notes), drums: $0.drums) }
        let sp = space
        Task.detached(priority: .userInitiated) {
            let done = jobs.map { j in (name: j.name, engraving: try? e.engrave(notes: j.notes, beats: end, project: p, drums: j.drums, width: w, space: sp)) }
            await MainActor.run { if mine == key { pages = done } }
        }
    }

    func colour(_ id: Double) -> Color {
        switch Int(id) {
        case 1: return light ? Theme.ink : Theme.text
        case 2: return light ? Theme.rule : Theme.hex(0x8A919C)
        case 3: return light ? Theme.playhead : Theme.roll
        case 4: return light ? Theme.hex(0xB0A800) : Theme.accent
        default: return light ? Theme.ink : Theme.text
        }
    }

    func draw(_ e: Engines.Engraving, _ g: GraphicsContext) {
        for op in e.ops {
            guard let kind = op.first?.text as String? else { continue }
            func n(_ i: Int) -> Double { i < op.count ? op[i].number : 0 }
            switch kind {
            case "line":
                var path = Path()
                path.move(to: CGPoint(x: n(1), y: n(2))); path.addLine(to: CGPoint(x: n(3), y: n(4)))
                g.stroke(path, with: .color(colour(n(5))), lineWidth: max(0.5, n(6)))
            case "poly":
                let pts = op.count > 1 ? op[1].list : []
                guard pts.count >= 6 else { continue }
                var path = Path()
                path.move(to: CGPoint(x: pts[0], y: pts[1]))
                var i = 2
                while i + 1 < pts.count { path.addLine(to: CGPoint(x: pts[i], y: pts[i + 1])); i += 2 }
                path.closeSubpath()
                g.fill(path, with: .color(colour(op.count > 2 ? op[2].number : 1)))
            case "circle":
                let r = max(0.5, n(3))
                let rect = CGRect(x: n(1) - r, y: n(2) - r, width: r * 2, height: r * 2)
                let filled = op.count > 5 ? op[5].flag : false
                if filled { g.fill(Path(ellipseIn: rect), with: .color(colour(n(4)))) }
                else { g.stroke(Path(ellipseIn: rect), with: .color(colour(n(4))), lineWidth: max(1, r * 0.4)) }
            case "text":
                let str = op.count > 4 ? op[4].text : ""
                let centred = op.count > 6 ? op[6].flag : false
                g.draw(Text(str).font(.system(size: max(8, n(5)), weight: .semibold)).foregroundColor(colour(n(3))),
                       at: CGPoint(x: n(1), y: n(2)), anchor: centred ? .center : .leading)
            default: break
            }
        }
    }
}
