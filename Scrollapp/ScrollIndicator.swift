import AppKit

@MainActor
final class ScrollIndicator {
    enum Style {
        case anchor
        case pointer

        var diameter: CGFloat { self == .anchor ? 24 : 22 }

        func frame(at point: NSPoint, screen: NSRect? = nil) -> NSRect {
            if self == .anchor {
                return NSRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                              width: diameter, height: diameter)
            }

            let gap: CGFloat = 10
            var x = point.x + gap
            var y = point.y - gap - diameter
            if let screen {
                if x + diameter > screen.maxX { x = point.x - gap - diameter }
                if y < screen.minY { y = point.y + gap }
                x = max(screen.minX, min(x, screen.maxX - diameter))
                y = max(screen.minY, min(y, screen.maxY - diameter))
            }
            // Creating a window at a fractional origin can enlarge its frame by a point.
            return NSRect(x: x.rounded(), y: y.rounded(), width: diameter, height: diameter)
        }
    }

    private let style: Style
    private var panel: NSPanel?
    private var indicator: ScrollIndicatorGlyph?
    private var lastPoint: NSPoint?
    private var horizontalEnabled = false
    private var direction = ScrollDirection()

    init(style: Style) {
        self.style = style
    }

    func show(at point: NSPoint, horizontalEnabled: Bool) {
        hide()

        let frame = frame(at: point)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let indicator = ScrollIndicatorGlyph(frame: NSRect(origin: .zero, size: frame.size))
        panel.contentView = indicator

        self.panel = panel
        self.indicator = indicator
        lastPoint = point
        update(horizontalEnabled: horizontalEnabled)
        panel.orderFrontRegardless()
    }

    func move(to point: NSPoint) {
        guard let panel, point != lastPoint else { return }
        lastPoint = point
        let origin = frame(at: point).origin
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
    }

    private func frame(at point: NSPoint) -> NSRect {
        let screen = style == .pointer ? NSScreen.screens.first(where: { $0.frame.contains(point) })?.frame : nil
        return style.frame(at: point, screen: screen)
    }

    func update(horizontalEnabled: Bool) {
        self.horizontalEnabled = horizontalEnabled
        if !horizontalEnabled { direction.horizontal = 0 }
        refreshIndicator()
    }

    func updateDirection(_ nextDirection: ScrollDirection) {
        guard direction != nextDirection, indicator != nil else { return }
        direction = nextDirection
        refreshIndicator()
    }

    private func refreshIndicator() {
        guard let indicator else { return }
        let axes = horizontalEnabled ? "Horizontal and vertical" : "Vertical"
        let label = axes + (style == .anchor ? " auto-scroll anchor" : " scroll cursor")
        indicator.setAccessibilityLabel(direction.label.map { "\(label), scrolling \($0)" } ?? label)
        indicator.update(horizontalEnabled: horizontalEnabled, direction: direction)
    }

    func hide() {
        panel?.close()
        panel = nil
        indicator = nil
        lastPoint = nil
        direction = ScrollDirection()
    }
}

@MainActor
private final class ScrollIndicatorGlyph: NSView {
    private static let brandBlue = NSColor(srgbRed: 0, green: 128 / 255, blue: 1, alpha: 1)
    private var horizontalEnabled = false
    private var direction = ScrollDirection()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
        let axes = horizontalEnabled ? [(0, 1), (0, -1), (-1, 0), (1, 0)] : [(0, 1), (0, -1)]
        let arrows = axes.map { x, y in
            let active = (x != 0 && x == direction.horizontal) || (y != 0 && y == direction.vertical)
            return (path: arrowPath(x: CGFloat(x), y: CGFloat(y)), active: active)
        }

        // Outline just the strokes so the glyph stays legible over light and dark content.
        NSColor.black.withAlphaComponent(0.8).setStroke()
        for path in [ring] + arrows.map(\.path) {
            path.lineWidth = 3
            path.stroke()
        }

        NSColor.white.setStroke()
        ring.lineWidth = 1.5
        ring.stroke()
        for (path, _) in arrows {
            path.lineWidth = 1.5
            path.stroke()
        }
        Self.brandBlue.setStroke()
        for (path, active) in arrows where active {
            path.stroke()
        }
    }

    private func arrowPath(x: CGFloat, y: CGFloat) -> NSBezierPath {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let reach = bounds.width * 0.25
        let head = bounds.width * 0.115
        let tip = CGPoint(x: center.x + x * reach, y: center.y + y * reach)
        let headBase = CGPoint(x: tip.x - x * head, y: tip.y - y * head)
        let wing = CGPoint(x: -y * head, y: x * head)
        let arrow = NSBezierPath()
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.move(to: center)
        arrow.line(to: tip)
        arrow.move(to: CGPoint(x: headBase.x + wing.x, y: headBase.y + wing.y))
        arrow.line(to: tip)
        arrow.line(to: CGPoint(x: headBase.x - wing.x, y: headBase.y - wing.y))
        return arrow
    }

    func update(horizontalEnabled: Bool, direction: ScrollDirection) {
        self.horizontalEnabled = horizontalEnabled
        self.direction = direction
        needsDisplay = true
    }
}
