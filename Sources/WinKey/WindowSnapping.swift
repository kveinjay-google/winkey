import AppKit

enum WindowSnapAction: Equatable {
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
        default:
            return nil
        }
    }
}
