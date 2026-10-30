import SwiftUI
import MiddawCore

/// The house scheme (docs/COLOUR.md): a dark cool-grey ground, light grey
/// controls with dark ink, and one yellow for whatever is on. Every word is
/// 7:1 on what it sits on; on is the accent *and* a dark bar under the label.
enum Theme {
    static func hex(_ v: UInt32) -> Color {
        Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
    static let accent = hex(HousePalette.accent)
    static let accentHover = hex(HousePalette.accentHover)
    static let control = hex(HousePalette.control)
    static let controlHover = hex(HousePalette.controlHover)
    static let controlHeld = hex(HousePalette.controlHeld)
    static let ground = hex(HousePalette.ground)
    static let raised = hex(HousePalette.raised)
    static let sunken = hex(HousePalette.sunken)
    static let roll = hex(HousePalette.roll)
    static let beat = hex(HousePalette.beat)
    static let rule = hex(HousePalette.rule)
    static let edge = hex(HousePalette.edge)
    static let ink = hex(HousePalette.ink)
    static let text = hex(HousePalette.text)
    static let textDim = hex(HousePalette.textDim)
    static let label = hex(HousePalette.label)
    static let warn = hex(HousePalette.warn)
    static let warnText = hex(HousePalette.warnText)
    static let playhead = hex(HousePalette.playhead)
    static let note = hex(HousePalette.control)
    static let noteDim = hex(HousePalette.rule)

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

    func makeBody(configuration: Configuration) -> some View {
        HouseButtonBody(label: configuration.label, pressed: configuration.isPressed, on: on, primary: primary, compact: compact)
    }
}

struct HouseButtonBody<Label: View>: View {
    let label: Label
    let pressed: Bool
    let on: Bool
    let primary: Bool
    let compact: Bool
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false

    var body: some View {
        let lit = on || primary
        let fill: Color = pressed ? (lit ? Theme.hex(0xD1C600) : Theme.controlHeld)
            : hover ? (lit ? Theme.accentHover : Theme.controlHover) : (lit ? Theme.accent : Theme.control)
        return label
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
