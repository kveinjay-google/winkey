import AppKit
import ApplicationServices

/// Converts between AppKit coordinates (origin at bottom-left) and the
/// Accessibility coordinate space (origin at top-left of the primary display).
enum ScreenGeometry {
    static var mainHeight: CGFloat {
        NSScreen.screens[0].frame.maxY
    }

    static func axRect(from appKitRect: CGRect) -> CGRect {
        CGRect(
            x: appKitRect.minX,
            y: mainHeight - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }

    static func appKitRect(from axRect: CGRect) -> CGRect {
        CGRect(
            x: axRect.minX,
            y: mainHeight - axRect.maxY,
            width: axRect.width,
            height: axRect.height
        )
    }

    static func axPoint(from appKitPoint: CGPoint) -> CGPoint {
        CGPoint(x: appKitPoint.x, y: mainHeight - appKitPoint.y)
    }

    static func axFrame(of screen: NSScreen) -> CGRect {
        axRect(from: screen.frame)
    }

    static func axVisibleFrame(of screen: NSScreen) -> CGRect {
        axRect(from: screen.visibleFrame)
    }
}

/// Moves and resizes windows through the macOS Accessibility API. The geometry
/// and key-chord logic live in WindowSnapping.swift and are unit tested; this
/// class is the thin AX wrapper and keeps per-window snap/restore state.
final class WindowSnapper {
    /// Bounds every Accessibility API call so an unresponsive app can never
    /// freeze WinKey's main thread (Rectangle uses the same mitigation).
    private let axMessagingTimeout: Float = 0.5

    private struct WindowState {
        var restoreFrame: CGRect
        var lastAction: WindowSnapAction?
        var lastFrame: CGRect
    }

    private var states: [CGWindowID: WindowState] = [:]

    func perform(
        _ shortcutAction: WindowSnapAction,
        element: AXUIElement? = nil,
        screen: NSScreen? = nil,
        useStateMachine: Bool = true
    ) {
        guard let window = element ?? frontmostWindowElement(),
              let frame = windowFrame(window) else {
            NSSound.beep()
            return
        }

        let windowId = windowIdentifier(for: window, frame: frame)
        var currentState: WindowState?
        if let windowId {
            currentState = states[windowId]
            // If the window moved since we snapped it, forget the stale state.
            if let state = currentState, frame != state.lastFrame {
                states.removeValue(forKey: windowId)
                currentState = nil
            }
        }

        let action: WindowSnapAction
        if shortcutAction.isDirectional, useStateMachine {
            action = WindowSnapStateMachine.nextAction(
                current: currentState?.lastAction,
                direction: shortcutAction
            )
        } else {
            action = shortcutAction
        }

        if action == .restore {
            guard let windowId, let restoreFrame = states[windowId]?.restoreFrame else {
                NSSound.beep()
                return
            }
            apply(frame: restoreFrame, to: window)
            states.removeValue(forKey: windowId)
            return
        }

        if action == .previousDisplay || action == .nextDisplay {
            guard let currentScreen = screen ?? self.screen(containing: frame),
                  let targetScreen = adjacentScreen(from: currentScreen, direction: action) else {
                NSSound.beep()
                return
            }

            let oldVisible = ScreenGeometry.axVisibleFrame(of: currentScreen)
            let newVisible = ScreenGeometry.axVisibleFrame(of: targetScreen)
            let relativeX = oldVisible.width > 0 ? (frame.minX - oldVisible.minX) / oldVisible.width : 0
            let relativeY = oldVisible.height > 0 ? (frame.minY - oldVisible.minY) / oldVisible.height : 0
            let target = CGRect(
                x: newVisible.minX + relativeX * newVisible.width,
                y: newVisible.minY + relativeY * newVisible.height,
                width: min(frame.width, newVisible.width),
                height: min(frame.height, newVisible.height)
            )
            apply(frame: target, to: window)
            recordState(for: windowId, action: action, restoreFrame: frame, target: target)
            return
        }

        guard let snapScreen = screen ?? self.screen(containing: frame),
              let target = WindowSnapLayout.targetFrame(
                  for: action,
                  currentFrame: frame,
                  visibleFrame: ScreenGeometry.axVisibleFrame(of: snapScreen)
              ) else {
            NSSound.beep()
            return
        }

        NSLog(
            "WinKey snap: action=%@ current=%@ screen=%@ target=%@",
            String(describing: action),
            NSStringFromRect(frame),
            NSStringFromRect(snapScreen.frame),
            NSStringFromRect(target)
        )
        apply(frame: target, to: window)
        recordState(for: windowId, action: action, restoreFrame: frame, target: target)
    }

