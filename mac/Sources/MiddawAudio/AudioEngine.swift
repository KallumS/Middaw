import Foundation
import AVFoundation
import CoreMIDI
import MiddawCore

/// The sound card: one AVAudioSourceNode whose render block is the
/// `Renderer`. Starting it is the only thing here that can fail.
public final class AudioEngine {
    public let renderer: Renderer
    /// Results heard before they are used, mixed in beside the song.
    public let preview: Renderer
    let engine = AVAudioEngine()
    var source: AVAudioSourceNode?
    var scratchL = [Float](repeating: 0, count: Renderer.maxFrames)
    var scratchR = [Float](repeating: 0, count: Renderer.maxFrames)
    public private(set) var running = false

    public init() {
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        renderer = Renderer(sampleRate: rate > 0 ? rate : 48000)
        preview = Renderer(sampleRate: rate > 0 ? rate : 48000)
    }

    func render(_ frames: Int, _ l: UnsafeMutablePointer<Float>, _ r: UnsafeMutablePointer<Float>) {
        renderer.render(frames, l, r)
        var done = 0
        while done < frames {
            let n = min(Renderer.maxFrames, frames - done)
            scratchL.withUnsafeMutableBufferPointer { a in
                scratchR.withUnsafeMutableBufferPointer { b in
                    preview.render(n, a.baseAddress!, b.baseAddress!)
                    for i in 0..<n { l[done + i] += a[i]; r[done + i] += b[i] }
                }
            }
            done += n
        }
    }

    public func start() throws {
        guard !running else { return }
        let me = self
        guard let format = AVAudioFormat(standardFormatWithSampleRate: r.sampleRate, channels: 2) else { return }
        let node = AVAudioSourceNode(format: format) { _, _, frames, abl -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            guard buffers.count >= 2,
                  let l = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let rr = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            me.render(Int(frames), l, rr)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        source = node
        running = true
    }

    public func stopEngine() { engine.stop(); running = false }
}

/// Every MIDI keyboard that is plugged in, now and later.
public final class MIDIInput {
    var client = MIDIClientRef()
    var port = MIDIPortRef()
    /// Called on Core MIDI's thread with status, data1, data2.
    public var onMessage: ((UInt8, UInt8, UInt8) -> Void)?

    public init() {}

    public func start() {
        let status = MIDIClientCreateWithBlock("Middaw" as CFString, &client) { [weak self] _ in self?.connectAll() }
        guard status == noErr else { return }
        MIDIInputPortCreateWithProtocol(client, "Middaw In" as CFString, ._1_0, &port) { [weak self] list, _ in
            self?.receive(list)
        }
        connectAll()
    }

    func connectAll() {
        for i in 0..<MIDIGetNumberOfSources() { MIDIPortConnectSource(port, MIDIGetSource(i), nil) }
    }

    func receive(_ list: UnsafePointer<MIDIEventList>) {
        for packet in list.unsafeSequence() {
            let words = MIDIEventPacket.WordCollection(packet)
            for w in words {
                // A MIDI 1.0 channel message in a Universal MIDI Packet: type 2.
                guard w >> 28 == 0x2 else { continue }
                let status = UInt8((w >> 16) & 0xFF), d1 = UInt8((w >> 8) & 0x7F), d2 = UInt8(w & 0x7F)
                onMessage?(status, d1, d2)
            }
        }
    }
}
