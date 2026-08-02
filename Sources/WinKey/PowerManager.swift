import CoreGraphics
import Foundation
import IOKit.pwr_mgt

final class PowerManager {
    private var idleSleepAssertion: IOPMAssertionID = 0
    private var userActivityAssertion: IOPMAssertionID = 0
    private var mouseTapPort: CFMachPort?
    private var mouseTapSource: CFRunLoopSource?
    private var lastUserActivityDate = Date.distantPast
    private let userActivityThrottle: TimeInterval = 2

    var isPreventingIdleSleep: Bool {
        idleSleepAssertion != 0
    }

    var isMouseWakeActive: Bool {
        mouseTapPort != nil && mouseTapSource != nil
    }

    func update(preventIdleSleep: Bool, externalDisplayMouseWake: Bool) {
        setPreventIdleSleep(preventIdleSleep)
        setExternalDisplayMouseWake(externalDisplayMouseWake)
    }

    func stop() {
        setExternalDisplayMouseWake(false)
        setPreventIdleSleep(false)
    }

    private func setPreventIdleSleep(_ enabled: Bool) {
        if enabled {
            guard idleSleepAssertion == 0 else {
                return
            }

            var assertionID: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "WinKey Prevent Idle System Sleep" as CFString,
                &assertionID
            )

            if result == kIOReturnSuccess {
                idleSleepAssertion = assertionID
            } else {
                NSLog("WinKey failed to create idle sleep assertion: \(result)")
            }
        } else {
            releaseAssertion(&idleSleepAssertion)
        }
    }

    private func setExternalDisplayMouseWake(_ enabled: Bool) {
        if enabled {
            guard mouseTapPort == nil else {
                return
            }

            let eventMask =
                CGEventMask(1 << CGEventType.mouseMoved.rawValue) |
                CGEventMask(1 << CGEventType.leftMouseDown.rawValue) |
                CGEventMask(1 << CGEventType.rightMouseDown.rawValue) |
                CGEventMask(1 << CGEventType.otherMouseDown.rawValue) |
                CGEventMask(1 << CGEventType.scrollWheel.rawValue)

            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .tailAppendEventTap,
                options: .listenOnly,
                eventsOfInterest: eventMask,
                callback: PowerManager.mouseWakeCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                NSLog("WinKey failed to create mouse wake event tap")
                return
            }

            guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
                CFMachPortInvalidate(tap)
                return
            }

            mouseTapPort = tap
            mouseTapSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            if let source = mouseTapSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                mouseTapSource = nil
            }

            if let tap = mouseTapPort {
                CFMachPortInvalidate(tap)
                mouseTapPort = nil
            }

            releaseAssertion(&userActivityAssertion)
        }
    }

    private func handleMouseWakeEvent(type: CGEventType) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = mouseTapPort {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        guard hasExternalDisplay() else {
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastUserActivityDate) >= userActivityThrottle else {
            return
        }

        lastUserActivityDate = now
        var assertionID = userActivityAssertion
        let result = IOPMAssertionDeclareUserActivity(
            "WinKey Mouse Wake External Display" as CFString,
            kIOPMUserActiveLocal,
            &assertionID
        )

        if result == kIOReturnSuccess {
            userActivityAssertion = assertionID
        } else {
            NSLog("WinKey failed to declare user activity: \(result)")
        }
    }

    private func hasExternalDisplay() -> Bool {
        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return false
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success else {
            return false
        }

        return displays.prefix(Int(displayCount)).contains { CGDisplayIsBuiltin($0) == 0 }
    }

    private func releaseAssertion(_ assertionID: inout IOPMAssertionID) {
        guard assertionID != 0 else {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    private static let mouseWakeCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<PowerManager>.fromOpaque(userInfo).takeUnretainedValue()
        manager.handleMouseWakeEvent(type: type)
        return Unmanaged.passUnretained(event)
    }

    deinit {
        stop()
    }
}
