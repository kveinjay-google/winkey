import AppKit

final class PermissionWindowController: NSWindowController {
    convenience init() {
        let viewController = PermissionViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "开启 WinKey"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 420, height: 190))
        window.center()
        self.init(window: window)
    }
}

final class PermissionViewController: NSViewController {
    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView(image: NSImage(systemSymbolName: "keyboard", accessibilityDescription: "键盘") ?? NSImage())
        iconView.symbolConfiguration = .init(pointSize: 28, weight: .medium)
        iconView.contentTintColor = .controlAccentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "允许 WinKey 接管键盘")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 0

        let bodyLabel = NSTextField(labelWithString: "在系统设置中开启“辅助功能”，即可使用 Delete、PrtSc、Home/End 等 Windows 键盘习惯。")
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.maximumNumberOfLines = 2

        let openButton = NSButton(title: "打开设置", target: self, action: #selector(openSettings))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"

        let buttonStack = NSStackView(views: [openButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fill
        buttonStack.spacing = 10
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [titleLabel, bodyLabel, buttonStack])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 12
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [iconView, textStack])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 34),
            iconView.heightAnchor.constraint(equalToConstant: 34),
            openButton.widthAnchor.constraint(equalToConstant: 118),
            openButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        view = root
    }

    @objc private func openSettings() {
        AccessibilityPermission.openSystemSettings()
    }
}
