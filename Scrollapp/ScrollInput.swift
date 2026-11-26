import AppKit

struct ScrollPosition {
    private var horizontal: Axis
    private var vertical: Axis
    private let start: CGPoint

    init(at point: CGPoint) {
        start = point
        horizontal = Axis(origin: point.x)
        vertical = Axis(origin: point.y)
    }

    mutating func origin(at pointer: CGPoint, horizontalEnabled: Bool) -> CGPoint {
        vertical.track(pointer.y)
        if horizontalEnabled {
            horizontal.track(pointer.x)
        } else {
            horizontal = Axis(origin: start.x)
        }
        return CGPoint(x: horizontal.origin, y: vertical.origin)
    }

    private struct Axis {
        private static let minimumExcursion: CGFloat = 32
        private static let reversalDistance: CGFloat = 16
        var origin: CGFloat
        private var extreme: CGFloat

        init(origin: CGFloat) {
            self.origin = origin
            extreme = origin
        }

        mutating func track(_ position: CGFloat) {
            let displacement = position - origin
            let excursion = extreme - origin
            if displacement == 0 || displacement.sign != excursion.sign || abs(displacement) >= abs(excursion) {
                extreme = position
            } else if abs(excursion) >= Self.minimumExcursion,
                      abs(extreme - position) >= Self.reversalDistance {
                // Measure the new direction from the last turning point.
                origin = extreme
                extreme = position
            }
        }
    }
}

struct ScrollMotion {
    static let sensitivityRange = 0.1...3.0

    struct Delta: Equatable {
        let vertical: Int32
        let horizontal: Int32
        let direction: ScrollDirection
    }

    private var vertical = AxisMotion()
    private var horizontal = AxisMotion()

    mutating func pixelDelta(displacement: CGPoint, sensitivity: Double, inverted: Bool,
                             horizontalEnabled: Bool = false, area: ScrollArea? = nil) -> Delta {
        let multiplier = CGFloat(sensitivity < 1 ? pow(sensitivity, 1.5) : sensitivity)
        let scale = inverted ? -multiplier : multiplier
        // A positive Quartz wheel delta moves up on axis 1 and left on axis 2.
        let y = vertical.step(displacement: displacement.y, scale: scale,
                              room: area?.verticalRoom(positive: displacement.y > 0))
        let x = horizontal.step(displacement: horizontalEnabled ? displacement.x : 0, scale: scale,
                                room: area?.horizontalRoom(positive: displacement.x > 0))
        return Delta(vertical: y.pixels, horizontal: -x.pixels,
                     direction: ScrollDirection(horizontal: x.direction, vertical: y.direction))
    }
}

struct ScrollDirection: Equatable {
    // -1, 0, and 1 represent the negative, neutral, and positive directions on each axis.
    var horizontal = 0
    var vertical = 0

    var label: String? {
        let verticalLabel = vertical == 0 ? nil : (vertical > 0 ? "up" : "down")
        let horizontalLabel = horizontal == 0 ? nil : (horizontal > 0 ? "right" : "left")
        let axes = [verticalLabel, horizontalLabel].compactMap { $0 }
        return axes.isEmpty ? nil : axes.joined(separator: " and ")
    }
}

struct ScrollArea {
    let anchor: CGPoint
    private let horizontal: ClosedRange<CGFloat>?
    private let vertical: ClosedRange<CGFloat>?

    init(anchor: CGPoint, screens: [CGRect]) {
        self.anchor = anchor
        horizontal = Self.connectedRange(containing: anchor.x, of: screens.filter {
            $0.minY <= anchor.y && anchor.y < $0.maxY
        }.map { $0.minX...$0.maxX })
        vertical = Self.connectedRange(containing: anchor.y, of: screens.filter {
            $0.minX <= anchor.x && anchor.x < $0.maxX
        }.map { $0.minY...$0.maxY })
    }

    func horizontalRoom(positive: Bool) -> CGFloat? { horizontal.map { Self.room(in: $0, from: anchor.x, positive: positive) } }
    func verticalRoom(positive: Bool) -> CGFloat? { vertical.map { Self.room(in: $0, from: anchor.y, positive: positive) } }

    private static func room(in range: ClosedRange<CGFloat>, from point: CGFloat, positive: Bool) -> CGFloat {
        // The last addressable point is just inside the upper edge of an AppKit frame.
        positive ? max(0, range.upperBound - point - 1) : point - range.lowerBound
    }

    private static func connectedRange(containing point: CGFloat, of ranges: [ClosedRange<CGFloat>]) -> ClosedRange<CGFloat>? {
        var connected: ClosedRange<CGFloat>?
        for next in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let current = connected {
                if current.overlaps(next) {
                    connected = current.lowerBound...max(current.upperBound, next.upperBound)
                } else if current.contains(point) {
                    return current
                } else {
                    connected = next
                }
            } else {
                connected = next
            }
        }
        return connected.flatMap { $0.contains(point) ? $0 : nil }
    }
}

private struct AxisMotion {
    private static let fullSpeedDistance: CGFloat = sqrt(30.0 / 2.5) * 50
    private var remainder: CGFloat = 0

    mutating func step(displacement: CGFloat, scale: CGFloat, room: CGFloat?) -> (pixels: Int32, direction: Int) {
        let available = room.flatMap { $0 > 0 ? $0 : nil }
        let deadZone = min(5, (available ?? 25) / 5)
        let distance = abs(displacement) - deadZone
        guard distance > 0 else {
            remainder = 0
            return (0, 0)
        }

        let accelerationDistance = min(Self.fullSpeedDistance, (available ?? .infinity) - deadZone)
        let speed = min(pow(distance / accelerationDistance, 2) * 30, 30)
        let direction: CGFloat = displacement > 0 ? 1 : -1
        let amount = speed * scale * direction

        if remainder.sign != amount.sign {
            remainder = 0
        }
        let total = amount + remainder
        let pixels = Int32(total)
        remainder = total - CGFloat(pixels)
        return (pixels, amount > 0 ? 1 : -1)
    }
}

struct DoubleClickActivation {
    private var firstClick: TimeInterval?

    mutating func registerClick(at timestamp: TimeInterval, interval: TimeInterval) -> Bool {
        if let firstClick, (0...interval).contains(timestamp - firstClick) {
            self.firstClick = nil
            return true
        }
        firstClick = timestamp
        return false
    }
}

struct TrackpadActivation {
    private var activatedInGesture = false

    mutating func shouldActivate(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase,
                                modifiers: NSEvent.ModifierFlags, hasPreciseDeltas: Bool,
                                displacement: CGPoint, horizontalEnabled: Bool = false,
                                isAutoScrolling: Bool) -> Bool {
        guard momentumPhase.isEmpty, hasPreciseDeltas else { return false }

        if phase == .began || phase == .ended || phase == .cancelled {
            activatedInGesture = false
        }

        let hasScroll = abs(displacement.y) > 0.1 || (horizontalEnabled && abs(displacement.x) > 0.1)
        guard phase == .began || phase == .changed,
              !activatedInGesture, !isAutoScrolling,
              modifiers.contains(.option), hasScroll else { return false }

        activatedInGesture = true
        return true
    }
}
