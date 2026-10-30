import SwiftUI

/// The house scheme (docs/COLOUR.md): a dark cool-grey ground, light grey
/// controls with dark ink, and one yellow for whatever is on. Every word is
/// 7:1 on what it sits on; on is the accent *and* a dark bar under the label.
enum Theme {
    static func hex(_ v: UInt32) -> Color {
        Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
    static let accent = hex(0xFFF200)
    static let accentHover = hex(0xFFF42E)
    static let control = hex(0xA9AFBA)
    static let controlHover = hex(0xC0C6CF)
    static let controlHeld = hex(0x8F96A2)
    static let ground = hex(0x23272E)
    static let raised = hex(0x2A2F37)
    static let sunken = hex(0x1A1D23)
    static let roll = hex(0x111419)
    static let beat = hex(0x1E2228)
    static let rule = hex(0x3A404A)
    static let edge = hex(0x6D7581)
    static let ink = hex(0x14171C)
    static let text = hex(0xDDE1E7)
    static let textDim = hex(0xB6BCC6)
    static let label = hex(0xBFC5CE)
    static let warn = hex(0xD2483F)
    static let warnText = hex(0xFFA6A0)
    static let playhead = hex(0xF2F4F7)
    static let note = hex(0xA9AFBA)
    static let noteDim = hex(0x3A404A)

    /// 28 points tall, Apple's Mac default; 12 between bezelled controls.
    static let controlHeight: CGFloat = 28
    static let gap: CGFloat = 12
}

/// A house button: grey with dark ink, the accent when it is the primary
/// action or when it is on - and then a dark bar under its label too.
struct HouseButtonStyle: ButtonStyle {
    var on = false
    var primary = false
    var compact = false
    @Environment(\.isEnabled) var enabled
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        let lit = on || primary
        let fill: Color = configuration.isPressed ? (lit ? Theme.hex(0xD1C600) : Theme.controlHeld)
            : hover ? (lit ? Theme.accentHover : Theme.controlHover) : (lit ? Theme.accent : Theme.control)
        return configuration.label
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .padding(.horizontal, compact ? 6 : 10)
            .frame(minWidth: Theme.controlHeight, minHeight: Theme.controlHeight)
            .background(RoundedRectangle(cornerRadius: 6).fill(fill))
            .overlay(alignment: .bottom) {
                if on {
                    GeometryReader { g in
                        Capsule().fill(Theme.ink).frame(width: g.size.width * 0.56, height: 2)
                            .position(x: g.size.width / 2, y: g.size.height - 4)
                    }
                }
            }
            .opacity(enabled ? 1 : 0.45)
            .contentShape(Rectangle())
            .onHover { hover = $0 }
    }
}

extension View {
    func house(on: Bool = false, primary: Bool = false, compact: Bool = false) -> some View {
        buttonStyle(HouseButtonStyle(on: on, primary: primary, compact: compact))
    }
    /// A section heading in a panel.
    func heading() -> some View {
        font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
    }
}

/// One of several, as a row of house buttons (a segmented control).
struct Choices<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { value, name in
                Button(name) { selection = value }
                    .house(on: selection == value, compact: true)
                    .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
    }
}

/// A labelled row in a panel: the label on the left, its control on the right.
struct Row<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 8) {
            Text(label).foregroundStyle(Theme.label).frame(width: 84, alignment: .leading)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
