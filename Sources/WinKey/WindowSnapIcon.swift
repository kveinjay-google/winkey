import AppKit

/// Draws small template icons that visualize a window layout for each snap
/// action (window outline + highlighted region). Template images automatically
/// adapt to light/dark menu and panel appearances.
enum WindowSnapIcon {
    static let size = NSSize(width: 16, height: 16)

    static func image(for action: WindowSnapAction) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            switch action {
            case .previousDisplay:
                drawTwoScreens(in: rect, highlight: .left)
            case .nextDisplay:
                drawTwoScreens(in: rect, highlight: .right)
            case .restore:
                drawOutline(in: rect)
                drawRestoreGlyph(in: rect)
            default:
                drawOutline(in: rect)
                if let fill = fillRect(for: action, in: rect) {
                    let path = NSBezierPath(roundedRect: fill, xRadius: 1.5, yRadius: 1.5)
                    NSColor.labelColor.setFill()
                    path.fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Normalized fill region for the action, in a bottom-left origin space.
    static func fillRect(for action: WindowSnapAction, in rect: CGRect) -> CGRect? {
        let region: CGRect
        switch action {
        case .leftHalf:
            region = CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf:
            region = CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf:
            region = CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .bottomHalf:
            region = CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .topLeft:
            region = CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .topRight:
            region = CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .bottomLeft:
            region = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .bottomRight:
            region = CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .firstThird:
            region = CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1)
        case .centerThird:
            region = CGRect(x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        case .lastThird:
            region = CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
        case .firstTwoThirds:
            region = CGRect(x: 0, y: 0, width: 2.0 / 3.0, height: 1)
        case .lastTwoThirds:
            region = CGRect(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1)
        case .maximize:
            region = CGRect(x: 0.06, y: 0.06, width: 0.88, height: 0.88)
        case .almostMaximize:
            region = CGRect(x: 0.13, y: 0.13, width: 0.74, height: 0.74)
        case .maximizeHeight:
            region = CGRect(x: 0.16, y: 0, width: 0.68, height: 1)
        case .center:
            region = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
        default:
            return nil
        }
        return CGRect(
            x: rect.minX + region.minX * rect.width,
            y: rect.minY + region.minY * rect.height,
            width: region.width * rect.width,
            height: region.height * rect.height
        )
    }

    private static func drawOutline(in rect: CGRect) {
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1.25, dy: 1.25), xRadius: 2.5, yRadius: 2.5)
        path.lineWidth = 1.25
        NSColor.labelColor.setStroke()
        path.stroke()
    }

    private static func drawTwoScreens(in rect: CGRect, highlight: ScreenSide) {
        let left = CGRect(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.08, width: rect.width * 0.46, height: rect.height * 0.84)
        let right = CGRect(x: rect.minX + rect.width * 0.52, y: rect.minY + rect.height * 0.08, width: rect.width * 0.46, height: rect.height * 0.84)
        for frame in [left, right] {
            let path = NSBezierPath(roundedRect: frame, xRadius: 2, yRadius: 2)
            path.lineWidth = 1.25
            NSColor.labelColor.setStroke()
            path.stroke()
        }
        let target = highlight == .left ? left : right
        let fill = NSBezierPath(roundedRect: target.insetBy(dx: 1.5, dy: 1.5), xRadius: 1.5, yRadius: 1.5)
        NSColor.labelColor.setFill()
        fill.fill()
    }

    private static func drawRestoreGlyph(in rect: CGRect) {
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 3.4, dy: 3.4), xRadius: 1.5, yRadius: 1.5)
        path.lineWidth = 1.25
        path.setLineDash([2.0, 1.5], count: 2, phase: 0)
        NSColor.labelColor.setStroke()
        path.stroke()
    }

    private enum ScreenSide {
        case left, right
    }
}
