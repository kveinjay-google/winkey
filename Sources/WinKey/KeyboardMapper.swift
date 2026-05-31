import AppKit
import ApplicationServices

final class KeyboardMapper {
    private let settings: SettingsStore
    private var keyboardEventTap: CFMachPort?
    private var keyboardRunLoopSource: CFRunLoopSource?
    private var scrollEventTap: CFMachPort?
    private var scrollRunLoopSource: CFRunLoopSource?
    private let syntheticEventMarker: Int64 = 0x57494E4B4559

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func startIfPossible() {
        stop()

        guard AccessibilityPermission.isTrusted else {
            return
        }

        let keyboardMask = 1 << CGEventType.keyDown.rawValue
        let scrollMask = 1 << CGEventType.scrollWheel.rawValue
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(keyboardMask),
            callback: KeyboardMapper.eventTapCallback,
            userInfo: userInfo
        ) {
            keyboardEventTap = tap
            keyboardRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

            if let keyboardRunLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), keyboardRunLoopSource, .commonModes)
            }

            CGEvent.tapEnable(tap: tap, enable: true)
        }

        if let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(scrollMask),
            callback: KeyboardMapper.eventTapCallback,
            userInfo: userInfo
        ) {
            scrollEventTap = tap
            scrollRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

            if let scrollRunLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), scrollRunLoopSource, .commonModes)
            }

            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func stop() {
        if let tap = keyboardEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let tap = scrollEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let keyboardRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), keyboardRunLoopSource, .commonModes)
        }

        if let scrollRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), scrollRunLoopSource, .commonModes)
        }

        keyboardRunLoopSource = nil
        keyboardEventTap = nil
        scrollRunLoopSource = nil
        scrollEventTap = nil
    }

    func restart() {
        startIfPossible()
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let mapper = Unmanaged<KeyboardMapper>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = mapper.keyboardEventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            if let tap = mapper.scrollEventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .scrollWheel {
            return mapper.handleScrollWheel(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        return mapper.handleKeyDown(event)
    }

    private func handleScrollWheel(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard settings.reverseScrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        reverseScrollField(.scrollWheelEventDeltaAxis1, in: event)
        reverseScrollField(.scrollWheelEventDeltaAxis2, in: event)
        reverseScrollField(.scrollWheelEventFixedPtDeltaAxis1, in: event)
        reverseScrollField(.scrollWheelEventFixedPtDeltaAxis2, in: event)
        reverseScrollField(.scrollWheelEventPointDeltaAxis1, in: event)
        reverseScrollField(.scrollWheelEventPointDeltaAxis2, in: event)

        return Unmanaged.passUnretained(event)
    }

    private func reverseScrollField(_ field: CGEventField, in event: CGEvent) {
        let value = event.getIntegerValueField(field)
        event.setIntegerValueField(field, value: -value)
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        guard settings.enabled else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if settings.deleteInFinder, keyCode == KeyCode.deleteForward, isFinderFrontmost() {
            confirmFinderDelete(for: NSWorkspace.shared.frontmostApplication)
            return nil
        }

        if settings.printScreen, keyCode == KeyCode.f13PrintScreen {
            sendShortcut(keyCode: KeyCode.number3, flags: [.maskCommand, .maskShift])
            return nil
        }

        if settings.altAClipboardScreenshot, keyCode == KeyCode.a, matchesScreenshotShortcut(flags) {
            sendShortcut(keyCode: KeyCode.number4, flags: [.maskCommand, .maskControl, .maskShift])
            return nil
        }

        if settings.ctrlASelectAll, keyCode == KeyCode.a, flags.contains(.maskControl) {
            sendShortcut(keyCode: KeyCode.a, flags: [.maskCommand])
            return nil
        }

        if settings.ctrlCommonShortcuts, handleCommonControlShortcut(keyCode: keyCode, flags: flags) {
            return nil
        }

        if settings.homeEnd, isTextEditingFocus() {
            if keyCode == KeyCode.home {
                sendShortcut(keyCode: KeyCode.left, flags: [.maskCommand])
                return nil
            }

            if keyCode == KeyCode.end {
                sendShortcut(keyCode: KeyCode.right, flags: [.maskCommand])
                return nil
            }
        }

        if settings.ctrlArrow, flags.contains(.maskControl), isTextEditingFocus() {
            if keyCode == KeyCode.left {
                sendShortcut(keyCode: KeyCode.left, flags: [.maskAlternate])
                return nil
            }

            if keyCode == KeyCode.right {
                sendShortcut(keyCode: KeyCode.right, flags: [.maskAlternate])
                return nil
            }

            if keyCode == KeyCode.home {
                sendShortcut(keyCode: KeyCode.up, flags: [.maskCommand])
                return nil
            }

            if keyCode == KeyCode.end {
                sendShortcut(keyCode: KeyCode.down, flags: [.maskCommand])
                return nil
            }
        }

        if settings.altTab, keyCode == KeyCode.tab, flags.contains(.maskAlternate) {
            sendCommandTab()
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func confirmFinderDelete(for finder: NSRunningApplication?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let alert = NSAlert()
            alert.messageText = LocalizedText.deleteAlertTitle(self.settings.language)
            alert.informativeText = LocalizedText.deleteAlertMessage(self.settings.language)
            alert.alertStyle = .warning
            alert.addButton(withTitle: LocalizedText.moveToTrash(self.settings.language))
            alert.addButton(withTitle: LocalizedText.cancel(self.settings.language))

            if alert.runModal() == .alertFirstButtonReturn {
                finder?.activate(options: [.activateIgnoringOtherApps])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.sendShortcut(
                        keyCode: KeyCode.deleteBackward,
                        flags: [.maskCommand]
                    )
                }
            }
        }
    }

    private func matchesScreenshotShortcut(_ flags: CGEventFlags) -> Bool {
        switch settings.screenshotShortcutModifier {
        case .option:
            return flags.contains(.maskAlternate)
        case .command:
            return flags.contains(.maskCommand)
        }
    }

    private func handleCommonControlShortcut(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard flags.contains(.maskControl) else {
            return false
        }

        switch keyCode {
        case KeyCode.c:
            sendShortcut(keyCode: KeyCode.c, flags: [.maskCommand])
        case KeyCode.v:
            sendShortcut(keyCode: KeyCode.v, flags: [.maskCommand])
        case KeyCode.x:
            sendShortcut(keyCode: KeyCode.x, flags: [.maskCommand])
        case KeyCode.z:
            sendShortcut(keyCode: KeyCode.z, flags: [.maskCommand])
        case KeyCode.y:
            sendShortcut(keyCode: KeyCode.z, flags: [.maskCommand, .maskShift])
        case KeyCode.f:
            sendShortcut(keyCode: KeyCode.f, flags: [.maskCommand])
        case KeyCode.s:
            sendShortcut(keyCode: KeyCode.s, flags: [.maskCommand])
        case KeyCode.p:
            sendShortcut(keyCode: KeyCode.p, flags: [.maskCommand])
        case KeyCode.w:
            sendShortcut(keyCode: KeyCode.w, flags: [.maskCommand])
        case KeyCode.t:
            if flags.contains(.maskShift) {
                sendShortcut(keyCode: KeyCode.t, flags: [.maskCommand, .maskShift])
            } else {
                sendShortcut(keyCode: KeyCode.t, flags: [.maskCommand])
            }
        case KeyCode.n:
            sendShortcut(keyCode: KeyCode.n, flags: flags.contains(.maskShift) ? [.maskCommand, .maskShift] : [.maskCommand])
        case KeyCode.o:
            sendShortcut(keyCode: KeyCode.o, flags: [.maskCommand])
        case KeyCode.r:
            sendShortcut(keyCode: KeyCode.r, flags: [.maskCommand])
        default:
            return false
        }

        return true
    }

    private func sendShortcut(keyCode: Int64, flags: CGEventFlags, targetPid: pid_t? = nil) {
        let modifiers = modifierKeys(for: flags)

        for modifier in modifiers {
            postKeyEvent(keyCode: modifier.keyCode, keyDown: true, flags: modifier.flag, targetPid: targetPid)
        }

        postKeyEvent(keyCode: keyCode, keyDown: true, flags: flags, targetPid: targetPid)
        postKeyEvent(keyCode: keyCode, keyDown: false, flags: flags, targetPid: targetPid)

        for modifier in modifiers.reversed() {
            postKeyEvent(keyCode: modifier.keyCode, keyDown: false, flags: [], targetPid: targetPid)
        }
    }

    private func sendCommandTab() {
        postKeyEvent(keyCode: KeyCode.leftCommand, keyDown: true, flags: [.maskCommand])
        postKeyEvent(keyCode: KeyCode.tab, keyDown: true, flags: [.maskCommand])
        postKeyEvent(keyCode: KeyCode.tab, keyDown: false, flags: [.maskCommand])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.postKeyEvent(keyCode: KeyCode.leftCommand, keyDown: false, flags: [])
        }
    }

    private func postKeyEvent(keyCode: Int64, keyDown: Bool, flags: CGEventFlags, targetPid: pid_t? = nil) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(keyCode),
            keyDown: keyDown
        ) else {
            return
        }

        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)

        if let targetPid {
            event.postToPid(targetPid)
        } else {
            event.post(tap: .cghidEventTap)
        }
    }

    private func modifierKeys(for flags: CGEventFlags) -> [(keyCode: Int64, flag: CGEventFlags)] {
        var modifiers: [(keyCode: Int64, flag: CGEventFlags)] = []

        if flags.contains(.maskControl) {
            modifiers.append((KeyCode.leftControl, .maskControl))
        }

        if flags.contains(.maskAlternate) {
            modifiers.append((KeyCode.leftOption, .maskAlternate))
        }

        if flags.contains(.maskShift) {
            modifiers.append((KeyCode.leftShift, .maskShift))
        }

        if flags.contains(.maskCommand) {
            modifiers.append((KeyCode.leftCommand, .maskCommand))
        }

        return modifiers
    }

    private func isFinderFrontmost() -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
    }

    private func isTextEditingFocus() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusedResult == .success, let focusedElement = focusedValue else {
            return false
        }

        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        guard roleResult == .success, let role = roleValue as? String else {
            return false
        }

        let textRoles = [
            "AXTextArea",
            "AXTextField",
            "AXComboBox",
            "AXSearchField"
        ]

        return textRoles.contains(role)
    }

    private func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }

        return value
    }
}
