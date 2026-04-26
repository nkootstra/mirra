import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class PreviewWindowController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    var sizePreset: PreviewSizePreset = .medium
    var placement: PreviewPlacement = .bottomTrailing

    var isVisible: Bool { panel?.isVisible ?? false }

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
            return
        }

        let size = sizePreset.size
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
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
    }

    func hide() {
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
        let newSize = preset.size
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let origin = placement.origin(for: newSize, in: screenFrame)
        let frame = NSRect(origin: origin, size: newSize)
        panel.setFrame(frame, display: true, animate: true)
    }

    func updatePlacement(_ newPlacement: PreviewPlacement) {
        placement = newPlacement
        guard let panel else { return }
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let origin = newPlacement.origin(for: panel.frame.size, in: screenFrame)
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
        view.layer?.cornerRadius = 10
        view.layer?.masksToBounds = true
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
}
