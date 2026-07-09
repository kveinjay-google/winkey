import AppKit
import Foundation

enum ScreenshotSaver {
    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()

    static func captureFullScreenToDesktop() {
        runScreencapture(arguments: ["-x", desktopScreenshotPath()])
    }

    static func captureInteractiveToDesktop() {
        let path = desktopScreenshotPath()
        runScreencapture(arguments: ["-i", "-x", path]) { success in
            guard success else {
                return
            }

            copyImageToPasteboard(at: path)
        }
    }

    private static func desktopScreenshotPath() -> String {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        let folder = desktopURL ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let timestamp = filenameFormatter.string(from: Date())
        return folder.appendingPathComponent("WinKey Screenshot \(timestamp).png").path
    }

    private static func runScreencapture(arguments: [String], completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments

            do {
                try process.run()
                process.waitUntilExit()
                completion?(process.terminationStatus == 0)
            } catch {
                NSLog("WinKey failed to start screencapture: \(error.localizedDescription)")
                completion?(false)
            }
        }
    }

    private static func copyImageToPasteboard(at path: String) {
        let url = URL(fileURLWithPath: path)

        DispatchQueue.main.async {
            guard let image = NSImage(contentsOf: url) else {
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        }
    }
}
