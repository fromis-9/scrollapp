//
//  ScrollappTests.swift
//  ScrollappTests
//

import AppKit
import Testing
@testable import Scrollapp

struct ScrollappTests {

    @MainActor
    @Test func fixedSpeedMiddleClickEmitsAnImmediatePixelAndTogglesOff() throws {
        let app = RecordingAppDelegate()
        defer { app.stopAutoScroll() }
        app.fixedScrollSpeed = .one
        let pointer = NSEvent.mouseLocation

        app.handleMouseButton(2, type: .otherMouseDown, modifiers: [], timestamp: 1, at: pointer)
        #expect(app.isAutoScrolling)
        #expect(app.verticalDeltas == [-1])
        #expect(app.horizontalDeltas == [0])
        let timer = try #require(app.scrollTimer)
        #expect(timer.timeInterval == 1)

        app.handleMouseButton(2, type: .otherMouseDown, modifiers: [], timestamp: 2, at: pointer)
        #expect(!app.isAutoScrolling)
        #expect(!timer.isValid)
        app.performScroll()
        #expect(app.verticalDeltas == [-1])
    }

    @MainActor
    @Test(arguments: [8, 64, 128])
    func fixedSpeedUsesItsOwnCadenceAndSupportsInversion(pixelsPerSecond: Int) throws {
        let app = RecordingAppDelegate()
        defer { app.stopAutoScroll() }
        app.fixedScrollSpeed = try #require(AppDelegate.FixedScrollSpeed(rawValue: pixelsPerSecond))
        app.isDirectionInverted = true
        app.scrollSensitivity = 0.2
        app.startAutoScroll(at: NSEvent.mouseLocation)
        app.performScroll()

        #expect(app.scrollTimer?.timeInterval == 1 / Double(pixelsPerSecond))
        #expect(app.verticalDeltas == [1, 1])
        #expect(app.horizontalDeltas == [0, 0])
    }

    @Test(arguments: [0.1, 0.2])
    func fractionalScrollAccumulatesAtLowSensitivity(sensitivity: Double) {
        var motion = ScrollMotion()
        let deltas = (0..<100).map { _ in
            motion.pixelDelta(displacement: CGPoint(x: 0, y: 25), sensitivity: sensitivity, inverted: false).vertical
        }
        #expect(deltas.first == 0)
        #expect(deltas.reduce(0, +) == (sensitivity == 0.1 ? 1 : 3))
    }

    @Test func eachScrollAxisReversesAtItsOwnTurningPoint() {
        var position = ScrollPosition(at: .zero)
        let far = CGPoint(x: 60, y: -70)
        #expect(position.origin(at: far, horizontalEnabled: true) == .zero)

        let moveUp = CGPoint(x: 64, y: -54)
        #expect(position.origin(at: moveUp, horizontalEnabled: true) == CGPoint(x: 0, y: -70))

        let moveLeft = CGPoint(x: 48, y: -50)
        #expect(position.origin(at: moveLeft, horizontalEnabled: true) == CGPoint(x: 64, y: -70))
    }

    @Test func deadZoneClearsFractionalScrollAndInversionReversesDirection() {
        var motion = ScrollMotion()
        let initial = motion.pixelDelta(displacement: CGPoint(x: 0, y: 30), sensitivity: 1, inverted: false)
        let stationary = motion.pixelDelta(displacement: CGPoint(x: 0, y: 5), sensitivity: 1, inverted: false)
        let restarted = motion.pixelDelta(displacement: CGPoint(x: 0, y: 30), sensitivity: 1, inverted: false)
        let inverted = motion.pixelDelta(displacement: CGPoint(x: 0, y: 100), sensitivity: 1, inverted: true)
        #expect(initial.vertical == 0)
        #expect(stationary.vertical == 0)
        #expect(restarted.vertical == 0)
        #expect(inverted.vertical == -9)
    }

    @Test func horizontalScrollingIsOptInAndSupportsDiagonalInversion() {
        let displacement = CGPoint(x: 100, y: 100)
        var motion = ScrollMotion()
        let vertical = motion.pixelDelta(displacement: displacement, sensitivity: 1, inverted: false)
        let diagonal = motion.pixelDelta(displacement: displacement, sensitivity: 1,
                                         inverted: false, horizontalEnabled: true)
        let inverted = motion.pixelDelta(displacement: displacement, sensitivity: 1,
                                         inverted: true, horizontalEnabled: true)
        #expect(vertical.vertical == 9 && vertical.horizontal == 0)
        #expect(diagonal.vertical > 0 && diagonal.horizontal == -9)
        #expect(inverted.vertical == -9 && inverted.horizontal == 9)
    }

