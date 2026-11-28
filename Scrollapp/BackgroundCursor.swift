import AppKit
import Darwin

@MainActor
final class BackgroundCursor {
    private typealias Connection = @convention(c) () -> Int32
    private typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
    private typealias IsVisible = @convention(c) () -> UInt32

    private let graphics: UnsafeMutableRawPointer
    private let connection: Int32
    private let setProperty: SetProperty
    private let isVisible: IsVisible
    private let property = "SetsCursorInBackground" as CFString
    private var hiddenDisplay: CGDirectDisplayID?

    init?() {
        guard let graphics = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY) else {
            return nil
        }
        guard let connection = dlsym(graphics, "_CGSDefaultConnection"),
              let setProperty = dlsym(graphics, "CGSSetConnectionProperty"),
              let isVisible = dlsym(graphics, "CGCursorIsVisible") else {
            dlclose(graphics)
            return nil
        }
        self.graphics = graphics
        self.connection = unsafeBitCast(connection, to: Connection.self)()
        self.setProperty = unsafeBitCast(setProperty, to: SetProperty.self)
        self.isVisible = unsafeBitCast(isVisible, to: IsVisible.self)
    }

    var isHidden: Bool { isVisible() == 0 }

    func hide() -> Bool {
        guard !isHidden, setProperty(connection, connection, property, kCFBooleanTrue) == 0 else {
            return false
        }
        let display = CGMainDisplayID()
        if CGDisplayHideCursor(display) == .success {
            hiddenDisplay = display
            if isHidden { return true }
        }
        restore()
        return false
    }

    func restore() {
        if let display = hiddenDisplay {
            CGDisplayShowCursor(display)
            hiddenDisplay = nil
        }
        _ = setProperty(connection, connection, property, kCFBooleanFalse)
    }

    deinit {
        dlclose(graphics)
    }
}
