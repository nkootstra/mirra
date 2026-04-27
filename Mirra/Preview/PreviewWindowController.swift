import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class PreviewWindowController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var hoverTracker: HoverTrackingView?
    private var closeButton: NSButton?
    private var mouseMonitor: Any?

    var sizePreset: PreviewSizePreset = .medium
    var placement: PreviewPlacement = .bottomTrailing
    var shape: PreviewShape = .rectangle
    var borderRadius: BorderRadius = .medium
    var hoverMode: HoverMode = .fade
    var hoverOpacity: HoverOpacity = .thirty
    var targetScreenNumber: Int?  // nil = main screen
    var onWindowPositionChanged: ((CGPoint) -> Void)?
    var onCloseRequested: (() -> Void)?
    var savedWindowPosition: CGPoint?  // set from preferences on launch

    var isVisible: Bool { panel?.isVisible ?? false }

    /// The effective window size, accounting for shape (circle forces square).
    private var effectiveSize: NSSize {
        let base = sizePreset.size
        if shape.isSquare {
            let side = min(base.width, base.height)
            return NSSize(width: side, height: side)
        }
        return base
    }

    /// The screen to place the preview on, or nil if no screens available.
    private var targetScreen: NSScreen? {
        if let num = targetScreenNumber {
            return NSScreen.screens.first { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int == num }
                ?? NSScreen.main ?? NSScreen.screens.first
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    func show(session: AVCaptureSession, isMirrored: Bool) {
        if let panel {
            // Always recreate content to ensure fresh layout
            let view = AnyView(
                CameraPreviewView(session: session, isMirrored: isMirrored)
            )
            let hosting = NSHostingView(rootView: view)
            panel.contentView = hosting
            applyCornerRadius(to: hosting)
            self.hostingView = hosting
            panel.orderFront(nil)
            installHoverTracking()
            return
        }

        let size = effectiveSize
        guard let screenFrame = targetScreen?.visibleFrame else { return }
        let origin: NSPoint
        if let saved = savedWindowPosition {
            origin = saved
        } else {
            origin = placement.origin(for: size, in: screenFrame)
        }
        let frame = NSRect(origin: origin, size: size)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        self.panel = panel

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        updateContent(session: session, isMirrored: isMirrored)
        panel.orderFront(nil)
        installHoverTracking()
    }

    func hide() {
        removeMouseMonitor()
        panel?.ignoresMouseEvents = false
        panel?.alphaValue = 1.0
        panel?.orderOut(nil)
    }

    func close() {
        removeMouseMonitor()
        panel?.close()
        panel = nil
        hostingView = nil
    }

    func updateMirror(_ isMirrored: Bool, session: AVCaptureSession) {
        updateContent(session: session, isMirrored: isMirrored)
    }

    func updateSize(_ preset: PreviewSizePreset) {
        sizePreset = preset
        guard let panel else { return }
        let newSize = effectiveSize
        guard let screenFrame = targetScreen?.visibleFrame else { return }
        let origin = placement.origin(for: newSize, in: screenFrame)
        let frame = NSRect(origin: origin, size: newSize)
        panel.setFrame(frame, display: true, animate: true)
        if let hosting = panel.contentView { applyCornerRadius(to: hosting) }
    }

    func updatePlacement(_ newPlacement: PreviewPlacement) {
        placement = newPlacement
        savedWindowPosition = nil
        guard let panel else { return }
        guard let screenFrame = targetScreen?.visibleFrame else { return }
        let origin = newPlacement.origin(for: panel.frame.size, in: screenFrame)
        var frame = panel.frame
        frame.origin = origin
        panel.setFrame(frame, display: true, animate: true)
    }

    func updateScreen(_ screenNumber: Int?) {
        targetScreenNumber = screenNumber
        guard let panel, panel.isVisible else { return }
        guard let screenFrame = targetScreen?.visibleFrame else { return }
        let origin = placement.origin(for: panel.frame.size, in: screenFrame)
        var frame = panel.frame
        frame.origin = origin
        panel.setFrame(frame, display: true, animate: true)
    }

    // MARK: - Private

    private func updateContent(session: AVCaptureSession, isMirrored: Bool) {
        guard let panel else { return }
        let view = AnyView(
            CameraPreviewView(session: session, isMirrored: isMirrored)
        )
        if let hostingView {
            hostingView.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            panel.contentView = hosting
            applyCornerRadius(to: hosting)
            self.hostingView = hosting
        }
    }

    private func applyCornerRadius(to view: NSView) {
        view.wantsLayer = true
        let radius: CGFloat
        if shape == .circle {
            radius = min(view.bounds.width, view.bounds.height) / 2
        } else {
            radius = borderRadius.value
        }
        view.layer?.cornerRadius = radius
        view.layer?.masksToBounds = true
    }

    func updateBorderRadius(_ newRadius: BorderRadius) {
        borderRadius = newRadius
        guard let panel, let hosting = panel.contentView else { return }
        applyCornerRadius(to: hosting)
    }

    func updateClickThrough(_ mode: ClickThroughMode) {
        guard let panel else { return }
        let isClickThrough = mode == .clickThrough
        panel.ignoresMouseEvents = isClickThrough
        panel.isMovableByWindowBackground = !isClickThrough
        if isClickThrough {
            removeMouseMonitor()
            hoverTracker?.removeFromSuperview()
            hoverTracker = nil
        } else {
            installHoverTracking()
        }
    }

    func updateShape(_ newShape: PreviewShape) {
        shape = newShape
        guard let panel else { return }
        let newSize = effectiveSize
        guard let screenFrame = targetScreen?.visibleFrame else { return }
        let origin = placement.origin(for: newSize, in: screenFrame)
        let frame = NSRect(origin: origin, size: newSize)
        panel.setFrame(frame, display: true, animate: true)
        if let hosting = panel.contentView { applyCornerRadius(to: hosting) }
    }

    @objc private func windowDidMove(_ notification: Notification) {
        constrainToScreen()
        if let panel {
            onWindowPositionChanged?(panel.frame.origin)
        }
    }

    private func constrainToScreen() {
        guard let panel else { return }
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let padding: CGFloat = 20
        var frame = panel.frame

        frame.origin.x = max(screenFrame.minX + padding, min(frame.origin.x, screenFrame.maxX - frame.width - padding))
        frame.origin.y = max(screenFrame.minY + padding, min(frame.origin.y, screenFrame.maxY - frame.height - padding))

        if frame != panel.frame {
            panel.setFrameOrigin(frame.origin)
        }
    }

    private func installHoverTracking() {
        guard let panel, let contentView = panel.contentView else { return }
        hoverTracker?.removeFromSuperview()
        removeCloseButton()
        removeMouseMonitor()
        let tracker = HoverTrackingView(frame: contentView.bounds)
        tracker.autoresizingMask = [.width, .height]
        tracker.onMouseEntered = { [weak self] in
            guard let self else { return }
            switch self.hoverMode {
            case .none: self.showCloseButton()
            case .fade:
                self.animateOpacity(to: self.hoverOpacity.value)
                self.showCloseButton()
            case .hide: self.enterHideMode()
            }
        }
        tracker.onMouseExited = { [weak self] in
            guard let self else { return }
            switch self.hoverMode {
            case .none: self.hideCloseButton()
            case .fade:
                self.animateOpacity(to: 1.0)
                self.hideCloseButton()
            case .hide: break  // handled by mouse monitor
            }
        }
        contentView.addSubview(tracker)
        hoverTracker = tracker
        installCloseButton()
    }

    private func enterHideMode() {
        guard let panel else { return }
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true

        // Poll mouse position to detect when cursor leaves the window frame
        removeMouseMonitor()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            let mouseLocation = NSEvent.mouseLocation
            if !panel.frame.contains(mouseLocation) {
                self.exitHideMode()
            }
        }
    }

    private func exitHideMode() {
        removeMouseMonitor()
        guard let panel else { return }
        panel.ignoresMouseEvents = false
        animateOpacity(to: 1.0)
    }

    private func removeMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func animateOpacity(to alpha: CGFloat) {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = alpha
        }
    }

    // MARK: - Close button

    private func installCloseButton() {
        guard let panel, let contentView = panel.contentView else { return }
        removeCloseButton()

        let button = NSButton(frame: .zero)
        button.bezelStyle = .inline
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close preview")
        button.imageScaling = .scaleProportionallyUpOrDown
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.5
        button.layer?.shadowOffset = .zero
        button.layer?.shadowRadius = 2
        button.alphaValue = 0
        button.target = self
        button.action = #selector(closeButtonClicked)

        let buttonSize: CGFloat = 20
        let inset: CGFloat = 6
        button.frame = NSRect(
            x: contentView.bounds.maxX - buttonSize - inset,
            y: contentView.bounds.maxY - buttonSize - inset,
            width: buttonSize,
            height: buttonSize
        )
        button.autoresizingMask = [.minXMargin, .minYMargin]

        contentView.addSubview(button, positioned: .above, relativeTo: nil)
        closeButton = button
    }

    private func removeCloseButton() {
        closeButton?.removeFromSuperview()
        closeButton = nil
    }

    private func showCloseButton() {
        guard let closeButton else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            closeButton.animator().alphaValue = 0.7
        }
    }

    private func hideCloseButton() {
        guard let closeButton else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            closeButton.animator().alphaValue = 0
        }
    }

    @objc private func closeButtonClicked() {
        onCloseRequested?()
    }
}

// MARK: - Hover Tracking View

private class HoverTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
