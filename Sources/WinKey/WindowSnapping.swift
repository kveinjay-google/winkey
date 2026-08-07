import AppKit

enum WindowSnapAction: Equatable, CaseIterable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case maximize
    case almostMaximize
    case maximizeHeight
    case firstThird
    case centerThird
    case lastThird
    case firstTwoThirds
    case lastTwoThirds
    case previousDisplay
    case nextDisplay
    case center
    case restore

    var isDirectional: Bool {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf:
            return true
        default:
            return false
        }
    }

    var id: String {
        switch self {
        case .leftHalf: return "leftHalf"
        case .rightHalf: return "rightHalf"
        case .topHalf: return "topHalf"
        case .bottomHalf: return "bottomHalf"
        case .topLeft: return "topLeft"
        case .topRight: return "topRight"
        case .bottomLeft: return "bottomLeft"
        case .bottomRight: return "bottomRight"
        case .maximize: return "maximize"
        case .almostMaximize: return "almostMaximize"
        case .maximizeHeight: return "maximizeHeight"
        case .firstThird: return "firstThird"
        case .centerThird: return "centerThird"
        case .lastThird: return "lastThird"
        case .firstTwoThirds: return "firstTwoThirds"
        case .lastTwoThirds: return "lastTwoThirds"
        case .previousDisplay: return "previousDisplay"
        case .nextDisplay: return "nextDisplay"
        case .center: return "center"
        case .restore: return "restore"
        }
    }

    static func action(withID id: String) -> WindowSnapAction? {
        allCases.first { $0.id == id }
    }
}

/// A key chord with an explicit modifier set, encodable to and from a stable
/// string for UserDefaults persistence.
struct WindowSnapShortcut: Equatable {
    let keyCode: Int64
    let flags: CGEventFlags

    var encoded: String {
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("control") }
        if flags.contains(.maskAlternate) { parts.append("option") }
        if flags.contains(.maskCommand) { parts.append("command") }
        if flags.contains(.maskShift) { parts.append("shift") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: "+")
    }

    var displayName: String {
        var result = ""
        if flags.contains(.maskControl) { result += "⌃" }
        if flags.contains(.maskAlternate) { result += "⌥" }
        if flags.contains(.maskCommand) { result += "⌘" }
        if flags.contains(.maskShift) { result += "⇧" }
        result += Self.keyGlyph(for: keyCode)
        return result
    }

    static func decode(_ string: String) -> WindowSnapShortcut? {
        let parts = string.split(separator: "+").map(String.init)
        guard !parts.isEmpty else {
            return nil
        }

        var flags: CGEventFlags = []
        var seenModifiers = Set<String>()
        var keyName: String?
        for part in parts {
            switch part {
            case "control", "option", "command", "shift":
                guard seenModifiers.insert(part).inserted else {
                    return nil
                }
                if part == "control" { flags.insert(.maskControl) }
                if part == "option" { flags.insert(.maskAlternate) }
                if part == "command" { flags.insert(.maskCommand) }
                if part == "shift" { flags.insert(.maskShift) }
            default:
                guard keyName == nil else {
                    return nil
                }
                keyName = part
            }
        }

        guard let keyName, let keyCode = keyCode(for: keyName) else {
            return nil
        }
        return WindowSnapShortcut(keyCode: keyCode, flags: flags)
    }

    private static func keyName(for keyCode: Int64) -> String {
        switch keyCode {
        case KeyCode.left: return "left"
        case KeyCode.right: return "right"
        case KeyCode.up: return "up"
        case KeyCode.down: return "down"
        case KeyCode.c: return "c"
        case KeyCode.d: return "d"
        case KeyCode.e: return "e"
        case KeyCode.f: return "f"
        case KeyCode.g: return "g"
        case KeyCode.i: return "i"
        case KeyCode.j: return "j"
        case KeyCode.k: return "k"
        case KeyCode.t: return "t"
        case KeyCode.u: return "u"
        case KeyCode.deleteForward: return "delete"
        case KeyCode.returnKey: return "return"
        default: return "key\(keyCode)"
        }
    }

    private static func keyCode(for name: String) -> Int64? {
        switch name {
        case "left": return KeyCode.left
        case "right": return KeyCode.right
        case "up": return KeyCode.up
        case "down": return KeyCode.down
        case "c": return KeyCode.c
        case "d": return KeyCode.d
        case "e": return KeyCode.e
        case "f": return KeyCode.f
        case "g": return KeyCode.g
        case "i": return KeyCode.i
        case "j": return KeyCode.j
        case "k": return KeyCode.k
        case "t": return KeyCode.t
        case "u": return KeyCode.u
        case "delete": return KeyCode.deleteForward
        case "return": return KeyCode.returnKey
        default:
            guard name.hasPrefix("key") else {
                return nil
            }
            return Int64(name.dropFirst(3))
        }
    }

    private static func keyGlyph(for keyCode: Int64) -> String {
        switch keyCode {
        case KeyCode.left: return "←"
        case KeyCode.right: return "→"
        case KeyCode.up: return "↑"
        case KeyCode.down: return "↓"
        case KeyCode.deleteForward: return "⌫"
        case KeyCode.returnKey: return "↩"
        default: return keyName(for: keyCode).uppercased()
        }
    }
}

