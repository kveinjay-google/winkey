import XCTest
@testable import WinKey

final class PowerFeatureTests: XCTestCase {
    func testPowerFeaturesDefaultOffAndPersist() {
        let defaults = UserDefaults(suiteName: "PowerFeatureTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)

        XCTAssertFalse(settings.preventIdleSleep)
        XCTAssertFalse(settings.externalDisplayMouseWake)

        settings.preventIdleSleep = true
        settings.externalDisplayMouseWake = true

        XCTAssertTrue(settings.preventIdleSleep)
        XCTAssertTrue(settings.externalDisplayMouseWake)
    }

    func testPowerFeatureMenuTextIsLocalized() {
        XCTAssertEqual(LocalizedText.preventIdleSleep(.english), "Prevent idle system sleep")
        XCTAssertEqual(LocalizedText.preventIdleSleep(.chinese), "防止闲置睡眠")
        XCTAssertEqual(LocalizedText.externalDisplayMouseWake(.english), "Wake external display with mouse")
        XCTAssertEqual(LocalizedText.externalDisplayMouseWake(.chinese), "鼠标唤醒外接显示器")
    }
}
