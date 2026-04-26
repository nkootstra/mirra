import AVFoundation
import SwiftUI

/// The view shown when the cursor enters the notch region.
/// Shows a camera preview with a mic status indicator overlaid at the bottom.
/// The entire view including the upward arrow is filled with the camera feed.
struct NotchPreviewView: View {
    let session: AVCaptureSession
    var isMirrored: Bool = false
    @ObservedObject var micCheck: MicCheckService

    static let arrowHeight: CGFloat = 12
    static let cornerRadius: CGFloat = 12

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: session, isMirrored: isMirrored)

            // Mic status overlay
            HStack(spacing: 6) {
                Image(systemName: micCheck.isAvailable ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)

                Text(micCheck.isAvailable ? "Mic OK" : "No Mic")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black.opacity(0.5))
            )
            .padding(6)
        }
        .clipShape(BubbleShape(arrowHeight: Self.arrowHeight, cornerRadius: Self.cornerRadius))
    }
}

/// A rounded rectangle with an upward-pointing arrow centered at the top.
/// The camera preview fills the entire shape including the arrow.
struct BubbleShape: Shape {
    var arrowHeight: CGFloat = 12
    var arrowWidth: CGFloat = 28
    var cornerRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let bodyTop = rect.minY + arrowHeight
        let bodyRect = CGRect(x: rect.minX, y: bodyTop, width: rect.width, height: rect.height - arrowHeight)
        let arrowTip = CGPoint(x: rect.midX, y: rect.minY)
        let arrowLeft = CGPoint(x: rect.midX - arrowWidth / 2, y: bodyTop)
        let arrowRight = CGPoint(x: rect.midX + arrowWidth / 2, y: bodyTop)

        var path = Path()

        path.move(to: arrowLeft)
        path.addLine(to: arrowTip)
        path.addLine(to: arrowRight)

        path.addLine(to: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyTop))
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyTop + cornerRadius),
            radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )

        path.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY - cornerRadius))
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyRect.maxY - cornerRadius),
            radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )

        path.addLine(to: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.maxY))
        path.addArc(
            center: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.maxY - cornerRadius),
            radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )

        path.addLine(to: CGPoint(x: bodyRect.minX, y: bodyTop + cornerRadius))
        path.addArc(
            center: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyTop + cornerRadius),
            radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )

        path.addLine(to: arrowLeft)
        path.closeSubpath()
        return path
    }
}
