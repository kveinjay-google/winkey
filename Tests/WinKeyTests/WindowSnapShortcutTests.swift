import CoreGraphics
import XCTest
@testable import WinKey

final class WindowSnapShortcutTests: XCTestCase {
    // MARK: - Codec

    func testShortcutCodecRoundTrip() {
        let cases: [(WindowSnapShortcut, String)] = [
            (WindowSnapShortcut(keyCode: KeyCode.left, flags: [.maskControl, .maskAlternate]), "control+option+left"),
            (WindowSnapShortcut(keyCode: KeyCode.c, flags: [.maskCommand]), "command+c"),
            (WindowSnapShortcut(keyCode: KeyCode.up, flags: [.maskControl, .maskAlternate, .maskShift]), "control+option+shift+up"),
            (WindowSnapShortcut(keyCode: KeyCode.deleteForward, flags: [.maskControl, .maskAlternate]), "control+option+delete")
        ]

        for (shortcut, encoded) in cases {
            XCTAssertEqual(shortcut.encoded, encoded)
            XCTAssertEqual(WindowSnapShortcut.decode(encoded), shortcut)
        }
    }

    func testShortcutDecodeRejectsInvalidStrings() {
        XCTAssertNil(WindowSnapShortcut.decode(""))
        XCTAssertNil(WindowSnapShortcut.decode("control+option"))
        XCTAssertNil(WindowSnapShortcut.decode("command+notakey"))
        XCTAssertNil(WindowSnapShortcut.decode("command+command+c"))
        XCTAssertNil(WindowSnapShortcut.decode("foo+bar"))
    }

    func testShortcutDisplayName() {
        XCTAssertEqual(WindowSnapShortcut(keyCode: KeyCode.left, flags: [.maskControl, .maskAlternate]).displayName, "⌃⌥←")
        XCTAssertEqual(WindowSnapShortcut(keyCode: KeyCode.c, flags: [.maskCommand]).displayName, "⌘C")
        XCTAssertEqual(WindowSnapShortcut(keyCode: KeyCode.up, flags: [.maskControl, .maskAlternate, .maskShift]).displayName, "⌃⌥⇧↑")
        XCTAssertEqual(WindowSnapShortcut(keyCode: KeyCode.deleteForward, flags: [.maskControl, .maskAlternate]).displayName, "⌃⌥⌫")
    }

    // MARK: - Action ids

    func testActionIdRoundTrip() {
        let actions: [WindowSnapAction] = [
            .leftHalf, .rightHalf, .topHalf, .bottomHalf,
            .topLeft, .topRight, .bottomLeft, .bottomRight,
            .maximize, .almostMaximize, .maximizeHeight,
            .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds,
            .previousDisplay, .nextDisplay, .center, .restore
        ]
        for action in actions {
            XCTAssertEqual(WindowSnapAction.action(withID: action.id), action, "roundtrip failed for \(action)")
        }
        XCTAssertNil(WindowSnapAction.action(withID: "notAnAction"))
    }

    // MARK: - Default chords

    func testDefaultChordsRoundTrip() {
        let actions: [WindowSnapAction] = [
            .leftHalf, .rightHalf, .topHalf, .bottomHalf,
            .topLeft, .topRight, .bottomLeft, .bottomRight,
            .maximize, .maximizeHeight, .firstThird, .centerThird,
            .lastThird, .firstTwoThirds, .lastTwoThirds,
            .previousDisplay, .nextDisplay, .center, .restore
        ]
        for action in actions {
            guard let chord = WindowSnapShortcuts.defaultChord(for: action) else {
                XCTFail("missing default chord for \(action)")
                continue
            }
            XCTAssertEqual(
                WindowSnapShortcuts.action(keyCode: chord.keyCode, flags: chord.flags),
                action,
                "default chord for \(action) does not map back"
            )
        }
        XCTAssertNil(WindowSnapShortcuts.defaultChord(for: .almostMaximize))
    }

    // MARK: - Resolver (custom overrides default)

    func testResolverPrefersCustomShortcut() {
        let custom = [
            "leftHalf": WindowSnapShortcut(keyCode: KeyCode.d, flags: [.maskControl, .maskAlternate]).encoded
        ]
        XCTAssertEqual(
            SnapShortcutResolver.action(
                keyCode: KeyCode.d,
                flags: [.maskControl, .maskAlternate],
                customShortcuts: custom
            ),
            .leftHalf
        )
    }

