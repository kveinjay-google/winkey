import AppKit
import XCTest
@testable import WinKey

final class WindowSnapIconTests: XCTestCase {
    func testEveryActionProducesATemplateIcon() {
        for action in WindowSnapAction.allCases {
            let image = WindowSnapIcon.image(for: action)
            XCTAssertTrue(image.isTemplate, "icon for \(action) must be a template image")
            XCTAssertEqual(image.size, NSSize(width: 16, height: 16), "icon for \(action) has wrong size")
        }
    }

    func testHalfIconsDifferFromEachOther() {
        let left = WindowSnapIcon.image(for: .leftHalf)
        let right = WindowSnapIcon.image(for: .rightHalf)
        XCTAssertNotEqual(left.tiffRepresentation, right.tiffRepresentation)
    }

    func testEqualAndUnequalSplitIconsDiffer() {
        let half = WindowSnapIcon.image(for: .leftHalf)
        let third = WindowSnapIcon.image(for: .firstThird)
        XCTAssertNotEqual(half.tiffRepresentation, third.tiffRepresentation)
    }

    func testMaximizeFillsMoreThanAlmostMaximize() {
        let maximize = WindowSnapIcon.image(for: .maximize)
        let almost = WindowSnapIcon.image(for: .almostMaximize)
        XCTAssertNotEqual(maximize.tiffRepresentation, almost.tiffRepresentation)
    }
}
