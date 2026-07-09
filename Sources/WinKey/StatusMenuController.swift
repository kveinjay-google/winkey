import AppKit
import ServiceManagement

final class StatusMenuController: NSObject {
    private let settings: SettingsStore
    private let keyboardMapper: KeyboardMapper
    private let permissionWindow: PermissionWindowController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let statusMenuItem = NSMenuItem()
    private let enabledItem = NSMenuItem()
    private let deleteItem = NSMenuItem()
    private let printScreenItem = NSMenuItem()
    private let homeEndItem = NSMenuItem()
    private let ctrlArrowItem = NSMenuItem()
    private let ctrlASelectAllItem = NSMenuItem()
    private let ctrlCommonShortcutsItem = NSMenuItem()
    private let altAScreenshotItem = NSMenuItem()
    private let screenshotShortcutItem = NSMenuItem()
    private let altTabItem = NSMenuItem()
    private let reverseScrollItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()
    private let languageItem = NSMenuItem()
    private let inputMonitoringItem = NSMenuItem()
    private let versionItem = NSMenuItem()

    init(
        settings: SettingsStore,
        keyboardMapper: KeyboardMapper,
        permissionWindow: PermissionWindowController
    ) {
        self.settings = settings
        self.keyboardMapper = keyboardMapper
        self.permissionWindow = permissionWindow
        super.init()
    }

