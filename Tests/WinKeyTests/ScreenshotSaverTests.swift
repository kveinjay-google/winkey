import AppKit
import XCTest
@testable import WinKey

final class ScreenshotSaverTests: XCTestCase {
    func testPasteboardContentsIncludeImageDataAndFileURL() throws {
        let url = URL(fileURLWithPath: "/Users/example/Desktop/WinKey Screenshot 2026-07-09 12.34.56.png")
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])

        let contents = ScreenshotSaver.pasteboardContents(imageData: imageData, fileURL: url)

        XCTAssertEqual(contents.pngData, imageData)
        XCTAssertEqual(contents.fileURL, url)
    }
}
