import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class PreviewWindowController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var hoverTracker: HoverTrackingView?

    private static let hoverOpacity: CGFloat = 0.3
    private static let normalOpacity: CGFloat = 1.0

    var sizePreset: PreviewSizePreset = .medium
    var placement: PreviewPlacement = .bottomTrailing
    var shape: PreviewShape = .rectangle
    var targetScreenNumber: Int?  // nil = main screen

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

    /// The screen to place the preview on.
    private var targetScreen: NSScreen {
        if let num = targetScreenNumber {
            return NSScreen.screens.first { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int == num }
                ?? NSScreen.main ?? NSScreen.screens[0]
        }
        return NSScreen.main ?? NSScreen.screens[0]
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
        let screenFrame = targetScreen.visibleFrame
        let origin = placement.origin(for: size, in: screenFrame)
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
        panel?.alphaValue = Self.normalOpacity
        panel?.orderOut(nil)
    }

    func close() {
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
        let screenFrame = targetScreen.visibleFrame
        let origin = placement.origin(for: newSize, in: screenFrame)
        let frame = NSRect(origin: origin, size: newSize)
        panel.setFrame(frame, display: true, animate: true)
        if let hosting = panel.contentView { applyCornerRadius(to: hosting) }
    }

    func updatePlacement(_ newPlacement: PreviewPlacement) {
        placement = newPlacement
        guard let panel else { return }
        let screenFrame = targetScreen.visibleFrame
        let origin = newPlacement.origin(for: panel.frame.size, in: screenFrame)
        var frame = panel.frame
        frame.origin = origin
        panel.setFrame(frame, display: true, animate: true)
    }

    func updateScreen(_ screenNumber: Int?) {
        targetScreenNumber = screenNumber
        guard let panel, panel.isVisible else { return }
        let screenFrame = targetScreen.visibleFrame
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
        let maxRadius = min(view.bounds.width, view.bounds.height) / 2
        let radius: CGFloat = switch shape {
        case .circle: maxRadius
        case .square: 10
        case .rectangle: 10
        }
        view.layer?.cornerRadius = radius
        view.layer?.masksToBounds = true
    }

    func updateShape(_ newShape: PreviewShape) {
        shape = newShape
        guard let panel else { return }
        let newSize = effectiveSize
        let screenFrame = targetScreen.visibleFrame
        let origin = placement.origin(for: newSize, in: screenFrame)
        let frame = NSRect(origin: origin, size: newSize)
        panel.setFrame(frame, display: true, animate: true)
        if let hosting = panel.contentView { applyCornerRadius(to: hosting) }
    }

    @objc private func windowDidMove(_ notification: Notification) {
        constrainToScreen()
    }

    private func constrainToScreen() {
        guard let panel else { return }
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        var frame = panel.frame

        frame.origin.x = max(screenFrame.minX, min(frame.origin.x, screenFrame.maxX - frame.width))
        frame.origin.y = max(screenFrame.minY, min(frame.origin.y, screenFrame.maxY - frame.height))

        if frame != panel.frame {
            panel.setFrameOrigin(frame.origin)
        }
    }

    private func installHoverTracking() {
        guard let panel, let contentView = panel.contentView else { return }
        hoverTracker?.removeFromSuperview()
        let tracker = HoverTrackingView(frame: contentView.bounds)
        tracker.autoresizingMask = [.width, .height]
        tracker.onMouseEntered = { [weak self] in
            self?.animateOpacity(to: Self.hoverOpacity)
        }
        tracker.onMouseExited = { [weak self] in
            self?.animateOpacity(to: Self.normalOpacity)
        }
        contentView.addSubview(tracker)
        hoverTracker = tracker
    }

    private func animateOpacity(to alpha: CGFloat) {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = alpha
        }
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
