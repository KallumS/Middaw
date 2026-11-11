import SwiftUI
import AppKit
import MiddawCore
import MiddawEngines
import MiddawAudio
import CoreAudioKit

/// The stage, seen from above with the audience at the bottom: the
/// orchestra in a fan around the conductor, a wedge for every player, and
/// the front, where anything that is not part of an orchestra plays. Click
/// an empty seat to choose what plays it; click a player to edit their part
/// underneath. Where a seat is drawn is where it is heard from
/// (`docs/STAGE.md`); at the front nothing is added.
struct StageView: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var menuSeat: String?

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { g in
                let fan = Fan(size: g.size)
                ZStack(alignment: .topLeading) {
                    ForEach(Stage.seats) { seat in
                        let t = s.project.track(inSeat: seat.id)
                        SeatWedge(seat: seat, fan: fan, track: t, chosen: t.map { isChosen($0.id) } ?? false,
                                  menuOpen: Binding(get: { menuSeat == seat.id }, set: { menuSeat = $0 ? seat.id : nil }))
                    }
                    chosenEdges(fan)
                    podium(fan)
                }
                .frame(width: g.size.width, height: g.size.height)
            }
            .background(Theme.roll)
            .clipped()
            FrontRow()
        }
        .background(Theme.ground)
    }

    func isChosen(_ id: String) -> Bool { s.selection.trackID == id || s.selection.others.contains(id) }

    /// Where the conductor stands: the hall the orchestra plays in is chosen here.
    func podium(_ fan: Fan) -> some View {
        ZStack(alignment: .topLeading) {
            Path { p in
                for k in 0...36 {
                    let pt = fan.point(2.0, -90 + Double(k) * 5)
                    if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
            }
            .fill(Theme.raised)
            .allowsHitTesting(false)
            Menu {
                ForEach(Hall.all) { h in Button(h.name) { s.setHall(h.id) } }
            } label: { Text(Hall.named(s.project.hall).name).font(.system(size: 11, weight: .semibold)) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .position(fan.point(0.8, 0))
            .help("The room the orchestra plays in")
        }
    }

    /// The chosen players' edges, over every wedge's.
    func chosenEdges(_ fan: Fan) -> some View {
        ForEach(Stage.seats.filter { seat in s.project.track(inSeat: seat.id).map { isChosen($0.id) } ?? false }) { seat in
            WedgeShape(seat: seat, fan: fan).stroke(Theme.accent, lineWidth: 2.5).allowsHitTesting(false)
        }
    }
}

/// The fan in points: the conductor at the bottom middle, the outer edge as
/// large as the space allows.
struct Fan {
    let centre: CGPoint
    let scale: CGFloat          // points per metre

    init(size: CGSize) {
        let margin: CGFloat = 6
        let radius = max(40, min(size.width / 2 - margin, size.height - margin * 2))
        scale = radius / CGFloat(Stage.radius)
        centre = CGPoint(x: size.width / 2, y: (size.height + radius) / 2)
    }

    func point(_ metres: Double, _ degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: centre.x + CGFloat(metres * sin(a)) * scale, y: centre.y - CGFloat(metres * cos(a)) * scale)
    }

    func wedge(_ seat: Seat) -> Path {
        var p = Path()
        let steps = max(4, Int((seat.to - seat.from) / 3))
        for k in 0...steps {
            let pt = point(seat.outer, seat.from + (seat.to - seat.from) * Double(k) / Double(steps))
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        for k in 0...steps { p.addLine(to: point(seat.inner, seat.to - (seat.to - seat.from) * Double(k) / Double(steps))) }
        p.closeSubpath()
        return p
    }

    /// The seat's label goes in the middle of its wedge.
    func middle(_ seat: Seat) -> CGPoint { point(seat.radius, seat.angle) }
    /// How much room the label has: the wedge's width at its middle and its depth.
    func room(_ seat: Seat) -> CGSize {
        CGSize(width: CGFloat(seat.radius * (seat.to - seat.from) * .pi / 180) * scale, height: CGFloat(seat.outer - seat.inner) * scale)
    }
}

struct WedgeShape: Shape {
    let seat: Seat
    let fan: Fan
    func path(in rect: CGRect) -> Path { fan.wedge(seat) }
}

/// One seat: its wedge, its short name, empty or played. The chosen player is
/// edged in the accent with a bar under the name (on is the accent and a
/// bar); a player lights up as they play.
struct SeatWedge: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    let seat: Seat
    let fan: Fan
    let track: Track?
    let chosen: Bool
    @Binding var menuOpen: Bool

    var body: some View {
        let shape = WedgeShape(seat: seat, fan: fan)
        let mid = fan.middle(seat), room = fan.room(seat)
        let ring = [StageSection.strings, .brass, .choir].contains(seat.section)
        ZStack(alignment: .topLeading) {
            shape.fill(track != nil ? Theme.rule : (ring ? Theme.raised : Theme.sunken))
            if let t = track { WedgeActivity(trackID: t.id, shape: shape) }
            shape.stroke(Theme.roll, lineWidth: 2)
            VStack(spacing: 1) {
                Text(seat.short)
                    .font(.system(size: 11, weight: track == nil ? .regular : .semibold))
                    .foregroundStyle(track == nil || track!.mute ? Theme.textDim : Theme.text)
                    .strikethrough(track?.mute ?? false)
                if let t = track, room.height > 34, room.width > 70 {
                    Text(soundName(t.sound)).font(.system(size: 10)).foregroundStyle(Theme.textDim)
                }
                if chosen { Capsule().fill(Theme.accent).frame(width: 18, height: 2) }
            }
            .lineLimit(1).minimumScaleFactor(0.6)
            .frame(width: max(24, min(room.width, 140)) - 4)
            .position(mid)
            .allowsHitTesting(false)
        }
        .contentShape(shape)
        .onTapGesture(count: 2) { menuOpen = true }
        .onTapGesture {
            if let t = track { s.select(track: t.id, extending: Clicks.modifiers.contains(.shift)) } else { menuOpen = true }
        }
        .popover(isPresented: $menuOpen, attachmentAnchor: .rect(.rect(CGRect(x: mid.x - 12, y: mid.y - 8, width: 24, height: 16))),
                 arrowEdge: .bottom) {
            SoundMenu(title: seat.name, instrument: seat.instrument, section: seat.section, drums: seat.instrument == "kit",
                      current: track?.sound) { choice in
                menuOpen = false
                s.fill(seat: seat, with: choice)
            }
            .environmentObject(studio)
        }
        .contextMenu {
            if let t = track {
                Button("Change Sound…") { menuOpen = true }
                if t.sound.device == "au" { Button("Show the Plug-in Window") { PluginWindows.shared.show(t.sound.id, title: "\(seat.name) – \(t.sound.plugin?.name ?? "")") } }
                Button(t.mute ? "Unmute" : "Mute") { s.updateTrack(t.id, t.mute ? "Unmute" : "Mute") { $0.mute.toggle() } }
                Button(t.solo ? "Unsolo" : "Solo") { s.updateTrack(t.id, t.solo ? "Unsolo" : "Solo") { $0.solo.toggle() } }
                Divider()
                Button("Move to the Front") { s.place(t.id, seat: nil) }
                Button("Remove the Player") { s.deleteTrack(t.id) }
            } else {
                Button("Choose a Sound…") { menuOpen = true }
            }
        }
        .help(track.map { "\(seat.name): \(soundName($0.sound))" } ?? "\(seat.name): choose a sound")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(track.map { "\(seat.name), \(soundName($0.sound))" } ?? "\(seat.name), empty")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

/// A player's wedge brightening with how loud they are now.
struct WedgeActivity: View {
    @EnvironmentObject var studio: Studio
    let trackID: String
    let shape: WedgeShape
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !studio.isPlaying)) { _ in
            let v = studio.isPlaying ? studio.audio.renderer.peak(of: trackID) : 0
            let db = v > 0 ? 20 * log10(Double(v)) : -60
            shape.fill(Theme.control.opacity(0.28 * max(0, min(1, (db + 48) / 48))))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The front of the stage: synths, drum machines, a band - as many as you
/// like, heard dry and in the middle.
struct FrontRow: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    @State private var adding: Bool?          // true for a drum machine

    var body: some View {
        HStack(spacing: 8) {
            Text("Front").foregroundStyle(Theme.label)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(s.project.tracks.filter { $0.seat == nil }) { t in FrontChip(track: t) }
                }
                .padding(.vertical, 4)
            }
            Button { adding = false } label: { Label("Instrument", systemImage: "plus") }.house(compact: true)
                .help("Add an instrument at the front: a synth, a sampler, any Audio Unit")
                .popover(isPresented: Binding(get: { adding == false }, set: { if !$0 { adding = nil } })) { menu(drums: false) }
            Button { adding = true } label: { Label("Drum Machine", systemImage: "plus") }.house(compact: true)
                .help("Add a drum machine at the front: its notes are drums, on channel 10")
                .popover(isPresented: Binding(get: { adding == true }, set: { if !$0 { adding = nil } })) { menu(drums: true) }
        }
        .padding(.horizontal, 10).frame(height: 46)
        .background(Theme.ground)
        .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    func menu(drums: Bool) -> some View {
        SoundMenu(title: drums ? "A Drum Machine" : "An Instrument", instrument: drums ? "kit" : "synth", section: nil, drums: drums,
                  current: nil) { choice in
            adding = nil
            s.addToFront(choice, drums: drums)
        }
        .environmentObject(studio)
    }
}

