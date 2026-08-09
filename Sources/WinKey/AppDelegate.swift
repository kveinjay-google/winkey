import AppKit
import WinKeyScrollReverser

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set when the user chooses Quit from the menu, so applicationWillTerminate
    /// can distinguish intentional quits from external terminations in logs.
    static var userRequestedQuit = false

    private let settings = SettingsStore()
    private let launchAgentManager = LaunchAgentManager()
    private var permissionTimer: Timer?
    private var lastTrustedState = AccessibilityPermission.isTrusted
    private lazy var windowSnapper = WindowSnapper()
    private lazy var keyboardMapper = KeyboardMapper(settings: settings, windowSnapper: windowSnapper)
    private lazy var dragSnapManager = WindowSnapDragManager(snapper: windowSnapper, settings: settings)
    private lazy var scrollReverser = WinKeyScrollReverser()
    private lazy var powerManager = PowerManager()
    private lazy var permissionWindow = PermissionWindowController(settings: settings)
    private lazy var statusMenu = StatusMenuController(
        settings: settings,
        keyboardMapper: keyboardMapper,
        windowSnapper: windowSnapper,
        dragSnapManager: dragSnapManager,
        scrollReverser: scrollReverser,
        powerManager: powerManager,
        permissionWindow: permissionWindow
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar utilities must never be auto-terminated by macOS when idle.
        ProcessInfo.processInfo.disableAutomaticTermination("WinKey background service")
        statusMenu.install()
        keyboardMapper.startIfPossible()
        updateDragSnapping()
        updateScrollReverser()
        updatePowerManager()
        launchAgentManager.sync(withEnabled: settings.launchAtLogin)
        startPermissionPolling()

        if !AccessibilityPermission.isTrusted {
            permissionWindow.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog(
            "WinKey terminating (userRequestedQuit=%@, agentInstalled=%@)",
            String(Self.userRequestedQuit),
            String(launchAgentManager.isInstalled)
        )
        permissionTimer?.invalidate()
        keyboardMapper.stop()
        dragSnapManager.stop()
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
            updateDragSnapping()
            updateScrollReverser()
            updatePowerManager()
        } else {
            keyboardMapper.stop()
            dragSnapManager.stop()
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

    private func updateDragSnapping() {
        guard AccessibilityPermission.isTrusted else {
            dragSnapManager.stop()
            return
        }
        dragSnapManager.update(enabled: settings.dragSnapping)
    }
}
