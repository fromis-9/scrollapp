//
//  ScrollappApp.swift
//  Scrollapp
//

import SwiftUI
import Cocoa
import UserNotifications
import ServiceManagement

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
    var launchAtLogin = false        // Track launch at login state
    var scrollSensitivity: Double = 1.0  // Default sensitivity multiplier
    var activationMethod: ActivationMethod = .middleClick  // Default activation method
    
    enum ActivationMethod: String, CaseIterable {
        case middleClick = "Middle Click"
        case shiftMiddleClick = "Shift + Middle Click"
        case cmdMiddleClick = "Cmd + Middle Click"
        case optionMiddleClick = "Option + Middle Click"
        case button4 = "Mouse Button 4"
        case button5 = "Mouse Button 5"
        case doubleMiddleClick = "Double Middle Click"
        
        var buttonNumber: Int? {
            switch self {
            case .middleClick, .shiftMiddleClick, .cmdMiddleClick, .optionMiddleClick, .doubleMiddleClick:
                return 2
            case .button4:
                return 3
            case .button5:
                return 4
            }
        }
        
        var requiresModifier: Bool {
            switch self {
            case .shiftMiddleClick, .cmdMiddleClick, .optionMiddleClick:
                return true
            default:
                return false
            }
        }
        
        var modifierFlags: NSEvent.ModifierFlags? {
            switch self {
            case .shiftMiddleClick:
                return .shift
            case .cmdMiddleClick:
                return .command
            case .optionMiddleClick:
                return .option
            default:
                return nil
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load user preferences
        isDirectionInverted = UserDefaults.standard.bool(forKey: "invertScrollDirection")
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        scrollSensitivity = UserDefaults.standard.double(forKey: "scrollSensitivity")
        if scrollSensitivity == 0 { scrollSensitivity = 1.0 } // Default if not set
        
        // Load activation method
        if let savedMethod = UserDefaults.standard.string(forKey: "activationMethod"),
           let method = ActivationMethod(rawValue: savedMethod) {
            activationMethod = method
        }
        
        // Set initial launch at login state based on saved preference
        updateLoginItemState()
        
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
        
        // Add sensitivity slider
        let sensitivityItem = NSMenuItem(title: String(format: "Scroll Speed: %.1fx", scrollSensitivity), action: nil, keyEquivalent: "")
        let sensitivityView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 30))
        
        let slider = NSSlider(frame: NSRect(x: 20, y: 5, width: 150, height: 20))
        slider.minValue = 0.2
        slider.maxValue = 3.0
        slider.doubleValue = scrollSensitivity
        slider.target = self
        slider.action = #selector(sensitivityChanged(_:))
        slider.isContinuous = true
        
        let label = NSTextField(labelWithString: String(format: "%.1fx", scrollSensitivity))
        label.frame = NSRect(x: 180, y: 5, width: 50, height: 20)
        label.alignment = .center
        label.tag = 100 // Tag to find it later
        
        sensitivityView.addSubview(slider)
        sensitivityView.addSubview(label)
        sensitivityItem.view = sensitivityView
        menu.addItem(sensitivityItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add activation method submenu
        let activationMenu = NSMenu()
        let activationItem = NSMenuItem(title: "Activation Method", action: nil, keyEquivalent: "")
        activationItem.submenu = activationMenu
        
        for method in ActivationMethod.allCases {
            let methodItem = NSMenuItem(title: method.rawValue, action: #selector(selectActivationMethod(_:)), keyEquivalent: "")
            methodItem.representedObject = method
            methodItem.state = (method == activationMethod) ? .on : .off
            activationMenu.addItem(methodItem)
        }
        
        menu.addItem(activationItem)
        
        // Add inverted direction toggle option - reworded to match new default
        let invertItem = NSMenuItem(title: "Invert Scrolling Direction", action: #selector(toggleDirectionInversion), keyEquivalent: "")
        invertItem.state = isDirectionInverted ? .on : .off
        menu.addItem(invertItem)
        
        // Add launch at login toggle
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = launchAtLogin ? .on : .off
        menu.addItem(launchItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Scrollapp", action: #selector(showAbout), keyEquivalent: ""))
        
        let methodsMenu = NSMenu()
        let methodsItem = NSMenuItem(title: "Activation Methods", action: nil, keyEquivalent: "")
        methodsItem.submenu = methodsMenu
        
        methodsMenu.addItem(NSMenuItem(title: "Mouse - Configurable button/modifier (see Activation Method)", action: nil, keyEquivalent: ""))
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

    var lastClickTime: Date?
    var clickCount = 0
    
    func setupMiddleClickListeners() {
        // Remove existing monitors
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        guard let buttonNumber = activationMethod.buttonNumber else { return }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self = self, event.buttonNumber == buttonNumber else { return }
            self.handleMouseClick(event, at: NSEvent.mouseLocation)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
            guard let self = self, event.buttonNumber == buttonNumber else { return event }
            self.handleMouseClick(event, at: NSEvent.mouseLocation)
            return event
        }
    }
    
    func handleMouseClick(_ event: NSEvent, at location: NSPoint) {
        // Check if this activation method requires modifier keys
        if activationMethod.requiresModifier {
            guard let requiredModifier = activationMethod.modifierFlags,
                  event.modifierFlags.contains(requiredModifier) else { return }
        }
        
        // Handle double-click detection for double middle click
        if activationMethod == .doubleMiddleClick {
            let now = Date()
            if let lastClick = lastClickTime, now.timeIntervalSince(lastClick) < 0.5 {
                clickCount += 1
                if clickCount >= 2 {
                    // Double click detected
                    clickCount = 0
                    lastClickTime = nil
                    isAutoScrolling ? stopAutoScroll() : startAutoScroll(at: location)
                }
            } else {
                clickCount = 1
                lastClickTime = now
                // Reset click count after timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.clickCount = 0
                    self?.lastClickTime = nil
                }
            }
        } else {
            // Single click activation
            isAutoScrolling ? stopAutoScroll() : startAutoScroll(at: location)
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
        let maxScrollSpeed: CGFloat = 30.00
        let scrollSpeed = min(acceleration * 2.5, maxScrollSpeed) // scaled + capped

        // Apply sensitivity multiplier with exponential scaling for values < 1.0
        // This makes slower speeds MUCH slower but still usable
        let adjustedSensitivity: CGFloat
        if scrollSensitivity < 1.0 {
            // Exponential scaling for slow speeds, but not too extreme
            // 0.1 becomes ~0.03, 0.2 becomes ~0.08, 0.5 becomes ~0.35
            adjustedSensitivity = CGFloat(pow(scrollSensitivity, 1.5))
        } else {
            // Linear scaling for faster speeds
            adjustedSensitivity = CGFloat(scrollSensitivity)
        }
        
        let finalAmount = direction * scrollSpeed * adjustedSensitivity

        // Dynamic threshold based on sensitivity - allow very slow scrolling at low sensitivities
        let threshold = min(0.1, adjustedSensitivity * 0.5)
        if abs(finalAmount) < threshold {
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

    @objc func sensitivityChanged(_ sender: NSSlider) {
        scrollSensitivity = sender.doubleValue
        UserDefaults.standard.set(scrollSensitivity, forKey: "scrollSensitivity")
        
        // Update the label and menu item title
        if let sensitivityItem = statusItem.menu?.items.first(where: { $0.title.starts(with: "Scroll Speed") }) {
            sensitivityItem.title = String(format: "Scroll Speed: %.1fx", scrollSensitivity)
            
            if let view = sensitivityItem.view,
               let label = view.viewWithTag(100) as? NSTextField {
                label.stringValue = String(format: "%.1fx", scrollSensitivity)
            }
        }
    }
    
    @objc func selectActivationMethod(_ sender: NSMenuItem) {
        guard let method = sender.representedObject as? ActivationMethod else { return }
        
        activationMethod = method
        UserDefaults.standard.set(method.rawValue, forKey: "activationMethod")
        
        // Update menu item states
        if let activationItem = statusItem.menu?.items.first(where: { $0.title == "Activation Method" }),
           let submenu = activationItem.submenu {
            for item in submenu.items {
                item.state = (item.representedObject as? ActivationMethod == method) ? .on : .off
            }
        }
        
        // Restart mouse listeners with new configuration
        setupMiddleClickListeners()
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Scrollapp"
        
        alert.informativeText = "Scrollapp enables auto-scrolling on macOS.\n\nHow to activate:\n• Mouse: Configurable button/modifier (see Activation Method in menu)\n• Trackpad: Hold Option key and scroll with two fingers\n• Menu: Use the menu bar icon and select 'Start/Stop Auto-Scroll'\n\nHow to stop:\n• Click anywhere to exit auto-scroll mode\n• Use your configured activation method again\n\nWhile active, move your cursor to control scroll speed and direction.\n\nAdjust scroll speed using the slider in the menu bar (0.2x - 3.0x).\nSpeeds below 1.0x are exponentially slower for fine control.\n\nConfigure your preferred activation method in the 'Activation Method' submenu to avoid conflicts with browser link opening."
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
            
            // Don't stop auto-scroll for the configured activation button
            if event.type == .otherMouseDown,
               let activationButtonNumber = self.activationMethod.buttonNumber,
               event.buttonNumber == activationButtonNumber {
                return // Skip - let the activation method handler deal with it
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

    @objc func toggleLaunchAtLogin() {
        launchAtLogin = !launchAtLogin
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        updateLoginItemState()
        
        // Update menu item state
        if let launchItem = statusItem.menu?.items.first(where: { $0.title == "Launch at Login" }) {
            launchItem.state = launchAtLogin ? .on : .off
        }
    }

    func updateLoginItemState() {
        if #available(macOS 13.0, *) {
            // Use the newer ServiceManagement API for macOS 13+
            let service = SMAppService.mainApp
            do {
                if launchAtLogin {
                    if service.status != .enabled {
                        try service.register()
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                }
            } catch {
                print("Failed to update login item: \(error.localizedDescription)")
            }
        } else {
            // Use the older SMLoginItemSetEnabled API for macOS 11.0-12.x
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, launchAtLogin)
                if !success {
                    print("Failed to update login item using legacy API")
                }
            }
        }
    }
}
