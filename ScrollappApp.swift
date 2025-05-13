//
//  ScrollappApp.swift
//  Scrollapp
//

import SwiftUI
import Cocoa

@main
struct ScrollappApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No window needed
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isAutoScrolling = false
    var scrollTimer: Timer?
    var originalPoint: CGPoint?
    var globalMonitor: Any?
    var localMonitor: Any?
    var mouseMoveMonitor: Any?
    var scrollCursor: NSCursor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        createScrollCursor()
        setupMiddleClickListeners()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopAutoScroll()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.up.and.down.circle", accessibilityDescription: "Scrollapp")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About Scrollapp", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func createScrollCursor() {
        let size = CGSize(width: 20, height: 20)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.clear.set()
        NSRect(x: 0, y: 0, width: size.width, height: size.height).fill()

        NSColor.systemBlue.withAlphaComponent(0.6).setFill()
        NSBezierPath(ovalIn: NSRect(x: 4, y: 4, width: 12, height: 12)).fill()

        NSColor.white.setStroke()
        let upArrow = NSBezierPath()
        upArrow.move(to: NSPoint(x: 10, y: 2))
        upArrow.line(to: NSPoint(x: 10, y: 0))
        upArrow.line(to: NSPoint(x: 8, y: 2))
        upArrow.move(to: NSPoint(x: 10, y: 0))
        upArrow.line(to: NSPoint(x: 12, y: 2))
        upArrow.lineWidth = 1
        upArrow.stroke()

        let downArrow = NSBezierPath()
        downArrow.move(to: NSPoint(x: 10, y: 18))
        downArrow.line(to: NSPoint(x: 10, y: 20))
        downArrow.line(to: NSPoint(x: 8, y: 18))
        downArrow.move(to: NSPoint(x: 10, y: 20))
        downArrow.line(to: NSPoint(x: 12, y: 18))
        downArrow.lineWidth = 1
        downArrow.stroke()
        image.unlockFocus()

        scrollCursor = NSCursor(image: image, hotSpot: NSPoint(x: 10, y: 10))
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Scrollapp"
        alert.informativeText = "Scrollapp enables auto-scrolling on macOS.\n\nUse middle-click to activate auto-scrolling, then move your mouse up or down to control scroll speed and direction."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func setupMiddleClickListeners() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self = self, event.buttonNumber == 2 else { return }
            self.isAutoScrolling ? self.stopAutoScroll() : self.startAutoScroll(at: NSEvent.mouseLocation)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self = self, event.buttonNumber == 2 else { return event }
            self.isAutoScrolling ? self.stopAutoScroll() : self.startAutoScroll(at: NSEvent.mouseLocation)
            return event
        }
    }

    func startAutoScroll(at point: NSPoint) {
        stopAutoScroll()
        originalPoint = point
        isAutoScrolling = true
        NSCursor.hide()
        scrollCursor?.set()

        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.performScroll()
            self?.scrollCursor?.set() // keep forcing cursor
        }
        RunLoop.current.add(scrollTimer!, forMode: .common)
    }

    func performScroll() {
        guard let start = originalPoint else { return }
        let current = NSEvent.mouseLocation
        let deltaY = current.y - start.y

        let deadZone: CGFloat = 5.0
        let direction = deltaY > 0 ? -1.0 : 1.0
        let distance = max(0, abs(deltaY) - deadZone)

        // Quadratic acceleration: scrollSpeed grows faster as distance increases
        let acceleration = pow(distance / 50, 2.0) // scale distance into a nice curve
        let maxScrollSpeed: CGFloat = 30.0
        let scrollSpeed = min(acceleration * 2.5, maxScrollSpeed) // scaled + capped

        let finalAmount = direction * scrollSpeed

        if abs(finalAmount) < 0.5 {
            return // don't scroll unless meaningful
        }

        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                    units: .pixel,
                                    wheelCount: 1,
                                    wheel1: Int32(finalAmount),
                                    wheel2: 0,
                                    wheel3: 0) {
            scrollEvent.flags = .maskNonCoalesced
            scrollEvent.post(tap: .cgSessionEventTap)
        }
    }

    func stopAutoScroll() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        NSCursor.unhide()
        isAutoScrolling = false
        originalPoint = nil
    }
}
