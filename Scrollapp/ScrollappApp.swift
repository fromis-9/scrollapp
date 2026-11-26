//
//  ScrollappApp.swift
//  Scrollapp
//

import SwiftUI
import Cocoa
import UserNotifications
import ApplicationServices

@main
struct ScrollappApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No window needed
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var isAutoScrolling = false
    var scrollTimer: Timer?
    var originalPoint: CGPoint?
    var globalMouseMonitor: Any?
    var localMouseMonitor: Any?
    var scrollMonitor: Any?
    var localScrollMonitor: Any?
    private let scrollAnchor = ScrollIndicator(style: .anchor)
    private let scrollCursor = ScrollIndicator(style: .pointer)
    private var scrollMenuItem: NSMenuItem?
    private var sensitivityItem: NSMenuItem?
    private var sensitivityValueLabel: NSTextField?
    private var heldButton: Int?
    private var showsScrollIndicators = true
    private var horizontalScrollingEnabled = false
    var trackpadActivationEnabled = true
    var keepsScrollingOnLeftClick = false
    var hidesMenuBarIcon = false
    private var scrollArea: ScrollArea?
    private var scrollPosition: ScrollPosition?
    private var scrollMotion = ScrollMotion()
    private var doubleClick = DoubleClickActivation()
    private var trackpadActivation = TrackpadActivation()
    var isDirectionInverted = false  // Default is now "up scrolls up"
    var scrollSensitivity: Double = 1.0  // Default sensitivity multiplier
    var fixedScrollSpeed: FixedScrollSpeed = .off
    var activationMethod: ActivationMethod = .middleClick  // Default activation method

    private var allowsHorizontalScrolling: Bool { horizontalScrollingEnabled && fixedScrollSpeed == .off }

    enum FixedScrollSpeed: Int, CaseIterable {
        case off = 0
        case one = 1
        case two = 2
        case four = 4
        case eight = 8
        case sixteen = 16
        case thirtyTwo = 32
        case sixtyFour = 64
        case oneHundredTwentyEight = 128

        var menuTitle: String { self == .off ? "Follow Pointer" : "\(rawValue) px/s" }
        var timerInterval: TimeInterval { self == .off ? 0.01 : 1 / Double(rawValue) }
    }
    
    enum ActivationMethod: String, CaseIterable {
        case middleClick = "Middle Click"
        case middleClickHold = "Middle Click (Hold)"
        case shiftMiddleClick = "Shift + Middle Click"
        case cmdMiddleClick = "Cmd + Middle Click"
        case optionMiddleClick = "Option + Middle Click"
        case button4 = "Mouse Button 4"
        case button5 = "Mouse Button 5"
        case doubleMiddleClick = "Double Middle Click"
        
        var buttonNumber: Int {
            switch self {
            case .middleClick, .middleClickHold, .shiftMiddleClick, .cmdMiddleClick, .optionMiddleClick, .doubleMiddleClick:
                return 2
            case .button4:
                return 3
            case .button5:
                return 4
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
        let launchedAtLogin = LoginAtStartup.wasLaunchedAtLogin
        showsScrollIndicators = UserDefaults.standard.object(forKey: "showsScrollAnchor") as? Bool ?? true
        horizontalScrollingEnabled = UserDefaults.standard.bool(forKey: "horizontalScrollingEnabled")
        trackpadActivationEnabled = UserDefaults.standard.object(forKey: "trackpadActivationEnabled") as? Bool ?? true
        keepsScrollingOnLeftClick = UserDefaults.standard.bool(forKey: "keepsScrollingOnLeftClick")
        hidesMenuBarIcon = UserDefaults.standard.bool(forKey: "hidesMenuBarIcon")
        fixedScrollSpeed = FixedScrollSpeed(rawValue: UserDefaults.standard.integer(forKey: "fixedScrollSpeed")) ?? .off
        let savedSensitivity = UserDefaults.standard.double(forKey: "scrollSensitivity")
        if ScrollMotion.sensitivityRange.contains(savedSensitivity) {
            scrollSensitivity = savedSensitivity
        }
        
        // Load activation method
        if let savedMethod = UserDefaults.standard.string(forKey: "activationMethod"),
           let method = ActivationMethod(rawValue: savedMethod) {
            activationMethod = method
        }
        
        if !isLaunchingForUITests {
            do {
                try LoginAtStartup.restoreRegistration()
            } catch {
                NSLog("Scrollapp couldn't restore launch at login: %@", error.localizedDescription)
            }
            checkAccessibilityPermissions()
        }
        
        setupMenuBar()
        setupMouseMonitors()
        setupTrackpadActivation()
        if hidesMenuBarIcon && !launchedAtLogin { revealMenuBarMenu() }
        
        if !isLaunchingForUITests {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private var isLaunchingForUITests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["SCROLLAPP_UI_TESTING"] == "1"
        #else
        false
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopAutoScroll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if hidesMenuBarIcon { revealMenuBarMenu() }
        return false
    }

    func menuDidClose(_ menu: NSMenu) {
        if menu === statusItem?.menu, hidesMenuBarIcon { statusItem.isVisible = false }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.item(withTitle: "Launch at Login")?.state = LoginAtStartup.menuState
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        let menu = NSMenu()
        menu.delegate = self
        let scrollItem = NSMenuItem(title: "Start Auto-Scroll", action: #selector(toggleTrackpadMode), keyEquivalent: "")
        scrollItem.target = self
        scrollMenuItem = scrollItem
        menu.addItem(scrollItem)
        menu.addItem(NSMenuItem.separator())
        
        let sensitivityItem = NSMenuItem(title: "Pointer Sensitivity", action: nil, keyEquivalent: "")
        let sensitivityView = NSView(frame: NSRect(x: 0, y: 0, width: 224, height: 47))
        let sensitivityLabel = NSTextField(labelWithString: sensitivityItem.title)
        sensitivityLabel.frame = NSRect(x: 22, y: 25, width: 145, height: 17)

        let slider = NSSlider(frame: NSRect(x: 19, y: 5, width: 186, height: 18))
        slider.setAccessibilityLabel(sensitivityItem.title)
        slider.minValue = ScrollMotion.sensitivityRange.lowerBound
        slider.maxValue = ScrollMotion.sensitivityRange.upperBound
        slider.doubleValue = scrollSensitivity
        slider.target = self
        slider.action = #selector(sensitivityChanged(_:))
        slider.isContinuous = true
        
        let valueLabel = NSTextField(labelWithString: String(format: "%.1fx", scrollSensitivity))
        valueLabel.frame = NSRect(x: 157, y: 25, width: 45, height: 17)
        valueLabel.alignment = .right
        sensitivityView.addSubview(sensitivityLabel)
        sensitivityView.addSubview(valueLabel)
        sensitivityView.addSubview(slider)
        sensitivityItem.view = sensitivityView
        sensitivityItem.isHidden = fixedScrollSpeed != .off
        self.sensitivityItem = sensitivityItem
        sensitivityValueLabel = valueLabel
        menu.addItem(sensitivityItem)

        let fixedSpeedItem = NSMenuItem(title: "Scroll Mode", action: nil, keyEquivalent: "")
        let fixedSpeedMenu = NSMenu()
        for speed in FixedScrollSpeed.allCases {
            let item = NSMenuItem(title: speed.menuTitle, action: #selector(selectFixedScrollSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.tag = speed.rawValue
            item.state = speed == fixedScrollSpeed ? .on : .off
            fixedSpeedMenu.addItem(item)
        }
        fixedSpeedItem.submenu = fixedSpeedMenu
        menu.addItem(fixedSpeedItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add activation method submenu
        let activationMenu = NSMenu()
        let activationItem = NSMenuItem(title: "Activation Method", action: nil, keyEquivalent: "")
        activationItem.submenu = activationMenu
        
        for method in ActivationMethod.allCases {
            let methodItem = NSMenuItem(title: method.rawValue, action: #selector(selectActivationMethod(_:)), keyEquivalent: "")
            methodItem.target = self
            methodItem.representedObject = method
            methodItem.state = (method == activationMethod) ? .on : .off
            activationMenu.addItem(methodItem)
        }
        activationMenu.addItem(NSMenuItem.separator())
        addToggle("Option + Scroll", action: #selector(toggleTrackpadActivation(_:)),
                  enabled: trackpadActivationEnabled, to: activationMenu)
        menu.addItem(activationItem)

        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()
        settingsMenu.delegate = self
        addToggle("Horizontal Scrolling", action: #selector(toggleHorizontalScrolling(_:)),
                  enabled: horizontalScrollingEnabled, to: settingsMenu)
        addToggle("Invert Scrolling Direction", action: #selector(toggleDirectionInversion(_:)),
                  enabled: isDirectionInverted, to: settingsMenu)
        addToggle("Show Auto-Scroll Indicators", action: #selector(toggleScrollIndicators(_:)),
                  enabled: showsScrollIndicators, to: settingsMenu)
        addToggle("Keep Scrolling on Left Click", action: #selector(toggleKeepsScrollingOnLeftClick(_:)),
                  enabled: keepsScrollingOnLeftClick, to: settingsMenu)
        settingsMenu.addItem(NSMenuItem.separator())
        addToggle("Hide Menu Bar Icon", action: #selector(toggleMenuBarVisibility(_:)),
                  enabled: hidesMenuBarIcon, to: settingsMenu)
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LoginAtStartup.menuState
        settingsMenu.addItem(launchItem)
        let permissionsItem = NSMenuItem(title: "Permissions…", action: #selector(showPermissions), keyEquivalent: "")
        permissionsItem.target = self
        settingsMenu.addItem(permissionsItem)
        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        let aboutItem = NSMenuItem(title: "About Scrollapp", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        let updatesItem = NSMenuItem(title: "View Latest Release…", action: #selector(openReleases), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        statusItem.isVisible = !hidesMenuBarIcon
        updateScrollFeedback()
    }

    private func addToggle(_ title: String, action: Selector, enabled: Bool, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = enabled ? .on : .off
        menu.addItem(item)
    }

    private func revealMenuBarMenu() {
        guard let statusItem, !statusItem.isVisible else { return }
        statusItem.isVisible = true
        DispatchQueue.main.async { [weak self] in
            guard let self, hidesMenuBarIcon, statusItem.isVisible,
                  let menu = statusItem.menu, let button = statusItem.button else { return }
            menu.popUp(positioning: nil, at: .zero, in: button)
            if hidesMenuBarIcon { statusItem.isVisible = false }
        }
    }

    private func setupMouseMonitors() {
        let activationEvents: NSEvent.EventTypeMask = [.otherMouseDown, .otherMouseUp]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: activationEvents.union([.leftMouseDown, .rightMouseDown])
        ) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: activationEvents) { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }
    }

    private func handleMouseEvent(_ event: NSEvent) {
        var isLink = false
        if !isAutoScrolling, activationMethod == .middleClick,
           event.type == .otherMouseDown, event.buttonNumber == activationMethod.buttonNumber,
           let point = event.cgEvent?.location {
            isLink = LinkHitTest.containsLink(at: point)
        }
        handleMouseButton(event.buttonNumber, type: event.type, modifiers: event.modifierFlags,
                          timestamp: event.timestamp, at: NSEvent.mouseLocation, isLink: isLink)
    }

    func handleMouseButton(_ button: Int, type: NSEvent.EventType, modifiers: NSEvent.ModifierFlags,
                           timestamp: TimeInterval, at location: NSPoint, isLink: Bool = false) {
        if type == .otherMouseUp {
            if button == heldButton { stopAutoScroll() }
            return
        }

        guard type == .otherMouseDown, button == activationMethod.buttonNumber else {
            if isAutoScrolling && (type != .leftMouseDown || !keepsScrollingOnLeftClick) { stopAutoScroll() }
            return
        }

        if !isAutoScrolling, activationMethod == .middleClick, isLink { return }

        if let requiredModifier = activationMethod.modifierFlags,
           !modifiers.contains(requiredModifier) { return }

        if activationMethod == .middleClickHold {
            startAutoScroll(at: location, holding: button)
            return
        }

        if activationMethod == .doubleMiddleClick,
           !doubleClick.registerClick(at: timestamp, interval: NSEvent.doubleClickInterval) { return }

        if isAutoScrolling {
            stopAutoScroll()
        } else {
            startAutoScroll(at: location)
        }
    }

    func startAutoScroll(at point: NSPoint, holding button: Int? = nil) {
        stopAutoScroll()
        originalPoint = point
        scrollPosition = ScrollPosition(at: point)
        heldButton = button
        isAutoScrolling = true
        updateScrollFeedback()
        scheduleScrollTimer()
        if fixedScrollSpeed != .off { performScroll() }
    }

    private func scheduleScrollTimer() {
        scrollTimer?.invalidate()
        let timer = Timer(timeInterval: fixedScrollSpeed.timerInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.performScroll() }
        }
        scrollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func performScroll(at pointer: CGPoint = NSEvent.mouseLocation) {
        guard originalPoint != nil else { return }
        let pixels: ScrollMotion.Delta
        if fixedScrollSpeed == .off {
            guard let origin = scrollPosition?.origin(at: pointer, horizontalEnabled: allowsHorizontalScrolling) else {
                return
            }
            if scrollArea?.anchor != origin {
                scrollArea = ScrollArea(anchor: origin, screens: NSScreen.screens.map(\.frame))
            }
            let displacement = CGPoint(x: pointer.x - origin.x, y: pointer.y - origin.y)
            pixels = scrollMotion.pixelDelta(displacement: displacement, sensitivity: scrollSensitivity,
                                             inverted: isDirectionInverted,
                                             horizontalEnabled: allowsHorizontalScrolling, area: scrollArea)
            scrollCursor.move(to: pointer)
            scrollCursor.updateDirection(pixels.direction)
        } else {
            let direction = isDirectionInverted ? 1 : -1
            pixels = ScrollMotion.Delta(vertical: Int32(direction), horizontal: 0,
                                        direction: ScrollDirection(vertical: direction))
            scrollAnchor.updateDirection(pixels.direction)
        }
        guard pixels.vertical != 0 || pixels.horizontal != 0 else { return }

        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                    units: .pixel,
                                    wheelCount: allowsHorizontalScrolling ? 2 : 1,
                                    wheel1: pixels.vertical,
                                    wheel2: pixels.horizontal,
                                    wheel3: 0) {
            scrollEvent.flags = .maskNonCoalesced
            postScrollEvent(scrollEvent)
        }
    }

    func postScrollEvent(_ event: CGEvent) {
        event.post(tap: .cgSessionEventTap)
    }

    private func updateScrollFeedback() {
        let symbol = isAutoScrolling ? "arrow.up.and.down.circle.fill" : "arrow.up.and.down.circle"
        let label = isAutoScrolling ? "Scrollapp, auto-scroll active" : "Scrollapp"
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        statusItem?.button?.contentTintColor = isAutoScrolling ? .systemGreen : nil
        scrollMenuItem?.title = isAutoScrolling ? "Stop Auto-Scroll" : "Start Auto-Scroll"

        if let point = originalPoint, showsScrollIndicators {
            if fixedScrollSpeed == .off {
                scrollAnchor.hide()
                scrollCursor.show(at: NSEvent.mouseLocation, horizontalEnabled: allowsHorizontalScrolling)
            } else {
                scrollCursor.hide()
                scrollAnchor.show(at: point, horizontalEnabled: false)
            }
        } else {
            scrollAnchor.hide()
            scrollCursor.hide()
        }
    }

    @objc private func toggleHorizontalScrolling(_ sender: NSMenuItem) {
        horizontalScrollingEnabled.toggle()
        UserDefaults.standard.set(horizontalScrollingEnabled, forKey: "horizontalScrollingEnabled")
        sender.state = horizontalScrollingEnabled ? .on : .off
        scrollMotion = ScrollMotion()
        scrollCursor.update(horizontalEnabled: allowsHorizontalScrolling)
    }

    @objc private func selectFixedScrollSpeed(_ sender: NSMenuItem) {
        guard let speed = FixedScrollSpeed(rawValue: sender.tag), speed != fixedScrollSpeed else { return }
        fixedScrollSpeed = speed
        sensitivityItem?.isHidden = speed != .off
        UserDefaults.standard.set(speed.rawValue, forKey: "fixedScrollSpeed")
        for item in sender.menu?.items ?? [] {
            item.state = item === sender ? .on : .off
        }
        if isAutoScrolling {
            scrollMotion = ScrollMotion()
            updateScrollFeedback()
            scheduleScrollTimer()
        }
    }

    @objc private func toggleScrollIndicators(_ sender: NSMenuItem) {
        showsScrollIndicators.toggle()
        UserDefaults.standard.set(showsScrollIndicators, forKey: "showsScrollAnchor")
        sender.state = showsScrollIndicators ? .on : .off
        updateScrollFeedback()
    }

    @objc private func toggleTrackpadActivation(_ sender: NSMenuItem) {
        trackpadActivationEnabled.toggle()
        UserDefaults.standard.set(trackpadActivationEnabled, forKey: "trackpadActivationEnabled")
        sender.state = trackpadActivationEnabled ? .on : .off
        trackpadActivation = TrackpadActivation()
    }

    @objc private func toggleKeepsScrollingOnLeftClick(_ sender: NSMenuItem) {
        keepsScrollingOnLeftClick.toggle()
        UserDefaults.standard.set(keepsScrollingOnLeftClick, forKey: "keepsScrollingOnLeftClick")
        sender.state = keepsScrollingOnLeftClick ? .on : .off
    }

    @objc private func toggleMenuBarVisibility(_ sender: NSMenuItem) {
        hidesMenuBarIcon.toggle()
        UserDefaults.standard.set(hidesMenuBarIcon, forKey: "hidesMenuBarIcon")
        sender.state = hidesMenuBarIcon ? .on : .off
        statusItem?.isVisible = !hidesMenuBarIcon
    }

    @objc func toggleTrackpadMode() {
        if isAutoScrolling {
            stopAutoScroll()
        } else {
            startTrackpadAutoScroll()
        }
    }

    func startTrackpadAutoScroll() {
        startAutoScroll(at: NSEvent.mouseLocation)
        showTrackpadModeNotification()
    }

    func showTrackpadModeNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Auto-Scroll Active"
        content.body = fixedScrollSpeed == .off
            ? "Move the pointer to control scrolling. Click to stop."
            : "Scrolling at \(fixedScrollSpeed.menuTitle). Use your activation shortcut again to stop."
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
        sensitivityValueLabel?.stringValue = String(format: "%.1fx", scrollSensitivity)
    }
    
    @objc func selectActivationMethod(_ sender: NSMenuItem) {
        guard let method = sender.representedObject as? ActivationMethod else { return }

        if method != activationMethod, heldButton != nil { stopAutoScroll() }
        activationMethod = method
        doubleClick = DoubleClickActivation()
        UserDefaults.standard.set(method.rawValue, forKey: "activationMethod")
        for item in sender.menu?.items ?? [] {
            guard let choice = item.representedObject as? ActivationMethod else { continue }
            item.state = choice == method ? .on : .off
        }
    }

    @objc func showAbout() {
        let alignment = NSMutableParagraphStyle()
        alignment.alignment = .center
        let credits = NSMutableAttributedString(
            string: """
            Auto-scroll for macOS. In Scroll Mode, choose Follow Pointer or a constant speed.

            Website  ·  GitHub
            """,
            attributes: [.paragraphStyle: alignment]
        )
        for (title, address) in [("Website", "https://scrollapp.app/"),
                                 ("GitHub", "https://github.com/fromis-9/scrollapp")] {
            guard let url = URL(string: address) else { continue }
            credits.addAttribute(.link, value: url, range: (credits.string as NSString).range(of: title))
        }
        let application = NSApplication.shared
        if #available(macOS 14.0, *) {
            application.activate()
        } else {
            application.activate(ignoringOtherApps: true)
        }
        application.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func openReleases() {
        guard let url = URL(string: "https://github.com/fromis-9/scrollapp/releases/latest") else { return }
        NSWorkspace.shared.open(url)
    }

    func stopAutoScroll() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        let wasScrolling = isAutoScrolling
        isAutoScrolling = false
        originalPoint = nil
        scrollArea = nil
        scrollPosition = nil
        heldButton = nil
        scrollMotion = ScrollMotion()
        doubleClick = DoubleClickActivation()
        if wasScrolling { updateScrollFeedback() }
    }

    func setupTrackpadActivation() {
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleTrackpadScroll(event)
        }
        localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleTrackpadScroll(event)
            return event
        }
    }

    private func handleTrackpadScroll(_ event: NSEvent) {
        guard trackpadActivationEnabled else { return }
        if trackpadActivation.shouldActivate(phase: event.phase, momentumPhase: event.momentumPhase,
                                           modifiers: event.modifierFlags,
                                           hasPreciseDeltas: event.hasPreciseScrollingDeltas,
                                           displacement: CGPoint(x: event.scrollingDeltaX, y: event.scrollingDeltaY),
                                           horizontalEnabled: allowsHorizontalScrolling,
                                           isAutoScrolling: isAutoScrolling) {
            startTrackpadAutoScroll()
        }
    }

    @objc private func toggleDirectionInversion(_ sender: NSMenuItem) {
        isDirectionInverted = !isDirectionInverted
        UserDefaults.standard.set(isDirectionInverted, forKey: "invertScrollDirection")
        sender.state = isDirectionInverted ? .on : .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let enabled = LoginAtStartup.menuState == .off
        do {
            try LoginAtStartup.setEnabled(enabled)
            if enabled, LoginAtStartup.menuState == .mixed {
                showLoginMessage("Allow Scrollapp to Open at Login",
                                 detail: "Approve Scrollapp in System Settings under General > Login Items.")
            }
        } catch {
            showLoginMessage("Couldn’t Change Launch at Login", detail: error.localizedDescription)
        }
        sender.state = LoginAtStartup.menuState
    }

    private func showLoginMessage(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }

    func checkAccessibilityPermissions() {
        if !AXIsProcessTrusted() { showPermissions() }
    }

    @objc private func showPermissions() {
        let accessibilityGranted = AXIsProcessTrusted()
        let inputMonitoringGranted = CGPreflightListenEventAccess()
        let alert = NSAlert()
        alert.messageText = "Scrollapp Permissions"
        alert.informativeText = """
        Accessibility: \(accessibilityGranted ? "Allowed" : "Not allowed")
        Input Monitoring: \(inputMonitoringGranted ? "Allowed" : "Not allowed")

        Allow Scrollapp in Accessibility to enable auto-scrolling. If mouse or trackpad shortcuts aren’t detected, check Input Monitoring. Reopen Scrollapp after changing permissions.
        """
        alert.alertStyle = accessibilityGranted ? .informational : .warning
        alert.addButton(withTitle: "Done")
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Open Input Monitoring")

        let pane: String
        switch alert.runModal() {
        case .alertSecondButtonReturn: pane = "Accessibility"
        case .alertThirdButtonReturn: pane = "ListenEvent"
        default: return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
