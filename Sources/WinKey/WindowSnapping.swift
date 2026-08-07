import CoreGraphics

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
    case center
    case restore
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
        case .center:
            let x = visibleFrame.midX - currentFrame.width / 2
            let y = visibleFrame.midY - currentFrame.height / 2
            return CGRect(x: x, y: y, width: currentFrame.width, height: currentFrame.height)
        case .restore:
            return nil
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
        let ctrlOption: CGEventFlags = [.maskControl, .maskAlternate]

        guard flags.intersection(relevantModifiers) == ctrlOption else {
            return nil
        }

        switch keyCode {
        case KeyCode.left:
            return .leftHalf
        case KeyCode.right:
            return .rightHalf
        case KeyCode.up:
            return .topHalf
        case KeyCode.down:
            return .bottomHalf
        case KeyCode.c:
            return .center
        case KeyCode.deleteForward:
            return .restore
        default:
            return nil
        }
    }
}
