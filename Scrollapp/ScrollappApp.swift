//
//  ScrollappApp.swift
//  Scrollapp
//

import SwiftUI
import Cocoa
import UserNotifications

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
    var optionKeyMonitor: Any?
    var scrollMonitor: Any?
    var clickMonitor: Any?
    var scrollCursor: NSCursor?
    var isTrackpadMode = false
    var lastScrollTime: Date?
    var scrollDetectionWindow = [CGFloat]()
    var isDirectionInverted = false  // Default is now "up scrolls up"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load user preferences
        isDirectionInverted = UserDefaults.standard.bool(forKey: "invertScrollDirection")
        
        setupMenuBar()
        createScrollCursor()
        setupMiddleClickListeners()
        setupTrackpadActivation()
        
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
        menu.addItem(NSMenuItem(title: "Start/Stop Auto-Scroll", action: #selector(toggleTrackpadMode), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // Add inverted direction toggle option - reworded to match new default
        let invertItem = NSMenuItem(title: "Invert Scrolling Direction", action: #selector(toggleDirectionInversion), keyEquivalent: "")
        invertItem.state = isDirectionInverted ? .on : .off
        menu.addItem(invertItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Scrollapp", action: #selector(showAbout), keyEquivalent: ""))
        
        let methodsMenu = NSMenu()
        let methodsItem = NSMenuItem(title: "Activation Methods", action: nil, keyEquivalent: "")
        methodsItem.submenu = methodsMenu
        
        methodsMenu.addItem(NSMenuItem(title: "Middle-click - Toggle auto-scroll (mouse)", action: nil, keyEquivalent: ""))
        methodsMenu.addItem(NSMenuItem(title: "Option + Scroll - Start auto-scroll (trackpad)", action: nil, keyEquivalent: ""))
        methodsMenu.addItem(NSMenuItem(title: "Menu Bar - Use the menu option above", action: nil, keyEquivalent: ""))
        methodsMenu.addItem(NSMenuItem(title: "Click - Stop auto-scroll", action: nil, keyEquivalent: ""))
        
        menu.addItem(methodsItem)
        
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
        
        // Flipped the default direction - now moving up scrolls up by default
        let directionMultiplier = isDirectionInverted ? 1.0 : -1.0  // Inverted the multiplier
        let direction = (deltaY > 0 ? -1.0 : 1.0) * directionMultiplier
        
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

    @objc func toggleTrackpadMode() {
        if isAutoScrolling {
            stopAutoScroll()
        } else {
            startTrackpadAutoScroll()
        }
    }

    func startTrackpadAutoScroll() {
        stopAutoScroll() // Clear any existing state
        
        isTrackpadMode = true
        originalPoint = NSEvent.mouseLocation
        isAutoScrolling = true
        
        // Show custom cursor
        NSCursor.hide()
        scrollCursor?.set()
        
        // Start timer for scrolling
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.performScroll()
            self?.scrollCursor?.set() // keep forcing cursor
        }
        RunLoop.current.add(scrollTimer!, forMode: .common)
        
        // Show feedback to user
        showTrackpadModeNotification()
    }

    func showTrackpadModeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Auto-Scroll Active"
        content.body = "Move cursor to control scrolling. Click anywhere to exit."
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: "com.scrollapp.trackpadmode",
            content: content,
            trigger: nil  // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error.localizedDescription)")
            }
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Scrollapp"
        
        alert.informativeText = "Scrollapp enables auto-scrolling on macOS.\n\nHow to activate:\n• Mouse: Middle-click anywhere\n• Trackpad: Hold Option key and scroll with two fingers\n• Menu: Use the menu bar icon and select 'Start/Stop Auto-Scroll'\n\nHow to stop:\n• Click anywhere to exit auto-scroll mode\n• Middle-click again (if using a mouse)\n\nWhile active, move your cursor to control scroll speed and direction."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func stopAutoScroll() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        NSCursor.unhide()
        isAutoScrolling = false
        isTrackpadMode = false
        originalPoint = nil
    }

    func setupTrackpadActivation() {
        // Detect Option key via flagsChanged
        optionKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            
            // Detect Option key
            let optionKeyFlag = NSEvent.ModifierFlags.option
            
            // If Option key is pressed and we're not already scrolling
            if event.modifierFlags.contains(optionKeyFlag) && !self.isAutoScrolling {
                // Start a timer to detect if two-finger scroll happens while Option is pressed
                self.lastScrollTime = Date()
                
                // If we detect a scroll within 1 second of Option press, activate auto-scroll
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.lastScrollTime = nil
                }
            }
        }
        
        // Detect two-finger scroll while Option is pressed
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self,
                  let lastScrollTime = self.lastScrollTime,
                  Date().timeIntervalSince(lastScrollTime) < 1.0,
                  !self.isAutoScrolling,
                  abs(event.deltaY) > 0.1 else { return }
            
            // Option + scroll detected, activate auto-scroll
            self.startTrackpadAutoScroll()
        }
        
        // Monitor for clicks to exit auto-scroll mode
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self = self, self.isAutoScrolling else { return }
            
            // For middle clicks (buttonNumber == 2), let the middle click handler deal with it
            if event.type == .otherMouseDown && event.buttonNumber == 2 {
                return // Skip - let the middle click monitors handle this
            }
            
            // For all other clicks, stop auto-scroll
            self.stopAutoScroll()
        }
    }

    @objc func toggleDirectionInversion() {
        // Toggle the inversion state
        isDirectionInverted = !isDirectionInverted
        
        // Save preference
        UserDefaults.standard.set(isDirectionInverted, forKey: "invertScrollDirection")
        
        // Update menu item state
        if let menu = statusItem.menu,
           let invertItem = menu.items.first(where: { $0.action == #selector(toggleDirectionInversion) }) {
            invertItem.state = isDirectionInverted ? .on : .off
        }
        
        // No notification - removed
    }
}
