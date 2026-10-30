import Foundation
import CJSFX
import MiddawCore
#if canImport(os)
import os
#endif

/// Where a device sits in a track's chain: MIDI effects, then the
/// instrument, then audio effects, as Bitwig and Ableton order them.
public enum DeviceRole: String { case midi, instrument, audio }

/// One of the family's JSFX as Middaw shows it. Its controls are its own
/// sliders, grouped so the ones you reach for come first - the browser
/// version's grouping (`docs/BROWSER-DAW.md`).
public struct DeviceInfo {
    /// The name a song file uses: "evolver".
    public let id: String
    /// The compiled device in CJSFX: "midi_evolver".
    public let code: String
    public let name: String
    public let role: DeviceRole
    public let main: [Int]
    public let groups: [(name: String, sliders: [Int])]
    public let more: [Int]
    /// Sounds it takes (Transient Shuffler's A and B).
    public let sounds: Int
}

/// A slider as the device's header declares it.
public struct SliderInfo: Identifiable, Hashable {
    public let index: Int
    public let name: String
    public let def: Double, min: Double, max: Double, step: Double
    public let choices: [String]
    /// 0 linear, 1 log, 2 squared, as the header's :log / :sqr.
    public let shape: Int
    public let shapeValue: Double
    public var id: Int { index }
}

public enum DeviceCatalog {
    public static let all: [DeviceInfo] = [
        DeviceInfo(id: "creator", code: "instrument_creator", name: "Instrument Creator", role: .instrument,
                   main: [13, 14, 15, 16, 17, 18, 23], groups: [("Parts", Array(1...12))], more: [19, 20, 21, 22], sounds: 0),
        DeviceInfo(id: "shuffler", code: "transient_shuffler", name: "Transient Shuffler", role: .instrument,
                   main: [7, 1, 2, 3], groups: [], more: [4, 5, 6, 8, 9, 10], sounds: 2),
        DeviceInfo(id: "autocc", code: "autocc", name: "AutoCC", role: .midi,
                   main: [1, 2, 3, 18], groups: [("Lanes", [11, 12, 13, 14, 15, 16, 17])], more: [4, 5, 6, 7, 8, 9, 10, 19], sounds: 0),
        DeviceInfo(id: "evolver", code: "midi_evolver", name: "Midi Evolver", role: .midi,
                   main: [1, 2, 3, 4, 5, 8], groups: [("Layers", [9, 10, 11, 12, 13])],
                   more: [6, 7, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 14, 15, 16, 17, 18, 29, 30, 31, 32], sounds: 0),
        DeviceInfo(id: "mpc", code: "midi_production_center", name: "MIDI Production Center", role: .midi,
                   main: [1, 2, 3, 4, 5],
                   groups: [("Filter", [12, 13, 14, 15, 16, 17]), ("EQ", [18, 19, 20, 21, 22, 23, 24, 25]),
                            ("Compressor", [26, 27, 28, 29, 30]), ("Delay", [31, 32, 33, 34, 35, 36]),
                            ("Stutter", [37, 38, 39, 40, 41, 42, 43]), ("Pitch Correct", [44, 45, 46, 47])],
                   more: [6, 7, 8, 9, 10, 11], sounds: 0),
        DeviceInfo(id: "reverberator", code: "reverberator", name: "Reverberator", role: .audio,
                   main: [1, 2, 3, 4, 5, 8], groups: [], more: [6, 7, 9, 10, 11, 12], sounds: 0),
    ]

    public static func info(_ id: String) -> DeviceInfo? { all.first { $0.id == id } }
    public static func of(_ role: DeviceRole) -> [DeviceInfo] { all.filter { $0.role == role } }

    static func desc(_ code: String) -> UnsafePointer<jsfx_desc>? { code.withCString { jsfx_find($0) } }

    /// Every slider the device declares, in order.
    public static func sliders(_ id: String) -> [SliderInfo] {
        guard let info = info(id), let d = desc(info.code) else { return [] }
        var out: [SliderInfo] = []
        for i in 0..<Int(d.pointee.nsliders) {
            let s = d.pointee.sliders[i]
            var choices: [String] = []
            if s.nnames > 0, let names = s.names {
                for k in 0..<Int(s.nnames) { choices.append(names[k].map { String(cString: $0) } ?? "") }
            }
            out.append(SliderInfo(index: Int(s.index), name: s.name.map { String(cString: $0) } ?? "Slider \(s.index)",
                                  def: s.def, min: s.min, max: s.max, step: s.step, choices: choices,
                                  shape: Int(s.shape), shapeValue: s.shapeValue))
        }
        return out
    }
    public static func slider(_ id: String, _ n: Int) -> SliderInfo? { sliders(id).first { $0.index == n } }

