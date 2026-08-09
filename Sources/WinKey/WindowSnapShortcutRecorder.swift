import AppKit

/// Settings panel for recording custom window-snap shortcuts: grouped rows with
/// layout icons, keycap-style shortcut display, a focused recording state, and
/// a footer with hints and a reset-all action. Built entirely with Auto Layout.
final class WindowSnapShortcutRecorder: NSObject, NSWindowDelegate {
    private struct Row {
        let action: WindowSnapAction
        let container: NSView
        let nameLabel: NSTextField
        let defaultLabel: NSTextField
        let keycap: KeycapView
        let recordButton: NSButton
        let clearButton: NSButton
    }

    private struct Section {
        let actions: [WindowSnapAction]
    }

    private let settings: SettingsStore
    private var panel: NSPanel?
    private var rows: [WindowSnapAction: Row] = [:]
    private var sectionHeaderLabels: [NSTextField] = []
    private var headerTitleLabel: NSTextField?
    private var headerSubtitleLabel: NSTextField?
    private var hintLabel: NSTextField?
    private var resetButton: NSButton?
    private var recordingAction: WindowSnapAction?
    private var localMonitor: Any?

    var rowCount: Int { rows.count }
    var isVisible: Bool { panel?.isVisible == true }

    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    private static let escapeKeyCode: UInt16 = 53

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func show() {
        if panel == nil {
            buildPanel()
        }
        refresh()
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        cancelRecording()
        panel?.orderOut(nil)
    }