/// Resolves a key press to a snap action, preferring user-recorded custom
/// chords and falling back to the built-in defaults.
enum SnapShortcutResolver {
    static func action(keyCode: Int64, flags: CGEventFlags, customShortcuts: [String: String]) -> WindowSnapAction? {
        let relevant: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]
        let pressed = WindowSnapShortcut(keyCode: keyCode, flags: flags.intersection(relevant))

        for (actionID, encoded) in customShortcuts {
            guard let shortcut = WindowSnapShortcut.decode(encoded),
                  shortcut == pressed,
                  let action = WindowSnapAction.action(withID: actionID) else {
                continue
            }
            return action
        }

        return WindowSnapShortcuts.action(keyCode: keyCode, flags: flags)
    }
}

/// Pure geometry for turning a snap action into a target frame.
enum WindowSnapLayout {
    static func targetFrame(
        for action: WindowSnapAction,
        currentFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGRect? {
        let halfWidth = visibleFrame.width / 2
        let halfHeight = visibleFrame.height / 2

        switch action {
        case .leftHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth, height: visibleFrame.height)
        case .rightHalf:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.minY, width: halfWidth, height: visibleFrame.height)
        case .topHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width, height: halfHeight)
        case .bottomHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.midY, width: visibleFrame.width, height: halfHeight)
        case .topLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        case .topRight:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        case .bottomLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.midY, width: halfWidth, height: halfHeight)
        case .bottomRight:
            return CGRect(x: visibleFrame.midX, y: visibleFrame.midY, width: halfWidth, height: halfHeight)
        case .maximize:
            return visibleFrame
        case .almostMaximize:
            return visibleFrame.insetBy(dx: 10, dy: 10)
        case .maximizeHeight:
            return CGRect(x: currentFrame.minX, y: visibleFrame.minY, width: currentFrame.width, height: visibleFrame.height)
        case .firstThird:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width / 3, height: visibleFrame.height)
        case .centerThird:
            return CGRect(x: visibleFrame.minX + visibleFrame.width / 3, y: visibleFrame.minY, width: visibleFrame.width / 3, height: visibleFrame.height)
        case .lastThird:
            return CGRect(x: visibleFrame.minX + visibleFrame.width * 2 / 3, y: visibleFrame.minY, width: visibleFrame.width / 3, height: visibleFrame.height)
        case .firstTwoThirds:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: visibleFrame.width * 2 / 3, height: visibleFrame.height)
        case .lastTwoThirds:
            return CGRect(x: visibleFrame.minX + visibleFrame.width / 3, y: visibleFrame.minY, width: visibleFrame.width * 2 / 3, height: visibleFrame.height)
        case .previousDisplay, .nextDisplay:
            return nil
        case .center:
            let x = visibleFrame.midX - currentFrame.width / 2
            let y = visibleFrame.midY - currentFrame.height / 2
            return CGRect(x: x, y: y, width: currentFrame.width, height: currentFrame.height)
        case .restore:
            return nil
        }
    }
}

enum Directional: Equatable {
    case tl, t, tr, l, r, bl, b, br
}

struct SnapArea: Equatable {
    let action: WindowSnapAction
    let screen: NSScreen

    static func == (lhs: SnapArea, rhs: SnapArea) -> Bool {
        lhs.action == rhs.action
            && lhs.screen.frame == rhs.screen.frame
    }
}

/// Determines which snap area a cursor location falls into, in AppKit
/// coordinates (origin at bottom-left). Mirrors Rectangle's landscape model:
/// edges snap halves, top maximizes, corners make quarters, and the bottom
/// edge offers thirds with a compound first/last two-thirds behavior.
enum SnapAreaDetector {
    static let margin: CGFloat = 4
    static let cornerSize: CGFloat = 8