    func restoreFrame(for windowId: CGWindowID) -> CGRect? {
        states[windowId]?.restoreFrame
    }

    func lastAction(for windowId: CGWindowID) -> WindowSnapAction? {
        states[windowId]?.lastAction
    }

    /// Called while the user is dragging a window we previously snapped:
    /// restore the pre-snap size, keeping the cursor inside the window.
    func unsnapForDrag(element: AXUIElement, windowId: CGWindowID, currentFrame: CGRect, cursorAppKit: CGPoint) {
        guard let state = states[windowId],
              state.restoreFrame != currentFrame else {
            return
        }

        var newFrame = currentFrame
        newFrame.size = state.restoreFrame.size
        let cursor = ScreenGeometry.axPoint(from: cursorAppKit)
        if !newFrame.contains(cursor) {
            newFrame.origin.x = currentFrame.maxX - newFrame.width
            if !newFrame.contains(cursor) {
                newFrame.origin.x = cursor.x - newFrame.width / 2
            }
        }

        apply(frame: newFrame, to: element)
        states[windowId] = WindowState(restoreFrame: state.restoreFrame, lastAction: nil, lastFrame: newFrame)
    }

    func windowElement(at axPoint: CGPoint) -> AXUIElement? {
        if let element = elementAtPosition(axPoint), let window = windowAncestor(of: element) {
            return window
        }

        // Fallback (adapted from Rectangle): match the CGWindow under the cursor
        // to the corresponding AX window of its owning app.
        guard let info = windowInfo(at: axPoint) else {
            return nil
        }
        let appElement = timed(AXUIElementCreateApplication(info.pid))
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return nil
        }
        for window in windows {
            let timedWindow = timed(window)
            if windowFrame(timedWindow)?.contains(axPoint) == true {
                return timedWindow
            }
        }
        return nil
    }