    func install() {
        statusItem.button?.title = "WinKey"
        statusItem.button?.toolTip = "Windows 键盘习惯"

        let menu = NSMenu()
        configure(item: statusMenuItem, action: nil)
        configure(item: enabledItem, action: #selector(toggleEnabled))
        configure(item: deleteItem, action: #selector(toggleDelete))
        configure(item: printScreenItem, action: #selector(togglePrintScreen))
        configure(item: homeEndItem, action: #selector(toggleHomeEnd))
        configure(item: ctrlArrowItem, action: #selector(toggleCtrlArrow))
        configure(item: ctrlASelectAllItem, action: #selector(toggleCtrlASelectAll))
        configure(item: ctrlCommonShortcutsItem, action: #selector(toggleCtrlCommonShortcuts))
        configure(item: altAScreenshotItem, action: #selector(toggleAltAScreenshot))
        configure(item: screenshotShortcutItem, action: #selector(toggleScreenshotShortcut))
        configure(item: altTabItem, action: #selector(toggleAltTab))
        configure(item: reverseScrollItem, action: #selector(toggleReverseScroll))
        configure(item: launchAtLoginItem, action: #selector(toggleLaunchAtLogin))
        configure(item: languageItem, action: #selector(toggleLanguage))
        configure(item: inputMonitoringItem, action: #selector(openInputMonitoringSettings))

        let permissionItem = NSMenuItem(
            title: "",
            action: #selector(openPermissionSettings),
            keyEquivalent: ""
        )
        permissionItem.target = self

        let quitItem = NSMenuItem(
            title: "",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(enabledItem)
        menu.addItem(.separator())
        menu.addItem(deleteItem)
        menu.addItem(printScreenItem)
        menu.addItem(altAScreenshotItem)
        menu.addItem(screenshotShortcutItem)
        menu.addItem(homeEndItem)
        menu.addItem(ctrlArrowItem)
        menu.addItem(ctrlASelectAllItem)
        menu.addItem(ctrlCommonShortcutsItem)
        menu.addItem(altTabItem)
        menu.addItem(reverseScrollItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
        menu.addItem(languageItem)
        menu.addItem(permissionItem)
        menu.addItem(inputMonitoringItem)
        menu.addItem(.separator())
        menu.addItem(versionItem)
        menu.addItem(quitItem)

        statusItem.menu = menu
        installCtrlCommonSubmenu()
        refresh()
    }

    private func configure(item: NSMenuItem, action: Selector?) {
        item.target = self
        item.action = action
    }

    func refresh() {
        let language = settings.language
        let inputMonitoringNeeded = settings.reverseScrollWheel && !InputMonitoringPermission.isTrusted
        statusItem.button?.toolTip = LocalizedText.appToolTip(language)

        if !AccessibilityPermission.isTrusted {
            statusMenuItem.title = LocalizedText.statusUnauthorized(language)
        } else if inputMonitoringNeeded {
            statusMenuItem.title = LocalizedText.statusInputMonitoringNeeded(language)
        } else if settings.enabled {
            statusMenuItem.title = LocalizedText.statusEnabled(language)
        } else {
            statusMenuItem.title = LocalizedText.statusPaused(language)
        }

        enabledItem.title = LocalizedText.enableKeyboardHabits(language)
        enabledItem.state = settings.enabled ? .on : .off

        deleteItem.title = LocalizedText.deleteFinderFiles(language)
        deleteItem.state = settings.deleteInFinder ? .on : .off

        printScreenItem.title = LocalizedText.printScreen(language)
        printScreenItem.state = settings.printScreen ? .on : .off

        altAScreenshotItem.title = LocalizedText.clipboardScreenshot(language)
        altAScreenshotItem.state = settings.altAClipboardScreenshot ? .on : .off

        screenshotShortcutItem.title = LocalizedText.screenshotShortcut(language, shortcut: settings.screenshotShortcutModifier.displayName)

        homeEndItem.title = LocalizedText.homeEndNavigation(language)
        homeEndItem.state = settings.homeEnd ? .on : .off

        ctrlArrowItem.title = LocalizedText.ctrlArrowNavigation(language)
        ctrlArrowItem.state = settings.ctrlArrow ? .on : .off

        ctrlASelectAllItem.title = LocalizedText.ctrlASelectAll(language)
        ctrlASelectAllItem.state = settings.ctrlASelectAll ? .on : .off

        ctrlCommonShortcutsItem.title = LocalizedText.ctrlCommonShortcuts(language)
        ctrlCommonShortcutsItem.state = settings.ctrlCommonShortcuts ? .on : .off

        altTabItem.title = LocalizedText.altTab(language)
        altTabItem.state = settings.altTab ? .on : .off

        reverseScrollItem.title = LocalizedText.reverseScroll(language)
        reverseScrollItem.state = settings.reverseScrollWheel ? .on : .off

        launchAtLoginItem.title = LocalizedText.launchAtLogin(language)
        launchAtLoginItem.state = settings.launchAtLogin ? .on : .off

        languageItem.title = LocalizedText.languageMenu(language)
        inputMonitoringItem.title = LocalizedText.openInputMonitoringSettings(language)
        inputMonitoringItem.isHidden = !inputMonitoringNeeded

        if let permissionItem = statusItem.menu?.items.first(where: { $0.action == #selector(openPermissionSettings) }) {
            permissionItem.title = LocalizedText.openAccessibilitySettings(language)
        }

        if let quitItem = statusItem.menu?.items.first(where: { $0.action == #selector(quit) }) {
            quitItem.title = LocalizedText.quit(language)
        }

        versionItem.title = LocalizedText.version(language)
        versionItem.isEnabled = false

        statusItem.button?.title = AccessibilityPermission.isTrusted && settings.enabled && !inputMonitoringNeeded ? "WinKey" : "WinKey!"
        permissionWindow.refreshLanguage(language)
    }

    private func installCtrlCommonSubmenu() {
        let submenu = NSMenu()
        [
            "Ctrl + C -> Command + C",
            "Ctrl + V -> Command + V",
            "Ctrl + X -> Command + X",
            "Ctrl + Z -> Command + Z",
            "Ctrl + Y -> Command + Shift + Z",
            "Ctrl + F -> Command + F",
            "Ctrl + S -> Command + S",
            "Ctrl + P -> Command + P",
            "Ctrl + W -> Command + W",
            "Ctrl + T -> Command + T",
            "Ctrl + Shift + T -> Command + Shift + T",
            "Ctrl + N -> Command + N",
            "Ctrl + Shift + N -> Command + Shift + N",
            "Ctrl + O -> Command + O",
            "Ctrl + R -> Command + R"
        ].forEach { title in
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            submenu.addItem(item)
        }

        ctrlCommonShortcutsItem.submenu = submenu
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        keyboardMapper.restart()
        refresh()
    }

    @objc private func toggleDelete() {
        settings.deleteInFinder.toggle()
        refresh()
    }

    @objc private func togglePrintScreen() {
        settings.printScreen.toggle()
        refresh()
    }

    @objc private func toggleHomeEnd() {
        settings.homeEnd.toggle()
        refresh()
    }

    @objc private func toggleCtrlArrow() {
        settings.ctrlArrow.toggle()
        refresh()
    }

    @objc private func toggleCtrlASelectAll() {
        settings.ctrlASelectAll.toggle()
        refresh()
    }

    @objc private func toggleCtrlCommonShortcuts() {
        settings.ctrlCommonShortcuts.toggle()
        refresh()
    }

    @objc private func toggleAltAScreenshot() {
        settings.altAClipboardScreenshot.toggle()
        refresh()
    }

    @objc private func toggleScreenshotShortcut() {
        settings.screenshotShortcutModifier = settings.screenshotShortcutModifier == .option ? .command : .option
        refresh()
    }

    @objc private func toggleAltTab() {
        settings.altTab.toggle()
        refresh()
    }

    @objc private func toggleReverseScroll() {
        settings.reverseScrollWheel.toggle()
        refresh()
    }

    @objc private func toggleLanguage() {
        settings.language = settings.language == .english ? .chinese : .english
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        let shouldEnable = !settings.launchAtLogin

        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            settings.launchAtLogin = shouldEnable
        } catch {
            showError(title: LocalizedText.launchAtLoginErrorTitle(settings.language), message: error.localizedDescription)
        }

        refresh()
    }

    @objc private func openPermissionSettings() {
        permissionWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        AccessibilityPermission.requestPrompt()
        AccessibilityPermission.openSystemSettings()
        keyboardMapper.restart()
        refresh()
    }

    @objc private func openInputMonitoringSettings() {
        InputMonitoringPermission.requestPrompt()
        InputMonitoringPermission.openSystemSettings()
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
