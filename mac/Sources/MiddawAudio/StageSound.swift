import Foundation
import MiddawCore

/// One seat's sound in the hall, on the audio thread: the player's stereo
/// narrowed to the seat's width, the air's darkening, the direct sound panned
/// to where the seat is and as loud as its distance allows, and the walls'
/// reflections (`Stage.sound`). The seat's impulse response is those plus the
/// hall's tail: the reflections are a handful of taps, so they are convolved
/// here directly; the tail is dense and shared, so the renderer convolves it
/// once for the whole stage (`HallTail`).
final class SeatVoice {
    /// What it was made from: kept while the seat and the hall stay the same.
    let key: String
    let left: Float, right: Float
    let width: Float
    let air: Float
    var lowpass: Float = 0
    let taps: Int
    let delays: UnsafeMutablePointer<Int>
    let gainsL: UnsafeMutablePointer<Float>, gainsR: UnsafeMutablePointer<Float>
    let line: UnsafeMutablePointer<Float>
    let mask: Int
    var write = 0

    init(seat: Seat, hall: Hall, sampleRate: Double) {
        key = seat.id + "@" + hall.id
        let sound = Stage.sound(seat, in: hall)
        let g = Stage.panGains(sound.pan)
        left = Float(g.left * sound.direct); right = Float(g.right * sound.direct)
        width = Float(sound.width)
        air = Float(1 - exp(-2 * .pi * min(sound.airCutoff, sampleRate * 0.45) / sampleRate))
        taps = sound.reflections.count
        delays = .allocate(capacity: max(1, taps))
        gainsL = .allocate(capacity: max(1, taps)); gainsR = .allocate(capacity: max(1, taps))
        var longest = 0
        for (k, r) in sound.reflections.enumerated() {
            delays[k] = max(1, Int((r.delay * sampleRate).rounded()))
            gainsL[k] = Float(r.left); gainsR[k] = Float(r.right)
            longest = max(longest, delays[k])
        }
        var size = 1
        while size < longest + 1 { size <<= 1 }
        mask = size - 1
        line = .allocate(capacity: size)
        line.initialize(repeating: 0, count: size)
    }

    deinit { delays.deallocate(); gainsL.deallocate(); gainsR.deallocate(); line.deallocate() }

    /// The player's block (`inL`, `inR`) at `gain`, into the mix; what goes to
    /// the hall's tail is added to `tail`.
    func process(_ n: Int, _ inL: UnsafePointer<Float>, _ inR: UnsafePointer<Float>, gain: Float,
                 _ outL: UnsafeMutablePointer<Float>, _ outR: UnsafeMutablePointer<Float>, _ tail: UnsafeMutablePointer<Float>) {
        for i in 0..<n {
            let mid = (inL[i] + inR[i]) * 0.5 * gain
            let side = (inL[i] - inR[i]) * 0.5 * gain * width
            lowpass += air * (mid - lowpass)
            let m = lowpass
            line[write & mask] = m
            var l = m * left + side, r = m * right - side
            for k in 0..<taps {
                let v = line[(write - delays[k]) & mask]
                l += v * gainsL[k]
                r += v * gainsR[k]
            }
            outL[i] += l
            outR[i] += r
            tail[i] += m
            write = (write + 1) & mask
        }
    }
}

/// The hall's late reverberation, one convolver an ear, fed by every seat.
final class HallTail {
    let id: String
    let left: Convolver, right: Convolver

    init(hall: Hall, sampleRate: Double) {
        id = hall.id
        let ir = Stage.tail(hall, sampleRate: sampleRate)
        left = Convolver(ir: ir.left)
        right = Convolver(ir: ir.right)
    }
}
