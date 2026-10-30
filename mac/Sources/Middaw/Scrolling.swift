import SwiftUI
import AppKit

/// Scroll wheels and trackpad pinches for the drawn views (arrange, piano
/// roll, score), which scroll and zoom themselves as a DAW's do. A view
/// registers the rectangle it occupies; the monitor hands it the events that
/// land inside.
@MainActor
final class ScrollMonitor {
    static let shared = ScrollMonitor()
    struct Region {
        weak var window: NSWindow?
        var frame: CGRect
        var scroll: (CGFloat, CGFloat, NSEvent.ModifierFlags) -> Void
        var magnify: ((CGFloat, CGPoint) -> Void)?
    }
    private var regions: [String: Region] = [:]
    private var installed = false

    func register(_ id: String, _ region: Region) {
        regions[id] = region
        install()
    }
    func remove(_ id: String) { regions[id] = nil }

    private func install() {
        guard !installed else { return }
        installed = true
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] e in
            guard let self = self, let w = e.window, let content = w.contentView else { return e }
            let p = content.convert(e.locationInWindow, from: nil)
            let pt = CGPoint(x: p.x, y: content.isFlipped ? p.y : content.bounds.height - p.y)
            for (_, r) in self.regions where r.window === w && r.frame.contains(pt) {
                if e.type == .scrollWheel {
                    let k: CGFloat = e.hasPreciseScrollingDeltas ? 1 : 12
                    r.scroll(e.scrollingDeltaX * k, e.scrollingDeltaY * k, e.modifierFlags)
                    return nil
                } else if let m = r.magnify {
                    m(e.magnification, CGPoint(x: pt.x - r.frame.minX, y: pt.y - r.frame.minY))
                    return nil
                }
            }
            return e
        }
    }
}

extension View {
    /// Receive scroll and pinch events over this view.
    func scrolls(_ id: String, window: NSWindow?, scroll: @escaping (CGFloat, CGFloat, NSEvent.ModifierFlags) -> Void,
                 magnify: ((CGFloat, CGPoint) -> Void)? = nil) -> some View {
        background(GeometryReader { g in
            Color.clear
                .onAppear { ScrollMonitor.shared.register(id, .init(window: window, frame: g.frame(in: .global), scroll: scroll, magnify: magnify)) }
                .onChange(of: g.frame(in: .global)) { _, f in
                    ScrollMonitor.shared.register(id, .init(window: window, frame: f, scroll: scroll, magnify: magnify))
                }
                .onChange(of: window) { _, w in
                    ScrollMonitor.shared.register(id, .init(window: w, frame: g.frame(in: .global), scroll: scroll, magnify: magnify))
                }
                .onDisappear { ScrollMonitor.shared.remove(id) }
        })
    }
}

/// Click counting and modifier keys for drawn views: SwiftUI's drag gesture
/// gives neither.
struct Clicks {
    private var lastTime = Date.distantPast
    private var lastPoint = CGPoint.zero
    private(set) var count = 1
    mutating func register(_ p: CGPoint) {
        let now = Date()
        if now.timeIntervalSince(lastTime) < NSEvent.doubleClickInterval && hypot(p.x - lastPoint.x, p.y - lastPoint.y) < 5 { count += 1 }
        else { count = 1 }
        lastTime = now; lastPoint = p
    }
    static var modifiers: NSEvent.ModifierFlags { NSEvent.modifierFlags }
}
