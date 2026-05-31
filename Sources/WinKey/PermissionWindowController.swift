import AppKit

final class PermissionWindowController: NSWindowController {
    convenience init(settings: SettingsStore) {
        let viewController = PermissionViewController(settings: settings)
        let window = NSWindow(contentViewController: viewController)
        window.title = LocalizedText.permissionWindowTitle(settings.language)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 420, height: 190))
        window.center()
        self.init(window: window)
    }

    func refreshLanguage(_ language: AppLanguage) {
        window?.title = LocalizedText.permissionWindowTitle(language)
        (contentViewController as? PermissionViewController)?.refreshLanguage()
    }
}

final class PermissionViewController: NSViewController {
    private let settings: SettingsStore
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(labelWithString: "")
    private let openButton = NSButton()

    init(settings: SettingsStore) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView(image: NSImage(systemSymbolName: "keyboard", accessibilityDescription: LocalizedText.permissionIconDescription(settings.language)) ?? NSImage())
        iconView.symbolConfiguration = .init(pointSize: 28, weight: .medium)
        iconView.contentTintColor = .controlAccentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.maximumNumberOfLines = 0

        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.maximumNumberOfLines = 2

        openButton.target = self
        openButton.action = #selector(openSettings)
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

        refreshLanguage()
        view = root
    }

    func refreshLanguage() {
        titleLabel.stringValue = LocalizedText.permissionTitle(settings.language)
        bodyLabel.stringValue = LocalizedText.permissionBody(settings.language)
        openButton.title = LocalizedText.openSettings(settings.language)
    }

    @objc private func openSettings() {
        AccessibilityPermission.openSystemSettings()
    }
}