struct FrontChip: View {
    @EnvironmentObject var s: Session
    @EnvironmentObject var studio: Studio
    let track: Track
    @State private var menuOpen = false
    var chosen: Bool { s.selection.trackID == track.id || s.selection.others.contains(track.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(track.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(track.mute ? Theme.textDim : Theme.text).lineLimit(1)
            Text(soundName(track.sound)).font(.system(size: 11)).foregroundStyle(Theme.textDim).lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(minWidth: 90, maxWidth: 170, minHeight: 34, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 5).fill(chosen ? Theme.raised : Theme.sunken))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(chosen ? Theme.accent : Theme.edge, lineWidth: chosen ? 2 : 1))
        .overlay(alignment: .bottom) {
            if chosen { Capsule().fill(Theme.accent).frame(width: 40, height: 2).padding(.bottom, 2) }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { menuOpen = true }
        .onTapGesture { s.select(track: track.id, extending: Clicks.modifiers.contains(.shift)) }
        .popover(isPresented: $menuOpen, arrowEdge: .top) {
            SoundMenu(title: track.name, instrument: track.instrument, section: nil, drums: track.drums, current: track.sound) { choice in
                menuOpen = false
                s.setSound(track.id, choice)
            }
            .environmentObject(studio)
        }
        .contextMenu {
            Button("Change Sound…") { menuOpen = true }
            if track.sound.device == "au" { Button("Show the Plug-in Window") { PluginWindows.shared.show(track.sound.id, title: "\(track.name) – \(track.sound.plugin?.name ?? "")") } }
            Button(track.mute ? "Unmute" : "Mute") { s.updateTrack(track.id, track.mute ? "Unmute" : "Mute") { $0.mute.toggle() } }
            Button(track.solo ? "Unsolo" : "Solo") { s.updateTrack(track.id, track.solo ? "Unsolo" : "Solo") { $0.solo.toggle() } }
            let free = Stage.seats.filter { $0.automatic && !s.project.takenSeats.contains($0.id) && $0.instrument == track.instrument }
            if !free.isEmpty {
                Menu("Move to a Seat") { ForEach(free) { seat in Button(seat.name) { s.place(track.id, seat: seat.id) } } }
            }
            Divider()
            Button("Duplicate the Player") { s.duplicateTrack(track.id) }
            Button("Remove the Player") { s.deleteTrack(track.id) }
        }
        .help(track.name)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// What plays a player: a short name for the stage and the part lane.
func soundName(_ d: Device) -> String {
    switch d.device {
    case "kit": return "Drum Kit"
    case "sampler": return "Instant Instrument"
    case "synth": return "Middaw Synth: " + SynthPresetName.name(d.preset)
    case "au": return d.plugin?.name ?? "Audio Unit"
    default: return DeviceCatalog.info(d.device)?.name ?? d.device
    }
}

/// The menu a seat or the front opens: Middaw's own sounds, then every Audio
/// Unit instrument on this Mac by maker, the ones named for the seat's
/// instrument first.
struct SoundMenu: View {
    @EnvironmentObject var studio: Studio
    let title: String
    let instrument: String
    let section: StageSection?
    let drums: Bool
    let current: Device?
    let choose: (SoundChoice) -> Void
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).heading()
            TextField("Search", text: $search).textFieldStyle(.roundedBorder)
            List {
                if !suggested.isEmpty {
                    Section("Suggested") { ForEach(suggested, id: \.self) { r in row(.plugin(r), maker: r.maker) } }
                }
                Section("Middaw") {
                    ForEach(builtIns.filter(matches), id: \.self) { c in row(c, maker: nil) }
                }
                ForEach(makers, id: \.self) { maker in
                    Section(maker) {
                        ForEach(studio.plugins.filter { $0.maker == maker && matches(.plugin($0)) }, id: \.self) { r in row(.plugin(r), maker: nil) }
                    }
                }
                if studio.plugins.isEmpty {
                    Text("No Audio Unit instruments are installed. Install one, then choose Look Again.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textDim)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            HStack {
                Spacer()
                Button("Look Again") { studio.rescanPlugins() }.house(compact: true)
                    .help("Find Audio Units installed since Middaw opened")
            }
        }
        .padding(12)
        .frame(width: 340, height: 440)
        .background(Theme.raised)
    }

    func row(_ c: SoundChoice, maker: String?) -> some View {
        Button { choose(c) } label: {
            HStack {
                Text(c.name).foregroundStyle(Theme.text)
                if let m = maker { Text(m).foregroundStyle(Theme.textDim) }
                Spacer()
                if isCurrent(c) { Image(systemName: "checkmark").foregroundStyle(Theme.accent).accessibilityLabel("Playing now") }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func isCurrent(_ c: SoundChoice) -> Bool {
        guard let d = current else { return false }
        switch c {
        case .synth(let p): return d.device == "synth" && d.preset == p
        case .kit: return d.device == "kit"
        case .sampler: return d.device == "sampler"
        case .jsfx(let id): return d.device == id
        case .plugin(let r): return d.device == "au" && d.plugin == r
        }
    }

    var builtIns: [SoundChoice] {
        if drums { return [.kit, .sampler, .jsfx("shuffler")] }
        let mine = presetFor[instrument] ?? "keys"
        let others = SynthPreset.all.map(\.id).filter { $0 != mine }.map { SoundChoice.synth($0) }
        return [.synth(mine)] + [.jsfx("creator"), .jsfx("reese"), .sampler] + others
    }

    func matches(_ c: SoundChoice) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        var hay = c.name.lowercased()
        if case .plugin(let r) = c { hay += " " + r.maker.lowercased() }
        return q.split(separator: " ").allSatisfy { hay.contains($0) }
    }

    var makers: [String] {
        var seen: [String] = []
        for r in studio.plugins where !seen.contains(r.maker) && matches(.plugin(r)) { seen.append(r.maker) }
        return seen
    }

    /// Audio Units whose name says what the seat is: "Oboe", "Strings",
    /// "Orchestra"; for the front, a drum machine or a synth.
    var suggested: [PluginRef] {
        var words: [String]
        if drums { words = ["drum", "beat", "kit", "machine", "percussion"] }
        else if instrument == "synth" { words = ["synth", "analog", "poly", "keys"] }
        else {
            let name = (studio.instrument(instrument)?.name ?? instrument).lowercased()
            words = name.split(separator: " ").map(String.init).filter { $0.count > 2 }
            switch section {
            case .strings?: words += ["string", "violin", "viola", "cello"]
            case .woodwinds?: words += ["woodwind", "wind"]
            case .brass?: words += ["brass"]
            case .percussion?: words += ["percussion", "mallet"]
            case .choir?: words += ["choir", "voice", "vocal"]
            case .keys?: words += [name]
            case nil: break
            }
            words += ["orchestra", "symphon"]
        }
        return studio.plugins.filter { r in
            let hay = r.name.lowercased()
            return words.contains { hay.contains($0) } && matches(.plugin(r))
        }
    }
}

/// A plug-in's own window, as its maker drew it.
@MainActor
final class PluginWindows {
    static let shared = PluginWindows()
    private var windows: [String: NSWindow] = [:]

    func show(_ deviceID: String, title: String) {
        if let w = windows[deviceID] { w.title = title; w.makeKeyAndOrderFront(nil); return }
        guard let inst = Studio.shared.audio.plugins.instance(id: deviceID) else {
            Studio.shared.active?.say("The plug-in is still opening. Try again in a moment.")
            return
        }
        let name = inst.ref.name
        inst.unit.requestViewController { vc in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let vc else { Studio.shared.active?.say("\(name) has no window of its own."); return }
                    let w = NSWindow(contentViewController: vc)
                    w.title = title
                    w.styleMask = [.titled, .closable, .miniaturizable]
                    w.isReleasedWhenClosed = false
                    if vc.preferredContentSize.width > 0 { w.setContentSize(vc.preferredContentSize) }
                    PluginWindows.shared.windows[deviceID] = w
                    w.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}
