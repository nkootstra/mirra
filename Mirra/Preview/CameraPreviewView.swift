import AppKit
import AVFoundation
import SwiftUI

/// Wraps an NSView that hosts an AVCaptureVideoPreviewLayer.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool = false

    func makeNSView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.wantsLayer = true
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer = previewLayer
        view.layer?.addSublayer(previewLayer)
        return view
    }

    func updateNSView(_ nsView: PreviewHostView, context: Context) {
        guard let previewLayer = nsView.previewLayer else { return }
        previewLayer.session = session
        previewLayer.frame = nsView.bounds

        if isMirrored {
            previewLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        } else {
            previewLayer.transform = CATransform3DIdentity
        }
    }
}

/// NSView subclass that keeps the preview layer sized to bounds.
final class PreviewHostView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}