    @Test func fractionalDeltasAccumulateIndependentlyOnBothAxes() {
        var motion = ScrollMotion()
        let deltas = (0..<30).map { _ in
            motion.pixelDelta(displacement: CGPoint(x: -25, y: 20), sensitivity: 0.2,
                              inverted: false, horizontalEnabled: true)
        }
        #expect(deltas.map(\.horizontal).reduce(0, +) == 1)
        #expect(deltas.map(\.vertical).reduce(0, +) == 0)
    }

    @Test func motionCanReachFullSpeedNearScreenEdges() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let area = ScrollArea(anchor: CGPoint(x: 980, y: 8), screens: [screen])
        let displacement = CGPoint(x: 19, y: -8)
        var normal = ScrollMotion()
        var adjusted = ScrollMotion()
        let baseline = normal.pixelDelta(displacement: displacement, sensitivity: 1,
                                         inverted: false, horizontalEnabled: true)
        let atEdge = adjusted.pixelDelta(displacement: displacement, sensitivity: 1,
                                         inverted: false, horizontalEnabled: true, area: area)
        #expect(baseline.vertical == 0 && baseline.horizontal == 0)
        #expect(atEdge.vertical == -30 && atEdge.horizontal == -30)
        #expect(atEdge.direction == ScrollDirection(horizontal: 1, vertical: -1))
    }

    @Test func adjacentDisplaysExtendRoomButGapsDoNot() {
        let area = ScrollArea(anchor: CGPoint(x: 90, y: 50), screens: [
            CGRect(x: 0, y: 0, width: 100, height: 100),
            CGRect(x: 100, y: 0, width: 100, height: 100),
            CGRect(x: 300, y: 0, width: 100, height: 100)
        ])
        #expect(area.horizontalRoom(positive: true) == 109)
        #expect(area.horizontalRoom(positive: false) == 90)
    }

    @Test func consecutiveDoubleClicksAreIndependent() {
        var clicks = DoubleClickActivation()
        let toggles = [0.0, 0.1, 0.35, 0.57, 0.7, 1.3, 1.5].map {
            clicks.registerClick(at: $0, interval: 0.5)
        }
        #expect(toggles == [false, true, false, true, false, false, true])
    }

    @Test func trackpadActivationRequiresOptionAndARealGesture() {
        var activation = TrackpadActivation()

        func event(_ phase: NSEvent.Phase, modifiers: NSEvent.ModifierFlags = [.option],
                   momentum: NSEvent.Phase = [], precise: Bool = true) -> Bool {
            activation.shouldActivate(phase: phase, momentumPhase: momentum, modifiers: modifiers,
                                      hasPreciseDeltas: precise, displacement: CGPoint(x: 0, y: 3),
                                      isAutoScrolling: false)
        }

        let events = [event(.began, modifiers: []), event(.changed, modifiers: []),
                      event([], precise: false), event([]), event(.changed, momentum: .changed),
                      event(.changed), event(.changed), event(.ended), event(.began)]
        #expect(events == [false, false, false, false, false, true, false, false, true])
    }

    @Test func horizontalTrackpadGestureRequiresHorizontalScrollingOption() {
        var activation = TrackpadActivation()
        let displacement = CGPoint(x: 3, y: 0)
        let disabled = activation.shouldActivate(phase: .began, momentumPhase: [], modifiers: .option,
                                                 hasPreciseDeltas: true, displacement: displacement,
                                                 isAutoScrolling: false)
        let enabled = activation.shouldActivate(phase: .began, momentumPhase: [], modifiers: .option,
                                                 hasPreciseDeltas: true, displacement: displacement,
                                                 horizontalEnabled: true, isAutoScrolling: false)
        #expect(!disabled)
        #expect(enabled)
    }

    @MainActor
    @Test func holdModeStopsOnMatchingReleaseAndLeavesMenuActivationIndependent() {
        let app = AppDelegate()
        defer { app.stopAutoScroll() }
        app.activationMethod = .middleClickHold
        let anchor = CGPoint(x: 120, y: 140)

        app.handleMouseButton(2, type: .otherMouseDown, modifiers: [], timestamp: 0, at: anchor)
        #expect(app.originalPoint == anchor)
        app.handleMouseButton(3, type: .otherMouseUp, modifiers: [], timestamp: 1, at: anchor)
        #expect(app.isAutoScrolling)
        app.handleMouseButton(2, type: .otherMouseUp, modifiers: [], timestamp: 2, at: anchor)
        #expect(!app.isAutoScrolling)

        app.startAutoScroll(at: anchor)
        app.handleMouseButton(2, type: .otherMouseUp, modifiers: [], timestamp: 3, at: anchor)
        #expect(app.isAutoScrolling)
    }

    @MainActor
    @Test func plainMiddleClickSkipsLinksWhileExplicitShortcutCanStart() {
        let app = AppDelegate()
        defer { app.stopAutoScroll() }
        let anchor = CGPoint(x: 140, y: 150)
        app.handleMouseButton(2, type: .otherMouseDown, modifiers: [], timestamp: 0, at: anchor, isLink: true)
        #expect(!app.isAutoScrolling)

        app.activationMethod = .shiftMiddleClick
        app.handleMouseButton(2, type: .otherMouseDown, modifiers: [.shift], timestamp: 1, at: anchor, isLink: true)
        #expect(app.isAutoScrolling)
    }

    @MainActor
    @Test func leftClickPreferenceLetsOtherButtonsStopScrolling() {
        let app = AppDelegate()
        defer { app.stopAutoScroll() }
        let anchor = CGPoint(x: 140, y: 150)
        app.startAutoScroll(at: anchor)
        app.handleMouseButton(0, type: .leftMouseDown, modifiers: [], timestamp: 0, at: anchor)
        #expect(!app.isAutoScrolling)

        app.keepsScrollingOnLeftClick = true
        app.startAutoScroll(at: anchor)
        app.handleMouseButton(0, type: .leftMouseDown, modifiers: [], timestamp: 1, at: anchor)
        #expect(app.isAutoScrolling)
        app.handleMouseButton(1, type: .rightMouseDown, modifiers: [], timestamp: 2, at: anchor)
        #expect(!app.isAutoScrolling)
    }

    @MainActor
    @Test func hiddenMenuBarStillHasAllRecoveryControls() throws {
        let app = AppDelegate()
        app.hidesMenuBarIcon = true
        app.setupMenuBar()
        let statusItem = try #require(app.statusItem)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let menu = try #require(statusItem.menu)
        #expect(!statusItem.isVisible)
        let settings = try #require(menu.item(withTitle: "Settings")?.submenu)
        for title in ["Hide Menu Bar Icon", "Horizontal Scrolling", "Keep Scrolling on Left Click", "Launch at Login", "Permissions…"] {
            #expect(settings.item(withTitle: title)?.target === app)
        }
        #expect(menu.item(withTitle: "View Latest Release…")?.target === app)
        let shouldOpenWindow = app.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        #expect(!shouldOpenWindow)
        #expect(statusItem.isVisible)
        app.menuDidClose(menu)
        #expect(!statusItem.isVisible)
    }

    @MainActor
    @Test func compactMenuUpdatesSensitivityAndKeepsActivationChoicesIndependent() throws {
        let defaults = UserDefaults.standard
        let keys = ["fixedScrollSpeed", "activationMethod", "invertScrollDirection"]
        let savedValues = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, savedValues) { defaults.set(value, forKey: key) }
        }
        let app = AppDelegate()
        app.fixedScrollSpeed = .four
        app.setupMenuBar()
        let statusItem = try #require(app.statusItem)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let menu = try #require(statusItem.menu)

        let sensitivity = try #require(menu.item(withTitle: "Pointer Sensitivity"))
        let slider = try #require(sensitivity.view?.subviews.compactMap { $0 as? NSSlider }.first)
        #expect(slider.minValue == 0.1)
        let speedMenu = try #require(menu.item(withTitle: "Scroll Mode")?.submenu)
        let pointer = try #require(speedMenu.item(withTitle: "Follow Pointer"))
        let fixed = try #require(speedMenu.item(withTitle: "4 px/s"))
        #expect(speedMenu.items.suffix(2).map(\.title) == ["64 px/s", "128 px/s"])
        #expect(sensitivity.isHidden)
        try sendMenuAction(pointer)
        #expect(!sensitivity.isHidden && pointer.state == .on && fixed.state == .off)
        try sendMenuAction(fixed)
        #expect(sensitivity.isHidden && pointer.state == .off && fixed.state == .on)

        #expect(menu.item(withTitle: "Activation Methods") == nil)
        let activation = try #require(menu.item(withTitle: "Activation Method")?.submenu)
        let trackpad = try #require(activation.item(withTitle: "Option + Scroll"))
        let sideButton = try #require(activation.item(withTitle: "Mouse Button 4"))
        try sendMenuAction(sideButton)
        #expect(sideButton.state == .on && trackpad.state == .on)
        #expect(activation.item(withTitle: "Middle Click")?.state == .off)

        let settings = try #require(menu.item(withTitle: "Settings")?.submenu)
        let invert = try #require(settings.item(withTitle: "Invert Scrolling Direction"))
        try sendMenuAction(invert)
        #expect(app.isDirectionInverted && invert.state == .on)
    }

    @MainActor
    @Test func menuActionStartsAndStopsAutoScroll() throws {
        let app = RecordingAppDelegate()
        app.setupMenuBar()
        let statusItem = try #require(app.statusItem)
        defer {
            app.stopAutoScroll()
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        let startStop = try #require(statusItem.menu?.item(withTitle: "Start Auto-Scroll"))
        try sendMenuAction(startStop)
        #expect(app.isAutoScrolling && startStop.title == "Stop Auto-Scroll")
        try sendMenuAction(startStop)
        #expect(!app.isAutoScrolling && startStop.title == "Start Auto-Scroll")
    }

    @MainActor
    private func sendMenuAction(_ item: NSMenuItem) throws {
        let action = try #require(item.action)
        let target = try #require(item.target as? NSObject)
        try #require(target.responds(to: action))
        _ = target.perform(action, with: item)
    }

    @MainActor
    @Test func aboutMenuOpensANonmodalPanel() throws {
        let app = AppDelegate()
        app.setupMenuBar()
        let statusItem = try #require(app.statusItem)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let item = try #require(statusItem.menu?.item(withTitle: "About Scrollapp"))
        let application = NSApplication.shared
        let visibleWindows = application.windows.filter(\.isVisible)
        let existingModalWindow = application.modalWindow
        try sendMenuAction(item)
        let panel = try #require(application.windows.first { $0.isVisible && !visibleWindows.contains($0) })
        defer { panel.close() }
        #expect(panel !== application.modalWindow)
        #expect(application.modalWindow === existingModalWindow)

        func textViews(in view: NSView) -> [NSTextView] {
            if let textView = view as? NSTextView { return [textView] }
            return view.subviews.flatMap { textViews(in: $0) }
        }

        let content = try #require(panel.contentView)
        let credits = try #require(textViews(in: content).first { $0.string.contains("Website") }?.textStorage)
        var destinations: [String] = []
        credits.enumerateAttribute(.link, in: NSRange(location: 0, length: credits.length)) { value, _, _ in
            if let url = value as? URL { destinations.append(url.absoluteString) }
        }
        #expect(destinations == ["https://scrollapp.app/", "https://github.com/fromis-9/scrollapp"])
    }

    @MainActor
    @Test func anchorIsVisibleClickThroughAndClosesOnStop() throws {
        let application = NSApplication.shared
        let anchor = ScrollIndicator(style: .anchor)
        defer { anchor.hide() }
        let point = CGPoint(x: 240, y: 260)
        anchor.show(at: point, horizontalEnabled: false)

        let panel = try #require(application.windows.compactMap { $0 as? NSPanel }.first {
            $0.frame.midX == point.x && $0.frame.midY == point.y && $0.ignoresMouseEvents
        })
        let glyph = try #require(panel.contentView)
        #expect(panel.isVisible)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.isOpaque && !panel.hasShadow)
        #expect(panel.backgroundColor == .clear)
        #expect(glyph.accessibilityLabel() == "Vertical auto-scroll anchor")
        anchor.update(horizontalEnabled: true)
        #expect(glyph.accessibilityLabel() == "Horizontal and vertical auto-scroll anchor")
        anchor.updateDirection(ScrollDirection(horizontal: -1, vertical: 1))
        #expect(glyph.accessibilityLabel() == "Horizontal and vertical auto-scroll anchor, scrolling up and left")
        anchor.hide()
        #expect(!panel.isVisible)
    }

    @MainActor
    @Test func brandBlueMovesWithTheActiveArrow() throws {
        let anchor = ScrollIndicator(style: .anchor)
        defer { anchor.hide() }
        let point = CGPoint(x: 250, y: 270)
        anchor.show(at: point, horizontalEnabled: false)
        let panel = try #require(NSApplication.shared.windows.first {
            $0.isVisible && $0.ignoresMouseEvents && $0.frame.midX == point.x && $0.frame.midY == point.y
        })
        let glyph = try #require(panel.contentView)

        func blueRows() throws -> [Int] {
            let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil,
                                                       pixelsWide: Int(glyph.bounds.width),
                                                       pixelsHigh: Int(glyph.bounds.height),
                                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                       isPlanar: false, colorSpaceName: .deviceRGB,
                                                       bytesPerRow: 0, bitsPerPixel: 0))
            let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.cgContext.clear(glyph.bounds)
            glyph.draw(glyph.bounds)
            NSGraphicsContext.restoreGraphicsState()
            #expect(bitmap.colorAt(x: 6, y: 6)?.alphaComponent == 0)
            return (0..<bitmap.pixelsHigh).filter { y in
                (0..<bitmap.pixelsWide).contains { x in
                    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
                    return color.alphaComponent > 0.5 && color.redComponent < 0.2
                        && abs(color.greenComponent - 128.0 / 255) < 0.12 && color.blueComponent > 0.8
                }
            }
        }

        #expect(try blueRows().isEmpty)
        anchor.updateDirection(ScrollDirection(vertical: 1))
        let up = try #require(blueRows().first)
        anchor.updateDirection(ScrollDirection(vertical: -1))
        let down = try #require(blueRows().first)
        #expect(abs(up - down) >= 4)
    }

    @MainActor
    @Test func followPointerShowsOnlyTheMovingIndicator() throws {
        let app = RecordingAppDelegate()
        defer { app.stopAutoScroll() }
        let screen = try #require(NSScreen.main?.frame)
        let start = CGPoint(x: screen.midX, y: screen.midY)
        let above = CGPoint(x: start.x + 25, y: start.y + 35)
        let below = CGPoint(x: start.x - 25, y: start.y - 35)
        app.startAutoScroll(at: start)
        app.performScroll(at: above)

        let windows = NSApplication.shared.windows.filter { $0.isVisible && $0.ignoresMouseEvents }
        let anchorFrame = ScrollIndicator.Style.anchor.frame(at: start)
        #expect(!windows.contains { $0.frame == anchorFrame })
        let cursor = try #require(windows.first { $0.frame == ScrollIndicator.Style.pointer.frame(at: above, screen: screen) })
        let glyph = try #require(cursor.contentView)
        #expect(glyph.accessibilityLabel() == "Vertical scroll cursor, scrolling up")

        let wobble = CGPoint(x: above.x, y: above.y - 4)
        app.performScroll(at: wobble)
        #expect(glyph.accessibilityLabel() == "Vertical scroll cursor, scrolling up")

        let turn = CGPoint(x: above.x, y: above.y - 16)
        let previousDeltaCount = app.verticalDeltas.count
        for _ in 0..<20 {
            app.performScroll(at: turn)
        }
        #expect(glyph.accessibilityLabel() == "Vertical scroll cursor, scrolling down")
        let reversedDeltas = app.verticalDeltas.dropFirst(previousDeltaCount)
        #expect(!reversedDeltas.isEmpty && reversedDeltas.allSatisfy { $0 < 0 })

        app.performScroll(at: below)
        #expect(cursor.frame == ScrollIndicator.Style.pointer.frame(at: below, screen: screen))
        #expect(glyph.accessibilityLabel() == "Vertical scroll cursor, scrolling down")
        #expect(app.originalPoint == start)

        app.stopAutoScroll()
        #expect(!cursor.isVisible)
    }

    @MainActor
    @Test func scrollCursorFlipsAtDisplayEdgesToStayVisible() {
        let screen = CGRect(x: -800, y: -100, width: 800, height: 600)
        let pointer = CGPoint(x: -1.25, y: -98.25)
        let badge = ScrollIndicator.Style.pointer.frame(at: pointer, screen: screen)
        #expect(screen.contains(badge))
        #expect(badge.maxX < pointer.x && badge.minY > pointer.y)
        #expect(badge.origin.x == badge.origin.x.rounded() && badge.origin.y == badge.origin.y.rounded())
    }
}

private final class RecordingAppDelegate: AppDelegate {
    private(set) var verticalDeltas: [Int64] = []
    private(set) var horizontalDeltas: [Int64] = []

    override func postScrollEvent(_ event: CGEvent) {
        verticalDeltas.append(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        horizontalDeltas.append(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
    }

    override func showTrackpadModeNotification() {}
}
