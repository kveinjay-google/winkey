enum LocalizedText {
    static func appToolTip(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Windows keyboard habits"
        case .chinese: return "Windows 键盘习惯"
        }
    }

    static func statusUnauthorized(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Status: Not Authorized"
        case .chinese: return "状态：未授权"
        }
    }

    static func statusEnabled(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Status: Enabled"
        case .chinese: return "状态：已启用"
        }
    }

    static func statusPaused(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Status: Paused"
        case .chinese: return "状态：已暂停"
        }
    }

    static func statusInputMonitoringNeeded(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Status: Input Monitoring needed"
        case .chinese: return "状态：需要输入监控权限"
        }
    }

    static func enableKeyboardHabits(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Enable Windows keyboard habits"
        case .chinese: return "启用 Windows 键盘习惯"
        }
    }

    static func deleteFinderFiles(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Delete Finder files with confirmation"
        case .chinese: return "Delete 删除 Finder 文件前确认"
        }
    }

    static func printScreen(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "PrtSc save full-screen screenshot"
        case .chinese: return "PrtSc 全屏截图保存到桌面"
        }
    }

    static func clipboardScreenshot(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Manual screenshot to Desktop and clipboard"
        case .chinese: return "手动截图保存到桌面并复制"
        }
    }

    static func screenshotShortcut(_ language: AppLanguage, shortcut: String) -> String {
        switch language {
        case .english: return "Screenshot shortcut: \(shortcut)"
        case .chinese: return "截图快捷键：\(shortcut)"
        }
    }

    static func homeEndNavigation(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Home / End text navigation"
        case .chinese: return "Home / End 文本导航"
        }
    }

    static func ctrlArrowNavigation(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Ctrl + Arrow text navigation"
        case .chinese: return "Ctrl + 方向键文本导航"
        }
    }

    static func ctrlASelectAll(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Ctrl + A select all"
        case .chinese: return "Ctrl + A 全选"
        }
    }

    static func ctrlCommonShortcuts(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Common Ctrl shortcuts"
        case .chinese: return "Ctrl 常用快捷键"
        }
    }

    static func altTab(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Alt + Tab app switching"
        case .chinese: return "Alt + Tab 切换应用"
        }
    }

    static func reverseScroll(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Reverse scroll direction"
        case .chinese: return "反转滚动方向"
        }
    }

    static func scrollDiagnostics(_ language: AppLanguage, summary: String) -> String {
        switch language {
        case .english: return "Scroll debug: \(summary)"
        case .chinese: return "滚轮调试：\(summary)"
        }
    }

    static func invertSyntheticScrollSign(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Flip synthetic scroll direction"
        case .chinese: return "切换合成滚轮方向"
        }
    }

    static func launchAtLogin(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Launch at login"
        case .chinese: return "开机启动"
        }
    }

    static func openAccessibilitySettings(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Open Accessibility Settings..."
        case .chinese: return "打开辅助功能权限设置..."
        }
    }

    static func openInputMonitoringSettings(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Open Input Monitoring Settings..."
        case .chinese: return "打开输入监控权限设置..."
        }
    }

    static func languageMenu(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Language: English"
        case .chinese: return "语言：中文"
        }
    }

    static func version(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Version \(AppVersion.shortVersion) (\(AppVersion.build))"
        case .chinese: return "版本 \(AppVersion.shortVersion) (\(AppVersion.build))"
        }
    }

    static func quit(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Quit WinKey"
        case .chinese: return "退出 WinKey"
        }
    }

    static func launchAtLoginErrorTitle(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Could not update launch at login"
        case .chinese: return "无法更新开机启动"
        }
    }

    static func deleteAlertTitle(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Move selected items to Trash?"
        case .chinese: return "是否将所选项目移到废纸篓？"
        }
    }

    static func deleteAlertMessage(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "This is the same as pressing Command + Delete in Finder. You can restore items from Trash."
        case .chinese: return "此操作等同于在 Finder 中按 Command + Delete，可从废纸篓恢复。"
        }
    }

    static func moveToTrash(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Move to Trash"
        case .chinese: return "移到废纸篓"
        }
    }

    static func cancel(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Cancel"
        case .chinese: return "取消"
        }
    }

    static func permissionWindowTitle(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Enable WinKey"
        case .chinese: return "开启 WinKey"
        }
    }

    static func permissionIconDescription(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Keyboard"
        case .chinese: return "键盘"
        }
    }

    static func permissionTitle(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Allow WinKey to control the keyboard"
        case .chinese: return "允许 WinKey 接管键盘"
        }
    }

    static func permissionBody(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Enable Accessibility in System Settings to use Delete, PrtSc, Home/End, and other Windows keyboard habits."
        case .chinese: return "在系统设置中开启“辅助功能”，即可使用 Delete、PrtSc、Home/End 等 Windows 键盘习惯。"
        }
    }

    static func openSettings(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Open Settings"
        case .chinese: return "打开设置"
        }
    }
}
