import AppKit

/// Compact settings panel for recording custom window-snap shortcuts.
final class WindowSnapShortcutRecorder: NSObject, NSWindowDelegate {
    private struct Row {
        let nameLabel: NSTextField
        let shortcutLabel: NSTextField
        let recordButton: NSButton
        let clearButton: NSButton
    }

    private let settings: SettingsStore
    private var panel: NSPanel?
    private var rows: [WindowSnapAction: Row] = [:]
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

    // MARK: - UI

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.delegate = self

        let scrollView = NSScrollView(frame: panel.contentView!.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let rowHeight: CGFloat = 38
        let actions = WindowSnapAction.allCases
        let document = NSView(frame: NSRect(x: 0, y: 0, width: panel.contentView!.bounds.width, height: CGFloat(actions.count) * rowHeight + 12))

        var y: CGFloat = 6
        for action in actions {
            let nameLabel = NSTextField(labelWithString: "")
            nameLabel.frame = NSRect(x: 12, y: y + 10, width: 190, height: 18)
            nameLabel.lineBreakMode = .byTruncatingTail

            let shortcutLabel = NSTextField(labelWithString: "")
            shortcutLabel.frame = NSRect(x: 208, y: y + 10, width: 100, height: 18)
            shortcutLabel.textColor = .secondaryLabelColor

            let recordButton = NSButton(title: "", target: self, action: #selector(recordTapped(_:)))
            recordButton.frame = NSRect(x: 314, y: y + 5, width: 82, height: 28)
            recordButton.bezelStyle = .rounded
            recordButton.identifier = NSUserInterfaceItemIdentifier(action.id)

            let clearButton = NSButton(title: "", target: self, action: #selector(clearTapped(_:)))
            clearButton.frame = NSRect(x: 402, y: y + 5, width: 66, height: 28)
            clearButton.bezelStyle = .rounded
            clearButton.identifier = NSUserInterfaceItemIdentifier(action.id)

            document.addSubview(nameLabel)
            document.addSubview(shortcutLabel)
            document.addSubview(recordButton)
            document.addSubview(clearButton)
            rows[action] = Row(
                nameLabel: nameLabel,
                shortcutLabel: shortcutLabel,
                recordButton: recordButton,
                clearButton: clearButton
            )
            y += rowHeight
        }

        scrollView.documentView = document
        panel.contentView = scrollView
        self.panel = panel
    }

    private func refresh() {
        panel?.title = LocalizedText.customShortcutSettings(settings.language)
        let custom = settings.customSnapShortcuts

        for (action, row) in rows {
            row.nameLabel.stringValue = LocalizedText.windowSnapActionName(action, settings.language)
            let chord = custom[action.id].flatMap(WindowSnapShortcut.decode)
                ?? WindowSnapShortcuts.defaultChord(for: action)
            row.shortcutLabel.stringValue = chord?.displayName ?? "—"

            if recordingAction == action {
                row.recordButton.title = LocalizedText.recordingPrompt(settings.language)
            } else {
                row.recordButton.title = LocalizedText.recordShortcut(settings.language)
            }
            row.clearButton.title = LocalizedText.clearShortcut(settings.language)
            row.clearButton.isEnabled = custom[action.id] != nil
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
            guard !modifiers.intersection(relevant).isEmpty,
                  !Self.modifierKeyCodes.contains(event.keyCode) else {
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
