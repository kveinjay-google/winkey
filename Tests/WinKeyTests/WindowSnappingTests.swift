import CoreGraphics
import XCTest
@testable import WinKey

final class WindowSnappingTests: XCTestCase {
    // MARK: - WindowSnapLayout

    func testLayoutProducesHalvesFromVisibleFrame() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 900)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .leftHalf, currentFrame: current, visibleFrame: visible),
            CGRect(x: 0, y: 25, width: 720, height: 900)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .rightHalf, currentFrame: current, visibleFrame: visible),
            CGRect(x: 720, y: 25, width: 720, height: 900)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .topHalf, currentFrame: current, visibleFrame: visible),
            CGRect(x: 0, y: 25, width: 1440, height: 450)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .bottomHalf, currentFrame: current, visibleFrame: visible),
            CGRect(x: 0, y: 475, width: 1440, height: 450)
        )
    }

    func testLayoutProducesQuarters() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 900)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .topLeft, currentFrame: current, visibleFrame: visible),
            CGRect(x: 0, y: 25, width: 720, height: 450)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .topRight, currentFrame: current, visibleFrame: visible),
            CGRect(x: 720, y: 25, width: 720, height: 450)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .bottomLeft, currentFrame: current, visibleFrame: visible),
            CGRect(x: 0, y: 475, width: 720, height: 450)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .bottomRight, currentFrame: current, visibleFrame: visible),
            CGRect(x: 720, y: 475, width: 720, height: 450)
        )
    }

    func testLayoutMaximizesToVisibleFrame() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 900)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .maximize, currentFrame: current, visibleFrame: visible),
            visible
        )
    }

    func testLayoutCentersWindowKeepingSize() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 900)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .center, currentFrame: current, visibleFrame: visible),
            CGRect(x: 320, y: 175, width: 800, height: 600)
        )
    }

    func testLayoutRestoreHasNoGeometry() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 900)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        XCTAssertNil(WindowSnapLayout.targetFrame(for: .restore, currentFrame: current, visibleFrame: visible))
    }

    // MARK: - WindowSnapStateMachine

    func testStateMachineFromNeutralAppliesDirection() {
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: nil, direction: .leftHalf), .leftHalf)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: nil, direction: .rightHalf), .rightHalf)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: nil, direction: .topHalf), .maximize)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: nil, direction: .bottomHalf), .bottomHalf)
    }

    func testStateMachineTransitionsFromHalvesToQuarters() {
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .leftHalf, direction: .topHalf), .topLeft)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .leftHalf, direction: .bottomHalf), .bottomLeft)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .rightHalf, direction: .topHalf), .topRight)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .rightHalf, direction: .bottomHalf), .bottomRight)
    }

    func testStateMachineSwitchesHalvesAndMovesBetweenQuarters() {
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .leftHalf, direction: .rightHalf), .rightHalf)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .rightHalf, direction: .leftHalf), .leftHalf)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .topLeft, direction: .rightHalf), .topRight)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .topRight, direction: .leftHalf), .topLeft)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .bottomLeft, direction: .rightHalf), .bottomRight)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .bottomRight, direction: .leftHalf), .bottomLeft)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .topLeft, direction: .bottomHalf), .bottomLeft)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .bottomLeft, direction: .topHalf), .topLeft)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .topRight, direction: .bottomHalf), .bottomRight)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .bottomRight, direction: .topHalf), .topRight)
    }

    func testStateMachineQuarterExpandsToHalf() {
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .topLeft, direction: .leftHalf), .leftHalf)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .topRight, direction: .rightHalf), .rightHalf)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .bottomLeft, direction: .leftHalf), .leftHalf)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .bottomRight, direction: .rightHalf), .rightHalf)
    }

    func testStateMachineFromTopRowMaximizesAndFromBottomRowRestores() {
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .topHalf, direction: .topHalf), .maximize)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .topLeft, direction: .topHalf), .maximize)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .topRight, direction: .topHalf), .maximize)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .maximize, direction: .topHalf), .maximize)

        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .bottomHalf, direction: .bottomHalf), .restore)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .bottomLeft, direction: .bottomHalf), .restore)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .bottomRight, direction: .bottomHalf), .restore)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .maximize, direction: .bottomHalf), .restore)
    }

    func testStateMachineFromMaximizeMovesToHalves() {
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .maximize, direction: .leftHalf), .leftHalf)
        XCTAssertEqual(WindowSnapStateMachine.nextAction(current: .maximize, direction: .rightHalf), .rightHalf)
    }

    // MARK: - WindowSnapShortcuts

    func testShortcutChordsMapToActions() {
        let ctrlOption: CGEventFlags = [.maskControl, .maskAlternate]

        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: ctrlOption), .leftHalf)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.right, flags: ctrlOption), .rightHalf)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.up, flags: ctrlOption), .topHalf)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.down, flags: ctrlOption), .bottomHalf)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.c, flags: ctrlOption), .center)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.deleteForward, flags: ctrlOption), .restore)
    }

    func testShortcutChordsRejectExtraOrMissingModifiers() {
        let ctrlOption: CGEventFlags = [.maskControl, .maskAlternate]

        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: ctrlOption.union(.maskCommand)))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: ctrlOption.union(.maskShift)))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: [.maskCommand]))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: [.maskControl]))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: [.maskAlternate, .maskCommand]))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.c, flags: [.maskControl]))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.up, flags: []))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: []))
    }

    // MARK: - Settings and localization

    func testWindowSnappingDefaultOnAndPersists() {
        let defaults = UserDefaults(suiteName: "WindowSnappingTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)

        XCTAssertTrue(settings.windowSnapping)

        settings.windowSnapping = false
        XCTAssertFalse(settings.windowSnapping)
    }

    func testWindowSnappingMenuTextIsLocalized() {
        XCTAssertEqual(LocalizedText.windowSnapping(.english), "Snap windows (Ctrl + Option + arrows)")
        XCTAssertEqual(LocalizedText.windowSnapping(.chinese), "窗口分屏（Ctrl + Option + 方向键）")
    }
}
