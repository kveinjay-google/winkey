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

    func testLayoutProducesThirds() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 900)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .firstThird, currentFrame: current, visibleFrame: visible),
            CGRect(x: 0, y: 25, width: 480, height: 900)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .centerThird, currentFrame: current, visibleFrame: visible),
            CGRect(x: 480, y: 25, width: 480, height: 900)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .lastThird, currentFrame: current, visibleFrame: visible),
            CGRect(x: 960, y: 25, width: 480, height: 900)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .firstTwoThirds, currentFrame: current, visibleFrame: visible),
            CGRect(x: 0, y: 25, width: 960, height: 900)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .lastTwoThirds, currentFrame: current, visibleFrame: visible),
            CGRect(x: 480, y: 25, width: 960, height: 900)
        )
    }

    func testLayoutAlmostMaximizeAndMaximizeHeight() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 900)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .almostMaximize, currentFrame: current, visibleFrame: visible),
            CGRect(x: 10, y: 35, width: 1420, height: 880)
        )
        XCTAssertEqual(
            WindowSnapLayout.targetFrame(for: .maximizeHeight, currentFrame: current, visibleFrame: visible),
            CGRect(x: 100, y: 25, width: 800, height: 900)
        )
    }

    func testLayoutRestoreHasNoGeometry() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 900)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        XCTAssertNil(WindowSnapLayout.targetFrame(for: .restore, currentFrame: current, visibleFrame: visible))
    }

    // MARK: - SnapAreaDetector

    func testSnapAreaDetectorFindsEdgesAndCorners() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 1, y: 450), screenFrame: screen, priorAction: nil),
            .leftHalf
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 1439, y: 450), screenFrame: screen, priorAction: nil),
            .rightHalf
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 720, y: 899), screenFrame: screen, priorAction: nil),
            .maximize
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 2, y: 897), screenFrame: screen, priorAction: nil),
            .topLeft
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 1437, y: 897), screenFrame: screen, priorAction: nil),
            .topRight
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 2, y: 2), screenFrame: screen, priorAction: nil),
            .bottomLeft
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 1437, y: 2), screenFrame: screen, priorAction: nil),
            .bottomRight
        )
    }

    func testSnapAreaDetectorBottomThird() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 200, y: 1), screenFrame: screen, priorAction: nil),
            .firstThird
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 720, y: 1), screenFrame: screen, priorAction: nil),
            .centerThird
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 1300, y: 1), screenFrame: screen, priorAction: nil),
            .lastThird
        )
    }

    func testSnapAreaDetectorCompoundThirds() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 720, y: 1), screenFrame: screen, priorAction: .firstThird),
            .firstTwoThirds
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 720, y: 1), screenFrame: screen, priorAction: .firstTwoThirds),
            .firstTwoThirds
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 720, y: 1), screenFrame: screen, priorAction: .lastThird),
            .lastTwoThirds
        )
        XCTAssertEqual(
            SnapAreaDetector.action(cursor: CGPoint(x: 720, y: 1), screenFrame: screen, priorAction: .lastTwoThirds),
            .lastTwoThirds
        )
    }

    func testSnapAreaDetectorCenterIsNotASnapArea() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        XCTAssertNil(SnapAreaDetector.directional(cursor: CGPoint(x: 720, y: 450), screenFrame: screen))
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

    func testShortcutChordsForExtendedActions() {
        let ctrlOption: CGEventFlags = [.maskControl, .maskAlternate]
        let ctrlOptionCommand = ctrlOption.union(.maskCommand)
        let ctrlOptionShift = ctrlOption.union(.maskShift)

        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: ctrlOptionCommand), .previousDisplay)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.right, flags: ctrlOptionCommand), .nextDisplay)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.d, flags: ctrlOption), .firstThird)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.e, flags: ctrlOption), .firstTwoThirds)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.f, flags: ctrlOption), .centerThird)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.t, flags: ctrlOption), .lastTwoThirds)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.g, flags: ctrlOption), .lastThird)
        XCTAssertEqual(WindowSnapShortcuts.action(keyCode: KeyCode.up, flags: ctrlOptionShift), .maximizeHeight)
    }

    func testShortcutChordsRejectExtraOrMissingModifiers() {
        let ctrlOption: CGEventFlags = [.maskControl, .maskAlternate]

        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.c, flags: ctrlOption.union(.maskCommand)))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: ctrlOption.union(.maskShift)))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: [.maskCommand]))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: [.maskControl]))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: [.maskAlternate, .maskCommand]))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.c, flags: [.maskControl]))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.up, flags: []))
        XCTAssertNil(WindowSnapShortcuts.action(keyCode: KeyCode.left, flags: []))
    }

    func testDragSnappingDefaultOnAndPersists() {
        let defaults = UserDefaults(suiteName: "DragSnappingTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)

        XCTAssertTrue(settings.dragSnapping)

        settings.dragSnapping = false
        XCTAssertFalse(settings.dragSnapping)
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