    /// Instrument Creator's nineteen instruments, read from its own table.
    public static func creatorPresets(source: String) -> [(name: String, values: [Double])] {
        func matches(_ pattern: String, _ text: String, _ opts: NSRegularExpression.Options = []) -> [[String]] {
            guard let re = try? NSRegularExpression(pattern: pattern, options: opts) else { return [] }
            let ns = text as NSString
            return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
                (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
            }
        }
        guard let at = source.range(of: "function preset_name") else { return [] }
        let rest = source[at.lowerBound...]
        guard let end = rest.range(of: ");") else { return [] }
        let body = String(rest[..<end.lowerBound])
        var names: [Int: String] = [:]
        for m in matches(#"k==(\d+)\?"([^"]+)""#, body) { if let k = Int(m[1]) { names[k] = m[2] } }
        var list = (0..<(names.keys.max().map { $0 + 1 } ?? 0)).map { names[$0] ?? "" }
        if let last = matches(#":"([^"]+)";\s*$"#, body).first { list.append(last[1]) }
        var rows: [Int: [Double]] = [:]
        for m in matches(#"^pdef\(\s*(\d+),([^)]*)\);"#, source, [.anchorsMatchLines]) {
            if let k = Int(m[1]) { rows[k] = m[2].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } }
        }
        return list.enumerated().map { (name: $1, values: rows[$0] ?? []) }
    }
}

/// One of the family's JSFX, live on a track: the compiled C running its own
/// @init, @slider, @block, @sample and @serialize.
///
/// The audio thread only ever *tries* the device's lock. The main thread holds
/// it to load a sound, save the state or read what the device has played,
/// and while it does the audio thread lets the device's block go by.
public final class JSFXDevice {
    public let modelID: String
    public let info: DeviceInfo
    public let signature: String
    let inst: OpaquePointer
    let lock: UnsafeMutablePointer<os_unfair_lock_s>
    let sampleRate: Double
    private var applied: [Int: Double] = [:]

    /// A string slot no device uses, for handing a name to a function.
    static let handoff = 900000.0

    public init?(_ d: Device, sampleRate: Double) {
        guard let info = DeviceCatalog.info(d.device), let desc = DeviceCatalog.desc(info.code),
              let inst = jsfx_new(desc, sampleRate) else { return nil }
        self.modelID = d.id; self.info = info; self.inst = inst; self.sampleRate = sampleRate
        signature = JSFXDevice.signature(d)
        lock = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock_s())
        for (k, v) in d.sliders { jsfx_set_slider(inst, Int32(k), v) }
        applied = d.sliders
        // The sounds first: a saved state names them.
        let names = JSFXDevice.addSounds(d, inst)
        jsfx_init(inst, sampleRate)
        if let st = d.state { JSFXDevice.restore(st, inst, desc) }
        for (slot, name) in names.enumerated() where !name.isEmpty {
            jsfx_set_string(inst, JSFXDevice.handoff, name)
            JSFXDevice.call(inst, "replace_slot", [Double(slot), JSFXDevice.handoff])
        }
        if names.contains(where: { !$0.isEmpty }) { JSFXDevice.call(inst, "recompute", []) }
    }