    static func directional(cursor: CGPoint, screenFrame: CGRect) -> Directional? {
        guard cursor.x >= screenFrame.minX,
              cursor.x <= screenFrame.maxX,
              cursor.y >= screenFrame.minY,
              cursor.y <= screenFrame.maxY else {
            return nil
        }

        let left = cursor.x < screenFrame.minX + margin + cornerSize
        let right = cursor.x > screenFrame.maxX - margin - cornerSize
        let top = cursor.y > screenFrame.maxY - margin - cornerSize
        let bottom = cursor.y < screenFrame.minY + margin + cornerSize

        if left && top { return .tl }
        if right && top { return .tr }
        if left && bottom { return .bl }
        if right && bottom { return .br }
        if cursor.x < screenFrame.minX + margin { return .l }
        if cursor.x > screenFrame.maxX - margin { return .r }
        if cursor.y > screenFrame.maxY - margin { return .t }
        if cursor.y < screenFrame.minY + margin { return .b }
        return nil
    }

    static func action(cursor: CGPoint, screenFrame: CGRect, priorAction: WindowSnapAction?) -> WindowSnapAction? {
        guard let directional = directional(cursor: cursor, screenFrame: screenFrame) else {
            return nil
        }

        switch directional {
        case .tl:
            return .topLeft
        case .t:
            return .maximize
        case .tr:
            return .topRight
        case .l:
            return .leftHalf
        case .r:
            return .rightHalf
        case .bl:
            return .bottomLeft
        case .br:
            return .bottomRight
        case .b:
            let thirdWidth = screenFrame.width / 3
            if cursor.x <= screenFrame.minX + thirdWidth {
                return .firstThird
            }
            if cursor.x >= screenFrame.maxX - thirdWidth {
                return .lastThird
            }
            switch priorAction {
            case .firstThird, .firstTwoThirds:
                return .firstTwoThirds
            case .lastThird, .lastTwoThirds:
                return .lastTwoThirds
            default:
                return .centerThird
            }
        }
    }
}

/// Windows-style directional snapping: consecutive arrow presses move a snapped
/// window between halves, quarters, maximize and restore.
enum WindowSnapStateMachine {
    static func nextAction(current: WindowSnapAction?, direction: WindowSnapAction) -> WindowSnapAction {
        guard let current else {
            return direction == .topHalf ? .maximize : direction
        }

        if current == .center {
            return direction == .topHalf ? .maximize : direction
        }

        switch (current, direction) {
        case (.leftHalf, .rightHalf), (.rightHalf, .leftHalf),
             (.topLeft, .leftHalf), (.bottomLeft, .leftHalf),
             (.topRight, .rightHalf), (.bottomRight, .rightHalf),
             (.maximize, .leftHalf), (.maximize, .rightHalf):
            return direction
        case (.topLeft, .rightHalf):
            return .topRight
        case (.topRight, .leftHalf):
            return .topLeft
        case (.bottomLeft, .rightHalf):
            return .bottomRight
        case (.bottomRight, .leftHalf):
            return .bottomLeft
        case (.leftHalf, .topHalf):
            return .topLeft
        case (.leftHalf, .bottomHalf):
            return .bottomLeft
        case (.rightHalf, .topHalf):
            return .topRight
        case (.rightHalf, .bottomHalf):
            return .bottomRight
        case (.topLeft, .bottomHalf):
            return .bottomLeft
        case (.bottomLeft, .topHalf):
            return .topLeft
        case (.topRight, .bottomHalf):
            return .bottomRight
        case (.bottomRight, .topHalf):
            return .topRight
        case (.topHalf, .leftHalf):
            return .topLeft
        case (.topHalf, .rightHalf):
            return .topRight
        case (.bottomHalf, .leftHalf):
            return .bottomLeft
        case (.bottomHalf, .rightHalf):
            return .bottomRight
        case (.bottomHalf, .topHalf):
            return .topHalf
        case (.topHalf, .bottomHalf):
            return .bottomHalf
        case (.topLeft, .topHalf), (.topRight, .topHalf), (.topHalf, .topHalf), (.maximize, .topHalf):
            return .maximize
        case (.bottomLeft, .bottomHalf), (.bottomRight, .bottomHalf), (.bottomHalf, .bottomHalf), (.maximize, .bottomHalf):
            return .restore
        default:
            return direction
        }
    }
}

/// Maps the Ctrl + Option (with optional Command-free) key chords to snap actions.
enum WindowSnapShortcuts {
    static func action(keyCode: Int64, flags: CGEventFlags) -> WindowSnapAction? {
        let relevantModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]

