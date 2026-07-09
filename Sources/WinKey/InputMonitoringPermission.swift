import AppKit
import WinKeyHIDShim

enum InputMonitoringPermission {
    static var isTrusted: Bool {
        WinKeyIOHIDListenEventAccessGranted() != 0
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
