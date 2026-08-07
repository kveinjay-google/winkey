import Foundation

enum AppLanguage: String {
    case english
    case chinese
}

enum ScreenshotShortcutModifier: String {
    case option
    case command

    var displayName: String {
        switch self {
        case .option:
            return "Option + A"
        case .command:
            return "Command + A"
        }
    }
}

final class SettingsStore {
    enum Key {
        static let language = "language"
        static let enabled = "enabled"
        static let deleteInFinder = "deleteInFinder"
        static let printScreen = "printScreen"
        static let homeEnd = "homeEnd"
        static let ctrlArrow = "ctrlArrow"
        static let ctrlASelectAll = "ctrlASelectAll"
        static let ctrlCommonShortcuts = "ctrlCommonShortcuts"
        static let altTab = "altTab"
        static let altAClipboardScreenshot = "altAClipboardScreenshot"
        static let screenshotShortcutModifier = "screenshotShortcutModifier"
        static let reverseScrollWheel = "reverseScrollWheel"
        static let windowSnapping = "windowSnapping"
        static let preventIdleSleep = "preventIdleSleep"
        static let externalDisplayMouseWake = "externalDisplayMouseWake"
        static let launchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.language: AppLanguage.english.rawValue,
            Key.enabled: true,
            Key.deleteInFinder: true,
            Key.printScreen: true,
            Key.homeEnd: true,
            Key.ctrlArrow: true,
            Key.ctrlASelectAll: true,
            Key.ctrlCommonShortcuts: true,
            Key.altTab: false,
            Key.altAClipboardScreenshot: true,
            Key.screenshotShortcutModifier: ScreenshotShortcutModifier.option.rawValue,
            Key.reverseScrollWheel: false,
            Key.windowSnapping: true,
            Key.preventIdleSleep: false,
            Key.externalDisplayMouseWake: false,
            Key.launchAtLogin: false
        ])
    }

    var language: AppLanguage {
        get {
            let rawValue = defaults.string(forKey: Key.language)
            return rawValue.flatMap(AppLanguage.init(rawValue:)) ?? .english
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.language)
        }
    }

    var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var deleteInFinder: Bool {
        get { defaults.bool(forKey: Key.deleteInFinder) }
        set { defaults.set(newValue, forKey: Key.deleteInFinder) }
    }

    var printScreen: Bool {
        get { defaults.bool(forKey: Key.printScreen) }
        set { defaults.set(newValue, forKey: Key.printScreen) }
    }

    var homeEnd: Bool {
        get { defaults.bool(forKey: Key.homeEnd) }
        set { defaults.set(newValue, forKey: Key.homeEnd) }
    }

    var ctrlArrow: Bool {
        get { defaults.bool(forKey: Key.ctrlArrow) }
        set { defaults.set(newValue, forKey: Key.ctrlArrow) }
    }

    var ctrlASelectAll: Bool {
        get { defaults.bool(forKey: Key.ctrlASelectAll) }
        set { defaults.set(newValue, forKey: Key.ctrlASelectAll) }
    }

    var ctrlCommonShortcuts: Bool {
        get { defaults.bool(forKey: Key.ctrlCommonShortcuts) }
        set { defaults.set(newValue, forKey: Key.ctrlCommonShortcuts) }
    }

    var altTab: Bool {
        get { defaults.bool(forKey: Key.altTab) }
        set { defaults.set(newValue, forKey: Key.altTab) }
    }

    var altAClipboardScreenshot: Bool {
        get { defaults.bool(forKey: Key.altAClipboardScreenshot) }
        set { defaults.set(newValue, forKey: Key.altAClipboardScreenshot) }
    }

    var screenshotShortcutModifier: ScreenshotShortcutModifier {
        get {
            let rawValue = defaults.string(forKey: Key.screenshotShortcutModifier)
            return rawValue.flatMap(ScreenshotShortcutModifier.init(rawValue:)) ?? .option
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.screenshotShortcutModifier)
        }
    }

    var reverseScrollWheel: Bool {
        get { defaults.bool(forKey: Key.reverseScrollWheel) }
        set { defaults.set(newValue, forKey: Key.reverseScrollWheel) }
    }

    var windowSnapping: Bool {
        get { defaults.bool(forKey: Key.windowSnapping) }
        set { defaults.set(newValue, forKey: Key.windowSnapping) }
    }

    var preventIdleSleep: Bool {
        get { defaults.bool(forKey: Key.preventIdleSleep) }
        set { defaults.set(newValue, forKey: Key.preventIdleSleep) }
    }

    var externalDisplayMouseWake: Bool {
        get { defaults.bool(forKey: Key.externalDisplayMouseWake) }
        set { defaults.set(newValue, forKey: Key.externalDisplayMouseWake) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }
}
