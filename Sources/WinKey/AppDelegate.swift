import AppKit
import WinKeyScrollReverser

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private var permissionTimer: Timer?
    private var lastTrustedState = AccessibilityPermission.isTrusted
    private lazy var keyboardMapper = KeyboardMapper(settings: settings)
    private lazy var scrollReverser = WinKeyScrollReverser()
    private lazy var powerManager = PowerManager()
    private lazy var permissionWindow = PermissionWindowController(settings: settings)
    private lazy var statusMenu = StatusMenuController(
        settings: settings,
        keyboardMapper: keyboardMapper,
        scrollReverser: scrollReverser,
        powerManager: powerManager,
        permissionWindow: permissionWindow
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu.install()
        keyboardMapper.startIfPossible()
        updateScrollReverser()
        updatePowerManager()
        startPermissionPolling()

        if !AccessibilityPermission.isTrusted {
            permissionWindow.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        keyboardMapper.stop()
        scrollReverser.stop()
        powerManager.stop()
    }

    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermissionState()
        }
    }

    private func refreshPermissionState() {
        let isTrusted = AccessibilityPermission.isTrusted
        guard isTrusted != lastTrustedState else {
            statusMenu.refresh()
            return
        }

        lastTrustedState = isTrusted

        if isTrusted {
            permissionWindow.close()
            keyboardMapper.startIfPossible()
            updateScrollReverser()
            updatePowerManager()
        } else {
            keyboardMapper.stop()
            scrollReverser.stop()
            updatePowerManager()
        }

        statusMenu.refresh()
    }

    private func updateScrollReverser() {
        guard AccessibilityPermission.isTrusted else {
            scrollReverser.stop()
            return
        }

        scrollReverser.start()
        scrollReverser.isEnabled = settings.enabled && settings.reverseScrollWheel
    }

    private func updatePowerManager() {
        powerManager.update(
            preventIdleSleep: settings.preventIdleSleep,
            externalDisplayMouseWake: settings.externalDisplayMouseWake
        )
    }
}
