import AppKit
import Foundation

enum ScreenshotSaver {
    struct PasteboardContents {
        let pngData: Data
        let fileURL: URL
    }

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

            copyScreenshotToPasteboard(at: path)
        }
    }

    static func pasteboardContents(imageData: Data, fileURL: URL) -> PasteboardContents {
        PasteboardContents(pngData: imageData, fileURL: fileURL)
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

    private static func copyScreenshotToPasteboard(at path: String) {
        let url = URL(fileURLWithPath: path)

        DispatchQueue.main.async {
            guard let imageData = try? Data(contentsOf: url) else {
                return
            }

            let contents = pasteboardContents(imageData: imageData, fileURL: url)
            let item = NSPasteboardItem()
            item.setData(contents.pngData, forType: .png)
            item.setString(contents.fileURL.absoluteString, forType: .fileURL)

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([item])
        }
    }
}
