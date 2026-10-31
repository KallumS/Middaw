import Foundation
import JavaScriptCore
import MiddawCore

/// The family's Lua engines, unchanged, running in JavaScriptCore through
/// Middaw's own Lua 5.4 (`runtime/lua/`) and `runtime/host.js`.
///
/// Not thread-safe by itself: every call goes through one serial queue, so
/// call it from anywhere, but expect a generate to take a moment.
public final class Engines {
    public struct Failure: Error, CustomStringConvertible {
        public let description: String
        public init(description: String) { self.description = description }
    }

    public struct Generator: Decodable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let description: String
        public let input: String?
    }

    public struct Setting: Decodable, Hashable, Identifiable {
        public let id: String
        public let label: String
        public let names: [String]
        /// 1-based, as the adapters count.
        public let index: Int
        public let hint: String?
        public let group: String?
    }

    public struct Part: Decodable, Hashable {
        public let name: String
        public let drums: Bool
        public let notes: [Note]
        enum CodingKeys: String, CodingKey { case name, drums, notes }
        public init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            name = (try? c.decode(String.self, forKey: .name)) ?? ""
            drums = (try? c.decode(Bool.self, forKey: .drums)) ?? false
            notes = (try? c.decode([Note].self, forKey: .notes)) ?? []
        }
    }

    public struct Result: Decodable, Hashable {
        public let title: String
        public let detail: String
        public let beats: Double
        public let parts: [Part]
        enum CodingKeys: String, CodingKey { case title, detail, beats, parts }
        public init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            title = (try? c.decode(String.self, forKey: .title)) ?? ""
            detail = (try? c.decode(String.self, forKey: .detail)) ?? ""
            beats = (try? c.decode(Double.self, forKey: .beats)) ?? 0
            parts = (try? c.decode([Part].self, forKey: .parts)) ?? []
        }
        /// Every note of every part, as one list.
        public var notes: [Note] { parts.flatMap(\.notes) }
    }

    public struct Results: Decodable {
        public let results: [Result]
        public let message: String?
    }

    /// What a generator is told about where it is writing.
    public struct Context: Encodable {
        public struct Selection: Encodable {
            public var notes: [Note]
            public var beats: Double
            public var drums: Bool
        }
        public var root: Int, scale: Int, num: Int, den: Int
        public var barBeats: Double, bpm: Double
        public var inst: String, catalogueId: String
        public var bars: Int
        public var selection: Selection

        public init(project p: Project, instrument: String, bars: Int, selection: [Note] = [], selectionBeats: Double = 0, drums: Bool = false) {
            root = p.key.root; scale = p.key.scale; num = p.meter[0]; den = p.meter[1]
            barBeats = p.beatsPerBar; bpm = p.tempo
            inst = instrument; catalogueId = instrument
            self.bars = bars
            self.selection = Selection(notes: selection, beats: selectionBeats, drums: drums)
        }
    }

    public struct Instrument: Decodable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let family: String?
        public let low: Int?
        public let high: Int?
        public let sweet: [Int]?
        public let poly: Int?
        public let drums: Bool?
        public var isDrums: Bool { drums ?? false }
    }

    let context: JSContext
    let queue = DispatchQueue(label: "middaw.engines")
    public let root: URL

    /// `root` holds `runtime/` and `family/` - the app's Resources, or the
    /// repository when run from source.
    public init(root: URL) throws {
        self.root = root
        guard let ctx = JSContext() else { throw Failure(description: "JavaScriptCore would not start") }
        context = ctx
        var loadError: String?
        ctx.exceptionHandler = { _, value in loadError = value?.toString() ?? "a script failed" }
        let log: @convention(block) (String) -> Void = { message in
            if ProcessInfo.processInfo.environment["MIDDAW_LOG"] != nil { print(message) }
        }
        let engines = root.appendingPathComponent("family/engines")
        let read: @convention(block) (String) -> String? = { path in
            guard !path.contains(".."), let data = try? Data(contentsOf: engines.appendingPathComponent(path)) else { return nil }
            return String(data: data, encoding: .isoLatin1)       // one character per byte
        }
        ctx.setObject(log, forKeyedSubscript: "__middawLog" as NSString)
        ctx.setObject(read, forKeyedSubscript: "__middawRead" as NSString)
        for file in ["runtime/polyfill.js", "runtime/lua/lua_parse.js", "runtime/lua/lua_runtime.js", "runtime/lua/lua_compile.js",
                     "runtime/jsfx/jsfx.js", "runtime/composer/py.js", "runtime/composer/pyrandom.js",
                     "runtime/composer/core.js", "runtime/composer/functional.js", "runtime/composer/music.js",
                     "runtime/composer/render.js", "runtime/host.js"] {
            let url = root.appendingPathComponent(file)
            guard let src = try? String(contentsOf: url, encoding: .utf8) else {
                throw Failure(description: "missing \(file) under \(root.path)")
            }
            ctx.evaluateScript(src, withSourceURL: url)
            if let e = loadError { throw Failure(description: "\(file): \(e)") }
        }
        ctx.evaluateScript("MiddawHost.init(__middawRead, __middawLog);")
        if let e = loadError { throw Failure(description: e) }
        ctx.exceptionHandler = { _, _ in }
        // The composer's vocabulary. Without it everything else still works,
        // and Compose says what is missing.
        let vocab = root.appendingPathComponent("data/vocab")
        if let tags = try? String(contentsOf: vocab.appendingPathComponent("tags.json"), encoding: .utf8),
           let drums = try? String(contentsOf: vocab.appendingPathComponent("drums.json"), encoding: .utf8) {
            _ = try? callAny("composerLoad", ["tags": tags, "drums": drums])
        }
    }

    /// Compose: Middaw's composer, a sentence in and the song's five parts
    /// out - the same answer `python3 -m middaw --json` gives for the seed.
    public func compose<T: Decodable>(_ prompt: String, seed: Int, as: T.Type = T.self) throws -> T {
        struct Args: Encodable { let prompt: String; let seed: Int }
        return try call("compose", Args(prompt: prompt, seed: seed))
    }

    /// Where the app's engines are: inside Middaw.app, or the repository
    /// this was built from.
    public static func defaultRoot() -> URL {
        if let res = Bundle.main.resourceURL, FileManager.default.fileExists(atPath: res.appendingPathComponent("runtime/host.js").path) {
            return res
        }
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 {
            dir.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("runtime/host.js").path) { return dir }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    // ----------------------------------------------------------- calling --
    struct Reply<T: Decodable>: Decodable { let ok: Bool; let value: T?; let error: String? }
    struct Empty: Encodable {}

    /// One host method: arguments as JSON in, the value decoded out.
    public func call<T: Decodable, A: Encodable>(_ method: String, _ args: A, as: T.Type = T.self) throws -> T {
        let json = String(decoding: try JSONEncoder().encode(args), as: UTF8.self)
        let text: String = queue.sync {
            let host = context.objectForKeyedSubscript("MiddawHost")
            return host?.invokeMethod("call", withArguments: [method, json])?.toString() ?? "{\"ok\":false,\"error\":\"no reply\"}"
        }
        let reply = try JSONDecoder().decode(Reply<T>.self, from: Data(text.utf8))
        guard reply.ok, let value = reply.value else { throw Failure(description: reply.error ?? "\(method) failed") }
        return value
    }

    /// For results with no fixed shape (the orchestration guide, the pass).
    public func callAny<A: Encodable>(_ method: String, _ args: A) throws -> Any {
        let json = String(decoding: try JSONEncoder().encode(args), as: UTF8.self)
        let text: String = queue.sync {
            context.objectForKeyedSubscript("MiddawHost")?.invokeMethod("call", withArguments: [method, json])?.toString() ?? "{}"
        }
        let obj = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed]) as? [String: Any] ?? [:]
        guard obj["ok"] as? Bool == true else { throw Failure(description: obj["error"] as? String ?? "\(method) failed") }
        return obj["value"] ?? NSNull()
    }

    // ------------------------------------------------------- generators --
    public func generators() throws -> [Generator] { try call("generators", Empty()) }

    /// A generator with its settings, which live in the engine as it left them.
    public final class Session {
        public let engines: Engines
        public let generator: String
        let id: Int
        init(engines: Engines, generator: String, id: Int) { self.engines = engines; self.generator = generator; self.id = id }
        deinit { _ = try? engines.call("closeSession", ["session": id], as: Bool.self) }

        struct KeyArgs: Encodable { let session: Int; let key: Key }
        struct CtxArgs: Encodable { let session: Int; let context: Context }
        struct SetArgs: Encodable { let session: Int; let setting: String; let index: Int; let context: Context }
        struct GenArgs: Encodable { let session: Int; let context: Context; let seed: Int; let count: Int }

        public func useKey(_ key: Key) throws { _ = try engines.call("useKey", KeyArgs(session: id, key: key), as: Bool.self) }
        public func settings(_ ctx: Context) throws -> [Setting] { try engines.call("settings", CtxArgs(session: id, context: ctx)) }
        public func set(_ setting: String, to index: Int, _ ctx: Context) throws {
            _ = try engines.call("set", SetArgs(session: id, setting: setting, index: index, context: ctx), as: Bool.self)
        }
        public func generate(_ ctx: Context, seed: Int, count: Int = 6) throws -> Results {
            try engines.call("generate", GenArgs(session: id, context: ctx, seed: seed, count: count))
        }
    }

    public func session(_ generator: String) throws -> Session {
        Session(engines: self, generator: generator, id: try call("newSession", ["generator": generator]))
    }

    // ----------------------------------------------------------- theory --
    struct ChordArgs: Encodable { let pitches: [Int]; let key: Key }
    struct KeyOnly: Encodable { let key: Key }
    struct NotesArgs: Encodable { let notes: [Note] }

    /// ScaleView's name for the chord these pitches make, or "".
    public func nameChord(_ pitches: [Int], in key: Key) -> String {
        (try? call("nameChord", ChordArgs(pitches: pitches, key: key), as: String.self)) ?? ""
    }
    public func noteNames(_ key: Key) -> [String] {
        (try? call("noteNames", KeyOnly(key: key), as: [String].self)) ?? Theory.sharpNames
    }
    public func detectKey(_ notes: [Note]) -> Key? {
        try? call("detectKey", NotesArgs(notes: notes), as: Key.self)
    }

    public func instruments() throws -> [Instrument] { try call("instruments", Empty()) }

    // ---------------------------------------------------------- devices --
    struct AutoCCArgs: Encodable {
        let source: String; let notes: [Note]; let tempo: Double; let meter: [Int]; let length: Double; let sliders: [String: Double]
    }

    /// AutoCC, the JSFX itself, run over a clip: the dynamics and expression
    /// curves it would play, as the clip's controller lanes.
    public func autoCC(notes: [Note], length: Double, project p: Project, sliders: [Int: Double]) throws -> [Int: [CCPoint]] {
        let url = root.appendingPathComponent("family/devices/AutoCC.jsfx")
        guard let src = try? String(contentsOf: url, encoding: .utf8) else { throw Failure(description: "AutoCC is missing") }
        let raw: [String: [[Double]]] = try call("autoCC", AutoCCArgs(source: src, notes: notes, tempo: p.tempo, meter: p.meter, length: length,
                                                                       sliders: Dictionary(uniqueKeysWithValues: sliders.map { (String($0.key), $0.value) })))
        var out: [Int: [CCPoint]] = [:]
        for (k, pts) in raw {
            guard let n = Int(k) else { continue }
            out[n] = pts.compactMap { $0.count >= 2 ? CCPoint(beat: $0[0], value: Int($0[1].rounded())) : nil }
        }
        return out
    }

    // --------------------------------------------------------- notation --
    public struct Engraving: Decodable {
        public let height: Double
        /// Pen calls: ["line", x1, y1, x2, y2, colour, width], ["poly", [x, y...], colour],
        /// ["circle", x, y, r, colour, filled], ["text", x, y, colour, text, size, centred].
        public let ops: [[PenArg]]
    }
    public enum PenArg: Decodable {
        case number(Double), text(String), flag(Bool), list([Double]), other
        public init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let n = try? c.decode(Double.self) { self = .number(n) }
            else if let b = try? c.decode(Bool.self) { self = .flag(b) }
            else if let s = try? c.decode(String.self) { self = .text(s) }
            else if let l = try? c.decode([Double].self) { self = .list(l) }
            else { self = .other }
        }
        public var number: Double { if case .number(let n) = self { return n }; return 0 }
        public var text: String { if case .text(let s) = self { return s }; return "" }
        public var flag: Bool { if case .flag(let b) = self { return b }; return false }
        public var list: [Double] { if case .list(let l) = self { return l }; return [] }
    }
    struct EngraveArgs: Encodable {
        let key: Key; let meter: [Int]; let barBeats: Double; let beats: Double
        let notes: [Note]; let name: String; let drums: Bool; let width: Double; let space: Double; let highlight: Double
    }

    /// A part engraved by Starting Blocks Notation, `width` in staff spaces.
    public func engrave(notes: [Note], beats: Double, project p: Project, drums: Bool, width: Double, space: Double,
                        highlight: Double = -1) throws -> Engraving {
        try call("engrave", EngraveArgs(key: p.key, meter: p.meter, barBeats: p.beatsPerBar, beats: beats, notes: notes,
                                        name: "", drums: drums, width: width, space: space, highlight: highlight))
    }
}
