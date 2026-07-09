import AppKit
import WinKeyHIDShim

enum InputMonitoringPermission {
    static var isTrusted: Bool {
        WinKeyCGListenEventAccessGranted() != 0 && WinKeyCGPostEventAccessGranted() != 0
    }

    static func requestPrompt() {
        DispatchQueue.global(qos: .userInitiated).async {
            WinKeyCGRequestListenEventAccess()
            WinKeyCGRequestPostEventAccess()
        }
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