    private func elementAtPosition(_ axPoint: CGPoint) -> AXUIElement? {
        let systemWide = timed(AXUIElementCreateSystemWide())
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(axPoint.x), Float(axPoint.y), &element)
        guard result == .success, let element else {
            return nil
        }
        return timed(element)
    }

    private func windowAncestor(of element: AXUIElement) -> AXUIElement? {
        var current = element
        var depth = 0
        while depth < 32 {
            depth += 1
            if isWindow(current) {
                return current
            }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXWindowAttribute as CFString, &parent) == .success,
                  let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else {
                return nil
            }
            current = timed(parent as! AXUIElement)
        }
        return nil
    }


    /// Returns false when a click cannot start a drag-snap: either it is not
    /// over any normal window (menu bar, Dock, desktop) or it is over one of
    /// our own windows (status item, panels). AX hit-testing our own app from
    /// the background drag queue crashes AppKit's accessibility code, so this
    /// must be checked before any AX lookup at that position.
    func shouldHandleDrag(at axPoint: CGPoint) -> Bool {
        guard let info = windowInfo(at: axPoint) else {
            return false
        }
        return info.pid != getpid()
    }

    private struct WindowInfo {
        let pid: pid_t
    }

    private func windowInfo(at axPoint: CGPoint) -> WindowInfo? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in list {
            guard let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue, layer == 0,
                  let boundsRaw = info[kCGWindowBounds as String],
                  CFGetTypeID(boundsRaw as CFTypeRef) == CFDictionaryGetTypeID(),
                  let bounds = CGRect(dictionaryRepresentation: boundsRaw as! CFDictionary),
                  bounds.contains(axPoint),
                  let ownerPid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else {
                continue
            }
            return WindowInfo(pid: ownerPid)
        }
        return nil
    }

    func frame(of element: AXUIElement) -> CGRect? {
        windowFrame(element)
    }

    func windowIdentifier(for element: AXUIElement, frame: CGRect) -> CGWindowID? {
        guard let pid = pid(of: element) else {
            return nil
        }

        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for info in list {
            guard let ownerPid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  ownerPid == pid,
                  let boundsRaw = info[kCGWindowBounds as String],
                  CFGetTypeID(boundsRaw as CFTypeRef) == CFDictionaryGetTypeID(),
                  let bounds = CGRect(dictionaryRepresentation: boundsRaw as! CFDictionary),
                  bounds == frame else {
                continue
            }

            if let number = info[kCGWindowNumber as String] as? NSNumber {
                return CGWindowID(number.uint32Value)
            }
        }

        // Fallback (adapted from Rectangle, MIT): derive a stable stand-in id
        // from the AX element when the window server isn't vending real ids.
        let hash = CFHash(element)
        return CGWindowID(0x8000_0000) | (CGWindowID(truncatingIfNeeded: hash) & 0x7FFF_FFFF)
    }

    // MARK: - State

    private func recordState(for windowId: CGWindowID?, action: WindowSnapAction, restoreFrame: CGRect, target: CGRect) {
        guard let windowId else {
            return
        }
        let currentState = states[windowId]
        let lastAction = action == .center ? currentState?.lastAction : action
        states[windowId] = WindowState(
            restoreFrame: currentState?.restoreFrame ?? restoreFrame,
            lastAction: lastAction,
            lastFrame: target
        )
    }

    // MARK: - Window discovery

    private func frontmostWindowElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let axApp = timed(AXUIElementCreateApplication(app.processIdentifier))
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let value else {
            return nil
        }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func isWindow(_ element: AXUIElement) -> Bool {
        guard let role: String = axValue(element, kAXRoleAttribute as CFString) else {
            return false
        }
        return role == kAXWindowRole as String
    }

    private func windowFrame(_ element: AXUIElement) -> CGRect? {
        guard let position: CGPoint = axValue(element, kAXPositionAttribute as CFString),
              let size: CGSize = axValue(element, kAXSizeAttribute as CFString) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    // MARK: - Frame manipulation

    private func apply(frame: CGRect, to element: AXUIElement) {
        // macOS only allows size and position changes separately; adjusting size
        // first (again afterwards) handles windows that get clamped on display
        // changes, matching Rectangle's approach.
        setSize(CGSize(width: frame.width, height: frame.height), on: element)
        setPosition(frame.origin, on: element)
        setSize(CGSize(width: frame.width, height: frame.height), on: element)
    }

    private func setPosition(_ point: CGPoint, on element: AXUIElement) {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else {
            return
        }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axValue)
    }

    private func setSize(_ size: CGSize, on element: AXUIElement) {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else {
            return
        }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axValue)
    }

    // MARK: - Screens

    func screen(containing frame: CGRect) -> NSScreen? {
        let axFrames = NSScreen.screens.map { (screen: $0, frame: ScreenGeometry.axFrame(of: $0)) }
        if let exact = axFrames.first(where: { $0.frame.contains(frame) }) {
            return exact.screen
        }

        return axFrames.max { a, b in
            a.frame.intersection(frame).area < b.frame.intersection(frame).area
        }?.screen
    }

    func adjacentScreen(from screen: NSScreen, direction: WindowSnapAction) -> NSScreen? {
        let screens = NSScreen.screens.sorted {
            if $0.frame.minX == $1.frame.minX {
                return $0.frame.minY < $1.frame.minY
            }
            return $0.frame.minX < $1.frame.minX
        }
        guard screens.count > 1, let index = screens.firstIndex(of: screen) else {
            return nil
        }

        switch direction {
        case .nextDisplay:
            return screens[(index + 1) % screens.count]
        case .previousDisplay:
            return screens[(index - 1 + screens.count) % screens.count]
        default:
            return nil
        }
    }

    // MARK: - AX helpers

    private func pid(of element: AXUIElement) -> pid_t? {
        var pid = pid_t(0)
        let result = AXUIElementGetPid(element, &pid)
        return result == .success ? pid : nil
    }

    private func axValue<T>(_ element: AXUIElement, _ attribute: CFString) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = value as! AXValue
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        let success = AXValueGetValue(axValue, AXValueGetType(axValue), pointer)
        let result = pointer.pointee
        pointer.deallocate()
        return success ? result : nil
    }

    private func timed(_ element: AXUIElement) -> AXUIElement {
        AXUIElementSetMessagingTimeout(element, axMessagingTimeout)
        return element
    }
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}
