import Foundation
import AVFoundation
import AudioToolbox
import CJSFX
import MiddawCore

// Audio Unit instruments, hosted: the plug-in format every Mac DAW reads,
// through Core Audio itself, so nothing is added to the app to host them. A
// sound library sold as VST3 on the Mac ships an Audio Unit beside it.
//
// An instrument is found and made on the main thread and played on the audio
// thread, inside the renderer's own block: its MIDI is scheduled with sample
// offsets and its render block is called with the renderer's buffers.

extension PluginRef {
    public var componentDescription: AudioComponentDescription {
        AudioComponentDescription(componentType: type, componentSubType: subtype, componentManufacturer: manufacturer,
                                  componentFlags: 0, componentFlagsMask: 0)
    }
}

public enum PluginCatalog {
    /// Every Audio Unit instrument on this Mac, by maker and name.
    public static func instruments() -> [PluginRef] {
        let any = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: 0,
                                            componentManufacturer: 0, componentFlags: 0, componentFlagsMask: 0)
        return AVAudioUnitComponentManager.shared().components(matching: any)
            .map { c in
                let d = c.audioComponentDescription
                return PluginRef(type: d.componentType, subtype: d.componentSubType, manufacturer: d.componentManufacturer,
                                 name: c.name, maker: c.manufacturerName)
            }
            .sorted { ($0.maker.lowercased(), $0.name.lowercased()) < ($1.maker.lowercased(), $1.name.lowercased()) }
    }
}

/// What a plug-in asks the host about the song while it plays, written by
/// the renderer before each block.
final class PluginClock {
    var tempo = 120.0, beat = 0.0, num = 4.0, den = 4, playing = false, sample = 0.0
}

/// One Audio Unit instrument, ready to play.
public final class PluginInstance {
    /// The device's id in the song.
    public let modelID: String
    public let ref: PluginRef
    public let unit: AUAudioUnit
    let renderBlock: AURenderBlock
    let schedule: AUScheduleMIDIEventBlock?
    let buffers: UnsafeMutableAudioBufferListPointer
    let clock: PluginClock
    var sampleTime = 0.0

    init(device: Device, ref: PluginRef, unit: AUAudioUnit, sampleRate: Double) throws {
        modelID = device.id
        self.ref = ref
        self.unit = unit
        if case .string(let saved)? = device.state, let data = Data(base64Encoded: saved),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            unit.fullStateForDocument = plist
        }
        if let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2), unit.outputBusses.count > 0 {
            try unit.outputBusses[0].setFormat(format)
        }
        unit.maximumFramesToRender = AUAudioFrameCount(Renderer.maxFrames)
        let clock = PluginClock()
        self.clock = clock
        unit.musicalContextBlock = { tempo, num, den, beat, offset, downbeat in
            tempo?.pointee = clock.tempo
            num?.pointee = clock.num
            den?.pointee = clock.den
            beat?.pointee = clock.beat
            offset?.pointee = 0
            downbeat?.pointee = (clock.beat / max(1, clock.num * 4 / Double(clock.den))).rounded(.down) * (clock.num * 4 / Double(clock.den))
            return true
        }
        unit.transportStateBlock = { flags, position, cycleStart, cycleEnd in
            flags?.pointee = clock.playing ? .moving : []
            position?.pointee = clock.sample
            cycleStart?.pointee = 0
            cycleEnd?.pointee = 0
            return true
        }
        try unit.allocateRenderResources()
        renderBlock = unit.renderBlock
        schedule = unit.scheduleMIDIEventBlock
        buffers = AudioBufferList.allocate(maximumBuffers: 2)
    }

    deinit {
        unit.deallocateRenderResources()
        free(buffers.unsafeMutablePointer)
    }

    /// The plug-in's state as the song keeps it.
    public func state() -> JSONValue? {
        guard let st = unit.fullStateForDocument ?? unit.fullState,
              let data = try? PropertyListSerialization.data(fromPropertyList: st, format: .binary, options: 0) else { return nil }
        return .string(data.base64EncodedString())
    }

    /// Play a block: the MIDI at its sample offsets, the sound into `L` and `R`
    /// (which it overwrites).
    func render(_ n: Int, _ L: UnsafeMutablePointer<Float>, _ R: UnsafeMutablePointer<Float>,
                _ midi: UnsafePointer<jsfx_midi>, _ count: Int, _ time: DeviceTime) {
        clock.tempo = time.tempo; clock.beat = time.beat; clock.num = time.num; clock.den = Int(time.den)
        clock.playing = time.playing; clock.sample = sampleTime
        if let schedule {
            for k in 0..<count {
                let e = midi[k]
                let at = AUEventSampleTimeImmediate + AUEventSampleTime(max(0, min(n - 1, Int(e.offset))))
                withUnsafeBytes(of: e.data) { raw in
                    if let p = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) { schedule(at, 0, max(1, min(3, Int(e.len))), p) }
                }
            }
        }
        let bytes = UInt32(n * MemoryLayout<Float>.size)
        buffers[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: UnsafeMutableRawPointer(L))
        buffers[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: bytes, mData: UnsafeMutableRawPointer(R))
        var flags = AudioUnitRenderActionFlags()
        var stamp = AudioTimeStamp()
        stamp.mSampleTime = sampleTime
        stamp.mFlags = .sampleTimeValid
        let status = renderBlock(&flags, &stamp, AUAudioFrameCount(n), 0, buffers.unsafeMutablePointer, nil)
        sampleTime += Double(n)
        if status != noErr {
            for i in 0..<n { L[i] = 0; R[i] = 0 }
            return
        }
        // A plug-in may answer with its own buffers rather than fill ours.
        if let d = buffers[0].mData, d != UnsafeMutableRawPointer(L) { L.update(from: d.assumingMemoryBound(to: Float.self), count: n) }
        if let d = buffers[1].mData, d != UnsafeMutableRawPointer(R) { R.update(from: d.assumingMemoryBound(to: Float.self), count: n) }
    }
}

