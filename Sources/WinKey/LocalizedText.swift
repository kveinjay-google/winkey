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

    static func windowSnapping(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Snap windows (Ctrl + Option + arrows)"
        case .chinese: return "窗口分屏（Ctrl + Option + 方向键）"
        }
    }

    static func dragSnapping(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Snap windows by dragging to screen edges"
        case .chinese: return "拖动窗口到屏幕边缘自动分屏"
        }
    }

    static func windowSnapActionsMenu(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Window snap actions"
        case .chinese: return "窗口分屏操作"
        }
    }

    static func customShortcutSettings(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Custom snap shortcuts…"
        case .chinese: return "自定义分屏快捷键…"
        }
    }

    static func recordShortcut(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Record"
        case .chinese: return "记录"
        }
    }

    static func recordingPrompt(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Press new shortcut… (Esc to cancel)"
        case .chinese: return "按下新快捷键…（Esc 取消）"
        }
    }

    static func clearShortcut(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Clear"
        case .chinese: return "清除"
        }
    }

    static func windowSnapActionName(_ action: WindowSnapAction, _ language: AppLanguage) -> String {
        switch action {
        case .leftHalf:
            return language == .english ? "Left half" : "左半屏"
        case .rightHalf:
            return language == .english ? "Right half" : "右半屏"
        case .topHalf:
            return language == .english ? "Top half" : "上半屏"
        case .bottomHalf:
            return language == .english ? "Bottom half" : "下半屏"
        case .topLeft:
            return language == .english ? "Top-left quarter" : "左上四分之一"
        case .topRight:
            return language == .english ? "Top-right quarter" : "右上四分之一"
        case .bottomLeft:
            return language == .english ? "Bottom-left quarter" : "左下四分之一"
        case .bottomRight:
            return language == .english ? "Bottom-right quarter" : "右下四分之一"
        case .maximize:
            return language == .english ? "Maximize" : "最大化"
        case .almostMaximize:
            return language == .english ? "Almost maximize" : "接近最大化"
        case .maximizeHeight:
            return language == .english ? "Maximize height" : "最大化高度"
        case .firstThird:
            return language == .english ? "First third" : "左三分之一"
        case .centerThird:
            return language == .english ? "Center third" : "中间三分之一"
        case .lastThird:
            return language == .english ? "Last third" : "右三分之一"
        case .firstTwoThirds:
            return language == .english ? "First two thirds" : "左三分之二"
        case .lastTwoThirds:
            return language == .english ? "Last two thirds" : "右三分之二"
        case .previousDisplay:
            return language == .english ? "Previous display" : "上一显示器"
        case .nextDisplay:
            return language == .english ? "Next display" : "下一显示器"
        case .center:
            return language == .english ? "Center" : "居中"
        case .restore:
            return language == .english ? "Restore" : "还原"
        }
    }

    static func preventIdleSleep(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Prevent idle system sleep"
        case .chinese: return "防止闲置睡眠"
        }
    }

    static func externalDisplayMouseWake(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "Wake external display with mouse"
        case .chinese: return "鼠标唤醒外接显示器"
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
