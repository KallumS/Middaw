import Foundation
import Accelerate

/// Convolution with an impulse response of any length, sample for sample and
/// with no delay, cheap enough for the audio thread.
///
/// The first `block` samples of the response are convolved directly; the rest
/// by uniformly partitioned overlap-save in the frequency domain (Accelerate's
/// FFT). A partitioned convolver is `block` samples late, which is exactly the
/// part the direct head covers: the tail's output for time t needs input only
/// up to t - block, so the two together are the whole convolution, on time.
///
/// Everything is allocated in `init`; `process` allocates, locks and waits on
/// nothing.
public final class Convolver {
    public let block: Int
    public let length: Int
    let size: Int
    let log2n: vDSP_Length
    let setup: FFTSetup
    let parts: Int
    let hasHead: Bool
    /// The head, reversed, for a dot product against the input history.
    let headRev: UnsafeMutablePointer<Float>
    /// Each partition's spectrum (split complex, Accelerate's packed real form).
    let hRe: UnsafeMutablePointer<Float>, hIm: UnsafeMutablePointer<Float>
    /// The last `parts` input blocks' spectra, a ring.
    let xRe: UnsafeMutablePointer<Float>, xIm: UnsafeMutablePointer<Float>
    let accRe: UnsafeMutablePointer<Float>, accIm: UnsafeMutablePointer<Float>
    /// The previous block and the one filling: 2 * block samples.
    let input: UnsafeMutablePointer<Float>
    /// The tail's output for the block now being played.
    let pending: UnsafeMutablePointer<Float>
    let work: UnsafeMutablePointer<Float>
    var fill = 0
    var slot = 0

    public init(ir: [Float], block: Int = 256) {
        precondition(block >= 16 && block & (block - 1) == 0, "the block is a power of two")
        self.block = block
        length = ir.count
        size = 2 * block
        log2n = vDSP_Length(Int(log2(Double(2 * block)).rounded()))
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        let B = block
        func zeros(_ n: Int) -> UnsafeMutablePointer<Float> {
            let p = UnsafeMutablePointer<Float>.allocate(capacity: n)
            p.initialize(repeating: 0, count: n)
            return p
        }
        headRev = zeros(B)
        var any = false
        for m in 0..<min(B, ir.count) where ir[m] != 0 { headRev[B - 1 - m] = ir[m]; any = true }
        hasHead = any
        parts = (max(0, ir.count - B) + B - 1) / B
        let cap = max(1, parts) * B
        hRe = zeros(cap); hIm = zeros(cap); xRe = zeros(cap); xIm = zeros(cap)
        accRe = zeros(B); accIm = zeros(B)
        input = zeros(2 * B); pending = zeros(B); work = zeros(2 * B)

        // Accelerate's real FFT is 2x the DFT going forward and N x coming
        // back, so a product of two forward transforms comes back 4N too loud.
        let scale = Float(1.0 / Double(4 * size))
        for j in 0..<parts {
            for k in 0..<(2 * B) { work[k] = 0 }
            let from = B + j * B
            for k in 0..<min(B, ir.count - from) { work[k] = ir[from + k] * scale }
            var h = DSPSplitComplex(realp: hRe + j * B, imagp: hIm + j * B)
            work.withMemoryRebound(to: DSPComplex.self, capacity: B) { vDSP_ctoz($0, 2, &h, 1, vDSP_Length(B)) }
            vDSP_fft_zrip(setup, &h, 1, log2n, FFTDirection(FFT_FORWARD))
        }
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        for p in [headRev, hRe, hIm, xRe, xIm, accRe, accIm, input, pending, work] { p.deallocate() }
    }

    /// Convolve `n` samples of `x`, adding the result into `y`.
    public func process(_ n: Int, _ x: UnsafePointer<Float>, _ y: UnsafeMutablePointer<Float>) {
        let B = block
        var i = 0
        while i < n {
            let run = min(n - i, B - fill)
            for k in 0..<run { input[B + fill + k] = x[i + k] }
            if parts > 0 { vDSP_vadd(pending + fill, 1, y + i, 1, y + i, 1, vDSP_Length(run)) }
            if hasHead {
                for k in 0..<run {
                    var sum: Float = 0
                    vDSP_dotpr(input + fill + k + 1, 1, headRev, 1, &sum, vDSP_Length(B))
                    y[i + k] += sum
                }
            }
            fill += run
            i += run
            if fill == B {
                if parts > 0 { transform() }
                for k in 0..<B { input[k] = input[B + k] }
                fill = 0
            }
        }
    }

    /// A full block in: its spectrum joins the ring, and every partition's
    /// share of the next block's output is summed and brought back.
    func transform() {
        let B = block
        var x = DSPSplitComplex(realp: xRe + slot * B, imagp: xIm + slot * B)
        input.withMemoryRebound(to: DSPComplex.self, capacity: B) { vDSP_ctoz($0, 2, &x, 1, vDSP_Length(B)) }
        vDSP_fft_zrip(setup, &x, 1, log2n, FFTDirection(FFT_FORWARD))
        vDSP_vclr(accRe, 1, vDSP_Length(B))
        vDSP_vclr(accIm, 1, vDSP_Length(B))
        var acc = DSPSplitComplex(realp: accRe, imagp: accIm)
        // Element 0 packs DC and Nyquist, which multiply as two reals.
        var dc: Float = 0, nyquist: Float = 0
        for j in 0..<parts {
            let s = (slot - j + parts) % parts
            var xs = DSPSplitComplex(realp: xRe + s * B, imagp: xIm + s * B)
            var hs = DSPSplitComplex(realp: hRe + j * B, imagp: hIm + j * B)
            dc += xs.realp[0] * hs.realp[0]
            nyquist += xs.imagp[0] * hs.imagp[0]
            withUnsafeMutablePointer(to: &acc) { a in vDSP_zvma(&xs, 1, &hs, 1, a, 1, a, 1, vDSP_Length(B)) }
        }
        accRe[0] = dc
        accIm[0] = nyquist
        vDSP_fft_zrip(setup, &acc, 1, log2n, FFTDirection(FFT_INVERSE))
        work.withMemoryRebound(to: DSPComplex.self, capacity: B) { vDSP_ztoc(&acc, 1, $0, 2, vDSP_Length(B)) }
        for k in 0..<B { pending[k] = work[B + k] }
        slot = (slot + 1) % parts
    }
}