    // MARK: - Panel construction

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 680),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 540, height: 560)
        panel.delegate = self

        let root = NSVisualEffectView()
        root.material = .sidebar
        root.blendingMode = .behindWindow
        root.state = .active
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = root

        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [titleLabel, subtitleLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 3
        header.translatesAutoresizingMaskIntoConstraints = false

        // Scrollable grouped content.
        let document = NSStackView()
        document.orientation = .vertical
        document.alignment = .leading
        document.spacing = 16
        document.translatesAutoresizingMaskIntoConstraints = false

        for (index, section) in Self.sections().enumerated() {
            let sectionHeader = NSTextField(labelWithString: "")
            sectionHeader.font = .systemFont(ofSize: 12, weight: .semibold)
            sectionHeader.textColor = .secondaryLabelColor
            sectionHeader.translatesAutoresizingMaskIntoConstraints = false
            document.addArrangedSubview(sectionHeader)
            sectionHeader.widthAnchor.constraint(equalTo: document.widthAnchor).isActive = true
            sectionHeaderLabels.append(sectionHeader)
            _ = index

            for action in section.actions {
                let row = makeRow(for: action)
                document.addArrangedSubview(row.container)
                row.container.widthAnchor.constraint(equalTo: document.widthAnchor).isActive = true
                rows[action] = row
            }
        }

        let documentContainer = NSView()
        documentContainer.translatesAutoresizingMaskIntoConstraints = false
        documentContainer.addSubview(document)
        NSLayoutConstraint.activate([
            document.leadingAnchor.constraint(equalTo: documentContainer.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: documentContainer.trailingAnchor),
            document.topAnchor.constraint(equalTo: documentContainer.topAnchor),
            document.bottomAnchor.constraint(equalTo: documentContainer.bottomAnchor)
        ])

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = documentContainer

        let hint = NSTextField(wrappingLabelWithString: "")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        let reset = NSButton(title: "", target: self, action: #selector(resetAllTapped))
        reset.bezelStyle = .rounded
        reset.translatesAutoresizingMaskIntoConstraints = false

        let footer = NSStackView(views: [hint, reset])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 12
        footer.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(header)
        root.addSubview(scrollView)
        root.addSubview(footer)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),

            footer.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 12),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),

            documentContainer.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        headerTitleLabel = titleLabel
        headerSubtitleLabel = subtitleLabel
        hintLabel = hint
        resetButton = reset
        self.panel = panel
    }

    private func makeRow(for action: WindowSnapAction) -> Row {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.cornerRadius = 8

        let iconView = NSImageView()
        iconView.image = WindowSnapIcon.image(for: action)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let defaultLabel = NSTextField(labelWithString: "")
        defaultLabel.font = .systemFont(ofSize: 11)
        defaultLabel.textColor = .tertiaryLabelColor
        defaultLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameStack = NSStackView(views: [nameLabel, defaultLabel])
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = 1
        nameStack.translatesAutoresizingMaskIntoConstraints = false

        let keycap = KeycapView()
        keycap.translatesAutoresizingMaskIntoConstraints = false

        let recordButton = NSButton(title: "", target: self, action: #selector(recordTapped(_:)))
        recordButton.bezelStyle = .rounded
        recordButton.identifier = NSUserInterfaceItemIdentifier(action.id)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true

        let clearButton = NSButton(title: "", target: self, action: #selector(clearTapped(_:)))
        clearButton.bezelStyle = .rounded
        clearButton.identifier = NSUserInterfaceItemIdentifier(action.id)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 62).isActive = true

        let rowStack = NSStackView(views: [iconView, nameStack, keycap, recordButton, clearButton])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 12
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(rowStack)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 52),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            rowStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            keycap.widthAnchor.constraint(greaterThanOrEqualToConstant: 124),
            nameStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])

        return Row(
            action: action,
            container: container,
            nameLabel: nameLabel,
            defaultLabel: defaultLabel,
            keycap: keycap,
            recordButton: recordButton,
            clearButton: clearButton
        )
    }

    private static func sections() -> [Section] {
        [
            Section(actions: [.leftHalf, .rightHalf, .topHalf, .bottomHalf,
                              .topLeft, .topRight, .bottomLeft, .bottomRight]),
            Section(actions: [.maximize, .almostMaximize, .maximizeHeight,
                              .firstThird, .centerThird, .lastThird,
                              .firstTwoThirds, .lastTwoThirds]),
            Section(actions: [.previousDisplay, .nextDisplay, .center, .restore])
        ]
    }

    // MARK: - Refresh

    private func refresh() {
        let language = settings.language
        let custom = settings.customSnapShortcuts

        panel?.title = LocalizedText.customShortcutSettings(language)
        headerTitleLabel?.stringValue = LocalizedText.customShortcutSettings(language)
        headerSubtitleLabel?.stringValue = LocalizedText.recorderSubtitle(language)
        hintLabel?.stringValue = LocalizedText.recordingHint(language)
        resetButton?.title = LocalizedText.resetAllShortcuts(language)
        resetButton?.isEnabled = !custom.isEmpty

        let sectionTitles: [String] = [
            LocalizedText.snapSectionHalvesQuarters(language),
            LocalizedText.snapSectionSizes(language),
            LocalizedText.snapSectionDisplayAndRestore(language)
        ]
        for (index, label) in sectionHeaderLabels.enumerated() where index < sectionTitles.count {
            label.stringValue = sectionTitles[index]
        }

        for (action, row) in rows {
            let hasCustom = custom[action.id] != nil
            let chord = custom[action.id].flatMap(WindowSnapShortcut.decode)
                ?? WindowSnapShortcuts.defaultChord(for: action)
            let isRecording = recordingAction == action

            row.nameLabel.stringValue = LocalizedText.windowSnapActionName(action, language)
            if hasCustom, let defaultChord = WindowSnapShortcuts.defaultChord(for: action) {
                row.defaultLabel.stringValue = LocalizedText.defaultShortcut(language, shortcut: defaultChord.displayName)
            } else {
                row.defaultLabel.stringValue = ""
            }

            row.keycap.setText(
                isRecording ? LocalizedText.recordingPromptShort(language) : (chord?.displayName ?? "—"),
                highlighted: isRecording || hasCustom
            )

            row.recordButton.title = isRecording
                ? LocalizedText.cancelRecording(language)
                : LocalizedText.recordShortcut(language)
            row.recordButton.contentTintColor = isRecording ? .systemRed : .controlAccentColor
            row.clearButton.title = LocalizedText.clearShortcut(language)
            row.clearButton.isEnabled = hasCustom
            row.container.layer?.backgroundColor = isRecording
                ? NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
                : NSColor.clear.cgColor
        }
    }

    // MARK: - Recording

    @objc private func recordTapped(_ sender: NSButton) {
        guard let action = action(for: sender) else {
            return
        }

        if recordingAction == action {
            cancelRecording()
            return
        }

        cancelRecording()
        recordingAction = action
        refresh()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let action = self.recordingAction else {
                return event
            }

            if event.keyCode == Self.escapeKeyCode {
                self.cancelRecording()
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let relevant: NSEvent.ModifierFlags = [.control, .option, .command]

            // A modifier key alone updates the live preview and waits for the key.
            if Self.modifierKeyCodes.contains(event.keyCode) {
                self.showRecordingPreview(modifiers: modifiers, action: action)
                return event
            }

            guard !modifiers.intersection(relevant).isEmpty else {
                NSSound.beep()
                return event
            }

            var flags: CGEventFlags = []
            if modifiers.contains(.control) { flags.insert(.maskControl) }
            if modifiers.contains(.option) { flags.insert(.maskAlternate) }
            if modifiers.contains(.command) { flags.insert(.maskCommand) }
            if modifiers.contains(.shift) { flags.insert(.maskShift) }

            let shortcut = WindowSnapShortcut(keyCode: Int64(event.keyCode), flags: flags)
            var custom = self.settings.customSnapShortcuts
            custom[action.id] = shortcut.encoded
            self.settings.customSnapShortcuts = custom
            self.cancelRecording()
            return nil
        }
    }

    @objc private func clearTapped(_ sender: NSButton) {
        guard let action = action(for: sender) else {
            return
        }
        var custom = settings.customSnapShortcuts
        custom.removeValue(forKey: action.id)
        settings.customSnapShortcuts = custom
        refresh()
    }

    @objc private func resetAllTapped() {
        settings.customSnapShortcuts = [:]
        refresh()
    }

    private func showRecordingPreview(modifiers: NSEvent.ModifierFlags, action: WindowSnapAction) {
        var symbols = ""
        if modifiers.contains(.control) { symbols += "⌃" }
        if modifiers.contains(.option) { symbols += "⌥" }
        if modifiers.contains(.command) { symbols += "⌘" }
        if modifiers.contains(.shift) { symbols += "⇧" }
        rows[action]?.keycap.setText(symbols.isEmpty ? "…" : symbols + "…", highlighted: true)
    }

    private func cancelRecording() {
        recordingAction = nil
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        refresh()
    }

    private func action(for control: NSControl) -> WindowSnapAction? {
        guard let id = control.identifier?.rawValue else {
            return nil
        }
        return WindowSnapAction.action(withID: id)
    }

    func windowWillClose(_ notification: Notification) {
        cancelRecording()
    }
}

/// Rounded "keycap" label showing a shortcut chord.
final class KeycapView: NSView {
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6

        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setText(_ text: String, highlighted: Bool) {
        label.stringValue = text
        label.textColor = highlighted ? .controlAccentColor : .labelColor
        layer?.backgroundColor = (highlighted
            ? NSColor.controlAccentColor.withAlphaComponent(0.18)
            : NSColor.secondaryLabelColor.withAlphaComponent(0.14)).cgColor
    }
}