    func testResolverFallsBackToDefaults() {
        let custom = [
            "leftHalf": WindowSnapShortcut(keyCode: KeyCode.d, flags: [.maskControl, .maskAlternate]).encoded
        ]
        XCTAssertEqual(
            SnapShortcutResolver.action(
                keyCode: KeyCode.left,
                flags: [.maskControl, .maskAlternate],
                customShortcuts: custom
            ),
            .leftHalf
        )
    }

    func testResolverIgnoresInvalidCustomEntries() {
        let custom = [
            "leftHalf": "not+a+valid+chord",
            "maximize": "command+notakey"
        ]
        XCTAssertEqual(
            SnapShortcutResolver.action(
                keyCode: KeyCode.c,
                flags: [.maskCommand],
                customShortcuts: custom
            ),
            nil
        )
        XCTAssertEqual(
            SnapShortcutResolver.action(
                keyCode: KeyCode.left,
                flags: [.maskControl, .maskAlternate],
                customShortcuts: ["restore": "command+left"]
            ),
            .leftHalf
        )
    }

    func testResolverRequiresExactModifiers() {
        let custom = [
            "leftHalf": WindowSnapShortcut(keyCode: KeyCode.left, flags: [.maskControl, .maskAlternate]).encoded
        ]
        XCTAssertEqual(
            SnapShortcutResolver.action(
                keyCode: KeyCode.left,
                flags: [.maskControl, .maskAlternate, .maskCommand],
                customShortcuts: custom
            ),
            .previousDisplay
        )
    }

    // MARK: - Settings and localization

    func testCustomShortcutsPersist() {
        let defaults = UserDefaults(suiteName: "CustomShortcutsTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)

        XCTAssertTrue(settings.customSnapShortcuts.isEmpty)

        settings.customSnapShortcuts = ["leftHalf": "command+c"]
        XCTAssertEqual(settings.customSnapShortcuts["leftHalf"], "command+c")
    }

    func testShortcutRecorderTextIsLocalized() {
        XCTAssertEqual(LocalizedText.customShortcutSettings(.english), "Custom snap shortcuts…")
        XCTAssertEqual(LocalizedText.customShortcutSettings(.chinese), "自定义分屏快捷键…")
        XCTAssertEqual(LocalizedText.recordShortcut(.english), "Record")
        XCTAssertEqual(LocalizedText.recordShortcut(.chinese), "记录")
        XCTAssertEqual(LocalizedText.recordingPrompt(.english), "Press new shortcut… (Esc to cancel)")
        XCTAssertEqual(LocalizedText.recordingPrompt(.chinese), "按下新快捷键…（Esc 取消）")
        XCTAssertEqual(LocalizedText.clearShortcut(.english), "Clear")
        XCTAssertEqual(LocalizedText.clearShortcut(.chinese), "清除")
    }

    func testRecorderBuildsRowForEveryAction() {
        let defaults = UserDefaults(suiteName: "RecorderTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        let recorder = WindowSnapShortcutRecorder(settings: settings)

        recorder.show()
        XCTAssertTrue(recorder.isVisible)
        XCTAssertEqual(recorder.rowCount, WindowSnapAction.allCases.count)

        recorder.hide()
        XCTAssertFalse(recorder.isVisible)
    }
    func testRecorderSectionAndFooterTextIsLocalized() {
        XCTAssertEqual(LocalizedText.snapSectionHalvesQuarters(.english), "Halves & Quarters")
        XCTAssertEqual(LocalizedText.snapSectionHalvesQuarters(.chinese), "半屏与四分之一")
        XCTAssertEqual(LocalizedText.snapSectionSizes(.english), "Sizes")
        XCTAssertEqual(LocalizedText.snapSectionSizes(.chinese), "尺寸")
        XCTAssertEqual(LocalizedText.snapSectionDisplayAndRestore(.english), "Displays & Restore")
        XCTAssertEqual(LocalizedText.snapSectionDisplayAndRestore(.chinese), "显示器与还原")
        XCTAssertEqual(LocalizedText.resetAllShortcuts(.english), "Reset all")
        XCTAssertEqual(LocalizedText.resetAllShortcuts(.chinese), "恢复默认")
        XCTAssertEqual(LocalizedText.cancelRecording(.english), "Cancel")
        XCTAssertEqual(LocalizedText.cancelRecording(.chinese), "取消")
        XCTAssertEqual(LocalizedText.defaultShortcut(.english, shortcut: "⌃⌥←"), "Default ⌃⌥←")
        XCTAssertEqual(LocalizedText.defaultShortcut(.chinese, shortcut: "⌃⌥←"), "默认 ⌃⌥←")
    }
}