        let matched = flags.intersection(relevantModifiers)
        guard matched.contains(.maskControl), matched.contains(.maskAlternate) else {
            return nil
        }
        let hasCommand = matched.contains(.maskCommand)
        let hasShift = matched.contains(.maskShift)

        switch keyCode {
        case KeyCode.left:
            if hasShift { return nil }
            return hasCommand ? .previousDisplay : .leftHalf
        case KeyCode.right:
            if hasShift { return nil }
            return hasCommand ? .nextDisplay : .rightHalf
        case KeyCode.up:
            if hasCommand { return nil }
            return hasShift ? .maximizeHeight : .topHalf
        case KeyCode.down:
            return hasCommand || hasShift ? nil : .bottomHalf
        case KeyCode.c:
            return hasCommand || hasShift ? nil : .center
        case KeyCode.deleteForward:
            return hasCommand || hasShift ? nil : .restore
        case KeyCode.d:
            return hasCommand || hasShift ? nil : .firstThird
        case KeyCode.e:
            return hasCommand || hasShift ? nil : .firstTwoThirds
        case KeyCode.f:
            return hasCommand || hasShift ? nil : .centerThird
        case KeyCode.t:
            return hasCommand || hasShift ? nil : .lastTwoThirds
        case KeyCode.g:
            return hasCommand || hasShift ? nil : .lastThird
        case KeyCode.returnKey:
            return hasCommand || hasShift ? nil : .maximize
        case KeyCode.u:
            return hasCommand || hasShift ? nil : .topLeft
        case KeyCode.i:
            return hasCommand || hasShift ? nil : .topRight
        case KeyCode.j:
            return hasCommand || hasShift ? nil : .bottomLeft
        case KeyCode.k:
            return hasCommand || hasShift ? nil : .bottomRight
        default:
            return nil
        }
    }

    static func defaultChord(for action: WindowSnapAction) -> WindowSnapShortcut? {
        let ctrlOption: CGEventFlags = [.maskControl, .maskAlternate]
        switch action {
        case .leftHalf:
            return WindowSnapShortcut(keyCode: KeyCode.left, flags: ctrlOption)
        case .rightHalf:
            return WindowSnapShortcut(keyCode: KeyCode.right, flags: ctrlOption)
        case .topHalf:
            return WindowSnapShortcut(keyCode: KeyCode.up, flags: ctrlOption)
        case .bottomHalf:
            return WindowSnapShortcut(keyCode: KeyCode.down, flags: ctrlOption)
        case .topLeft:
            return WindowSnapShortcut(keyCode: KeyCode.u, flags: ctrlOption)
        case .topRight:
            return WindowSnapShortcut(keyCode: KeyCode.i, flags: ctrlOption)
        case .bottomLeft:
            return WindowSnapShortcut(keyCode: KeyCode.j, flags: ctrlOption)
        case .bottomRight:
            return WindowSnapShortcut(keyCode: KeyCode.k, flags: ctrlOption)
        case .maximize:
            return WindowSnapShortcut(keyCode: KeyCode.returnKey, flags: ctrlOption)
        case .maximizeHeight:
            return WindowSnapShortcut(keyCode: KeyCode.up, flags: ctrlOption.union(.maskShift))
        case .firstThird:
            return WindowSnapShortcut(keyCode: KeyCode.d, flags: ctrlOption)
        case .firstTwoThirds:
            return WindowSnapShortcut(keyCode: KeyCode.e, flags: ctrlOption)
        case .centerThird:
            return WindowSnapShortcut(keyCode: KeyCode.f, flags: ctrlOption)
        case .lastTwoThirds:
            return WindowSnapShortcut(keyCode: KeyCode.t, flags: ctrlOption)
        case .lastThird:
            return WindowSnapShortcut(keyCode: KeyCode.g, flags: ctrlOption)
        case .previousDisplay:
            return WindowSnapShortcut(keyCode: KeyCode.left, flags: ctrlOption.union(.maskCommand))
        case .nextDisplay:
            return WindowSnapShortcut(keyCode: KeyCode.right, flags: ctrlOption.union(.maskCommand))
        case .center:
            return WindowSnapShortcut(keyCode: KeyCode.c, flags: ctrlOption)
        case .restore:
            return WindowSnapShortcut(keyCode: KeyCode.deleteForward, flags: ctrlOption)
        case .almostMaximize:
            return nil
        }
    }
}
