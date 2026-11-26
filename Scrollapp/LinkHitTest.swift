import AppKit
import ApplicationServices

enum LinkHitTest {
    static func containsLink(at point: CGPoint) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element) == .success else {
            return false
        }

        // Browsers may return the text or image inside a link as the hit element.
        for _ in 0..<8 {
            guard let current = element else { break }
            var role: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &role)
            if result == .success, role as? String == NSAccessibility.Role.link.rawValue { return true }
            if result == .cannotComplete { break }

            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            element = (parent as! AXUIElement)
        }

        return false
    }
}