/// The Audio Units a song's players use, made once and kept while the song
/// keeps them. Making one is asynchronous; when it is ready, `onLoaded` asks
/// for the song to be played again with it.
public final class PluginHost {
    public let sampleRate: Double
    public var onLoaded: (() -> Void)?
    private var instances: [String: PluginInstance] = [:]
    private var loading: Set<String> = []
    /// Why a device's plug-in could not be made, by device id.
    public private(set) var failures: [String: String] = [:]

    public init(sampleRate: Double) { self.sampleRate = sampleRate }

    /// The device's plug-in if it is ready; else it is started and nil for now.
    public func instance(for d: Device) -> PluginInstance? {
        guard d.device == "au", let ref = d.plugin else { return nil }
        if let i = instances[d.id], i.ref == ref { return i }
        if !loading.contains(d.id) && failures[d.id] == nil { load(d, ref) }
        return nil
    }

    public func instance(id: String) -> PluginInstance? { instances[id] }

    func load(_ d: Device, _ ref: PluginRef) {
        loading.insert(d.id)
        let rate = sampleRate
        AUAudioUnit.instantiate(with: ref.componentDescription, options: []) { [weak self] unit, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.loading.remove(d.id)
                do {
                    guard let unit else { throw error ?? PluginError(description: "\(ref.name) didn’t open.") }
                    self.instances[d.id] = try PluginInstance(device: d, ref: ref, unit: unit, sampleRate: rate)
                } catch {
                    self.failures[d.id] = "\(ref.name) couldn’t be opened: \(error.localizedDescription)"
                }
                self.onLoaded?()
            }
        }
    }

    /// Every plug-in the song uses, made before returning: for rendering the
    /// song to a file, away from the main thread.
    public func loadAll(_ p: Project) {
        for t in p.tracks where t.sound.device == "au" {
            guard let ref = t.sound.plugin, instances[t.sound.id] == nil else { continue }
            do {
                let unit = try AUAudioUnit(componentDescription: ref.componentDescription, options: [])
                instances[t.sound.id] = try PluginInstance(device: t.sound, ref: ref, unit: unit, sampleRate: sampleRate)
            } catch {
                failures[t.sound.id] = "\(ref.name) couldn’t be opened: \(error.localizedDescription)"
            }
        }
    }

    /// Plug-ins the song no longer uses are let go.
    public func keep(only ids: Set<String>) {
        for id in instances.keys where !ids.contains(id) { instances.removeValue(forKey: id) }
        for id in failures.keys where !ids.contains(id) { failures.removeValue(forKey: id) }
    }

    /// Every plug-in's saved state, by its device id.
    public func states() -> [String: JSONValue] {
        var out: [String: JSONValue] = [:]
        for (id, i) in instances { if let s = i.state() { out[id] = s } }
        return out
    }
}

public struct PluginError: Error, CustomStringConvertible { public let description: String }
