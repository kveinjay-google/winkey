import AppKit
import ApplicationServices

/// Moves and resizes the frontmost window through the macOS Accessibility API.
/// The geometry and key-chord logic live in WindowSnapping.swift and are unit
/// tested; this class is a thin wrapper over AXUIElement calls.
final class WindowSnapper {
    private struct WindowState {
        var restoreFrame: CGRect
        var lastAction: WindowSnapAction?
        var lastFrame: CGRect
    }

    private var states: [CGWindowID: WindowState] = [:]

    func perform(_ shortcutAction: WindowSnapAction) {
        guard let window = frontmostWindowElement(),
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
        if shortcutAction == .center || shortcutAction == .restore {
            action = shortcutAction
        } else {
            action = WindowSnapStateMachine.nextAction(
                current: currentState?.lastAction,
                direction: shortcutAction
            )
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

        guard let screen = screen(containing: frame),
              let target = WindowSnapLayout.targetFrame(
                  for: action,
                  currentFrame: frame,
                  visibleFrame: axVisibleFrame(of: screen)
              ) else {
            NSSound.beep()
            return
        }

        apply(frame: target, to: window)

        guard let windowId else {
            return
        }

        let restoreFrame = currentState?.restoreFrame ?? frame
        let lastAction = action == .center ? currentState?.lastAction : action
        states[windowId] = WindowState(restoreFrame: restoreFrame, lastAction: lastAction, lastFrame: target)
    }

    // MARK: - Window discovery

    private func frontmostWindowElement() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
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

    private func windowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position: CGPoint = axValue(window, kAXPositionAttribute as CFString),
              let size: CGSize = axValue(window, kAXSizeAttribute as CFString) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func windowIdentifier(for window: AXUIElement, frame: CGRect) -> CGWindowID? {
        guard let pid = pid(of: window) else {
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
        let hash = CFHash(window)
        return CGWindowID(0x8000_0000) | (CGWindowID(truncatingIfNeeded: hash) & 0x7FFF_FFFF)
    }

    // MARK: - Frame manipulation

    private func apply(frame: CGRect, to window: AXUIElement) {
        // macOS only allows size and position changes separately; adjusting size
        // first (again afterwards) handles windows that get clamped on display
        // changes, matching Rectangle's approach.
        setSize(CGSize(width: frame.width, height: frame.height), on: window)
        setPosition(frame.origin, on: window)
        setSize(CGSize(width: frame.width, height: frame.height), on: window)
    }

    private func setPosition(_ point: CGPoint, on window: AXUIElement) {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else {
            return
        }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axValue)
    }

    private func setSize(_ size: CGSize, on window: AXUIElement) {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else {
            return
        }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axValue)
    }

    // MARK: - Screens

    private func screen(containing frame: CGRect) -> NSScreen? {
        let axFrames = NSScreen.screens.map { (screen: $0, frame: axFrame(of: $0)) }
        if let exact = axFrames.first(where: { $0.frame.contains(frame) }) {
            return exact.screen
        }

        return axFrames.max { a, b in
            a.frame.intersection(frame).area < b.frame.intersection(frame).area
        }?.screen
    }

    /// Converts an AppKit frame (origin at bottom-left) to the Accessibility
    /// coordinate space (origin at top-left of the primary display).
    private func axRect(from appKitFrame: CGRect) -> CGRect {
        let mainScreenHeight = NSScreen.screens[0].frame.maxY
        return CGRect(
            x: appKitFrame.minX,
            y: mainScreenHeight - appKitFrame.maxY,
            width: appKitFrame.width,
            height: appKitFrame.height
        )
    }

    private func axFrame(of screen: NSScreen) -> CGRect {
        axRect(from: screen.frame)
    }

    private func axVisibleFrame(of screen: NSScreen) -> CGRect {
        axRect(from: screen.visibleFrame)
    }

    // MARK: - AX helpers

    private func pid(of window: AXUIElement) -> pid_t? {
        var pid = pid_t(0)
        let result = AXUIElementGetPid(window, &pid)
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
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}
