/// The house scheme (docs/COLOUR.md), as numbers: the one place the colours
/// live. The app's Theme reads them; PaletteTests measures them.
public enum HousePalette {
    public static let accent: UInt32 = 0xFFF200
    public static let accentHover: UInt32 = 0xFFF42E
    public static let accentHeld: UInt32 = 0xD1C600
    public static let control: UInt32 = 0xA9AFBA
    public static let controlHover: UInt32 = 0xC0C6CF
    public static let controlHeld: UInt32 = 0x8F96A2
    public static let ground: UInt32 = 0x23272E
    public static let raised: UInt32 = 0x2A2F37
    public static let sunken: UInt32 = 0x1A1D23
    public static let roll: UInt32 = 0x111419
    public static let beat: UInt32 = 0x1E2228
    public static let rule: UInt32 = 0x3A404A
    public static let edge: UInt32 = 0x6D7581
    public static let ink: UInt32 = 0x14171C
    public static let text: UInt32 = 0xDDE1E7
    /// 7:1 on the raised panels too (the house #B0B6C0 is 6.6 there).
    public static let textDim: UInt32 = 0xB6BCC6
    public static let label: UInt32 = 0xBFC5CE
    /// A mark only: an edge, a clipping meter, a note outside the instrument. Never words.
    public static let warn: UInt32 = 0xD2483F
    public static let warnText: UInt32 = 0xFFA6A0
    public static let playhead: UInt32 = 0xF2F4F7
    public static let staff: UInt32 = 0x8A919C

    /// WCAG relative luminance.
    public static func luminance(_ c: UInt32) -> Double {
        func ch(_ v: UInt32) -> Double {
            let x = Double(v) / 255
            return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * ch((c >> 16) & 0xFF) + 0.7152 * ch((c >> 8) & 0xFF) + 0.0722 * ch(c & 0xFF)
    }

    public static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
