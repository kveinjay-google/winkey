import AppKit
import ApplicationServices

/// Semi-transparent overlay showing where a dragged window will snap.
final class FootprintWindow: NSWindow {
    init() {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .modalPanel
        isReleasedWhenClosed = false
        ignoresMouseEvents = true

        let box = NSBox()
        box.boxType = .custom
        box.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.25)
        box.borderColor = NSColor.controlAccentColor
        box.borderWidth = 2
        box.cornerRadius = 8
        box.wantsLayer = true
        contentView = box
    }
}

/// Watches mouse drags and snaps windows to screen edges with a live preview,
/// mirroring Rectangle's drag-to-snap behavior.
final class WindowSnapDragManager {
    private let snapper: WindowSnapper
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var windowElement: AXUIElement?
    private var windowId: CGWindowID?
    private var initialRect: CGRect?
    private var windowMoving = false
    private var currentSnapArea: SnapArea?
    private var dragAttempts = 0
    private var footprint: FootprintWindow?

    init(snapper: WindowSnapper) {
        self.snapper = snapper
    }

    func update(enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func start() {
        stop()

        let mask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: WindowSnapDragManager.eventTapCallback,
            userInfo: userInfo
        ) else {
            return
        }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        tap = nil
        resetDragState()
        footprint?.orderOut(nil)
        footprint = nil
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<WindowSnapDragManager>.fromOpaque(userInfo).takeUnretainedValue()
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = manager.tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }
        DispatchQueue.main.async {
            manager.handle(nsEvent)
        }
        return Unmanaged.passUnretained(event)
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            handleMouseDown(event)
        case .leftMouseDragged:
            handleMouseDragged(event)
        case .leftMouseUp:
            handleMouseUp(event)
        default:
            break
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        let cursorAX = event.cgEvent?.location ?? ScreenGeometry.axPoint(from: NSEvent.mouseLocation)
        windowElement = snapper.windowElement(at: cursorAX)
        initialRect = windowElement.flatMap { snapper.frame(of: $0) }
        windowId = nil
        if let windowElement, let initialRect {
            windowId = snapper.windowIdentifier(for: windowElement, frame: initialRect)
        }
        windowMoving = false
        currentSnapArea = nil
        dragAttempts = 0
        footprint?.orderOut(nil)
    }

    private func handleMouseDragged(_ event: NSEvent) {
        if windowElement == nil, dragAttempts < 10 {
            let cursorAX = event.cgEvent?.location ?? ScreenGeometry.axPoint(from: NSEvent.mouseLocation)
            windowElement = snapper.windowElement(at: cursorAX)
            initialRect = windowElement.flatMap { snapper.frame(of: $0) }
            dragAttempts += 1
        }

        guard let windowElement, let currentRect = snapper.frame(of: windowElement) else {
            return
        }

        let cursorAppKit = NSEvent.mouseLocation

        if !windowMoving {
            guard let initialRect,
                  currentRect.origin != initialRect.origin,
                  currentRect.size == initialRect.size else {
                return
            }
            windowMoving = true
            if let windowId {
                snapper.unsnapForDrag(
                    element: windowElement,
                    windowId: windowId,
                    currentFrame: currentRect,
                    cursorAppKit: cursorAppKit
                )
            }
        }

        let priorAction = windowId.flatMap { snapper.lastAction(for: $0) }
        var foundSnap: SnapArea?
        for screen in NSScreen.screens {
            if let action = SnapAreaDetector.action(cursor: cursorAppKit, screenFrame: screen.frame, priorAction: priorAction) {
                foundSnap = SnapArea(action: action, screen: screen)
                break
            }
        }

        if let snap = foundSnap {
            NSLog("WinKey drag: snap area %@ on screen %@", String(describing: snap.action), NSStringFromRect(snap.screen.frame))
            if snap != currentSnapArea {
                currentSnapArea = snap
                if let target = WindowSnapLayout.targetFrame(
                    for: snap.action,
                    currentFrame: ScreenGeometry.appKitRect(from: currentRect),
                    visibleFrame: snap.screen.visibleFrame
                ) {
                    if footprint == nil {
                        footprint = FootprintWindow()
                    }
                    footprint?.setFrame(target, display: true)
                    footprint?.orderFront(nil)
                }
            }
        } else if currentSnapArea != nil {
            footprint?.orderOut(nil)
            currentSnapArea = nil
        }
    }

    private func handleMouseUp(_ event: NSEvent) {
        if let snap = currentSnapArea, let element = windowElement {
            footprint?.orderOut(nil)
            let action = snap.action
            let screen = snap.screen
            snapper.perform(action, element: element, screen: screen, useStateMachine: false)
            // The window server can still be settling the drag when the tap fires;
            // re-apply shortly after to make the size stick.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.snapper.perform(action, element: element, screen: screen, useStateMachine: false)
            }
        }
        resetDragState()
        footprint?.orderOut(nil)
    }

    private func resetDragState() {
        windowElement = nil
        windowId = nil
        initialRect = nil
        windowMoving = false
        currentSnapArea = nil
        dragAttempts = 0
    }
}