    deinit {
        jsfx_free(inst)
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    /// What decides whether a device can be kept as it is: which device, and
    /// which sounds it holds. Sliders change in place.
    public static func signature(_ d: Device) -> String {
        var s = d.device
        for x in d.samples ?? [] { s += "|" + (x.map { "\($0.name):\($0.data.count)" } ?? "-") }
        return s
    }

    // ------------------------------------------------------ main thread --
    @discardableResult
    func locked<T>(_ body: (OpaquePointer) -> T) -> T {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return body(inst)
    }

    /// The song's slider values, where they have moved.
    func sync(_ d: Device) {
        let changed = d.sliders.filter { applied[$0.key] != $0.value }
        guard !changed.isEmpty else { return }
        locked { i in for (k, v) in changed { jsfx_set_slider(i, Int32(k), v) } }
        for (k, v) in changed { applied[k] = v }
    }

    public func setSlider(_ n: Int, _ value: Double) {
        locked { jsfx_set_slider($0, Int32(n), value) }
        applied[n] = value
    }
    public func slider(_ n: Int) -> Double { locked { jsfx_get_slider($0, Int32(n)) } }
    public func variable(_ name: String) -> Double { locked { i in name.withCString { jsfx_get_var(i, $0) } } }
    public func setVariable(_ name: String, _ value: Double) { locked { i in name.withCString { jsfx_set_var(i, $0, value) } } }
    public func memory(_ addr: Int, _ count: Int) -> [Double] {
        locked { i in (0..<max(0, count)).map { jsfx_mem(i, Double(addr + $0)) } }
    }
    /// What a REAPER script would write into the device's shared memory.
    public func writeShared(_ writes: [(Int, Double)]) {
        locked { i in
            guard let g = jsfx_gmem(i) else { return }
            for (a, v) in writes where a >= 0 && a < 8 * 1024 * 1024 { g[a] = v }
        }
    }
    @discardableResult
    public func call(_ name: String, _ args: [Double] = []) -> Double? { locked { JSFXDevice.call($0, name, args) } }

    /// The device's @serialize, as the browser version saved it:
    /// {"sliders": [...], "data": [numbers and {"s": text}]}.
    public func state() -> JSONValue {
        locked { i in
            var items: UnsafeMutablePointer<jsfx_serial_item>? = nil
            let n = Int(jsfx_serialize(i, &items))
            var data: [JSONValue] = []
            if let it = items {
                for k in 0..<n {
                    if it[k].isString != 0 { data.append(.object(["s": .string(it[k].string.map { String(cString: $0) } ?? "")])) }
                    else { data.append(.number(it[k].value)) }
                }
            }
            jsfx_free_items(items, Int32(n))
            let sliders = DeviceCatalog.sliders(info.id).map { JSONValue.number(jsfx_get_slider(i, Int32($0.index))) }
            return .object(["sliders": .array(sliders), "data": .array(data)])
        }
    }

    static func restore(_ st: JSONValue, _ inst: OpaquePointer, _ desc: UnsafePointer<jsfx_desc>) {
        guard case .object(let o) = st else { return }
        if case .array(let sl)? = o["sliders"] {
            for (k, v) in sl.enumerated() where k < Int(desc.pointee.nsliders) {
                if case .number(let x) = v { jsfx_set_slider(inst, desc.pointee.sliders[k].index, x) }
            }
        }
        guard case .array(let data)? = o["data"] else { return }
        let items = UnsafeMutablePointer<jsfx_serial_item>.allocate(capacity: max(1, data.count))
        defer { items.deallocate() }
        var strings: [UnsafeMutablePointer<CChar>] = []
        for (k, v) in data.enumerated() {
            switch v {
            case .number(let x): items[k] = jsfx_serial_item(isString: 0, value: x, string: nil)
            case .object(let s):
                if case .string(let text)? = s["s"], let c = strdup(text) {
                    strings.append(c); items[k] = jsfx_serial_item(isString: 1, value: 0, string: c)
                } else { items[k] = jsfx_serial_item(isString: 0, value: 0, string: nil) }
            default: items[k] = jsfx_serial_item(isString: 0, value: 0, string: nil)
            }
        }
        jsfx_deserialize(inst, items, Int32(data.count))
        for c in strings { free(c) }
    }

    /// The device's sounds as files it opens by name. Returns the names.
    static func addSounds(_ d: Device, _ inst: OpaquePointer) -> [String] {
        var names: [String] = []
        for (slot, s) in (d.samples ?? []).enumerated() {
            guard let s = s, let pcm = SampleCodec.decode(s) else { names.append(""); continue }
            let name = "slot\(slot)-" + s.name.replacingOccurrences(of: "\"", with: "")
            let ch = pcm.right == nil ? 1 : 2, frames = pcm.left.count
            var inter = [Float](repeating: 0, count: frames * ch)
            for i in 0..<frames { inter[i * ch] = pcm.left[i]; if let r = pcm.right { inter[i * ch + 1] = r[i] } }
            inter.withUnsafeBufferPointer { b in name.withCString { jsfx_add_file(inst, $0, b.baseAddress, Int64(frames), Int32(ch), s.rate) } }
            names.append(name)
        }
        return names
    }

    @discardableResult
    static func call(_ inst: OpaquePointer, _ name: String, _ args: [Double]) -> Double? {
        var result = 0.0
        let ok = name.withCString { n in args.withUnsafeBufferPointer { jsfx_call(inst, n, $0.baseAddress, Int32(args.count), &result) } }
        return ok != 0 ? result : nil
    }

    // ----------------------------------------------------- audio thread --
    /// One block. Returns how many MIDI events it sent (in `midiOut`), or -1
    /// when the main thread has the device and the block went by without it.
    @inline(__always)
    func process(_ n: Int, _ ins: UnsafePointer<UnsafePointer<Float>?>?, _ nin: Int,
                 _ outs: UnsafePointer<UnsafeMutablePointer<Float>?>?, _ nout: Int,
                 _ midi: UnsafePointer<jsfx_midi>?, _ count: Int, _ time: DeviceTime) -> Int {
        guard os_unfair_lock_trylock(lock) else { return -1 }
        defer { os_unfair_lock_unlock(lock) }
        jsfx_set_time(inst, time.tempo, time.playing ? 1 : 0, time.beat, time.beat * 60 / time.tempo, time.num, time.den)
        return Int(jsfx_process(inst, Int32(n), ins, Int32(nin), outs, Int32(nout), midi, Int32(count)))
    }
    var midiOut: UnsafePointer<jsfx_midi> { jsfx_midi_out(inst) }
}

/// The transport as a device sees it.
struct DeviceTime {
    var tempo: Double, playing: Bool, beat: Double, num: Double, den: Double
}
