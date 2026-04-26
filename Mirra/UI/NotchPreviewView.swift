import AVFoundation
import SwiftUI

/// The view shown when the cursor enters the notch region.
/// Shows a camera preview with a mic level indicator overlaid at the bottom.
/// The entire view including the upward arrow is filled with the camera feed.
struct NotchPreviewView: View {
    let session: AVCaptureSession
    var isMirrored: Bool = false
    @ObservedObject var micMonitor: MicLevelMonitor

    static let arrowHeight: CGFloat = 12
    static let cornerRadius: CGFloat = 12

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: session, isMirrored: isMirrored)

            // Mic level overlay
            HStack(spacing: 6) {
                Image(systemName: micMonitor.isActive ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: 4)

                        Capsule()
                            .fill(micLevelColor)
                            .frame(width: geo.size.width * CGFloat(micMonitor.level), height: 4)
                            .animation(.linear(duration: 0.05), value: micMonitor.level)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 12)

                Text(micMonitor.isActive ? "OK" : "No Mic")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.5))
        }
        .clipShape(BubbleShape(arrowHeight: Self.arrowHeight, cornerRadius: Self.cornerRadius))
    }

    private var micLevelColor: Color {
        if micMonitor.level > 0.8 {
            return .red
        } else if micMonitor.level > 0.5 {
            return .yellow
        } else {
            return .green
        }
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

        // Start at arrow left base, draw arrow tip, then arrow right base
        path.move(to: arrowLeft)
        path.addLine(to: arrowTip)
        path.addLine(to: arrowRight)

        // Continue along the top edge to top-right corner
        path.addLine(to: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyTop))
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyTop + cornerRadius),
            radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )

        // Right edge down to bottom-right corner
        path.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY - cornerRadius))
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyRect.maxY - cornerRadius),
            radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )

        // Bottom edge to bottom-left corner
        path.addLine(to: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.maxY))
        path.addArc(
            center: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.maxY - cornerRadius),
            radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )

        // Left edge up to top-left corner
        path.addLine(to: CGPoint(x: bodyRect.minX, y: bodyTop + cornerRadius))
        path.addArc(
            center: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyTop + cornerRadius),
            radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )

        // Back to arrow left base
        path.addLine(to: arrowLeft)

        path.closeSubpath()
        return path
    }
}
